`timescale 1ns/1ps
module sdram_diag_core #(
    parameter RETENTION_CYCLES=8192,
    parameter WATCHDOG_CYCLES=125000000
)(
    input clk, rst, init_done, ref_active, mem_busy,
    output wr_en, rd_en,
    output [20:0] wr_addr, rd_addr,
    output [31:0] wr_data,
    input rd_valid,
    input [31:0] rd_data,
    output reg [3:0] phase,
    output reg [19:0] errors,
    output reg [15:0] passes,
    output reg timed_out,
    output reg first_valid,
    output reg [20:0] first_addr,
    output reg [31:0] first_expected, first_actual
);
localparam INIT=0, WWAIT=1, WRITE=2, WDRAIN=3, HOLD=4,
           RWAIT=5, READ=6, RDRAIN=7, FAULT=15;
reg [2:0] block;
reg [8:0] sent, received;
reg [31:0] wr_lfsr, rd_lfsr;
reg [31:0] timer, watchdog;
reg [20:0] base;
function [20:0] block_base;
 input [2:0] b;
 begin
  case(b)
   0:block_base=21'h000000; 1:block_base=21'h000100;
   2:block_base=21'h000200; 3:block_base=21'h000300;
   4:block_base=21'h000400; 5:block_base=21'h03ff00;
   6:block_base=21'h100000; default:block_base=21'h1fff00;
  endcase
 end
endfunction
function [31:0] advance;
 input [31:0] v;
 begin advance={v[30:0],v[31]^v[21]^v[1]^v[0]};end
endfunction
wire [31:0] seed=32'h13579bdf^{16'd0,passes};
assign wr_en=(phase==WRITE);
assign rd_en=(phase==READ);
assign wr_addr=base+sent;
assign rd_addr=base+sent;
assign wr_data=wr_lfsr^{11'd0,wr_addr};
wire receiving=(phase==READ || phase==RDRAIN);
wire [20:0] compare_addr=base+received;
wire [31:0] expected=rd_lfsr^{11'd0,compare_addr};
wire progress=(phase==WRITE || rd_valid);
// Pipeline only the observer. Commands and controller valid/data are untouched.
reg check_valid,check_overrun,mismatch_pending;
reg [20:0] check_addr,failed_addr;
reg [31:0] check_actual,check_expected,failed_actual,failed_expected;
always @(posedge clk or posedge rst) begin
 if(rst) begin
  phase<=INIT;block<=0;base<=0;sent<=0;received<=0;timer<=0;watchdog<=0;
  wr_lfsr<=32'h13579bdf;rd_lfsr<=32'h13579bdf;
  errors<=0;passes<=0;timed_out<=0;first_valid<=0;
  first_addr<=0;first_expected<=0;first_actual<=0;
  check_valid<=0;check_overrun<=0;mismatch_pending<=0;
  check_addr<=0;failed_addr<=0;check_actual<=0;check_expected<=0;
  failed_actual<=0;failed_expected<=0;
 end else begin
  check_valid<=receiving && rd_valid;
  check_overrun<=received>=256;
  check_addr<=compare_addr;check_actual<=rd_data;check_expected<=expected;
  mismatch_pending<=check_valid && (check_overrun || check_actual!==check_expected);
  failed_addr<=check_addr;failed_actual<=check_actual;failed_expected<=check_expected;
  if(mismatch_pending) begin
   if(errors!=20'hfffff) errors<=errors+1'b1;
   if(!first_valid) begin
    first_valid<=1;first_addr<=failed_addr;
    first_expected<=failed_expected;first_actual<=failed_actual;
   end
  end
  // Every response is checked using validity, never an assumed read latency.
  if(receiving && rd_valid) begin
   if(received<257) received<=received+1'b1;
   rd_lfsr<=advance(rd_lfsr);
  end
  if(progress || phase==HOLD) watchdog<=0;
  else if(watchdog<WATCHDOG_CYCLES-1) watchdog<=watchdog+1'b1;
  case(phase)
   INIT:if(init_done) begin phase<=WWAIT;timer<=0;end
   WWAIT:begin
    // Resolve bank/row selection during the quiet wait, outside the
    // per-word address and mismatch paths. Stable before any command.
    base<=block_base(block);sent<=0;wr_lfsr<=seed;
    if(!mem_busy && !ref_active) begin
     if(timer==31) begin phase<=WRITE;timer<=0;end
     else timer<=timer+1'b1;
    end else timer<=0;
   end
   WRITE:begin
    wr_lfsr<=advance(wr_lfsr);
    if(sent==255) begin phase<=WDRAIN;timer<=0;end
    else sent<=sent+1'b1;
   end
   WDRAIN:begin
    if(timer==63) begin
     timer<=0;
     if(block==7) begin block<=0;phase<=HOLD;end
     else begin block<=block+1'b1;phase<=WWAIT;end
    end else timer<=timer+1'b1;
   end
   HOLD:begin
    if(timer==RETENTION_CYCLES-1) begin timer<=0;phase<=RWAIT;end
    else timer<=timer+1'b1;
   end
   RWAIT:begin
    base<=block_base(block);sent<=0;received<=0;rd_lfsr<=seed;
    if(!mem_busy && !ref_active) begin
     if(timer==31) begin phase<=READ;timer<=0;end
     else timer<=timer+1'b1;
    end else timer<=0;
   end
   READ:begin
    if(sent==255) begin phase<=RDRAIN;timer<=0;end
    else sent<=sent+1'b1;
   end
   RDRAIN:begin
    // Include a quiet tail so unexpected extra responses are also detected.
    if(received>=256) begin
     if(timer==63) begin
      timer<=0;
      if(block==7) begin
       block<=0;passes<=passes+1'b1;phase<=WWAIT;
      end else begin block<=block+1'b1;phase<=RWAIT;end
     end else timer<=timer+1'b1;
    end
   end
   default:phase<=FAULT;
  endcase
  if(watchdog>=WATCHDOG_CYCLES-1 && !progress && phase!=HOLD) begin
   timed_out<=1;phase<=FAULT;
  end
 end
end
endmodule
