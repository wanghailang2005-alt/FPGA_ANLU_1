# 滚动字幕候选版本（2026-10-25）

用户批准范围：底部黑色透明背景 WELCOME TO ANLU FPGA，保留 IMG/AUTO、视频延迟及原存储/音频逻辑，不生成 bit。

## 实现

- 修改 osd_overlay.v，工程副本与 osd_dev/rtl 副本 SHA256 一致。
- SCROLL_ENABLE 默认 1，可设为 0 恢复原字幕行为；STATUS_MODE 保持不变。
- 20 个字符，8×16 字模，宽 160 像素，y=448..463。
- 使用现有像素时钟；在消隐期 VS 下降沿计帧，每两帧移动 1 像素。位移 0..800，完全离屏后归零。不依赖 enable 计帧，因为顶层 enable 含逐像素 position_valid。
- 不增加视频寄存器：RGB/DE/HS/VS/X/Y 仍为 overlay 3 级，含坐标恢复和 AXIS 转换的既有总延迟仍为 5 级。
- 没有修改顶层、SD/FIFO/SDRAM、PLL、约束或 .al 文件；现有工程自动使用被修改的原源文件。

## 验证与限制

- 原 IMG/AUTO 回归：SIM PASS，4,620,016 次检查，覆盖图片编号、无效编号、AUTO、旁路、复位及三拍对齐。该测试显式禁用滚动以保留原参考模型。
- 新增滚动测试结果：SIM PASS，20,653,821 次检查，0 errors / 0 warnings。
- 新增 run_scroll_overlay.do / tb_scroll_overlay.sv：独立字符串/字模参考，逐像素检查完整滚动循环、左右裁剪、IMG/AUTO 同时显示、关闭字幕及复位。
- 扩展测试曾因旧 200ms 仿真时限超时；时限按新增扫描工作量调至 300ms，未为此修改 RTL。
- 本次未重新综合、布局布线或板测；原有时序违例仍待独立处理。仿真通过不代表整机时序通过。
- 已验证 bit OSD_DIAG_DYNAMIC_20261025.bit 未修改，SHA256 仍为 7de92fadbeb41deba367878660618af12e58bb202c72ff7908aed6606635e870；该 bit 不含本次滚动字幕，当前源代码属于新候选版本。

## 回退边界

只将 osd_overlay 的 SCROLL_ENABLE 设为 0 即可关闭新增滚动逻辑；原 IMG/AUTO 状态路径保留。不要用旧 bit 的板测结论代表本候选已经板测。