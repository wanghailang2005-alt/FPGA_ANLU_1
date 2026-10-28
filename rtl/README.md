# OSD RTL

> 最新转场功能已获用户板测确认；优化补丁及独立自检源码见[集成入口](../integration/README.md)。


| 模块 | 职责 |
|---|---|
| osd_font_rom.v | 字符行位图；8×8字形纵向重复为8×16 |
| osd_glyph_pixel.v | 字符位图查询和取点 |
| osd_fixed_layout.v | 固定文字排版 |
| osd_status_layout.v | IMG/AUTO文字排版 |
| osd_overlay.v | OSD与可选WELCOME字幕叠加，RGB/同步等延迟 |
| osd_video_position.v | DE/VS恢复坐标，1拍 |
| osd_status_cdc.v | 状态邮箱，可合并中间状态，非事件队列 |

转场候选新增模块在[集成包rtl目录](../integration/transition_20261027/rtl/)，避免混淆候选与成功基线。

坐标恢复1拍、叠加3拍。接线时保持RGB、DE、HS、VS及坐标延迟一致。字形来源见[第三方声明](../THIRD_PARTY_NOTICES.md)。
