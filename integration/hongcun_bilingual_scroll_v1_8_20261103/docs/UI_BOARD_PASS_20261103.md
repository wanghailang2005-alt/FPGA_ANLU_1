# UI布局板测归档（2026-11-03）

用户原话：“板上测试通过，github归档”。本轮 UI 版本记为 **BOARD PASS（用户反馈）**。

关联下载文件：`UI_LAYOUT_480x360_20261103.bit`。SHA-256：`2ea197d6293374900cd112d303f762a1ab8aa8876dd8b0be208f15e33701bbb3`。该文件是本对话上一轮交付版本；用户未另提供设备端哈希，不声称独立测得下载身份。

约束内实现setup WNS +0.107 ns，hold WNS +0.003 ns，STA覆盖率95.22%。原SDRAM时钟例外和接口约束边界不变，功能板测通过不改变该边界。

本次只记录板测并归档，不修改RTL、工程配置、管脚或SDC，也不重新生成bit。源文件均已与此前验证清单逐项核验。

- 布局、操作及仿真：[UI_LAYOUT.md](UI_LAYOUT.md)
- 本地完整快照：`archives/20261103_UI_LAYOUT_BOARD_PASS/project`
- GitHub自研归档：`integration/ui_layout_v1_7_20261103`
- 原V1.5归档及tag保留。
