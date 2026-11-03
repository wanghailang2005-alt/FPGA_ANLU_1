`timescale 1ns/1ps
module tb_control_keys;
 reg clk=0,rst=1,enable=0,k2=1,k4=1;
 always #10 clk=~clk;
 wire paused;wire [3:0] volume;
 music_controls #(.CLK_FREQ_HZ(100000),.FILTER_MS(1)) dut(clk,rst,enable,k2,k4,paused,volume);
 task settle;repeat(130)@(negedge clk);endtask
 task volume_press;begin k4=0;settle();k4=1;settle();end endtask
 integer test_pass=0,j;
 initial begin
  #100;rst=0;settle();
  if(paused!==0 || volume!==5)$fatal(1,"default state");
  volume_press();k2=0;settle();k2=1;settle();
  if(paused!==0 || volume!==5)$fatal(1,"non-1001 action");
  enable=1;
  repeat(10)begin k2=~k2;repeat(5)@(negedge clk);end
  k2=1;settle();if(paused!==0)$fatal(1,"bounce");
  k2=0;settle();if(paused!==1)$fatal(1,"pause key");
  repeat(600)@(negedge clk);if(paused!==1)$fatal(1,"long press repeated");
  k2=1;settle();k2=0;settle();k2=1;settle();if(paused!==0)$fatal(1,"resume key");
  for(j=1;j<=10;j=j+1)begin
   volume_press();if(volume!==(5+j>10 ? 5+j-10:5+j))$fatal(1,"volume cycle %0d %0d",j,volume);
  end
  k4=0;settle();repeat(600)@(negedge clk);if(volume!==6)$fatal(1,"volume long press");
  enable=0;k4=1;settle();volume_press();if(volume!==6)$fatal(1,"state not retained outside mode");
  $display("PASS control keys: K2 pause/resume, K4 ten levels, bounce/hold/mode guards");
  test_pass=1;$finish;
 end
endmodule
