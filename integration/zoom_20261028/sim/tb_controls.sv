`timescale 1ns/1ps
module tb_controls;
reg clk=0,dst_clk=0,rst_n=0,key=1;
always #10 clk=~clk;
always #7 dst_clk=~dst_clk;
reg [3:0] sw=0;
wire [1:0] mode,tm,ds,received;
wire [3:0] stable;
reg test_pass=0;
user_control #(.CLK_FREQ_HZ(1000),.FILTER_MS(2)) dut(
 .clk(clk),.rst_n(rst_n),.key3_n(key),.sw(sw),.transition_mode(tm),
 .duration_sel(ds),.scale_mode(mode),.sw_stable(stable));
osd_status_cdc #(.WIDTH(2)) cdc(.src_clk(clk),.dst_clk(dst_clk),.rst(!rst_n),.src_data(mode),.dst_data(received));
task automatic press;
 begin key=0; repeat(20) @(negedge clk); key=1; repeat(20) @(negedge clk); end
endtask
task automatic expect_mode(input integer expected);
 begin repeat(20) @(negedge clk);
 if(mode!=expected || received!=expected) $fatal(1,"mode/mailbox mismatch expected=%0d got=%0d/%0d",expected,mode,received);
 end
endtask
initial begin
 repeat(5) @(negedge clk); rst_n=1; repeat(20) @(negedge clk);
 sw=7; repeat(20) @(negedge clk);
 press(); expect_mode(1); press(); expect_mode(2); press(); expect_mode(0);
 // One long press must not repeat.
 key=0; repeat(200) @(negedge clk); expect_mode(1);
 key=1; repeat(20) @(negedge clk);
 sw=4; repeat(20) @(negedge clk); press();
 if(tm!=1 || mode!=1) $fatal(1,"transition setting changed zoom");
 press(); press(); if(tm!=0 || mode!=1) $fatal(1,"transition cycle regression");
 sw=5; repeat(20) @(negedge clk); press();
 if(ds!=2 || mode!=1) $fatal(1,"duration setting changed zoom");
 sw=8; repeat(20) @(negedge clk); press(); expect_mode(1);
 rst_n=0; repeat(10) @(negedge clk); rst_n=1; expect_mode(0);
 test_pass=1; $display("RESULT PASS controls mode_cycle gating long_press reset mailbox"); $finish;
end
endmodule
