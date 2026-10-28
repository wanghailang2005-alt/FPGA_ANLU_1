`timescale 1ns/1ps
module tb_storage;
reg mc=0,wc=0,pc=0,rst=1,wr=0,rr=0,we=0,re=0;
always #4 mc=~mc;
always #5 wc=~wc;
always #20 pc=~pc;
wire wa,wf,ra,rf,wen,ren;
wire [20:0] waddr,raddr;
wire [31:0] wd,rd;
reg [31:0] din=0;
reg [31:0] mem[0:614399];
reg [1:0] write_bank=0,read_bank=0;
reg [31:0] ret_data[0:5];
reg [5:0] ret_valid=0;
wire [79:0] diag;
wire [2:0] wdiag;
wire [8:0] usedw;
wire [4:0] status;
integer n=0,j,consumed=0,readback=0,t=0;
integer pattern_case=0;
reg test_pass=0;
reg [20:0] captured_addr;
reg [31:0] captured_data;
reg pending_write=0;
function automatic [31:0] value(input integer index);
 if(pattern_case==3 && (index/640<120 || index/640>=360)) value=0;
 else value={8'(index%640),8'(479-index/640),8'((index%640)^(479-index/640)),8'h00};
endfunction
frame_read_write #(.BURST_BITS(10),.BURST_SIZE(128)) dut(
 .rst(rst),.mem_clk(mc),.Sdr_init_done(1'b1),.Sdr_init_ref_vld(1'b0),.Sdr_busy(1'b0),
 .App_rd_en(ren),.App_rd_addr(raddr),.Sdr_rd_en(ret_valid[5]),.Sdr_rd_dout(ret_data[5]),
 .read_clk(pc),.read_req(rr),.read_req_ack(ra),.read_finish(rf),
 .read_addr_0(21'd0),.read_addr_1(21'd307200),.read_addr_2(21'd0),.read_addr_3(21'd0),
 .read_status(9'b001000000),.read_frame_status(status),.read_addr_index(read_bank),.read_len(21'd307200),
 .read_en(re),.read_data(rd),.App_wr_en(wen),.App_wr_addr(waddr),.App_wr_din(wd),.App_wr_dm(),
 .write_clk(wc),.write_req(wr),.write_req_ack(wa),.write_finish(wf),
 .write_addr_0(21'd0),.write_addr_1(21'd307200),.write_addr_2(21'd0),.write_addr_3(21'd0),
 .write_addr_index(write_bank),.write_len(21'd307200),.write_en(we),.write_data(din),
 .write_usedw(usedw),.storage_diag_mem(diag),.storage_diag_write(wdiag));
// Write FIFO uses SHOW_AHEAD_EN=1: sample its payload at the command edge.
always @(posedge mc) begin
 pending_write<=wen; captured_addr<=waddr;captured_data<=wd;
 ret_valid<={ret_valid[4:0],ren};
 if(ren) ret_data[0]<=mem[raddr];
 for(j=1;j<6;j=j+1) ret_data[j]<=ret_data[j-1];
 if(wen) begin
  if(dut.diag_fifo_empty) $fatal(1,"write FIFO underflow at %0d",consumed);
  if(ren) $fatal(1,"simultaneous read/write command");
  if(waddr !== (write_bank*307200+(479-consumed/640)*640+consumed%640)) $fatal(1,"write address mismatch");
 end
end
always @(negedge mc) if(pending_write) begin
 if(captured_data !== value(consumed)) $fatal(1,"FIFO data mismatch n=%0d got=%h expected=%h",consumed,captured_data,value(consumed));
 mem[captured_addr]=captured_data; consumed=consumed+1;
end
task automatic consume_frame;
 integer k;
 begin
 rr=1;wait(ra);@(negedge pc);rr=0;wait(!ra);repeat(100) @(negedge pc);
 for(k=0;k<307200;k=k+1) begin
  @(negedge pc);re=1;
  @(posedge pc);#1;
  if(rd!==value((479-k/640)*640+k%640)) $fatal(1,"readback mismatch n=%0d got=%h expected=%h",k,rd,value((479-k/640)*640+k%640));
 end
 @(negedge pc);re=0;
 end
endtask
task automatic run_frame(input integer sparse);
 integer k,cycles;
 begin
 rst=1;wr=0;rr=0;we=0;re=0; consumed=0;write_bank=(sparse==1);read_bank=0;pattern_case=sparse;
 repeat(8) @(negedge wc);rst=0;wr=1;
 wait(wa);@(negedge wc);wr=0;wait(!wa);repeat(5) @(negedge wc);
 k=0;cycles=0;
 fork
 begin if(sparse==1) consume_frame(); end
 begin
 while(k<307200 && cycles<15000000) begin
  @(negedge wc);we=0;cycles=cycles+1;
  if(usedw<384 && ((sparse==1) ? cycles%35==0 :
      (sparse==2 || (sparse==3 && (k/640<120 || k/640>=360))) ? 1'b1 : cycles%2==0)) begin
   we=1;din=value(k);k=k+1;
  end
 end
 @(negedge wc);we=0;t=0;
 end
 join
 while(!wf && t<10000) begin @(negedge mc);t=t+1;end
 if(!wf || consumed!=307200 || wdiag[2:1] || diag[74]) $fatal(1,"write completion/flags failure produced=%0d consumed=%0d wf=%b wdiag=%b diag=%h",k,consumed,wf,wdiag,diag);
 read_bank=write_bank;consume_frame();
 $display("PASS real FIFOs write/vertical-flip/readback sparse=%0d pixels=307200",sparse);
 end
endtask
initial begin
 force dut.rdusedw[9]=0;force dut.wrusedw[9]=0;
 run_frame(0);run_frame(1);run_frame(2);run_frame(3);
 test_pass=1;$display("RESULT PASS real FIFO storage frames=4 pixels=1228800 includes_full_rate_and_black_borders");$finish;
end
initial begin #300000000;$fatal(1,"storage test timeout");end
endmodule
