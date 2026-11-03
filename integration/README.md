# 集成入口

最新开发归档：[V1.8 五图宏村主题与完整双语滚动字幕](hongcun_bilingual_scroll_v1_8_20261103/README.md)。导览图→月沼→木雕→旧影→马头墙，setup +0.119ns、hold +0.004ns；用户于2026-11-03反馈板测通过。

上一版板测基线：[V1.7 四区域UI](ui_layout_v1_7_20261103/README.md)，用户于2026-11-03反馈板上测试通过。主图、右栏、常驻音频频谱与独立字幕分区，约束内setup/hold通过。

历史V1.5图片播放集成基线：[V1.5 逐图双语字幕](per_image_captions_v1_5_20261103/README.md)，2026-11-03 用户确认全部功能板测通过；[功能表](per_image_captions_v1_5_20261103/docs/USAGE.md)。setup WNS -1.458 ns，尚未时序闭合。

| 入口 | 用途与状态 |
|---|---|
| [audio_visualizer_20261029](audio_visualizer_20261029/README.md) | 音频可视化，1001 入口；用户确认功能 BOARD PASS |
| [timing_20261028](timing_20261028/README.md) | 最新板测、两批优化、异步分组实验、版本哈希 |
| [sdram_diag_20261028](sdram_diag_20261028/README.md) | 独立自检源码；未上板，默认时序模型未通过 |
| [transition_20261027](transition_20261027/README.md) | 转场原始集成补丁；用户后续确认功能正常 |
| [current_baseline](current_baseline/README.md) | 10月25日OSD历史成功基线 |
| [按键与拨码规划](../docs/按键与拨码规划.md) | V1.5 当前操作、默认值与引脚 |

按顺序恢复指定基线，先git apply --check再应用，不能强行覆盖队友修改。厂商工程/IP需本地准备。异步分组实验保留功能板测反馈，但屏蔽检查不代表时序闭合。

## 历史工具

[FIXED_OSD_GUIDE.md](FIXED_OSD_GUIDE.md)、STATUS_OSD.md、STALL_DIAGNOSTICS.md及旧补丁/构建脚本保留原路径，供追溯。最新版本以日期、哈希和验证阶段选择。

历史：[最近邻缩放BOARD PASS归档](zoom_20261028/README.md)。当时基线zoom_black2；上表时序实验版为历史基线。
