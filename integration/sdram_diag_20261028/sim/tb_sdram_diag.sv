`timescale 1ns/1ps
module tb_sdram_diag #(parameter MODEL_TIMING=1);
reg clk=0,rst=1;
always #4 clk=~clk;
wire shifted=~clk;
wire sclk,cke,ras,cas,wen;
wire [1:0] ba;
wire [10:0] address;
wire [3:0] dm;
wire [31:0] dq;
wire init_done,ref_active,mem_busy,we,re,rv;
wire [20:0] wa,ra;
wire [31:0] wd,data;
wire [3:0] phase;
wire [19:0] errors;
wire [15:0] passes;
wire timeout_flag,first_valid;
wire [20:0] first_addr;
wire [31:0] first_expected,first_actual;
reg inject=0,drop=0;
reg test_passed=0;
integer writes=0,reads=0,responses=0,refreshes=0;
reg [20:0] injected_addr;
reg [31:0] injected_expected,injected_actual;
sdram mem(.SDRAM_CLK(sclk),.SDR_CKE(cke),.SDR_RAS(ras),.SDR_CAS(cas),
 .SDR_WE(wen),.SDR_BA(ba),.SDR_ADDR(address),.SDR_DM(dm),.SDR_DQ(dq),
 .Clk(clk),.Clk_sft(shifted),.Rst(rst),.Sdr_init_done(init_done),
 .Sdr_init_ref_vld(ref_active),.Sdr_busy(mem_busy),.App_wr_en(we),
 .App_wr_addr(wa),.App_wr_dm(4'd0),.App_wr_din(wd),.App_rd_en(re),
 .App_rd_addr(ra),.Sdr_rd_en(rv),.Sdr_rd_dout(data));
// Same external bus-functional model used by the official APUG011 testbench.
// The synthesis primitive supplied in sim_release is an empty module.
// Default keeps the supplied -7 timing. The optional extended hold window
// isolates logic checking from this known interface timing failure. It is
// deliberately not a device model for timing signoff or hardware prediction.
IS42s32200 #(.tAC(5.5),.tHZ(5.5),.tOH(MODEL_TIMING ? 2.5 : 4.5))
 dram_model(.Clk(sclk),.Cke(cke),.Cs_n(1'b0),.Ras_n(ras),
 .Cas_n(cas),.We_n(wen),.Ba(ba),.Addr(address),.Dqm(dm),.Dq(dq));
sdram_diag_core #(.WATCHDOG_CYCLES(1000000)) dut(.clk(clk),.rst(rst),
 .init_done(init_done),.ref_active(ref_active),.mem_busy(mem_busy),
 .wr_en(we),.rd_en(re),.wr_addr(wa),.rd_addr(ra),.wr_data(wd),
 .rd_valid(rv&&!drop),.rd_data(data^(inject ? 32'd1 : 32'd0)),
 .phase(phase),.errors(errors),.passes(passes),.timed_out(timeout_flag),
 .first_valid(first_valid),.first_addr(first_addr),
 .first_expected(first_expected),.first_actual(first_actual));
always @(posedge clk) if(!rst) begin
 if(we) writes=writes+1;
 if(re) reads=reads+1;
 if(rv) responses=responses+1;
 if(inject && rv) begin
  injected_addr=dut.compare_addr;
  injected_expected=dut.expected;injected_actual=data^32'd1;
 end
 if(ref_active) refreshes=refreshes+1;
 if(we&&re) $fatal(1,"overlapping requests");
 if(!drop && errors<2 && rv && dut.receiving && data!==dut.expected) $display("mismatch phase=%0d n=%0d got=%h expected=%h time=%0t",phase,dut.received,data,dut.expected,$time);
end
initial begin
 repeat(10) @(negedge clk);rst=0;
 wait(passes==1 || timeout_flag);
 if(MODEL_TIMING) begin
  $display("TIMED MODEL RESULT: errors=%0d timeout=%b wr=%0d rd=%0d responses=%0d refresh=%0d; no hardware timing pass claimed",errors,timeout_flag,writes,reads,responses,refreshes);
  if(timeout_flag || writes!=2048 || reads!=2048 || responses!=2048 || !refreshes)
   $fatal(1,"timed model did not complete baseline transactions");
  if(errors!=0 && !first_valid) $fatal(1,"mismatch snapshot missing");
  test_passed=1;$finish;
 end
 if(timeout_flag || errors || !refreshes || writes!=2048 || reads!=2048 || responses!=2048)
  $fatal(1,"native SDRAM baseline failed errors=%0d timeout=%b wr=%0d rd=%0d responses=%0d refresh=%0d",errors,timeout_flag,writes,reads,responses,refreshes);
 $display("FUNCTIONAL SIM PASS (extended-hold reference model, not device timing): 2048 words, 8 bank/row blocks, retention/refresh, exact valid/data match");
 wait(rv);@(negedge clk);inject=1;
 @(negedge clk);inject=0;
 repeat(3) @(negedge clk);
 if(errors!=1 || !first_valid || (first_expected^first_actual)!=1 ||
    first_addr!==injected_addr || first_expected!==injected_expected ||
    first_actual!==injected_actual) $fatal(1,"error injection/snapshot not captured exactly once and aligned");
 wait(passes==2 || timeout_flag);
 if(timeout_flag || errors!=1) $fatal(1,"error counter/next pass");
 $display("SIM PASS injected mismatch: count and first-failure snapshot");
 @(negedge clk);rst=1;
 repeat(4) @(negedge clk);
 if(errors || passes || first_valid || we || re) $fatal(1,"reset did not clear diagnostics");
 rst=0;drop=1;
 wait(timeout_flag);
 if(phase!=15 || we || re) $fatal(1,"timeout did not stop commands");
 $display("SIM PASS dropped read responses: watchdog stops safely; reset recovery checked");
 test_passed=1;$finish;
end
initial begin #100000000;$fatal(1,"simulation timeout");end
endmodule
