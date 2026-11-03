onerror {quit -code 1 -force}
onbreak {resume}
vlog ../src/user_source/hdl_source/SD/bmp_read.v
vlog -sv tb_ui_load.sv
vsim -voptargs=+acc -onfinish stop work.tb_zoom
run -all
if {[examine -radix unsigned /tb_zoom/test_pass] != 1} {quit -code 1 -force}
quit -code 0 -force
