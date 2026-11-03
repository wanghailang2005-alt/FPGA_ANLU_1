# 右上角图形 Logo（局部白底）

最终生产RTL为逻辑查表版。像素与视频链路仿真通过，但本轮全工程时序未通过，未发布新的上板bit；以 `logo_evidence/summary.json`为准。下文BRAM验证、种子重试属于历史候选记录，不代表最终版时序通过。最终独立综合/实现位于 `logo_evidence/logic`，无需修改原GUI工程入口即可使用当前RTL；后续重建仍需重新检查时序。

2026-11-03，用户确认“开始”后实施，随后要求“叠加一个白底吧，那一小部分”。

- 工程入口：`../src/td_project/HDMI1.4b_Transmitter_v1.0.al`，继续保留当前 TF 音乐集成。
- 仅修改生产 RTL `OSD/osd_overlay.v`，原文件备份在 `../logo_evidence/before/osd_overlay.v`。
- 品牌文字原第 0、1 行替换为红蓝图形 Logo。Logo 位于 x=528..591、y=3..43，为64×41像素；局部白底位于 x=524..595、y=0..46，为72×47像素。其余右栏、运行时间和分区保持原位置。
- 图形沿用用户最初提供的红蓝标志，白色素材背景转换为透明索引，最终叠加到局部白底上。图案ROM初始化直接嵌入RTL，综合及下载不依赖外部图片或hex文件。
- Logo 遵循原固定OSD开关：`SW=0001`、K3切换文字状态，固定OSD关闭时Logo及其白底同时关闭。参数沿用帧边界更新。
- 最终版使用逻辑查表、一拍图案采样、一拍索引和有效信号、最终一拍RGB合成，共三拍；DE、HS、VS、XY延迟不变。没有增加时钟、跨域或DSP运算，查表结果寄存器仅在Logo有效区域更新。早期BRAM候选增加了1块BRAM，已改为逻辑查表；早期候选报告不能作为最终版本证据。

## 验证与下载

独立像素测试：在 `logo_evidence` 中运行 ModelSim `logo.do`，检查红蓝像素、白底、边界、禁用、消隐、复位以及RGB/DE/HS/VS/XY逐拍对齐。`golden.hex`来自参考图片采样，不读取RTL初始化作为期望。

现有字幕测试 `caption_scroll_evidence/captions.do` 与集成测试 `scene.do` 用于回归。集成测试使用历史测试音源检查频谱至AXIS的视频链路；它不等价于新增的整卡音乐端到端板测。

`../logo_evidence/RTL_PREVIEW_WHITE.png`是RTL仿真输出，不是开发板实拍。

全工程按现有 `run_music.ps1 -Step build` 构建，包含原有显式hold修复流程，不新增时序例外。时序通过后由 `logo_evidence/collect.py`收集 `HONGCUN_LOGO_TF_MUSIC_20261103.bit`、SHA256、资源及报告。最终状态见 `../logo_evidence/summary.json`。继承的SDRAM时序例外和接口约束边界仍然存在。

默认seed 4的白底版在显式hold修复后，setup WNS为-0.082 ns，未作为发布版。重试脚本 `logo_evidence/build_seed5.tcl`沿用现有批处理参数，仅将布局seed设为5，不改工程元数据或SDC。复现时先完成综合，再在 `src/td_project/HDMI1.4b_Transmitter_v1.0_Runs/phy_1` 中用TD命令行运行 `../../../../logo_evidence/build_seed5.tcl`，回到工程根目录运行原有 `tools/fix_music_hold.tcl`。发布前必须再次收集并核对时序，不能只看bit文件是否生成。

| 要求 | 证据 | 状态 |
|---|---|---|
| 原参考图案、白底边界、OSD开关、复位 | logo_evidence/logo_logic.log | SIM PASS |
| RGB/DE/HS/VS/XY仍为三拍对齐 | logo_evidence/logo_logic.log | SIM PASS |
| 早期BRAM候选的4096项初始化 | logo_evidence/logo_rom_init.json | 仅早期候选SYNTH PASS，最终版不使用该ROM |
| 双语字幕48次渲染回归 | logo_evidence/captions.log | SIM PASS |
| 频谱/OSD/AXIS视频链路5帧回归 | logo_evidence/scene.log | SIM PASS |
| 全工程资源、布局布线时序 | logo_evidence/summary.json及routed_*报告 | 以最终收集结果为准 |
| 开发板实际显示与音乐 | 待用户上板检查 | UNVERIFIED |

## 回退

恢复 `logo_evidence/before/osd_overlay.v` 后按当前音乐流程重建，或使用此前音乐版本已保留的命名bit。不能把此前板测结论自动用于本版。板上验收需确认白底Logo、文字开关、换图、字幕及实际音乐播放。
