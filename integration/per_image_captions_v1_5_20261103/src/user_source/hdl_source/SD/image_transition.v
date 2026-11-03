// 图片转场与画面效果模块：8 种转场 + 亮度/对比度调节。
// 本模块只处理显示像素，不读取 SD 卡，也不直接切换缓冲区。
//
// transition_mode:
//   0 直接切换   1 淡出淡入   2 水平滑动   3 风车旋转
//   4 垂直擦除   5 百叶窗     6 圆形光圈   7 方块溶解
// duration_sel: 0=15帧，1=30帧，2=60帧
// slide_dir: 控制水平滑动与垂直擦除的方向
// brightness: 0~10，5 为中性；contrast: 0~10，5 为中性（1.0 倍）
//
// 所有几何转场共用一条 0~1024 的归一化进度 frac，由它派生出各自的边界量，
// 这样只需要 3 个常数除法，其余全是移位/常数乘加。
// 亮度/对比度折叠进淡化的乘法器里，逐像素不增加乘法器：
//   base = (c*KG + 128) >> 8 ; out = clamp(base + OG)
//   KG = (K*gain) >> 8 ; OG = ((128 - K/2 + B) * gain) >> 8
module image_transition #(
    parameter integer FRAME_WIDTH  = 640,
    parameter integer FRAME_HEIGHT = 480
)(
    input              video_clk,
    input              rst,
    input              vs,
    input              de,
    input      [23:0]  rgb_in,
    input      [2:0]   transition_mode,
    input      [1:0]   duration_sel,
    input              slide_dir,
    input      [3:0]   brightness,
    input      [3:0]   contrast,
    input              transition_req_toggle,
    input              transition_commit_toggle,
    output reg         dark_ack_toggle,
    output reg         done_toggle,
    output     [23:0]  rgb_out
);
    localparam [2:0] MODE_DIRECT = 3'd0;
    localparam [2:0] MODE_FADE   = 3'd1;
    localparam [2:0] MODE_SLIDE  = 3'd2;
    localparam [2:0] MODE_ROTATE = 3'd3;
    localparam [2:0] MODE_VSLIDE = 3'd4;
    localparam [2:0] MODE_BLIND  = 3'd5;
    localparam [2:0] MODE_IRIS   = 3'd6;
    localparam [2:0] MODE_BLOCK  = 3'd7;

    localparam integer X_W = (FRAME_WIDTH < 2) ? 1 : $clog2(FRAME_WIDTH + 1);
    localparam [9:0]  W_MAX     = FRAME_WIDTH;    // 640
    localparam [9:0]  H_MAX     = FRAME_HEIGHT;   // 480
    localparam [9:0]  ROT_MAX   = 10'd320;        // 风车张开度上限
    localparam [17:0] IRIS_FULL = 18'd160768;     // >= 320^2+240^2，满屏可见

    reg [2:0] req_sync;
    reg [2:0] commit_sync;
    reg [2:0] mode_meta, mode_sync;
    reg [1:0] duration_meta, duration_sync;
    reg dir_meta, dir_sync;
    reg req_seen, commit_seen, vs_d, de_d;
    reg [2:0] mode_latched;
    reg [1:0] duration_latched;
    reg dir_latched;
    reg transition_pending;

    reg eff_out, eff_in;
    reg direct_wait_ack;
    reg [8:0] gain;              // 0..256，256=原始亮度
    reg [6:0] frame_count;
    reg [X_W-1:0] slide_pos;     // 水平滑动可见宽度
    reg [9:0] vert_pos;          // 垂直擦除可见行数
    reg [9:0] rot_T;             // 风车张开度
    reg [5:0] blind_pos;         // 百叶窗每条带可见高度 0..32
    reg [17:0] iris_sq;          // 圆形光圈半径平方
    reg [7:0] blk_thr;           // 方块溶解阈值 0..128
    reg [X_W-1:0] x_count;
    reg [8:0] y_count;
    reg [3:0] bright_l, contra_l;

    // 本次提交要显示的模式：普通切图用请求时锁存的值，首图提交用当前设置
    wire [2:0] cmode = transition_pending ? mode_latched : mode_sync;

    wire frame_tick = vs & ~vs_d;
    wire [6:0] frame_count_next = frame_count + 1'b1;
    wire [6:0] frames_total = (duration_latched == 2'd0) ? 7'd15 :
                              (duration_latched == 2'd2) ? 7'd60 : 7'd30;

    // ---------------- 统一进度 0..1024 ----------------
    // 注意：乘法必须显式扩到 18 位，否则 Verilog 会把结果截断到操作数最大位宽（11 位），
    // frame_count>=2 时 1024*frame_count 就会溢出。
    wire [17:0] fc_x1024 = {11'd0, frame_count_next} * 18'd1024;
    wire [10:0] frac15 = fc_x1024 / 18'd15;
    wire [10:0] frac30 = fc_x1024 / 18'd30;
    wire [10:0] frac60 = fc_x1024 / 18'd60;
    wire [10:0] frac_raw = (duration_latched == 2'd0) ? frac15 :
                           (duration_latched == 2'd2) ? frac60 : frac30;
    wire [10:0] frac = (frac_raw > 11'd1024) ? 11'd1024 : frac_raw;

    // 各效果的边界量（frac=1024 时正好是满屏可见的端点）
    wire [8:0]  gain_new  = {3'd0, frac[10:2]};        // 0..256
    wire [9:0]  slide_new = (frac * 5) >> 3;           // 0..640
    wire [9:0]  rot_new   = (frac * 5) >> 4;           // 0..320
    wire [9:0]  vert_new  = (frac * 15) >> 5;          // 0..480
    wire [5:0]  blind_new = frac[10:5];                // 0..32
    wire [7:0]  blk_new   = {1'b0, frac[10:3]};        // 0..128
    wire [17:0] iris_new  = frac * 8'd157;             // 0..160768

    // ---------------- 亮度 / 对比度 ----------------
    reg [9:0] contrast_k;
    reg signed [8:0] bright_off;
    always @* begin
        case (contra_l)
            4'd0: contrast_k = 10'd126;
            4'd1: contrast_k = 10'd152;
            4'd2: contrast_k = 10'd178;
            4'd3: contrast_k = 10'd204;
            4'd4: contrast_k = 10'd230;
            4'd6: contrast_k = 10'd282;
            4'd7: contrast_k = 10'd308;
            4'd8: contrast_k = 10'd334;
            4'd9: contrast_k = 10'd360;
            4'd10: contrast_k = 10'd386;
            default: contrast_k = 10'd256;
        endcase
        case (bright_l)
            4'd0: bright_off = -9'sd80;
            4'd1: bright_off = -9'sd64;
            4'd2: bright_off = -9'sd48;
            4'd3: bright_off = -9'sd32;
            4'd4: bright_off = -9'sd16;
            4'd6: bright_off =  9'sd16;
            4'd7: bright_off =  9'sd32;
            4'd8: bright_off =  9'sd48;
            4'd9: bright_off =  9'sd64;
            4'd10: bright_off = 9'sd80;
            default: bright_off = 9'sd0;
        endcase
    end

    wire [9:0] k_half = contrast_k >> 1;
    wire signed [10:0] off0 = 11'sd128 - $signed({1'b0, k_half}) + bright_off;

    wire [17:0] kg_full = contrast_k * gain;
    wire [8:0]  kg      = kg_full[16:8];
    wire signed [20:0] og_product = off0 * $signed({1'b0, gain});
    wire signed [12:0] og = og_product >>> 8;

    wire [16:0] red_product   = {9'd0, rgb_in[23:16]} * {8'd0, kg};
    wire [16:0] green_product = {9'd0, rgb_in[15:8]}  * {8'd0, kg};
    wire [16:0] blue_product  = {9'd0, rgb_in[7:0]}   * {8'd0, kg};
    wire [8:0]  red_base   = (red_product   + 17'd128) >> 8;
    wire [8:0]  green_base = (green_product + 17'd128) >> 8;
    wire [8:0]  blue_base  = (blue_product  + 17'd128) >> 8;

    wire signed [12:0] red_sum   = $signed({4'd0, red_base})   + og;
    wire signed [12:0] green_sum = $signed({4'd0, green_base}) + og;
    wire signed [12:0] blue_sum  = $signed({4'd0, blue_base})  + og;

    wire [7:0] red_out   = (red_sum   < 13'sd0) ? 8'd0 : (red_sum   > 13'sd255) ? 8'd255 : red_sum[7:0];
    wire [7:0] green_out = (green_sum < 13'sd0) ? 8'd0 : (green_sum > 13'sd255) ? 8'd255 : green_sum[7:0];
    wire [7:0] blue_out  = (blue_sum  < 13'sd0) ? 8'd0 : (blue_sum  > 13'sd255) ? 8'd255 : blue_sum[7:0];
    wire [23:0] pixel_out = {red_out, green_out, blue_out};

    // ---------------- 各转场的可见窗口 ----------------
    wire [9:0] dx_abs = (x_count < 10'd320) ? (10'd320 - x_count) : (x_count - 10'd320);
    wire [9:0] dy_abs = (y_count < 9'd240)  ? ({1'b0, 9'd240 - y_count}) : ({1'b0, y_count - 9'd240});

    // 水平滑动：dir=0 可见左侧，dir=1 可见右侧
    wire [10:0] slide_start = {1'b0, W_MAX} - {1'b0, slide_pos};
    wire        slide_visible = dir_latched
                              ? ({1'b0, x_count} >= slide_start)
                              : (x_count < slide_pos);

    // 垂直擦除：dir=0 可见上方（黑幕自下往上），dir=1 可见下方
    wire [9:0]  vstart = H_MAX - vert_pos;
    wire        vslide_visible = dir_latched
                               ? ({1'b0, y_count} >= vstart)
                               : ({1'b0, y_count} < vert_pos);

    // 风车：m*256 < M*T
    wire [9:0]  rot_min = (dx_abs < dy_abs) ? dx_abs : dy_abs;
    wire [9:0]  rot_max = (dx_abs > dy_abs) ? dx_abs : dy_abs;
    wire [19:0] rot_lhs = {2'b00, rot_min, 8'd0};
    wire [19:0] rot_rhs = rot_max * rot_T;
    wire        rot_visible = (rot_max == 10'd0) || (rot_lhs < rot_rhs);

    // 百叶窗：480 = 15 条 32 行的横带，每条带可见高度 blind_pos
    wire        blind_visible = ({1'b0, y_count[4:0]} < {1'b0, blind_pos});

    // 圆形光圈：dx^2 + dy^2 <= R^2
    wire [17:0] iris_d2 = ({8'd0, dx_abs} * {8'd0, dx_abs}) +
                          ({8'd0, dy_abs} * {8'd0, dy_abs});
    wire        iris_visible = (iris_d2 <= iris_sq);

    // 方块溶解：64x64 分块，10 列 x 8 行，共 80 块，按伪随机顺序消失
    wire [6:0]  blk_idx   = ({1'b0, y_count[8:6]} * 4'd10) + {3'd0, x_count[9:6]};
    wire [11:0] blk_prod  = blk_idx * 6'd37;
    wire [7:0]  blk_order = {1'b0, blk_prod[6:0]};
    wire        blk_visible = (blk_order >= blk_thr);

    // 水平/垂直有效区坐标。DE 上升沿对应每行 x=0，每行结束 y 加一。
    always @(posedge video_clk or posedge rst) begin
        if (rst) begin
            x_count <= {X_W{1'b0}};
            y_count <= 9'd0;
            de_d    <= 1'b0;
        end else begin
            de_d <= de;
            if (frame_tick)
                y_count <= 9'd0;
            else if (!de) begin
                x_count <= {X_W{1'b0}};
                if (de_d && (y_count < FRAME_HEIGHT))
                    y_count <= y_count + 1'b1;
            end else if (x_count < FRAME_WIDTH) begin
                x_count <= x_count + 1'b1;
            end
        end
    end

    // 控制事件同步到视频像素时钟域；模式/时长/方向在切图请求时锁存。
    always @(posedge video_clk or posedge rst) begin
        if (rst) begin
            req_sync          <= 3'b000;
            commit_sync       <= 3'b000;
            mode_meta         <= MODE_DIRECT;
            mode_sync         <= MODE_DIRECT;
            duration_meta     <= 2'd1;
            duration_sync     <= 2'd1;
            dir_meta          <= 1'b0;
            dir_sync          <= 1'b0;
            req_seen          <= 1'b0;
            commit_seen       <= 1'b0;
            vs_d              <= 1'b0;
            mode_latched      <= MODE_DIRECT;
            duration_latched  <= 2'd1;
            dir_latched       <= 1'b0;
            transition_pending<= 1'b0;
            eff_out           <= 1'b0;
            eff_in            <= 1'b0;
            direct_wait_ack   <= 1'b0;
            gain              <= 9'd256;
            frame_count       <= 7'd0;
            slide_pos         <= W_MAX;
            vert_pos          <= H_MAX;
            rot_T             <= ROT_MAX;
            blind_pos         <= 6'd32;
            iris_sq           <= IRIS_FULL;
            blk_thr           <= 8'd0;
            bright_l          <= 4'd5;
            contra_l          <= 4'd5;
            dark_ack_toggle   <= 1'b0;
            done_toggle       <= 1'b0;
        end else begin
            req_sync      <= {req_sync[1:0], transition_req_toggle};
            commit_sync   <= {commit_sync[1:0], transition_commit_toggle};
            mode_meta     <= transition_mode;
            mode_sync     <= mode_meta;
            duration_meta <= duration_sel;
            duration_sync <= duration_meta;
            dir_meta      <= slide_dir;
            dir_sync      <= dir_meta;
            vs_d          <= vs;

            // 新切图请求：按当前设置锁存效果、时长、方向，并回到“整幅可见”端点
            if (req_sync[2] != req_seen) begin
                req_seen           <= req_sync[2];
                mode_latched       <= mode_sync;
                duration_latched   <= duration_sync;
                dir_latched        <= dir_sync;
                transition_pending <= 1'b1;
                frame_count        <= 7'd0;
                eff_in             <= 1'b0;
                gain               <= 9'd256;
                slide_pos          <= W_MAX;
                vert_pos           <= H_MAX;
                rot_T              <= ROT_MAX;
                blind_pos          <= 6'd32;
                iris_sq            <= IRIS_FULL;
                blk_thr            <= 8'd0;
                if (mode_sync == MODE_DIRECT) begin
                    eff_out         <= 1'b0;
                    direct_wait_ack <= 1'b1;
                end else begin
                    eff_out         <= 1'b1;
                    direct_wait_ack <= 1'b0;
                end
            end

            // 缓冲区提交事件：开始显示新图
            if (commit_sync[2] != commit_seen && !de) begin
                commit_seen <= commit_sync[2];
                if (!transition_pending) begin
                    mode_latched     <= mode_sync;
                    duration_latched <= duration_sync;
                    dir_latched      <= dir_sync;
                end
                frame_count     <= 7'd0;
                eff_out         <= 1'b0;
                direct_wait_ack <= 1'b0;
                if (cmode == MODE_DIRECT) begin
                    done_toggle <= commit_sync[2];
                    eff_in      <= 1'b0;
                    gain        <= 9'd256;
                    slide_pos   <= W_MAX;
                    vert_pos    <= H_MAX;
                    rot_T       <= ROT_MAX;
                    blind_pos   <= 6'd32;
                    iris_sq     <= IRIS_FULL;
                    blk_thr     <= 8'd0;
                end else begin
                    eff_in      <= 1'b1;
                    // 只有淡化需要把增益降到 0，其余模式保持满亮度（否则画面永远全黑）
                    gain        <= (cmode == MODE_FADE) ? 9'd0 : 9'd256;
                    slide_pos   <= {X_W{1'b0}};
                    vert_pos    <= 10'd0;
                    rot_T       <= 10'd0;
                    blind_pos   <= 6'd0;
                    iris_sq     <= 18'd0;
                    blk_thr     <= 8'd128;
                end
                transition_pending <= 1'b0;
            end

            // 每个视频帧只更新一次边界量
            if (frame_tick && (req_sync[2] == req_seen) &&
                (commit_sync[2] == commit_seen)) begin
                bright_l <= brightness;
                contra_l <= contrast;
                if (direct_wait_ack) begin
                    direct_wait_ack <= 1'b0;
                    dark_ack_toggle <= req_seen;
                end else if (eff_out) begin
                    frame_count <= frame_count_next;
                    case (mode_latched)
                        MODE_FADE:   gain      <= 9'd256 - gain_new;
                        MODE_SLIDE:  slide_pos <= W_MAX - slide_new;
                        MODE_ROTATE: rot_T     <= ROT_MAX - rot_new;
                        MODE_VSLIDE: vert_pos  <= H_MAX - vert_new;
                        MODE_BLIND:  blind_pos <= 6'd32 - blind_new;
                        MODE_IRIS:   iris_sq   <= IRIS_FULL - iris_new;
                        MODE_BLOCK:  blk_thr   <= blk_new;          // 阈值越大越黑
                        default:     ;
                    endcase
                    if (frame_count_next >= frames_total) begin
                        eff_out         <= 1'b0;
                        dark_ack_toggle <= req_seen;
                    end
                end else if (eff_in) begin
                    frame_count <= frame_count_next;
                    case (mode_latched)
                        MODE_FADE:   gain      <= gain_new;
                        MODE_SLIDE:  slide_pos <= slide_new[X_W-1:0];
                        MODE_ROTATE: rot_T     <= rot_new;
                        MODE_VSLIDE: vert_pos  <= vert_new;
                        MODE_BLIND:  blind_pos <= blind_new;
                        MODE_IRIS:   iris_sq   <= iris_new;
                        MODE_BLOCK:  blk_thr   <= 8'd128 - blk_new; // 阈值越小越亮
                        default:     ;
                    endcase
                    if (frame_count_next >= frames_total) begin
                        eff_in      <= 1'b0;
                        done_toggle <= commit_seen;
                    end
                end
            end
        end
    end

    // DE=0 输出黑色；转场期间 RGB、同步与 DE 均不暂停。
    assign rgb_out = !de ? 24'h000000 :
                     (mode_latched == MODE_FADE)   ? pixel_out :
                     (mode_latched == MODE_SLIDE)  ? (slide_visible  ? pixel_out : 24'h000000) :
                     (mode_latched == MODE_ROTATE) ? (rot_visible    ? pixel_out : 24'h000000) :
                     (mode_latched == MODE_VSLIDE) ? (vslide_visible ? pixel_out : 24'h000000) :
                     (mode_latched == MODE_BLIND)  ? (blind_visible  ? pixel_out : 24'h000000) :
                     (mode_latched == MODE_IRIS)   ? (iris_visible   ? pixel_out : 24'h000000) :
                     (mode_latched == MODE_BLOCK)  ? (blk_visible    ? pixel_out : 24'h000000) :
                     pixel_out;
endmodule
