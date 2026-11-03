# V1.5 板测及实现记录

## 意图与环境

| 项目 | 事实与状态 |
|---|---|
| 最终效果 | CONFIRMED：逐图中英字幕、八种转场、缩放及亮度/对比度集成；用户确认全部板测通过 |
| 平台 | CONFIRMED：EG4S20BG256，TD 6.2.168116，640×480 输出 |
| 时钟 | CONFIRMED：主时钟 50 MHz，SD 域 100 MHz，视频域 25 MHz，内存域与 HDMI 5x 域 125 MHz |
| 复位 | CONFIRMED：顶层 rst_all = ~rst_n OR ~audio_pll_lock；模块沿用现有复位 |
| 吞吐/延迟 | CONFIRMED：OSD 字形两级、最终合成一级；中文/ASCII 与视频共三拍。未进行本次动态波形验证 |
| 本次范围 | CONFIRMED：文档、版本归档及 GitHub 发布；RTL、工具脚本、工程元数据和约束保持原字节 |
| 验收身份 | UNKNOWN：用户未提供已下载 bit 的哈希及逐项测量日志 |

## 功能与证据

2026-11-03 用户原话：“已经上板测试了，全部测试通过”。

| 要求 | 证据 | 结果 |
|---|---|---|
| 全部集成功能上板运行 | 用户确认；源码与功能表已核对 | BOARD PASS（用户反馈） |
| 逐图字幕数据 | 30/40/21/35 字，共 126 字格、93 字形 | STATIC CHECK |
| 工程源文件存在 | .al 引用的本地源文件路径均存在 | STATIC CHECK |
| 综合、布局布线与 bitgen | 本地 syn_1/phy_1 日志及 bit 文件 | 已生成产物 |
| setup 时序闭合 | routed WNS -1.458 ns / TNS -18.741 ns | FAIL |
| hold 时序 | routed WNS +0.003 ns / TNS 0.000 ns | 报告约束范围内通过 |
| 已测 bit 与归档 bit 同一性 | 未提供下载文件哈希 | UNVERIFIED |
| 新仿真 | ModelSim 启动失败，系统 DLL 重定位错误 | 未完成 |

最新报告生成于 2026-11-03 13:58:51，STA coverage 95.64%。最差路径位于 125 MHz ext_mem_clk：source cache RAM 输出到 first_bad_row_reg[4] 的 CE，数据路径延迟 9.106 ns。视频域 setup +3.858 ns，SD 域 +0.169 ns。约束仍屏蔽 ext_mem_clk 与 ext_mem_clk_sft 之间的分析；板测通过不能替代完整接口时序验证。

资源：LUT 13816/19600（70.49%），寄存器 8709/19600（44.43%），BRAM9K 41/64（64.06%），DSP 28/29（96.55%）。后续新增乘法功能需注意 DSP 余量。

## 尚未修改的维护问题

1. tools/gen_captions.py 的 RTL、SUB 使用原作者机器绝对路径，且 MARK1“字模查表”在当前 RTL 中缺失；直接重新生成不能成功。
2. 英文窗口起点 160，若要按 640 宽画面居中应为 192；保留已测显示布局。
3. 字体点阵由 Windows 宋体生成，生成工具依赖 Pillow 和本地字体；字体与素材不随 GitHub 源码包分发，沿用原权利边界。

若进行脚本修复、RTL 布局修正或缓存时序优化，需作为后续版本另行验证。V1.5 原始源码和 bit 可按哈希回退；本次未修改功能实现。
