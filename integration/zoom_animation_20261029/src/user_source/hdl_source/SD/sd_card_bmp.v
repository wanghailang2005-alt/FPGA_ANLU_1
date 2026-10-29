
module sd_card_bmp #(
    parameter integer CLK_FREQ_HZ       = 100_000_000,
    parameter [31:0]  SCAN_START_SECTOR = 32'd0,
    parameter [31:0]  SCAN_MAX_SECTOR   = 32'd131071,
    parameter [2:0]   SCAN_TARGET_COUNT = 3'd4
)(
    input                       clk,
    input                       rst,
    input                       key_next,
    input                       key_auto,
    input [1:0] scale_mode,
    input interpolation,
    input cache_valid,cache_upload_ready,
    output wire cache_upload_req,cache_upload_valid,
    output wire [23:0] cache_upload_pixel,
    output wire [15:0] cache_source_w,cache_source_h,
    output wire animation_active,
    output wire cache_row_req,
    output wire [15:0] cache_row_index,
    input wire cache_row_ack,cache_row_valid,
    input wire [23:0] cache_row_pixel,
    output wire cache_row_ready,
    input diagnostic_gray_requested,
    output wire [79:0] diagnostic_source,
    input [8:0] write_fifo_usedw,
    input transition_dark_toggle,
    input transition_done_toggle,
    output reg transition_req_toggle,
    output reg transition_commit_toggle,
    output [3:0]                state_code,
    output [19:0]               pixel_count_debug,
    input  [15:0]               bmp_width,
    input  [15:0]               bmp_height,
    output reg                  display_valid,
    // SD-domain coherent metadata: {auto,valid,selected bank,tag1,tag0}.
    output wire [8:0]           osd_status,

    input [79:0] storage_diag_sd,
    input [2:0] storage_diag_write,
    input                       write_finish_toggle,
    output wire [1:0] write_buf_idx,
    output reg [1:0]            disp_buf_idx,

    output                      write_req,
    input                       write_req_ack,
    output                      write_en,
    output [31:0]               write_data,
    output                      SD_nCS,
    output                      SD_DCLK,
    output                      SD_MOSI,
    input                       SD_MISO
);

reg [1:0] normal_write_buf_idx;

// Return ACK is held by the memory domain until write_req is revoked.
// Only the first synchronizer stage consumes the raw cross-domain level.
(* ASYNC_REG="TRUE" *) reg write_ack_meta, write_ack_sync;
always @(posedge clk or posedge rst) begin
    if (rst) begin write_ack_meta<=0; write_ack_sync<=0; end
    else begin write_ack_meta<=write_req_ack; write_ack_sync<=write_ack_meta; end
end
wire key_next_press;
wire key_auto_press;

wire             sd_sec_read;
wire [31:0]      sd_sec_read_addr;
wire [7:0]       sd_sec_read_data;
wire             sd_sec_read_data_valid;
wire             sd_sec_read_end;
wire [3:0]       state_code_i;
wire             bmp_data_wr_en;
wire [23:0]      bmp_data;
wire             sd_init_done;
wire             bmp_ready;
wire             bmp_load_done;
wire             bmp_load_error;
wire [3:0]       bmp_load_error_code;
wire [1:0]       bmp_load_error_retries;
wire [19:0]      bmp_load_error_sector;
wire [15:0]      bmp_load_error_signature;
wire             scan_done;
wire             scan_found_valid;
wire [31:0]      scan_found_sector;
wire [15:0]      scan_found_signature;
wire [2:0]       scan_found_total;

reg              scan_start_pulse;
reg              load_start_pulse;
reg [31:0]       load_sector;
reg              scan_kicked;
reg              first_image_committed;
reg              auto_play_en;
reg [31:0]       auto_cnt;
reg [2:0]        img_found_count;
reg [1:0]        img_idx;              // 当前真正显示中的图片编号
reg [1:0]        load_idx;             // 当前正在写入的图片编号
reg [1:0]        pending_buf_idx;      // 当前正在写入的目标缓冲区
reg [31:0]       img_sector0;
reg [31:0]       img_sector1;
reg [31:0]       img_sector2;
reg [31:0]       img_sector3;
reg [1:0] osd_tag0, osd_tag1;
assign osd_status = {transition_commit_toggle, auto_play_en, display_valid, disp_buf_idx, osd_tag1, osd_tag0};
reg transition_waiting, transition_active;
reg [2:0] dark_sync, done_sync;
always @(posedge clk or posedge rst) begin
    if (rst) begin dark_sync<=0; done_sync<=0; end
    else begin
        dark_sync <= {dark_sync[1:0], transition_dark_toggle};
        done_sync <= {done_sync[1:0], transition_done_toggle};
    end
