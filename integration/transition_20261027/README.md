# 2026-10-27 转场与OSD集成包

> 2026-10-28更新：这是历史恢复入口，最新板测及两批优化/异步分组实验见[最新集成记录](../timing_20261028/README.md)。下文“白屏/未上板/当前”等描述保留当时状态。


状态：三组SIM PASS，TD bitgen完成，GLOBAL SETUP FAIL。用户报告白屏且初始bit也白屏，原因未定位；本版未通过板测。详见[今日记录](../../docs/2026-10-27.md)和[按键规划](../../docs/按键与拨码规划.md)。

## 恢复集成改动

1. 准备与integration/current_baseline一致的OSD ACK_RELEASE完整候选工程；本仓库不包含厂商IP和完整原工程。
2. 复制该成功工程到独立目录，保留原工程。
3. 在复制的工程根目录运行`git apply --check transition_sources.patch`，通过后再应用；路径相对于工程根的src目录。此补丁是相对OSD成功基线，不能直接对原始官方工程或qiepin_src强制应用。
4. 将rtl/user_control.v复制到src/user_source/hdl_source/；rtl/image_transition.v复制到其SD/目录。将两文件添加至TD工程的综合及布局布线源列表，保留全部OSD源。
5. TD工程改为新位置，使用其自身源文件，勿引用旧目录。pin.adc补丁含K3与四位SW引脚；SDC、PLL与音频沿用OSD基线。
6. 仿真和重新构建后检查时序与板测，不能直接标记成功。

`transition_sources.patch`覆盖顶层、sd_card_bmp、frame_read_write、frame_fifo_read及pin.adc。新增状态位、跨域与忙状态见LOCAL_CANDIDATE_README.md。该文件是生成候选时的原始说明，其中“未烧录”是当时状态；后续白屏反馈以今日记录为准。

## 内容和证据

- rtl/：新增转场与K3/SW控制。
- sim/：本次3组测试；run.do依赖本仓库同级lab_ex5_i2s_osd_transition完整候选工程，复制原完整工程后才能运行控制器测试。
- evidence/simulation.log：三组实测仿真，均0 errors/0 warnings。
- evidence/evidence_syn.log、evidence_phy.log：TD构建记录。
- evidence/timing_summary.txt、timing_overview.txt、utilization.txt：实现后的时序与资源。
- evidence/build_manifest.json：候选源哈希与本地bit哈希；其source清单不代表厂商源码已上传。

仓库保留以前的成功基线，此目录是新增候选集成，不将白屏版本替换为“当前成功版”。
