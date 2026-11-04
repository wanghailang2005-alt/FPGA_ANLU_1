# 使用与复现导航

[返回首页](../README.md) · [版本索引](../integration/README.md)

## 1. 选择版本

当前交付是 [V1.9](../integration/hongcun_logo_music_controls_v1_9_20261104/README.md)。它包含 Logo、音乐控制和前序图片／字幕功能。需要历史回退或比较时，从版本索引进入相应归档，使用该版本自己的源码和测试。

## 2. 操作与素材

- V1.9 音乐操作：SW=`1001`，K2 暂停／继续、K3 古琴／竹笛切换、K4 循环调整 1～10 档音量，默认 5 档。
- 图片、字幕等基础操作查 [V1.8 字幕与操作说明](../integration/hongcun_bilingual_scroll_v1_8_20261103/docs/HONGCUN_BILINGUAL_SCROLL.md)及[基础功能使用表](../integration/hongcun_bilingual_scroll_v1_8_20261103/docs/USAGE.md)；音乐模式按上面的 V1.9 说明操作。
- [TF 音乐与镜像布局](../integration/hongcun_logo_music_controls_v1_9_20261104/docs/TF_MUSIC.md)记录素材准备、原始扇区和音频格式。其“不设暂停键”、旧 bit 和 BOARD UNVERIFIED 属于早期音乐候选状态；当前控制与板测以 V1.9 README 为准。
- [Logo 专题](../integration/hongcun_logo_music_controls_v1_9_20261104/docs/LOGO_OVERLAY.md)记录图形实现过程；最终白底状态见 V1.9 README。

音乐采用原始扇区 TF 镜像，直接复制 WAV/PCM 文件不能代替镜像写入。镜像、图片和音乐素材保留本地；写卡会覆盖卡上数据，应先备份并核对目标卡。

## 3. 准备构建依赖

器件为 EG4S20 / HX4S20，项目归档使用 Anlogic Tang Dynasty（TD）；具体配置以对应版本说明为准。需自行准备合法持有的原厂工程及其 IP、TD 工具、配套素材；仿真使用归档指定的 ModelSim 环境及依赖。

当前本地完整工程入口为工作区的 `zoom_animation_per_image_captions/src/td_project/HDMI1.4b_Transmitter_v1.0.al`，该路径不是本仓库克隆后的文件。

V1.9 按其 [src/](../integration/hongcun_logo_music_controls_v1_9_20261104/src/) 相对路径恢复自研文件，并核对 [project_sources.json](../integration/hongcun_logo_music_controls_v1_9_20261104/project_sources.json)；两个 AUDIO_MUSIC 模块都必须加入综合清单。构建与测试脚本的工作目录及本地依赖按归档说明准备。

## 4. 核对验证记录

- [V1.9 板测反馈与哈希](../integration/hongcun_logo_music_controls_v1_9_20261104/board_feedback.json)
- [V1.9 最新本地时序状态](../integration/hongcun_logo_music_controls_v1_9_20261104/timing_status.txt)
- [V1.9 归档文件清单](../integration/hongcun_logo_music_controls_v1_9_20261104/archive_manifest.json)

V1.9 已获用户板测通过反馈，最新本地时序仍 FAIL；未独立核对设备端 bit 哈希。重新编译的产物需要单独验证，历史仿真日志与板测反馈不会自动成为新产物的验收结论。
