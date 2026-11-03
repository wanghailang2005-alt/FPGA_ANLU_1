onerror {quit -code 1 -force}
onbreak {resume}
if {![file exists work]} {vlib work}
vlog ../src/user_source/hdl_source/user_control.v
vlog -sv tb_control_keys.sv
vsim -voptargs=+acc -onfinish stop work.tb_control_keys
run -all
if {[examine -radix unsigned /tb_control_keys/test_pass] != 1} {quit -code 1 -force}
quit -code 0 -force
