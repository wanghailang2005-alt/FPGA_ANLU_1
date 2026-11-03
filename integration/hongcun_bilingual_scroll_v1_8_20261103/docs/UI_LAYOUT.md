> 2026-11-03：用户确认“板上测试通过”，本轮记录见 [板测归档](UI_BOARD_PASS_20261103.md)。

# 四区域 UI 布局

本轮基于 `zoom_animation_per_image_captions`，按用户确认的参考图实施。源码修改经用户“kaishiba”批准。现有 `zoom_animation_ui` 工程未修改。

## 区域（坐标含边界）

| 区域 | 坐标 | 内容 |
|---|---|---|
| 主图片 | x=0..479，y=0..359 | 480×360，原尺寸居中／等比例留边／铺满裁剪 |
| 右栏 | x=480..639，y=0..359 | 品牌、运行时间、未校时、图片、轮播、当前操作、缩放、转场、亮度及对比度 |
| 音频 | x=0..639，y=360..415 | 深色不透明底，AUDIO TEST 标识，32柱PCM频谱 |
| 字幕 | x=0..639，y=416..479 | 黑色不透明底；中文y=432..447，英文y=456..471 |

图片完整缩放到主窗口；不是用OSD遮掉原图右侧和下部。原尺寸模式仍保持原像素尺寸，大图会在480×360内居中裁剪。图片亮度、对比度和转场在UI合成前处理，因此不影响UI配色。

右栏使用16×16字模，分三组，仅两条低亮度分隔线。SW=0111/1000时缩放行高亮，0100时转场行高亮，1010/1011时亮度/对比度行高亮。其余设置在“当前操作”中标明类别。

## 操作变化

- K1复位、K2切图、K3调整、K4轮播及既有拨码参数循环保持。
- 音频频谱改为常驻底部，SW=1001不再改变布局；原真实PCM分析链路不变，音源仍为原内部测试音阶，并未增加TF音频解码。
- SW=1100继续选择关闭／中文／英文／双语。
- 中文字幕窗口宽608像素：不超过窗口的字幕居中静止；超长字幕先显示开头并停留60帧，再按SW=0010/0011选择的速度、方向滚动。
- 原欢迎滚动条与底部亮度提示取消，参数在右栏显示。SW=0001仍循环原四个文字状态，其中固定文字位控制右栏文字；原滚动条位不再产生独立欢迎条。逐图字幕仍由1100独立控制。
- 关闭右栏文字或字幕时，区域背景和主图窗口大小不改变。
- 时钟没有RTC输入：上电从00:00:00计时，24小时回绕，K1清零；下一行显示“未校时”。不显示伪造的真实日期，断电不保存。
- Logo为本地字模的ANLOGIC／安路科技文字标识，未使用正式图形Logo素材。

## 工程范围与时钟

- 保持640×480 HDMI时序、每帧307200个像素、帧缓冲地址与640像素行跨度、SDRAM写翻转方式、PLL、管脚与SDC约束。
- `scale_on_load.v`、`zoom_cached_scaler.v`增加独立VIEW参数，生产完整640×480缓存，在主图窗口外写黑；默认VIEW等于OUT，保留通用模块原行为。
- `zoom_animation.v`按VIEW计算目标几何，仍写满完整帧；`sd_card_bmp.v`将VIEW设为480×360。
- `image_transition.v`保持640×480扫描计数，按480×360设置转场中心与边界。风车角度上限保留320，避免完整展开时对角线缺像素。
- `osd_overlay.v`内含`ui_sidebar`模块及常量字模初始化，无需外部字库文件或更改工程源清单。
- `top_tf_hdmi_audio.v`将拨码、显示参数、缩放和转场模式打成29位快照，经现有握手CDC跨50MHz到25MHz，在垂直消隐更新。
- 图片装载域100MHz；存储域125MHz；UI和音频分析显示域25MHz；无新增时钟或PLL。

## 延迟账本

以原图输出`vout_data/de/hs/vs`为共同起点，延迟与修改前一致：

| 节点 | RGB | DE | HS/VS | 坐标 |
|---|---:|---:|---:|---:|
| 位置恢复 | 1 | 1 | 1 | 1 |
| UI/OSD | 4 | 4 | 4 | 4 |
| 频谱合成 | 7 | 7 | 7 | 7 |
| AXIS输出 | 8 | 8 | 根据对应边界生成SOF/EOL | 不外传 |

sidebar和中英文字符均为两级字形流水＋一级合成；频谱的分析RAM读延迟与视频延迟保持匹配。集成仿真按像素验证控制和RGB对齐。

## 可复跑验证

在`ui_evidence`目录运行ModelSim：

```powershell
vsim -c -do compile.do -l compile.log
vsim -c -do cached.do -l cached.log
vsim -c -do load.do -l load.log
vsim -c -do transition.do -l transition.log
vsim -c -do captions.do -l captions.log
vsim -c -do clock.do -l clock.log
vsim -c -do scene.do -l scene.log
```

| 需求 | 证据 | 状态 |
|---|---|---|
| 双线性视口及留边/裁剪 | cached.log，4帧1228800像素，独立整数参考，含奇数宽和竖图 | SIM PASS |
| BMP装载、两算法、三缩放模式 | load.log，12帧3686400像素，另拒绝4种非法BMP | SIM PASS |
| 八转场握手与完整可见端点 | transition.log，每种检查480×360像素 | SIM PASS |
| 四图四语言、停留、方向、短句静止 | captions.log，像素颜色/位置/图像签名检查 | SIM PASS |
| 运行计时、进位、帧边界更新 | clock.log | SIM PASS |
| 实际I2S→FFT→UI→AXIS | scene.log，5帧1536000像素、5 SOF/2400 EOL，opaque字幕检查 | SIM PASS |
| 全工程综合/布局布线/bit | synthesis_release.log、implementation_release.log、release_summary.json | 以最终报告为准 |
| 实际开发板显示/声音/切图 | 2026-11-03用户反馈板测通过 | BOARD PASS（用户反馈，2026-11-03） |

`ui_preview.png`来自真实RTL输出，主图是测试台生成的村落图案，不是板上照片。原始源文件备份位于`ui_evidence/before`，历史根目录bit不代表本次UI版本。

原SDRAM相关时钟例外以及缺失接口时延约束继续保留；约束内setup/hold结果不等于完整接口电气时序验证。上板前请使用本次单独命名的候选bit，并检查四张图片、所有缩放/转场、字幕语言与滚动、声音和运行时间。

## 最终构建结果

- 下载文件：`UI_LAYOUT_480x360_20261103.bit`。
- 状态：**IMPLEMENTED/TIMING PASS；BOARD UNVERIFIED**。
- 最终实现setup WNS **+0.107ns**，hold WNS **+0.003ns**，setup/hold TNS均为0；STA覆盖率95.22%。主时钟50MHz，装载100MHz，存储125MHz，视频25MHz。
- 资源：LUT 14836/19600，寄存器9600/19600，BRAM 55/64，DSP 29/29。DSP已用满，后续增加算术功能需要评估资源复用。
- 字库初始化另经只读综合网表导出核实：中文字幕和右栏各4片BRAM、2048行，合计65536初始化位逐位匹配，见`font_init_verified.json`。综合器对只读数组的“无driver”提示不代表初始化丢失，此项已有网表证据。
- 8个HDL文件相对V1.6基线改变；其余源文件及管脚/SDC约束哈希保持一致。完整哈希、测试结果见`release_summary.json`和`source_manifest.json`。
- 源码及下载文件已完成，用户已反馈板上测试通过；真实SDRAM接口电气时序和逐项测量仍不在本次反馈范围。
