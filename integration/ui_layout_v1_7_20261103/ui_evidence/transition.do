onerror {quit -code 1 -force}
onbreak {resume}
vlog ../src/user_source/hdl_source/SD/image_transition.v
vlog -sv tb_transition_ui.sv
vsim -voptargs=+acc -onfinish stop work.tb_transition_ui
run -all
if {[examine -radix unsigned /tb_transition_ui/test_pass] != 1} {quit -code 1 -force}
quit -code 0 -force
