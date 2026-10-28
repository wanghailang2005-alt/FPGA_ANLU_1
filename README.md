# FPGA_ANLU_1

安路EG4S20 / HX4S20 HDMI多媒体项目：图片切换、自动轮播、IMG/AUTO、WELCOME滚动字幕、淡出淡入和滑动揭幕。

## 当前版本

| 版本 | 功能板测 | 时序边界 |
|---|---|---|
| 10月28日异步分组GUI实验版 | 用户确认完整通过，作为后续功能开发候选基线 | 屏蔽SDRAM时钟对后setup +0.102ns、hold +0.003ns；不是完整时序闭合 |
| 第二批未屏蔽版本 | 用户确认通过，保留回退 | SD域及内存域内部通过，SDRAM接口仍-6.699ns |
| 独立SDRAM自检 | 未上板 | 默认参考时序模型未通过；逻辑验证需看模型边界 |
| 图片缩放 | 尚未实现 | 下一步核对赛题需求 |

## 入口

- [10月28日优化、补丁与板测](integration/timing_20261028/README.md)
- [版本哈希及本地bit路径](integration/timing_20261028/versions.json)
- [统一按键与拨码规划](docs/按键与拨码规划.md)
- [当天记录](docs/2026-10-28.md) · [本地工作区索引](docs/workspace_index_20261028.md)
- [转场原始集成包](integration/transition_20261027/README.md) · [10月25日OSD历史基线](integration/current_baseline/README.md)
- [独立SDRAM自检](integration/sdram_diag_20261028/README.md)

## 仓库内容

rtl与sim保留OSD模块和测试；integration保存分阶段补丁、控制模块、自检源码与证据；docs记录按键、版本和工作区导航；evidence保存历史诊断。旧记录中的白屏/未上板结论为当时状态，后续以对应日期、bit哈希和板测反馈为准。

本仓库上传自研RTL、补丁、测试与摘要。完整厂商工程、加密IP、bit、TD缓存和数据库保留本地；只克隆仓库不能独立生成整机bit。字库来源见[第三方声明](THIRD_PARTY_NOTICES.md)。

历史首页见[10月28日时序更新前快照](docs/history/README_before_timing_20261028.md)。
