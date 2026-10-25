# 固定文字 OSD 候选工程接入

最新状态（2026-10-25）：字幕前景色已改黑；用户反馈屏幕已显示 HELLO FPGA。下文构建时间、bit 哈希与 UNVERIFIED 表格为历史记录，不代表本次板测所用 bit。完整回归和整机时序收敛仍待完成，详见仓库 README 最新记录。

日期：2026-10-20。状态：接口与接入片段 SIM PASS，TD 综合及布局布线/bitgen 完成，整机 setup 未通过，板测 UNVERIFIED。

## 本次已生成的本地工程

候选目录位于本仓库的同级：`../lab_ex5_i2s_osd/`。

TD 入口：`src/td_project/HDMI1.4b_Transmitter_v1.0.al`。

测试 bitstream：`src/td_project/HDMI1.4b_Transmitter_v1.0_Runs/phy_1/HDMI1.4b_Transmitter_v1.0.bit`。

本地已完成构建，无需再运行准备脚本覆盖。脚本遇到已存在目录会拒绝执行，避免破坏候选版本。原 `lab_ex5_i2s` 136 个源码/IP 文件在构建后重新校验均未修改。

## 修改边界

复制后只修改三份已有文件：

1. 顶层 `top_tf_hdmi_audio.v`：插入坐标与 OSD，RGB-to-AXIS 改接匹配的延迟后 RGB/DE/VS。
2. `.al` 工程：更新候选目录，加入五个 OSD 源文件；新建候选运行目录与对应源清单。
3. `video_rgb_to_axis_640x480.v`：用户单独批准的行尾修正，行首 `S_x_cnt <= 0` 改为 `1`；不改输出延迟。

新增五个源文件复制至候选 `src/user_source/hdl_source/OSD/`。未更改 PLL/IP 参数、音频、TF/SDRAM 算法、引脚或 SDC，不增加 SW/K3。物理 K1/K2/K4 原功能保留。

本仓库提供准备脚本、接入片段和小范围变更 patch；不直接分发厂商加密 IP、整套参考源码或编译数据库。候选 bitstream 含完整厂商设计，因此仅作为本地构建产物，不提交 GitHub。

## 接线与延迟

`vout_data/hs/vs/de → osd_video_position → osd_overlay → 原 RGB-to-AXIS → HDMI核/PHY`。

坐标一级，OSD 三级，AXIS 适配一级；从接入点输入到 AXIS 输出共五级寄存。没有为新增逻辑创建时钟，全部使用现有 video_clk、rst_all。

首图前原有 display_valid 黑屏门控保留。新增文字使能单独对 display_valid 做两级单比特同步，再于坐标模块帧消隐事件锁存，避免首图提交前出现字幕及半帧开字。固定文字因此可能比首图晚一帧出现。

现有 HDMI 核 ready 与上游无反压的结构未改变；仿真没有将其扩展为已证明支持任意 backpressure 的 AXIS 源。需要额外研究 ready 时另立接口与验证方案。

## 为什么修正 LAST

原适配器在第一个有效像素将计数设为 0，后续判断读取旧计数，导致第 640 个像素仍未发出 LAST。基线定向测试在 line=0、x=639 失败，保存在 `evidence/modelsim_axis_baseline.log`。

修正后两行 1,280 个像素检查通过；整个接入片段加修正后适配器的三帧测试通过 1,260,007 次检查，得到 921,600 个有效像素、1,440 个 LAST、3 个 SOF。原适配器文件没有修改，只修改候选副本。

## 构建与时序结果

| 项目 | 结果 |
|---|---|
| 工具/器件 | TD 6.2.168116 / EG4S20BG256 |
| 综合 | SYNTH PASS，完成，不是零警告 |
| 布局布线与 bitgen | 完成，生成 629,624 字节 bit 文件 |
| LUT / 寄存器 | 4,542 / 4,077 |
| BRAM9K / DSP / PLL | 20 / 0 / 3 |
| video_clk | 25 MHz，40 ns，报告该域 setup WNS +4.139 ns |
| 整机 setup | WNS -6.699 ns，TNS -295.425 ns，66 个违例端点 |
| 整机 hold | WNS +0.003 ns，TNS 0 |
| STA coverage | 95.62%，并非全覆盖 |
| 整机时序结论 | FAIL，不能标记 IMPLEMENTED/TIMING PASS |
| 板级 | UNVERIFIED |

