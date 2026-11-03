module bmp_read(
    input                       clk,
    input                       rst,
    output                      ready,

    // 上电扫描：从 scan_start_sector 开始，顺序寻找前 scan_target_count 张 BMP
    input                       scan_start,
    input  [31:0]               scan_start_sector,
    input  [31:0]               scan_max_sector,
    input  [2:0]                scan_target_count,
    output reg                  scan_done,
    output reg                  scan_found_valid,
    output reg [31:0]           scan_found_sector,
    output reg [15:0]           scan_found_signature,
    output reg [2:0]            scan_found_total,

    // 按指定扇区加载一张图到 SDRAM
    input                       load_start,
    input  [31:0]               load_sector,
    output reg                  load_done,
    output reg                  load_error,
    output reg [3:0]             load_error_code,
    output reg [1:0]             load_error_retries,
    output reg [19:0]            load_error_sector,
    output reg [15:0]            load_error_signature,

    input                       sd_init_done,
    output reg [3:0]            state_code,
    input  [15:0]               bmp_width,
    input  [15:0]               bmp_height,

    output reg                  write_req,
    input                       write_req_ack,

    output reg                  sd_sec_read,
    output reg [31:0]           sd_sec_read_addr,
    input  [7:0]                sd_sec_read_data,
    input                       sd_sec_read_data_valid,
    input                       sd_sec_read_end,

    output reg                  bmp_data_wr_en,
    output wire [15:0] src_w, src_h,
    input wire src_accept,
    output reg [23:0]           bmp_data
);

localparam ST_IDLE      = 3'd0;
localparam ST_SCAN      = 3'd1;
localparam ST_LOAD_HDR  = 3'd2;
localparam ST_LOAD_WAIT = 3'd3;
localparam ST_LOAD_DATA = 3'd4;
localparam ST_LOAD_RELEASE = 3'd5;
localparam ST_DRAIN=3'd6, ST_DRAIN_READ=3'd7;

reg [2:0]  state;
reg [9:0]  rd_cnt;

reg [7:0]  header_0;
reg [7:0]  header_1;
reg [31:0] file_len;
reg [31:0] pixel_offset;
reg [31:0] width;
reg [31:0] height;
reg [15:0] bit_count;
reg [31:0] compression;

reg [31:0] scan_sector;
reg [31:0] load_sector_latched;
reg [1:0]  load_retry_count;
reg [31:0] bmp_len_cnt;
reg [1:0]  bmp_byte_idx;

wire header_match;
wire bmp_data_valid;
reg [31:0] file_sector_count;
wire [31:0] next_scan_sector_if_match;
wire [31:0] next_scan_sector_if_miss;

