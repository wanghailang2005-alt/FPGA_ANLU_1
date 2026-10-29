# FPGA_ANLU_1

2026-10-29：**音频可视化已获用户确认板测通过**，入口 SW=`1001`，含 512 点 FFT、32 柱频谱、峰值保持、波形和左右电平。见 [音频可视化源码与验证](integration/audio_visualizer_20261029/README.md)。

2026-10-29：连续缩放和缓存诊断的源码、仿真及板测记录已归档，见 [动画工程记录](integration/zoom_animation_20261029/README.md)。用户反馈缓存校验版所测缩放正常；此前奇数宽噪点仍作为待确认历史问题。

## 历史基线：最近邻缩放板测通过

当前功能开发基线改为zoom_black2。多尺寸BMP三模式适配、黑边修复及用户最终全部测试通过，见[缩放归档](integration/zoom_20261028/README.md)。下文时序实验版等为保留的历史基线。

安路EG4S20 / HX4S20 HDMI多媒体项目：图片切换、自动轮播、IMG/AUTO、WELCOME滚动字幕、淡出淡入和滑动揭幕。

## 当前版本

| 版本 | 功能板测 | 时序边界 |
|---|---|---|
| 10月28日异步分组GUI实验版 | 用户确认完整通过，作为后续功能开发候选基线 | 屏蔽SDRAM时钟对后setup +0.102ns、hold +0.003ns；不是完整时序闭合 |
| 第二批未屏蔽版本 | 用户确认通过，保留回退 | SD域及内存域内部通过，SDRAM接口仍-6.699ns |
| 独立SDRAM自检 | 未上板 | 默认参考时序模型未通过；逻辑验证需看模型边界 |
| 最近邻缩放 | 用户确认全部板测通过 | zoom_black2，详见最新缩放归档 |

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
