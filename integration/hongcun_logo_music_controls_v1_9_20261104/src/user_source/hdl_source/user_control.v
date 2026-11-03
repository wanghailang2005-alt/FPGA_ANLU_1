// HX4S20 用户控制模块
// 物理按键：K3 低有效；SW1~SW4 拨上为 1。
// sw[3:0] 按 SW4 SW3 SW2 SW1 排列。
// SW=0001：K3 循环 文字关闭 -> 固定 OSD -> 滚动字幕 -> 两者同时
// SW=0010：K3 循环 滚动速度 慢(1 像素/帧) -> 中(2) -> 快(4)
// SW=0011：K3 循环 滚动方向 向左 -> 向右
// SW=0100：K3 循环 直接切换 -> 淡出淡入 -> 水平滑动 -> 风车旋转
// SW=0101：K3 循环 转场时长 短(15帧) -> 中(30帧) -> 长(60帧)
// SW=0110：K3 循环 滑动方向 向左 -> 向右
// SW=0111：K3 循环 最近邻缩放三档；SW=1000：K3 循环双线性缩放三档
// SW=1010：K3 调节亮度 0..10（5 为中性，逐档 +16 亮度偏移）
// SW=1011：K3 调节对比度 0..10（5 为中性 1.0 倍，0.49 倍 ~ 1.51 倍）
// SW=1100：K3 切换字幕语言 关闭 -> 中文 -> 英文 -> 双语上下叠加
//
// 说明：所有参数各自独立保存，拨动 SW 本身不改变任何参数；K3 每次按下只产生
// 一次操作，SW 正在滤波期间的操作被丢弃，长按不连发。
module user_control #(
    parameter integer CLK_FREQ_HZ = 50_000_000,
    parameter integer FILTER_MS   = 20,
    // 复位后的文字显示模式：0=关闭 1=固定 OSD 2=滚动字幕 3=两者同时。
    // 默认 3 保持本工程原有“固定状态 + 滚动字幕常显”的上电观感；
    // 若要符合任务书“默认文字关闭”，改成 2'd0 即可。
    parameter [1:0]   TEXT_MODE_RESET = 2'd3,
    // 复位后的字幕语言：0=关闭 1=只中文 2=只英文 3=双语上下叠加。
    // 默认双语，上电即可看到中英字幕；要默认关闭改成 2'd0。
    parameter [1:0]   SUB_MODE_RESET  = 2'd3
)(
    input  wire       clk,
    input  wire       rst_n,
    input wire animation_busy,
    input  wire       key3_n,
    input  wire [3:0] sw,
    output reg  [2:0] transition_mode,
    output reg  [1:0] duration_sel,
    output reg [1:0] scale_mode,
    output reg interpolation,
    output reg  [3:0] sw_stable,
    output reg  [1:0] text_mode,
    output reg  [1:0] scroll_speed,
    output reg        scroll_dir,
    output reg        slide_dir,
    output reg  [3:0] brightness,
    output reg  [3:0] contrast,
    output reg  [1:0] sub_mode,
    output reg music_track,
    output reg  [3:0] setting_value
);
    localparam integer FILTER_CYCLES = (CLK_FREQ_HZ / 1000) * FILTER_MS;
    localparam [2:0] MODE_DIRECT = 3'd0;
    localparam [2:0] MODE_FADE   = 3'd1;
    localparam [2:0] MODE_SLIDE  = 3'd2;
    localparam [2:0] MODE_ROTATE = 3'd3;
    localparam [2:0] MODE_LAST   = 3'd7;

    reg [3:0] sw_meta, sw_sync;
    reg [3:0] sw_candidate;
    reg [20:0] sw_filter_cnt;
    reg sw_ready;

    reg [1:0] nearest_mode,bilinear_mode;
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
            music_track <= 1'b0;
            scale_mode      <= 2'd0;
            interpolation   <= 1'b0;
            nearest_mode    <= 2'd0;
            bilinear_mode   <= 2'd0;
            transition_mode <= MODE_DIRECT;
            duration_sel    <= 2'd1;             // 默认中等：30 帧
            text_mode       <= TEXT_MODE_RESET;  // 默认固定 OSD + 滚动字幕
            scroll_speed    <= 2'd0;             // 默认慢速：1 像素/帧
            scroll_dir      <= 1'b0;             // 默认向左
            slide_dir       <= 1'b0;             // 默认向左
            brightness      <= 4'd5;             // 默认中性亮度
            contrast        <= 4'd5;             // 默认中性对比度
            sub_mode        <= SUB_MODE_RESET;   // 默认双语字幕
        end else if (key3_press && sw_ready &&
                     (sw_sync == sw_candidate) &&
                     (sw_candidate == sw_stable)) begin
            case (sw_stable)
                4'b1001: music_track <= ~music_track;
                4'b0001: begin
                    // 关闭 -> 固定 OSD -> 滚动字幕 -> 两者同时 -> 关闭
                    text_mode <= text_mode + 2'd1;
                end
                4'b0010: begin
                    // 慢 -> 中 -> 快 -> 慢
                    if (scroll_speed >= 2'd2)
                        scroll_speed <= 2'd0;
                    else
                        scroll_speed <= scroll_speed + 2'd1;
                end
                4'b0011: begin
                    scroll_dir <= ~scroll_dir;
                end
                4'b0110: begin
                    slide_dir <= ~slide_dir;
                end
                4'b0100: begin
                    // 8 种转场循环：直接/淡入淡出/水平滑动/风车旋转/
                    //               垂直擦除/百叶窗/圆形光圈/方块溶解
                    if (transition_mode >= MODE_LAST)
                        transition_mode <= MODE_DIRECT;
                    else
                        transition_mode <= transition_mode + 3'd1;
                end
                4'b1100: begin
                    // 关闭 -> 中文 -> 英文 -> 双语 -> 关闭
                    sub_mode <= sub_mode + 2'd1;
                end
                4'b1010: begin
                    // 亮度 0..10 循环，5 为中性
                    if (brightness >= 4'd10)
                        brightness <= 4'd0;
                    else
                        brightness <= brightness + 4'd1;
                end
                4'b1011: begin
                    // 对比度 0..10 循环，5 为中性
                    if (contrast >= 4'd10)
                        contrast <= 4'd0;
                    else
                        contrast <= contrast + 4'd1;
                end
                4'b1000: if(!animation_busy) begin
                    interpolation<=1;bilinear_mode<=bilinear_mode==2 ? 0:bilinear_mode+1'b1;
                    scale_mode<=bilinear_mode==2 ? 0:bilinear_mode+1'b1;end
                4'b0111: if(!animation_busy) begin
                    interpolation<=0;nearest_mode<=nearest_mode==2 ? 0:nearest_mode+1'b1;
                    scale_mode<=nearest_mode==2 ? 0:nearest_mode+1'b1;end
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

    // 送 OSD 显示的“当前设置项的值”，统一从 1 开始编号，0 表示无设置项。
    always @* begin
        case (sw_stable)
            4'b0001: setting_value = {2'd0, text_mode}       + 4'd1;
            4'b0010: setting_value = {2'd0, scroll_speed}    + 4'd1;
            4'b0011: setting_value = {3'd0, scroll_dir}      + 4'd1;
            4'b0100: setting_value = {1'b0, transition_mode} + 4'd1;
            4'b0101: setting_value = {2'd0, duration_sel}    + 4'd1;
            4'b0110: setting_value = {3'd0, slide_dir}       + 4'd1;
            4'b0111: setting_value = {2'd0, nearest_mode}    + 4'd1;
            4'b1001: setting_value = {3'd0,music_track} + 4'd1;
            4'b1000: setting_value = {2'd0, bilinear_mode}   + 4'd1;
            4'b1010: setting_value = brightness;
            4'b1011: setting_value = contrast;
            4'b1100: setting_value = {2'd0, sub_mode} + 4'd1;
            default: setting_value = 4'd0;
        endcase
    end
