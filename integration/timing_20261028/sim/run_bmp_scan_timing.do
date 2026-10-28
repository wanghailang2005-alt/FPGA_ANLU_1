onerror {quit -code 1 -force}
transcript file bmp_scan_timing.log
if {![file exists work]} {vlib work}
vmap work work
vlog ../../../../lab_ex5_i2s_osd_transition/src/user_source/hdl_source/SD/bmp_read.v
vlog -sv tb_bmp_scan_timing.sv
vsim -voptargs=+acc -onfinish stop work.tb_bmp_scan_timing
run -all
if {[examine -radix unsigned /tb_bmp_scan_timing/test_passed] != 1} {quit -code 1 -force}
quit -code 0 -force
