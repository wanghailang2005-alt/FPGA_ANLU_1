`timescale 1ns/1ps
module tb_dma_drain;
reg mc=0,wc=0,pc=0,rst=1,rr=0,wr=0,we=0;
always #4 mc=~mc;always #5 wc=~wc;always #20 pc=~pc;
wire ra,wa,rf,wf,ren,wen,owner_busy;
wire [20:0] raddr,waddr;
wire [31:0] wdata;
reg [36:0] return_pipe=0;
reg [31:0] return_data[0:36];
reg [31:0] data=0;
integer pending=0,issued=0,returned=0,written=0,j,t;
reg test_pass=0;
frame_read_write #(.BURST_SIZE(16),.FRAME_WIDTH(16),.FRAME_HEIGHT(8)) dut(
 .rst(rst),.mem_clk(mc),.auxiliary_hold(1'b0),.legacy_busy(owner_busy),
 .Sdr_init_done(!rst),.Sdr_init_ref_vld(1'b0),.Sdr_busy(1'b0),
 .App_rd_en(ren),.App_rd_addr(raddr),.Sdr_rd_en(return_pipe[36]),.Sdr_rd_dout(return_data[36]),
 .read_clk(pc),.read_req(rr),.read_req_ack(ra),.read_finish(rf),
 .read_addr_0(21'd0),.read_addr_1(21'd128),.read_addr_2(21'd0),.read_addr_3(21'd0),
 .read_status(9'd0),.read_frame_status(),.read_addr_index(2'd0),.read_len(21'd16),.read_en(1'b0),.read_data(),
 .App_wr_en(wen),.App_wr_addr(waddr),.App_wr_din(wdata),.App_wr_dm(),
 .write_clk(wc),.write_req(wr),.write_req_ack(wa),.write_finish(wf),
 .write_addr_0(21'd128),.write_addr_1(21'd0),.write_addr_2(21'd0),.write_addr_3(21'd0),
 .write_addr_index(2'd0),.write_len(21'd128),.write_usedw(),.write_en(we),.write_data(data),
 .storage_diag_mem(),.storage_diag_write(),.diagnostic_read());
always @(posedge mc) begin
 if(rst) begin return_pipe<=0;pending=0;issued=0;returned=0;written=0;end
 else begin
  if(pending!=0 && !owner_busy) $fatal(1,"legacy ownership released with pending read returns=%0d",pending);
  if(wen && pending!=0) $fatal(1,"write burst started before read return drain");
  return_pipe<={return_pipe[35:0],ren};
  if(ren) begin return_data[0]<=raddr;issued=issued+1;end
  for(j=1;j<37;j=j+1) return_data[j]<=return_data[j-1];
  if(return_pipe[36]) returned=returned+1;
  pending=pending+ren-return_pipe[36];
  if(wen) written=written+1;
 end
end
initial begin
 repeat(10) @(negedge wc);rst=0;
 @(negedge pc);rr=1;wait(ra);@(negedge pc);rr=0;
 wait(ren);@(negedge wc);wr=1;wait(wa);@(negedge wc);wr=0;wait(!wa);repeat(4) @(negedge wc);
 for(t=0;t<128;t=t+1) begin we=1;data=t;@(negedge wc);end
 we=0;t=0;
 while(!wf && t<5000) begin @(negedge wc);t=t+1;end
 if(!wf || pending!=0 || issued!=16 || returned!=16 || written!=128) $fatal(1,"drain regression completion counts");
 $display("RESULT PASS dma_drain latency=37 reads=16 returns=16 writes=128 no_early_owner_release=PASS");
 test_pass=1;$finish;
end
initial begin #100000;$fatal(1,"DMA drain test timed out");end
endmodule
