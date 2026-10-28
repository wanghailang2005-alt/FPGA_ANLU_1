# 独立SDRAM自检基准（未上板）

平台EG4S20BG256，沿用125MHz/180度及现有加密控制器。每轮8个256字块，地址覆盖多个bank/行及空间两端；写入后等待8192周期，再逐字比较地址与LFSR模式，记录累计错误和首错地址/期望/实际值，超时停止命令。

本目录只上传自研core/top和测试平台；厂商PLL、加密控制器、封装、数码管模块、IS42s32200参考模型及完整工程留在本地。RTL不能单独生成bit。

## 证据边界

- 最终自检域setup +1.405ns，hold +0.214ns；SDRAM接口仍为-6.699ns。见[evidence/timing_overview.txt](evidence/timing_overview.txt)。
- 官方APUG011提供的IS42s32200 -7模型默认tAC=5.5ns、tOH=2.5ns，2048返回中512个比较错误；[默认模型记录](evidence/timed_model.log)不是SIM PASS。它也不是内部EM638325的精确速度模型。
- 单独将仿真模型实例tOH扩至4.5ns，以隔离采样窗口问题后，自检逻辑逐字比较、单次错误注入、首错快照、复位和超时验证通过；[逻辑验证](evidence/functional_model.log)仅证明自检器逻辑，不证明器件时序。
- 观察器流水线使错误计数/快照晚2拍，与地址/数据同延迟；不改变存储接口。
- 基准bit已生成，未收到板测反馈；不同于已经板测通过的多媒体实验版。

本地完整工程路径见[工作区索引](../../docs/workspace_index_20261028.md)。完整bit哈希见[版本清单](../timing_20261028/versions.json)。
