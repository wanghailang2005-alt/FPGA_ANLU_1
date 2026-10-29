`timescale 1ns/1ps
`default_nettype none
// Third SDRAM client. Blocks legacy DMA only in short, drained transactions.
// Display/normal writer keep their existing command and FIFO contracts.
module zoom_source_cache #(
    parameter CACHE_BASE=614400, BLOCK=8, GAP=64,
    parameter ACQUIRE_QUIET=8, RELEASE_QUIET=16
)(
    input wire rst,sd_clk,mem_clk,
    input wire upload_req,
    input wire [15:0] src_w,src_h,
    input wire upload_valid,
    input wire [23:0] upload_pixel,
    output wire upload_ready,
    output wire cache_valid,
    input wire row_req,
    input wire [15:0] row_index,
    output wire row_ack,row_valid,
    output wire [23:0] row_pixel,
    input wire row_ready,
    output reg legacy_hold,
    input wire legacy_busy,
    output wire aux_active,aux_read,aux_write,
    output wire [20:0] aux_addr,
    output wire [31:0] aux_data,
    input wire init_done,refresh_busy,sdr_busy,
    input wire read_valid,
    input wire [31:0] read_data,
    output wire cache_error,
    output wire [19:0] checksum_status
);
localparam PICK=0,WAIT_LEGACY=1,GUARD=2,RUN=3,TAIL=4,YIELD=5,
           PLAN_CAPTURE=6,PLAN_SIZE=7,PLAN_CHOOSE=8;