assign ready = (state == ST_IDLE);
assign src_w=width[15:0];
assign src_h=height[15:0];
reg [31:0] row_bytes,row_stride,pixel_size,pixel_end;
reg header_match_q;
// Header fields settle by byte 34; decisions occur only after byte 511.
// Pipeline frame-constant arithmetic rather than placing a multiply/add/compare
// chain on the 100 MHz sector request path. Invalid large dimensions are rejected.
always @(posedge clk or posedge rst) begin
    if(rst) begin row_bytes<=0; row_stride<=0; pixel_size<=0; pixel_end<=0; header_match_q<=0; end
    else begin
        row_bytes<={21'd0,width[10:0]}*32'd3;
        row_stride<=(row_bytes+32'd3)&32'hfffffffc;
        pixel_size<=row_stride[12:0]*height[10:0];
        pixel_end<=pixel_offset+pixel_size;
        header_match_q<=(header_0=="B") && (header_1=="M") &&
    width>=1 && width<=1024 && height>=1 && height<=1024 &&
    bit_count==24 && compression==0 && pixel_offset>=54 &&
    pixel_end>=pixel_offset && file_len>=pixel_end;
    end
end
assign header_match=header_match_q;
reg [7:0] sector_mem[0:511];
reg [7:0] sector_q;
reg [8:0] recv_idx, drain_idx;
reg [31:0] row_byte;
wire advance=(state==ST_DRAIN) && (!bmp_data_wr_en || src_accept);
assign bmp_data_valid=advance && bmp_len_cnt>=pixel_offset &&
    bmp_len_cnt<pixel_end && row_byte<row_bytes;
always @(posedge clk) begin
    if(state==ST_LOAD_DATA && sd_sec_read_data_valid)
        sector_mem[recv_idx]<=sd_sec_read_data;
    if(state==ST_DRAIN_READ) sector_q<=sector_mem[drain_idx];
end
always @(posedge clk or posedge rst) begin
    if(rst) recv_idx<=0;
    else if(state!=ST_LOAD_DATA) recv_idx<=0;
    else if(sd_sec_read_data_valid) recv_idx<=recv_idx+1'b1;
end
// Header bytes 2..5 set file_len; scan decisions occur after the full
// 512-byte sector. Precompute one cycle later to break the length ->
// rounding -> sector address -> end-of-scan comparison timing path.
// Keep the original 32-bit addition (including its overflow semantics).
always @(posedge clk or posedge rst) begin
    if (rst)
        file_sector_count <= 32'd1;
    else
        file_sector_count <= (file_len == 32'd0) ? 32'd1 : ((file_len + 32'd511) >> 9);
end
assign next_scan_sector_if_match = scan_sector + file_sector_count;
assign next_scan_sector_if_miss  = scan_sector + 32'd1;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        rd_cnt <= 10'd0;
    end else if ((state == ST_SCAN) || (state == ST_LOAD_HDR)) begin
        if (sd_sec_read_data_valid)
            rd_cnt <= rd_cnt + 10'd1;
        else if (sd_sec_read_end)
            rd_cnt <= 10'd0;
    end else begin
        rd_cnt <= 10'd0;
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        header_0     <= 8'd0;
        header_1     <= 8'd0;
        file_len     <= 32'd0;
        pixel_offset <= 32'd54;
        width        <= 32'd0;
        height       <= 32'd0;
        bit_count    <= 16'd0;
        compression  <= 32'd0;
    end else if (((state == ST_SCAN) || (state == ST_LOAD_HDR)) && sd_sec_read_data_valid) begin
        case (rd_cnt)
            10'd0 : header_0 <= sd_sec_read_data;
            10'd1 : header_1 <= sd_sec_read_data;

            10'd2 : file_len[7:0] <= sd_sec_read_data;
            10'd3 : file_len[15:8] <= sd_sec_read_data;
            10'd4 : file_len[23:16] <= sd_sec_read_data;
            10'd5 : file_len[31:24] <= sd_sec_read_data;

            10'd10: pixel_offset[7:0] <= sd_sec_read_data;
            10'd11: pixel_offset[15:8] <= sd_sec_read_data;
            10'd12: pixel_offset[23:16] <= sd_sec_read_data;
            10'd13: pixel_offset[31:24] <= sd_sec_read_data;

            10'd18: width[7:0] <= sd_sec_read_data;
            10'd19: width[15:8] <= sd_sec_read_data;
            10'd20: width[23:16] <= sd_sec_read_data;
            10'd21: width[31:24] <= sd_sec_read_data;

            10'd22: height[7:0] <= sd_sec_read_data;
            10'd23: height[15:8] <= sd_sec_read_data;
            10'd24: height[23:16] <= sd_sec_read_data;
            10'd25: height[31:24] <= sd_sec_read_data;

            10'd28: bit_count[7:0] <= sd_sec_read_data;
            10'd29: bit_count[15:8] <= sd_sec_read_data;

            10'd30: compression[7:0] <= sd_sec_read_data;
            10'd31: compression[15:8] <= sd_sec_read_data;
            10'd32: compression[23:16] <= sd_sec_read_data;
            10'd33: compression[31:24] <= sd_sec_read_data;
            default: ;
        endcase
    end
end

// Drain one buffered sector; pending pixel is held until ready.
always @(posedge clk or posedge rst) begin
    if(rst) begin
        bmp_len_cnt<=0; row_byte<=0; bmp_byte_idx<=0;
        bmp_data_wr_en<=0; bmp_data<=0;
    end else begin
        if(bmp_data_wr_en && src_accept) bmp_data_wr_en<=0;
        if(state!=ST_LOAD_DATA && state!=ST_DRAIN && state!=ST_DRAIN_READ) begin
            bmp_len_cnt<=0; row_byte<=0; bmp_byte_idx<=0;
        end else if(advance) begin
            bmp_len_cnt<=bmp_len_cnt+1'b1;
            if(bmp_len_cnt>=pixel_offset && bmp_len_cnt<pixel_end) begin
                if(row_byte==row_stride-1) row_byte<=0;
                else row_byte<=row_byte+1'b1;
            end
            if(bmp_data_valid) begin
                case(bmp_byte_idx)
                    0: bmp_data[7:0]<=sector_q;
                    1: bmp_data[15:8]<=sector_q;
                    2: begin bmp_data[23:16]<=sector_q; bmp_data_wr_en<=1; end
                endcase
                bmp_byte_idx<=bmp_byte_idx==2 ? 0 : bmp_byte_idx+1'b1;
            end
        end
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        drain_idx<=0;
        state             <= ST_IDLE;
        state_code        <= 4'd0;
        sd_sec_read       <= 1'b0;
        sd_sec_read_addr  <= 32'd0;
        write_req         <= 1'b0;
        scan_done         <= 1'b0;
        load_done         <= 1'b0;
        load_error        <= 1'b0;
        load_error_code   <= 4'd0;
        load_error_retries <= 2'd0;
        load_error_sector <= 20'd0;
        load_error_signature <= 16'd0;
        scan_found_valid  <= 1'b0;
        scan_found_sector <= 32'd0;
        scan_found_signature <= 16'd0;
        scan_found_total  <= 3'd0;
        scan_sector       <= 32'd0;
        load_sector_latched <= 32'd0;
        load_retry_count <= 2'd0;
    end else if (!sd_init_done) begin
        drain_idx<=0;
        state             <= ST_IDLE;
        state_code        <= 4'd0;
        sd_sec_read       <= 1'b0;
        sd_sec_read_addr  <= 32'd0;
        write_req         <= 1'b0;
        scan_done         <= 1'b0;
        load_done         <= 1'b0;
        load_error        <= 1'b0;
        load_error_code   <= 4'd0;
        load_error_retries <= 2'd0;
        load_error_sector <= 20'd0;
        load_error_signature <= 16'd0;
        scan_found_valid  <= 1'b0;
        scan_found_sector <= 32'd0;
        scan_found_signature <= 16'd0;
        scan_found_total  <= 3'd0;
        scan_sector       <= 32'd0;
        load_sector_latched <= 32'd0;
        load_retry_count <= 2'd0;
    end else begin
        scan_found_valid <= 1'b0;
        load_done        <= 1'b0;
        load_error       <= 1'b0;

        case (state)
            ST_IDLE: begin
                state_code  <= 4'd1;
                sd_sec_read <= 1'b0;
                write_req   <= 1'b0;

                if (scan_start) begin
                    scan_done        <= 1'b0;
                    scan_found_total <= 3'd0;
                    scan_sector      <= scan_start_sector;
                    sd_sec_read_addr <= scan_start_sector;
                    state            <= ST_SCAN;
                end else if (load_start) begin
                    load_sector_latched <= load_sector;
                    sd_sec_read_addr    <= load_sector;
                    load_error_code     <= 4'd0;
                    load_error_retries  <= 2'd0;
                    load_error_sector   <= load_sector[19:0];
                    load_error_signature <= 16'd0;
                    load_retry_count    <= 2'd0;
                    state               <= ST_LOAD_HDR;
                end
            end

            ST_SCAN: begin
                state_code  <= 4'd2;
                sd_sec_read <= 1'b1;

                if (sd_sec_read_end) begin
                    sd_sec_read <= 1'b0;

                    if (header_match) begin
                        scan_found_valid  <= 1'b1;
                        scan_found_sector <= scan_sector;
                        scan_found_signature <= {header_0, header_1};
                        scan_found_total  <= scan_found_total + 3'd1;

                        if ((scan_found_total + 3'd1 >= scan_target_count) || (next_scan_sector_if_match > scan_max_sector)) begin
                            scan_done        <= 1'b1;
                            state            <= ST_IDLE;
                            sd_sec_read_addr <= next_scan_sector_if_match;
                            scan_sector      <= next_scan_sector_if_match;
                        end else begin
                            sd_sec_read_addr <= next_scan_sector_if_match;
                            scan_sector      <= next_scan_sector_if_match;
                        end
                    end else begin
                        if (scan_sector >= scan_max_sector) begin
                            scan_done <= 1'b1;
                            state     <= ST_IDLE;
                        end else begin
                            sd_sec_read_addr <= next_scan_sector_if_miss;
                            scan_sector      <= next_scan_sector_if_miss;
                        end
                    end
                end
            end

            ST_LOAD_HDR: begin
                state_code  <= 4'd2;
                sd_sec_read <= 1'b1;

                if (sd_sec_read_end) begin
                    sd_sec_read <= 1'b0;
                    if (header_match) begin
                        load_retry_count <= 2'd0;
                        write_req        <= 1'b1;
                        sd_sec_read_addr <= load_sector_latched;
                        state            <= ST_LOAD_WAIT;
                    end else if (load_retry_count < 2'd2) begin
                        // Retry transient CMD17/header corruption twice before failing.
                        load_retry_count <= load_retry_count + 2'd1;
                        sd_sec_read      <= 1'b0;
                        sd_sec_read_addr <= load_sector_latched;
                    end else begin
                        load_error <= 1'b1;
                        load_error_retries <= load_retry_count;
                        load_error_code <= {1'b0,
                                            (bit_count != 16'd24) || (compression != 32'd0),
                                            (width[15:0] != bmp_width) || (height[15:0] != bmp_height),
                                            (header_0 != "B") || (header_1 != "M")};
                        load_error_signature <= {header_0, header_1};
                        state <= ST_IDLE;
                    end
                end
            end

            ST_LOAD_WAIT: begin
                state_code <= 4'd3;
                if (write_req_ack) begin
                    write_req <= 1'b0;
                    state     <= ST_LOAD_RELEASE;
                end
            end

            ST_LOAD_RELEASE: begin
                // ACK low confirms that the memory controller released FIFO clear.
                // Do not request sector data or emit pixels while ACK remains high.
                state_code  <= 4'd3;
                write_req   <= 1'b0;
                sd_sec_read <= 1'b0;
                if (!write_req_ack)
                    state <= ST_LOAD_DATA;
            end

            ST_LOAD_DATA: begin
                state_code<=4'd4; sd_sec_read<=1;
                if(sd_sec_read_end) begin
                    sd_sec_read<=0; drain_idx<=0; state<=ST_DRAIN_READ;
                end
            end
            ST_DRAIN_READ: begin sd_sec_read<=0; state<=ST_DRAIN; end
            ST_DRAIN: begin
                sd_sec_read<=0;
                if(advance) begin
                    if(drain_idx==511) begin
                        if(bmp_len_cnt+1>=file_len) begin
                            load_done<=1; state<=ST_IDLE;
                        end else begin
                            sd_sec_read_addr<=sd_sec_read_addr+1'b1;
                            state<=ST_LOAD_DATA;
                        end
                    end else begin drain_idx<=drain_idx+1'b1; state<=ST_DRAIN_READ; end
                end
            end

            default: begin
                state       <= ST_IDLE;
                state_code  <= 4'd1;
                sd_sec_read <= 1'b0;
                write_req   <= 1'b0;
            end
        endcase
    end
end

endmodule
