# 五张图片支持（2026-11-03）

经用户“开始”批准，从现有四图 UI 扩展到五图；新下载文件为 `FIVE_IMAGES_UI_20261103.bit`。旧根目录 bit 保留。

K2 翻页及自动轮播按 1→2→3→4→5→1 循环；不足五张时按实际扫描数量循环。扫描顺序仍按 TF 卡物理扇区顺序，最多取前五个合法 BMP，不按文件名排序。沿用未压缩 24 位 BMP、宽高 1..1024、单个文件连续扇区存储的要求；扫描范围仍为扇区 0..131071。请确保第五个 BMP 头位于范围内。

第五张默认字幕：第五张图片 / IMAGE FIVE。前四张字幕保留。修改 `tools/gen_captions.py` 可生成字幕表，脚本使用当前工程相对路径，只替换生成区，保留 UI 及像素流水线。

图片编号、加载编号、双缓冲标签扩为 3 位；SD→存储状态由 9 位扩为 11 位，存储→像素状态由 5 位扩为 6 位。帧边界锁存及 CDC 握手结构保留，OSD RGB/DE/HS/VS/X/Y 仍为原有三拍对齐。帧状态与双缓冲标签通过定向仿真；完整跨时钟系统及板上行为仍待实测。旧数码管诊断 flags 的加载编号保持低两位，完整编号见屏幕右栏。

| 要求 | 证据 | 状态 |
|---|---|---|
| 扫描五张、第五张像素读取 | five_image_evidence/five.log；合成 BMP 扇区模型 | SIM PASS |
| 0..5 张边界及循环 | 从 RTL 提取 next_index_limited、sector_lut 的测试 | SIM PASS（函数级） |
| 五图四语言、滚动与静止字幕 | five_image_evidence/captions.log；像素回归 | SIM PASS |
| 第五张双缓冲编号及帧提交 | five_image_evidence/metadata.log | SIM PASS |
| 综合、布局布线和 bit 生成 | synthesis.log、implementation.log | PASS |
| 当前约束下时序 | routed_timing.rpt；setup +0.116ns、hold +0.003ns，TNS 均为 0 | IMPLEMENTED/TIMING PASS |
| 资源 | routed_area.rpt；LUT 14942/19600、BRAM9K 55/64、DSP 29/29 | PASS |
| 真实 TF 卡和 HDMI 板测 | 未执行；不能沿用旧版板测结论 | UNVERIFIED |

时钟保留：输入 50MHz，图片读取 100MHz、存储 125MHz、视频 25MHz。原 SDRAM 时钟例外与接口约束边界保留，时序报告不是完整接口电气验证。

上板：下载新 bit，K1 复位，等待扫描与首图显示；连续按 K2 检查第五张和 5→1、右栏 5/5 及第五张字幕，再开启轮播检查五图循环，回归缩放和转场。

重建：`./run_spectrum.ps1 -Step build`。定向仿真：在 `five_image_evidence` 下用 ModelSim 分别执行 `five.do`、`captions.do`、`metadata.do`。`before/` 保存本次修改前源文件，回退时需成组恢复，避免状态位宽不匹配。下载文件哈希与源码清单见同目录 JSON。
