# ACK释放握手修复候选

用户批准2026-10-25：修改sd_card_bmp.v和bmp_read.v及对应测试，先同步ACK，再等待ACK释放才读取图片数据，保留诊断/滚动/IMG/AUTO、时钟、视频延迟，生成独立bit。

CONFIRMED：SD100MHz、存储125MHz；ACK为保持电平，frame_fifo_write在S_ACK中ACK与fifo_aclr同时保持高，请求撤销经3级同步后同拍清ACK和fifo_aclr。
CONFIRMED：旧BMP逻辑看见ACK高立即撤销请求并进入ST_LOAD_DATA，未建立等待清零释放的保证。
CONFIRMED：用户诊断页D2C806：reset_write锁存为1，overflow/underflow为0；同时源计数满、写端计数0、状态CHECK_FIFO且used0。
INFERRED：握手缺口与板级故障相关；这些证据不足以证明它是全部板级故障的唯一根因。

## 实现
- sd_card_bmp：新增两级SD域ACK同步器，raw ACK只进入首级；bmp_read和诊断均使用同步后ACK。
- bmp_read：新增ST_LOAD_RELEASE；见ACK高只撤销write_req并保持sd_sec_read=0，见ACK低后才进入ST_LOAD_DATA。
- 不改变BMP数据格式、扫描、图号、轮播策略、内存写读控制、PLL或SDC。
- 启动握手增加SD域同步/等待时间，ACK撤销前可以无限等待，不通过超时跳过；RGB/DE/HS/VS/坐标视频延迟不变。
- 这证明ACK协议顺序；厂商FIFO内部异步复位恢复时间和真实硬件仍需板测验证。

## 仿真证据
run_ack_release.do：使用真实sd_card_bmp和bmp_read逻辑，模拟带3级请求同步和保持ACK/FIFO-clear的存储端，不是SD卡/硬SDRAM电气模型。强制扫描与卡字节边界，使用1x1 BMP快速检查。
PASS：三次连续加载、不同ACK撤销延迟、清零期间禁止请求数据/输出像素、首像素RGB与数量、等待期间复位及恢复；mem和SD两时钟有相位差。
负对照：同一测试用修改前bmp_read，失败于sector requested before FIFO clear released（negative_old_bmp.log），证明测试可检出该顺序缺口。
run_stall_diagnostics.do：PASS，停滞状态码、七页冻结、AUTO响应及复位。
run_status_source.do：PASS，四个图号提交/不提前暴露/AUTO消抖开关。该历史测试未接两项诊断输入，3条端口连接警告不影响所检验状态路径。
同步器RTL仿真不证明亚稳态MTBF；未仿真完整TF/加密SDRAM/HDMI链路。

## 验收矩阵
|要求|证据|状态|
|ACK高低顺序及等待|正/负对照仿真|SIM PASS|
|首像素和连续加载/复位|握手仿真|SIM PASS（局部模型）|
|IMG/AUTO提交和诊断保留|两项回归|SIM PASS|
|视频延迟|相关模块未修改|STATIC unchanged|
|综合/布局布线/bit|manifest及原始报告|以报告为准|
|整机时序闭合|routed timing|尚不能宣称通过|
|K2短按/长按、K4与滚动实机稳定|等待用户板测|UNVERIFIED|

## 板测
使用独立命名bit，同一卡复位后先单次短按K2，再测长按、连续切图，最后K4轮播。若卡住，拍10秒数码管覆盖七页，重点D页reset_write是否还置位。即使暂时不卡，也需持续回归，不能以bitgen成功代替时序或板测通过。
旧正常动态bit、关闭滚动正常bit、精简滚动bit及前一诊断bit均不覆盖。
源码已在原.al引用路径内更新，无需手动添加新模块；GUI旧编译报告不代表当前源码结果。
