# HX4S20 多媒体工程工作区

当前可用工程：`lab_ex5_i2s_osd/src/td_project/HDMI1.4b_Transmitter_v1.0.al`。
用户确认正常bit：`lab_ex5_i2s_osd/OSD_FIX_ACK_RELEASE_20261025_181945.bit`。
**Runs/best_result 的 bit 仍为旧故障版，不作为成功基线。** 当前HDL已与成功构建哈希核对一致。

|目录|用途|
|---|---|
|lab_ex5_i2s_osd|当前工程，保留原路径，含动态IMG/AUTO、滚动字幕、ACK握手修复与诊断|
|lab_ex5_i2s|原音视频参考工程，保留|
|lab_ex4_tf|TF参考工程，保留|
|osd_dev|独立OSD Git仓库、测试与集成补丁|
|docs/project|任务、协作、设计及开源资料说明|
|docs/requirements|原题目Word及压缩包|
|archives/20261025_OSD_ACK_RELEASE_BOARD_PASS|成功版源码/工程快照、bit、SHA256和报告|
|archives/20261025_root_logs|原先散落根目录的TD日志|
|archives|历史归档；部分旧固定版基线已被用户纠正，不作为当前成功版|
|third_party|上游开源参考和许可|

今日记录见 [2026-10-25记录](2026-10-25.md)。
工程及bit路径未搬动；文件整理映射见 `archives/organization_20261025.json`。
成功功能由用户板测反馈确认；30分钟完整回归尚未记录。整机时序仍失败，WNS=-6.699ns。
