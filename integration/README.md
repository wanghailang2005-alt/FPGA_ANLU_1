# 集成入口

先确认版本，再使用对应补丁。这里有成功基线、最新候选和历史诊断三种用途，不能混用。

## 当前入口

| 目的 | 文件/目录 | 状态 |
|---|---|---|
| 恢复历史成功OSD版 | [current_baseline](current_baseline/README.md) | 10月25日用户报告成功，时序未闭合 |
| 查看OSD＋转场集成 | [transition_20261027](transition_20261027/README.md) | 三组仿真通过，白屏待查，未通过板测 |
| 确认按键及实现范围 | [统一按键规划](../docs/按键与拨码规划.md) | 0100/0101已接入候选，其余见表 |

补丁应用到指定基线前先运行git apply --check，不能强制覆盖队友修改。厂商工程和IP需本地准备。

## 历史说明与工具

| 内容 | 入口/文件 | 用途 |
|---|---|---|
| 固定OSD接入 | [FIXED_OSD_GUIDE.md](FIXED_OSD_GUIDE.md) | 早期接线、AXIS修正及资源 |
| 动态IMG/AUTO接入 | [STATUS_OSD.md](STATUS_OSD.md) | 状态标签、读帧对齐的历史说明 |
| 卡住诊断 | [STALL_DIAGNOSTICS.md](STALL_DIAGNOSTICS.md) | 诊断状态与分页解码 |
| 候选准备 | prepare_candidate.py、top_osd_insert.vh | 早期固定OSD准备，不覆盖已有目标 |
| 状态接入 | enable_status.py、top_status_insert.vh | 对应历史开发阶段 |
| 工程检查 | check_status_project.tcl、repair_status_project.tcl、inspect_td_commands.tcl | 先读对应说明 |
| TD构建 | build_td.tcl | 在候选运行目录调用默认流程 |
| 诊断构建 | build_stall_diagnostics.py | 历史工具，勿直接覆盖当前选择 |

candidate_changes.patch、status_candidate.patch、stall_diagnostics.patch是历史分步补丁。成功版使用current_baseline/current_sources.patch；转场版在成功版基础上应用transition_20261027/transition_sources.patch。

本次保留脚本和RTL原路径，避免影响本地同级完整工程、仿真和证据引用。
