`timescale 1ns/1ps
`default_nettype none
// RGB888, bottom-up rows in AND out. The existing SDRAM writer flips rows.
// Input is valid/ready; output is a write pulse with FIFO occupancy feedback.
// Own implementation; references and limitations are recorded in README.md.
module scale_on_load #(
    parameter OUT_W=640, OUT_H=480, SRC_W_MAX=1024,
    parameter FIFO_STALL=384
)(
    input wire clk, rst, load_start,
    input wire [1:0] mode,
    input wire interpolation,
    input wire [15:0] src_w, src_h,
    input wire src_px_valid,
    input wire [23:0] src_px,
    output wire src_accept,
    input wire source_done,
    input wire [8:0] fifo_usedw,
    output reg tgt_px_valid,
    output reg [31:0] tgt_px,
    output wire busy,
    output reg cfg_error, frame_done
);
localparam IDLE=0, CFG=1, CFGDIV=2, OFFSETS=3, XSTEP=4,
           XSTEPWAIT=5, XSEED=6, XSEEDWAIT=7, Y=8, YWAIT=9,
           ROW=10, READ=11, EMIT=12, BLACK=13, TAIL=14, YPREP=15, YWEIGHT=16, RIGHT=17, WEIGHT=18,
           H0MUL=19, H0ADD=20, H1MUL=21, H1ADD=22, VMUL=23, VADD=24, H0EXEC=25, H1EXEC=26, VEXEC=27, SAMPLE=28;