reg [3:0] state;
wire uempty,ufull,rempty,rfull;
wire [8:0] uwused,urused,rwused;
wire [31:0] udata,rdata;
reg flush_upload,session_ready_mem;
wire upop=aux_write || (flush_upload && state==PICK && !uempty);
wfifo_32_32_512 u_upload(
    .rst(rst),.clkw(sd_clk),.clkr(mem_clk),
    .we(upload_valid && upload_ready),.di({upload_pixel,8'd0}),
    .re(upop),.dout(udata),.empty_flag(uempty),.full_flag(ufull),
    .wrusedw(uwused),.rdusedw(urused));
(* ASYNC_REG="TRUE" *) reg session_meta,session_sync;
reg upload_allow;
always @(posedge sd_clk or posedge rst) begin
 if(rst) begin session_meta<=0;session_sync<=0;upload_allow<=0;end
 else begin
    session_meta<=session_ready_mem;session_sync<=session_meta;
    upload_allow<=session_sync && !ufull && uwused<384;
 end
end
assign upload_ready=!upload_req && upload_allow;
reg read_kind;
wire return_to_row=aux_active && read_kind && read_valid;
reg row_pending,row_buffer_valid;
reg [23:0] row_buffer;
wire row_pop=!rempty && !row_pending && (!row_buffer_valid || row_ready);
assign row_valid=row_buffer_valid;
assign row_pixel=row_buffer;
always @(posedge sd_clk or posedge rst) begin
 if(rst) begin row_pending<=0;row_buffer_valid<=0;row_buffer<=0;end
 else begin
    if(row_buffer_valid && row_ready) row_buffer_valid<=0;
    if(row_pop) row_pending<=1;
    if(row_pending) begin row_buffer<=rdata[31:8];row_buffer_valid<=1;row_pending<=0;end
 end
end

rfifo_32_32_512 u_row(
    .rst(rst),.clkw(mem_clk),.clkr(sd_clk),
    .we(return_to_row),.di(read_data),.re(row_pop),
    .dout(rdata),.empty_flag(rempty),.full_flag(rfull),.wrusedw(rwused),.rdusedw());
(* ASYNC_REG="TRUE" *) reg req_meta,req_sync,row_meta,row_sync,cv_meta,cv_sync,ack_meta,ack_sync;
reg cache_valid_mem,ack_mem;
always @(posedge sd_clk or posedge rst) begin
    if(rst) begin cv_meta<=0;cv_sync<=0;ack_meta<=0;ack_sync<=0;end
    else begin cv_meta<=cache_valid_mem;cv_sync<=cv_meta;ack_meta<=ack_mem;ack_sync<=ack_meta;end
end
assign cache_valid=cv_sync && !upload_req;
assign row_ack=ack_sync;
always @(posedge mem_clk or posedge rst) begin
    if(rst) begin req_meta<=0;req_sync<=0;row_meta<=0;row_sync<=0;end
    else begin req_meta<=upload_req;req_sync<=req_meta;row_meta<=row_req;row_sync<=row_meta;end
end


reg [5:0] block_len,issued,returned;
reg [7:0] guard_count;
reg [20:0] uploaded,total,row_issued,row_returned;
reg [20:0] read_addr;
reg [15:0] width;
reg [15:0] source_w_mem,source_h_mem,row_index_mem;
reg [31:0] expected_pixels,row_product;
always @(posedge mem_clk or posedge rst) begin
 if(rst) begin source_w_mem<=0;source_h_mem<=0;row_index_mem<=0;expected_pixels<=0;row_product<=0;end
 else begin
    // Bundled payload is held across the synchronized request/ACK transaction.
    source_w_mem<=src_w;source_h_mem<=src_h;row_index_mem<=row_index;
    expected_pixels<=source_w_mem*source_h_mem;
    row_product<=row_index_mem*width;
 end
end
// Observation-only per-source-row signatures. Upload data is sampled at the
// actual SDRAM write command; read data at the corresponding return edge.
// The row RAM is written only after a complete upload row and read while the
// request metadata is stable. No reset is applied to the RAM itself.
reg [31:0] row_hash_mem [0:1023];
reg [31:0] expected_row_hash;
reg [31:0] write_hash,read_hash;
reg [10:0] write_x;
reg [9:0] write_row;
reg checked_row,hash_mismatch;
reg [9:0] first_bad_row;
reg [7:0] checked_count;
// Observation-only timing split: freeze the completed row and its expected
// signature, then update diagnostic flags one mem_clk later. No DMA/FIFO,
// command, ownership, pixel, or row-valid path consumes these registers.
reg hash_check_pending;
reg [31:0] completed_read_hash,completed_expected_hash;
reg [9:0] completed_row;
wire [31:0] next_write_hash={write_hash[30:0],write_hash[31]} ^ aux_data;
wire [31:0] next_read_hash={read_hash[30:0],read_hash[31]} ^ read_data;
assign checksum_status={checked_row,hash_mismatch,first_bad_row,checked_count};
always @(posedge mem_clk) begin
    expected_row_hash<=row_hash_mem[row_index_mem[9:0]];
    if(aux_write && write_x==width-1'b1)
        row_hash_mem[write_row]<=next_write_hash;
end
always @(posedge mem_clk or posedge rst) begin
    if(rst) begin
        write_hash<=0;read_hash<=0;write_x<=0;write_row<=0;
        checked_row<=0;hash_mismatch<=0;first_bad_row<=0;checked_count<=0;
        hash_check_pending<=0;completed_read_hash<=0;completed_expected_hash<=0;completed_row<=0;
    end else if(req_sync) begin
        write_hash<=0;read_hash<=0;write_x<=0;write_row<=0;
        checked_row<=0;hash_mismatch<=0;first_bad_row<=0;checked_count<=0;
        hash_check_pending<=0;completed_read_hash<=0;completed_expected_hash<=0;completed_row<=0;
    end else begin
        hash_check_pending<=0;
        if(hash_check_pending) begin
            checked_row<=1;
            if(checked_count!=8'hff) checked_count<=checked_count+1'b1;
            if(completed_read_hash!=completed_expected_hash) begin
                if(!hash_mismatch) first_bad_row<=completed_row;
                hash_mismatch<=1;
            end
        end
        if(aux_write) begin
            if(write_x==width-1'b1) begin
                write_hash<=0;write_x<=0;write_row<=write_row+1'b1;
            end else begin write_hash<=next_write_hash;write_x<=write_x+1'b1;end
        end
        if(return_to_row) begin
            if(row_returned==width-1'b1) begin
                read_hash<=0;
                hash_check_pending<=1;
                completed_read_hash<=next_read_hash;
                completed_expected_hash<=expected_row_hash;
                completed_row<=row_index_mem[9:0];
            end else read_hash<=next_read_hash;
        end
    end
end
reg row_active,error_mem;
wire permitted=init_done && !refresh_busy && !sdr_busy;
reg [20:0] upload_left_q,row_left_q;
reg [8:0] read_column_q;
reg [5:0] upload_block_q,read_block_q;
wire upload_block_ready=upload_block_q!=0 && {1'b0,urused}>=upload_block_q;
// A row can begin at any source-column address. Never span the SDRAM's
// 256-word column boundary inside an auxiliary command packet.
reg [5:0] planned_read_block;
always @* begin
    planned_read_block=row_left_q>BLOCK ? BLOCK:row_left_q[5:0];
    if(read_column_q<planned_read_block) planned_read_block=read_column_q[5:0];
end
assign aux_active=state==RUN || state==TAIL;
// A bounded burst starts only after a quiet, controller-idle acquisition.
// Own-burst busy is expected, so it must not chop this packet into individual
// one-word transactions. Refresh still pauses commands without releasing owner.
assign aux_read=state==RUN && read_kind && issued<block_len && init_done && !refresh_busy;
assign aux_write=state==RUN && !read_kind && issued<block_len && init_done && !refresh_busy;
assign aux_addr=read_kind ? read_addr : (CACHE_BASE+uploaded);
assign aux_data=udata;
assign cache_error=error_mem;
always @(posedge mem_clk or posedge rst) begin
    if(rst) begin
        state<=PICK;legacy_hold<=0;read_kind<=0;block_len<=0;issued<=0;returned<=0;guard_count<=0;
        uploaded<=0;total<=0;width<=0;row_issued<=0;row_returned<=0;read_addr<=0;
        row_active<=0;ack_mem<=0;cache_valid_mem<=0;error_mem<=0;flush_upload<=0;session_ready_mem<=0;
        upload_left_q<=0;row_left_q<=0;read_column_q<=0;upload_block_q<=0;read_block_q<=0;
    end else begin
        if(req_sync) begin
            uploaded<=0;total<=expected_pixels[20:0];width<=source_w_mem;cache_valid_mem<=0;flush_upload<=1;session_ready_mem<=0;
        end else if(flush_upload && state==PICK && uempty) begin
            flush_upload<=0;session_ready_mem<=1;uploaded<=0;
        end else if(total!=0 && uploaded==total && state==PICK) cache_valid_mem<=1;
        if(return_to_row) begin
            row_returned<=row_returned+1'b1;returned<=returned+1'b1;
            if(rfull) error_mem<=1;
            if(returned>=issued && !aux_read) error_mem<=1;
        end
        if(aux_active && !read_kind && read_valid) error_mem<=1;
        if(aux_write) begin uploaded<=uploaded+1'b1;if(uempty) error_mem<=1;end
        if(aux_read) begin read_addr<=read_addr+1'b1;row_issued<=row_issued+1'b1;end
        if(aux_read || aux_write) begin issued<=issued+1'b1;guard_count<=0;end
        if(state==PICK && !row_active && row_sync && cache_valid_mem) begin
            read_addr<=CACHE_BASE+row_product[20:0];row_issued<=0;row_returned<=0;
            row_active<=1;ack_mem<=1;
        end
        if(row_active && row_issued==width && row_returned==width && !row_sync && state==PICK) begin
            row_active<=0;ack_mem<=0;
        end
        case(state)
        PICK:begin
            issued<=0;returned<=0;guard_count<=0;
            if(!req_sync && !flush_upload && init_done) state<=PLAN_CAPTURE;
        end
        // uploaded/row_issued cannot advance outside RUN. Request metadata has
        // settled by this stage, including a row accepted on the preceding PICK.
        PLAN_CAPTURE:if(req_sync || flush_upload) state<=PICK;
            else begin
                upload_left_q<=total-uploaded;row_left_q<=width-row_issued;
                read_column_q<=9'd256-{1'b0,read_addr[7:0]};state<=PLAN_SIZE;
            end
        PLAN_SIZE:if(req_sync || flush_upload) state<=PICK;
            else begin
                upload_block_q<=upload_left_q<BLOCK ? upload_left_q[5:0]:BLOCK;
                read_block_q<=planned_read_block;state<=PLAN_CHOOSE;
            end
        PLAN_CHOOSE:begin
            if(req_sync || flush_upload || !init_done) state<=PICK;
            else begin
                if(row_active && row_left_q!=0 && rwused<384) begin
                    read_kind<=1;block_len<=read_block_q;
                    legacy_hold<=1;state<=WAIT_LEGACY;
                end else if(upload_left_q!=0 && !uempty && upload_block_ready) begin
                    read_kind<=0;
                    // Coalesce slow BMP arrivals. Previously any single FIFO
                    // word could seize SDRAM and force another row turnaround.
                    block_len<=upload_block_q;
                    legacy_hold<=1;state<=WAIT_LEGACY;
                end else state<=PICK;
            end
        end
        WAIT_LEGACY:if(!legacy_busy) begin guard_count<=0;state<=GUARD;end
        GUARD:if(legacy_busy || !permitted || read_valid) begin guard_count<=0;state<=WAIT_LEGACY;end
            else if(guard_count==ACQUIRE_QUIET-1) begin state<=RUN;guard_count<=0;end
            else guard_count<=guard_count+1'b1;
        RUN:if(issued==block_len) begin state<=TAIL;guard_count<=0;end
        TAIL:begin
            if(!permitted || read_valid) guard_count<=0;
            else if(guard_count<RELEASE_QUIET) guard_count<=guard_count+1'b1;
            if(guard_count==RELEASE_QUIET && permitted && !read_valid &&
               (!read_kind || returned==issued)) begin
                legacy_hold<=0;guard_count<=0;state<=YIELD;
            end
        end
        YIELD:if(guard_count==GAP-1) begin guard_count<=0;state<=PICK;end
            else guard_count<=guard_count+1'b1;
        default:state<=PICK;
        endcase
    end
end
endmodule

// Observation only. Inputs are sampled together; none of these outputs gates
// arbitration, FIFOs, image payload, or display timing.
module zoom_memory_probe(
 input wire clk,rst,read_cmd,write_cmd,read_return,cache_owner,cache_error,
 output reg [47:0] status
);
reg rc,wc,rv,owner,ce;
reg [9:0] legacy_pending,cache_pending;
reg [15:0] issued,returned;
reg stray,handoff,collision,overflow,cache_fault;
wire [10:0] total_pending={1'b0,legacy_pending}+{1'b0,cache_pending};
always @(posedge clk or posedge rst) begin
 if(rst) begin
  rc<=0;wc<=0;rv<=0;owner<=0;ce<=0;legacy_pending<=0;cache_pending<=0;
  issued<=0;returned<=0;stray<=0;handoff<=0;collision<=0;overflow<=0;cache_fault<=0;status<=0;
 end else begin
  rc<=read_cmd;wc<=write_cmd;rv<=read_return;owner<=cache_owner;ce<=cache_error;
  if(rc) issued<=issued+1'b1;
  if(rv) returned<=returned+1'b1;
  if(rc && wc) collision<=1;
  if(ce) cache_fault<=1;
  if(rv && total_pending==0 && !rc) stray<=1;
  if((owner && legacy_pending!=0) || (!owner && cache_pending!=0)) handoff<=1;
  if(owner) begin
   case({rc,rv})
    2'b10:if(cache_pending==1023) overflow<=1;else cache_pending<=cache_pending+1'b1;
    2'b01:if(cache_pending!=0) cache_pending<=cache_pending-1'b1;else stray<=1;
    default: ;
   endcase
  end else begin
   case({rc,rv})
    2'b10:if(legacy_pending==1023) overflow<=1;else legacy_pending<=legacy_pending+1'b1;
    2'b01:if(legacy_pending!=0) legacy_pending<=legacy_pending-1'b1;else stray<=1;
    default: ;
   endcase
  end
  status<={cache_fault,stray,handoff,collision,overflow,total_pending,issued,returned};
 end
end
endmodule
`default_nettype wire
