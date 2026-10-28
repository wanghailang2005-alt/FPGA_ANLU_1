# 时序优化第二批：FIFO写入启动判断寄存

2026-10-28，用户批准具体方案后实施。沿用第一批bmp_read.v扇区数寄存修复，只修改frame_fifo_write.v，新增fifo_data_ready寄存器。

## 逻辑和延迟

FIFO数据充足条件只在S_CHECK_FIFO且无同步新请求时计算并寄存，其他状态清零；into_burst仍使用当前周期App_rd_busy进行仲裁。该等待状态不消耗FIFO数据，故上一拍为真的充足判断保持安全。复位、新请求ACK和离开检查状态均清除资格，防止突发结束后复用旧值。

启动资格比原组合判断增加一拍，125MHz下为8ns；进入检查状态时增加一拍资格采样。读写竞争仍可增加等待。突发内部的输出时序、吞吐、像素格式和地址算法均未修改，OSD/RGB/DE/HS/VS延迟不变。每个完整256字突发多一拍检查，纯写入周期开销约0.4%，实际整机影响未板测。

本批未修改FIFO IP、PLL、时钟、约束或厂商加密控制器，也未使用false path隐藏违例。

## 需求与证据

| 项目 | 第一批 | 第二批 | 状态 |
|---|---:|---:|---|
| 内存域内部setup WNS，125MHz | -0.496ns | +0.140ns | IMPLEMENTED/TIMING PASS（该域） |
| 内存域内部setup违例端点 | 39 | 0 | 清零 |
| SD卡域内部setup WNS，100MHz | +0.182ns | +0.300ns | PASS |
| 视频域内部setup WNS，25MHz | +7.988ns | +9.554ns | PASS |
| SDRAM命令方向setup WNS | -2.842ns | -2.787ns | FAIL |
| SDRAM读方向setup WNS | -6.699ns | -6.699ns | FAIL |
| 全局setup WNS/TNS | -6.699/-307.853ns | -6.699/-293.242ns | FAIL |
| 全局hold WNS/TNS | +0.003/0ns | +0.003/0ns | PASS，裕量很小 |
| STA覆盖 | 95.13% | 95.09% | 非全覆盖 |
| LUT/REG | 5582/4645 | 5461/4648 | BRAM20、DSP3、PLL3 |

剩余setup违例：ext_mem_clk到移相SDRAM时钟32个端点，反方向32个端点，总计64个。其他路径裕量变化包含重新综合及布局布线的影响，不代表对应模块另有逻辑修改。

- 新增tb_fifo_write_timing.sv：旧版参考控制器与新版各自驱动独立FIFO模型，用独立数学模型检查所有实际输出地址及数量。正向/翻转各8组场景，共16组通过，覆盖1/255/256/257/512/307200字长度、输入停顿、空FIFO、读写仲裁、新请求清除旧资格、突发中复位和复位后再次加载。
- 完整640x480图像两种地址模式均严格输出307200字，无FIFO空读、越界多写、读写重叠或地址错位。仿真为控制与FIFO模型级，不是实际SDRAM硬件验收。
- 既有回归通过：三模式/三档转场、545297有效像素、22586字形点；加载控制回归；元数据跨域18项场景。
- TD综合、布局布线、bitgen完成；ModelSim在获准的沙箱外执行。
- 新bit尚未上板，BOARD UNVERIFIED。不能标记整机时序闭合。

## 原有边界问题

非256整数倍长度，旧版和新版都会输出准确的尾部字数，但旧版wr_burst_finish只判断burst_cnt达到BURST_SIZE，尾部不足一突发会停留等待，不能正常报告整帧完成。本次保持原行为；当前640x480固定长度307200为256整数倍，不触发该问题。若后续缩放改变实际写入长度，必须重新处理此边界，不能据本测试声称任意帧长均可完成。

## 文件和回退

- OSD_TRANSITION_TIMING_STAGE2_20261028.bit：本次候选，SHA256见source_and_bit_hashes.json。
- frame_fifo_write.before.v：第一批版本的FIFO控制源码，可回退；frame_fifo_write_reference.v为仿真参考副本。
- before/after_timing.rpt、before/after_area.rpt、synthesis.log、implementation.log及仿真日志：本次证据。
- source_and_bit_hashes.json：生成后记录的RTL/约束/IP配置及bit哈希。
- 原用户板测成功bit保留在../board_pass_20261028；第一批候选保留在../timing_opt_stage1_20261028；OSD_TRANSITION_20261027.bit未覆盖。
- 本批通过批处理生成phy_1输出，未执行save_best_bits。best_result和GUI缓存未必对应本批结果；本目录命名bit及after_timing.rpt是本批交付入口。

下一步：核对SDRAM内置硬核的时序模型、加密控制器使用要求和PLL相位，另行提出接口时序修改方案。

## 后续用户板测反馈

2026-10-28，用户在第二批交付后明确反馈“上板验证也通过了”。因此第二批功能标记为用户反馈BOARD PASS；不代表整机时序闭合或长期运行稳定性验收。原始构建时的未上板描述作为当时状态保留。
