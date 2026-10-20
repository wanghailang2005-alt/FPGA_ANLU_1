# SDRAM 与写入握手时序诊断

日期：2026-10-20。只读诊断完成；本步不修改 RTL、测试平台、PLL、约束、IP 或工程元数据。整机时序 FAIL，板级 UNVERIFIED。

## 意图与边界

| 项目 | 状态与内容 |
|---|---|
| 最终效果 | CONFIRMED：保留图片、轮播、音频，在图像上加入固定文字；原已跑通工程保留 |
| 平台 | CONFIRMED：EG4S20BG256，TD 6.2.168116，独立 lab_ex5_i2s_osd 候选 |
| 接口 | CONFIRMED：读卡 100 MHz、存储 125 MHz，现有帧 FIFO；视频 25 MHz |
| 视频延迟 | CONFIRMED：坐标 1 级、OSD 3 级、AXIS 1 级，共 5 级；本步不变 |
| 本步允许范围 | CONFIRMED：读取代码、实现报告和厂商资料，保存诊断证据 |
| 存储采样方案 | UNKNOWN：现有相位下的硬 SDRAM 路径尚未证明满足时序；不能直接判为假路径 |
| 验收 | CONFIRMED：仿真、综合、布局布线、整机时序、板测分别记录；bitgen 不等于时序通过 |

## 全部违例的归类

源报告：候选 `src/td_project/HDMI1.4b_Transmitter_v1.0_Runs/phy_1/HDMI1.4b_Transmitter_v1.0_pr.timing`。报告为 Routed、slow/fast 双角，STA coverage 95.62%。

| 路径组 | setup WNS/ns | TNS/ns | 违例端点 | 打印的负裕量详细路径 |
|---|---:|---:|---:|---:|
| ext_mem_clk → sd_card_clk | -0.612 | -0.712 | 2 | 2 |
| ext_mem_clk → PLL 输出 2（125 MHz、180°） | -2.799 | -80.345 | 32 | 10 |
| PLL 输出 2 → ext_mem_clk | -6.699 | -214.368 | 32 | 10 |
| 合计 | -6.699 | -295.425 | 66 | 22 |

端点数来自路径组汇总，详细路径最多打印每组 10 个，不能把 22 当成全部违例。三组 TNS 之和与全局报告一致。机器可读结果和源报告 SHA256 见 [分类 JSON](sdram_setup_classification.json)，每组最差详细路径见 [原文摘录](sdram_setup_path_extracts.txt)。

全局 hold WNS +0.003 ns、TNS 0；视频域汇总 setup WNS +4.139 ns。当前 setup 失败集中于原有存储及握手结构。历史基线最差 WNS 也是 -6.699 ns，但没有重新构建基线，不能以此证明新增逻辑对所有路径都没有影响。

## SDRAM 读写路径

读路径 `U3/sdram.dq[0] → U3/sdram_syn_1.bpad`：半周期预算 4 ns，数据路径 6.453 ns（硬 SDRAM 访问 5 ns，加输入 PAD 1.453 ns），无数据布线延迟；报告时钟 skew 4.306 ns，最终 slack -6.699 ns。它不是可用 OSD 流水线切分的长组合逻辑。

写路径 `U3/u2_ram/u2_wrrd/app_wr_din_2d_reg[20]_syn_3.clk → U3/sdram.dq[17]`：预算 4 ns，数据延迟 10.364 ns，cell 8.193 ns、net 2.171 ns，slack -2.799 ns。

当前 sys_pll 输出为 100 MHz、125 MHz 0°、125 MHz 180°；sdram.v 给控制器接入后两者。未经采样周期和控制器数据对齐分析，不能添加 multicycle/false path，也不能随意改相位。125 MHz 降到 100 MHz，半周期只多 1 ns，不能据此保证解决 -6.699 ns。

## 写入握手与 FIFO 清零

静态追踪：`frame_fifo_write` 的 write_req 经三级寄存进入 mem_clk；返回 write_req_ack 经 frame_read_write、顶层、sd_card_bmp 接到 bmp_read，在 ST_LOAD_WAIT 直接使用，没有返回域同步器。

