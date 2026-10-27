`timescale 1ns/1ps
module tb_integrated;
reg clk=0,rst=1,vs=0,de=0,req=0,commit=0;
reg [1:0] mode=0,duration=0;
reg [9:0] x=0;
reg [8:0] y=0;
wire [23:0] effect,over_rgb,ref_rgb;
wire ack,done,ode,rde;
reg test_passed=0;
integer checks=0, glyphs=0, i,m,d,n;
always #5 clk=~clk;
image_transition dut(.video_clk(clk),.rst(rst),.vs(vs),.de(de),.rgb_in(24'hc08040),
 .transition_mode(mode),.duration_sel(duration),.transition_req_toggle(req),
 .transition_commit_toggle(commit),.dark_ack_toggle(ack),.done_toggle(done),.rgb_out(effect));
osd_overlay #(.STATUS_MODE(1)) overlay(.clk(clk),.rst(rst),.enable(1'b1),
 .image_valid(1'b1),.image_index(2'd2),.auto_play(1'b1),.in_rgb(effect),
 .in_de(de),.in_hs(1'b0),.in_vs(vs),.in_x(x),.in_y(y),.out_rgb(over_rgb),.out_de(ode),
 .out_hs(),.out_vs(),.out_x(),.out_y());
osd_overlay #(.STATUS_MODE(1)) reference(.clk(clk),.rst(rst),.enable(1'b1),
 .image_valid(1'b1),.image_index(2'd2),.auto_play(1'b1),.in_rgb(24'hc08040),
 .in_de(de),.in_hs(1'b0),.in_vs(vs),.in_x(x),.in_y(y),.out_rgb(ref_rgb),.out_de(rde),
 .out_hs(),.out_vs(),.out_x(),.out_y());
reg [23:0] rgb_pipe[0:2];
reg [2:0] de_pipe=0;
always @(posedge clk) begin
 if(rst) begin de_pipe=0; rgb_pipe[0]=0;rgb_pipe[1]=0;rgb_pipe[2]=0;end
 else begin
  rgb_pipe[2]=rgb_pipe[1];rgb_pipe[1]=rgb_pipe[0];rgb_pipe[0]=effect;
  de_pipe={de_pipe[1:0],de};
  #1;
  if(ode!==de_pipe[2] || ode!==rde) $fatal(1,"DE alignment");
  if(ode) begin
   if(ref_rgb==0) begin
    if(over_rgb!==0) $fatal(1,"OSD glyph affected by transition");
    glyphs=glyphs+1;
   end else if(over_rgb!==rgb_pipe[2]) $fatal(1,"background pixel mismatch");
   checks=checks+1;
  end
  if(overlay.scroll_phase!==reference.scroll_phase) $fatal(1,"scroll interrupted");
 end
end
task tick;
 begin
 @(negedge clk);de=0;vs=1;repeat(10) @(negedge clk);
 vs=0;repeat(10) @(negedge clk);
 end
endtask
task line(input integer yy);
 integer xx;
 begin
 @(negedge clk);y=yy;
 for(xx=0;xx<640;xx=xx+1) begin de=1;x=xx;@(negedge clk);end
 de=0;repeat(8) @(negedge clk);
 end
endtask
initial begin
 repeat(4) @(negedge clk);rst=0;
 repeat(10) @(negedge clk);
 for(m=0;m<3;m=m+1) for(d=0;d<3;d=d+1) begin
  mode=m;duration=d;repeat(10) @(negedge clk);
  req=~req;repeat(10) @(negedge clk);
  n=(m==0)?1:((d==0)?15:((d==1)?30:60));
  for(i=0;i<n;i=i+1) begin
   tick();line(20);line(452);
   if(i<n-1 && ack===req) $fatal(1,"early dark ACK");
  end
  if(ack!==req) $fatal(1,"missing dark ACK mode=%0d",m);
  @(negedge clk);de=1;#1;
  if(m!=0 && effect!==0) $fatal(1,"not black before commit");
  @(negedge clk);de=0;
  // Simulate delayed real frame selection: remain dark until generation arrives.
  repeat(3) tick();
  commit=~commit;repeat(12) @(negedge clk);
  if(m!=0 && done===commit) $fatal(1,"early completion");
  for(i=0;i<n;i=i+1) begin
   tick();line(20);line(452);
   if(m!=0 && i<n-1 && done===commit) $fatal(1,"early done");
  end
  if(done!==commit) $fatal(1,"missing done");
  @(negedge clk);de=1;#1;if(effect!==24'hc08040) $fatal(1,"final RGB");
  @(negedge clk);de=0;
 end
 rst=1;repeat(4) @(negedge clk);rst=0;repeat(6) @(negedge clk);
 if(ack!==0 || done!==0) $fatal(1,"reset handshake");
 test_passed=1;$display("SIM PASS modes=3 durations=3 pixels=%0d preserved_glyphs=%0d",checks,glyphs);$finish;
end
initial begin #50000000;$fatal(1,"timeout");end
endmodule
