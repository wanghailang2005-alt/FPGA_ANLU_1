`timescale 1ns/1ps
`default_nettype none
// One immutable source, two display buffers, and a displayed-generation ACK.
module zoom_animation #(
    parameter CLK_HZ=100000000, STEPS=24, SLOT_CYCLES=CLK_HZ/20,
    parameter OUT_W=640,OUT_H=480, VIEW_W=OUT_W,VIEW_H=OUT_H
)(
    input wire clk,rst,start,
    input wire [15:0] src_w,src_h,
    input wire [1:0] from_mode,target_mode,display_bank,
    input wire commit_generation,view_done_toggle,
    input wire writer_ack,writer_finish_toggle,
    input wire [8:0] fifo_usedw,
    output reg write_req,
    output reg [1:0] write_bank,
    output wire pixel_valid,
    output wire [31:0] pixel,
    output reg commit,
    output wire busy,
    output reg done,
    output wire row_req,
    output wire [15:0] row_index,
    input wire row_ack,row_valid,
    input wire [23:0] row_data,
    output wire row_ready,
    output wire [4:0] step_debug,
    output reg error
);
localparam IDLE=0,G0=1,G0WAIT=2,G1=3,G1WAIT=4,DW=5,DWWAIT=6,DH=7,DHWAIT=8,
 PREP=9,WR_REQ=10,WR_RELEASE=11,RENDER=12,DEADLINE=13,VIEW=14;
reg [3:0] state;
reg [15:0] w,h;
reg [1:0] old_mode,new_mode;
reg [19:0] current_w,current_h,end_w,end_h;
reg w_plus,h_plus;
reg [19:0] w_step,h_step;
reg [4:0] w_rem,h_rem,w_acc,h_acc;
wire [5:0] w_sum={1'b0,w_acc}+{1'b0,w_rem};
wire [5:0] h_sum={1'b0,h_acc}+{1'b0,h_rem};
reg [4:0] step;
reg [31:0] elapsed,deadline;
reg geom_go,div_go,render_go;
reg [1:0] geom_mode;
wire geom_done;
wire [19:0] gw,gh;
wire div_busy,div_done;
reg [31:0] div_n;
wire [31:0] dq,dr;
reg finish_seen,write_complete,render_complete,expected_generation;
wire render_done,render_error,render_busy;
assign busy=state!=IDLE;
assign step_debug=step;
zoom_mode_geometry #(.OUT_W(VIEW_W),.OUT_H(VIEW_H)) u_geometry(
 .clk(clk),.rst(rst),.start(geom_go),.src_w(w),.src_h(h),.mode(geom_mode),
 .done(geom_done),.scaled_w(gw),.scaled_h(gh));
zoom_udiv32 u_delta_div(clk,rst,div_go,div_n,STEPS,div_busy,div_done,dq,dr);
zoom_cached_scaler #(.OUT_W(OUT_W),.OUT_H(OUT_H),.VIEW_W(VIEW_W),.VIEW_H(VIEW_H)) u_render(
 .clk(clk),.rst(rst),.start(render_go),.src_w(w),.src_h(h),.scaled_w(current_w),.scaled_h(current_h),
 .row_req(row_req),.row_index(row_index),.row_ack(row_ack),.row_valid(row_valid),
 .row_data(row_data),.row_ready(row_ready),.fifo_usedw((write_req || writer_ack) ? 9'd511 : fifo_usedw),
 .pixel_valid(pixel_valid),.pixel(pixel),.busy(render_busy),.done(render_done),.error(render_error));
