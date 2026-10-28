# 当前可用基线：滚动字幕 + IMG/AUTO + ACK释放握手

> 2026-10-28更新：这是历史恢复入口，最新板测及两批优化/异步分组实验见[最新集成记录](../timing_20261028/README.md)。下文“白屏/未上板/当前”等描述保留当时状态。


2026-10-25用户报告板测正常；精确bit哈希、当前源码哈希和timing见 [selection.json](selection.json)。这不是时序闭合版本。

## 文件与恢复方式

- `current_sources.patch`：相对于本地原始 `lab_ex5_i2s/src/user_source/hdl_source` 的七个文件改动，包含顶层、动态状态/诊断、读写标签、ACK修复及既有AXIS对齐修正。
- 仓库 `rtl/*.v`：把这些OSD文件放到候选工程 `src/user_source/hdl_source/OSD/`。
- 补丁在复制好的候选工程根目录应用：先 `git apply --check current_sources.patch`，检查通过后再应用。若原参考代码已有同学改动，必须逐项合并，不能强制覆盖。
- TD工程须包含全部OSD RTL。现有本地原.al已经包含，打开即可；全新移植则按已有integration说明配置工程源列表，勿套用过期固定版配置。
- 本仓库不包含厂商IP和完整原始参考工程，因此只克隆仓库不能独立生成整机bit。测试中引用`../../lab_ex5_i2s_osd`的入口需要同级候选工程。
- 当前保留七页诊断，不属于无诊断发布版；不擅自移除，以免改变本次板测基线。

## 版本选择

使用本地命名文件 `OSD_FIX_ACK_RELEASE_20261025_181945.bit`。
不要使用 `Runs/best_result/HDMI1.4b_Transmitter_v1.0.bit`：它仍是旧滚动故障版本。
成功bit没有上传；本地完整归档和SHA256见工作区archives目录。

完整测试与局限见 [当日记录](../../docs/2026-10-25.md)。以下旧脚本/旧patch仍作为历史材料保留，不能代替本目录当前补丁。
