`timescale 1ns/1ps
`default_nettype none
// Loading-only scaler. The source is an immutable bottom-up SDRAM cache.
// Request one source row at a time; the bridge returns RGB888 words in order.
module zoom_cached_scaler #(
    parameter OUT_W=640, OUT_H=480, MAX_W=1024, FIFO_STALL=384
)(
    input wire clk,rst,start,
    input wire [15:0] src_w,src_h,
    input wire [19:0] scaled_w,scaled_h,
    output reg row_req,
    output reg [15:0] row_index,
    input wire row_ack,row_valid,
    input wire [23:0] row_data,
    output wire row_ready,
    input wire [8:0] fifo_usedw,
    output reg pixel_valid,
    output reg [31:0] pixel,
    output wire busy,
    output reg done,error
);
localparam IDLE=0,SETUP=1,XSTEP=2,XSTEP_WAIT=3,XSEED=4,XSEED_WAIT=5,
 XSFRAC=6,XSFRAC_WAIT=7,YPREP=8,YDIV=9,YWAIT=10,YFRAC=11,YFWAIT=12,
 CHECK=13,FETCH_REQ=14,FETCH=15,LEFT=16,RIGHT=17,C0=18,C1=19,C2=20,
 DRAIN=21,FINISH=22;
reg [4:0] state;
reg [10:0] w,h;
reg [19:0] sw,sh;
reg signed [31:0] ox,oy,fy;
reg [15:0] tx,tr,needed,fetch_x,fetch_row;
reg [15:0] tag_even,tag_odd;
reg valid_even,valid_odd;
reg [31:0] xstep,xstep_rem,xseed,xseed_rem,xcoord,xrem;
reg [31:0] seed_int,seed_rem;
reg [7:0] wy;
reg [19:0] crop_x;
wire signed [31:0] fx=$signed({16'd0,tx})-ox;
wire inside_x=fx>=0 && fx<$signed({12'd0,sw});
wire inside_y=fy>=0 && fy<$signed({12'd0,sh});
wire in_image=inside_x && inside_y;
wire [31:0] rem_sum=xrem+xstep_rem;
wire [9:0] sx=xcoord[17:8];
wire [9:0] sx1=(sx<w-1) ? sx+10'd1 : sx;
wire top_present=needed[0] ? (valid_odd && tag_odd==needed) : (valid_even && tag_even==needed);
wire bottom_present=needed==0 || (needed[0] ? (valid_even && tag_even==needed-1'b1) : (valid_odd && tag_odd==needed-1'b1));
assign row_ready=state==FETCH;
assign busy=state!=IDLE;
reg [23:0] even_mem[0:MAX_W-1],odd_mem[0:MAX_W-1];
reg [23:0] eq,oq,el,ol;
wire [23:0] tl=needed[0] ? ol : el;
wire [23:0] rr=needed[0] ? oq : eq;
wire [23:0] bl=needed==0 ? tl : (needed[0] ? el : ol);
wire [23:0] br=needed==0 ? rr : (needed[0] ? eq : oq);
always @(posedge clk) begin
    if(row_valid && row_ready) begin
        if(fetch_row[0]) odd_mem[fetch_x]<=row_data;
        else even_mem[fetch_x]<=row_data;
    end
    if((state==LEFT || state==RIGHT) && in_image) begin
        eq<=even_mem[state==RIGHT ? sx1 : sx];
        oq<=odd_mem[state==RIGHT ? sx1 : sx];
    end
    if(state==RIGHT) begin el<=eq;ol<=oq;end
end
reg div_go;
reg [31:0] div_n,div_d;
wire div_busy,div_done;
wire [31:0] dq,dr;
zoom_udiv32 u_div(clk,rst,div_go,div_n,div_d,div_busy,div_done,dq,dr);

// Three channels are issued on consecutive clocks; two horizontal DSPs and
// one vertical DSP are shared by RGB. Pixel service time is five clocks.
wire issue=(state==C0 || state==C1 || state==C2);
wire [1:0] channel=state==C0 ? 2'd0 : state==C1 ? 2'd1 : 2'd2;
wire [4:0] shift=state==C0 ? 5'd16 : state==C1 ? 5'd8 : 5'd0;
reg [6:0] vp,lp;
reg [1:0] cp[0:6];
integer i;
reg [7:0] a0,b0,c0,d0,wx0,wy0;
reg signed [8:0] dx1,dx_b1;
reg [7:0] a1,c1,wx1,wy1;
reg signed [17:0] hp2,bp2;
reg [7:0] a2,c2,wy2;
reg signed [17:0] ht3,hb3;
reg [7:0] wy3;
reg signed [17:0] dy4,ht4;
reg [7:0] wy4;
reg signed [26:0] prod5,sum6;
reg signed [17:0] ht5;
reg [7:0] red_hold,green_hold;
always @(posedge clk or posedge rst) begin
    if(rst) begin
        vp<=0;lp<=0;pixel_valid<=0;pixel<=0;red_hold<=0;green_hold<=0;
        for(i=0;i<7;i=i+1) cp[i]<=0;
        a0<=0;b0<=0;c0<=0;d0<=0;wx0<=0;wy0<=0;
        dx1<=0;dx_b1<=0;a1<=0;c1<=0;wx1<=0;wy1<=0;
        hp2<=0;bp2<=0;a2<=0;c2<=0;wy2<=0;ht3<=0;hb3<=0;wy3<=0;
        dy4<=0;ht4<=0;wy4<=0;prod5<=0;ht5<=0;sum6<=0;
    end else begin
        vp<={vp[5:0],issue};lp<={lp[5:0],issue && tx==OUT_W-1 && tr==OUT_H-1};
        cp[0]<=channel;for(i=1;i<7;i=i+1) cp[i]<=cp[i-1];
        a0<=in_image ? (tl>>shift) : 8'd0;b0<=in_image ? (rr>>shift) : 8'd0;
        c0<=in_image ? (bl>>shift) : 8'd0;d0<=in_image ? (br>>shift) : 8'd0;
        wx0<=xcoord[7:0];wy0<=wy;
        dx1<=$signed({1'b0,b0})-$signed({1'b0,a0});
        dx_b1<=$signed({1'b0,d0})-$signed({1'b0,c0});
        a1<=a0;c1<=c0;wx1<=wx0;wy1<=wy0;
        hp2<=dx1*$signed({1'b0,wx1});bp2<=dx_b1*$signed({1'b0,wx1});
        a2<=a1;c2<=c1;wy2<=wy1;
        ht3<=$signed({1'b0,a2,8'd0})+hp2;
        hb3<=$signed({1'b0,c2,8'd0})+bp2;wy3<=wy2;
        dy4<=hb3-ht3;ht4<=ht3;wy4<=wy3;
        prod5<=dy4*$signed({1'b0,wy4});ht5<=ht4;
        sum6<=($signed(ht5)<<<8)+prod5+27'sd32768;
        pixel_valid<=0;
        if(vp[6]) case(cp[6])
            0:red_hold<=sum6[23:16];
            1:green_hold<=sum6[23:16];
            2:begin pixel<={red_hold,green_hold,sum6[23:16],8'd0};pixel_valid<=1;end
            default: ;
        endcase
    end
end
always @(posedge clk or posedge rst) begin
    if(rst) begin
        state<=IDLE;done<=0;error<=0;w<=0;h<=0;sw<=0;sh<=0;ox<=0;oy<=0;fy<=0;
        tx<=0;tr<=0;needed<=0;fetch_x<=0;fetch_row<=0;tag_even<=0;tag_odd<=0;
        valid_even<=0;valid_odd<=0;row_req<=0;row_index<=0;
        div_go<=0;div_n<=0;div_d<=1;xstep<=0;xstep_rem<=0;
        xseed<=0;xseed_rem<=0;xcoord<=0;xrem<=0;seed_int<=0;seed_rem<=0;wy<=0;crop_x<=0;
    end else begin
        done<=0;div_go<=0;
        case(state)
        IDLE:if(start) begin
            w<=src_w[10:0];h<=src_h[10:0];sw<=scaled_w;sh<=scaled_h;
            valid_even<=0;valid_odd<=0;tr<=0;tx<=0;
            error<=src_w==0 || src_h==0 || src_w>MAX_W || src_h>1024 || scaled_w==0 || scaled_h==0;
            state<=(src_w==0 || src_h==0 || src_w>MAX_W || src_h>1024 || scaled_w==0 || scaled_h==0) ? FINISH : SETUP;
        end
        SETUP:begin ox<=($signed(OUT_W)-$signed({12'd0,sw}))>>>1;oy<=($signed(OUT_H)-$signed({12'd0,sh}))>>>1;state<=XSTEP;end
        XSTEP:begin crop_x<=ox<0 ? -ox:0;div_n<={13'd0,w,8'd0};div_d<={12'd0,sw};div_go<=1;state<=XSTEP_WAIT;end
        XSTEP_WAIT:if(div_done) begin xstep<=dq;xstep_rem<=dr;state<=XSEED;end
        XSEED:if(ox<0) begin div_n<=crop_x*w;div_d<={12'd0,sw};div_go<=1;state<=XSEED_WAIT;end
            else begin xseed<=0;xseed_rem<=0;state<=YPREP;end
        XSEED_WAIT:if(div_done) begin seed_int<=dq;seed_rem<=dr;state<=XSFRAC;end
        XSFRAC:begin div_n<=seed_rem<<8;div_d<={12'd0,sw};div_go<=1;state<=XSFRAC_WAIT;end
        XSFRAC_WAIT:if(div_done) begin xseed<=(seed_int<<8)+dq;xseed_rem<=dr;state<=YPREP;end
        YPREP:begin fy<=$signed(OUT_H-1)-$signed({16'd0,tr})-oy;tx<=0;xcoord<=xseed;xrem<=xseed_rem;state<=YDIV;end
        YDIV:if(inside_y) begin div_n<=fy*h;div_d<={12'd0,sh};div_go<=1;state<=YWAIT;end else state<=LEFT;
        YWAIT:if(div_done) begin needed<=h-1-dq;seed_rem<=dr;state<=YFRAC;end
        YFRAC:begin div_n<=seed_rem<<8;div_d<={12'd0,sh};div_go<=1;state<=YFWAIT;end
        YFWAIT:if(div_done) begin wy<=dq[7:0];state<=CHECK;end
        CHECK:if(!row_ack) begin
            if(!top_present) begin fetch_row<=needed;row_index<=needed;row_req<=1;state<=FETCH_REQ;end
            else if(!bottom_present) begin fetch_row<=needed-1'b1;row_index<=needed-1'b1;row_req<=1;state<=FETCH_REQ;end
            else state<=LEFT;
        end
        FETCH_REQ:if(row_ack) begin row_req<=0;fetch_x<=0;state<=FETCH;end
        FETCH:if(row_valid) begin
            if(fetch_x==w-1) begin
                if(fetch_row[0]) begin tag_odd<=fetch_row;valid_odd<=1;end
                else begin tag_even<=fetch_row;valid_even<=1;end
                state<=CHECK;
            end else fetch_x<=fetch_x+1'b1;
        end
        LEFT:if(fifo_usedw<FIFO_STALL) state<=RIGHT;
        RIGHT:state<=C0;
        C0:state<=C1;
        C1:state<=C2;
        C2:begin
            if(inside_x) begin
                xcoord<=xcoord+xstep+(rem_sum>=sw ? 32'd1:32'd0);
                xrem<=rem_sum>=sw ? rem_sum-sw:rem_sum;
            end
            if(tx==OUT_W-1) state<=DRAIN;
            else begin tx<=tx+1'b1;state<=LEFT;end
        end
        DRAIN:if(vp==0 && !pixel_valid) begin
            if(tr==OUT_H-1) state<=FINISH;
            else begin tr<=tr+1'b1;state<=YPREP;end
        end
        FINISH:begin done<=1;state<=IDLE;end
        default:state<=IDLE;
        endcase
    end
end
endmodule
`default_nettype wire

