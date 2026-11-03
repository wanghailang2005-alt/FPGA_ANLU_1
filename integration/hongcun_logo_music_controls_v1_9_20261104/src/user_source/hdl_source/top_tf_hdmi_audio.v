
module top(
    input                       clk,
    input                       rst_n,
    input                       key1,           // 手动下一张
    input                       key2,           // K4: auto play
    input                       key3,           // K3: selected setting
    input [3:0]                 sw,             // SW4..SW1

    output [5:0]                seg_sel,
    output [7:0]                seg_data,

    // HDMI TMDS
    output                      HDMI_CLK_P,
    output                      HDMI_D2_P,
    output                      HDMI_D1_P,
    output                      HDMI_D0_P,

    // HDMI DDC
    output                      HDMI_DDC_SCL,
    inout                       HDMI_DDC_SDA,

    // TF card SPI
    output                      sd_ncs,
    output                      sd_dclk,
    output                      sd_mosi,
    input                       sd_miso
);

// Diagnostic A/B: 1=dynamic metadata path, 0=fixed text + legacy bank selection.
parameter OSD_STATUS_MODE = 1;
// Diagnostic comparison: the only functional variant is source-cache access.
// 0 bypasses cache upload and cached animation; 1 preserves the animation build.
parameter SOURCE_CACHE_ENABLE = 1;
parameter MEM_DATA_BITS = 32;
parameter ADDR_BITS     = 21;
parameter BUSRT_BITS    = 10;
parameter FRAME_PIXELS  = 24'd307200;   // 640*480
parameter BUF0_ADDR     = 24'd0;
parameter BUF1_ADDR     = FRAME_PIXELS;

wire Sdr_init_done;
wire Sdr_init_ref_vld;
wire Sdr_busy;

wire sd_card_clk;
wire ext_mem_clk;
wire ext_mem_clk_sft;
wire video_clk;
wire hdmi_5x_clk;

wire hs;
wire vs;
wire de;

wire [23:0] vout_data_raw;
wire [23:0] vout_data;
wire        display_valid;
wire rst_all;
wire transition_req_toggle, transition_commit_toggle, transition_dark_toggle, transition_done_toggle;
wire [2:0] transition_mode;
wire [1:0] transition_duration;
// SW=0001/0010/0011/0110 的文字与滑动方向设置，SW=1010/1011 的亮度/对比度，
// SW=1100 的中英字幕层选择
wire [1:0] text_mode, scroll_speed;
wire       scroll_dir, slide_dir;
wire [3:0] setting_value;
wire [3:0] brightness, contrast;
wire [1:0] sub_mode;
// 打包送 video 像素域的设置快照
// {setting_value, sub_mode, contrast, brightness, text_mode, scroll_dir, scroll_speed}
wire [18:0] osd_cfg_sys, osd_cfg_video;
wire [3:0] osd_value_video, osd_contrast_video, osd_brightness_video;
wire [1:0] osd_text_mode_video, osd_scroll_speed_video, osd_sub_mode_video;
wire       osd_scroll_dir_video;
wire [1:0] scale_mode,scale_mode_sd;
wire App_rd_en;
wire [ADDR_BITS-1:0] App_rd_addr;
wire Sdr_rd_en;
wire [MEM_DATA_BITS-1:0] Sdr_rd_dout;
wire App_wr_en;
wire [ADDR_BITS-1:0] App_wr_addr;
wire [MEM_DATA_BITS-1:0] App_wr_din;
wire [3:0] App_wr_dm;
wire interpolation;
wire animation_active;
(* ASYNC_REG="TRUE",keep="true" *) reg animation_meta,animation_sys,animation_video_meta,animation_video;
always @(posedge clk or posedge rst_all) begin
 if(rst_all) begin animation_meta<=0;animation_sys<=0;end
 else begin animation_meta<=animation_active;animation_sys<=animation_meta;end
end
always @(posedge video_clk or posedge rst_all) begin
 if(rst_all) begin animation_video_meta<=0;animation_video<=0;end
 else begin animation_video_meta<=animation_active;animation_video<=animation_video_meta;end
end
wire cache_valid,cache_upload_ready,cache_upload_req,cache_upload_valid;
wire [23:0] cache_upload_pixel,cache_row_pixel;
wire [15:0] cache_source_w,cache_source_h,cache_row_index;
wire cache_row_req,cache_row_ack,cache_row_valid,cache_row_ready;
wire cache_hold,legacy_busy,cache_aux_active,cache_aux_read,cache_aux_write,cache_error;
wire [19:0] checksum_status_mem,checksum_status_sys;
wire [20:0] cache_aux_addr;
wire [31:0] cache_aux_data;
wire        sd_card_write_req;
wire [1:0]  write_buf_idx;
reg dma_write_req;
reg [1:0] dma_write_bank;
always @(posedge sd_card_clk or posedge rst_all) begin
 if(rst_all) begin dma_write_req<=0;dma_write_bank<=0;end
 else begin dma_write_req<=sd_card_write_req;dma_write_bank<=write_buf_idx;end
