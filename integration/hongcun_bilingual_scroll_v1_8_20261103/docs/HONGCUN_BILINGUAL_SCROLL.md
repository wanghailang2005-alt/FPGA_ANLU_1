# 宏村五图完整中英文滚动字幕

2026-11-03，用户确认“开始”后实施。下载文件：`../HONGCUN_5_BILINGUAL_SCROLL_20261103.bit`。旧命名 bit 和源码备份保留。本次状态为 **BOARD PASS（用户反馈），IMPLEMENTED/TIMING PASS（继承约束内）**。

## 字幕与顺序

| 屏幕编号 | 图片 | 中文字幕长度 | 英文长度 |
|---|---|---:|---:|
| 1/5 | 宏村文化导览 480×360 | 40 | 182 |
| 2/5 | 古村落全景／宏村月沼 480×360 | 30 | 144 |
| 3/5 | 承志堂木雕 400×300 | 40 | 188 |
| 4/5 | 宏村历史老照片 320×240 | 21 | 98 |
| 5/5 | 徽派建筑马头墙 640×480 | 35 | 238 |

导览图新增介绍，其余四条中文保留用户原文。完整中英正文见 `HONGCUN_CAPTIONS_5.txt`；可维护数据源为 `HONGCUN_CAPTIONS_5.json`。英文为完整译文，沿用现有 ASCII 字库以大写显示，新增逗号字形，不再使用32字符短标题。

中文在 y=432..447，英文在 y=456..471，共用 x=16..623 的608像素窗口。切图时两行同时回到左对齐的开头，停留60帧后按相同速度、方向移动；两行各自按文字长度回绕。短中文也滚动。位置仅在帧消隐更新，换图时同步重置。切换速度或方向保留当前位置。

## 上板操作

1. 下载新命名 bit，K1复位；上电默认双语，自动轮播默认关闭。
2. K2逐张翻图，检查五组字幕及5→1，确认与上表一一对应。
3. SW=1100，按K3循环关闭／中文／英文／双语。
4. SW=0010，按K3选1／2／4像素每帧；SW=0011，按K3切左右方向。
5. 先保持自动轮播关闭，完整阅读每条字幕。按K4可开关原有轮播，但原轮播只在空闲显示约1秒后请求切图，会打断长字幕，本次没有修改轮播时间。

注意：当前扫描器按TF卡**物理扇区顺序**取前五个合法BMP，不按文件名前缀排序。资源管理器截图不能证明板上扫描顺序。若图文不对应，先核对板上实际顺序、制卡顺序和连续扇区条件；本次未改写TF卡，也未修改读卡算法。

## 修改与资源

修改 `tools/gen_captions.py`、`OSD/osd_overlay.v`、`OSD/osd_font_rom.v`。生成脚本从JSON读取五组正文，只替换字幕生成区。补齐英文长度、起点、完整字符表，扩大英文滚动位置到12位，覆盖最长238字符。中文110种字形继续使用原2048×16 BRAM，未增加BRAM或DSP。

保持现有时钟与复位结构，未增加跨时钟通道。字形两级、OSD RGB/DE/HS/VS/X/Y三拍、OSD加频谱六拍保持对齐，视频输出段与右栏逻辑和修改前逐字核对一致。

最终资源：LUT **15394/19600**，寄存器 **9676/19600**，BRAM9K **55/64**，DSP **29/29**，PLL **3/4**。最终 setup WNS **+0.119ns**、hold WNS **+0.004ns**，两项TNS为0，STA覆盖率95.38%。原SDRAM时钟例外和接口约束边界保留；这不代表完整接口电气验证。

## 验证矩阵

| 要求 | 证据（caption_scroll_evidence） | 状态 |
|---|---|---|
| 五组中英文全字符及顺序 | captions.log；JSON独立期望值逐字符与中文字形核对 | SIM PASS |
| 双语模式、短句、三速度、双向、尾部和回绕 | captions.log；48次渲染、1966080个精确参考像素 | SIM PASS |
| 切图、5→1、复位 | captions.log；独立位置模型 | SIM PASS |
| 字幕像素和RGB/DE/HS/VS/XY延迟 | captions.log；三拍逐像素核对 | SIM PASS |
| 导览图、I2S→FFT频谱、AXIS输出 | scene.log；实际素材、5帧、1536000像素、5 SOF、2400 EOL | SIM PASS |
| 中文BRAM初始化 | font_rom_init.json；2048行、32768位与综合数据库一致 | SYNTH PASS |
| 全工程综合、布局布线、bit | synthesis.log、implementation.log、routed_timing.rpt、routed_area.rpt | IMPLEMENTED/TIMING PASS（继承约束内） |
| 实际开发板功能 | 用户反馈“已经板上测试通过了”；无独立设备端哈希或逐项测量 | BOARD PASS（用户反馈） |

`caption_scroll_evidence/RTL_PREVIEW.png`来自真实RTL仿真输出，主图为导览BMP，不是板上实拍。下载文件SHA256及源码指纹见 `release_summary.json` 和 `source_manifest.json`。

## 重建与回退

在工程根目录执行 `python tools/gen_captions.py`，再运行 `./run_spectrum.ps1 -Step build`，或用TD打开现有 `.al` 工程重新综合实现。不要用历史 `prepare` 流程覆盖当前字幕修改。新构建需重新验证并记录哈希，不能沿用本次报告。

在 `caption_scroll_evidence` 目录运行：

```powershell
& 'E:\Modelsim\win64\vsim.exe' -c -do captions.do -l captions.log
& 'E:\Modelsim\win64\vsim.exe' -c -do scene.do -l scene.log
```

更改字幕正文后需同步更新测试黄金数据（golden.svh），再执行回归。其字符流来自批准JSON，中文字形来自软件字体渲染；测试不使用RTL自身的滚动位置作为期望。

回退：恢复 `caption_scroll_evidence/before` 中三个源码文件，或直接下载保留的 `FIVE_IMAGES_UI_20261103.bit`。历史四图板测结论不自动适用于本次bit。

## 本轮板测反馈

2026-11-03用户原话：“已经板上测试通过了”。关联本轮交付的 `HONGCUN_5_BILINGUAL_SCROLL_20261103.bit`，SHA256 `728f960e4054e46cea244d7ba5907edbc7d7c0ff35f3ec7ecef21fbbf2aa789d`。这是用户功能验收反馈，不声称独立观察到设备端下载哈希，也不扩大为完整SDRAM电气接口验证。
