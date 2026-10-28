`timescale 1ns/1ps
module tb_display;
reg clk=0,rst=1,de=0,hs=1,vs=1,select_pattern=0;
always #5 clk=~clk;
wire [23:0] posrgb,pattern,output_rgb;
wire pde,phs,pvs,pvalid,ode;
wire [9:0] px,ox;
wire [8:0] py,oy;
wire [7:0] health;
reg test_pass=0;
integer checks=0,glyphs=0,banner=0,xx,yy,frame;
reg [23:0] expected;
osd_video_position position(.clk(clk),.rst(rst),.in_rgb(24'h806040),.in_de(de),.in_hs(hs),.in_vs(vs),
 .out_rgb(posrgb),.out_de(pde),.out_hs(phs),.out_vs(pvs),.out_x(px),.out_y(py),.position_valid(pvalid),.frame_tick());
zoom_diagnostics diagnostic(.clk(clk),.rst(rst),.select_pattern(select_pattern),.de(pde),.hs(phs),.vs(pvs),
 .position_valid(pvalid),.x(px),.y(py),.rgb(posrgb),.read_health(2'b00),.rgb_out(pattern),.health(health));
osd_overlay #(.STATUS_MODE(1)) overlay(.clk(clk),.rst(rst),.enable(pvalid),.image_valid(1'b1),
 .image_index(2'd0),.auto_play(1'b0),.in_rgb(pattern),.in_de(pde),.in_hs(phs),.in_vs(pvs),
 .in_x(px),.in_y(py),.out_rgb(output_rgb),.out_de(ode),.out_hs(),.out_vs(),.out_x(ox),.out_y(oy));
always @(posedge clk) begin
 #1;
 if(!rst && ode && checks>=0) begin
  expected=select_pattern ? ((ox[5]^oy[5]) ? 24'he0e0a0 : 24'hffffff) : 24'h806040;
  if(output_rgb==0) begin
    if(oy>=448 && oy<464) banner=banner+1;
    else glyphs=glyphs+1;
  end else if(output_rgb!==expected) $fatal(1,"display payload/coordinate mismatch xy=%0d,%0d",ox,oy);
  checks=checks+1;
 end
end
initial begin
 repeat(5) @(negedge clk);rst=0;
 // Enough frames for the default offscreen banner to enter the active area.
 for(frame=0;frame<12;frame=frame+1) begin
  repeat(10) @(negedge clk);vs=0;repeat(10) @(negedge clk);vs=1;repeat(10) @(negedge clk);
  select_pattern=(frame>=6);
  for(yy=0;yy<480;yy=yy+1) begin
   hs=0;repeat(4) @(negedge clk);hs=1;
   for(xx=0;xx<640;xx=xx+1) begin de=1;@(negedge clk);end
   de=0;repeat(12) @(negedge clk);
  end
 end
 repeat(20) @(negedge clk);
 if(health[3:0]!=15 || glyphs<100 || banner==0) $fatal(1,"missing health/text/banner flags=%h glyph=%0d banner=%0d",health,glyphs,banner);
 test_pass=1;$display("RESULT PASS position/diagnostic pattern/OSD/banner pixels=%0d glyphs=%0d banner=%0d",checks,glyphs,banner);$finish;
end
endmodule
