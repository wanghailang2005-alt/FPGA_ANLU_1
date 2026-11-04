# HX4S20 / EG4S20 HDMI 多媒体播放器

基于安路 HX4S20 开发板的图片、字幕与音频演示项目。GitHub 保存自研 RTL、分阶段集成源码、测试及验证记录。

**当前交付：V1.9 白底 Logo 与 TF 音乐控制（2026-11-04，用户反馈板测通过）。**

## 从这里开始

| 需要 | 入口 |
|---|---|
| 查看最终版本、操作与交付状态 | [V1.9 交付说明](integration/hongcun_logo_music_controls_v1_9_20261104/README.md) |
| 查按键、TF 素材及复现步骤 | [使用与复现导航](docs/GETTING_STARTED.md) |
| 查各阶段功能、验证与回退版本 | [版本索引](integration/README.md) |
| 查源码、测试和证据放在哪里 | [仓库结构](docs/REPOSITORY_GUIDE.md) |
| 查开发记录和专题文档 | [文档目录](docs/README.md) |

## 已完成功能

- 五张宏村主题图片、图片切换与自动轮播。
- 480×360 主图、右侧信息栏、常驻音频频谱与双语字幕区域。
- 逐图完整中英文滚动字幕，支持语言、速度和方向设置。
- 八种转场、缩放动画、亮度及对比度调节。
- 右上角红蓝 Logo 及局部白底。
- TF 卡两首音乐，支持暂停／继续、切歌和十档音量控制。

SW=`1001` 时，K2 暂停／继续，K3 切换古琴／竹笛，K4 循环调整音量，默认 5 档。其他操作见[使用导航](docs/GETTING_STARTED.md)。

## 交付与验证

V1.9 的 **BOARD PASS 来自用户反馈**；最新本地实现报告仍为 **TIMING FAIL**：setup WNS -4.533 ns、hold WNS -0.020 ns。设备端 bit 哈希未独立核对。详见[板测反馈](integration/hongcun_logo_music_controls_v1_9_20261104/board_feedback.json)和[时序状态](integration/hongcun_logo_music_controls_v1_9_20261104/timing_status.txt)。

历史版本各自的时序通过、未上板或故障记录仅适用于对应版本；按[版本索引](integration/README.md)选择需要的基线。

## 仓库布局

| 目录 | 内容 |
|---|---|
| [integration/](integration/README.md) | V1.9 交付及各阶段集成归档，包含版本对应的源码、测试和证据 |
| [rtl/](rtl/README.md) | 早期独立 OSD 模块；整机当前源码见 V1.9 的 src/ |
| [sim/](sim/README.md) | 独立 OSD 仿真与历史集成测试入口 |
| [docs/](docs/README.md) | 使用导航、版本说明与历史研发记录 |
| [evidence/](evidence/README.md) | 早期诊断与验证记录；后续证据随各集成版本保存 |
| tools/ | 仓库文档相对链接检查工具 |

## 获取与复现

完整厂商 TD 工程、加密 IP、bit、数据库及图片／音乐素材保留本地，**仅克隆本仓库不能独立生成整机 bit**。需合法持有原工程，再按[复现导航](docs/GETTING_STARTED.md)恢复相应版本的源码与依赖。

第三方来源与许可见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) 和 [LICENSE.FPGA-text-overlay](LICENSE.FPGA-text-overlay)。该许可对应所引用的字库来源。
