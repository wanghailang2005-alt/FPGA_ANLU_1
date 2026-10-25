onerror {quit -code 1 -force}
onbreak {resume}
transcript file ../evidence/modelsim_storage_probe.log
transcript on
if {[file exists work]} {vmap work work} else {vlib work; vmap work work}
set h ../../lab_ex5_i2s_osd/src/user_source/hdl_source
vlog -work work $h/IP/afifo_16_32_256.v $h/IP/afifo_32_16_256.v $h/SD/frame_fifo_write.v $h/SD/frame_fifo_read.v $h/SD/frame_read_write.v
vlog -sv -work work tb_storage_probe.sv
vsim -voptargs=+acc -onfinish stop work.tb_storage_probe
run -all
if {[examine -radix unsigned /tb_storage_probe/test_passed] != 1} {quit -code 1 -force}
quit -code 0 -force
