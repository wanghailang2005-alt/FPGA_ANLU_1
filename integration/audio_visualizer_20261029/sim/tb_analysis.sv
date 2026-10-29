`timescale 1ns/1ps
module tb_analysis;
 reg clk=0,rst=1,frame_tick=0,audio_valid=0;
 reg [23:0] audio_left=0,audio_right=0;
 reg [8:0] wave_address=0;
 reg [4:0] band_address=0;
 wire [7:0] bar_height,peak_height;
 wire [7:0] wave_y,level_left,level_right;
 wire [255:0] bar_heights,peak_heights;
 wire overflow;
 wire [15:0] fft_frames;
 always #20 clk=~clk;
 audio_visualizer dut(.*);
 genvar dg;
 generate for(dg=0;dg<32;dg=dg+1) begin:observe
  assign bar_heights[dg*8+:8]=dut.display_ready ? dut.display_mem[dg][7:0]:8'd0;
  assign peak_heights[dg*8+:8]=dut.display_ready ? dut.display_mem[dg][15:8]:8'd0;
 end endgenerate
 integer tick_count=0,i,v,largest,maxheight,actual_samples=0;
 integer expected_max[0:31],expected_height[0:31],edges[0:32];
 integer b,mag,exp2,frac,h,checked_frames=0;
 reg test_pass=0;
 // Accelerated display ticks exercise attack, hold, and decay without a GPU.
 always @(negedge clk) begin
  frame_tick=0;
  if(!rst) begin
   if(tick_count==11999) begin tick_count=0;frame_tick=1;end
   else tick_count=tick_count+1;
  end
 end
 task send(input integer l,input integer r);
  @(negedge clk);audio_valid=1;audio_left=l*256;audio_right=r*256;
  @(negedge clk);audio_valid=0;repeat(519) @(negedge clk);
 endtask
 initial begin
  for(i=0;i<17;i=i+1) edges[i]=i+1;
  edges[17]=18;edges[18]=20;edges[19]=23;edges[20]=27;edges[21]=32;
  edges[22]=38;edges[23]=45;edges[24]=54;edges[25]=64;edges[26]=76;
  edges[27]=90;edges[28]=107;edges[29]=128;edges[30]=152;edges[31]=181;edges[32]=256;
  for(i=0;i<32;i=i+1) begin expected_max[i]=0;expected_height[i]=0;end
  repeat(8) @(negedge clk);rst=0;
  for(i=0;i<2048;i=i+1) begin
   v=$rtoi(16000.0*$sin(6.283185307179586*12*i/512.0));send(v,v/2);
  end
  wait(fft_frames>=4);repeat(13000) @(negedge clk);
  maxheight=0;largest=0;
  for(i=0;i<32;i=i+1) if(dut.display_mem[i][7:0]>maxheight) begin largest=i;maxheight=dut.display_mem[i][7:0];end
  if(largest!=11 || maxheight<100) $fatal(1,"frequency-to-band mapping largest=%0d height=%0d",largest,maxheight);
  if(level_left<=level_right || level_right<30) $fatal(1,"stereo meters");
  // Opposite full-scale channel signs must cancel after a widened signed sum.
  for(i=0;i<1024;i=i+1) send(16000,-16000);
  if(level_left<100 || level_right<100) $fatal(1,"meters must observe stereo before mono cancellation");
  for(i=0;i<2048;i=i+1) send(0,0);
  wait(fft_frames>=10);
  repeat(2200000) @(negedge clk);
  for(i=0;i<32;i=i+1) if(dut.display_mem[i][15:0]!=0) $fatal(1,"silence decay band=%0d",i);
  if(level_left!=0 || level_right!=0 || overflow) $fatal(1,"silence/overflow");
  if(checked_frames<10) $fatal(1,"target reference was not exercised");
  // Extreme signed input and asynchronous reset during acquisition.
  send(-32768,-32768);repeat(10) @(negedge clk);
  rst=1;repeat(4) @(negedge clk);
  if(fft_frames!=0 || bar_heights!==0 || peak_heights!==0 || level_left!==0 || overflow) $fatal(1,"analysis reset");
  $display("RESULT PASS analysis checked_fft_frames=%0d frequency_band=11 stereo_meters mono_cancellation silence_decay reset",checked_frames);
  test_pass=1;$finish;
 end
 always @(negedge clk) if(!rst) begin
  if(overflow) $fatal(1,"overflow");
  if(dut.bin_valid && dut.bin_index!=0) begin
   b=0;
   while(b<31 && dut.bin_index>=edges[b+1]) b=b+1;
   mag=($signed(dut.bin_re)<0 ? -$signed(dut.bin_re):$signed(dut.bin_re));
   v=($signed(dut.bin_im)<0 ? -$signed(dut.bin_im):$signed(dut.bin_im));
   mag=mag>=v ? mag+(v/2):v+(mag/2);
   if(mag>expected_max[b]) expected_max[b]=mag;
  end
  if(dut.fft_done) begin
   // The final target write occurs on the following edge.
   for(integer j=0;j<32;j=j+1) begin
    mag=expected_max[j];h=0;
    if(mag>=4) begin
     exp2=0;while((1<<(exp2+1))<=mag) exp2=exp2+1;
     frac=(mag*8/(1<<exp2))-8;
     h=(exp2-2)*14+frac*2;if(h>160)h=160;
    end
    expected_height[j]=h;expected_max[j]=0;
   end
   @(negedge clk);
   for(integer j=0;j<32;j=j+1)
    if(dut.target_mem[{dut.target_published_bank,5'(j)}]!==8'(expected_height[j]))
     $fatal(1,"target reference frame=%0d band=%0d",checked_frames,j);
   checked_frames=checked_frames+1;
  end
 end
 initial begin #220000000;$fatal(1,"analysis watchdog");end
endmodule
