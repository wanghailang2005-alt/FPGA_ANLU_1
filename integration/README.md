# 集成入口

| 入口 | 用途与状态 |
|---|---|
| [timing_20261028](timing_20261028/README.md) | 最新板测、两批优化、异步分组实验、版本哈希 |
| [sdram_diag_20261028](sdram_diag_20261028/README.md) | 独立自检源码；未上板，默认时序模型未通过 |
| [transition_20261027](transition_20261027/README.md) | 转场原始集成补丁；用户后续确认功能正常 |
| [current_baseline](current_baseline/README.md) | 10月25日OSD历史成功基线 |
| [统一按键规划](../docs/按键与拨码规划.md) | 已实现操作与预留功能 |

按顺序恢复指定基线，先git apply --check再应用，不能强行覆盖队友修改。厂商工程/IP需本地准备。异步分组实验保留功能板测反馈，但屏蔽检查不代表时序闭合。

## 历史工具

[FIXED_OSD_GUIDE.md](FIXED_OSD_GUIDE.md)、STATUS_OSD.md、STALL_DIAGNOSTICS.md及旧补丁/构建脚本保留原路径，供追溯。最新版本以日期、哈希和验证阶段选择。

最新：[最近邻缩放BOARD PASS归档](zoom_20261028/README.md)。当前基线zoom_black2；上表时序实验版为历史基线。
