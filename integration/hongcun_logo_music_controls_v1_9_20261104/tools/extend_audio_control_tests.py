from pathlib import Path
R=Path(__file__).resolve().parents[1];P=R/'music_sim/tb_music.sv'
s=P.read_text(encoding='utf-8')
s=s.replace('parameter REAL_PCM=0','parameter REAL_PCM=0,CONTROLS_TEST=0')
s=s.replace(' reg [1:0] control=0;',' reg [1:0] control=0;reg [4:0] playback=10;')
s=s.replace("dout,health,5'd10);",'dout,health,playback);')
s=s.replace(' initial begin\n  #1000;rst=0;control=2\'b10;', ' initial if(!CONTROLS_TEST) begin\n  #1000;rst=0;control=2\'b10;')
marker=' initial begin #500000000;'
extra='''
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
'''
assert marker in s
s=s.replace(marker,extra+marker)
P.write_text(s,encoding='utf-8')
