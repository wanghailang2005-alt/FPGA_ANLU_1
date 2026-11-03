# 缓存校验版工程恢复记录

> 本记录中的未带链接的相对路径以 `zoom_animation` 工程根目录为准。

2026-10-29 用户反馈：烧录 `ZOOM_CACHE_CHECK_20261029.bit`，测试缩放全部正常。反馈没有指定此次测试的图片和奇数宽覆盖范围，保留此前奇数宽噪点记录。

`src/td_project/HDMI1.4b_Transmitter_v1.0.al` 是工程描述文件，不能用 bit 内容覆盖。该文件原本引用同目录 user_source；已把缓存源码和顶层恢复为 `evidence/cache_checksum_20261029` 的当时快照，并恢复 phy seed 3。其他 user_source 与该 bit 构建时的修复 1 清单一致。59 个 .al 源条目路径均存在。行尾诊断版仍保留在 `evidence/cache_tail_diag_20261029` 和独立 bit 文件中。

已重新综合、布局布线并生成 bit，约束内 setup +0.133ns、hold +0.019ns；重建 bit 的 SHA256 为 `990bde25c97536d754976aee7d0c35fd68dfaf3d52bd5c2af26f5ce083d5306c`，与用户板测 bit 的哈希不同，不能声称二者字节一致或该重建 bit 已上板。重建产物保存为 `evidence/cache_checksum_20261029/rebuilt_20261029.bit`。为了让工程运行目录的下载文件直接指向用户已测文件，已将原始 `ZOOM_CACHE_CHECK_20261029.bit` 复制到 `src/td_project/HDMI1.4b_Transmitter_v1.0_Runs/phy_1/HDMI1.4b_Transmitter_v1.0.bit`，其 SHA256 与原始文件均为 `da74acbd3af8562dda6edd2f543da5e8bf524d128f9a8c1942c5a97c75ff8176`。最新运行报告描述的是重建结果，不是对复制后的原 bit 的重新分析；此前原 bit 的实现日志和 summary 在证据目录。以后重新运行 TD 会生成新的 bit，需要重新确认哈希并上板测试。

原相关 SDRAM 时钟例外仍保留，约束内通过不表示完整接口时序闭合。
