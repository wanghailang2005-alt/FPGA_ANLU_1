onerror {quit -code 1 -force}
onbreak {resume}
if {![file exists checksum_odd_work]} {vlib checksum_odd_work}
set h ../src/user_source/hdl_source
vlog -work checksum_odd_work +incdir+$h/SD $h/ip/afifo_16_32_256.v $h/ip/afifo_32_16_256.v $h/OSD/osd_status_cdc.v $h/SD/color_bar.v $h/SD/video_timing_data.v $h/SD/video_delay.v $h/SD/image_transition.v
vlog -work checksum_odd_work -sv $h/SD/scale_on_load.v $h/SD/zoom_cached_scaler.v $h/SD/zoom_source_cache.v $h/SD/zoom_animation.v $h/SD/bmp_read.v $h/SD/sd_card_bmp.v $h/SD/frame_fifo_write.v $h/SD/frame_fifo_read.v $h/SD/frame_read_write.v tb_checksum_odd.sv sd_model.sv
vsim -voptargs=+acc=r+/tb_system -onfinish stop checksum_odd_work.tb_system
run -all
if {[examine -radix unsigned /tb_system/test_pass] != 1} {quit -code 1 -force}
quit -code 0 -force
