# OSD、动态字幕与切图集成候选版

2026-10-27，按用户要求集成；未烧录。两份原成功工程均保留。

## 入口与行为

- 工程：`src/td_project/HDMI1.4b_Transmitter_v1.0.al`
- 候选下载文件：`OSD_TRANSITION_20261027.bit`
- 平台：EG4S20BG256，TD 6.2.168116。
- 基线：OSD工程中已上板成功的ACK_RELEASE源码，保留BMP读取和写ACK释放修复。
- 视频链路：SDRAM → video_delay → image_transition → OSD坐标恢复 → OSD/动态字幕 → RGB-to-AXIS → HDMI。

转场作用于图片，IMG/AUTO与WELCOME字幕继续绘制和滚动。沿用黑色字形，黑场时黑字不可见；背景恢复后可观察字幕继续移动。未新增文字模式、速度、方向控制和转场参数OSD。

## 按键

| 操作 | 功能 |
|---|---|
| K1 | 复位；默认直接切换、中等时长 |
| K2 | 下一张；加载/转场忙时忽略、不排队；沿用OSD基线，不主动关闭轮播 |
| K4 | 自动轮播启停，至少两张有效图片 |
| SW4..SW1=0100，按K3 | 直接切换→淡出淡入→滑动揭幕 |
| SW4..SW1=0101，按K3 | 短15→中30→长60帧；默认中，第一次按进入长 |
| 其他SW编码，按K3 | 无操作；不改变现有OSD与字幕 |

SW只选设置项，拨动本身不改参数。新增引脚：K3=B1，SW1=C8、SW2=C7、SW3=C6、SW4=C5，沿用切图源码的上拨为1定义，物理方向需板测。

淡入淡出为旧图→黑→新图；滑动为黑幕遮盖/揭开，非双图推移。帧数是单段时长，总体约两倍再加缓存等待。请求时锁存效果和时长，途中修改只影响下一次转场。

## 集成修改

复制切图的user_control和image_transition，合并SD控制器的request/dark/commit握手。新图提交generation随缓存地址和图片标签，通过既有邮箱到内存域，在实际读帧S_ACK锁存后送往像素域，DE=0时接受，避免读帧尚未选择新图就开始淡入。

状态总线8→9位：`{generation,AUTO,valid,bank[1:0],tag1[1:0],tag0[1:0]}`；读帧状态4→5位：`{generation,AUTO,valid,image_index[1:0]}`。新增done toggle，完整转场结束后才允许下一次加载。修正滑动横坐标首像素重复计0问题。

延迟：转场0拍，坐标恢复1拍，OSD叠加3拍，RGB-to-AXIS1拍；像素通路RGB/DE/HS/VS保持同延迟。沿用OSD的时钟、复位、PLL、音频、SDC及加密IP。

## 验证

| 项目 | 证据 | 结果 |
|---|---|---|
| 三模式、三档精确帧数、延迟提交、结束/复位 | sim/tb_integrated.sv；sim/simulation.log | SIM PASS |
| OSD与背景像素/DE对齐，滚动相位连续 | 同上，545297有效像素，22586字形点 | SIM PASS |
| 首图、4次提交、延迟dark/done、忙时K2、复位 | sim/tb_control.sv | SIM PASS，BMP完成边界注入 |
| 地址/图号/generation跨域与帧锁存 | sim/tb_transport.sv，18次检查 | SIM PASS |
| TD顶层综合 | evidence_syn.log | SYNTH PASS，含厂商/基线警告 |
| 布局布线、bit生成 | evidence_phy.log；Runs | 完成 |
| 全局setup | SWNS -6.699ns，STNS -342.719ns | FAIL |
| 全局hold | HWNS +0.011ns，HTNS 0 | PASS |
| video_clk 25MHz | Clock Summary SWNS +3.763ns，域内SWNS +10.432ns | 正裕量 |
| STA覆盖 | 95.14% | 非全覆盖 |
| 资源 | LUT5479，REG4627，BRAM9K20，DSP3，PLL3 | 可放入器件 |
| TF/SDRAM/HDMI/音频联合板测 | 未执行 | UNVERIFIED |

原OSD成功基线setup同样SWNS -6.699ns，TNS -312.086ns。本版TNS增加，sd_card_clk、ext_mem_clk和clk等仍有负裕量，不能标记整机时序通过；没有放宽约束隐藏违例。仿真是模块与控制边界验证，不替代真实TF卡和硬件验收。

## 上板顺序

1. 使用原来成功的TF卡和浅色背景图片，下载本目录命名bit，检查IMG/AUTO/WELCOME和音频。
2. 默认直接切换下按K2，核对图号与画面。
3. SW=0100按K3一次，再按K2测试淡出淡入；再按K3，按K2测试滑动。
4. SW=0101轮换长、短、中；转场中再次按K2应忽略。观察字幕恢复后仍在继续滚动。
5. K4开启轮播，连续观察多轮；途中改效果应下一次生效，关闭轮播后当前操作完成再停。
6. 测试复位，记录bit SHA256及所有异常。尚未执行的项目不能记为BOARD PASS。

回退直接使用原lab_ex5_i2s_osd工程及已验证bit。

重跑仿真：sim目录执行`vsim -c -do run.do`。TD可从本候选.al重新综合和实现。
