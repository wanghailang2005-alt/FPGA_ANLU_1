onerror {quit -code 1 -force}
onbreak {resume}
if {![file exists drain_work]} {vlib drain_work}
set h ../src/user_source/hdl_source
vlog -work drain_work $h/ip/afifo_16_32_256.v $h/ip/afifo_32_16_256.v
vlog -work drain_work -sv $h/SD/frame_fifo_write.v $h/SD/frame_fifo_read.v $h/SD/frame_read_write.v tb_dma_drain.sv
vsim -voptargs=+acc=r+/tb_dma_drain -onfinish stop drain_work.tb_dma_drain
run -all
if {[examine -radix unsigned /tb_dma_drain/test_pass] != 1} {quit -code 1 -force}
quit -code 0 -force
