
# ============================================================
# merged_top_tf_hdmi_audio.sdc
# 用于：TF 图片轮播 + HDMI(视频+音频) 整合工程
#
# 合并原则：
# 1) 保留 top.sdc 里的系统主时钟与 derive_clocks
# 2) 把 timing(2).sdc 里的 pixel/serial 时钟改成整合工程实际名字
# 3) 增加 hdmi_5x_clk / audio_mclk 的命名
# 4) 不再对内部 net 直接 create_clock，避免和 derive_clocks 重复
# ============================================================

# ------------------------------------------------------------
# 1. 板级输入主时钟
#    你的原 top.sdc 里 clk=50MHz，所以这里仍然用 20ns
# ------------------------------------------------------------
create_clock -name clk -period 20 -waveform {0 10} [get_ports {clk}]

# ------------------------------------------------------------
# 2. 自动推导 PLL 输出时钟
# ------------------------------------------------------------
derive_clocks

# ------------------------------------------------------------
# 3. 给关键 PLL 输出命名
#    下面这些路径是按你当前工程实例名写的：
#      sys_pll      -> sys_pll_m0
#      video_pll    -> video_pll_m0
#      音频 PLL     -> u_audio_pll
#
#    如果综合后实例路径略有不同，就按 Timing Analyzer 里的实际 pin 路径改。
# ------------------------------------------------------------
rename_clock -name {sd_card_clk} -source [get_ports {clk}] -master_clock {clk} [get_pins {sys_pll_m0/pll_inst.clkc[0]}]
rename_clock -name {ext_mem_clk} -source [get_ports {clk}] -master_clock {clk} [get_pins {sys_pll_m0/pll_inst.clkc[1]}]
rename_clock -name {video_clk}   -source [get_ports {clk}] -master_clock {clk} [get_pins {video_pll_m0/pll_inst.clkc[0]}]
rename_clock -name {hdmi_5x_clk} -source [get_ports {clk}] -master_clock {clk} [get_pins {video_pll_m0/pll_inst.clkc[1]}]
rename_clock -name {audio_mclk}  -source [get_ports {clk}] -master_clock {clk} [get_pins {u_audio_pll/pll_inst.clkc[2]}]

# USER-APPROVED EXPERIMENT ONLY: name the existing 125MHz/180-degree
# output and SUPPRESS analysis between it and ext_mem_clk. These clocks
# are physically related. This exception is not proof of timing closure.
rename_clock -name {ext_mem_clk_sft} -source [get_ports {clk}] -master_clock {clk} [get_pins {sys_pll_m0/pll_inst.clkc[2]}]
set_clock_groups -asynchronous \
    -group [get_clocks {ext_mem_clk}] \
    -group [get_clocks {ext_mem_clk_sft}]

# ------------------------------------------------------------
# 4. 从原 timing(2).sdc 迁移过来的 HDMI 像素/串行时钟约束
#
#    原文件是：
#      create_clock -name pixel_clk  ... [get_nets {S_pixel_clk}]
#      create_clock -name serial_clk ... [get_nets {S_serial_clk}]
#      set_clock_groups -exclusive ...
#
#    在整合工程里，这两个时钟已经由 video_pll 产生，并通过 derive_clocks 建出来了，
#    所以这里只保留“组关系”，不再重复 create_clock。
#
#    这里沿用原作者的写法，把 video_clk 和 hdmi_5x_clk 设成 exclusive。
#    如果后面 Timing Analyzer 明确显示两者之间需要做同步时序分析，再把这一条去掉。
# ------------------------------------------------------------
set_clock_groups -exclusive \
    -group [get_clocks {video_clk}] \
    -group [get_clocks {hdmi_5x_clk}]

# ------------------------------------------------------------
# 5. 音频 I2S 发生器/接收器跨域
#
#    audio_mclk 域里生成 I2S，video_clk 域里做三拍同步采样。
#    这类路径不是普通同步时序路径，直接切掉更合理。
# ------------------------------------------------------------
set_clock_groups -asynchronous \
    -group {audio_mclk} \
    -group {video_clk hdmi_5x_clk sd_card_clk ext_mem_clk}

# ------------------------------------------------------------
# 6. 可选：如果你的 frame_read_write 内部异步 FIFO 已经完全处理好了跨域，
#    且报告里总出现 video_clk / sd_card_clk / ext_mem_clk 之间的大量伪违例，
#    可以打开下面这组异步分组。
#
#    建议先不要开，先看报告；
#    只有确认这些跨域都只经过 FIFO / 同步器时再开。
# ------------------------------------------------------------
# set_clock_groups -asynchronous \
#     -group [get_clocks {sd_card_clk}] \
#     -group [get_clocks {ext_mem_clk}] \
#     -group [get_clocks {video_clk}] \
#     -group [get_clocks {hdmi_5x_clk}]

