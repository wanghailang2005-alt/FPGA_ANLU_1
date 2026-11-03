onerror {quit -code 1 -force}
onbreak {resume}
if {![file exists work]} {vlib work}
set h ../src/user_source/hdl_source
vlog +incdir+$h/SD $h/OSD/osd_status_cdc.v $h/SD/frame_fifo_read.v $h/SD/video_timing_data.v $h/SD/color_bar.v
vlog -sv tb_cdc.sv
vsim -voptargs=+acc -onfinish stop work.tb_cdc
run -all
if {[examine -radix unsigned /tb_cdc/test_pass] != 1} {quit -code 1 -force}
quit -code 0 -force
