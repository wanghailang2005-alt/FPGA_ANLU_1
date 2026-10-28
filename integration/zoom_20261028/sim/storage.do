onerror {quit -code 1 -force}
onbreak {resume}
if {![file exists work]} {vlib work}
set h ../src/user_source/hdl_source
vlog $h/ip/afifo_16_32_256.v $h/ip/afifo_32_16_256.v $h/SD/frame_fifo_write.v $h/SD/frame_fifo_read.v $h/SD/frame_read_write.v
vlog -sv tb_storage.sv
vsim -voptargs=+acc -onfinish stop work.tb_storage
run -all
if {[examine -radix unsigned /tb_storage/test_pass] != 1} {quit -code 1 -force}
quit -code 0 -force