end
wire frame_App_rd_en,frame_App_wr_en;
wire [20:0] frame_App_rd_addr,frame_App_wr_addr;
wire [31:0] frame_App_wr_din;
assign App_rd_en=cache_aux_active ? cache_aux_read:frame_App_rd_en;
assign App_wr_en=cache_aux_active ? cache_aux_write:frame_App_wr_en;
assign App_rd_addr=cache_aux_active ? cache_aux_addr:frame_App_rd_addr;
assign App_wr_addr=cache_aux_active ? cache_aux_addr:frame_App_wr_addr;
assign App_wr_din=cache_aux_active ? cache_aux_data:frame_App_wr_din;
generate if(SOURCE_CACHE_ENABLE) begin:g_source_cache
zoom_source_cache u_source_cache(
 .rst(rst_all),.sd_clk(sd_card_clk),.mem_clk(ext_mem_clk),
 .upload_req(cache_upload_req),.src_w(cache_source_w),.src_h(cache_source_h),
 .upload_valid(cache_upload_valid),.upload_pixel(cache_upload_pixel),.upload_ready(cache_upload_ready),.cache_valid(cache_valid),
 .row_req(cache_row_req),.row_index(cache_row_index),.row_ack(cache_row_ack),.row_valid(cache_row_valid),
 .row_pixel(cache_row_pixel),.row_ready(cache_row_ready),.legacy_hold(cache_hold),.legacy_busy(legacy_busy),
 .aux_active(cache_aux_active),.aux_read(cache_aux_read),.aux_write(cache_aux_write),.aux_addr(cache_aux_addr),.aux_data(cache_aux_data),
 .init_done(Sdr_init_done),.refresh_busy(Sdr_init_ref_vld),.sdr_busy(Sdr_busy),
 .read_valid(Sdr_rd_en),.read_data(Sdr_rd_dout),.cache_error(cache_error),
 .checksum_status(checksum_status_mem));
end else begin:g_source_cache_bypass
 assign cache_upload_ready=1'b1;
 assign cache_valid=1'b0;
 assign cache_row_ack=1'b0;
 assign cache_row_valid=1'b0;
 assign cache_row_pixel=24'd0;
 assign cache_hold=1'b0;
 assign cache_aux_active=1'b0;
 assign cache_aux_read=1'b0;
 assign cache_aux_write=1'b0;
 assign cache_aux_addr=21'd0;
 assign cache_aux_data=32'd0;
 assign cache_error=1'b0;
 assign checksum_status_mem=20'd0;
end endgenerate
osd_status_cdc #(.WIDTH(20)) u_checksum_cdc(
 .src_clk(ext_mem_clk),.dst_clk(clk),.rst(rst_all),
 .src_data(checksum_status_mem),.dst_data(checksum_status_sys));
wire [47:0] memory_probe_mem,memory_probe_sys;
zoom_memory_probe u_memory_probe(
 .clk(ext_mem_clk),.rst(rst_all),.read_cmd(App_rd_en),.write_cmd(App_wr_en),
 .read_return(Sdr_rd_en),.cache_owner(cache_aux_active),.cache_error(cache_error),
 .status(memory_probe_mem));
osd_status_cdc #(.WIDTH(48)) u_memory_probe_cdc(
 .src_clk(ext_mem_clk),.dst_clk(clk),.rst(rst_all),
 .src_data(memory_probe_mem),.dst_data(memory_probe_sys));