always @(posedge clk or posedge rst) begin
 if(rst) begin
    state<=IDLE;write_req<=0;write_bank<=0;commit<=0;done<=0;error<=0;
    w<=0;h<=0;old_mode<=0;new_mode<=0;current_w<=0;current_h<=0;end_w<=0;end_h<=0;
    w_plus<=0;h_plus<=0;w_step<=0;h_step<=0;w_rem<=0;h_rem<=0;w_acc<=0;h_acc<=0;
    step<=0;elapsed<=0;deadline<=0;geom_go<=0;geom_mode<=0;div_go<=0;div_n<=0;render_go<=0;
    finish_seen<=0;write_complete<=0;render_complete<=0;expected_generation<=0;
 end else begin
    commit<=0;done<=0;geom_go<=0;div_go<=0;render_go<=0;
    if(busy) elapsed<=elapsed+1'b1;
    if(render_done) render_complete<=1;
    if(writer_finish_toggle!=finish_seen && state>=WR_REQ) write_complete<=1;
    if(render_error && busy) error<=1;
    case(state)
    IDLE:if(start) begin
        w<=src_w;h<=src_h;old_mode<=from_mode;new_mode<=target_mode;step<=0;
        w_acc<=0;h_acc<=0;elapsed<=0;deadline<=SLOT_CYCLES;error<=0;state<=G0;
    end
    G0:begin geom_mode<=old_mode;geom_go<=1;state<=G0WAIT;end
    G0WAIT:if(geom_done) begin current_w<=gw;current_h<=gh;state<=G1;end
    G1:begin geom_mode<=new_mode;geom_go<=1;state<=G1WAIT;end
    G1WAIT:if(geom_done) begin end_w<=gw;end_h<=gh;w_plus<=gw>=current_w;h_plus<=gh>=current_h;state<=DW;end
    DW:begin div_n<=w_plus ? end_w-current_w : current_w-end_w;div_go<=1;state<=DWWAIT;end
    DWWAIT:if(div_done) begin w_step<=dq[19:0];w_rem<=dr[4:0];state<=DH;end
    DH:begin div_n<=h_plus ? end_h-current_h : current_h-end_h;div_go<=1;state<=DHWAIT;end
    DHWAIT:if(div_done) begin h_step<=dq[19:0];h_rem<=dr[4:0];state<=PREP;end
    PREP:begin
        current_w<=w_plus ? current_w+w_step+(w_sum>=STEPS) : current_w-w_step-(w_sum>=STEPS);
        current_h<=h_plus ? current_h+h_step+(h_sum>=STEPS) : current_h-h_step-(h_sum>=STEPS);
        w_acc<=w_sum>=STEPS ? w_sum-STEPS:w_sum;h_acc<=h_sum>=STEPS ? h_sum-STEPS:h_sum;
        step<=step+1'b1;write_bank<={1'b0,~display_bank[0]};
        finish_seen<=writer_finish_toggle;write_complete<=0;render_complete<=0;
        write_req<=1;state<=WR_REQ;
    end
    WR_REQ:if(writer_ack) begin write_req<=0;state<=WR_RELEASE;end
    WR_RELEASE:if(!writer_ack) begin render_go<=1;state<=RENDER;end
    RENDER:if((render_complete || render_done) && write_complete) state<=DEADLINE;
    DEADLINE:if(elapsed>=deadline) begin commit<=1;expected_generation<=~commit_generation;state<=VIEW;end
    VIEW:if(view_done_toggle==expected_generation) begin
        if(step==STEPS) begin done<=1;state<=IDLE;end
        else begin deadline<=deadline+SLOT_CYCLES;state<=PREP;end
    end
    default:state<=IDLE;
    endcase
 end
end
endmodule

module zoom_mode_geometry #(parameter OUT_W=640,OUT_H=480)(
 input wire clk,rst,start,input wire [15:0] src_w,src_h,input wire [1:0] mode,
 output reg done,output reg [19:0] scaled_w,scaled_h
);
reg [2:0] state;
reg [15:0] w,h;
reg [1:0] m;
reg width_div;
reg go;
reg [31:0] n,d;
wire dbusy,ddone;
wire [31:0] q,rem;
zoom_udiv32 u_div(clk,rst,go,n,d,dbusy,ddone,q,rem);
always @(posedge clk or posedge rst) begin
 if(rst) begin state<=0;done<=0;scaled_w<=1;scaled_h<=1;w<=0;h<=0;m<=0;width_div<=0;go<=0;n<=0;d<=1;end
 else begin
    done<=0;go<=0;
    case(state)
    0:if(start) begin w<=src_w;h<=src_h;m<=mode;state<=1;end
    1:if(m==0) begin scaled_w<=w;scaled_h<=h;state<=3;end
      else begin
        if(((w*OUT_H<=h*OUT_W) && m==1) || ((w*OUT_H>h*OUT_W) && m==2)) begin
            scaled_h<=OUT_H;n<=w*OUT_H;d<=h;width_div<=1;
        end else begin scaled_w<=OUT_W;n<=h*OUT_W;d<=w;width_div<=0;end
        go<=1;state<=2;
      end
    2:if(ddone) begin
        if(width_div) scaled_w<=q==0 ? 20'd1:q[19:0];
        else scaled_h<=q==0 ? 20'd1:q[19:0];state<=3;
      end
    3:begin done<=1;state<=0;end
    default:state<=0;
    endcase
 end
end
endmodule
`default_nettype wire
