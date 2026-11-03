`timescale 1ns/1ps
module frame_read_write
#
(
	parameter MEM_DATA_BITS          = 32,
	parameter READ_DATA_BITS         = 32,
	parameter WRITE_DATA_BITS        = 32,
	parameter ADDR_BITS              = 21,
	parameter BURST_BITS             = 9,//
	parameter BURST_SIZE             = 256,
	parameter WRITE_V_FLIP           = 1,      // 1: vertical flip when writing TF/BMP frame into SDRAM
	parameter FRAME_WIDTH            = 640,
	parameter FRAME_HEIGHT           = 480
) 
(
	input wire auxiliary_hold,
    output wire legacy_busy,
	input                            rst,                  
	input                            mem_clk,                    // external memory controller user interface clock
	input							 Sdr_init_done,
	input							 Sdr_init_ref_vld,
    input							 Sdr_busy,
	
    /*
    output                           rd_burst_req,               // to external memory controller,send out a burst read request
	output[BURST_BITS - 1:0]         rd_burst_len,               // to external memory controller,data length of the burst read request, not bytes
	output[ADDR_BITS - 1:0]          rd_burst_addr,              // to external memory controller,base address of the burst read request 
	input                            rd_burst_data_valid,        // from external memory controller,read data valid 
	input[MEM_DATA_BITS - 1:0]       rd_burst_data,              // from external memory controller,read request data
	input                            rd_burst_finish,            // from external memory controller,burst read finish
	*/
	output							 App_rd_en,
	output[ADDR_BITS - 1:0]			 App_rd_addr,
	input							 Sdr_rd_en,					 //read_data_valid
	input[MEM_DATA_BITS - 1:0]		 Sdr_rd_dout,
	
	input                            read_clk,                   // data read module clock
	input                            read_req,                   // data read module read request,keep '1' until read_req_ack = '1'
	output                           read_req_ack,               // data read module read request response
	output                           read_finish,                // data read module read request finish
	input[ADDR_BITS - 1:0]           read_addr_0,                // data read module read request base address 0, used when read_addr_index = 0
	input[ADDR_BITS - 1:0]           read_addr_1,                // data read module read request base address 1, used when read_addr_index = 1
	input[ADDR_BITS - 1:0]           read_addr_2,                // data read module read request base address 1, used when read_addr_index = 2
	input[ADDR_BITS - 1:0]           read_addr_3,                // data read module read request base address 1, used when read_addr_index = 3
    input [10:0] read_status, // coherent metadata already in mem_clk domain
    output wire [5:0] read_frame_status,
	input[1:0]                       read_addr_index,            // select valid base address from read_addr_0 read_addr_1 read_addr_2 read_addr_3
	input[ADDR_BITS - 1:0]           read_len,                   // data read module read request data length
	input                            read_en,                    // data read module read request for one data, read_data valid next clock
	output[READ_DATA_BITS  - 1:0]    read_data,                  // read data
	/*
	output                           wr_burst_req,               // to external memory controller,send out a burst write request
	output[BURST_BITS - 1:0]         wr_burst_len,               // to external memory controller,data length of the burst write request, not bytes
	output[ADDR_BITS - 1:0]          wr_burst_addr,              // to external memory controller,base address of the burst write request 
	input                            wr_burst_data_req,          // from external memory controller,write data request ,before data 1 clock
	output[MEM_DATA_BITS - 1:0]      wr_burst_data,              // to external memory controller,write data
	input                            wr_burst_finish,            // from external memory controller,burst write finish
	*/
	output							 App_wr_en,
	output[ADDR_BITS - 1:0]			 App_wr_addr,
	output[MEM_DATA_BITS - 1:0]	 App_wr_din,
	output[3:0]						 App_wr_dm,
	
	//
	input                            write_clk,                  // data write module clock
	input                            write_req,                  // data write module write request,keep '1' until read_req_ack = '1'
	output                           write_req_ack,              // data write module write request response
	output                           write_finish,               // data write module write request finish
	input[ADDR_BITS - 1:0]           write_addr_0,               // data write module write request base address 0, used when write_addr_index = 0
	input[ADDR_BITS - 1:0]           write_addr_1,               // data write module write request base address 1, used when write_addr_index = 1
	input[ADDR_BITS - 1:0]           write_addr_2,               // data write module write request base address 1, used when write_addr_index = 2
	input[ADDR_BITS - 1:0]           write_addr_3,               // data write module write request base address 1, used when write_addr_index = 3
	input[1:0]                       write_addr_index,           // select valid base address from write_addr_0 write_addr_1 write_addr_2 write_addr_3
	input[ADDR_BITS - 1:0]           write_len,                  // data write module write request data length
	output wire [8:0] write_usedw,
    output wire [1:0] diagnostic_read,
	input                            write_en,                   // data write module write request for one data
    output wire [79:0] storage_diag_mem,
    output wire [2:0] storage_diag_write,
	input[WRITE_DATA_BITS - 1:0]     write_data                 // write data

);
wire[8:0]                           wrusedw;                    // write used words
wire[8:0]                           rdusedw;                    // read used words

wire 								 App_rd_busy;
wire								 App_wr_busy;

wire                                 read_fifo_aclr;             // fifo Asynchronous clear
wire                                 write_fifo_aclr;            // fifo Asynchronous clear

wire O_wr_busy;
wire O_rd_busy;

// Sdr_rd_en is routed to this client only while it owns the SDRAM interface.
// Keep ownership until every issued read has actually returned. The legacy
// reader's ten-clock tail remains intact, but is no longer the only proof of
// drain. A controller-busy level means an outstanding transaction, not a
// per-word ready: test it before starting the next legacy burst, never inside.
reg [9:0] legacy_reads_pending;
reg legacy_return_fault;
always @(posedge mem_clk or posedge rst) begin
    if(rst) begin legacy_reads_pending<=0;legacy_return_fault<=0;end
    else case({App_rd_en,Sdr_rd_en})
        2'b10:if(legacy_reads_pending==1023) legacy_return_fault<=1;
              else legacy_reads_pending<=legacy_reads_pending+1'b1;
        2'b01:if(legacy_reads_pending==0) legacy_return_fault<=1;
              else legacy_reads_pending<=legacy_reads_pending-1'b1;
        default: ;
    endcase
end
wire legacy_read_drain=legacy_reads_pending!=0 || legacy_return_fault;
wire controller_wait=Sdr_busy || Sdr_init_ref_vld;
assign legacy_busy=O_wr_busy || O_rd_busy || legacy_read_drain ||
                   controller_wait || App_rd_en || App_wr_en;
assign App_wr_busy=O_wr_busy || auxiliary_hold || controller_wait || legacy_read_drain;
assign App_rd_busy=O_rd_busy || auxiliary_hold || controller_wait || legacy_read_drain;
assign App_wr_dm = 4'b0000;
// Observation only: these signals never gate FIFO or memory control.
wire diag_fifo_full, diag_fifo_empty;
wire [ADDR_BITS-1:0] diag_write_count;
wire [3:0] diag_write_state;
wire [BURST_BITS-1:0] diag_burst_count;
reg [19:0] diag_fifo_pop_count;
reg diag_underflow, diag_finish_seen;
reg diag_req_prev, diag_overflow, diag_reset_write;
always @(posedge write_clk or posedge rst) begin
    if (rst) begin
        diag_req_prev<=0; diag_overflow<=0; diag_reset_write<=0;
    end else begin
        diag_req_prev<=write_req;
        if (write_req && !diag_req_prev) begin
            diag_overflow<=0; diag_reset_write<=0;
        end else begin
            if (write_en && diag_fifo_full && !write_fifo_aclr) diag_overflow<=1;
            if (write_en && write_fifo_aclr) diag_reset_write<=1;
        end
    end
end
always @(posedge mem_clk or posedge rst) begin
    if (rst) begin
        diag_fifo_pop_count<=0; diag_underflow<=0; diag_finish_seen<=0;
    end else if (write_fifo_aclr) begin
        diag_fifo_pop_count<=0; diag_underflow<=0; diag_finish_seen<=0;
    end else begin
        if (App_wr_en && !diag_fifo_empty) diag_fifo_pop_count<=diag_fifo_pop_count+1'b1;
        if (App_wr_en && diag_fifo_empty) diag_underflow<=1;
        if (write_finish) diag_finish_seen<=1;
    end
end
// [75:68]flags, [67:64]state, [59:50]burst, [49:40]used,
// [39:20]nonempty FIFO read requests, [19:0]completed-burst word count.
wire [19:0] diag_commits = diag_write_count;
wire [9:0] diag_used = rdusedw;
wire [9:0] diag_burst = diag_burst_count;
reg [79:0] storage_diag_mem_q;
always @(posedge mem_clk or posedge rst) begin
    if(rst) storage_diag_mem_q<=0;
    else storage_diag_mem_q<={4'd0,diag_finish_seen,diag_underflow,
        App_rd_busy,App_wr_busy,Sdr_busy,Sdr_init_done,write_finish,
        write_fifo_aclr,diag_write_state,4'd0,diag_burst,diag_used,
        diag_fifo_pop_count,diag_commits};
end
assign storage_diag_mem=storage_diag_mem_q;
assign storage_diag_write = {diag_reset_write, diag_overflow, diag_fifo_full};

//instantiate an asynchronous FIFO 
wfifo_32_32_512 write_buf
	(
	.clkr                      	(mem_clk                  ),          // Read side clock
	.clkw                      	(write_clk                ),          // Write side clock
	.rst                       	(write_fifo_aclr          ),          // Asynchronous clear
	.we                      	(write_en                 ),          // Write Request
	.re                      	(App_wr_en        		  ),          // Read Request
	.di                       	(write_data               ),          // Input Data
	.empty_flag                 (diag_fifo_empty),          // Read side Empty flag
	.full_flag                  (diag_fifo_full),          // Write side Full flag
	.wrusedw(write_usedw),          // Read Used Words
	.rdusedw                	(rdusedw                  ),          // Write Used Words
	.dout                       (App_wr_din		          )
);

frame_fifo_write
#
(
	.MEM_DATA_BITS              (MEM_DATA_BITS            ),
	.ADDR_BITS                  (ADDR_BITS                ),
	.BURST_BITS                 (BURST_BITS               ),
	.BURST_SIZE                 (BURST_SIZE               ),
	.WRITE_V_FLIP               (WRITE_V_FLIP             ),
	.FRAME_WIDTH                (FRAME_WIDTH              ),
	.FRAME_HEIGHT               (FRAME_HEIGHT             )
) 
frame_fifo_write_m0              
(  
	.rst                        (rst                      ),
	.mem_clk                    (mem_clk                  ),
    .Sdr_init_done				(Sdr_init_done),
	.Sdr_init_ref_vld			(Sdr_init_ref_vld),
    .Sdr_busy					(Sdr_busy),
	.App_rd_busy				(App_rd_busy),
    .O_wr_busy					(O_wr_busy),
	
	.App_wr_en					(App_wr_en),
    .App_wr_addr				(App_wr_addr),
	.write_req                  (write_req                ),
	.write_req_ack              (write_req_ack            ),
    .diag_write_count(diag_write_count), .diag_write_state(diag_write_state),
    .diag_burst_count(diag_burst_count),
	.write_finish               (write_finish             ),
	.write_addr_0               (write_addr_0             ),
	.write_addr_1               (write_addr_1             ),
	.write_addr_2               (write_addr_2             ),
	.write_addr_3               (write_addr_3             ),
	.write_addr_index           (write_addr_index         ),    
	.write_len                  (write_len                ),
	.fifo_aclr                  (write_fifo_aclr          ),
	.rdusedw                 	({1'b0,rdusedw}                  )
);

// Read-side diagnostics are clocked where FIFO consumption occurs.
wire diagnostic_read_empty;
reg diagnostic_read_req_prev,diagnostic_read_underflow,diagnostic_last_underflow;
always @(posedge read_clk or posedge rst) begin
    if(rst) begin
        diagnostic_read_req_prev<=0;diagnostic_read_underflow<=0;diagnostic_last_underflow<=0;
    end else begin
        diagnostic_read_req_prev<=read_req;
        if(read_req && !diagnostic_read_req_prev) begin
            diagnostic_last_underflow<=diagnostic_read_underflow;
            diagnostic_read_underflow<=0;
        end else if(read_en && diagnostic_read_empty) diagnostic_read_underflow<=1;
    end
end
assign diagnostic_read={diagnostic_read_underflow|diagnostic_last_underflow,diagnostic_read_empty};
//instantiate an asynchronous FIFO
rfifo_32_32_512 read_buf
	(
	.clkr                     	(read_clk                   ),          // Read side clock
	.clkw                     	(mem_clk                    ),          // Write side clock
	.rst                      	(read_fifo_aclr             ),          // Asynchronous clear
	.we                     	(Sdr_rd_en       			),          // Write Request
	.re                     	(read_en                    ),          // Read Request
	.di                      	(Sdr_rd_dout                ),          // Input Data
	.empty_flag(diagnostic_read_empty),          // Read side Empty flag
	.full_flag					(                           ),          // Write side Full flag
	.wrusedw                	(wrusedw         	  	  		 ),          // Read Used Words
	.rdusedw                	(                  			 ),          // Write Used Words
	.dout						(read_data                  )
);

frame_fifo_read
#
(
	.MEM_DATA_BITS              (MEM_DATA_BITS            ),
	.ADDR_BITS                  (ADDR_BITS                ),
	.BURST_BITS                 (BURST_BITS               ),
	.BURST_SIZE                 (BURST_SIZE               )
)
frame_fifo_read_m0
(
    .read_status(read_status), .read_frame_status(read_frame_status),
	.rst                        (rst                      ),
	.mem_clk                    (mem_clk                  ),
    .Sdr_init_done				(Sdr_init_done),
	.Sdr_init_ref_vld			(Sdr_init_ref_vld),
    .Sdr_busy					(Sdr_busy),
    .Sdr_rd_en					(Sdr_rd_en),
	.App_wr_busy				(App_wr_busy),
    .O_rd_busy					(O_rd_busy),
	
    .App_rd_en					(App_rd_en),
    .App_rd_addr				(App_rd_addr),
	.read_req                   (read_req                 ),
	.read_req_ack               (read_req_ack             ),
	.read_finish                (read_finish              ),
	.read_addr_0                (read_addr_0              ),
	.read_addr_1                (read_addr_1              ),
	.read_addr_2                (read_addr_2              ),
	.read_addr_3                (read_addr_3              ),
	.read_addr_index            (read_addr_index          ),    
	.read_len                   (read_len                 ),
	.fifo_aclr                  (read_fifo_aclr           ),
	.wrusedw                	({1'b0,wrusedw}                  )
);

endmodule
