onerror {quit -code 1 -force}
onbreak {resume}
vlib work
vlog ../src/user_source/hdl_source/SD/bmp_read.v
vlog -sv tb_five.sv
vsim -voptargs=+acc -onfinish stop work.tb_five
run -all
if {[examine -radix unsigned /tb_five/test_pass] != 1} {quit -code 1 -force}
quit -code 0 -force
