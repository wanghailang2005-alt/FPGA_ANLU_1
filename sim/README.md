# 仿真入口

在本目录执行vsim -c -do run_名称.do。脚本检查最终成功标志，不能仅以仿真器退出判断通过。work、modelsim.ini和波形属于本地生成物。

## 仓库内OSD模块测试

| 入口 | 验证内容 |
|---|---|
| run_font_rom.do | 字库编码、气泡与复位 |
| run_glyph_pixel.do | 字形取点及延迟 |
| run_overlay.do | 文字、背景和同步对齐 |
| run_video_position.do | 坐标与帧定位 |
| run_scroll_overlay.do | 滚动字幕像素与位置 |
| run_status_overlay.do | IMG/AUTO文字 |

## 依赖本地完整工程的测试

这些入口引用同级lab_ex5_i2s_osd或原参考工程，克隆仓库不含这些依赖。

| 入口 | 验证内容 |
|---|---|
| run_candidate_axis.do、run_candidate_video.do | 候选接入及AXIS边界 |
| run_real_video_timing.do | 真实视频时序链路 |
| run_status_source.do、run_status_transport.do、run_status_video.do | 源状态、标签、跨域与串联 |
| run_storage_probe.do、run_stall_diagnostics.do | 存储及卡住诊断 |
| run_ack_release.do | 写请求/ACK释放修复 |

## 最新集成候选

[转场测试入口](../integration/transition_20261027/sim/run.do)包括转场/OSD像素、控制握手和状态传输三组，依赖同级lab_ex5_i2s_osd_transition。结果与边界见[集成说明](../integration/transition_20261027/README.md)。

仿真不代表真实TF、SDRAM、HDMI和音频整机通过。
