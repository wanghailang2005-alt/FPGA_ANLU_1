onerror {quit -code 1 -force}
onbreak {resume}
vlog ../src/user_source/hdl_source/SD/frame_fifo_read.v
vlog -sv tb_metadata.sv
vsim -voptargs=+acc -onfinish stop work.tb_metadata
run -all
if {[examine -radix unsigned /tb_metadata/test_pass] != 1} {quit -code 1 -force}
quit -code 0 -force
