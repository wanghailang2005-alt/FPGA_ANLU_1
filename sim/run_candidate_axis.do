onerror {quit -code 1 -force}
onbreak {resume}
file mkdir ../evidence
if {![info exists log_file]} {set log_file ../evidence/modelsim_axis_baseline.log}
if {![info exists axis_source]} {set axis_source ../../lab_ex5_i2s/src/user_source/hdl_source/video_rgb_to_axis_640x480.v}
transcript file $log_file
transcript on
if {[file exists work]} {vmap work work} else {vlib work; vmap work work}
vlog -work work $axis_source
vlog -sv -work work tb_candidate_axis.sv
vsim -voptargs=+acc -onfinish stop work.tb_candidate_axis
run -all
if {[examine -radix unsigned /tb_candidate_axis/test_passed] != 1} {quit -code 1 -force}
quit -code 0 -force