end
reg              next_req_pending;
reg              load_busy;
reg [18:0]       pixel_write_count;

// bmp_ready 先表示“源文件读取/送 FIFO 完成”；真正切显示要等 write_finish_toggle 同步后
reg              source_done_seen;
reg              write_done_seen;
reg              load_error_seen;
reg [19:0]       load_error_sector_seen;
reg [15:0]       scan_first_signature_seen;
reg [15:0]       load_error_signature_seen;
reg [3:0]        load_error_code_seen;
reg [1:0]        load_error_retries_seen;
reg [31:0]       debug_page_count;
reg [1:0]        debug_page;

// 同步 mem_clk 域的 write_finish_toggle
reg [2:0]        wrfin_tgl_sync;
wire             write_finish_pulse;

wire auto_tick;
wire [1:0] next_from_current;

// Observation only: no timeout recovery, no modifications to load control.
localparam [31:0] DIAG_STALL_CYCLES = CLK_FREQ_HZ * 2;
reg [31:0] diag_stall_count, diag_page_count;
reg [18:0] diag_prev_pixels, diag_snapshot_pixels;
reg [7:0] diag_prev_progress;
reg [19:0] diag_snapshot_flags;
reg diag_snapshot_valid;
reg [2:0] diag_probe_page;
wire diag_flag_page = (diag_probe_page == 1);
reg [79:0] diag_storage_snapshot;
reg [2:0] diag_write_snapshot;
reg [19:0] diag_page_value;
always @* begin
    case (diag_probe_page)
        0: diag_page_value = {1'b0,diag_snapshot_pixels};
        1: diag_page_value = diag_snapshot_flags;
        2: diag_page_value = diag_storage_snapshot[19:0];
        3: diag_page_value = diag_storage_snapshot[39:20];
        4: diag_page_value = {4'hc,diag_storage_snapshot[67:64],diag_storage_snapshot[49:40],2'b0};
        5: diag_page_value = {4'hd,diag_storage_snapshot[75:68],diag_write_snapshot,5'd0};
        6: diag_page_value = {4'he,diag_storage_snapshot[59:50],6'd0};
        default: diag_page_value = 20'hbad00;
    endcase
end
wire [7:0] diag_progress = {state_code_i, source_done_seen, write_done_seen,
                            write_req, write_ack_sync};
wire [19:0] diag_flags_now = {4'hf,
    load_busy, source_done_seen, write_done_seen, write_finish_pulse,
    bmp_ready, write_req, write_ack_sync, sd_init_done,
    load_idx, disp_buf_idx,
    wrfin_tgl_sync[2], wrfin_tgl_sync[1], next_req_pending, auto_play_en};
wire diag_wait = load_busy && (source_done_seen || bmp_ready);
always @(posedge clk or posedge rst) begin
    if (rst) begin
        diag_stall_count<=0; diag_page_count<=0; diag_prev_pixels<=0;
        diag_snapshot_pixels<=0; diag_prev_progress<=0;
        diag_snapshot_flags<=0; diag_snapshot_valid<=0; diag_probe_page<=0;
        diag_storage_snapshot<=0; diag_write_snapshot<=0;
    end else begin
        diag_prev_pixels<=pixel_write_count;
        diag_prev_progress<=diag_progress;
        if (!sd_init_done || !load_busy || load_start_pulse) begin
            diag_stall_count<=0; diag_snapshot_valid<=0;
            diag_page_count<=0; diag_probe_page<=0;
        end else begin
            if (!diag_snapshot_valid) begin
                if (diag_prev_pixels!=pixel_write_count || diag_prev_progress!=diag_progress)
                    diag_stall_count<=0;
                else if (diag_stall_count < DIAG_STALL_CYCLES-1)
                    diag_stall_count<=diag_stall_count+1'b1;
                else begin
                    diag_snapshot_pixels<=pixel_write_count;
                    diag_snapshot_flags<=diag_flags_now;
                    diag_storage_snapshot<=storage_diag_sd;
                    diag_write_snapshot<=storage_diag_write;
                    diag_snapshot_valid<=1;
                end
            end
            if (diag_snapshot_valid) begin
                if (diag_page_count >= CLK_FREQ_HZ-1) begin
                    diag_page_count<=0; diag_probe_page <= (diag_probe_page==6) ? 3'd0 : diag_probe_page+1'b1;
                end else diag_page_count<=diag_page_count+1'b1;
            end
        end
    end
end

wire [15:0] source_w,source_h;
wire source_ready,scale_source_ready,scale_done,scale_error;
reg [1:0] load_scale_mode,applied_scale_mode;
reg load_interpolation,applied_interpolation;
wire bmp_write_req,scale_write_en;
wire animation_busy,animation_done,animation_commit,animation_error;
wire anim_write_req,anim_write_en;
wire [1:0] anim_write_bank;
wire [31:0] anim_write_data;
wire [4:0] anim_step;
reg anim_start,anim_running;
reg [1:0] anim_target;
assign animation_active=anim_running || animation_busy;
assign write_req=animation_active ? anim_write_req:bmp_write_req;
assign write_en=animation_active ? anim_write_en:scale_write_en;
assign write_buf_idx=animation_active ? anim_write_bank:normal_write_buf_idx;
assign source_ready=scale_source_ready && cache_upload_ready;
assign cache_upload_req=bmp_write_req;
assign cache_upload_valid=bmp_data_wr_en && source_ready;
assign cache_upload_pixel=bmp_data;
assign cache_source_w=source_w;assign cache_source_h=source_h;
zoom_animation #(.CLK_HZ(CLK_FREQ_HZ)) u_animation(
 .clk(clk),.rst(rst),.start(anim_start),.src_w(source_w),.src_h(source_h),
 .from_mode(applied_scale_mode),.target_mode(anim_target),.display_bank(disp_buf_idx),
 .commit_generation(transition_commit_toggle),.view_done_toggle(done_sync[2]),
 .writer_ack(write_ack_sync),.writer_finish_toggle(wrfin_tgl_sync[2]),.fifo_usedw(write_fifo_usedw),
 .write_req(anim_write_req),.write_bank(anim_write_bank),.pixel_valid(anim_write_en),.pixel(anim_write_data),
 .commit(animation_commit),.busy(animation_busy),.done(animation_done),
 .row_req(cache_row_req),.row_index(cache_row_index),.row_ack(cache_row_ack),.row_valid(cache_row_valid),
 .row_data(cache_row_pixel),.row_ready(cache_row_ready),.step_debug(anim_step),.error(animation_error));