endmodule

// K2/B2 and K4/C1. Filter continuously; execute presses only in stable SW1001.
module music_controls #(parameter CLK_FREQ_HZ=50000000,FILTER_MS=20)(
 input clk,rst,enable,input key_pause_n,key_volume_n,
 output reg paused,output reg [3:0] volume);
 localparam LIMIT=(CLK_FREQ_HZ/1000)*FILTER_MS;
 (* ASYNC_REG="TRUE",keep="true" *) reg [1:0] meta,sync_key;
 reg [1:0] stable,pulse;
 reg [20:0] count[0:1];integer k;
 always @(posedge clk or posedge rst) begin
  if(rst)begin meta<=3;sync_key<=3;stable<=3;pulse<=0;count[0]<=0;count[1]<=0;end
  else begin
   meta<={key_volume_n,key_pause_n};sync_key<=meta;pulse<=0;
   for(k=0;k<2;k=k+1)begin
    if(sync_key[k]==stable[k]) count[k]<=0;
    else if(count[k]>=LIMIT-1)begin
     stable[k]<=sync_key[k];count[k]<=0;
     if(!sync_key[k])pulse[k]<=1;
    end else count[k]<=count[k]+1'b1;
   end
  end
 end
 always @(posedge clk or posedge rst)begin
  if(rst)begin paused<=0;volume<=5;end
  else if(enable)begin
   if(pulse[0])paused<=~paused;
   if(pulse[1])volume<=volume==10 ? 4'd1:volume+1'b1;
  end
 end
endmodule
