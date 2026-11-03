# V1.5 逐图双语字幕集成版

版本日期：2026-11-03。用户已确认：“已经上板测试了，全部测试通过”。本版作为当前功能板测基线。

- [功能使用表](docs/USAGE.md)
- [板测与实现记录](docs/BOARD_TEST_20261103.md)
- [版本记录](docs/CHANGELOG.md)
- [逐图字幕设计说明](docs/CAPTIONS_PER_IMAGE.md)

包含四图对应的中英字幕、普通状态 OSD 与滚动条、八种转场、最近邻/双线性三档缩放及缩放动画、亮度/对比度调整、手动切图和自动轮播。本次发布整理不改变 RTL、工程配置、约束或生成脚本。

功能板测状态为 **BOARD PASS（用户确认）**。目录中最新 routed 报告的 setup WNS 为 **-1.458 ns**、TNS 为 **-18.741 ns**，hold WNS 为 **+0.003 ns**；这不是时序闭合版本。视频域 setup 裕量 +3.858 ns。详细边界见板测记录。

逐图字幕默认对应宏村四图；卡内图片应与字幕顺序一致。TF 扫描前 131072 扇区内前四张 BMP，读取依赖连续扇区。

原本地工程中的 bit 位于 TD 的 best_result 和 phy_1 内，哈希见 [versions.json](versions.json)。用户没有按哈希指认下载文件，不能把目录 bit 的哈希等同于已测文件身份。

本地完整快照保存在工作区 archives/20261103_CAPTIONS_V1_5_BOARD_PASS。GitHub 归档提供自研集成源码、使用说明和实现摘要；沿用仓库惯例，厂商加密 IP、生成 IP、TD 数据库及 bit 保留本地。

历史缓存诊断说明保留在 docs 中，仅描述当时版本。另一个音频频谱分支单独归档；本版 SW=1001 无操作，未声称集成 FFT 音频可视化。

## 恢复与复现

本包提供自研集成文件快照，src 路径对应原工程。请在本地完整 V1.5 厂商工程副本中按 source_manifest.json 核验依赖，再合入文件；本包不能单独综合。原始 .al、PLL、FIFO、加密 SDRAM/HDMI IP 与 bit 仅在本地完整归档中保存。本包不附新的构建脚本，也不改动原工程设置。字库 MIT 来源见仓库根目录 THIRD_PARTY_NOTICES.md 与 LICENSE.FPGA-text-overlay。
