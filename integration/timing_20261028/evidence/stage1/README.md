# 时序优化第一批：BMP扫描扇区数预计算

2026-10-28，用户确认具体方案后实施。仅修改RTL bmp_read.v，将file_sector_count组合表达式改为每周期寄存。保留32位加法的原有溢出语义。文件长度在头部第2..5字节获取，扫描判断在512字节扇区结束时执行，因此预计算的一拍延迟不增加扫描事务、图像或控制输出延迟。未改时钟、复位、约束、IP、FIFO和像素路径。

## 验证与时序

| 项目 | 修改前 | 修改后 | 状态 |
|---|---:|---:|---|
| SD卡域setup WNS，100MHz | -0.305ns | +0.182ns | IMPLEMENTED/TIMING PASS（该域） |
| SD卡域违例端点 | 3 | 0 | 清零 |
| 内存域内部setup WNS，125MHz | -1.626ns | -0.496ns | FAIL |
| SDRAM命令方向setup WNS | -2.787ns | -2.842ns | FAIL，略恶化 |
| SDRAM读方向setup WNS | -6.699ns | -6.699ns | FAIL |
| 数码管路径setup WNS | -0.325ns | +0.004ns | PASS，裕量很小 |
| 全局setup WNS/TNS | -6.699/-342.719ns | -6.699/-307.853ns | FAIL |
| 全局hold WNS/TNS | +0.011/0ns | +0.003/0ns | PASS，裕量很小 |
| STA覆盖 | 95.14% | 95.13% | 未全覆盖 |
| LUT/REG | 5479/4627（既有记录） | 5582/4645 | BRAM20、DSP3、PLL3 |

除目标SD卡逻辑外，其他路径裕量变化属于本次重新综合、布局布线的结果，不能解释为对应模块逻辑已修复。

- 新增tb_bmp_scan_timing.sv和run_bmp_scan_timing.do：12组零长度、511/512/513边界、正常BMP长度、32位溢出、数据停顿、无效头、扫描上界场景通过。
- 既有转场/OSD回归通过：545297有效像素，22586字形点；控制回归通过；跨域元数据传输18项通过。
- ModelSim沙箱内启动发生系统DLL重定位错误，使用获准的沙箱外运行后通过。
- TD综合、布局布线和bitgen完成。约束未放宽，尚未烧录，本批新bit为BOARD UNVERIFIED。

## 文件与回退

- bmp_read.before.v：修改前源文件。
- before_timing.rpt：10月28日10:37旧报告。
- after_timing.rpt：本次10:48 Routed报告；不要将phy_1中未重新生成的final_timing.rpt误认为最新报告。
- after_area.rpt、implementation.log、两份仿真日志：本次证据。
- OSD_TRANSITION_TIMING_STAGE1_20261028.bit：本次候选，哈希见hashes.json。
- 用户成功bit仍保存在../board_pass_20261028，命名OSD_TRANSITION_20261027.bit未覆盖。本次批处理未执行save_best_bits，best_result不代表本次候选。

下一批建议分析FIFO写入条件的加法比较链；SDRAM接口则需结合器件/控制器时序和移相单独确定方案，不可直接切为false path。后续RTL或PLL/约束变更需另行审阅方案。
