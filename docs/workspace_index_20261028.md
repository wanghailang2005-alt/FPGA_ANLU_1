# 本地工作区索引：2026-10-28

工作区根目录为7_lab_ex_2026_nosoft；GitHub仓库为其中osd_dev。TD工程保留原路径。

| 目录 | 用途 |
|---|---|
| hdmi_async_exp_20261028 | 最新完整功能板测实验版；含屏蔽SDRAM检查的约束 |
| hdmi_async_exp_20261028/board_pass_20261028 | GUI版bit备份、截图与哈希，优先回退候选 |
| lab_ex5_i2s_osd_transition | 未屏蔽SDRAM接口的集成工程；两批优化与成功bit保留 |
| lab_ex5_i2s_osd_transition/timing_opt_stage2_20261028 | 第二批用户板测成功bit及报告 |
| lab_ex5_i2s_osd_transition/sdram_diagnosis_20261028/memory_test | 独立SDRAM自检工程，未上板 |
| lab_ex5_i2s_osd | 10月25日OSD/字幕历史成功工程 |
| lab_ex5_i2s、lab_ex4_tf、qiepin_src | 音视频、TF和队友转场参考，原路径保留 |
| osd_dev | Git仓库，上传自研源码/补丁/记录，完整厂商依赖留本地 |
| docs/project、docs/requirements | 研发任务、原题目与参考说明 |
| archives | 历史快照和日志；勿混同当前成功版 |
| tools/history/20261028 | 旧根目录脚本归档，原内容未改，勿直接重跑 |
| third_party | 开源参考与许可 |

最新项目为hdmi_async_exp_20261028/src/td_project/HDMI1.4b_Transmitter_v1.0.al。当前GUI版bit哈希fc087e1684d7de60b6fe3bfeef511e04afcf5d2f549d2c5e4e57f2c3d5cc6bdc；此前批处理命名bit为8284d9ec…，不可视为同一文件。

后续缩放建议另建候选，保留两个成功版本。所有bit仍在本地，GitHub的[版本清单](../integration/timing_20261028/versions.json)只记录路径/哈希。
