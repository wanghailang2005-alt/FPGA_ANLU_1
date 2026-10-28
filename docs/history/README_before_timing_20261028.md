# 时序更新前的首页（历史）

以下保留当时状态，当前请看[首页](../../README.md)。

# FPGA_ANLU_1

基于安路 EG4S20 / HX4S20 开发板的 HDMI 图片播放扩展项目，记录 OSD、动态字幕、图片转场和后续缩放功能的开发与验证。

## 先看这里

| 你要找的内容 | 入口 |
|---|---|
| 按键、拨码与短中长时间 | [统一按键规划](../../docs/按键与拨码规划.md) |
| OSD与动态字幕历史成功版 | [成功基线、补丁和精确哈希](../../integration/current_baseline/README.md) |
| OSD＋转场最新集成候选 | [10月27日集成包](../../integration/transition_20261027/README.md) |
| 最新测试及白屏反馈 | [10月27日工作记录](../../docs/2026-10-27.md) |
| 所有文档 | [文档目录](../../docs/README.md) |

## 项目状态

| 版本/功能 | 已有证据 | 当前边界 |
|---|---|---|
| IMG/AUTO、WELCOME字幕、写ACK释放修复 | 10月25日用户报告板测正常 | 历史成功基线，整机setup未闭合 |
| 淡入淡出、滑动揭幕与OSD集成 | 三组仿真通过；TD综合、布局布线及bit生成完成 | 全局setup WNS −6.699ns；集成未通过板测 |
| 当前板上白屏 | 用户反馈集成版白屏，初始bit也白屏 | 原因未定位，不能归因于温度或集成代码 |
| OSD参数控制、滑动方向、图片缩放 | [统一规划](../../docs/按键与拨码规划.md) | 尚未完整接入，不作为已完成功能 |

10月28日只整理仓库和更名，没有修改RTL、重建bit或新增板测结论。

## 目录

```text
rtl/                         OSD、字库、坐标及状态跨域模块
sim/                         OSD测试与ModelSim入口
integration/
  current_baseline/          历史成功版补丁及哈希
  transition_20261027/       转场候选：新增RTL、补丁、仿真和证据
docs/                        按键规划、日期记录、工作区资料索引
  history/                   原首页，保留早期实现细节
evidence/                    OSD历史仿真、诊断、时序和资源证据
```

目录入口：[RTL](../../rtl/README.md) · [仿真](../../sim/README.md) · [集成](../../integration/README.md) · [验证证据](../../evidence/README.md)。

## 使用方式

1. 查阅[按键规划](../../docs/按键与拨码规划.md)，区分已实现项和预留项。
2. 使用OSD成功版时，从[current_baseline](../../integration/current_baseline/README.md)核对补丁和bit哈希；集成候选按[转场接入说明](../../integration/transition_20261027/README.md)操作。
3. 在sim目录执行相应run_*.do；测试依赖见[仿真索引](../../sim/README.md)。
4. 构建、时序和板测分别记录，不以bitgen完成代替硬件验收。

本仓库提供自研RTL、补丁、测试和记录。完整厂商工程、加密IP、bit与编译缓存保留本地；仅克隆仓库不能独立生成整机bit。

## 来源与历史

字形来源见[第三方声明](../../THIRD_PARTY_NOTICES.md)和[上游许可](../../LICENSE.FPGA-text-overlay)。早期细节保留于[旧首页](../../docs/history/README_before_20261028.md)。本次整理见[10月28日记录](../../docs/2026-10-28.md)。