wire [31:0] scaled_data;
reg diagnostic_req_prev,diagnostic_gray_frame;
reg [10:0] diagnostic_width,diagnostic_height;
reg [19:0] diagnostic_sector;
always @(posedge clk or posedge rst) begin
    if(rst) begin
        diagnostic_req_prev<=0;diagnostic_gray_frame<=0;
        diagnostic_width<=0;diagnostic_height<=0;diagnostic_sector<=0;
    end else begin
        diagnostic_req_prev<=write_req;
        if(write_req && !diagnostic_req_prev) begin
            diagnostic_gray_frame<=diagnostic_gray_requested;
            diagnostic_width<=source_w[10:0];diagnostic_height<=source_h[10:0];
            diagnostic_sector<=load_sector[19:0];
        end
    end
end
// Tags change only when a complete image is committed, never at load start.
always @(posedge clk or posedge rst) begin
    if (rst) begin osd_tag0<=0; osd_tag1<=0; end
    else if (!sd_init_done) begin osd_tag0<=0; osd_tag1<=0; end
    else if(animation_commit) begin
        if(anim_write_bank==0) osd_tag0<=img_idx;else osd_tag1<=img_idx;
    end
    else if (!animation_active && load_busy && source_done_seen && (write_done_seen || write_finish_pulse)) begin
        if (pending_buf_idx==0) osd_tag0<=load_idx;
        else if (pending_buf_idx==1) osd_tag1<=load_idx;
    end
