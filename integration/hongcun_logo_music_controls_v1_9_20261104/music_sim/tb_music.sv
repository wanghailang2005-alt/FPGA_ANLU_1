`timescale 1ns/1ps
module tb_music #(parameter REAL_PCM=0,CONTROLS_TEST=0);
 reg [15:0] reference_pcm[0:4095];
 initial if(REAL_PCM) $readmemh("real_pcm.hex",reference_pcm);
 reg sd=0,ac=0,vc=0,rst=1;
 always #5 sd=~sd;
 always #40.690104 ac=~ac;
 always #20 vc=~vc;
 reg [1:0] control=0;reg [4:0] playback=10;
 wire ar,ag,av,ae,irv,ire,pr;
 wire [31:0] aa,pa;
 reg ir=1;reg [31:0] ia=42;
 reg pv=0,pe=0;reg [7:0] pd=0;
 wire bclk,lrck,dout;wire [2:0] health;
 tf_music_player #(.TRACK_SECTORS(8)) dut(sd,ac,rst,control,1'b1,ar,aa,ag,av,ae,pd,bclk,lrck,dout,health,playback);
 sd_music_arbiter arb(sd,rst,ir,ia,irv,ire,ar,aa,ag,av,ae,pr,pa,pv,pe);
 wire valid;wire [23:0] left_pcm,right_pcm;
 I2S_receiver rx(vc,rst,bclk,lrck,dout,valid,left_pcm,right_pcm);
 integer image_sectors=0,audio_sectors=0,wraps=0,received=0;
 reg busy=0;integer count=0,delay_count=0;
 reg [31:0] address;
 reg [15:0] sample_value;
 // 3.125MHz byte-time model + CMD/token delay. Images continuously compete.
 always @(posedge sd) begin
  pv<=0;pe<=0;
  if(rst)begin busy<=0;count<=0;delay_count<=0;end
  else if(!busy && pr)begin busy<=1;address<=pa;count<=0;delay_count<=500;end
  else if(busy)begin
   if(delay_count!=0)delay_count<=delay_count-1;
   else if(count<512)begin
    sample_value=(address>=136697 ? 16'hcdef:16'h1234)+
                 ((address-(address>=136697 ? 136697:131072))*256)+(count>>1);
    if(REAL_PCM && address!=42) sample_value=reference_pcm[
     (address>=136697 ? 2048:0)+((address-(address>=136697 ? 136697:131072))*256)+(count>>1)];
    pd<=count[0] ? sample_value[15:8]:sample_value[7:0];
    pv<=1;count<=count+1;delay_count<=255;
   end else begin
    pe<=1;busy<=0;delay_count<=0;
    if(address==42)image_sectors<=image_sectors+1;
    else begin audio_sectors<=audio_sectors+1;if(address==131079)wraps<=wraps+1;end
   end
  end
 end
 always @(posedge sd)begin
  if((irv || ire) && arb.owner!=1)$fatal(1,"image response ownership");
  if((av || ae) && arb.owner!=2)$fatal(1,"audio response ownership");
 end
 task expect_pcm(input [23:0] expected);
 integer n,timeout,offset,ref_idx;reg locked;reg [15:0] expected_word;
 begin
  n=0;timeout=0;locked=0;expected_word=expected[23:8];
  offset=expected==24'h123400 ? 0:2048;ref_idx=0;
  if(REAL_PCM)begin
   while(reference_pcm[offset+ref_idx]==0)ref_idx=ref_idx+1;
   expected_word=reference_pcm[offset+ref_idx];
  end
  while(n<100)begin
   @(negedge vc);timeout=timeout+1;
   if(timeout>2000000)$fatal(1,"PCM timeout %h got %h/%h",expected,left_pcm,right_pcm);
   if(valid)begin
    if(!locked && left_pcm=={expected_word,8'd0} && right_pcm=={expected_word,8'd0})begin
     locked=1;n=1;ref_idx=ref_idx+1;
     expected_word=REAL_PCM ? reference_pcm[offset+ref_idx]:expected_word+1;
    end
    else if(locked)begin
     if(left_pcm!={expected_word,8'd0} || right_pcm!={expected_word,8'd0})
      $fatal(1,"sample dropped/repeated: expected %h got %h/%h",expected_word,left_pcm,right_pcm);
     n=n+1;ref_idx=ref_idx+1;
     expected_word=REAL_PCM ? reference_pcm[offset+ref_idx]:expected_word+1;
    end
   end
  end
 end endtask
 integer test_pass=0;
 initial if(!CONTROLS_TEST) begin
  #1000;rst=0;control=2'b10;
  expect_pcm(24'h123400);
  wait(wraps>=1);expect_pcm(24'h123400);
  // Change while a sector is owned; stale bytes must be drained and discarded.
  wait(busy && address<136697 && address!=42 && count>20);
  control=2'b11;expect_pcm(24'hcdef00);
  repeat(200000)@(negedge vc);
  if(health[2:1]!=0)$fatal(1,"underflow or short sector %b",health);
  control=0;repeat(10000)@(negedge vc);
  if(left_pcm!=0 || right_pcm!=0)$fatal(1,"exit not muted");
  control=2'b10;expect_pcm(24'h123400);
  // Repeated quick control changes must converge on the last selection.
  repeat(6)begin #17000;control[0]=~control[0];end
  control=2'b11;expect_pcm(24'hcdef00);
  if(image_sectors<2)$fatal(1,"image client starved");
  if(health[2:1]!=0)$fatal(1,"health %b",health);
  $display("PASS music: PCM bit exact L/R, switches, wrap, mute, competing image reads=%0d audio=%0d",image_sectors,audio_sectors);
  test_pass=1;$finish;
 end

 function integer gain_ref(input integer v);
  case(v) 1:gain_ref=26;2:gain_ref=51;3:gain_ref=77;4:gain_ref=102;5:gain_ref=128;
  6:gain_ref=154;7:gain_ref=179;8:gain_ref=205;9:gain_ref=230;default:gain_ref=256;endcase
 endfunction
 task expect_sequence(input integer base,input integer start_idx,input integer vol);
 integer n,timeout,idx,scaled;reg locked;reg [23:0] expected;
 begin
  n=0;timeout=0;idx=start_idx;locked=0;
  while(n<40)begin
   @(negedge vc);timeout=timeout+1;
   scaled=((base+idx)*gain_ref(vol))>>>8;expected={16'(scaled),8'd0};
   if(timeout>1000000)$fatal(1,"resume timeout vol %0d idx %0d",vol,idx);
   if(valid)begin
    if(!locked && left_pcm==expected && right_pcm==expected)locked=1;
    if(locked)begin
     if(left_pcm!==expected || right_pcm!==expected)
      $fatal(1,"pause/gain sequence expected %h got %h/%h",expected,left_pcm,right_pcm);
     n=n+1;idx=(idx+1)%2048;
    end
   end
  end
 end endtask
 integer level,sample_test,expected_scaled,position;
 initial if(CONTROLS_TEST)begin
  #1000;rst=0;control=2'b10;
  for(level=1;level<=10;level=level+1)begin
   for(sample_test=-32768;sample_test<=32767;sample_test=sample_test+37)begin
    expected_scaled=(sample_test*gain_ref(level))>>>8;
    if(dut.scale_sample(16'(sample_test),4'(level))!==16'(expected_scaled))
     $fatal(1,"signed volume arithmetic %0d %0d",level,sample_test);
   end
   if(dut.scale_sample(16'h7fff,4'(level))!==16'((32767*gain_ref(level))>>>8))$fatal(1,"positive full scale");
  end
  expect_pcm(24'h123400);
  for(level=1;level<=10;level=level+1)begin
   playback={1'b1,4'(level)};
   wait(dut.playback_audio==playback);repeat(800)@(negedge ac);
   position=dut.rd_bin;
   repeat(3000)begin
    @(negedge ac);if(dut.rd_bin!=position)$fatal(1,"pause advanced pointer");
   end
   if(left_pcm!=0 || right_pcm!=0)$fatal(1,"pause not silent");
   playback={1'b0,4'(level)};
   expect_sequence(16'h1234,position%2048,level);
   if(health[2:1]!=0)$fatal(1,"buffer health %b",health);
  end
  playback=5'b11010;wait(dut.paused);repeat(800)@(negedge ac);
  control=2'b11;
  wait(dut.selected==control && dut.state==2 && dut.used_audio>=1024);
  repeat(800)@(negedge ac);
  if(dut.rd_bin!=0 || left_pcm!=0 || right_pcm!=0)$fatal(1,"paused song switch consumed data");
  playback=10;expect_sequence(-12817,0,10);
  playback=5'b10101;wait(dut.paused);repeat(800)@(negedge ac);position=dut.rd_bin;
  playback=5'b00101;expect_sequence(-12817,position%2048,5);
  $display("PASS controls: 10 signed gains, silence/frozen pointer, exact resume, negative PCM, song switch while paused");
  test_pass=1;$finish;
 end
 initial begin #500000000;$fatal(1,"watchdog");end
endmodule
