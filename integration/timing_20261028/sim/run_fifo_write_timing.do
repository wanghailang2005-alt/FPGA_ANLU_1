onerror {quit -code 1 -force}
transcript file fifo_write_timing.log
if {![file exists work]} {vlib work}
vmap work work
vlog ../../../../lab_ex5_i2s_osd_transition/src/user_source/hdl_source/SD/frame_fifo_write.v ../../../../lab_ex5_i2s_osd_transition/timing_opt_stage2_20261028/frame_fifo_write_reference.v
vlog -sv tb_fifo_write_timing.sv
vsim -voptargs=+acc -onfinish stop work.tb_fifo_write_timing
run -all
if {[examine -radix unsigned /tb_fifo_write_timing/test_passed] != 1} {quit -code 1 -force}
quit -code 0 -force