wire [3:0] diagnostic_sw_stable,diagnostic_sw_video;
wire [3:0] diagnostic_config_sd;
wire [79:0] diagnostic_source_sd,diagnostic_source_sys;
wire [7:0] diagnostic_health_video,diagnostic_health_sys;
wire [1:0] diagnostic_read;
assign scale_mode_sd=diagnostic_config_sd[1:0];
wire [8:0] write_fifo_usedw;
osd_status_cdc #(.WIDTH(4)) u_scale_mode_cdc (
    .src_clk(clk), .dst_clk(sd_card_clk), .rst(rst_all),
    .src_data({1'b0,interpolation,scale_mode}), .dst_data(diagnostic_config_sd));
wire music_track;
wire [6:0] music_control_sd;
wire music_paused;wire [3:0] music_volume;
wire music_mode_sys=diagnostic_sw_stable==4'h9;
music_controls u_music_controls(.clk(clk),.rst(rst_all),
 .enable(music_mode_sys && sw==4'h9),.key_pause_n(key1),.key_volume_n(key2),
 .paused(music_paused),.volume(music_volume));
wire [2:0] music_health;
osd_status_cdc #(.WIDTH(7)) u_music_control_cdc(
 .src_clk(clk),.dst_clk(sd_card_clk),.rst(rst_all),
 .src_data({music_paused,music_volume,1'b1,music_track}),.dst_data(music_control_sd));
user_control u_transition_control (
    .clk(clk), .rst_n(~rst_all), .key3_n(key3), .sw(sw), .animation_busy(animation_sys),
    .transition_mode(transition_mode), .duration_sel(transition_duration), .scale_mode(scale_mode), .interpolation(interpolation), .sw_stable(diagnostic_sw_stable),
    .music_track(music_track), .text_mode(text_mode), .scroll_speed(scroll_speed), .scroll_dir(scroll_dir), .slide_dir(slide_dir), .setting_value(setting_value),
    .brightness(brightness), .contrast(contrast), .sub_mode(sub_mode)
);
osd_status_cdc #(.WIDTH(4)) u_diag_sw_video (
 .src_clk(clk),.dst_clk(video_clk),.rst(rst_all),
 .src_data(diagnostic_sw_stable),.dst_data(diagnostic_sw_video));
// 文字显示模式/滚动速度/滚动方向/设置值/亮度/对比度：打包成一致快照跨到视频
// 像素域，目标域在帧消隐边界使用，避免逐位同步造成的瞬时不一致。
// One coherent snapshot: SW, mode and displayed values travel together.
wire [34:0] ui_state_video;reg [34:0] ui_state_frame;
wire [5:0] ui_modes_frame=ui_state_frame[24:19];
wire [3:0] ui_sw_frame=ui_state_frame[28:25];
assign osd_cfg_sys={setting_value,sub_mode,contrast,brightness,text_mode,scroll_dir,scroll_speed};
osd_status_cdc #(.WIDTH(35)) u_osd_cfg_video(
 .src_clk(clk),.dst_clk(video_clk),.rst(rst_all),
 .src_data({music_track,music_paused,music_volume,diagnostic_sw_stable,transition_mode,interpolation,scale_mode,osd_cfg_sys}),
 .dst_data(ui_state_video));
always @(posedge video_clk or posedge rst_all)begin
 if(rst_all)ui_state_frame<=35'd0;
 else if(osd_frame_tick)ui_state_frame<=ui_state_video;end
assign osd_cfg_video=ui_state_frame[18:0];
assign {osd_value_video,osd_sub_mode_video,osd_contrast_video,osd_brightness_video,
 osd_text_mode_video,osd_scroll_dir_video,osd_scroll_speed_video}=osd_cfg_video;
osd_status_cdc #(.WIDTH(80)) u_diag_source_sys (
 .src_clk(sd_card_clk),.dst_clk(clk),.rst(rst_all),
 .src_data(diagnostic_source_sd),.dst_data(diagnostic_source_sys));
osd_status_cdc #(.WIDTH(8)) u_diag_health_sys (
 .src_clk(video_clk),.dst_clk(clk),.rst(rst_all),
 .src_data(diagnostic_health_video),.dst_data(diagnostic_health_sys));
wire [10:0] osd_sd_status, osd_mem_status;
wire [79:0] storage_diag_mem, storage_diag_sd;
wire [2:0] storage_diag_write;
osd_status_cdc #(.WIDTH(80)) u_storage_probe_mem_sd (
    .src_clk(ext_mem_clk), .dst_clk(sd_card_clk), .rst(rst_all),
    .src_data(storage_diag_mem), .dst_data(storage_diag_sd));
wire [5:0] osd_read_status, osd_pixel_status;
osd_status_cdc #(.WIDTH(11)) u_status_sd_mem (
    .src_clk(sd_card_clk), .dst_clk(ext_mem_clk), .rst(rst_all),
    .src_data(osd_sd_status), .dst_data(osd_mem_status));
osd_status_cdc #(.WIDTH(6)) u_status_mem_pixel (
    .src_clk(ext_mem_clk), .dst_clk(video_clk), .rst(rst_all),
    .src_data(osd_read_status), .dst_data(osd_pixel_status));

wire [3:0]  state_code;
wire [6:0]  seg_data_0;
wire [19:0] pixel_count_debug;
wire [23:0] diagnostic_legacy_sys;
reg [23:0] diagnostic_legacy_sd;
always @(posedge sd_card_clk or posedge rst_all) begin
 if(rst_all) diagnostic_legacy_sd<=0;
 else diagnostic_legacy_sd<={state_code,pixel_count_debug};
end
wire [3:0] state_code_sys=diagnostic_legacy_sys[23:20];
wire [19:0] pixel_count_sys=diagnostic_legacy_sys[19:0];
osd_status_cdc #(.WIDTH(24)) u_diag_legacy_sys (
 .src_clk(sd_card_clk),.dst_clk(clk),.rst(rst_all),
 .src_data(diagnostic_legacy_sd),.dst_data(diagnostic_legacy_sys));
wire [6:0]  seg_count_0;
wire [6:0]  seg_count_1;
wire [6:0]  seg_count_2;
wire [6:0]  seg_count_3;
wire [6:0]  seg_count_4;

wire        video_read_req;
wire        video_read_req_ack;
wire        video_read_en;
wire [31:0] video_read_data;

wire        sd_card_write_en;
wire [31:0] sd_card_write_data;

wire        sd_card_write_req_ack;
wire        frame_write_finish;
reg         frame_write_toggle_mem;


wire [1:0]  disp_buf_idx;



wire hs_0;
wire vs_0;
wire de_0;

// HDMI 1.4b 音频发射相关
wire        audio_pll_lock;
wire        audio_mclk;
wire        audio_i2s_bclk;
wire        audio_i2s_lrck;
wire        audio_i2s_dout;
wire        audio_valid;
wire [23:0] audio_left_data;
wire [23:0] audio_right_data;
wire        acr_valid;
wire [19:0] acr_cts;
wire [19:0] acr_n;

