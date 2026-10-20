# HX4S20 HDMI OSD 渐进开发

本目录是三人协作项目中 OSD 板块的独立开发仓库。已完成字库、单字符选点和 HELLO FPGA 固定文字的 RGB 透明叠加仿真；尚未接入原有 TF/SDRAM/HDMI 工程。

## 当前能力

- 支持 A～Z、0～9、空格以及 `+ - . / : ;`，共 43 个编码；其他编码返回空白。
- 字形基于 8×8 位图，每行重复两次形成 8×16 字符框，不是真正的原生 8×16 字体。
- 每拍可接收一个行请求，输出经过一个寄存器级；无反压。
- 高有效异步复位，复位或无效请求时输出清零。
- `osd_glyph_pixel` 在字库后选择字内横坐标对应的像素，端到端固定两级寄存，支持每拍一个像素请求。
- `osd_overlay` 在 (16,16) 叠加白色 HELLO FPGA，三级寄存，背景/同步/坐标保持匹配，开关旁路不改变延迟。
- 文字还没有显示到 HDMI；当前验证级别为 SIM PASS，未进行本模块 TD 综合、时序或板测。

## 目录

```text
rtl/osd_font_rom.v          可综合字体行查询
rtl/osd_glyph_pixel.v       两级寄存的字符像素查询
rtl/osd_fixed_layout.v      HELLO FPGA 字符排版，组合输出
rtl/osd_overlay.v           三级视频寄存、透明叠加
sim/tb_osd_font_rom.sv      独立自检与字形预览输出
sim/run_font_rom.do         ModelSim 编译运行，返回成功或失败码
sim/tb_osd_glyph_pixel.sv   完整字符像素和两级时序自检
sim/run_glyph_pixel.do      选点模块自检入口
sim/tb_osd_overlay.sv       三帧完整视频逐拍自检
sim/run_overlay.do          固定文字叠加自检入口
evidence/                  真实仿真日志和 DUT 字形预览
THIRD_PARTY_NOTICES.md      字形来源与适配说明
LICENSE.FPGA-text-overlay   上游 MIT 许可原文
```

`.gitignore` 排除 ModelSim work 库、个人映射文件和波形缓存。原有厂商工程不属于本目录，不上传到本模块仓库。

## 接口与数据流

| 信号 | 方向/位宽 | 含义 |
|---|---|---|
| `clk` | 输入 1 | 单一处理时钟，未来接像素时钟 |
| `rst` | 输入 1 | 高有效异步复位 |
| `in_valid` | 输入 1 | 当前字符行请求有效 |
| `char_code` | 输入 8 | ASCII 编码，例如 A=0x41、0=0x30 |
| `glyph_y` | 输入 4 | 字符框行号 0～15 |
| `out_valid` | 输出 1 | 与本次寄存输出对应的有效标志 |
| `row_bits` | 输出 8 | 当前字形行；bit7 在左，bit0 在右 |

在上升沿采样输入，输出在该沿寄存器更新后生效。RTL 有一个寄存器级；不是在请求采样后再额外等待第二个上升沿。有效请求即使字符未知也返回 `out_valid=1`、全零行；无效请求返回 `out_valid=0`、全零行。

内部先选 64 位字形，再用 `glyph_y[3:1]` 选择原 8×8 的行，因此新行 0/1 对应原第 0 行，新行 14/15 对应原第 7 行。

## 运行 ModelSim

在 ModelSim Transcript 中执行，先把目录替换成本机位置：

```tcl
cd D:/2026FPGA_1/HX4S20_Contest_202606/7_lab_ex_2026_nosoft/osd_dev/sim
do run_font_rom.do
```

脚本最后会退出 ModelSim 并返回结果码，推荐使用命令行批处理。PowerShell 示例：

```powershell
Set-Location 'D:\2026FPGA_1\HX4S20_Contest_202606\7_lab_ex_2026_nosoft\osd_dev\sim'
& 'E:\Modelsim\win64\vsim.exe' -c -do run_font_rom.do
$LASTEXITCODE
```

成功结果码为 0；日志应包含 `SIM PASS: requests=4471 checks=8945`。脚本检查 testbench 的最终成功标志，不能仅凭 ModelSim 正常结束或打印内容判定通过。

自检包含全部 256 编码×16 行、连续变化的字符/行号、气泡、异步复位中断、复位后请求及寄存输出稳定性。预期数据来自独立的完整字形 fixture，查询计算与 DUT 不同；位图本身共享同一被引用作品，不声称第三方字形的审美或含义被数学证明。

可选的故意失败检查，用来验证测试脚本不会误报成功：

```powershell
& 'E:\Modelsim\win64\vsim.exe' -c -do 'set sim_args {+FORCE_FAIL}; set log_file ../evidence/modelsim_harness_negative.log; do run_font_rom.do'
$LASTEXITCODE
```

该命令预期返回 1，不能当作模块失败；正常功能自检仍使用不带参数的命令。

## 第二步 单字符像素查询

`osd_glyph_pixel` 输入为 `clk/rst/in_valid/char_code/glyph_x[2:0]/glyph_y[3:0]`，输出为 `out_valid/pixel_on`。x 范围 0～7，y 范围 0～15；1 表示文字前景像素，0 表示透明候选点。本模块不输出 RGB，不生成屏幕坐标。

```text
上升沿 N：字库寄存对应行，同时寄存输入 glyph_x
上升沿 N+1：用匹配的行与 x 选择像素，寄存 out_valid/pixel_on
```

