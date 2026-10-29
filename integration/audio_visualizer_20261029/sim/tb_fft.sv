`timescale 1ns/1ps
module tb_fft;
 reg clk=0,rst=1,sample_valid=0;
 reg signed [15:0] sample_data=0;
 always #20 clk=~clk;
 wire overflow,load_valid,bin_valid,fft_done;
 wire [8:0] load_index;
 wire signed [15:0] load_sample,bin_re,bin_im;
 wire [7:0] bin_index;
 audio_fft512 dut(.*);
 reg [15:0] samples[0:4095];
 integer loaded=0,bin_count=0,frames=0,max_fifo=0,f,i;
 reg test_pass=0,checking=0;
 initial begin
  $readmemh("samples.hex",samples);f=$fopen("fft_output.txt","w");
  // Reset while collecting: no stale samples or partial frame may survive.
  repeat(5) @(negedge clk);rst=0;
  repeat(70) begin
   @(negedge clk);sample_valid=1;sample_data=16'sd1234;
   @(negedge clk);sample_valid=0;repeat(20) @(negedge clk);
  end
  @(negedge clk);rst=1;repeat(4) @(negedge clk);rst=0;checking=1;
  for(i=0;i<4096;i=i+1) begin
   @(negedge clk);sample_valid=1;sample_data=samples[i];
   @(negedge clk);sample_valid=0;
   repeat(519) @(negedge clk);
  end
  wait(frames==8);repeat(10) @(negedge clk);
  if(loaded!=4096 || bin_count!=2048 || overflow) $fatal(1,"counts or overflow");
  $fclose(f);
  // Reset while the butterfly is running, then verify a full fresh zero frame.
  checking=0;
  for(i=0;i<512;i=i+1) begin
   @(negedge clk);sample_valid=1;sample_data=10000;
   @(negedge clk);sample_valid=0;repeat(519) @(negedge clk);
  end
  wait(dut.state==13);@(negedge clk);rst=1;
  repeat(4) @(negedge clk);rst=0;
  for(i=0;i<512;i=i+1) begin
   @(negedge clk);sample_valid=1;sample_data=0;
   @(negedge clk);sample_valid=0;repeat(519) @(negedge clk);
  end
  wait(bin_valid);
  repeat(780) begin
   @(negedge clk);
   if(bin_valid && (bin_re!==0 || bin_im!==0)) $fatal(1,"stale FFT after reset");
  end
  // Deliberately exceed throughput: overflow is sticky, and reset clears it.
  for(i=0;i<700;i=i+1) begin
   @(negedge clk);sample_valid=1;sample_data=1234;
  end
  @(negedge clk);sample_valid=0;
  if(!overflow) $fatal(1,"overflow flag did not latch");
  rst=1;repeat(4) @(negedge clk);
  if(overflow) $fatal(1,"overflow reset");
  test_pass=1;
  $display("RESULT PASS fft frames=8 bin_count=2048 samples=4096 max_fifo=%0d reset_collect/reset_compute overflow_detection",max_fifo);
  $finish;
 end
 always @(negedge clk) if(!rst && checking) begin
  if(dut.fifo_count>max_fifo) max_fifo=dut.fifo_count;
  if(overflow) $fatal(1,"sample overflow");
  if(load_valid) begin
   if(load_index!==(loaded%512) || load_sample!==$signed(samples[loaded]))
    $fatal(1,"sample stream mismatch at %0d index=%0d data=%0d expected=%0d",loaded,load_index,load_sample,$signed(samples[loaded]));
   loaded=loaded+1;
  end
  if(bin_valid) begin
   if(bin_index!==(bin_count%256)) $fatal(1,"bin order");
   if($isunknown({bin_re,bin_im})) $fatal(1,"unknown FFT value");
   $fwrite(f,"%0d %0d %0d %0d\n",frames,bin_index,bin_re,bin_im);bin_count=bin_count+1;
  end
  if(fft_done) frames=frames+1;
 end
 initial begin #150000000;$fatal(1,"FFT watchdog");end
endmodule

