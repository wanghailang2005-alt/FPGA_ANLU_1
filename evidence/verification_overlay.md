# 固定文字 RGB 叠加验证记录

日期：2026-10-20，Asia/Shanghai。

## 结论与范围

osd_fixed_layout 与 osd_overlay：SIM PASS。ModelSim SE-64 2020.4 编译/正常仿真 0 errors、0 warnings，进程返回 0。沿用原有字库和选点模块，没有修改这两份源文件。

主工程未修改，尚未执行 TD 综合/实现、板测或 AXIS/HDMI 链路仿真。

## 逐拍检查

- 三帧 800×525 总时序，640×480 有效区，三帧依次 enable=1/0/1。
- 总检查数 1,260,016；有效输出像素 921,600，等于 3×640×480；白色文字像素共 868，两帧各 434。
- 正常结束时间 12,600,150 ns。100 MHz 为测试时钟，不能据此声称板级频率或帧率。
- 完整背景采用不等 R/G/B 和逐像素/逐帧变化的图案，不会与白色前景混淆。
- 独立参考模型按字符串序号、完整 64 位字形位移计算文字像素；逐拍比较整个 RGB/DE/HS/VS/X/Y 数据包。
- 覆盖字框 x=16～95、y=16～31、透明空格、字形空白、区域外背景、DE 无效时黑色、HS/VS 消隐和旁路恢复。
- 先在有效文字请求正在流水线内时异步复位，检查三级全部清空，再运行完整三帧。

## 延迟账本

| 阶段 | 字形路径 | 原图与控制路径 |
|---|---|---|
| 组合输入 | 位置范围、ASCII、字内坐标 | in_rgb/de/hs/vs/x/y |
| 寄存 1，采样沿 N 后 | 字库行与匹配 x | video_d1 |
| 寄存 2，N+1 沿后 | pixel_on 与 glyph_valid | video_d2 |
| 寄存 3，N+2 沿后 | 选择白字或对应背景并输出 | out_rgb/de/hs/vs/x/y |

旁路仍经过相同三级。输出字段之间的对应由三帧逐拍比较证明；与真实视频坐标、AXIS 和 HDMI 的对应尚待接入验证。

## 可视检查

`hello_fpga_crop.ppm` 是首帧实际 DUT 输出的 x=8～103、y=8～39 区域；`hello_fpga_preview.png` 为该数据的 6 倍最近邻放大。已查看预览，HELLO FPGA 完整、左右位序正确、空格透明，未见字框外背景被清黑。

## 复现

从 sim 目录执行 `vsim -c -do run_overlay.do`。正常日志保存于 modelsim_overlay.log，脚本检查最终 test_passed 标志后退出。

另执行 FORCE_FAIL 负向检查：2 ns 时故意 fatal，退出码 1，符合预期；对应日志为 modelsim_overlay_negative.log。
