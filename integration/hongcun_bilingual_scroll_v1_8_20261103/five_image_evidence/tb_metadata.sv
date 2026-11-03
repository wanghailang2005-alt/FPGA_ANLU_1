`timescale 1ns/1ps
module tb_metadata;
reg clk=0;always #4 clk=~clk;
reg rst=1,req=0;reg [1:0] bank=0;reg [10:0] status=0;wire ack;wire [5:0] frame_status;reg test_pass=0;
frame_fifo_read dut(.rst(rst),.mem_clk(clk),.Sdr_init_done(1'b1),.Sdr_init_ref_vld(1'b0),.Sdr_busy(1'b0),.Sdr_rd_en(1'b0),.App_wr_busy(1'b0),.read_req(req),.read_req_ack(ack),.read_addr_0(21'd0),.read_addr_1(21'd307200),.read_status(status),.read_frame_status(frame_status),.read_addr_index(bank),.read_len(21'd307200),.wrusedw(10'd0));
task check(input [1:0] b,input [2:0] t0,t1,input [2:0] expected);
begin
@(negedge clk);bank=b;status={1'b1,1'b1,1'b1,b,t1,t0};repeat(5)@(negedge clk);req=1;wait(ack);@(negedge clk);
if(frame_status!=={3'b111,expected})$fatal(1,"metadata mismatch %b",frame_status);
req=0;repeat(15)@(negedge clk);
end endtask
initial begin
repeat(4)@(negedge clk);rst=0;
check(0,4,1,4);check(1,0,4,4);check(0,0,4,0);
test_pass=1;$display("PASS fifth image bank tags and frame commit metadata");$finish;end
initial begin #10000;$fatal(1,"timeout");end
endmodule
