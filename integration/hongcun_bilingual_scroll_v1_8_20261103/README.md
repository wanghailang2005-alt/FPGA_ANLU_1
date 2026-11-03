# V1.8 五图宏村主题与完整双语滚动字幕

2026-11-03当前进度归档，标签 `v1.8-five-bilingual-scroll-20261103`。**BOARD PASS（用户反馈），继承约束内实现时序通过**。用户于2026-11-03确认“已经板上测试通过了”，关联本轮交付的命名bit；未提供独立设备端哈希。V1.7归档保留。

五张素材顺序：导览图 → 月沼全景 → 承志堂木雕 → 历史老照片 → 马头墙。五图编号、双缓冲标签和状态通道支持3位索引。完整中文与英文正文随图切换；中文16×16、英文8×16（大写显示），两行在608像素窗口滚动，共用速度、方向、初始60帧停留，各自按文字长度回绕。短中文同样滚动。保留480×360主图、右栏、音频频谱、缩放、转场、亮度和对比度。

- [本轮板测记录](docs/HONGCUN_BOARD_PASS_20261103.md)
- [完整字幕与操作](docs/HONGCUN_BILINGUAL_SCROLL.md)
- [五组中英正文](docs/HONGCUN_CAPTIONS_5.txt) / [可维护数据源](docs/HONGCUN_CAPTIONS_5.json)
- [验证摘要](caption_scroll_evidence/release_summary.json) / [TD工程核对](caption_scroll_evidence/td_project_verified.json)
- [版本和下载文件哈希](versions.json) / [归档文件清单](archive_manifest.json)

## 验证结果

字幕独立期望值逐字符核对，五图四语言、三速度、双向、首尾回绕、复位及5→1切换通过：48次渲染、1966080个像素；OSD RGB/DE/HS/VS/X/Y保持三拍对齐。实际导览BMP、I2S→FFT频谱、AXIS集成测试通过5帧、1536000像素。中文BRAM初始化2048行、32768位与综合网表核对一致。

最终setup **+0.119ns**、hold **+0.004ns**，TNS均为0，STA覆盖率95.38%。LUT **15394/19600**，寄存器 **9676/19600**，BRAM9K **55/64**，DSP **29/29**。原SDRAM时钟例外及接口约束边界保留，不声称完整电气接口时序验证。当前bit为 `HONGCUN_5_BILINGUAL_SCROLL_20261103.bit`，SHA256 `728f960e4054e46cea244d7ba5907edbc7d7c0ff35f3ec7ecef21fbbf2aa789d`。

## 使用边界

- TF扫描按物理扇区顺序，文件名前缀不能保证硬件顺序；真实卡顺序待板测确认。
- 上电自动轮播默认关闭。原自动轮播空闲停留约1秒，会打断长字幕；完整阅读使用K2手动翻图。
- SW=1100/K3选择语言；0010/K3选1、2、4像素每帧；0011/K3切方向。
- 本次归档记录用户板测通过反馈，不修改RTL、不重编bit。

## 归档与复现

沿用本仓库范围：GitHub保存自研RTL、约束、字幕、测试和报告摘要；完整TD工程、厂商依赖、数据库、bit、实际图片及预览保存在本地 `archives/20261103_HONGCUN_5_BILINGUAL_SCROLL`。**公开包不能独立生成整机bit**。用合法持有的原厂工程，按src相对路径恢复自研文件并核对source_manifest；原`.al`已引用新源码。本地完整快照包含可直接打开的TD工程。

在caption_scroll_evidence目录用ModelSim运行 `vsim -c -do captions.do -l captions.log`，可复跑独立字幕测试。five_image_evidence中的five.do、metadata.do分别验证扫描和帧标签。集成scene.do需本地完整快照的guide_pixels.hex，它包含照片像素，不随公开包上传。重生成字幕用 `python tools/gen_captions.py`；修改正文后需更新golden.svh并重新验证。

ASCII字库MIT来源见仓库根目录THIRD_PARTY_NOTICES.md及LICENSE.FPGA-text-overlay；新增逗号字形为本次自研。字体文件不上传。导览为文化演示布局，地理位置不作导航用途。
