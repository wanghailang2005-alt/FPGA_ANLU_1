`timescale 1ns/1ps
module tb_visualizer;
 reg clk=0,mclk=0,rst=1,frame_tick=0,enable_request=0;
 always #20 clk=~clk;
 always #40.667 mclk=~mclk;
 wire bclk,lrck,dout,audio_valid;
 wire [23:0] audio_left,audio_right;
 hdmi_audio_tone_i2s_64fs #(.NOTE_HOLD_FRAMES(2400)) tone(
  .I_mclk(mclk),.I_rst(rst),.O_i2s_BCLK(bclk),.O_i2s_LRCK(lrck),.O_i2s_DOUT(dout));
 I2S_receiver receiver(.I_clk(clk),.I_rst(rst),.I_i2s_BCLK(bclk),.I_i2s_LRCK(lrck),
  .I_i2s_DOUT(dout),.O_audio_valid(audio_valid),.O_audio_left_data(audio_left),.O_audio_right_data(audio_right));
 reg [23:0] in_rgb=0;
 reg in_de=0,in_hs=1,in_vs=1;
 reg [9:0] in_x=0;
 reg [8:0] in_y=0;
 wire [23:0] out_rgb;
 wire out_de,out_hs,out_vs;
 wire [9:0] out_x;
 wire [8:0] out_y;
 audio_visualizer_overlay dut(.*);
 wire [255:0] bars,peaks;
 genvar dg;
 generate for(dg=0;dg<32;dg=dg+1) begin:observe
  assign bars[dg*8+:8]=dut.analysis.display_ready ? dut.analysis.display_mem[dg][7:0]:8'd0;
  assign peaks[dg*8+:8]=dut.analysis.display_ready ? dut.analysis.display_mem[dg][15:8]:8'd0;
 end endgenerate
 wire axis_valid,axis_user,axis_last;
 wire [23:0] axis_data;
 video_rgb_to_axis_640x480 axis_adapter(.I_clk(clk),.I_rst(rst),.I_vs(out_vs),.I_de(out_de),.I_rgb(out_rgb),
  .O_video_user(axis_user),.O_video_valid(axis_valid),.O_video_last(axis_last),.O_video_data(axis_data));
 reg [46:0] expected[0:2];
 integer tag[0:2];
 integer frame_no=-1,f,x,y,ppm,pixels=0,axis_pixels=0,sof=0,eol=0;
 integer screenshot_pixels=0,cyan_pixels=0,green_pixels=0,audio_samples=0,k;
 integer max_fifo=0;
 integer check_band,check_depth,check_height,check_peak,check_wave0,check_wave1;
 reg [23:0] check_color;
 reg test_pass=0;
 reg [23:0] axis_rgb_before;
 reg axis_de_before,axis_enabled_before;
 reg [9:0] axis_x_before;
 reg [8:0] axis_y_before;
 reg [255:0] previous_bars=0,previous_peaks=0;
 reg previous_wave_bank=0,frame_tick_before;
 initial begin
  for(k=0;k<3;k=k+1) begin expected[k]=0;tag[k]=-1;end
  ppm=$fopen("visualizer.ppm","wb");$fwrite(ppm,"P6\n640 480\n255\n");
  repeat(8) @(negedge clk);rst=0;
  for(f=0;f<8;f=f+1) begin
   for(y=0;y<525;y=y+1) begin
    for(x=0;x<800;x=x+1) begin
     @(negedge clk);
     frame_no=f;
     in_de=x<640 && y<480;in_hs=!(x>=656 && x<752);in_vs=!(y>=490 && y<492);
     in_x=x<640 ? x:0;in_y=y<480 ? y:0;
     in_rgb={8'(30+(x>>3)),8'(50+(y>>3)),8'(90+((x+y)>>4))};
     frame_tick=y==500 && x==0;
     // User changes switch in active video; effect must wait for vblank.
     if(f==0 && y==100 && x==100) enable_request=1;
     if(f==4 && y==100 && x==100) enable_request=0;
     if(f==5 && y==100 && x==100) enable_request=1;
    end
   end
  end
  @(negedge clk);in_de=0;frame_tick=0;frame_no=-1;
  repeat(8) @(negedge clk);
  $fclose(ppm);
  if(pixels!=8*640*480 || axis_pixels!=pixels || sof!=8 || eol!=8*480) $fatal(1,"video counts %0d %0d %0d %0d",pixels,axis_pixels,sof,eol);
  if(screenshot_pixels!=640*480 || cyan_pixels<100 || green_pixels<100) $fatal(1,"rendered content missing");
  if(audio_samples<6000 || dut.analysis.fft_frames<10 || dut.analysis.overflow) $fatal(1,"audio analysis did not run");
  $display("RESULT PASS visualizer frames=8 pixels=%0d axis_pixels=%0d sof=%0d eol=%0d fft_frames=%0d audio_samples=%0d max_fifo=%0d cyan=%0d green=%0d",pixels,axis_pixels,sof,eol,dut.analysis.fft_frames,audio_samples,max_fifo,cyan_pixels,green_pixels);
  test_pass=1;$finish;
 end
 always @(posedge clk) begin
  if(!rst) begin
   axis_rgb_before=out_rgb;axis_de_before=out_de;axis_x_before=out_x;axis_y_before=out_y;
   axis_enabled_before=dut.enabled;frame_tick_before=frame_tick;
   expected[2]=expected[1];expected[1]=expected[0];
   expected[0]={dut.enabled,in_de,in_hs,in_vs,in_x,in_y,in_rgb};
   tag[2]=tag[1];tag[1]=tag[0];tag[0]=frame_no;
   #1;
   if({out_de,out_hs,out_vs,out_x,out_y}!==expected[2][45:24]) $fatal(1,"three-stage coordinate/control alignment");
   if(out_de) begin
    pixels=pixels+1;
    if($isunknown(out_rgb)) $fatal(1,"unknown active RGB x=%0d y=%0d",out_x,out_y);
    if(!expected[2][46] && out_rgb!==expected[2][23:0]) $fatal(1,"bypass pixel mismatch");
    // Check synchronous display RAM read alignment at every band boundary.
    if(expected[2][46] && out_x>=32 && out_x<544 && out_y>=256 && out_y<=423 &&
       ((out_x-32)%16)>=2 && ((out_x-32)%16)<=13) begin
     check_band=(out_x-32)/16;check_depth=423-out_y;
     check_height=dut.analysis.display_mem[check_band][7:0];
     check_peak=dut.analysis.display_mem[check_band][15:8];
     check_color=out_y<304 ? 24'hff533d:(out_y<352 ? 24'hffd43b:24'h26e65a);
     if(check_peak!=0 && check_depth==check_peak) begin
      if(out_rgb!==24'hf0ffff) $fatal(1,"peak pixel alignment");
     end else if(check_depth<check_height && out_y%8!=7 && out_rgb!==check_color)
      $fatal(1,"bar pixel alignment x=%0d y=%0d",out_x,out_y);
    end
    if(expected[2][46] && dut.analysis.wave_ready && out_x>=32 && out_x<544 && out_y>=112 && out_y<=208) begin
     check_wave0=dut.analysis.wave_mem[{dut.analysis.wave_bank,9'(out_x-32)}];
     check_wave1=out_x==32 ? check_wave0:dut.analysis.wave_mem[{dut.analysis.wave_bank,9'(out_x-33)}];
     if(out_y>=(check_wave0<check_wave1 ? check_wave0:check_wave1) &&
        out_y<=(check_wave0>check_wave1 ? check_wave0:check_wave1) && out_rgb!==24'h38e8ff)
      $fatal(1,"waveform pixel alignment");
    end
    if(tag[2]==3) begin
     $fwrite(ppm,"%c%c%c",out_rgb[23:16],out_rgb[15:8],out_rgb[7:0]);
     screenshot_pixels=screenshot_pixels+1;
     if(out_rgb==24'h38e8ff) cyan_pixels=cyan_pixels+1;
     if(out_rgb==24'h26e65a) green_pixels=green_pixels+1;
    end
   end
   if(axis_valid!==axis_de_before || axis_data!==axis_rgb_before) $fatal(1,"AXIS payload alignment");
   if(axis_valid) begin
    axis_pixels=axis_pixels+1;
    if(axis_last!==(axis_x_before==639)) $fatal(1,"AXIS LAST alignment");
    if(axis_user!==(axis_x_before==0 && axis_y_before==0)) $fatal(1,"AXIS USER alignment");
    if(axis_last) eol=eol+1;
    if(axis_user) sof=sof+1;
   end
   if(dut.enabled!=axis_enabled_before && !frame_tick_before) $fatal(1,"mid-frame enable change");
   if(bars[7:0]>160) $fatal(1,"bar overflow");
   if(in_de && (bars!==previous_bars || peaks!==previous_peaks))
    $fatal(1,"spectrum changed in active video");
   if(!frame_tick_before && dut.analysis.wave_bank!=previous_wave_bank)
    $fatal(1,"waveform changed outside frame commit");
   previous_bars=bars;previous_peaks=peaks;previous_wave_bank=dut.analysis.wave_bank;
   if(dut.analysis.overflow) $fatal(1,"audio FIFO overflow");
   if(dut.analysis.fft.fifo_count>max_fifo) max_fifo=dut.analysis.fft.fifo_count;
   if(audio_valid) audio_samples=audio_samples+1;
  end
 end
 initial begin #180000000;$fatal(1,"visualizer watchdog");end
endmodule
