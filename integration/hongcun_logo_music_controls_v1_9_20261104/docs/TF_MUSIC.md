# 两首 TF 音乐替换内部测试音

用户授权：2026-11-03，“开始”；后续要求“原本的测试音频直接替换”。随后明确同意“扩大范围，修正原工程的跨时钟同步与相关时序约束，然后继续完成稳定版”。

## 使用方式

TD 图形界面入口：`src/td_project/HDMI1.4b_Transmitter_v1.0.al`，顶层 `top`。已补齐 `AUDIO_MUSIC/tf_music_player.v` 和 `sd_music_arbiter.v`；GUI 与已验证 batch 工程的 64 项文件引用一致，所有文件存在。GUI 已保存 seed=4、place effort/opt_timing/fix_hold=high、hold_fix_iteration=15。

TD GUI 参数检查器不接受 route effort=high，因此图形界面保留合法的 normal；完整复现之前已验证的批处理参数及独立布线后 hold 修复，请使用工程根目录 `run_music.ps1`。本次仅同步工程元数据，未重编译或更改已交付 bit。`music_evidence/gui_sync_validation.json` 记录工程同步及源码一致性验证，原 bit 对应的历史工程哈希仍保留在原 summary 中。

- 上电后 TF 初始化完成即播放《松风抚琴（古琴）》前 30 秒，单曲循环。
- SW4..SW1=`1001`：显示原频谱布局；K3 在古琴、竹笛之间循环切换，从新歌开头播放。
- 其他拨码档音乐继续，K3 沿用各档原设置功能；K1/K2 沿用原图片控制逻辑。
- 不设暂停键。原测试音阶发生器不再连接顶层。
- HDMI 输出 48 kHz，PCM16 扩展到 PCM24，左右声道相同。频谱观察同一组实际音频采样。

## 下载与 TF 素材

最终下载文件：`HONGCUN_2_MUSIC_K3_20261103.bit`，638,936 字节，SHA256 见工程根目录同名 `.bit.sha256`。当前状态 **SIM PASS / IMPLEMENTED & TIMING PASS（继承约束内） / BOARD UNVERIFIED**。

最终布局布线与独立保持时间修复后：LUT 15,464/19,600，寄存器 9,886/19,600，BRAM9K 59/64，DSP 29/29，PLL 3/4；setup WNS +0.105 ns、setup TNS 0，hold WNS +0.021 ns、hold TNS 0，STA 覆盖率 95.24%。布局 seed=4。来源：`music_evidence/routed_timing.rpt`、`routed_area.rpt`、`post_route_hold.log`；源码、bit 和 TF 镜像指纹见 `summary.json`。不是板测通过结论。

配套 TF 镜像：`music_media/HONGCUN_5_IMAGES_2_MUSIC_TF.img`，72,868,864 字节。
这是**原始扇区镜像，不是普通文件集合或 FAT 文件系统**。把 WAV/PCM 文件直接复制进 TF 卡不能使本版播放音乐。

使用磁盘镜像写入工具（例如 Win32 Disk Imager）选择该 `.img`，确认目标是用于实验的 TF 卡后写入。镜像写入会覆盖卡上原有数据，先备份。写入后不要接受 Windows 的格式化提示。
本任务只生成镜像，没有操作任何实际磁盘或下载板卡。

镜像前部按当前双语字幕次序包含五张图片：宏村文化导览、月沼、木雕、历史黑白、马头墙；每张从完整扇区起始，单文件连续存放。导览图采用 480×360 版本。

| 内容 | 起始 LBA（512 字节/扇区） | 扇区数 |
|---|---:|---:|
| 古琴 PCM16 小端 | 131072 | 5625 |
| 竹笛 PCM16 小端 | 136697 | 5625 |

音频从 64 MiB 处开始，位于原图片扫描范围 0..131071 之外。每首 1,440,000 个采样、2,880,000 字节。完整布局、素材来源和 SHA256 见 `music_media/manifest.json`。

原 WAV 实际分别为 36.5 秒和 31 秒，40 kHz 双声道 PCM16；两者 RIFF data 长度都标为 `0xffffffff`。转换按实际数据长度，取前 30 秒、左右声道平均、线性插值升采样到 48 kHz，首尾各 5 ms 淡入淡出以减轻循环接缝。处理后试听文件为 `music_media/*_30s.wav`。

## 实现与时钟

CONFIRMED：EG4S20BG256 / TD 6.2.168116；SD 域 100 MHz；音频主时钟名义 12.288 MHz；视频域 25 MHz；SD SPI 分频 14，约 3.125 MHz。PLL 和引脚保持原配置。SDC 音频异步组原查询写作 `[get_clocks {video_clk} hdmi_5x_clk sd_card_clk ext_mem_clk]`，未正确包含后面三个时钟；改为完整时钟名列表，只修复已有音频分组。其余时序例外保持原样。