`frame_fifo_write` 的 S_ACK 在请求保持高时同时置 ACK 和 fifo_aclr 为高；请求低经过三级同步返回后，才同时清 ACK 和 fifo_aclr。`frame_read_write` 将 fifo_aclr 接到写 FIFO 的 rst。综合合并/命名使报告起点出现 fifo_aclr_reg；不能仅凭网表名称把它当成独立于 ACK 的问题。

`bmp_read` 目前看到 ACK 高即撤销请求、进入 ST_LOAD_DATA，下一拍便可以发 sd_sec_read。真实 SD 读命令通常有等待时间，但代码没有建立“FIFO 清零已释放，才能开始数据”的握手保证。仅在 ACK 返回处增加两级同步可以隔离直接采样，却不能独立证明清零与首数据的顺序正确。

建议的后续小步：在 bmp_read 内同步 ACK；看到 ACK 高只撤销请求，新增等待 ACK 低的状态；确认 ACK 低已同步后才进入读数据状态。这样增加的是每张图启动时的等待，不改变像素吞吐或 OSD 五级延迟。同步器预计增加 2 个触发器，状态译码资源待综合确认。必须结合实际 FIFO 复位规格验证恢复时间；数字仿真不能模拟或证明亚稳态 MTBF。

## 厂商资料核对

本地官方资料包：`6_EG4S20数据手册/设计的IP参考设计文档.zip` 内的 APUG011 high_performance_sdram_read_write v1.2 和 APUG011 PDF。

- 参考设计采用同频 0°/180°，示例 150 MHz；约束仅定义主时钟并 derive_pll_clocks，没有可直接套用的 SDRAM false path 或 multicycle。
- APUG011 PDF 第 10 页（印刷页 7）列出 Sdr_clk / Sdr_clk_sft 接口；第 15 页（印刷页 12）迁移注意事项第 6 条说明硬件、频率、相位变化可能导致读数据相差一个周期，需要实际适配。
- 当前 sdr_wrrd.enc.v 与参考版本字节相同；sdr_as_ram、sdr_init_ref 不同，因此不能当成整套相同实现。未解密或编辑加密 HDL。
- 旧版手册的器件时序数字不能替代当前 TD 库模型，也不能据此覆盖报告的 5 ns 访问延迟。

尝试读取 routed DB 的 report_clock_utilization -dramhardcon，工具提示该器件不支持此选项，因此没有得到可用于判断专用时钟布线的新证据。

## 下一步选择（待批准，尚未实施）

1. **推荐先做握手小步**：只改候选 bmp_read、相应可审阅补丁/复现材料，新增双时钟握手测试。覆盖多个相位、ACK 高低等待、请求保持、复位中断、连续两张图，以及最快首数据到达。再重建检查握手路径、资源和全局时序。普通 RTL 修改，回退边界清晰；不会单独解决其余 64 个 SDRAM 违例。同步器首级约束如需处理，先根据结构提交具体方案，不屏蔽整个时钟组。
2. **先做独立 SDRAM 验证工程**：以厂商参考做写入/读回和图案校验，核对实际器件及采样周期，再设计受控 PLL/接口方案。工作量与验证范围更大，可能改变启动或存储延迟、资源和兼容性，目前没有证据确定最终参数；不能承诺一轮消除违例。

两条路径都不需要重写现有 OSD。建议先把可定位的握手问题单独闭环，再处理硬 SDRAM 路径。后续修改须先批准具体文件与验证范围；本报告不是修改授权，也不宣称已修复。

| 要求 | 证据 | 当前状态 |
|---|---|---|
| 全部 setup 违例归类 | 路径组端点合计 66、TNS 合计 -295.425 ns | 诊断完成 |
| 解释最差路径 | Routed 路径、PLL 配置、厂商接口资料 | 已定位，修复方案待验证 |
| 追踪返回握手 | bmp_read / frame_fifo_write / frame_read_write 静态代码 | 确认直接采样与释放顺序缺口；尚未修改 |
| 保持原工程与候选实现 | 本步仅新增证据及文档 | 无 RTL/IP/约束改动 |
| 整机时序与板级运行 | 现有构建报告；暂无板测反馈 | TIMING FAIL / BOARD UNVERIFIED |