从输入到输出经过两级寄存器；输入在 N 沿采样，匹配结果在 N+1 沿更新后可用，不是再等待到 N+2。无效请求在同样两级时序后输出 0/0。有效的空格、未知字符仍返回 out_valid=1、pixel_on=0。

ModelSim 命令行：

```powershell
Set-Location 'D:\2026FPGA_1\HX4S20_Contest_202606\7_lab_ex_2026_nosoft\osd_dev\sim'
& 'E:\Modelsim\win64\vsim.exe' -c -do run_glyph_pixel.do
$LASTEXITCODE
```

结果为 `SIM PASS: glyph pixels requests=33288 checks=66582`，退出码 0。检查包括全部 256 编码×16 行×8 列、快速改变字符/坐标、气泡、复位中断和流水线排空。独立队列在每个沿检查上一沿请求的结果，避免把一级或三级误认为两级。

`evidence/glyph_pixel_A.txt` 和 `.pbm` 是实际 DUT 输出的单字符图，PBM 中 1 表示字形前景。`modelsim_glyph_pixel.log` 保存编译与测试过程。当前仍只有 SIM PASS，未验证整帧视频对齐或板级显示。

可选失败退出检查：

```powershell
& 'E:\Modelsim\win64\vsim.exe' -c -do 'set sim_args {+FORCE_FAIL}; set log_file ../evidence/modelsim_glyph_negative.log; do run_glyph_pixel.do'
```

预期返回 1。该命令只检验脚本失败判定，不代表正常模块自检失败。

## 第三步 固定文字透明叠加

![实际 DUT 输出的文字局部预览](evidence/hello_fpga_preview.png)

预览来自仿真实际输出的 96×32 局部 PPM，PNG 只做 6 倍最近邻放大以方便阅读，不是开发板照片。原始 PPM 保存在 `evidence/hello_fpga_crop.ppm`。

模块连接：`osd_fixed_layout → osd_glyph_pixel → RGB 前景/背景选择`。字体/选点模块未修改。固定字框覆盖 x=16～95、y=16～31；字形点为 1 时白色，其他有效像素保留原图，DE=0 时黑色。

`osd_overlay` 接口：

| 输入/输出 | 含义 |
|---|---|
| `clk/rst` | 单一像素时钟、高有效异步复位 |
| `enable` | 文字开关；调用方保证一帧有效区期间稳定 |
| `in_rgb[23:0]` / `out_rgb[23:0]` | RGB888，R 在高 8 位 |
| `in_de/hs/vs` / `out_de/hs/vs` | 实际端口分别为 `in_de,in_hs,in_vs` 和 `out_de,out_hs,out_vs`；控制与像素等延迟 |
| `in_x[9:0],in_y[8:0]` / `out_x,out_y` | 左上原点有效区坐标；坐标由调用方提供，不能从此模块取得新增视频时序 |

排版是组合逻辑，不增加寄存级。选点经过两级寄存，同时背景与控制也经过两级；第三级寄存进行叠加并输出同步控制。输入在 N 沿采样，结果在 N+2 沿更新后可用；enable=0 也经过相同三级，不是直接接线旁路。主工程以后接入时，须使用匹配的 out_rgb/out_de/out_vs，不能只替换 RGB 而仍使用原始同步。

PowerShell 运行入口：

```powershell
Set-Location 'D:\2026FPGA_1\HX4S20_Contest_202606\7_lab_ex_2026_nosoft\osd_dev\sim'
& 'E:\Modelsim\win64\vsim.exe' -c -do run_overlay.do
$LASTEXITCODE
```

实际结果：`checks=1260016 active_pixels=921600 foreground_pixels=868`，退出码 0。测试运行三帧 800×525 总时序，其中每帧 640×480 有效区，HS/VS 为负极性；三帧依次开启/关闭/开启，逐拍比较 RGB、DE、HS、VS、X/Y，覆盖空格、字框四边、首末行列、消隐和复位中断。仿真使用 100 MHz 测试时钟加速逻辑检查，这不是板级像素频率或实测帧率。

正常日志为 `evidence/modelsim_overlay.log`。可用 `sim_args {+FORCE_FAIL}` 和独立 log_file 执行故意失败检查；预期返回 1。

本步没有生成真实视频坐标模块，也没有进行 AXIS/HDMI 完整链路验证、TD 综合、时序或板测；后续实时接入须先核对坐标和同步来源。

## Git 与 GitHub

本目录作为独立 Git 仓库，使用 `main` 分支。初始化提交包括模块、测试、使用说明、来源和验证证据。源码所在的上层参考工程没有被改成 Git 上传范围。

GitHub 仓库已建立并绑定：<https://github.com/wanghailang2005-alt/fpga-hdmi-osd>，主分支为 main。每个经过自检的小步骤单独提交。若远程出现队友提交，先检查并集成历史，不能强推覆盖。

认证由用户通过 Git Credential Manager 或浏览器登录完成，不把密码、Token 或私钥写进代码、日志或聊天。首次推送完成后，按同学的 GitHub 账号邀请协作者。

## 后续步骤

1. 已完成：字库行查询与单字符像素查询，对齐 x 与行数据并自检。
2. 已完成：在仿真背景上显示 HELLO FPGA，逐拍验证透明背景与 RGB/DE/HS/VS/坐标的三级对齐。
3. 下一步：核对并实现实时坐标适配，再经单独接入方案审阅，在候选工程接入并做 TD 检查与上板。
4. 加入图片序号、轮播状态与菜单；最后做滚动字幕和四位 SW/K3 控制。

K1 复位、K2 下一张、K4 轮播保持一致；本步骤尚未修改物理端口或按键逻辑。
