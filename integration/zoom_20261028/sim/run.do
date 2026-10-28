onerror {quit -code 1 -force}
onbreak {resume}
if {![file exists work]} {vlib work}
vlog -sv ../src/user_source/hdl_source/SD/scale_on_load.v ../src/user_source/hdl_source/SD/bmp_read.v tb_zoom.sv
vsim -voptargs=+acc -onfinish stop work.tb_zoom
run -all
if {[examine -radix unsigned /tb_zoom/test_pass] != 1} {quit -code 1 -force}
quit -code 0 -force
