# 滚动版切图回归只读诊断 — 2026-10-25

## 版本与证据

- 用户确认同卡测试 OSD_DIAG_DYNAMIC_20261025.bit 完全正常；SHA256 7de92fadbeb41deba367878660618af12e58bb202c72ff7908aed6606635e870。
- 用户烧录 best_result/HDMI1.4b_Transmitter_v1.0.bit，SHA256 4df845fc94384141eaca09ca666d67691ecf43c34d8aeae08db17db8193cb774，与 phy_1 的 bit 完全相同，时间 16:43:11。
- 当前 top_tf_hdmi_audio.v、sd_card_bmp.v、frame_fifo_read.v、frame_read_write.v 与成功动态构建清单四项哈希全部一致。该清单没有覆盖全部工程文件，不能据此宣称整个工程仅一个文件不同。
- 当前 osd_overlay.v 的滚动输出只接到图像叠加；没有发现对 SD、FIFO、写完成控制的直接反馈。静态无反馈不能排除布局布线影响。

## 状态码重新解释

4B0006：源像素计数 0x4B000=307200，状态6=源结束但仍等待存储提交。
FC9CC6：flags=0xFC9CC，状态6。冻结快照解码：load_busy=1，source_done_seen=1，write_done_seen=0，write_finish_pulse=0，bmp_ready=1，write_req=0，write_req_ack=0，sd_init_done=1，load_idx=3，disp_buf_idx=0，wrfin_sync[2:1]=11，next_req_pending=0，auto_play_en=0。这是冻结时状态，不代表当前按键或 AUTO 值。

此前说“图片像素已送入 FIFO”不够严谨：计数器只计 bmp_data_wr_en，且到307200后饱和。它不检查 FIFO 接收、溢出或清零状态，不能证明307200个字实际被FIFO接受。

## 实际路径

bmp_data_wr_en -> write_buf.we -> App_wr_en 读 FIFO -> frame_fifo_write.write_cnt -> S_END -> frame_write_finish -> mem 域 toggle -> SD 域三级同步 -> write_done_seen -> 提交显示缓冲区。

静态风险：
- write_buf 的 full_flag、empty_flag 未连接到监测或控制，wrusedw 未导出。
- frame_fifo_write 的 into_burst 依赖 write_cnt+rdusedw；如源停止时仍缺尾部数据，最后一组可能永远不启动。
- ACK 在 SD 域没有返回同步，且读图仅等ACK高，未明确等FIFO清零撤销；这是已存在问题，尚无证据确认是本次回归根因。
- 完成通知已使用 toggle 和三级同步，不是直接跨域的单拍脉冲。冻结时同步末两级均为1，不足以证明通知没有产生或丢失。

## 新旧时序

正常旧版仅保存有 summary 与构建日志；未找到可确认与该次成功动态构建一一对应的完整 routed 路径报告。因此不把旧固定版/更早动态版详细路径冒充该次成功动态版的路径。

旧版：setup WNS -6.699ns / TNS -404.416ns；hold WNS +0.003ns。
新版：setup WNS -6.699ns / TNS -377.890ns；hold WNS +0.019ns。
新版 video->video WNS +20.598ns，ext_mem->sd_card WNS -1.832ns（63端点），ext_mem->SDRAM移相时钟 WNS -2.859ns（32端点），反向 WNS -6.699ns（32端点）。新版未出现 mem->mem setup 违例。

总TNS改善但板测反而失败，说明不能凭总分识别故障，也不能声称新增字幕让所有存储路径更差。

## 下一步修改计划（待批准）

最小对照：仅关闭原工程 overlay 的 SCROLL_ENABLE 默认值；保留滚动代码、其他源文件、时钟、约束与工程配置；单独保存诊断 bit 和源码哈希，不覆盖已验证 bit；用户同卡测试 K2/K4。该实验区分“启用滚动的实现”与“当前其他工程状态”，不能独立区分滚动RTL功能错误和布局布线敏感性。

若仍不能定位，再提出单独的观测方案：在 mem 域冻结写状态、write_cnt、FIFO rdusedw 与完成 toggle，并在写域锁存 FIFO 溢出/清零期间写入。跨域快照须用握手同步，不能直接把多位状态接数码管。本轮不实施，也不提前假定需要修哪个模块。

本轮无 RTL、约束、IP、项目元数据修改，无构建或烧录；结论为诊断进展，根因未确认。