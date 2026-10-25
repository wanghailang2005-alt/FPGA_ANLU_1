onerror {quit -code 1 -force}
onbreak {resume}
transcript file ../evidence/modelsim_status_transport.log
transcript on
if {[file exists work]} {vmap work work} else {vlib work; vmap work work}
vlog -work work ../rtl/osd_status_cdc.v ../../lab_ex5_i2s_osd/src/user_source/hdl_source/SD/frame_fifo_read.v
vlog -sv -work work tb_status_transport.sv
vsim -voptargs=+acc -onfinish stop work.tb_status_transport
run -all
if {[examine -radix unsigned /tb_status_transport/test_passed] != 1} {quit -code 1 -force}
quit -code 0 -force
