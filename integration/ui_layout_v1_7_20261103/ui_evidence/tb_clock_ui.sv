`timescale 1ns/1ps
module tb_clock_ui;
 reg clk=0,rst=1,frame=0;always #5 clk=~clk;
 wire v,p;wire [23:0]c;reg test_pass=0;
 ui_sidebar #(.CLOCK_HZ(4)) dut(.clk(clk),.rst(rst),.frame_tick(frame),.enable(1'b0),
 .x(10'd0),.y(9'd0),.de(1'b0),.image_valid(1'b0),.auto_play(1'b0),
 .image_index(2'd0),.scale_mode(2'd0),.interpolation(1'b0),.transition_mode(3'd0),
 .sw_code(4'd0),.brightness(4'd5),.contrast(4'd5),.setting_value(4'd0),
 .valid(v),.pixel(p),.color(c));
 initial begin
 repeat(3)@(negedge clk);rst=0;repeat(240)@(negedge clk);
 if(dut.clock_frame!==0)$fatal(1,"clock changed outside frame boundary");
 frame=1;@(negedge clk);frame=0;
 if(dut.clock_frame!==24'h000100)$fatal(1,"minute rollover expected 00:01:00 got %h",dut.clock_frame);
 repeat(4*59*60)@(negedge clk);frame=1;@(negedge clk);frame=0;
 if(dut.clock_frame[23:8]!==16'h0100)$fatal(1,"hour rollover");
 rst=1;@(negedge clk);if(dut.clock_frame!==0)$fatal(1,"reset failed");
 test_pass=1;$display("RESULT PASS runtime clock minute/hour rollover, reset, frame-constant display");$finish;
 end
endmodule