- `user_control.v`：在现有稳定拨码及 K3 消抖条件下，1001 每按一次翻转歌曲编号；上电歌曲 0。
- `top_tf_hdmi_audio.v`：用既有一致快照 CDC 传递歌曲控制，接入 TF I2S，替换测试音实例。
- `SD/sd_card_bmp.v`：保留 BMP 客户端，在底层单扇区接口前插入仲裁器。
- `AUDIO_MUSIC/sd_music_arbiter.v`：一次扇区归属保持至 END，响应只发给对应客户端；音频需要补充时优先；END 后插入释放周期，避免旧地址重复发起。
- `AUDIO_MUSIC/tf_music_player.v`：2048×16 双时钟 RAM 环形缓冲，Gray 指针双拍同步，TD `keep` 保留同步寄存器；缓冲占用不超过 1536 样本时预读，水位判决寄存一拍，首次积累 1024 样本再播放。额外一个扇区的空间覆盖判决延迟。切歌等待已发起扇区结束，使用停止/确认握手复位队列，再读取新歌。缓冲欠载时输出零并重新预充，恢复后续播。

数据延迟：TF 扇区经过串行读取和异步队列（可变预充延迟），RAM 同步读 1 个音频时钟；每 256 个 MCLK 消费一个单声道样本。左右各 64 个 BCLK，保持原有串行传输格式，再经原 I2S_receiver 的视频域同步接收。新歌启动通常需数个扇区时间，实际以 TF 响应为准。视频像素和其控制信号的流水级数没有改动。

批准的跨域修正：`osd_status_cdc.v` 保留 held_data、request/ACK 和两级同步边界；原图像请求、转场 generation toggle、缓存握手同步链也添加 TD `keep`。`video_timing_data.v` 补齐读帧 ACK 的两级视频域同步，ACK 控制延迟增加 2 个像素时钟，RGB/DE/HS/VS 流水级数不变。邮箱 payload 保持至 ACK 返回，接收在 request 两级同步后采样；SDC 对每个邮箱的 request→首级、ACK→首级和 held_data→dst_data 分别施加 8 ns `set_max_delay -datapath_only`。按 TD SWUG200 §3.11，该约束忽略异步相位/偏斜并自动取消相应 hold 分析，但仍限制数据路径延迟。另对读帧请求/ACK、转场 toggle 的首级同步寄存器施加同样上限。未把全体视频、存储、系统时钟整体切成异步组。

构建参数修正：TD 有效键为 `place fix_hold high`，旧脚本的 `place hold_fix high` 不生效。但 EG4 日志仍提示不支持预布线保持时间修复，且超过 90% slice 时跳过自动布线后修复；`tools/fix_music_hold.tcl` 用独立布线后命令修复剩余普通 hold 路径。所有最终结论以实际报告为准。

音频持续需求 96,000 字节/秒；SPI 原始上限约 390,625 字节/秒，协议与卡响应占用额外带宽。2048 样本队列约 42.7 ms，预充阈值约 21.3 ms。仿真覆盖连续图片竞争读取；不同 TF 卡的长延迟和真实 HDMI 播放仍需板测。

## 验证与回退

| 要求 | 证据 | 状态 |
|---|---|---|
| 两首各 30s / 镜像布局 | manifest.json、prepare_music.py | 静态检查通过 |
| 单样本次序、左右一致、循环、扇区中切歌、快速切歌 | music_sim/music.log，缩短曲长加速覆盖循环 | SIM PASS |
| 两首真实音频采样通过完整 TF 客户端→I2S→原接收器 | music_sim/real_music.log，使用两首各前 2048 样本，缩短曲长 | SIM PASS |
| K3 消抖、长按一次、两首循环、其他设置模式兼容 | music_sim/keys.log | SIM PASS |
| 跨域邮箱数据保持、顺序及完整性；20 帧请求/ACK 和每帧读取计数 | music_sim/cdc.log；215 次邮箱传输 | SIM PASS |
| 图片缓存最大 1024×1024 上传、10 行读取、复位重载、8 字突发合并及列边界 | spectrum_sim/music_cache_regression.log | SIM PASS |
| 中文字体综合初始化 2048 行 / 32768 位 | music_evidence/font_rom_init.json | SYNTH PASS |
| 综合资源与最终布局布线、建立和保持时序 | music_evidence/summary.json 和 routed_* 报告 | IMPLEMENTED/TIMING PASS（继承约束内） |
| 实际 TF、HDMI 声音和频谱、K1/K2 图片功能 | 需用户下载配套 bit 和 TF 镜像验证 | UNVERIFIED |

所有新文件均在本工程内。音乐改动前源码存于 `music_evidence/before`，跨域修正前源码另存于 `music_evidence/before_cdc`，旧命名 bit 保留。回退可使用原 `HONGCUN_5_BILINGUAL_SCROLL_20261103.bit` 与原卡素材；恢复源码时先恢复 before_cdc，再恢复 before 中原 HDL、SDC、`.al`，重新生成 batch `.prj` 并移除新增音乐源注册。

复现入口：`./run_music.ps1`，可用 `-Step prepare|simulate|build|collect` 分阶段。原 WAV 已保存在 `music_media/original`。素材准备还会读取相邻 `media` 下的五张 BMP。ModelSim 执行 `music.do`、`real_music.do`、`keys.do`、`cdc.do`；TD 在既有 `syn_1`、`phy_1` 中运行原构建脚本，最后执行独立保持时间修复。已集成工程无需再运行一次性集成辅助脚本。

原 SDC 的 SDRAM 相移时钟例外与未设置板级 I/O delay 的边界仍在；即使最终约束内时序通过，也不能替代实际板卡验证。
