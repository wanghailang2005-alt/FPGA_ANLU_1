// 图片转场像素模块：直接切换、单图淡出淡入、水平滑动揭幕。
// 本模块只处理显示像素，不读取 SD 卡，也不直接切换 SDRAM 缓冲区。
// mode: 0=直接切换，1=淡出淡入，2=滑动揭幕（左到右的黑幕擦除/揭开）。
// duration_sel: 0=15帧，1=30帧，2=60帧。
module image_transition #(
    parameter integer FRAME_WIDTH  = 640,
    parameter integer FRAME_HEIGHT = 480
)(
    input              video_clk,
    input              rst,
    input              vs,
    input              de,
    input      [23:0]  rgb_in,
    input      [1:0]   transition_mode,
    input      [1:0]   duration_sel,
    input              transition_req_toggle,
    input              transition_commit_toggle,
    output reg         dark_ack_toggle,
    output reg         done_toggle,
    output     [23:0]  rgb_out
);
    localparam [1:0] MODE_DIRECT = 2'd0;
    localparam [1:0] MODE_FADE   = 2'd1;
    localparam [1:0] MODE_SLIDE  = 2'd2;
    localparam integer X_W = (FRAME_WIDTH < 2) ? 1 : $clog2(FRAME_WIDTH + 1);

    reg [2:0] req_sync;
    reg [2:0] commit_sync;
    reg [1:0] mode_meta, mode_sync;
    reg [1:0] duration_meta, duration_sync;
    reg req_seen, commit_seen, vs_d, de_d;
    reg [1:0] mode_latched, duration_latched;
    reg transition_pending;

    reg fading_out, fading_in;
    reg sliding_out, sliding_in;
    reg direct_wait_ack;
    reg [8:0] gain; // 0..256，256=原始亮度
    reg [6:0] frame_count;
    reg [X_W-1:0] slide_pos;
    reg [X_W-1:0] x_count;

    wire frame_tick = vs & ~vs_d;
    wire [6:0] frame_count_next = frame_count + 1'b1;
    wire [6:0] frames_total = (duration_latched == 2'd0) ? 7'd15 :
                              (duration_latched == 2'd2) ? 7'd60 : 7'd30;

    wire [8:0] gain_fraction = gain_for_frame(frame_count_next, duration_latched);
    wire [10:0] slide_fraction = slide_for_frame(frame_count_next, duration_latched);

    wire [16:0] red_product   = {9'd0, rgb_in[23:16]} * {8'd0, gain};
    wire [16:0] green_product = {9'd0, rgb_in[15:8]}  * {8'd0, gain};
    wire [16:0] blue_product  = {9'd0, rgb_in[7:0]}   * {8'd0, gain};
    wire [7:0] red_scaled   = (red_product   + 17'd128) >> 8;
    wire [7:0] green_scaled = (green_product + 17'd128) >> 8;
    wire [7:0] blue_scaled  = (blue_product  + 17'd128) >> 8;

    function [8:0] gain_for_frame;
        input [6:0] frame_num;
        input [1:0] duration;
        reg [31:0] scaled;
        begin
            case (duration)
                2'd0: scaled = (frame_num * 32'd256) / 32'd15;
                2'd2: scaled = (frame_num * 32'd256) / 32'd60;
                default: scaled = (frame_num * 32'd256) / 32'd30;
            endcase
            if (scaled > 256)
                gain_for_frame = 9'd256;
            else
                gain_for_frame = scaled[8:0];
        end
    endfunction

    function [10:0] slide_for_frame;
        input [6:0] frame_num;
        input [1:0] duration;
        reg [31:0] scaled;
        begin
            case (duration)
                2'd0: scaled = (frame_num * FRAME_WIDTH) / 32'd15;
                2'd2: scaled = (frame_num * FRAME_WIDTH) / 32'd60;
                default: scaled = (frame_num * FRAME_WIDTH) / 32'd30;
            endcase
            if (scaled > FRAME_WIDTH)
                slide_for_frame = FRAME_WIDTH;
            else
                slide_for_frame = scaled[10:0];
        end
    endfunction

    // 水平有效区坐标。DE 上升沿对应每行 x=0。
    always @(posedge video_clk or posedge rst) begin
        if (rst) begin
            x_count <= {X_W{1'b0}};
            de_d    <= 1'b0;
        end else begin
            de_d <= de;
            if (!de)
                x_count <= {X_W{1'b0}};
            else if (x_count < FRAME_WIDTH)
                x_count <= x_count + 1'b1;
        end
    end

    // 控制事件同步到视频像素时钟域；多位设置在一次转场期间锁存。
    always @(posedge video_clk or posedge rst) begin
        if (rst) begin
            req_sync          <= 3'b000;
            commit_sync       <= 3'b000;
            mode_meta         <= MODE_DIRECT;
            mode_sync         <= MODE_DIRECT;
            duration_meta     <= 2'd1;
            duration_sync     <= 2'd1;
            req_seen          <= 1'b0;
            commit_seen       <= 1'b0;
            vs_d              <= 1'b0;
            mode_latched      <= MODE_DIRECT;
            duration_latched  <= 2'd1;
            transition_pending<= 1'b0;
            fading_out        <= 1'b0;
            fading_in         <= 1'b0;
            sliding_out       <= 1'b0;
            sliding_in        <= 1'b0;
            direct_wait_ack   <= 1'b0;
            gain              <= 9'd256;
            frame_count       <= 7'd0;
            slide_pos         <= FRAME_WIDTH;
            dark_ack_toggle   <= 1'b0;
            done_toggle       <= 1'b0;
        end else begin
            req_sync      <= {req_sync[1:0], transition_req_toggle};
            commit_sync   <= {commit_sync[1:0], transition_commit_toggle};
            mode_meta     <= transition_mode;
            mode_sync     <= mode_meta;
            duration_meta <= duration_sel;
            duration_sync <= duration_meta;
            vs_d          <= vs;

            // 新切图请求：按当前设置锁存效果和时长。
            if (req_sync[2] != req_seen) begin
                req_seen           <= req_sync[2];
                mode_latched       <= mode_sync;
                duration_latched   <= duration_sync;
                transition_pending <= 1'b1;
                frame_count        <= 7'd0;
                fading_in          <= 1'b0;
                sliding_in         <= 1'b0;
                if (mode_sync == MODE_DIRECT) begin
                    fading_out      <= 1'b0;
                    sliding_out     <= 1'b0;
                    direct_wait_ack <= 1'b1;
                    gain            <= 9'd256;
                    slide_pos       <= FRAME_WIDTH;
                end else if (mode_sync == MODE_FADE) begin
                    fading_out  <= 1'b1;
                    fading_in   <= 1'b0;
                    sliding_out <= 1'b0;
                    sliding_in  <= 1'b0;
                    gain        <= 9'd256;
                end else begin
                    fading_out  <= 1'b0;
                    fading_in   <= 1'b0;
                    sliding_out <= 1'b1;
                    sliding_in  <= 1'b0;
                    slide_pos   <= FRAME_WIDTH;
                end
            end

            // 缓冲区提交事件：开始显示新图。若是首图提交，则使用当前设置；
            // 普通切图使用请求阶段锁存的设置，避免中途拨 SW 改变当前转场。
            if (commit_sync[2] != commit_seen && !de) begin
                commit_seen <= commit_sync[2];
                if (!transition_pending) begin
                    mode_latched     <= mode_sync;
                    duration_latched <= duration_sync;
                end
                frame_count     <= 7'd0;
                fading_out      <= 1'b0;
                sliding_out     <= 1'b0;
                direct_wait_ack <= 1'b0;
                if ((transition_pending ? mode_latched : mode_sync) == MODE_FADE) begin
                    gain       <= 9'd0;
                    fading_in  <= 1'b1;
                    sliding_in <= 1'b0;
                end else if ((transition_pending ? mode_latched : mode_sync) == MODE_SLIDE) begin
                    slide_pos  <= {X_W{1'b0}};
                    fading_in  <= 1'b0;
                    sliding_in <= 1'b1;
                end else begin
                    gain       <= 9'd256;
                    done_toggle <= commit_sync[2];
                    slide_pos  <= FRAME_WIDTH;
                    fading_in  <= 1'b0;
                    sliding_in <= 1'b0;
                end
                transition_pending <= 1'b0;
            end

            // 每个视频帧只更新一次效果系数/滑动边界。
            if (frame_tick && (req_sync[2] == req_seen) &&
                (commit_sync[2] == commit_seen)) begin
                if (direct_wait_ack) begin
                    direct_wait_ack <= 1'b0;
                    dark_ack_toggle <= req_seen;
                end else if (fading_out) begin
                    frame_count <= frame_count_next;
                    gain <= 9'd256 - gain_fraction;
                    if (frame_count_next >= frames_total) begin
                        gain              <= 9'd0;
                        fading_out        <= 1'b0;
                        dark_ack_toggle   <= req_seen;
                    end
                end else if (fading_in) begin
                    frame_count <= frame_count_next;
                    gain <= gain_fraction;
                    if (frame_count_next >= frames_total) begin
                        gain       <= 9'd256;
                        fading_in  <= 1'b0;
                        done_toggle <= commit_seen;
                    end
                end else if (sliding_out) begin
                    frame_count <= frame_count_next;
                    slide_pos <= FRAME_WIDTH - slide_fraction;
                    if (frame_count_next >= frames_total) begin
                        slide_pos       <= {X_W{1'b0}};
                        sliding_out     <= 1'b0;
                        dark_ack_toggle <= req_seen;
                    end
                end else if (sliding_in) begin
                    frame_count <= frame_count_next;
                    slide_pos <= slide_fraction;
                    if (frame_count_next >= frames_total) begin
                        slide_pos  <= FRAME_WIDTH;
                        sliding_in <= 1'b0;
                        done_toggle <= commit_seen;
                    end
                end
            end
        end
    end

    // DE=0 输出黑色；转场期间 RGB、同步与 DE 均不暂停。
    assign rgb_out = !de ? 24'h000000 :
                     (mode_latched == MODE_DIRECT) ? rgb_in :
                     (mode_latched == MODE_FADE) ? {red_scaled, green_scaled, blue_scaled} :
                     (x_count < slide_pos) ? rgb_in : 24'h000000;
endmodule