最差 setup 路径由 `U3/sdram.dq[0]`（sys_pll 第 2 输出、125 MHz、相移）到 `U3/sdram_syn_1.bpad`（ext_mem_clk，125 MHz），不在新增 OSD 组合路径中。历史基线报告的全局 WNS 同为 -6.699 ns、TNS -296.527 ns；这只是历史报告对照，没有为本轮重新构建原工程。

历史资源报告 LUT=4,362、reg=3,912，候选差值 +180/+165；由于存在单独批准的 LAST 修正与重新布局，该差值不能全部精确归因于 OSD。

综合警告仍包含加密 SDRAM 内部未驱动时钟、忽略某些 IP 初值以及未约束时序端点等。与历史综合日志比较没有新增 SYN 警告编号；编号相同不代表每条告警已完全审阅或不存在新增实例。保留原约束，没有放宽时钟或添加 false path 来消除报告。

## 在另一台电脑重建

准备好自己的官方 `lab_ex5_i2s` 基线，包含已有 TD 运行生成的 `.prj` 和 `settings.cfg`。从 osd_dev 目录运行，目标必须为不存在的新目录：

```powershell
python integration/prepare_candidate.py --source ../lab_ex5_i2s --dest ../lab_ex5_i2s_osd --fix-axis
```

`--fix-axis` 明确启用本次已批准的候选修正，不会写源目录。脚本记录源码哈希并检查候选 `.al/.prj` 的所有 File Path 均在候选内且存在。

打开候选 `.al` 后可以从 GUI 重建。命令行使用本机 TD 安装的 DefaultFlow，先 syn_1 再 phy_1：

```powershell
$osdRepo = (Resolve-Path .).Path.Replace('\','/')
$tdExe = 'E:\Anlogic\TD_6.2.1_Engineer_6.2.168.116\bin\td_commands_prompt.exe'
Push-Location '../lab_ex5_i2s_osd/src/td_project/HDMI1.4b_Transmitter_v1.0_Runs/syn_1'
& $tdExe "$osdRepo/integration/build_td.tcl"
Pop-Location
Push-Location '../lab_ex5_i2s_osd/src/td_project/HDMI1.4b_Transmitter_v1.0_Runs/phy_1'
& $tdExe "$osdRepo/integration/build_td.tcl"
Pop-Location
```

注意 Tcl 脚本参数使用正斜杠，反斜杠会被 TD 命令入口当作转义。不能只看进程退出码判断完整成功，检查 .end 标记、最终报告和本次 bit 文件。

## 仿真复现

从 sim 目录依次使用：

- `run_candidate_axis.do` 默认读原基线，预期重现 LAST 失败；验证候选时设置 axis_source 为候选适配器，并指定独立 log_file。
- `run_candidate_video.do` 默认读同级候选适配器，使用与真实顶层相同的 `top_osd_insert.vh` 片段，检查首图前黑屏、帧边界开字、五级延迟以及 USER/LAST/valid/data。
- 测试使用像素源和假定 display_valid 变化，不是 TF、SDRAM、音频和 HDMI 加密 IP 的端到端仿真。

## 上板记录与回退

本 bit 文件是实验候选，整机时序尚未通过，不作为稳定发布版本。若用于本轮实验观察，记录所用 bit SHA256、板卡、卡内容、接线与实际结果；不得把“bit 已生成”写成“板级通过”。建议先解决或明确分析存储/读卡时序问题，再做稳定性验收。

实际操作时打开候选工程而非原工程，使用原 HDMI_B 接线和已验证 TF 卡。预期首图出现后左上角显示 HELLO FPGA，背景保留。记录切图、轮播、测试音、复位、重新上电和长时间运行。失败时回到原已验证 bit，不在原目录继续改写。

bit SHA256：`b8256206e55ecf75b58fdbff28b803c9b01dae8abd82e4f16e46d0389212b545`。

| 验收项 | 当前状态 | 待补证据 |
|---|---|---|
| OSD 到 AXIS 像素与标记 | SIM PASS | 仿真日志已保存 |
| 完整候选综合 | SYNTH PASS | 报告已保存 |
| 布局布线与 bit 生成 | 完成 | 本地 bit 和报告 |
| 整机时序 | FAIL | 存储相关 setup 违例需单独诊断 |
| 真正 HDMI 图像与文字 | UNVERIFIED | 显示照片或录像 |
| 切图、轮播、音频回归 | UNVERIFIED | 用户板测记录 |
