onerror {quit -code 1 -force}
onbreak {resume}
if {![file exists reset_work]} {vlib reset_work}
vlog -work reset_work -sv ../src/user_source/hdl_source/SD/scale_on_load.v tb_reset.sv
vsim -voptargs=+acc -onfinish stop reset_work.tb_reset
run -all
if {[examine -radix unsigned /tb_reset/test_pass] != 1} {quit -code 1 -force}
quit -code 0 -force
