// HX4S20 用户控制模块
// 物理按键：K3 低有效；SW1~SW4 拨上为 1。
// sw[3:0] 按 SW4 SW3 SW2 SW1 排列。
// SW=0100：K3 循环直接切换 -> 淡出淡入 -> 滑动揭幕。
// SW=0101：K3 循环转场时长 短(15帧) -> 中(30帧) -> 长(60帧)。
module user_control #(
    parameter integer CLK_FREQ_HZ = 50_000_000,
    parameter integer FILTER_MS   = 20
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       key3_n,
    input  wire [3:0] sw,
    output reg  [1:0] transition_mode,
    output reg  [1:0] duration_sel,
    output reg [1:0] scale_mode,
    output reg  [3:0] sw_stable
);
    localparam integer FILTER_CYCLES = (CLK_FREQ_HZ / 1000) * FILTER_MS;
    localparam [1:0] MODE_DIRECT = 2'd0;
    localparam [1:0] MODE_FADE   = 2'd1;
    localparam [1:0] MODE_SLIDE  = 2'd2;

    reg [3:0] sw_meta, sw_sync;
    reg [3:0] sw_candidate;
    reg [20:0] sw_filter_cnt;
    reg sw_ready;

    reg key_meta, key_sync;
    reg key_candidate, key_stable;
    reg [20:0] key_filter_cnt;
    reg key3_press;

    // SW 输入同步 + 稳定滤波。只有连续稳定 FILTER_MS 后才更新 sw_stable。
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sw_meta        <= 4'b0000;
            sw_sync        <= 4'b0000;
            sw_candidate   <= 4'b0000;
            sw_filter_cnt  <= 21'd0;
            sw_stable      <= 4'b0000;
            sw_ready       <= 1'b0;
        end else begin
            sw_meta <= sw;
            sw_sync <= sw_meta;

            if (sw_sync != sw_candidate) begin
                sw_candidate  <= sw_sync;
                sw_filter_cnt <= 21'd0;
            end else if (sw_filter_cnt < FILTER_CYCLES) begin
                sw_filter_cnt <= sw_filter_cnt + 1'b1;
            end else begin
                sw_stable <= sw_candidate;
                sw_ready  <= 1'b1;
            end
        end
    end

    // K3 同步、消抖；按下（低电平）只产生一个 clk 周期脉冲。
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            key_meta       <= 1'b1;
            key_sync       <= 1'b1;
            key_candidate  <= 1'b1;
            key_stable     <= 1'b1;
            key_filter_cnt <= 21'd0;
            key3_press     <= 1'b0;
        end else begin
            key_meta   <= key3_n;
            key_sync   <= key_meta;
            key3_press <= 1'b0;

            if (key_sync != key_candidate) begin
                key_candidate  <= key_sync;
                key_filter_cnt <= 21'd0;
            end else if (key_filter_cnt < FILTER_CYCLES) begin
                key_filter_cnt <= key_filter_cnt + 1'b1;
            end else if (key_stable != key_candidate) begin
                key_stable <= key_candidate;
                if (key_candidate == 1'b0)
                    key3_press <= 1'b1;
            end
        end
    end

    // 参数独立保存；SW 只选择设置项，不会因拨动开关而直接改变参数。
    // K3 在 SW 正在变化/滤波期间的操作会被丢弃。
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scale_mode <= 2'd0;
            transition_mode <= MODE_DIRECT;
            duration_sel    <= 2'd1; // 默认中等：30 帧
        end else if (key3_press && sw_ready &&
                     (sw_sync == sw_candidate) &&
                     (sw_candidate == sw_stable)) begin
            case (sw_stable)
                4'b0100: begin
                    case (transition_mode)
                        MODE_DIRECT: transition_mode <= MODE_FADE;
                        MODE_FADE:   transition_mode <= MODE_SLIDE;
                        default:     transition_mode <= MODE_DIRECT;
                    endcase
                end
                4'b0111: scale_mode <= scale_mode==2 ? 0 : scale_mode+1'b1;
                4'b0101: begin
                    if (duration_sel >= 2'd2)
                        duration_sel <= 2'd0;
                    else
                        duration_sel <= duration_sel + 1'b1;
                end
                default: begin
                    // 未开放的 SW 编码不执行操作。
                end
            endcase
        end
    end
endmodule
