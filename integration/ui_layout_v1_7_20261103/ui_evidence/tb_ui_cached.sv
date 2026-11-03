`timescale 1ns/1ps
module tb_cached;
reg clk=0;always #5 clk=~clk;
reg rst=1,start=0;
reg [15:0] iw=320,ih=240;
reg [19:0] ww=640,hh=480;
wire req,ready,busy,done,error,ov;
wire [15:0] ri;
reg ack=0,rv=0;
reg [23:0] data=0;
wire [31:0] pixel;
reg [8:0] used=0;
integer ticks=0,got=0,cases=0,rx=0,ry=0,row_count=0,ox,oy,x,y,fx,fy,sx,sy,timeout;
reg sending=0,checking=0,test_pass=0;
reg row_taken=0;always @(posedge clk) row_taken<=rv && ready;
reg [31:0] expected;
zoom_cached_scaler #(.VIEW_W(480),.VIEW_H(360)) dut(.clk(clk),.rst(rst),.start(start),.src_w(iw),.src_h(ih),
 .scaled_w(ww),.scaled_h(hh),.row_req(req),.row_index(ri),.row_ack(ack),
 .row_valid(rv),.row_data(data),.row_ready(ready),.fifo_usedw(used),
 .pixel_valid(ov),.pixel(pixel),.busy(busy),.done(done),.error(error));
function automatic [23:0] colour(input integer xx,yy);
 colour={8'(xx),8'(yy),8'(xx+yy)};
endfunction
function automatic [23:0] reference(input integer xx,yy,rx,ry,denx,deny);
 integer x1,y1,ax,ay,c,a,b,d,e,v;reg [23:0] z;
 begin
 x1=xx+1<iw ? xx+1 : xx;y1=yy+1<ih ? yy+1 : yy;
 ax=rx*256/denx;ay=ry*256/deny;z=0;
 for(c=0;c<3;c=c+1) begin
 a=(colour(xx,yy)>>(8*c))&255;b=(colour(x1,yy)>>(8*c))&255;
 d=(colour(xx,y1)>>(8*c))&255;e=(colour(x1,y1)>>(8*c))&255;
 v=(a*(256-ax)*(256-ay)+b*ax*(256-ay)+d*(256-ax)*ay+e*ax*ay+32768)/65536;
 z=z|(v<<(8*c));
 end
 reference=z;
 end
endfunction
// Stalled row source, held request/ACK, and stable data while the reader stalls.
always @(negedge clk) begin
 ticks=ticks+1;used=ticks%997<111 ? 450:0;
 if(rst) begin ack=0;rv=0;sending=0;rx=0;end
 else if(!ack && req) begin
   if(ri>=ih) $fatal(1,"source row out of bounds");
   ack=1;sending=1;rx=0;ry=ih-1-ri;row_count=row_count+1;
 end else if(sending) begin
   if(row_taken) begin rx=rx+1;rv=0;end
   if(rx==iw) begin sending=0;rv=0;end
   else if(!rv && ticks%7!=0) begin data=colour(rx,ry);rv=1;end
 end else if(ack && !req) ack=0;
end
always @(posedge clk) if(checking && !rst && ov) begin
 if(got>=640*480) $fatal(1,"too many output pixels");
 x=got%640;y=479-got/640;fx=x-ox;fy=y-oy;expected=0;
 if(x<480 && y<360 && fx>=0 && fy>=0 && fx<ww && fy<hh) begin
  sx=fx*iw/ww;sy=fy*ih/hh;
  expected={reference(sx,sy,(fx*iw)%ww,(fy*ih)%hh,ww,hh),8'd0};
 end
 if(pixel!==expected) $fatal(1,"cached pixel mismatch src=%0dx%0d scale=%0dx%0d xy=%0d,%0d got=%h expected=%h",iw,ih,ww,hh,x,y,pixel,expected);
 got=got+1;
end
task automatic run_case(input integer width,height,tw,th);
 begin
 checking=0;rst=1;repeat(5) @(negedge clk);iw=width;ih=height;ww=tw;hh=th;
 ox=(480-tw)>>>1;oy=((360-th)>>>1);got=0;row_count=0;rst=0;checking=1;
 repeat(5) @(negedge clk);start=1;@(negedge clk);start=0;timeout=0;
 while(!done && timeout<15000000) begin @(negedge clk);timeout=timeout+1;end
 if(!done || error || got!=307200) $fatal(1,"bad completion state=%0d pixels=%0d rows=%0d",dut.state,got,row_count);
 repeat(20) @(negedge clk);if(busy || ov || got!=307200) $fatal(1,"output after completion");
 cases=cases+1;$display("PASS cached src=%0dx%0d scaled=%0dx%0d pixels=%0d rows=%0d cycles=%0d",iw,ih,ww,hh,got,row_count,timeout);
 end
endtask
initial begin
 run_case(320,240,480,360);run_case(241,361,240,360);run_case(241,361,480,719);run_case(1,1,480,360);
 $display("RESULT PASS cached frames=%0d pixels=%0d",cases,cases*307200);test_pass=1;$finish;
end
endmodule
