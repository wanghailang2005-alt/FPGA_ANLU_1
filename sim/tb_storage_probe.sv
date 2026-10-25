`timescale 1ns/1ps
module tb_storage_probe;
reg mem_clk=0,write_clk=0,rst=1,req=0,we=0;
always #4 mem_clk=~mem_clk;
always #5 write_clk=~write_clk;
wire ack,finish; wire [79:0] probe; wire [2:0] wprobe;
reg test_passed=0;
integer i,timeout;
frame_read_write #(.BURST_BITS(10),.BURST_SIZE(4),.WRITE_V_FLIP(0),.FRAME_WIDTH(8),.FRAME_HEIGHT(1)) dut (
.rst(rst),.mem_clk(mem_clk),.write_clk(write_clk),.read_clk(write_clk),
.Sdr_init_done(1'b1),.Sdr_init_ref_vld(1'b0),.Sdr_busy(1'b0),
.Sdr_rd_en(1'b0),.Sdr_rd_dout(32'd0),.read_req(1'b0),.read_en(1'b0),
.read_len(21'd8),.read_addr_index(2'd0),.read_status(8'd0),
.read_addr_0(21'd0),.read_addr_1(21'd0),.read_addr_2(21'd0),.read_addr_3(21'd0),
.write_req(req),.write_req_ack(ack),.write_finish(finish),
.write_len(21'd8),.write_addr_index(2'd0),.write_data(32'h12345678),.write_en(we),
.write_addr_0(21'd0),.write_addr_1(21'd0),.write_addr_2(21'd0),.write_addr_3(21'd0),
.storage_diag_mem(probe),.storage_diag_write(wprobe));
initial begin
 // Explicit zero-padding assumption for existing FIFO port-width mismatch.
 force dut.rdusedw[9]=0; force dut.wrusedw[9]=0;
 repeat(4) @(negedge write_clk);rst=0;req=1;
 wait(ack); @(negedge write_clk);req=0;wait(!ack);
 repeat(6) @(negedge write_clk);
 for(i=0;i<8;i=i+1) begin we=1;@(negedge write_clk);end
 we=0;timeout=0;
 while(!probe[75] && timeout<200) begin @(negedge mem_clk);timeout=timeout+1;end
 if(!probe[75] || probe[19:0]!==20'd8 || probe[39:20]!==20'd8)
    $fatal(1,"normal transfer counters fail probe=%h",probe);
 if(probe[74] || wprobe[2:1]!==0) $fatal(1,"unexpected FIFO error");
 // Inject observations, confirm sticky capture and per-transfer clearing.
 force dut.diag_fifo_full=1; we=1;repeat(2) @(negedge write_clk);we=0;
 if(!wprobe[1]) $fatal(1,"overflow not captured");
 release dut.diag_fifo_full;
 force dut.write_fifo_aclr=1;we=1;repeat(2) @(negedge write_clk);we=0;
 if(!wprobe[2]) $fatal(1,"reset-write not captured");
 release dut.write_fifo_aclr;
 force dut.App_wr_en=1;force dut.diag_fifo_empty=1;
 @(negedge mem_clk);
 if(!probe[74]) $fatal(1,"underflow not captured");
 release dut.App_wr_en;release dut.diag_fifo_empty;
 force dut.write_fifo_aclr=1;@(negedge mem_clk);
 if(probe[75:74]!==0 || probe[39:20]!==0) $fatal(1,"memory diagnostic clear failed");
 release dut.write_fifo_aclr;
 req=1;repeat(2) @(negedge write_clk);
 if(wprobe[2:1]!==0) $fatal(1,"write diagnostic clear failed");
 test_passed=1;$display("SIM PASS storage probe: real FIFO transfer, counters, sticky errors, clear");$finish;
end
initial begin #100000;$fatal(1,"timeout");end
endmodule
