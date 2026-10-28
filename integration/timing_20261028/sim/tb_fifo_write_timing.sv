`timescale 1ns/1ps
module fifo_write_case #(parameter FLIP=1)(output reg passed=0);
reg clk=0,rst=1,req=0,feed=0,read_busy=0;
reg hold_read=0;
reg [20:0] length=0;
wire [1:0] ack,finish,en,clear,busy;
wire [20:0] addr[0:1];
reg [9:0] used[0:1];
integer occupancy[0:1],produced[0:1],consumed[0:1];
integer cycle=0,tests=0,stall_cycles=0;
integer j,expected,arrival;
always #4 clk=~clk;
genvar g;
generate for(g=0;g<2;g=g+1) begin: instances
 if(g==0) begin: updated
 frame_fifo_write #(.BURST_SIZE(256),.WRITE_V_FLIP(FLIP)) dut(
  .mem_clk(clk),.rst(rst),.Sdr_init_done(1'b1),.Sdr_init_ref_vld(1'b0),
  .Sdr_busy(1'b0),.App_rd_busy(read_busy),.O_wr_busy(busy[g]),
  .App_wr_en(en[g]),.App_wr_addr(addr[g]),.write_req(req),.write_req_ack(ack[g]),
  .write_finish(finish[g]),.write_addr_0(21'd1000),.write_addr_1(21'd500000),
  .write_addr_2(21'd0),.write_addr_3(21'd0),.write_addr_index(2'd0),
  .write_len(length),.fifo_aclr(clear[g]),.rdusedw(used[g]),
  .diag_write_count(),.diag_write_state(),.diag_burst_count());
 end else begin: reference
 frame_fifo_write_reference #(.BURST_SIZE(256),.WRITE_V_FLIP(FLIP)) dut(
  .mem_clk(clk),.rst(rst),.Sdr_init_done(1'b1),.Sdr_init_ref_vld(1'b0),
  .Sdr_busy(1'b0),.App_rd_busy(read_busy),.O_wr_busy(busy[g]),
  .App_wr_en(en[g]),.App_wr_addr(addr[g]),.write_req(req),.write_req_ack(ack[g]),
  .write_finish(finish[g]),.write_addr_0(21'd1000),.write_addr_1(21'd500000),
  .write_addr_2(21'd0),.write_addr_3(21'd0),.write_addr_index(2'd0),
  .write_len(length),.fifo_aclr(clear[g]),.rdusedw(used[g]),
  .diag_write_count(),.diag_write_state(),.diag_burst_count());
 end
end endgenerate
// Two independent FIFO models let the old/new controllers run at different
// cycles. Every accepted write is checked against the same address model.
always @(posedge clk) begin
 cycle<=cycle+1;
 for(j=0;j<2;j=j+1) begin
  if(rst || clear[j]) begin
   occupancy[j]<=0;produced[j]<=0;consumed[j]<=0;used[j]<=0;
  end else begin
   arrival=feed && produced[j]<length && occupancy[j]<512 && cycle%3!=0;
   if(en[j]) begin
    if(occupancy[j]<=0) $fatal(1,"FIFO underflow flip=%0d variant=%0d",FLIP,j);
    if(read_busy) $fatal(1,"read/write overlap");
    if(consumed[j]>=length) $fatal(1,"too many writes");
    expected=1000+(FLIP ? ((479-consumed[j]/640)*640+consumed[j]%640) : consumed[j]);
    if(addr[j]!==expected) $fatal(1,"address mismatch flip=%0d variant=%0d n=%0d addr=%h expected=%h",FLIP,j,consumed[j],addr[j],expected);
    consumed[j]<=consumed[j]+1;
   end
   occupancy[j]<=occupancy[j]+arrival-en[j];
   used[j]<=occupancy[j]+arrival-en[j];
   produced[j]<=produced[j]+arrival;
  end
 end
end
// Model a reader that may claim the bus only when neither writer reserves it.
always @(negedge clk) begin
 if(rst) begin read_busy=0;stall_cycles=0;end
 else if(hold_read) begin read_busy=1;stall_cycles=0;end
 else if(stall_cycles>0) begin stall_cycles=stall_cycles-1;read_busy=1;end
 else begin
  read_busy=0;
  if(cycle%47==0 && !busy[0] && !busy[1]) begin read_busy=1;stall_cycles=8;end
 end
end
task automatic start_frame(input integer n);
 begin
  @(negedge clk);rst=1;req=0;feed=0;length=n;
  repeat(3) @(negedge clk);rst=0;req=1;
  wait(&ack);@(negedge clk);req=0;
  wait(clear==0);@(negedge clk);
  // Empty FIFO must not start a positive-length frame.
  repeat(12) begin @(negedge clk);if(|en) $fatal(1,"empty FIFO write");end
  feed=1;
 end
endtask
task automatic frame_case(input integer n);
 integer t; reg [1:0] seen;
 begin
  start_frame(n);seen=0;t=0;
  while(t<n*5+5000 && (consumed[0]<n || consumed[1]<n || ((n%256==0) && seen!=3))) begin
   @(negedge clk);seen=seen|finish;t=t+1;
  end
  if(consumed[0]!=n || consumed[1]!=n) $fatal(1,"frame count n=%0d old=%0d new=%0d",n,consumed[1],consumed[0]);
  if(n%256==0 && seen!=3) $fatal(1,"aligned frame missing completion");
  repeat(32) begin @(negedge clk);if(|en) $fatal(1,"trailing write");end
  // Legacy controller does not finish a partial final burst. Verify that
  // behavior separately; repairing it is outside this timing-only change.
  if(n%256!=0 && (|finish)) $fatal(1,"partial completion behavior changed");
  tests=tests+1;
 end
endtask
initial begin
 frame_case(1);frame_case(255);frame_case(256);frame_case(257);
 frame_case(512);frame_case(640*480);
 // Withdraw an eligible pending burst by issuing a fresh frame request.
 // Keep the reader busy until the FIFO clear handshake has completed.
 hold_read=1;start_frame(1024);
 wait(instances[0].updated.dut.fifo_data_ready);
 @(negedge clk);feed=0;req=1;
 wait(&ack);@(negedge clk);req=0;
 wait(clear==0);repeat(4) @(negedge clk);
 hold_read=0;
 repeat(12) begin @(negedge clk);if(|en) $fatal(1,"stale readiness after new request");end
 tests=tests+1;
 // Reset during a live burst must clear data eligibility and write output.
 start_frame(1024);wait(en[0]);@(negedge clk);rst=1;feed=0;
 #1;if(en[0] || instances[0].updated.dut.fifo_data_ready) $fatal(1,"reset did not clear writer");
 frame_case(256);
 passed=1;$display("SIM PASS FIFO writer flip=%0d cases=%0d; exact counts/addresses, underflow, arbitration, reset; legacy partial-burst completion limitation retained",FLIP,tests);
end
endmodule
module tb_fifo_write_timing;
wire a,b;
wire test_passed=a&&b;
fifo_write_case #(.FLIP(0)) normal(a);
fifo_write_case #(.FLIP(1)) flipped(b);
initial begin wait(test_passed);$finish;end
initial begin #30000000;$fatal(1,"timeout");end
endmodule