end


assign write_data=diagnostic_gray_frame ? 32'hc0c0c000 : (animation_active ? anim_write_data:scaled_data);
assign diagnostic_source={storage_diag_write,storage_diag_sd[74],scan_done,
    display_valid,load_busy,diagnostic_gray_frame,8'd0,
    scale_error,load_scale_mode,diagnostic_width,diagnostic_height,
    diagnostic_sector,pixel_write_count};
wire reload_scale=(scale_mode!=applied_scale_mode) || (interpolation!=applied_interpolation);
always @(posedge clk or posedge rst) begin
    if(rst) begin load_scale_mode<=0; applied_scale_mode<=0; load_interpolation<=0; applied_interpolation<=0; end
    else begin
        if(load_start_pulse) begin load_scale_mode<=scale_mode; load_interpolation<=interpolation; end
        if(!animation_active && load_busy && source_done_seen && (write_done_seen || write_finish_pulse))
            begin applied_scale_mode<=load_scale_mode; applied_interpolation<=load_interpolation; end
        if(animation_done) begin applied_scale_mode<=anim_target;applied_interpolation<=1;end
    end
end
scale_on_load u_scale (
    .clk(clk), .rst(rst || bmp_load_error), .load_start(bmp_write_req),
    .mode(load_scale_mode), .interpolation(load_interpolation), .src_w(source_w), .src_h(source_h),
    .src_px_valid(bmp_data_wr_en && cache_upload_ready), .src_px(bmp_data), .src_accept(scale_source_ready),
    .source_done(bmp_load_done),
    // Writer clears FIFO during request/ACK. Borders must wait as well as BMP data.
    .fifo_usedw((write_req || write_ack_sync) ? 9'd511 : write_fifo_usedw),
    .tgt_px_valid(scale_write_en), .tgt_px(scaled_data), .busy(),
    .cfg_error(scale_error), .frame_done(scale_done));
assign pixel_count_debug = (diag_wait && !load_error_seen) ?
                           reverse_hex_digits(diag_snapshot_valid ?
                               diag_page_value :
                               {1'b0,pixel_write_count}) : load_error_seen ?
                           (debug_page == 2'd0) ? reverse_hex_digits(load_error_sector_seen) :
                           (debug_page == 2'd1) ? reverse_hex_digits({4'd0, scan_first_signature_seen}) :
                           (debug_page == 2'd2) ? reverse_hex_digits({4'd0, load_error_signature_seen}) :
                           reverse_hex_digits({12'd0, 2'b00, load_error_retries_seen, load_error_code_seen}) :
                           {1'b0, pixel_write_count};

function [19:0] reverse_hex_digits;
    input [19:0] value;
    begin
        reverse_hex_digits = {value[3:0], value[7:4], value[11:8], value[15:12], value[19:16]};
    end
endfunction
assign auto_tick  = (auto_cnt == (CLK_FREQ_HZ - 1));
assign next_from_current = next_index_limited(img_idx, img_found_count);
assign write_finish_pulse = wrfin_tgl_sync[2] ^ wrfin_tgl_sync[1];
// Make the previously ambiguous state 2 observable:
// 2=scan, 5=read BMP header, E=no supported BMP found,
// 6=307200 pixels reached the FIFO but SDRAM frame write is still pending,
// 7=source read ended with a pixel count other than 640x480.
assign state_code = (scan_done && (img_found_count == 3'd0) && !display_valid) ? 4'he :
                    (scan_done && (state_code_i == 4'd2)) ? 4'd5 :
                    (load_busy && load_error_seen) ? 4'd8 :
                    (load_busy && source_done_seen && (pixel_write_count != 19'd307200)) ? 4'd7 :
                    (load_busy && source_done_seen) ? 4'd6 :
                    (load_busy && bmp_ready) ? 4'd9 :
                    state_code_i;

key_press_debounce #(
    .CLK_FREQ_HZ (CLK_FREQ_HZ),
    .DEBOUNCE_MS (20)
) u_key_next (
    .clk        (clk),
    .rst        (rst),
    .button_in  (key_next),
    .press_pulse(key_next_press)
);

key_press_debounce #(
    .CLK_FREQ_HZ (CLK_FREQ_HZ),
    .DEBOUNCE_MS (20)
) u_key_auto (
    .clk        (clk),
    .rst        (rst),
    .button_in  (key_auto),
    .press_pulse(key_auto_press)
);

function [1:0] next_index_limited;
    input [1:0] cur;
    input [2:0] count;
    begin
        case (count)
            3'd0: next_index_limited = 2'd0;
            3'd1: next_index_limited = 2'd0;
            3'd2: next_index_limited = (cur == 2'd1) ? 2'd0 : (cur + 2'd1);
            3'd3: next_index_limited = (cur == 2'd2) ? 2'd0 : (cur + 2'd1);
            default: next_index_limited = (cur == 2'd3) ? 2'd0 : (cur + 2'd1);
        endcase
    end
endfunction

function [31:0] sector_lut;
    input [1:0] idx;
    begin
        case (idx)
            2'd0: sector_lut = img_sector0;
            2'd1: sector_lut = img_sector1;
            2'd2: sector_lut = img_sector2;
            2'd3: sector_lut = img_sector3;
            default: sector_lut = img_sector0;
        endcase
    end
endfunction

function [1:0] next_buf_lut;
    input [1:0] cur_disp_buf;
    input       valid_now;
    begin
        if (!valid_now)
            next_buf_lut = 2'd0;                 // 首图固定写 buffer0
        else if (cur_disp_buf == 2'd0)
            next_buf_lut = 2'd1;
        else
            next_buf_lut = 2'd0;
    end
endfunction

always @(posedge clk or posedge rst) begin
    if (rst) begin
        wrfin_tgl_sync        <= 3'b000;
        anim_start<=0;anim_running<=0;anim_target<=0;
        transition_req_toggle<=0; transition_commit_toggle<=0;
        transition_waiting<=0; transition_active<=0;
        scan_start_pulse      <= 1'b0;
        load_start_pulse      <= 1'b0;
        load_sector           <= 32'd0;
        scan_kicked           <= 1'b0;
        first_image_committed <= 1'b0;
        auto_play_en          <= 1'b0;
        auto_cnt              <= 32'd0;
        img_found_count       <= 3'd0;
        img_idx               <= 2'd0;
        load_idx              <= 2'd0;
        pending_buf_idx       <= 2'd0;
        normal_write_buf_idx         <= 2'd0;
        disp_buf_idx          <= 2'd0;
        img_sector0           <= 32'd0;
        img_sector1           <= 32'd0;
        img_sector2           <= 32'd0;
        img_sector3           <= 32'd0;
        next_req_pending      <= 1'b0;
        load_busy             <= 1'b0;
        pixel_write_count     <= 19'd0;
        source_done_seen      <= 1'b0;
        write_done_seen       <= 1'b0;
        load_error_seen       <= 1'b0;
        load_error_sector_seen <= 20'd0;
        scan_first_signature_seen <= 16'd0;
        load_error_signature_seen <= 16'd0;
        load_error_code_seen  <= 4'd0;
        load_error_retries_seen <= 2'd0;
        debug_page_count      <= 32'd0;
        debug_page            <= 2'd0;
        display_valid         <= 1'b0;
    end else begin
        wrfin_tgl_sync   <= {wrfin_tgl_sync[1:0], write_finish_toggle};
        anim_start<=0;
        if(animation_commit) begin
            disp_buf_idx<=anim_write_bank;transition_commit_toggle<=~transition_commit_toggle;
        end
        if(animation_done) begin
            anim_running<=0;load_busy<=0;source_done_seen<=0;write_done_seen<=0;
        end
        if (transition_active && done_sync[2]==transition_commit_toggle)
            transition_active<=0;
        scan_start_pulse <= 1'b0;
        load_start_pulse <= 1'b0;

        if (!sd_init_done) begin
            anim_running<=0;anim_start<=0;
            transition_req_toggle<=0; transition_commit_toggle<=0;
            transition_waiting<=0; transition_active<=0;
            scan_kicked           <= 1'b0;
            first_image_committed <= 1'b0;
            auto_play_en          <= 1'b0;
            auto_cnt              <= 32'd0;
            img_found_count       <= 3'd0;
            img_idx               <= 2'd0;
            load_idx              <= 2'd0;
            pending_buf_idx       <= 2'd0;
            normal_write_buf_idx         <= 2'd0;
            disp_buf_idx          <= 2'd0;
            img_sector0           <= 32'd0;
            img_sector1           <= 32'd0;
            img_sector2           <= 32'd0;
            img_sector3           <= 32'd0;
            next_req_pending      <= 1'b0;
            load_busy             <= 1'b0;
            pixel_write_count     <= 19'd0;
            source_done_seen      <= 1'b0;
            write_done_seen       <= 1'b0;
            load_error_seen       <= 1'b0;
            load_error_sector_seen <= 20'd0;
            scan_first_signature_seen <= 16'd0;
            load_error_signature_seen <= 16'd0;
            load_error_code_seen  <= 4'd0;
            load_error_retries_seen <= 2'd0;
            debug_page_count      <= 32'd0;
            debug_page            <= 2'd0;
            display_valid         <= 1'b0;
        end else begin
            // 扫描阶段缓存前 4 张图的起始 sector
            if (scan_found_valid) begin
                if (img_found_count == 3'd0)
                    scan_first_signature_seen <= scan_found_signature;
                case (img_found_count)
                    3'd0: img_sector0 <= scan_found_sector;
                    3'd1: img_sector1 <= scan_found_sector;
                    3'd2: img_sector2 <= scan_found_sector;
                    3'd3: img_sector3 <= scan_found_sector;
                    default: ;
                endcase

                if (img_found_count < 3'd4)
                    img_found_count <= img_found_count + 3'd1;
            end

            // 记住 bmp_read 已经把源图送完 FIFO，但还不能切显示，得等整帧写完
            if (load_busy && scale_done)
                source_done_seen <= 1'b1;
            if (load_busy && bmp_load_error) begin
                load_error_seen <= 1'b1;
                load_error_sector_seen <= bmp_load_error_sector;
                load_error_signature_seen <= bmp_load_error_signature;
                load_error_code_seen <= bmp_load_error_code;
                load_error_retries_seen <= bmp_load_error_retries;
                debug_page_count <= 32'd0;
                debug_page <= 2'd0;
            end

            if (load_start_pulse) begin
                pixel_write_count <= 19'd0;
                load_error_seen <= 1'b0;
                load_error_sector_seen <= 20'd0;
                load_error_signature_seen <= 16'd0;
                load_error_code_seen <= 4'd0;
                load_error_retries_seen <= 2'd0;
                debug_page_count <= 32'd0;
                debug_page <= 2'd0;
            end
            else if (load_busy && write_en && (pixel_write_count < 19'd307200))
                pixel_write_count <= pixel_write_count + 1'b1;

            if (load_error_seen) begin
                if (debug_page_count >= ((CLK_FREQ_HZ / 2) - 1)) begin
                    debug_page_count <= 32'd0;
                    debug_page <= (debug_page == 2'd3) ? 2'd0 : (debug_page + 2'd1);
                end else begin
                    debug_page_count <= debug_page_count + 1'b1;
                end
            end

            // Latch the frame-finish toggle so its pulse cannot be lost if it
            // arrives before bmp_read returns to IDLE and raises bmp_ready.
            if (load_busy && write_finish_pulse)
                write_done_seen <= 1'b1;

            // 只有真正收到 write_finish_toggle 脉冲，才提交新图并切换显示缓冲区
            if (!animation_active && load_busy && source_done_seen && (write_done_seen || write_finish_pulse)) begin
                if (!display_valid || (transition_waiting && dark_sync[2]==transition_req_toggle)) begin
                    load_busy<=0; source_done_seen<=0; write_done_seen<=0;
                    disp_buf_idx<=pending_buf_idx; img_idx<=load_idx;
                    display_valid<=1; first_image_committed<=1;
                    transition_commit_toggle<=~transition_commit_toggle;
                    transition_active<=1; transition_waiting<=0;
                end else if (!transition_waiting) begin
                    transition_req_toggle<=~transition_req_toggle;
                    transition_waiting<=1;
                end
            end

            // 上电后自动发起一次“扫描前 4 张 BMP”
            if (!scan_kicked && bmp_ready) begin
                scan_start_pulse      <= 1'b1;
                scan_kicked           <= 1'b1;
                first_image_committed <= 1'b0;
                auto_play_en          <= 1'b0;
                auto_cnt              <= 32'd0;
                img_found_count       <= 3'd0;
                img_idx               <= 2'd0;
                load_idx              <= 2'd0;
                pending_buf_idx       <= 2'd0;
                normal_write_buf_idx         <= 2'd0;
                disp_buf_idx          <= 2'd0;
                next_req_pending      <= 1'b0;
                display_valid         <= 1'b0;
                load_busy             <= 1'b0;
                source_done_seen      <= 1'b0;
                write_done_seen       <= 1'b0;
            end else begin
                // Ignore new manual requests throughout load and both transition phases.
                if (key_next_press && scan_done && !load_busy && !transition_active && (img_found_count > 3'd0))
                    next_req_pending <= 1'b1;

                // 自动播放开/关
                if (key_auto_press && scan_done && (img_found_count > 3'd1)) begin
                    auto_play_en <= ~auto_play_en;
                    auto_cnt     <= 32'd0;
                end

                // 自动播放 1s 计数：只有当前没有写图任务时才计时
                if (scan_done && auto_play_en && display_valid && !load_busy && !transition_active && first_image_committed && (img_found_count > 3'd1)) begin
                    if (auto_tick)
                        auto_cnt <= 32'd0;
                    else
                        auto_cnt <= auto_cnt + 32'd1;
                end else begin
                    auto_cnt <= 32'd0;
                end

                // 首图自动加载到 buffer0
                if (scan_done && !first_image_committed && bmp_ready && !load_busy && !transition_active && (img_found_count != 3'd0)) begin
                    load_idx         <= 2'd0;
                    load_sector      <= img_sector0;
                    pending_buf_idx  <= 2'd0;
                    normal_write_buf_idx    <= 2'd0;
                    load_start_pulse <= 1'b1;
                    load_busy        <= 1'b1;
                    pixel_write_count <= 19'd0;
                    source_done_seen <= 1'b0;
                    write_done_seen  <= 1'b0;
                    next_req_pending <= 1'b0;
                    auto_cnt         <= 32'd0;
                end
                else if(scan_done && bmp_ready && display_valid && !load_busy &&
                        !transition_active && reload_scale) begin
                    if(interpolation && cache_valid) begin
                        anim_target<=scale_mode;anim_running<=1;anim_start<=1;load_busy<=1;
                        source_done_seen<=0;write_done_seen<=0;auto_cnt<=0;
                    end else begin
                    load_idx<=img_idx; load_sector<=sector_lut(img_idx);
                    pending_buf_idx<=next_buf_lut(disp_buf_idx,display_valid);
                    normal_write_buf_idx<=next_buf_lut(disp_buf_idx,display_valid);
                    load_start_pulse<=1; load_busy<=1;
                    pixel_write_count<=0; source_done_seen<=0; write_done_seen<=0; auto_cnt<=0;
                    end
                end
                // 手动下一张优先：写到“非当前显示”的另一块 buffer
                else if (scan_done && bmp_ready && display_valid && !load_busy && !transition_active && next_req_pending && (img_found_count != 3'd0)) begin
                    load_idx         <= next_from_current;
                    load_sector      <= sector_lut(next_from_current);
                    pending_buf_idx  <= next_buf_lut(disp_buf_idx, display_valid);
                    normal_write_buf_idx    <= next_buf_lut(disp_buf_idx, display_valid);
                    load_start_pulse <= 1'b1;
                    load_busy        <= 1'b1;
                    pixel_write_count <= 19'd0;
                    source_done_seen <= 1'b0;
                    write_done_seen  <= 1'b0;
                    next_req_pending <= 1'b0;
                    auto_cnt         <= 32'd0;
                end
                // 自动播放下一张：同样写到“非当前显示”的另一块 buffer
                else if (scan_done && bmp_ready && display_valid && !load_busy && !transition_active && auto_play_en && auto_tick && (img_found_count > 3'd1)) begin
                    load_idx         <= next_from_current;
                    load_sector      <= sector_lut(next_from_current);
                    pending_buf_idx  <= next_buf_lut(disp_buf_idx, display_valid);
                    normal_write_buf_idx    <= next_buf_lut(disp_buf_idx, display_valid);
                    load_start_pulse <= 1'b1;
                    load_busy        <= 1'b1;
                    pixel_write_count <= 19'd0;
                    source_done_seen <= 1'b0;
                    write_done_seen  <= 1'b0;
                    auto_cnt         <= 32'd0;
                end
            end
        end
    end
end

bmp_read bmp_read_m0(
    .clk                    (clk),
    .rst                    (rst),
    .ready                  (bmp_ready),

    .scan_start             (scan_start_pulse),
    .scan_start_sector      (SCAN_START_SECTOR),
    .scan_max_sector        (SCAN_MAX_SECTOR),
    .scan_target_count      (SCAN_TARGET_COUNT),
    .scan_done              (scan_done),
    .scan_found_valid       (scan_found_valid),
    .scan_found_sector      (scan_found_sector),
    .scan_found_signature   (scan_found_signature),
    .scan_found_total       (scan_found_total),

    .load_start             (load_start_pulse),
    .load_sector            (load_sector),
    .load_done              (bmp_load_done),
    .load_error             (bmp_load_error),
    .load_error_code        (bmp_load_error_code),
    .load_error_retries     (bmp_load_error_retries),
    .load_error_sector      (bmp_load_error_sector),
    .load_error_signature   (bmp_load_error_signature),

    .sd_init_done           (sd_init_done),
    .state_code             (state_code_i),
    .bmp_width              (bmp_width),
    .bmp_height             (bmp_height),
    .write_req              (bmp_write_req),
    .write_req_ack          (write_ack_sync),
    .sd_sec_read            (sd_sec_read),
    .sd_sec_read_addr       (sd_sec_read_addr),
    .sd_sec_read_data       (sd_sec_read_data),
    .sd_sec_read_data_valid (sd_sec_read_data_valid),
    .sd_sec_read_end        (sd_sec_read_end),
    .bmp_data_wr_en         (bmp_data_wr_en),
    .src_w(source_w), .src_h(source_h), .src_accept(source_ready),
    .bmp_data               (bmp_data)
);

// Use a conservative ~3.125 MHz read clock while diagnosing repeat-read errors.
sd_card_top #(
    .SPI_HIGH_SPEED_DIV (16'd14)
) sd_card_top_m0(
    .clk                    (clk),
    .rst                    (rst),
    .SD_nCS                 (SD_nCS),
    .SD_DCLK                (SD_DCLK),
    .SD_MOSI                (SD_MOSI),
    .SD_MISO                (SD_MISO),
    .sd_init_done           (sd_init_done),
    .sd_sec_read            (sd_sec_read),
    .sd_sec_read_addr       (sd_sec_read_addr),
    .sd_sec_read_data       (sd_sec_read_data),
    .sd_sec_read_data_valid (sd_sec_read_data_valid),
    .sd_sec_read_end        (sd_sec_read_end),
    .sd_sec_write           (1'b0),
    .sd_sec_write_addr      (32'd0),
    .sd_sec_write_data      (),
    .sd_sec_write_data_req  (),
    .sd_sec_write_end       ()
);

endmodule

module key_press_debounce #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer DEBOUNCE_MS = 20
)(
    input  wire clk,
    input  wire rst,
    input  wire button_in,    // 默认：松开=1，按下=0
    output reg  press_pulse
);

localparam integer DEBOUNCE_CYCLES = (CLK_FREQ_HZ / 1000) * DEBOUNCE_MS;

reg button_sync0;
reg button_sync1;
reg button_stable;
reg [31:0] cnt;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        button_sync0  <= 1'b1;
        button_sync1  <= 1'b1;
        button_stable <= 1'b1;
        cnt           <= 32'd0;
        press_pulse   <= 1'b0;
    end else begin
        button_sync0 <= button_in;
        button_sync1 <= button_sync0;
        press_pulse  <= 1'b0;

        if (button_sync1 == button_stable) begin
            cnt <= 32'd0;
        end else begin
            if (cnt >= DEBOUNCE_CYCLES - 1) begin
                if (button_stable && !button_sync1)
                    press_pulse <= 1'b1;
                button_stable <= button_sync1;
                cnt           <= 32'd0;
            end else begin
                cnt <= cnt + 32'd1;
            end
        end
    end
end

endmodule
