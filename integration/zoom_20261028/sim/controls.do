onerror {quit -code 1 -force}
onbreak {resume}
if {![file exists ctrl_work]} {vlib ctrl_work}
vlog -work ctrl_work -sv ../src/user_source/hdl_source/user_control.v ../src/user_source/hdl_source/OSD/osd_status_cdc.v tb_controls.sv
vsim -voptargs=+acc -onfinish stop ctrl_work.tb_controls
run -all
if {[examine -radix unsigned /tb_controls/test_pass] != 1} {quit -code 1 -force}
quit -code 0 -force