reg [4:0] state;
reg bilinear;
reg [10:0] w,h;
reg [1:0] m;
reg [31:0] sc_w,sc_h;
reg signed [31:0] offx,offy,endx;
reg cfg_width;
reg [31:0] x_step,x_frac,x_seed,x_rem_seed,sx,x_rem;
reg [15:0] tx,tr,needed,src_x,src_row,row_tag;
reg row_full, start_d, source_seen;
reg black_ready;
wire start = load_start && !start_d;
wire signed [31:0] fy_raw = $signed(OUT_H-1)-$signed({16'd0,tr})-offy;
reg signed [31:0] fy;
reg [19:0] crop_x;
wire signed [31:0] fx = $signed({16'd0,tx})-offx;
wire inside_x = $signed({16'd0,tx})>=offx && $signed({16'd0,tx})<endx;
wire inside_y = fy>=0 && fy<$signed(sc_h);
wire [31:0] x_sum = x_rem+x_frac;
// Two parity banks retain adjacent source rows in bottom-up stream order.
reg [23:0] line_even[0:SRC_W_MAX-1],line_odd[0:SRC_W_MAX-1];
reg [23:0] even_left,odd_left,even_right,odd_right;
wire [9:0] right_x = sx < w-1 ? sx[9:0]+10'd1 : sx[9:0];
wire [23:0] top_left = needed[0] ? (bilinear ? odd_left : odd_right) : (bilinear ? even_left : even_right);
wire [23:0] top_right = needed[0] ? odd_right : even_right;
wire [23:0] bottom_left = needed==0 ? top_left : (needed[0] ? even_left : odd_left);
wire [23:0] bottom_right = needed==0 ? top_right : (needed[0] ? even_right : odd_right);
reg [7:0] wx,wy;
reg [31:0] weight_rem;
reg [3:0] weight_count;
wire [32:0] weight_trial={weight_rem,1'b0};
reg [1:0] channel;
reg [23:0] blended;
reg [7:0] p00,p01,p10,p11;
reg signed [17:0] mul_a_reg;
reg signed [8:0] mul_b_reg;
reg signed [17:0] ht,hb;
reg signed [17:0] mul_a;
reg signed [8:0] mul_b;
reg signed [26:0] product;
wire signed [26:0] vertical_sum=($signed(ht) <<< 8)+product+27'sd32768;
always @* begin
    mul_a=0;mul_b=$signed({1'b0,wx});
    case(state)
        H0MUL: mul_a=$signed({1'b0,p01})-$signed({1'b0,p00});
        H1MUL: mul_a=$signed({1'b0,p11})-$signed({1'b0,p10});
        VMUL: begin mul_a=hb-ht;mul_b=$signed({1'b0,wy});end
        default: ;
    endcase
end
assign busy = state!=IDLE;
assign src_accept = !rst && !start && ((state==TAIL) ||
                    (state==ROW && !row_full && src_row<=needed));
// No reset on RAM ports: infer two synchronous simple dual-port RAM banks.
always @(posedge clk) begin
    if(src_px_valid && src_accept && state==ROW) begin
        if(src_row[0]) line_odd[src_x] <= src_px;
        else line_even[src_x] <= src_px;
    end
    if((state==READ && inside_x) || state==RIGHT) begin
        even_right<=line_even[state==RIGHT ? right_x : sx[9:0]];
        odd_right<=line_odd[state==RIGHT ? right_x : sx[9:0]];
    end
    if(state==RIGHT) begin even_left<=even_right;odd_left<=odd_right;end
end
reg div_go;
reg [31:0] div_n,div_d;
wire div_busy,div_done;
wire [31:0] div_q,div_r;
zoom_udiv32 u_div(clk,rst,div_go,div_n,div_d,div_busy,div_done,div_q,div_r);
always @(posedge clk or posedge rst) begin
    if(rst) begin
        state<=IDLE; bilinear<=0; wx<=0;wy<=0;weight_rem<=0;weight_count<=0;
        p00<=0;p01<=0;p10<=0;p11<=0;mul_a_reg<=0;mul_b_reg<=0;
        channel<=0;blended<=0;ht<=0;hb<=0;product<=0; start_d<=0; source_seen<=0; black_ready<=0;
        w<=0; h<=0; m<=0; sc_w<=1; sc_h<=1; offx<=0; offy<=0;endx<=0;
        cfg_width<=0; x_step<=0; x_frac<=0; x_seed<=0; x_rem_seed<=0;
        sx<=0; x_rem<=0; tx<=0; tr<=0; needed<=0;
        src_x<=0; src_row<=0; row_tag<=0; row_full<=0;
        div_go<=0; div_n<=0; div_d<=1; fy<=0; crop_x<=0;
        tgt_px_valid<=0; tgt_px<=0; cfg_error<=0; frame_done<=0;
    end else begin
        start_d<=load_start; div_go<=0; tgt_px_valid<=0; frame_done<=0;
        if(source_done) source_seen<=1;
        if(src_px_valid && src_accept) begin
            if(src_x==w-1) begin
                src_x<=0; src_row<=src_row+1'b1;
                if(state==ROW && src_row==needed) begin
                    row_full<=1; row_tag<=src_row;
                end
            end else src_x<=src_x+1'b1;
        end
        if(start) begin
            w<=src_w[10:0]; h<=src_h[10:0]; m<=mode; bilinear<=interpolation;
            tr<=0; tx<=0; src_x<=0; src_row<=0; row_full<=0; source_seen<=0; black_ready<=0;
            cfg_error<=src_w==0 || src_h==0 || src_w>SRC_W_MAX || src_h>1024;
            state <= (src_w==0 || src_h==0 || src_w>SRC_W_MAX || src_h>1024) ? IDLE : CFG;
        end else case(state)
            IDLE: ;
            CFG: begin
                if(m==0 || m==3) begin sc_w<=w; sc_h<=h; state<=OFFSETS; end
                else begin
                    // Fit: choose the limiting dimension. Fill: choose its opposite.
                    if(((w*OUT_H <= h*OUT_W) && m==1) ||
                       ((w*OUT_H > h*OUT_W) && m==2)) begin
                        sc_h<=OUT_H; div_n<=w*OUT_H; div_d<=h; cfg_width<=1;
                    end else begin
                        sc_w<=OUT_W; div_n<=h*OUT_W; div_d<=w; cfg_width<=0;
                    end
                    div_go<=1; state<=CFGDIV;
                end
            end
            CFGDIV: if(div_done) begin
                if(cfg_width) sc_w<=div_q==0 ? 1 : div_q;
                else sc_h<=div_q==0 ? 1 : div_q;
                state<=OFFSETS;
            end
            OFFSETS: begin
                offx<=($signed(OUT_W)-$signed(sc_w)) >>> 1;
                endx<=($signed(OUT_W)+$signed(sc_w)) >>> 1;
                offy<=($signed(OUT_H)-$signed(sc_h)) >>> 1;
                state<=XSTEP;
            end
            XSTEP: begin
                crop_x<=offx<0 ? -offx : 0;
                div_n<=w; div_d<=sc_w; div_go<=1; state<=XSTEPWAIT;
            end
            XSTEPWAIT: if(div_done) begin x_step<=div_q; x_frac<=div_r; state<=XSEED; end
            XSEED: begin
                if(offx<0) begin div_n<=crop_x*w; div_d<=sc_w; div_go<=1; state<=XSEEDWAIT; end
                else begin x_seed<=0; x_rem_seed<=0; state<=YPREP; end
            end
            XSEEDWAIT: if(div_done) begin x_seed<=div_q; x_rem_seed<=div_r; state<=YPREP; end
            YPREP: begin fy<=fy_raw; state<=Y; end
            Y: begin
                tx<=0; sx<=x_seed; x_rem<=x_rem_seed; black_ready<=0;
                if(inside_y) begin div_n<=fy[19:0]*h; div_d<=sc_h; div_go<=1; state<=YWAIT; end
                else state<=BLACK;
            end
            YWAIT: if(div_done) begin
                needed<=h-1-div_q;
                if(bilinear) begin div_n<=div_r<<8;div_d<=sc_h;div_go<=1;state<=YWEIGHT;end
                else state<=ROW;
            end
            YWEIGHT: if(div_done) begin wy<=div_q[7:0];state<=ROW;end
            ROW: begin
                if(row_full && row_tag==needed) state<=READ;
                else if(row_full) row_full<=0;
            end
            READ: begin
                if(bilinear && inside_x) begin state<=RIGHT;channel<=0;end
                else state<=EMIT;
            end
            RIGHT: begin weight_rem<=x_rem;weight_count<=0;wx<=0;state<=WEIGHT;end
            // Exact floor(256 * x_remainder / scaled_width), eight fraction bits.
            WEIGHT: begin
                if(weight_trial>={1'b0,sc_w}) begin
                    wx<={wx[6:0],1'b1};weight_rem<=weight_trial-sc_w;
                end else begin wx<={wx[6:0],1'b0};weight_rem<=weight_trial;end
                if(weight_count==7) state<=SAMPLE;
                else weight_count<=weight_count+1'b1;
            end
            // One shared signed multiplier; retain horizontal Q8 precision.
            SAMPLE: begin
                p00<=top_left>>(channel*8);p01<=top_right>>(channel*8);
                p10<=bottom_left>>(channel*8);p11<=bottom_right>>(channel*8);
                state<=H0MUL;
            end
            H0MUL: begin mul_a_reg<=mul_a;mul_b_reg<=mul_b;state<=H0EXEC;end
            H0EXEC: begin product<=mul_a_reg*mul_b_reg;state<=H0ADD;end
            H0ADD: begin ht<=$signed({1'b0,p00,8'd0})+product;state<=H1MUL;end
            H1MUL: begin mul_a_reg<=mul_a;mul_b_reg<=mul_b;state<=H1EXEC;end
            H1EXEC: begin product<=mul_a_reg*mul_b_reg;state<=H1ADD;end
            H1ADD: begin hb<=$signed({1'b0,p10,8'd0})+product;state<=VMUL;end
            VMUL: begin mul_a_reg<=mul_a;mul_b_reg<=mul_b;state<=VEXEC;end
            VEXEC: begin product<=mul_a_reg*mul_b_reg;state<=VADD;end
            VADD: begin
                case(channel)
                    0: blended[7:0]<=vertical_sum[23:16];
                    1: blended[15:8]<=vertical_sum[23:16];
                    2: blended[23:16]<=vertical_sum[23:16];
                    default: ;
                endcase
                if(channel==2) state<=EMIT;
                else begin channel<=channel+1'b1;state<=SAMPLE;end
            end
            EMIT: if(fifo_usedw<FIFO_STALL) begin
                tgt_px_valid<=1; tgt_px<=inside_x ? {(bilinear ? blended : top_left),8'd0} : 32'd0;
                if(inside_x) begin
                    sx<=sx+x_step+(x_sum>=sc_w ? 32'd1 : 32'd0);
                    x_rem<=x_sum>=sc_w ? x_sum-sc_w : x_sum;
                end
                if(tx==OUT_W-1) begin
                    if(tr==OUT_H-1) state<=TAIL;
                    else begin tr<=tr+1'b1; state<=YPREP; end
                end else begin tx<=tx+1'b1; state<=READ; end
            end
            BLACK: if(!black_ready) begin
                // Match READ/EMIT cadence: one preparation clock per pixel.
                black_ready<=1;
            end else if(fifo_usedw<FIFO_STALL) begin
                tgt_px_valid<=1; tgt_px<=0; black_ready<=0;
                if(tx==OUT_W-1) begin
                    if(tr==OUT_H-1) state<=TAIL;
                    else begin tr<=tr+1'b1; state<=YPREP; end
                end else tx<=tx+1'b1;
            end
            TAIL: if(source_seen || source_done) begin frame_done<=1; state<=IDLE; end
            default: state<=IDLE;
        endcase
    end
end
endmodule

// One shared iterative divider: no variable combinational divide in pixel paths.
module zoom_udiv32(
    input wire clk,rst,go,
    input wire [31:0] numerator,denominator,
    output reg busy,done,
    output reg [31:0] quotient,remainder
);
reg [31:0] n,d;
reg [4:0] bitno;
wire [32:0] trial={remainder,n[31]};
always @(posedge clk or posedge rst) begin
    if(rst) begin busy<=0; done<=0; quotient<=0; remainder<=0; n<=0; d<=1; bitno<=0; end
    else begin
        done<=0;
        if(go && !busy) begin
            n<=numerator; d<=denominator; quotient<=0; remainder<=0; bitno<=31; busy<=1;
        end else if(busy) begin
            n<=n<<1;
            quotient<={quotient[30:0],(trial>={1'b0,d})};
            if(trial>={1'b0,d}) remainder<=trial-{1'b0,d};
            else remainder<=trial[31:0];
            if(bitno==0) begin busy<=0; done<=1; end
            else bitno<=bitno-1'b1;
        end
    end
end
endmodule
`default_nettype wire
