`timescale 1ns/1ps
module tb_zoom;
reg clk=0; always #5 clk=~clk;
reg rst=1,load_start=0;
reg [1:0] mode=0;
reg interpolation=0;
wire req,ack,read_req,ready,load_done,load_error;
wire [31:0] read_addr;
reg [7:0] sd_byte=0;
reg sd_valid=0,sd_end=0;
wire px_valid,px_ready;
wire [23:0] px;
wire [15:0] sw,sh;
wire out_valid,busy,done,error;
wire [31:0] out_px;
reg [8:0] usedw=0;
integer iw=640,ih=480,im=0;
integer tick=0,got=0,src_count=0,cases=0,tail_ticks=0;
integer ww,hh,ox,oy,ex,ey,x,y,fx,fy;
reg checking=0,done_seen=0,test_pass=0;
reg previous_output=0;
integer compression_test=0;
reg [31:0] expected;
reg [10:0] ack_delay=0;
reg ack_r=0;
assign ack=ack_r;
always @(posedge clk) begin
    if(rst) begin ack_r<=0; ack_delay<=0; end
    else if(req && !ack_r) begin
        if(ack_delay==300) ack_r<=1;
        else ack_delay<=ack_delay+1;
    end else if(!req) begin ack_r<=0; ack_delay<=0; end
end
bmp_read u_bmp(
 .clk(clk),.rst(rst),.ready(ready),.scan_start(1'b0),
 .scan_start_sector(32'd0),.scan_max_sector(32'd100000),.scan_target_count(3'd4),
 .scan_done(),.scan_found_valid(),.scan_found_sector(),.scan_found_signature(),.scan_found_total(),
 .load_start(load_start),.load_sector(32'd0),.load_done(load_done),.load_error(load_error),
 .load_error_code(),.load_error_retries(),.load_error_sector(),.load_error_signature(),
 .sd_init_done(1'b1),.state_code(),.bmp_width(16'd640),.bmp_height(16'd480),
 .write_req(req),.write_req_ack(ack),.sd_sec_read(read_req),.sd_sec_read_addr(read_addr),
 .sd_sec_read_data(sd_byte),.sd_sec_read_data_valid(sd_valid),.sd_sec_read_end(sd_end),
 .bmp_data_wr_en(px_valid),.bmp_data(px),.src_w(sw),.src_h(sh),.src_accept(px_ready));
scale_on_load #(.VIEW_W(480),.VIEW_H(360)) u_scale(
 .clk(clk),.rst(rst),.load_start(req),.mode(mode),.interpolation(interpolation),.src_w(sw),.src_h(sh),
 .src_px_valid(px_valid),.src_px(px),.src_accept(px_ready),.source_done(load_done),
 .fifo_usedw((req || ack) ? 9'd511 : usedw),.tgt_px_valid(out_valid),.tgt_px(out_px),.busy(busy),
 .cfg_error(error),.frame_done(done));
function automatic [23:0] colour(input integer xx,yy);
 colour={8'(xx),8'(yy),8'(xx+yy)};
endfunction
function automatic [23:0] interpolated(input integer xx,yy,rx,ry,denx,deny);
 integer x1,y1,ax,ay,c,a,b,d,e,v;
 reg [23:0] z;
 begin
 x1=xx+1<iw ? xx+1 : xx; y1=yy+1<ih ? yy+1 : yy;
 ax=rx*256/denx;ay=ry*256/deny;z=0;
 for(c=0;c<3;c=c+1) begin
   a=(colour(xx,yy)>>(8*c))&255;b=(colour(x1,yy)>>(8*c))&255;
   d=(colour(xx,y1)>>(8*c))&255;e=(colour(x1,y1)>>(8*c))&255;
   v=(a*(256-ax)*(256-ay)+b*ax*(256-ay)+d*(256-ax)*ay+e*ax*ay+32768)/65536;
   z=z|(v<<(8*c));
 end
 interpolated=z;
 end
endfunction
function automatic [7:0] file_byte(input integer addr);
 integer stride,len,k,row,col,c,v;
 begin
 stride=(iw*3+3)&~3; len=54+stride*ih; file_byte=0;
 if(addr==0) file_byte="B";
 else if(addr==1) file_byte="M";
 else if(addr>=2 && addr<=5) file_byte=(len>>((addr-2)*8))&255;
 else if(addr==10) file_byte=54;
 else if(addr==14) file_byte=40;
 else if(addr>=18 && addr<=21) file_byte=(iw>>((addr-18)*8))&255;
 else if(addr>=22 && addr<=25) file_byte=(ih>>((addr-22)*8))&255;
 else if(addr==26) file_byte=1;
 else if(addr==28) file_byte=24;
 else if(addr==30) file_byte=compression_test;
 else if(addr>=54 && addr<len) begin
   k=addr-54; row=ih-1-k/stride; col=(k%stride)/3; c=(k%stride)%3;
   if(k%stride>=iw*3) file_byte=8'ha5;
   else begin v=colour(col,row); file_byte=(v>>(8*c))&255; end
 end
 end
endfunction
integer pos=0,base=0;
reg active=0,wait_low=0;
always @(posedge clk) begin
    sd_valid<=0; sd_end<=0;
    if(rst) begin active<=0; wait_low<=0; pos<=0; end
    else if(wait_low) begin if(!read_req) wait_low<=0; end
    else if(!active) begin
        if(read_req) begin active<=1; pos<=0; base<=read_addr*512; end
    end else if(pos==512) begin sd_end<=1; active<=0; wait_low<=1; end
    else if(tick%7!=0) begin
        sd_byte<=file_byte(base+pos); sd_valid<=1; pos<=pos+1;
    end
end
always @(posedge clk) begin
 if(rst) previous_output<=0;
 else begin
   if(checking && out_valid && previous_output) $fatal(1,"output cadence exceeds one pixel per two clocks");
   previous_output<=out_valid;
 end
 tick<=tick+1;
 // Model a FIFO which temporarily cannot accept writes, including black borders.
 usedw <= (tick%997<111) ? 9'd400 : 9'd0;
 if(checking && !rst) begin
   if(load_error || error) $fatal(1,"unexpected configuration/load error");
   if(px_valid && px_ready) begin
     ex=src_count%iw; ey=ih-1-src_count/iw;
     if(px!==colour(ex,ey)) $fatal(1,"BMP pixel mismatch %0dx%0d idx=%0d got=%h",iw,ih,src_count,px);
     src_count=src_count+1;
   end
   if(out_valid) begin
     if(req || ack) $fatal(1,"pixel written during writer FIFO clear handshake");
     if(got>=640*480) $fatal(1,"extra target pixels after frame");
     x=got%640; y=479-got/640; fx=x-ox; fy=y-oy;
     expected=0;
     if(x<480 && y<360 && fx>=0 && fy>=0 && fx<ww && fy<hh) begin
       ex=fx*iw/ww; ey=fy*ih/hh;
       expected={colour(ex,ey),8'd0};
       if(interpolation) expected={interpolated(ex,ey,(fx*iw)%ww,(fy*ih)%hh,ww,hh),8'd0};
     end
     if(out_px!==expected) $fatal(1,"target mismatch src=%0dx%0d mode=%0d xy=%0d,%0d got=%h expected=%h",iw,ih,im,x,y,out_px,expected);
     got=got+1;
   end
   if(done) begin
      if(done_seen || got!=307200 || src_count!=iw*ih)
         $fatal(1,"bad completion count out=%0d src=%0d expected_src=%0d",got,src_count,iw*ih);
      done_seen=1;
   end
 end
end
task automatic run_case(input integer width,height,md);
 integer timeout;
 begin
 checking=0; rst=(cases==0 || cases%5==0); repeat(5) @(negedge clk);
 iw=width; ih=height; im=md; mode=md;
 ww=iw; hh=ih;
 if(md!=0) begin
   if((iw*360<=ih*480 && md==1) || (iw*360>ih*480 && md==2)) begin
      hh=360; ww=iw*360/ih;
   end else begin ww=480; hh=ih*480/iw; end
 end
 if(ww<1) ww=1; if(hh<1) hh=1;
 ox=(480-ww)>>>1; oy=(360-hh)>>>1;
 got=0; src_count=0; done_seen=0; checking=1; rst=0;
 repeat(4) @(negedge clk); load_start=1;
 @(negedge clk); load_start=0;
 timeout=0;
 while(!done_seen && timeout<40000000) begin @(negedge clk); timeout=timeout+1; end
 if(!done_seen) $fatal(1,"timeout src=%0dx%0d mode=%0d state=%0d bmp=%0d got=%0d src=%0d need=%0d",iw,ih,md,u_scale.state,u_bmp.state,got,src_count,u_scale.needed);
 repeat(1000) @(negedge clk);
 if(busy || !ready) $fatal(1,"not idle after completion");
 cases=cases+1;
 $display("PASS src=%0dx%0d mode=%0d algorithm=%0d target=%0d source=%0d cycles=%0d",iw,ih,md,interpolation,got,src_count,timeout);
 checking=0;
 end
endtask
task automatic reject_case(input integer width,height,compression_value);
 integer t;
 begin
 checking=0; rst=1; repeat(5) @(negedge clk);
 iw=width; ih=height; compression_test=compression_value; rst=0;
 repeat(4) @(negedge clk); load_start=1;
 @(negedge clk); load_start=0;
 t=0;
 while(!load_error && t<10000) begin
   @(negedge clk); t=t+1;
   if(req || px_valid || out_valid) $fatal(1,"invalid BMP emitted a transaction");
 end
 if(!load_error) $fatal(1,"invalid BMP did not terminate");
 $display("PASS rejected BMP width=%0d height=%0d compression=%0d",iw,ih,compression_test);
 compression_test=0;
 end
endtask
integer md,algorithm;
initial begin
 for(algorithm=0;algorithm<2;algorithm=algorithm+1)begin interpolation=algorithm;
 for(md=0;md<3;md=md+1)begin run_case(321,241,md);run_case(241,361,md);end end
 reject_case(0,240,0); reject_case(1025,480,0);
 reject_case(640,-480,0); reject_case(640,480,1);
 $display("RESULT PASS cases=%0d checked_target_pixels=%0d rejected=4",cases,cases*307200);
 test_pass=1;
 $finish;
end
endmodule
