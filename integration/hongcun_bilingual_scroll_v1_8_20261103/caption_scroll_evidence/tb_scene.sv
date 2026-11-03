`timescale 1ns/1ps
// Integration of the actual OSD, audio receiver/FFT, spectrum and AXIS RTL.
// Actual guide BMP used as stimulus; output is RTL simulation, not board capture.
module tb_scene;
 reg clk=0,mclk=0,rst=1,frame_tick=0;
 always #20 clk=~clk;
 always #40.667 mclk=~mclk;
 wire bclk,lrck,dout,audio_valid;
 wire [23:0] audio_left,audio_right;
 hdmi_audio_tone_i2s_64fs #(.NOTE_HOLD_FRAMES(2400)) tone(
  .I_mclk(mclk),.I_rst(rst),.O_i2s_BCLK(bclk),.O_i2s_LRCK(lrck),.O_i2s_DOUT(dout));
 I2S_receiver receiver(.I_clk(clk),.I_rst(rst),.I_i2s_BCLK(bclk),.I_i2s_LRCK(lrck),
  .I_i2s_DOUT(dout),.O_audio_valid(audio_valid),.O_audio_left_data(audio_left),.O_audio_right_data(audio_right));
 reg [3:0] sw_request=0;
 reg [2:0] image_request=0,image_index=0;
 reg audio_mode_frame=0;
 always @(posedge clk or posedge rst) begin
  if(rst) begin audio_mode_frame<=0;image_index<=0;end
  else if(frame_tick) begin
   audio_mode_frame<=sw_request==4'h9;
   image_index<=image_request;
  end
 end
 reg [23:0] in_rgb=0;
 reg in_de=0,in_hs=1,in_vs=1;
 reg [9:0] in_x=0;
 reg [8:0] in_y=0;
 wire [23:0] osd_rgb,out_rgb;
 wire osd_de,osd_hs,osd_vs,out_de,out_hs,out_vs;
 wire [9:0] osd_x,out_x;
 wire [8:0] osd_y,out_y;
 osd_overlay #(.STATUS_MODE(1)) osd (
  .clk(clk),.rst(rst),.enable(1'b1),.compact_layout(1'b1),.scale_mode(2'd1),.interpolation(1'b1),.transition_mode(3'd1),
  .image_valid(1'b1),.image_index(image_index),.auto_play(1'b1),
  .sw_code(sw_request),.setting_value(4'd5),.brightness(4'd5),.contrast(4'd5),
  .sub_mode(2'd3),.text_mode(2'd3),.scroll_speed(2'd2),.scroll_dir(1'b0),
  .in_rgb(in_rgb),.in_de(in_de),.in_hs(in_hs),.in_vs(in_vs),.in_x(in_x),.in_y(in_y),
  .out_rgb(osd_rgb),.out_de(osd_de),.out_hs(osd_hs),.out_vs(osd_vs),.out_x(osd_x),.out_y(osd_y));
 audio_spectrum_overlay spectrum (
  .clk(clk),.rst(rst),.frame_tick(frame_tick),.enable(1'b1),
  .audio_valid(audio_valid),.audio_left(audio_left),.audio_right(audio_right),
  .in_rgb(osd_rgb),.in_de(osd_de),.in_hs(osd_hs),.in_vs(osd_vs),.in_x(osd_x),.in_y(osd_y),
  .out_rgb(out_rgb),.out_de(out_de),.out_hs(out_hs),.out_vs(out_vs),.out_x(out_x),.out_y(out_y));
 wire axis_valid,axis_user,axis_last;
 wire [23:0] axis_data;
 video_rgb_to_axis_640x480 axis_adapter(.I_clk(clk),.I_rst(rst),.I_vs(out_vs),.I_de(out_de),.I_rgb(out_rgb),
  .O_video_user(axis_user),.O_video_valid(axis_valid),.O_video_last(axis_last),.O_video_data(axis_data));

 reg [23:0] guide_pixels[0:172799];
 initial $readmemh("guide_pixels.hex",guide_pixels);
 function [23:0] background(input integer px,input integer py,input integer photo);
 begin
 if(px<480 && py<360)background=guide_pixels[py*480+px];
 else background=24'h000000;
 end
 endfunction

 reg [45:0] pipe[0:5];integer tags[0:5];
 integer frame_no=-1,f,x,y,k,ppm,pixels=0,axis_pixels=0,sof=0,eol=0;
 integer zh=0,en=0,bars=0,side=0;reg test_pass=0;
 reg axis_de_before;reg [23:0] axis_rgb_before;reg [9:0] axis_x_before;reg [8:0] axis_y_before;
 initial begin
 for(k=0;k<6;k=k+1)begin pipe[k]=0;tags[k]=-1;end
 ppm=$fopen("ui_preview.ppm","wb");$fwrite(ppm,"P6\n640 480\n255\n");
 repeat(8)@(negedge clk);rst=0;sw_request=8;
 for(f=0;f<5;f=f+1)begin
 for(y=0;y<525;y=y+1)for(x=0;x<800;x=x+1)begin
 @(negedge clk);frame_no=f;
 in_de=x<640 && y<480;in_hs=!(x>=656 && x<752);in_vs=!(y>=490 && y<492);
 in_x=x<640 ? x:0;in_y=y<480 ? y:0;in_rgb=background(x,y,image_index);
 frame_tick=y==500 && x==0;
 end end
 @(negedge clk);in_de=0;frame_no=-1;repeat(10)@(negedge clk);$fclose(ppm);
 if(pixels!=5*307200 || axis_pixels!=pixels || sof!=5 || eol!=5*480)$fatal(1,"video counts");
 if(zh<100 || en<100 || bars<10 || side<100)$fatal(1,"missing content zh=%d en=%d bars=%d side=%d",zh,en,bars,side);
 if(spectrum.analysis.fft_frames<4 || spectrum.analysis.overflow)$fatal(1,"audio analysis failed");
 $display("RESULT PASS ui frames=5 pixels=%0d SOF=%0d EOL=%0d zh=%0d en=%0d bars=%0d sidebar=%0d",pixels,sof,eol,zh,en,bars,side);
 test_pass=1;$finish;end
 always @(posedge clk)if(!rst)begin
 axis_de_before=out_de;axis_rgb_before=out_rgb;axis_x_before=out_x;axis_y_before=out_y;
 for(integer q=5;q>0;q=q-1)begin pipe[q]=pipe[q-1];tags[q]=tags[q-1];end
 pipe[0]={in_de,in_hs,in_vs,in_x,in_y,in_rgb};tags[0]=frame_no;#1;
 if({out_de,out_hs,out_vs,out_x,out_y}!==pipe[5][45:24])$fatal(1,"six-cycle video misalignment");
 if(out_de)begin pixels=pixels+1;if($isunknown(out_rgb))$fatal(1,"unknown RGB");
 if(out_x<480 && out_y<360 && out_rgb!==pipe[5][23:0])$fatal(1,"main photo modified");
 if(out_y>=416 && out_rgb!=0 && out_rgb!=24'hf2f4f6 && out_rgb!=24'ha8b3c0)$fatal(1,"subtitle background leakage");
 if(tags[5]==4)begin
 $fwrite(ppm,"%c%c%c",out_rgb[23:16],out_rgb[15:8],out_rgb[7:0]);
 if(out_y>=432 && out_y<448 && out_rgb==24'hf2f4f6)zh=zh+1;
 if(out_y>=456 && out_y<472 && out_rgb==24'ha8b3c0)en=en+1;
 if(out_y>=360 && out_y<416 && (out_rgb==24'h286474 || out_rgb==24'h82c4c7))bars=bars+1;
 if(out_x>=480 && out_y<360 && out_rgb==24'hdce5ee)side=side+1;
 end end
 if(axis_valid)begin axis_pixels=axis_pixels+1;
 if(!axis_de_before || axis_data!==axis_rgb_before)$fatal(1,"AXIS pixel alignment");
 if(axis_user)begin sof=sof+1;if(axis_x_before!=0 || axis_y_before!=0)$fatal(1,"SOF position");end
 if(axis_last)begin eol=eol+1;if(axis_x_before!=639)$fatal(1,"EOL position");end end
 end
 endmodule