# ------------------------------------------------------------
# 7. 其余 Input/Output delay 先保持空白
#    你当前两个原始 sdc 也都没有写这部分。
# ------------------------------------------------------------

# BEGIN APPROVED BOUNDED CDC -- 2026-11-03
# TD SWUG200 3.11: -datapath_only bounds routing and automatically removes
# the meaningless inter-clock hold check. No synchronous pipeline is cut.
# Mailbox request/ACK uses two retained synchronizer registers. Payload is
# held from request until ACK returns; capture follows two destination edges.
# 8ns is at most one period of the fastest destination (125MHz).
set_max_delay -from [get_regs -nowarn {u_checksum_cdc/request}] -to [get_regs -nowarn {u_checksum_cdc/req_meta}] -datapath_only 8.000
set_max_delay -from [get_regs -nowarn {u_checksum_cdc/acknowledge}] -to [get_regs -nowarn {u_checksum_cdc/ack_meta}] -datapath_only 8.000
set_max_delay -from [get_regs -nowarn {u_checksum_cdc/held_data[*]}] -to [get_regs -nowarn {u_checksum_cdc/dst_data[*]}] -datapath_only 8.000
set_max_delay -from [get_regs -nowarn {u_memory_probe_cdc/request}] -to [get_regs -nowarn {u_memory_probe_cdc/req_meta}] -datapath_only 8.000
set_max_delay -from [get_regs -nowarn {u_memory_probe_cdc/acknowledge}] -to [get_regs -nowarn {u_memory_probe_cdc/ack_meta}] -datapath_only 8.000
set_max_delay -from [get_regs -nowarn {u_memory_probe_cdc/held_data[*]}] -to [get_regs -nowarn {u_memory_probe_cdc/dst_data[*]}] -datapath_only 8.000
set_max_delay -from [get_regs -nowarn {u_scale_mode_cdc/request}] -to [get_regs -nowarn {u_scale_mode_cdc/req_meta}] -datapath_only 8.000
set_max_delay -from [get_regs -nowarn {u_scale_mode_cdc/acknowledge}] -to [get_regs -nowarn {u_scale_mode_cdc/ack_meta}] -datapath_only 8.000
set_max_delay -from [get_regs -nowarn {u_scale_mode_cdc/held_data[*]}] -to [get_regs -nowarn {u_scale_mode_cdc/dst_data[*]}] -datapath_only 8.000
set_max_delay -from [get_regs -nowarn {u_music_control_cdc/request}] -to [get_regs -nowarn {u_music_control_cdc/req_meta}] -datapath_only 8.000
set_max_delay -from [get_regs -nowarn {u_music_control_cdc/acknowledge}] -to [get_regs -nowarn {u_music_control_cdc/ack_meta}] -datapath_only 8.000
set_max_delay -from [get_regs -nowarn {u_music_control_cdc/held_data[*]}] -to [get_regs -nowarn {u_music_control_cdc/dst_data[*]}] -datapath_only 8.000
set_max_delay -from [get_regs -nowarn {u_diag_sw_video/request}] -to [get_regs -nowarn {u_diag_sw_video/req_meta}] -datapath_only 8.000
set_max_delay -from [get_regs -nowarn {u_diag_sw_video/acknowledge}] -to [get_regs -nowarn {u_diag_sw_video/ack_meta}] -datapath_only 8.000
set_max_delay -from [get_regs -nowarn {u_diag_sw_video/held_data[*]}] -to [get_regs -nowarn {u_diag_sw_video/dst_data[*]}] -datapath_only 8.000
set_max_delay -from [get_regs -nowarn {u_osd_cfg_video/request}] -to [get_regs -nowarn {u_osd_cfg_video/req_meta}] -datapath_only 8.000
set_max_delay -from [get_regs -nowarn {u_osd_cfg_video/acknowledge}] -to [get_regs -nowarn {u_osd_cfg_video/ack_meta}] -datapath_only 8.000
set_max_delay -from [get_regs -nowarn {u_osd_cfg_video/held_data[*]}] -to [get_regs -nowarn {u_osd_cfg_video/dst_data[*]}] -datapath_only 8.000
set_max_delay -from [get_regs -nowarn {u_diag_source_sys/request}] -to [get_regs -nowarn {u_diag_source_sys/req_meta}] -datapath_only 8.000
set_max_delay -from [get_regs -nowarn {u_diag_source_sys/acknowledge}] -to [get_regs -nowarn {u_diag_source_sys/ack_meta}] -datapath_only 8.000
set_max_delay -from [get_regs -nowarn {u_diag_source_sys/held_data[*]}] -to [get_regs -nowarn {u_diag_source_sys/dst_data[*]}] -datapath_only 8.000
set_max_delay -from [get_regs -nowarn {u_diag_health_sys/request}] -to [get_regs -nowarn {u_diag_health_sys/req_meta}] -datapath_only 8.000
set_max_delay -from [get_regs -nowarn {u_diag_health_sys/acknowledge}] -to [get_regs -nowarn {u_diag_health_sys/ack_meta}] -datapath_only 8.000
set_max_delay -from [get_regs -nowarn {u_diag_health_sys/held_data[*]}] -to [get_regs -nowarn {u_diag_health_sys/dst_data[*]}] -datapath_only 8.000
set_max_delay -from [get_regs -nowarn {u_storage_probe_mem_sd/request}] -to [get_regs -nowarn {u_storage_probe_mem_sd/req_meta}] -datapath_only 8.000
set_max_delay -from [get_regs -nowarn {u_storage_probe_mem_sd/acknowledge}] -to [get_regs -nowarn {u_storage_probe_mem_sd/ack_meta}] -datapath_only 8.000
set_max_delay -from [get_regs -nowarn {u_storage_probe_mem_sd/held_data[*]}] -to [get_regs -nowarn {u_storage_probe_mem_sd/dst_data[*]}] -datapath_only 8.000
set_max_delay -from [get_regs -nowarn {u_status_sd_mem/request}] -to [get_regs -nowarn {u_status_sd_mem/req_meta}] -datapath_only 8.000
set_max_delay -from [get_regs -nowarn {u_status_sd_mem/acknowledge}] -to [get_regs -nowarn {u_status_sd_mem/ack_meta}] -datapath_only 8.000
set_max_delay -from [get_regs -nowarn {u_status_sd_mem/held_data[*]}] -to [get_regs -nowarn {u_status_sd_mem/dst_data[*]}] -datapath_only 8.000
set_max_delay -from [get_regs -nowarn {u_status_mem_pixel/request}] -to [get_regs -nowarn {u_status_mem_pixel/req_meta}] -datapath_only 8.000
set_max_delay -from [get_regs -nowarn {u_status_mem_pixel/acknowledge}] -to [get_regs -nowarn {u_status_mem_pixel/ack_meta}] -datapath_only 8.000
set_max_delay -from [get_regs -nowarn {u_status_mem_pixel/held_data[*]}] -to [get_regs -nowarn {u_status_mem_pixel/dst_data[*]}] -datapath_only 8.000
set_max_delay -from [get_regs -nowarn {u_diag_legacy_sys/request}] -to [get_regs -nowarn {u_diag_legacy_sys/req_meta}] -datapath_only 8.000
set_max_delay -from [get_regs -nowarn {u_diag_legacy_sys/acknowledge}] -to [get_regs -nowarn {u_diag_legacy_sys/ack_meta}] -datapath_only 8.000
set_max_delay -from [get_regs -nowarn {u_diag_legacy_sys/held_data[*]}] -to [get_regs -nowarn {u_diag_legacy_sys/dst_data[*]}] -datapath_only 8.000
# Held frame request and return ACK, each synchronized before use.
set_max_delay -from [get_clocks {video_clk}] -to [get_regs -nowarn {frame_read_write_m0/frame_fifo_read_m0/read_req_d0}] -datapath_only 8.000
set_max_delay -from [get_clocks {ext_mem_clk}] -to [get_regs -nowarn {video_timing_data_m0/ack_meta}] -datapath_only 8.000
# Persistent generation toggles. Only the first synchronizer stage is bounded.
set_max_delay -from [get_clocks {video_clk}] -to [get_regs -nowarn {sd_card_bmp_m0/dark_sync[0] sd_card_bmp_m0/done_sync[0]}] -datapath_only 8.000
set_max_delay -from [get_clocks {sd_card_clk}] -to [get_regs -nowarn {u_image_transition/req_sync[0] u_image_transition/commit_sync[0]}] -datapath_only 8.000
# END APPROVED BOUNDED CDC
