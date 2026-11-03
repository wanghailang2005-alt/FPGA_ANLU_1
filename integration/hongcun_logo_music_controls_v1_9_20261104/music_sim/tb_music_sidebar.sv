`timescale 1ns/1ps
module tb_music_sidebar;
 reg clk=0,rst=1,paused=0,track=0;reg [3:0] volume=5,sw=9;
 reg [9:0] x=0;reg [8:0] y=0;
 wire valid,pixel;wire [23:0] color;
 always #20 clk=~clk;
 ui_sidebar dut(.clk(clk),.rst(rst),.frame_tick(1'b0),.enable(1'b1),
 .music_track(track),.music_paused(paused),.music_volume(volume),.x(x),.y(y),.de(1'b1),
 .image_valid(1'b1),.auto_play(1'b0),.image_index(3'd0),.scale_mode(2'd0),
 .interpolation(1'b0),.transition_mode(3'd0),.sw_code(sw),.brightness(4'd5),.contrast(4'd5),
 .setting_value(4'd1),.valid(valid),.pixel(pixel),.color(color));
 reg [15:0] font[0:2047];
 reg expected_valid=0,expected_pixel=0;reg [23:0] expected_color=0;
 reg current_valid,current_pixel;reg [23:0] current_color;
 integer gid,column,row,checks=0;
 function integer glyph(input integer row,input integer col);
 begin
  glyph=0;
  case(row)
  18:case(col)
   0:glyph=83;1:glyph=119;3:glyph=volume==10 ? 97:96;
   4:glyph=volume==10 ? 96:96+volume;5:glyph=107;6:glyph=97;7:glyph=96;
  endcase
  19:case(col)0:glyph=paused ? 120:14;1:glyph=paused ? 121:24;endcase
  20:case(col)0:glyph=83;1:glyph=84;3:glyph=96;4:glyph=track ? 98:97;5:glyph=107;6:glyph=96;7:glyph=98;endcase
  endcase
 end endfunction
 always @(posedge clk)begin
  column=(x-488)/16;row=y/16;
  current_valid=!rst && x>=488 && x<632 && row>=18 && row<=20;
  gid=glyph(row,column);
  current_pixel=current_valid && font[gid*16+(y%16)][15-((x-488)%16)];
  current_color=row==18 ? 24'h39b9c8:row==19 ? (paused ? 24'hf0b867:24'h39b9c8):24'hdce5ee;
  #1;
  if(!rst && checks>2)begin
   if(valid!==expected_valid || pixel!==(expected_valid && expected_pixel))
    $fatal(1,"sidebar raster mismatch x %0d y %0d",x,y);
   if(valid && color!==expected_color)$fatal(1,"sidebar color mismatch");
  end
  expected_valid=current_valid;expected_pixel=current_pixel;expected_color=current_color;checks=checks+1;
 end
 integer test_pass=0,v,p,t,xx,yy,file_out;
 reg [23:0] preview[0:6911];integer previous_index=-1,current_index;
 task scan(input integer capture);
 begin
  previous_index=-1;
  for(yy=288;yy<336;yy=yy+1)for(xx=488;xx<632;xx=xx+1)begin
   @(negedge clk);x=xx;y=yy;current_index=(yy-288)*144+xx-488;
   @(posedge clk);#2;
   if(capture && previous_index>=0)preview[previous_index]=valid && pixel ? color:24'h091426;
   previous_index=current_index;
  end
  @(negedge clk);x=0;y=0;@(posedge clk);#2;
  if(capture)preview[previous_index]=valid && pixel ? color:24'h091426;
 end endtask
 task dump(input string name);
 integer n;begin
  file_out=$fopen(name,"w");$fdisplay(file_out,"P3\n144 48\n255");
  for(n=0;n<6912;n=n+1)$fdisplay(file_out,"%0d %0d %0d",preview[n][23:16],preview[n][15:8],preview[n][7:0]);
  $fclose(file_out);
 end endtask
 initial begin
  $readmemh("../audio_controls_evidence/sidebar_font.hex",font);
  repeat(4)@(negedge clk);rst=0;
  for(v=1;v<=10;v=v+1)for(p=0;p<=1;p=p+1)for(t=0;t<=1;t=t+1)begin
   @(negedge clk);volume=v;paused=p;track=t;
   scan(1);
   if(v==5 && p==0 && t==0)dump("../audio_controls_evidence/playing_05.ppm");
   if(v==10 && p==1 && t==1)dump("../audio_controls_evidence/paused_10.ppm");
  end
  $display("PASS sidebar: 40 music states, 10 volume levels, pause/play/track glyphs, two-stage exact pixels and colors");
  test_pass=1;$finish;
 end
endmodule