wire        axis_s_user;
wire        axis_s_valid;
wire        axis_s_last;
wire [23:0] axis_s_data;
wire        axis_s_ready;

wire        edid_trig;
wire        edid_valid;
wire [7:0]  edid_data;

wire [9:0]  tmds_ch0_data;
wire [9:0]  tmds_ch1_data;
wire [9:0]  tmds_ch2_data;
wire [9:0]  tmds_clk_data;

// 统一复位：TF 图像链路 + HDMI 音频链路
assign rst_all = ~rst_n | ~audio_pll_lock;

// 保持你原来的 TF / SDRAM / video 时钟
sys_pll sys_pll_m0(
    .refclk     (clk),
    .clk0_out   (sd_card_clk),
    .clk1_out   (ext_mem_clk),
    .clk2_out   (ext_mem_clk_sft),
    .reset      (1'b0)
);

video_pll video_pll_m0(
    .refclk     (clk),
    .clk0_out   (video_clk),
    .clk1_out   (hdmi_5x_clk),
    .reset      (1'b0)
);

// 复用你 I2S->HDMI 工程里的 PLL，只取 12.288MHz 音频主时钟
PLL_HDMI_AUDIO u_audio_pll(
    .refclk     (clk),
    .reset      (1'b0),
    .extlock    (audio_pll_lock),
    .clk0_out   (),
    .clk1_out   (),
    .clk2_out   (audio_mclk)
);

// mem_clk 域把 write_finish 单拍转成 toggle，供 sd_card_clk 域可靠同步
always @(posedge ext_mem_clk or posedge rst_all) begin
    if (rst_all)
        frame_write_toggle_mem <= 1'b0;
    else if (frame_write_finish)
        frame_write_toggle_mem <= ~frame_write_toggle_mem;
end

// ===================== TF 多图扫描与缓存（双缓冲） =====================
sd_card_bmp #(
    .CLK_FREQ_HZ       (100_000_000),
    .SCAN_START_SECTOR (32'd0),
    .SCAN_MAX_SECTOR   (32'd131071),
    .SCAN_TARGET_COUNT (3'd5)
) sd_card_bmp_m0(
    .clk               (sd_card_clk),
    .rst               (rst_all),
    .music_control(music_control_sd[1:0]),.playback_controls(music_control_sd[6:2]),.audio_mclk(audio_mclk),
    .music_bclk(audio_i2s_bclk),.music_lrck(audio_i2s_lrck),.music_dout(audio_i2s_dout),
    .music_health(music_health),
    .key_next          (music_mode_sys ? 1'b1:key1),
    .key_auto          (music_mode_sys ? 1'b1:key2),
    .transition_dark_toggle(transition_dark_toggle),
    .transition_done_toggle(transition_done_toggle),
    .transition_req_toggle(transition_req_toggle),
    .transition_commit_toggle(transition_commit_toggle),
    .state_code        (state_code),
    .pixel_count_debug (pixel_count_debug),
    .storage_diag_sd(storage_diag_sd), .storage_diag_write(storage_diag_write),
    .bmp_width         (16'd640),
    .bmp_height        (16'd480),
    .display_valid     (display_valid),
    .osd_status(osd_sd_status),

    .write_finish_toggle(frame_write_toggle_mem),
    .write_buf_idx     (write_buf_idx),
    .disp_buf_idx      (disp_buf_idx),

    .write_req         (sd_card_write_req),
    .write_req_ack     (sd_card_write_req_ack),
    .write_fifo_usedw(write_fifo_usedw), .scale_mode(scale_mode_sd), .interpolation(diagnostic_config_sd[2]),
    .cache_valid(cache_valid),.cache_upload_ready(cache_upload_ready),.cache_upload_req(cache_upload_req),
    .cache_upload_valid(cache_upload_valid),.cache_upload_pixel(cache_upload_pixel),.cache_source_w(cache_source_w),.cache_source_h(cache_source_h),
    .animation_active(animation_active),.cache_row_req(cache_row_req),.cache_row_index(cache_row_index),
    .cache_row_ack(cache_row_ack),.cache_row_valid(cache_row_valid),.cache_row_pixel(cache_row_pixel),.cache_row_ready(cache_row_ready),
    .diagnostic_gray_requested(diagnostic_config_sd[3]),.diagnostic_source(diagnostic_source_sd),
    .write_en          (sd_card_write_en),
    .write_data        (sd_card_write_data),
    .SD_nCS            (sd_ncs),
    .SD_DCLK           (sd_dclk),
    .SD_MOSI           (sd_mosi),
    .SD_MISO           (sd_miso)
);

seg_decoder seg_decoder_m0(
    .bin_data          (state_code_sys),
    .seg_data          (seg_data_0)
);

seg_decoder seg_count_decoder_0(.bin_data(pixel_count_sys[3:0]),   .seg_data(seg_count_0));
seg_decoder seg_count_decoder_1(.bin_data(pixel_count_sys[7:4]),   .seg_data(seg_count_1));
seg_decoder seg_count_decoder_2(.bin_data(pixel_count_sys[11:8]),  .seg_data(seg_count_2));
seg_decoder seg_count_decoder_3(.bin_data(pixel_count_sys[15:12]), .seg_data(seg_count_3));
seg_decoder seg_count_decoder_4(.bin_data(pixel_count_sys[19:16]), .seg_data(seg_count_4));

// SW=1001 以及 1101~1111 为诊断页；1010/1011 已改为亮度/对比度，1100 改为字幕语言。
wire diagnostic_page=(diagnostic_sw_stable==4'h9)||(diagnostic_sw_stable>=4'hd);
reg [25:0] memory_probe_page_count;
reg [1:0] memory_probe_page;
always @(posedge clk or posedge rst_all) begin
 if(rst_all) begin memory_probe_page_count<=0;memory_probe_page<=0;end
 else if(diagnostic_sw_stable!=4'hf) begin memory_probe_page_count<=0;memory_probe_page<=0;end
 else if(memory_probe_page_count==49999999) begin
  memory_probe_page_count<=0;memory_probe_page<=memory_probe_page+1'b1;
 end else memory_probe_page_count<=memory_probe_page_count+1'b1;
end
// Flags: cache FIFO error, stray return, owner handoff with pending data,
// simultaneous read/write, pending overflow, target write during reset,
// target write overflow, current/previous video-frame read underflow.
wire [7:0] memory_probe_flags={memory_probe_sys[47:43],
 diagnostic_source_sys[79],diagnostic_source_sys[78],diagnostic_health_sys[5]};
wire [3:0] memory_probe_marker=SOURCE_CACHE_ENABLE ? 4'hb:4'ha;
wire [3:0] diagnostic_heading=diagnostic_sw_stable!=4'hf ? diagnostic_sw_stable :
 memory_probe_page==0 ? 4'hf:memory_probe_page==1 ? 4'h1:memory_probe_page==2 ? 4'h2:4'h3;
reg [19:0] diagnostic_number;
always @* begin
 case(diagnostic_sw_stable)
  4'hb:diagnostic_number={9'd0,diagnostic_source_sys[60:50]};
  4'hc:diagnostic_number={9'd0,diagnostic_source_sys[49:39]};
  4'hd:diagnostic_number=diagnostic_source_sys[38:19];
  4'he:diagnostic_number={1'b0,diagnostic_source_sys[18:0]};
  4'hf:case(memory_probe_page)
    0:diagnostic_number={memory_probe_marker,memory_probe_flags,memory_probe_sys[39:32]};
    1:diagnostic_number={memory_probe_marker,memory_probe_sys[31:16]};
    2:diagnostic_number={memory_probe_marker,memory_probe_sys[15:0]};
    default:diagnostic_number=checksum_status_sys;
   endcase
  default:diagnostic_number={4'd0,diagnostic_source_sys[79:72],diagnostic_health_sys};
 endcase
end
wire [7:0] diagnostic_segment[0:5];
genvar dg;
generate for(dg=0;dg<5;dg=dg+1) begin:diag_digits
 wire [6:0] decoded;
 seg_decoder u_dec(.bin_data(diagnostic_number[dg*4+:4]),.seg_data(decoded));
 assign diagnostic_segment[dg]={1'b1,decoded};
end endgenerate
wire [6:0] diagnostic_page_segment;
seg_decoder u_diag_page(.bin_data(diagnostic_heading),.seg_data(diagnostic_page_segment));
assign diagnostic_segment[5]={1'b0,diagnostic_page_segment};
seg_scan seg_scan_m0(
    .clk               (clk),
    .rst_n             (rst_n),
    .seg_sel           (seg_sel),
    .seg_data          (seg_data),
    .seg_data_0        (diagnostic_page ? diagnostic_segment[0] : ((state_code_sys == 4'd6 || state_code_sys == 4'd7 || state_code_sys == 4'd8 || state_code_sys == 4'd9) ? {1'b1,seg_count_0} : {1'b1,7'b1111_111})),
    .seg_data_1        (diagnostic_page ? diagnostic_segment[1] : ((state_code_sys == 4'd6 || state_code_sys == 4'd7 || state_code_sys == 4'd8 || state_code_sys == 4'd9) ? {1'b1,seg_count_1} : {1'b1,7'b1111_111})),
    .seg_data_2        (diagnostic_page ? diagnostic_segment[2] : ((state_code_sys == 4'd6 || state_code_sys == 4'd7 || state_code_sys == 4'd8 || state_code_sys == 4'd9) ? {1'b1,seg_count_2} : {1'b1,7'b1111_111})),
    .seg_data_3        (diagnostic_page ? diagnostic_segment[3] : ((state_code_sys == 4'd6 || state_code_sys == 4'd7 || state_code_sys == 4'd8 || state_code_sys == 4'd9) ? {1'b1,seg_count_3} : {1'b1,7'b1111_111})),
    .seg_data_4        (diagnostic_page ? diagnostic_segment[4] : ((state_code_sys == 4'd6 || state_code_sys == 4'd7 || state_code_sys == 4'd8 || state_code_sys == 4'd9) ? {1'b1,seg_count_4} : {1'b1,7'b1111_111})),
    .seg_data_5        (diagnostic_page ? diagnostic_segment[5] : ({1'b1,seg_data_0}))
);

// ===================== 原图像时序与帧缓存 =====================
video_timing_data video_timing_data_m0(
    .video_clk         (video_clk),
    .rst               (rst_all),
    .read_req          (video_read_req),
    .read_req_ack      (video_read_req_ack),
    .hs                (hs_0),
    .vs                (vs_0),
    .de                (de_0)
);

video_delay video_delay_m0(
    .video_clk         (video_clk),
    .rst               (rst_all),
    .read_en           (video_read_en),
    .read_data         (video_read_data[31:8]),
    .hs                (hs_0),
    .vs                (vs_0),
    .de                (de_0),
    .hs_r              (hs),
    .vs_r              (vs),
    .de_r              (de),
    .vout_data         (vout_data_raw)
);

// 首图提交前黑屏；提交后一直显示当前显示缓冲区内容
// Generation bit reaches the pixel domain only after the reader selects that frame.
image_transition #(.VIEW_WIDTH(480),.VIEW_HEIGHT(360)) u_image_transition (
    .video_clk(video_clk), .rst(rst_all), .vs(vs), .de(de),
    .rgb_in(osd_pixel_status[3] ? vout_data_raw : 24'd0),
    .transition_mode(animation_video ? 3'd0:transition_mode), .duration_sel(transition_duration),
    .slide_dir(animation_video ? 1'b0:slide_dir),
    .brightness(osd_brightness_video), .contrast(osd_contrast_video),
    .transition_req_toggle(transition_req_toggle),
    .transition_commit_toggle(osd_pixel_status[5]),
    .dark_ack_toggle(transition_dark_toggle), .done_toggle(transition_done_toggle),
    .rgb_out(vout_data)
);

frame_read_write #(
    .WRITE_V_FLIP     (1),
    .FRAME_WIDTH      (640),
    .FRAME_HEIGHT     (480)
) frame_read_write_m0(
    .auxiliary_hold(cache_hold),.legacy_busy(legacy_busy),
    .mem_clk           (ext_mem_clk),
    .rst               (rst_all),
    .Sdr_init_done     (Sdr_init_done),
    .Sdr_init_ref_vld  (Sdr_init_ref_vld),
    .Sdr_busy          (Sdr_busy),

    .App_rd_en         (frame_App_rd_en),
    .App_rd_addr       (frame_App_rd_addr),
    .Sdr_rd_en         (Sdr_rd_en && !cache_aux_active),
    .Sdr_rd_dout       (Sdr_rd_dout),

    .read_clk          (video_clk),
    .read_req          (video_read_req),
    .read_req_ack      (video_read_req_ack),
    .read_finish       (),
    .read_status(osd_mem_status), .read_frame_status(osd_read_status),
    .read_addr_0       (BUF0_ADDR),
    .read_addr_1       (BUF1_ADDR),
    .read_addr_2       (24'd0),
    .read_addr_3       (24'd0),
    .read_addr_index   (OSD_STATUS_MODE ? osd_mem_status[7:6] : disp_buf_idx),
    .read_len          (FRAME_PIXELS),
    .read_en           (video_read_en),
    .read_data         (video_read_data),

    .App_wr_en         (frame_App_wr_en),
    .App_wr_addr       (frame_App_wr_addr),
    .App_wr_din        (frame_App_wr_din),
    .App_wr_dm         (App_wr_dm),

    .write_clk         (sd_card_clk),
    .write_req         (dma_write_req),
    .write_req_ack     (sd_card_write_req_ack),
    .write_finish      (frame_write_finish),
    .storage_diag_mem(storage_diag_mem), .storage_diag_write(storage_diag_write),
    .write_addr_0      (BUF0_ADDR),
    .write_addr_1      (BUF1_ADDR),
    .write_addr_2      (24'd0),
    .write_addr_3      (24'd0),
    .write_addr_index  (dma_write_bank),
    .write_len         (FRAME_PIXELS),
    .write_usedw(write_fifo_usedw), .diagnostic_read(diagnostic_read),
    .write_en          (sd_card_write_en),
    .write_data        (sd_card_write_data)
);

sdram U3(
    .Clk               (ext_mem_clk),
    .Clk_sft           (ext_mem_clk_sft),
    .Rst               (rst_all),
    .Sdr_init_done     (Sdr_init_done),
    .Sdr_init_ref_vld  (Sdr_init_ref_vld),
    .Sdr_busy          (Sdr_busy),
    .App_wr_en         (App_wr_en),
    .App_wr_addr       (App_wr_addr),
    .App_wr_dm         (App_wr_dm),
    .App_wr_din        (App_wr_din),
    .App_rd_en         (App_rd_en),
    .App_rd_addr       (App_rd_addr),
    .Sdr_rd_en         (Sdr_rd_en),
    .Sdr_rd_dout       (Sdr_rd_dout)
);

// TF PCM is serialized with the existing 64-bit/channel transport.
I2S_receiver u_I2S_receiver(
    .I_clk              (video_clk),
    .I_rst              (rst_all),
    .I_i2s_BCLK         (audio_i2s_bclk),
    .I_i2s_LRCK         (audio_i2s_lrck),
    .I_i2s_DOUT         (audio_i2s_dout),
    .O_audio_valid      (audio_valid),
    .O_audio_left_data  (audio_left_data),
    .O_audio_right_data (audio_right_data)
);

audio_arc_calculate #(
    .ACR_N         (6144)
) u_audio_arc_calculate (
    .I_clk         (video_clk),
    .I_rst         (rst_all),
    .I_audio_valid (audio_valid),
    .O_acr_valid   (acr_valid),
    .O_acr_cts     (acr_cts),
    .O_acr_n       (acr_n)
);

// ===================== RGB/DE 转 AXIS 视频 =====================
// Candidate-only insertion before the existing RGB-to-AXIS instance.
wire [23:0] osd_pos_rgb;
wire osd_pos_de, osd_pos_hs, osd_pos_vs, osd_position_valid, osd_frame_tick;
wire [9:0] osd_pos_x;
wire [8:0] osd_pos_y;
wire [23:0] osd_video_rgb;
wire osd_video_de, osd_video_hs, osd_video_vs;
wire [9:0] osd_video_x;
wire [8:0] osd_video_y;
wire [23:0] spectrum_video_rgb;
wire spectrum_video_de, spectrum_video_hs, spectrum_video_vs;
wire [9:0] spectrum_video_x;
wire [8:0] spectrum_video_y;
// SW=1001 selects the compact audio/caption layout. Commit once in vblank,
// so captions and spectrum always use one frame-constant selection.
reg audio_mode_frame;
always @(posedge video_clk or posedge rst_all) begin
    if (rst_all) audio_mode_frame <= 1'b0;
    else if (osd_frame_tick) audio_mode_frame <= diagnostic_sw_video == 4'h9;
end
(* ASYNC_REG="TRUE",keep="true" *) reg osd_display_meta, osd_display_sync;
reg osd_enable_frame;

// Only the OSD enable consumes this synchronized status. The original
// display_valid black-screen gate and TF/SDRAM path remain unchanged.
always @(posedge video_clk or posedge rst_all) begin
    if (rst_all) begin
        osd_display_meta <= 1'b0;
        osd_display_sync <= 1'b0;
        osd_enable_frame <= 1'b0;
    end else begin
        osd_display_meta <= display_valid;
        osd_display_sync <= osd_display_meta;
        if (osd_frame_tick)
            osd_enable_frame <= osd_display_sync;
    end
end

osd_video_position #(.VS_ACTIVE(1'b0)) u_osd_video_position (
    .clk(video_clk), .rst(rst_all),
    .in_rgb(vout_data), .in_de(de), .in_hs(hs), .in_vs(vs),
    .out_rgb(osd_pos_rgb), .out_de(osd_pos_de),
    .out_hs(osd_pos_hs), .out_vs(osd_pos_vs),
    .out_x(osd_pos_x), .out_y(osd_pos_y),
    .position_valid(osd_position_valid), .frame_tick(osd_frame_tick)
);
// Latch after the memory frame request, at active-video entry. Metadata
// has the entire vertical back porch to cross; first text pixel is x=16.
reg osd_pos_de_prev;
reg [4:0] osd_status_frame;
always @(posedge video_clk or posedge rst_all) begin
    if (rst_all) begin osd_pos_de_prev<=0; osd_status_frame<=0; end
    else begin
        osd_pos_de_prev<=osd_pos_de;
        if (osd_pos_de && !osd_pos_de_prev && osd_pos_y==0)
            osd_status_frame<=osd_pixel_status[4:0];
    end
end
wire [23:0] diagnostic_overlay_rgb;
zoom_diagnostics u_zoom_diagnostics(
 .clk(video_clk),.rst(rst_all),.select_pattern(1'b0),
 .de(osd_pos_de),.hs(osd_pos_hs),.vs(osd_pos_vs),.position_valid(osd_position_valid),
 .x(osd_pos_x),.y(osd_pos_y),.rgb(osd_pos_rgb),.read_health(diagnostic_read),
 .rgb_out(diagnostic_overlay_rgb),.health(diagnostic_health_video));
osd_overlay #(.STATUS_MODE(OSD_STATUS_MODE)) u_osd_overlay (
    .music_track(ui_state_frame[34]),.music_paused(ui_state_frame[33]),.music_volume(ui_state_frame[32:29]),
    .compact_layout(1'b1),
    .scale_mode(ui_modes_frame[1:0]),.interpolation(ui_modes_frame[2]),
    .transition_mode(ui_modes_frame[5:3]),
    .image_valid(osd_status_frame[3]), .image_index(osd_status_frame[2:0]),
    .auto_play(osd_status_frame[4]),
    .sw_code(ui_sw_frame), .setting_value(osd_value_video),
    .brightness(osd_brightness_video), .contrast(osd_contrast_video),
    .sub_mode(osd_sub_mode_video),
    .text_mode(osd_text_mode_video), .scroll_speed(osd_scroll_speed_video),
    .scroll_dir(osd_scroll_dir_video),
    .clk(video_clk), .rst(rst_all),
    .enable(osd_position_valid && (OSD_STATUS_MODE || osd_enable_frame)),
    .in_rgb(diagnostic_overlay_rgb), .in_de(osd_pos_de),
    .in_hs(osd_pos_hs), .in_vs(osd_pos_vs),
    .in_x(osd_pos_x), .in_y(osd_pos_y),
    .out_rgb(osd_video_rgb), .out_de(osd_video_de),
    .out_hs(osd_video_hs), .out_vs(osd_video_vs),
    .out_x(osd_video_x), .out_y(osd_video_y)
);

// The FFT observes existing PCM only. HDMI audio and all clocks are unchanged.
// RGB/DE/HS/VS/X/Y gain three matched registers, including bypass mode.
audio_spectrum_overlay u_audio_spectrum_overlay (
    .clk(video_clk), .rst(rst_all), .frame_tick(osd_frame_tick),
    .enable(1'b1), .audio_valid(audio_valid),
    .audio_left(audio_left_data), .audio_right(audio_right_data),
    .in_rgb(osd_video_rgb), .in_de(osd_video_de),
    .in_hs(osd_video_hs), .in_vs(osd_video_vs),
    .in_x(osd_video_x), .in_y(osd_video_y),
    .out_rgb(spectrum_video_rgb), .out_de(spectrum_video_de),
    .out_hs(spectrum_video_hs), .out_vs(spectrum_video_vs),
    .out_x(spectrum_video_x), .out_y(spectrum_video_y)
);

video_rgb_to_axis_640x480 u_video_rgb_to_axis_640x480(
    .I_clk         (video_clk),
    .I_rst         (rst_all),
    .I_vs          (spectrum_video_vs),
    .I_de          (spectrum_video_de),
    .I_rgb         (spectrum_video_rgb),
    .O_video_user  (axis_s_user),
    .O_video_valid (axis_s_valid),
    .O_video_last  (axis_s_last),
    .O_video_data  (axis_s_data)
);

// 上电后自动打一拍，触发一次 EDID 读取
startup_pulse #(
    .CNT_MAX(20'd100000)
) u_startup_pulse (
    .I_clk   (video_clk),
    .I_rst   (rst_all),
    .O_pulse (edid_trig)
);

// ===================== 带音频的 HDMI 1.4b 发射 =====================
hdmi_1_4b_transmitter_core_wrapper #(
    .DEVICE                 ( "EG"       ),
    .HTOTAL                 ( 800        ),
    .HSA                    ( 96         ),
    .HFP                    ( 16         ),
    .HBP                    ( 48         ),
    .HACTIVE                ( 640        ),
    .VTOTAL                 ( 525        ),
    .VSA                    ( 2          ),
    .VFP                    ( 10         ),
    .VBP                    ( 33         ),
    .VACTIVE                ( 480        ),
    .VIDEO_VIC              ( 1          ),
    .VIDEO_TPG              ( "Disable"  ),
    .VIDEO_FORMAT           ( "RGB"      ),
    .AUDIO_SAMPLE_RATE      ( "48K"      ),
    .IIC_SCL_DIV            ( 250        )
) u_hdmi_1_4b_transmitter_core_wrapper(
    .I_pixel_clk        (video_clk),
    .I_rst              (rst_all),
    .I_edid_read_trig   (edid_trig),
    .O_edid_read_valid  (edid_valid),
    .O_edid_read_data   (edid_data),

    .I_axis_s_user      (axis_s_user),
    .I_axis_s_valid     (axis_s_valid),
    .I_axis_s_last      (axis_s_last),
    .I_axis_s_data      (axis_s_data),
    .O_axis_s_ready     (axis_s_ready),

    .I_audio_valid      (audio_valid),
    .I_audio_left_data  (audio_left_data),
    .I_audio_right_data (audio_right_data),
    .I_acr_valid        (acr_valid),
    .I_acr_cts          (acr_cts),
    .I_acr_n            (acr_n),

    .O_video_locked     (),
    .O_ddc_scl          (HDMI_DDC_SCL),
    .IO_ddc_sda         (HDMI_DDC_SDA),

    .O_ch0_tmds_data    (tmds_ch0_data),
    .O_ch1_tmds_data    (tmds_ch1_data),
    .O_ch2_tmds_data    (tmds_ch2_data),
    .O_clk_tmds_data    (tmds_clk_data)
);

hdmi_phy_wrapper #(
    .DEVICE ( "EG" )
) u_hdmi2phy_wrapper(
    .I_pixel_clk        (video_clk),
    .I_serial_clk       (hdmi_5x_clk),
    .I_rst              (rst_all),
    .I_tmds_channel_0   (tmds_ch0_data),
    .I_tmds_channel_1   (tmds_ch1_data),
    .I_tmds_channel_2   (tmds_ch2_data),
    .I_tmds_channel_clk (tmds_clk_data),
    .O_tmds_ch0_p       (HDMI_D0_P),
    .O_tmds_ch1_p       (HDMI_D1_P),
    .O_tmds_ch2_p       (HDMI_D2_P),
    .O_tmds_clk_p       (HDMI_CLK_P)
);

endmodule
