`timescale 1ns/1ps
module tb_music_keys;
 reg clk=0,rst_n=0,key=1;reg [3:0] sw=0;
 always #10 clk=~clk;
 wire track;wire [3:0] stable,value;wire [1:0] text_mode;
 user_control #(.CLK_FREQ_HZ(100000),.FILTER_MS(1)) dut(
 .clk(clk),.rst_n(rst_n),.animation_busy(1'b0),.key3_n(key),.sw(sw),
 .music_track(track),.sw_stable(stable),.setting_value(value),.text_mode(text_mode),
 .transition_mode(),.duration_sel(),.scale_mode(),.interpolation(),.scroll_speed(),
 .scroll_dir(),.slide_dir(),.brightness(),.contrast(),.sub_mode());
 task settle;repeat(130)@(negedge clk);endtask
 task press;begin key=0;settle();key=1;settle();end endtask
 integer test_pass=0;
 initial begin
  #100;rst_n=1;sw=9;settle();
  if(track!==0 || stable!==9 || value!==1)$fatal(1,"initial selection");
  repeat(12)begin key=~key;repeat(5)@(negedge clk);end
  key=1;settle();if(track!==0)$fatal(1,"bounce changed track");
  key=0;settle();if(track!==1 || value!==2)$fatal(1,"K3 did not switch");
  repeat(500)@(negedge clk);if(track!==1)$fatal(1,"long press repeated");
  key=1;settle();press();if(track!==0)$fatal(1,"second press did not wrap");
  sw=1;settle();press();
  if(track!==0 || text_mode!==0)$fatal(1,"other mode changed track or old control broken");
  sw=9;settle();if(track!==0)$fatal(1,"switch entry changed song");
  $display("PASS keys: bounce rejected, long press once, two-song wrap, original mode retained");
  test_pass=1;$finish;
 end
endmodule
