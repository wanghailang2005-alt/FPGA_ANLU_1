# 集成版本索引

[返回首页](../README.md) · [使用与复现](../docs/GETTING_STARTED.md)

## 当前交付

| 版本 | 日期 | 内容 | 验证状态 |
|---|---|---|---|
| [V1.9](hongcun_logo_music_controls_v1_9_20261104/README.md) | 2026-11-04 | 白底 Logo、两首 TF 音乐、暂停／切歌／十档音量，保留图片与字幕功能 | 用户反馈 BOARD PASS；最新本地 setup -4.533 ns、hold -0.020 ns，TIMING FAIL |

V1.9 的操作与板测状态以其 README 和 board_feedback.json 为准。包内专题文档与日志保留各自开发阶段结论。

## 历史功能版本

| 版本 | 日期 | 主要内容 | 状态与用途 |
|---|---|---|---|
| [V1.8](hongcun_bilingual_scroll_v1_8_20261103/README.md) | 2026-11-03 | 五张宏村图片、完整双语滚动字幕 | 用户反馈 BOARD PASS；继承约束内 setup +0.119 ns、hold +0.004 ns |
| [V1.7](ui_layout_v1_7_20261103/README.md) | 2026-11-03 | 四区域 UI、480×360 主图与常驻频谱 | 用户反馈 BOARD PASS；约束内 setup +0.107 ns、hold +0.003 ns |
| [V1.5](per_image_captions_v1_5_20261103/README.md) | 2026-11-03 | 逐图双语字幕、八种转场、缩放及亮度／对比度 | 用户反馈功能全部板测通过；归档 setup -1.458 ns |
| [音频可视化](audio_visualizer_20261029/README.md) | 2026-10-29 | 512 点 FFT、32 柱频谱、峰值、波形和电平 | 用户反馈 BOARD PASS；独立阶段归档 |
| [连续缩放与缓存诊断](zoom_animation_20261029/README.md) | 2026-10-29 | 缩放动画、缓存验证和诊断 | 用户反馈所测缩放正常；奇数宽图片历史问题见包内记录 |
| [最近邻缩放](zoom_20261028/README.md) | 2026-10-28 | 多尺寸 BMP、三模式适配与黑边修复 | 用户反馈全部板测通过；历史回退 |

## 早期基线与诊断

| 归档 | 内容与边界 |
|---|---|
| [时序优化与异步实验](timing_20261028/README.md) | 分阶段补丁、版本哈希、板测及 SDRAM 时序边界 |
| [SDRAM 独立自检](sdram_diag_20261028/README.md) | 诊断源码与模型验证；未上板，参考模型未通过 |
| [转场集成](transition_20261027/README.md) | 早期转场控制、集成与本地候选记录 |
| [固定 OSD 基线](current_baseline/README.md) | 早期 OSD 板测基线及接入说明 |
| [固定 OSD 指南](FIXED_OSD_GUIDE.md) | 固定 OSD 使用说明 |
| [OSD 状态记录](STATUS_OSD.md) / [停顿诊断](STALL_DIAGNOSTICS.md) | 早期问题定位与当时结论 |

上述时序通过均受各归档所列时钟例外和 SDRAM 接口约束边界限制。历史目录保留原路径，便于复核补丁、脚本和清单。
