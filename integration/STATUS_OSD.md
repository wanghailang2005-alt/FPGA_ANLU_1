> 当前成功版请以 [current_baseline](current_baseline/README.md) 和 [2026-10-25测试记录](../docs/2026-10-25.md) 为准；下文保留历史接入过程。

# 动态图片编号与轮播状态 OSD

2026-10-25。批准范围：动态文字、真实状态导出、跨域与帧标签对齐、候选工程接入、仿真和 TD 构建。未修改原 lab_ex5_i2s，未改引脚、PLL、SDC、音频或加密 IP；未执行烧录，未推送 GitHub。

## 预期板上行为

- 第一行 (16,16)：IMG:1 至 IMG:4，数字取扫描顺序；无有效图片 IMG:-。
- 第二行 (16,40)：AUTO:ON 或 AUTO:OFF。
- 继续使用黑色字形、透明背景。请先用浅色图片观察；黑色背景上黑字不可辨识。
- K2（顶层 key1）：下一张图片；K4（顶层 key2）：轮播开关；K1：复位。无新增 SW/K3。
- 轮播文字跟随真实状态，经帧请求和帧边界显示，允许约一帧反馈延迟。最新状态可能在下一帧生效，不能要求半帧立即更新。

## 状态与接口

SD 域新增 8 位 osd_status：bit7=AUTO，bit6=display_valid，bit5:4=显示缓冲区，bit3:2=缓冲区1图片编号，bit1:0=缓冲区0图片编号。图片编号为 0～3，排版显示时加一。

缓冲区标签与原控制器同一个完整写入提交条件更新。不能在 load_start 或 bmp_load_done 时提前更新标签。状态通过 osd_status_cdc 握手邮箱整体传至内存域；原帧读取器的 read_addr_index 改接这一致快照中的 bank，地址和标签一起经过两级输入寄存器，并在 S_ACK 中同拍锁定。read_frame_status 是 {AUTO,valid,image_index[1:0]}。

最终选择的 read_frame_status 再经邮箱传至像素域，第一有效行开始时保存至 osd_status_frame，并在本帧有效区内保持。第一文字行在 y=16，因此锁存不会影响首像素绘制。

邮箱以 held_data 保持整个数据字，请求/应答各经过两级同步；共享高有效异步复位。状态可合并，不能当作不可丢失的事件队列使用。未增加 false path 或放宽时序要求；板级 CDC 稳定性尚待验证。

## 延迟

| 视频模块 | 寄存级数 | 吞吐 |
|---|---:|---|
| 坐标恢复 | 1 | 每拍一个样本 |
| 排版 | 0 | 组合 |
| 字形行查询、取点、RGB叠加 | 3 | 每拍一个样本 |
| RGB-to-AXIS | 1 | 沿用现有无反压源 |
| 接入点至 AXIS 总计 | 5 | 启用与旁路等延迟 |

所有 RGB/DE/HS/VS/X/Y 等延迟。新增元数据邮箱不在像素通路中。原 HDMI ready 结构未改变，未证明任意 backpressure 支持。

## 验证结果

| 项目 | 证据 | 状态 |
|---|---|---|
| 4 次真实 SD 控制器帧提交、源读取完成不提前曝光、AUTO 消抖 | modelsim_status_source.log | SIM PASS；边界注入，非 TF 卡端到端 |
| 不同速率时钟、真实帧读取器地址/标签、帧中提交、快速更新、复位 | modelsim_status_transport.log，18 次场景检查 | SIM PASS |
| 11 帧、所有图片编号、无图、AUTO、旁路、复位、三级视频延迟 | modelsim_status_overlay.log，4,620,016 次检查 | SIM PASS |
| 真实视频时序、跨域状态、帧内稳定、AXIS USER/LAST/data/valid | modelsim_status_video.log，1,679,202 次检查 | SIM PASS |
| 固定 HELLO FPGA 参数模式回退 | modelsim_fixed_fallback.log，1,260,016 次检查 | SIM PASS；3 个新增未使用状态端口产生缺省连接警告 |
| 顶层及帧缓存包装 ModelSim 语法 | vlog 完成，0 errors / 0 warnings | 编译通过 |
| TD 综合、布局布线、bitgen | 本地 Runs 最终 td_20261025 日志及 .end 标记 | 完成，非零警告 |
| 实现资源 | status_utilization.txt | LUT 4620，reg 4134，BRAM9K 20，DSP 0，PLL 3 |
| video_clk 25 MHz setup | status_clock_summary.txt | WNS +4.581 ns |
| 整机 setup | status_timing_summary.txt | FAIL：WNS −6.699 ns，TNS −295.005 ns |
| 整机 hold | 同上 | WNS +0.003 ns，TNS 0 |
| STA coverage | status_clock_summary.txt | 95.58%，非全覆盖 |
| 动态版上板显示及音视频回归 | 待用户实际下载验证 | UNVERIFIED |

历史最差 SDRAM 路径仍存在；sd_card_clk 域也有负裕量（−0.732 ns）。不能把 bitgen 完成或视频域正裕量写成整机时序通过。编译仍有厂商 SDRAM/HDMI IP 内部的未驱动、初值忽略等警告；未将这些静默清除。

## 下载文件与回退

候选根目录：`../lab_ex5_i2s_osd/OSD_STATUS_IMG_AUTO_20261025.bit`

大小 629624 字节；SHA256：`a10b2a408cc34cf07ad900a02ddd0d45cab0f0178adebf26b849158e5cafbe2b`。

工程入口仍为候选的 `src/td_project/HDMI1.4b_Transmitter_v1.0.al`。TD 默认输出位于 Runs/phy_1，根目录 bit 是同内容的命名副本。

修改前的候选源码、工程清单和旧 bit 保存在候选目录 `fixed_osd_backup/`。这份旧 bit 是修改前本地构建产物；未将其 SHA256 与用户先前板测反馈绑定。需要回退源码时，按备份中的相对目录恢复，再使用旧 bit；不要覆盖原始 lab_ex5_i2s。

osd_overlay 的 STATUS_MODE=0 保留固定模式，STATUS_MODE=1 启用动态模式。`status_candidate.patch` 记录四个已有 HDL 文件的差异；`enable_status.py` 是从固定候选执行的可复现接入脚本，遇到已接入或已有备份会拒绝覆盖。先执行原 prepare_candidate.py 创建固定候选，再执行 enable_status.py。

## 板测记录待填写

1. 下载上述命名 bit，HDMI_B 连接和 TF 卡沿用已成功的配置。
2. 冷启动后核对第一张图与 IMG:1、AUTO:OFF。
3. 用明显标有 1～4 的图片，K2 逐次切换，核对图片与编号一致，加载期间不提前变号。
4. K4 开启轮播，核对 AUTO:ON 和编号循环；关闭后 AUTO:OFF 且停止自动切换。
5. 核对复位、单图、多图、测试音、至少 30 分钟运行；记录异常、bit 哈希和显示照片。

注意：内部逐拍比较已证明受测片段的数据/控制对齐，尚未涵盖完整 TF/SPI/SDRAM/加密 HDMI IP 的端到端仿真或真实板测。
