# 验证证据索引

> 最新板测与时序边界见[10月28日集成记录](../integration/timing_20261028/README.md)。下表为历史证据，早期“未通过板测”状态已获后续用户反馈补充。


保留原名称和目录，确保旧日志、补丁与脚本可追溯。先确认版本，再看对应证据。

| 内容 | 入口 | 定位 |
|---|---|---|
| 历史成功OSD版 | [ACK修复记录](ack_release_20261025_181945/README.md) | 10月25日构建、补丁和哈希 |
| 精确成功版选择 | [current_baseline](../integration/current_baseline/README.md) | 优先入口 |
| 最新转场候选 | [候选证据目录](../integration/transition_20261027/evidence/) | 未通过板测 |
| 滚动卡住排查 | [只读诊断](scroll_stall_readonly_diagnosis.md)、[滚动验证](scroll_overlay_verification.md) | 历史问题 |
| 存储观察 | [storage_probe](storage_probe_20261025_173145/README.md) | 观察不等于修复 |
| 紧凑滚动候选 | [scroll_compact](scroll_compact_20261025_171625/README.md) | 历史候选 |
| SDRAM时序 | [诊断说明](sdram_timing_diagnosis.md) | setup问题分析 |

## 文件分类

- modelsim_*.log：仿真日志，negative命名的负向测试需结合说明阅读。
- verification_*.md：字体、取点、叠加、坐标与真实时序验证。
- status_*：动态OSD构建、资源、时钟和传输证据。
- candidate_*、fixed_default_*、diag_*：早期候选，属于历史材料。
- png、pbm、glyph_*.txt：仿真图像，不是实际板上照片。
- selection/manifest类JSON：特定阶段的选择和哈希；成功版优先看current_baseline。

早期白屏反馈见[10月27日记录](../docs/2026-10-27.md)，后续恢复及板测见[10月28日记录](../docs/2026-10-28.md)。具体温度根因尚未证实。
