`timescale 1ns/1ps
module tb_control;
reg clk=0,rst=1,dark=0,done=0;
wire req,commit,valid;
wire [8:0] status;
reg test_passed=0;
integer i;
always #5 clk=~clk;
sd_card_bmp dut(.clk(clk),.rst(rst),.key_next(1'b1),.key_auto(1'b1),
 .transition_dark_toggle(dark),.transition_done_toggle(done),
 .transition_req_toggle(req),.transition_commit_toggle(commit),
 .state_code(),.pixel_count_debug(),.bmp_width(16'd640),.bmp_height(16'd480),
 .display_valid(valid),.osd_status(status),.storage_diag_sd(80'd0),.storage_diag_write(3'd0),
 .write_finish_toggle(1'b0),.write_buf_idx(),.disp_buf_idx(),.write_req(),
 .write_req_ack(1'b0),.write_en(),.write_data(),.SD_nCS(),.SD_DCLK(),.SD_MOSI(),.SD_MISO(1'b1));
task complete_load(input integer idx);
 begin
 @(negedge clk);
 dut.load_busy=1;dut.load_idx=idx;dut.pending_buf_idx=idx%2;
 dut.source_done_seen=0;dut.write_done_seen=0;
 repeat(4) @(negedge clk);
 dut.source_done_seen=1;
 repeat(4) @(negedge clk);
 if(commit!==done) $fatal(1,"source done committed early");
 dut.write_done_seen=1;
 @(negedge clk);
 end
endtask
initial begin
 force dut.sd_init_done=1;force dut.scan_done=1;force dut.bmp_ready=0;
 force dut.bmp_load_done=0;force dut.bmp_load_error=0;force dut.bmp_data_wr_en=0;
 repeat(3) @(negedge clk);rst=0;
 dut.scan_kicked=1;dut.img_found_count=4;
 complete_load(0);
 if(!valid || !commit || req || !dut.transition_active) $fatal(1,"first commit");
 repeat(12) @(negedge clk);
 if(!dut.transition_active) $fatal(1,"busy released without video completion");
 done=commit;repeat(5) @(negedge clk);
 if(dut.transition_active) $fatal(1,"busy stuck");
 for(i=1;i<5;i=i+1) begin
  complete_load(i%4);
  if(req===dark || commit!==done || !dut.load_busy) $fatal(1,"missing request or early bank commit");
  force dut.key_next_press=1;@(negedge clk);force dut.key_next_press=0;
  if(dut.next_req_pending) $fatal(1,"busy K2 queued");
  repeat(10) @(negedge clk);
  if(commit!==done) $fatal(1,"commit before dark ACK");
  dark=req;repeat(5) @(negedge clk);
  if(commit===done || dut.load_busy || !dut.transition_active) $fatal(1,"dark commit failed");
  if(status[8]!==commit || status[5:4]!==i%2) $fatal(1,"metadata generation/bank");
  repeat(5) @(negedge clk);
  if(!dut.transition_active) $fatal(1,"fade-in not busy");
  done=commit;repeat(5) @(negedge clk);
  if(dut.transition_active) $fatal(1,"completion not acknowledged");
 end
 rst=1;repeat(3) @(negedge clk);
 if(req || commit || valid) $fatal(1,"reset");
 test_passed=1;$display("SIM PASS controller: first image, 4 toggled commits, delayed dark/done, busy K2, reset");$finish;
end
initial begin #100000;$fatal(1,"timeout");end
endmodule
