# 存储观测诊断版

## 批准与边界
用户批准2026-10-25：修改frame_fifo_write、frame_read_write、top_tf_hdmi_audio、sd_card_bmp及测试，增加观测，不更改切图策略、时钟、视频流水线延迟，生成独立诊断bit。
CONFIRMED：EG4S20/TD6.2；SD100MHz、mem125MHz、pixel25MHz；现有滚动保留；旧bit保留。
UNKNOWN：短按K2卡住的硬件根因；新增观测布局后是否仍重现。

## 观测语义
- 写控制器输出原state、write_cnt、burst_cnt，仅新增输出连线，未改变状态转移或控制表达式。
- write_cnt是已完成突发的字数计数，不是硬SDRAM内容校验。
- pop_count是App_wr_en && !empty_flag的请求计数，清零期间不计；它也不是SDRAM实际写入验证。
- write域overflow：write_en && full && !fifo_aclr时锁存。
- write域reset_write：write_en && fifo_aclr时锁存。以上两位在新write_req上升沿清除。
- mem域underflow：App_wr_en && empty时锁存；finish_seen：曾观察到write_finish。这两位与pop_count在FIFO清零时清除。
- mem状态通过复用osd_status_cdc的80位邮箱送入SD域，多位数据保持到ACK返回。中间状态可能合并，不能用邮箱捕获单拍事件，因此事件先在源域锁存。
- SD域停滞2秒后冻结最近一次邮箱状态和write域标志。两域观察不是严格同拍；快照可能滞后数个时钟，非波形采集。
- FIFO清零信号是现有异步控制的写域观察，reset_write仍需结合其它证据判断，不能单凭此位证明电气边沿。

## 数码管七页顺序
每页1秒，循环7秒。前5位是数据，最后一位仍为原状态码，例如6。
0. 原源像素数，例如4B0006。
1. 原F开头的flags，例如FC9CC6。
2. 已完成突发字数write_cnt（无页头）。
3. 非空FIFO读请求数pop_count（无页头）。
4. C开头：C + state四位 + used10位 + 2'b00；从20位值提取state=(value>>12)&15，used=(value>>2)&1023。
5. D开头：D + memflags8位 + writeflags3位 + 5'b0。
   memflags从高到低：finish_seen、underflow、read_busy、write_busy、Sdr_busy、Sdr_init_done、write_finish、fifo_aclr。
   writeflags从高到低：reset_write、overflow、full。
6. E开头：E + burst_count10位 + 6'b0。

请卡住后保留现场，录至少10秒完整数码管，另记录字幕是否继续移动。未卡住时不宣称已修复；应再测单次短按、长按、K4。

## 验证
SIM PASS（有明确边界）：run_storage_probe.do使用真实厂商FIFO RTL，8字/4字突发缩小场景验证正常计数、完成事件、注入溢出/清零写/空读锁存及清除。
原工程9位FIFO输出接到10位网线，纯RTL仿真高位Z导致原控制条件X；为隔离新增观测，测试显式force这两个高位为0。该假设不是工程修改，也不是整机等价证明。初始未填零的测试失败已记录，厂商RTL未修改。
SIM PASS：run_stall_diagnostics.do覆盖原3类停滞、AUTO仍响应、七页解码、冻结存储快照不随输入变化、复位清除。该测试强制内部加载状态，不验证真实TF卡读写。
HDL新代码分析零错误；真实FIFO测试仍有原有未连接端口和位宽警告。数码管测试零错误/零警告。
原RGB/DE/HS/VS/坐标流水线未修改；本轮未重跑此前已通过的2065万次滚动逐像素测试，因为滚动模块未更改。
整机时序、构建和bit哈希以manifest和本目录原始报告为准；板测UNVERIFIED。

## 回退
正常关闭滚动bit和原动态bit未覆盖。四个修改前源码保存在本目录；仅在确认没有后续同学修改时才可按observation.patch逐项回退，禁止整仓重置。
