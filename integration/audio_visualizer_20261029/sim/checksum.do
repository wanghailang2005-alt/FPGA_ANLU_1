onerror {quit -code 1 -force}
onbreak {resume}
if {![file exists checksum_work]} {vlib checksum_work}
set h ../user_source/hdl_source
vlog -work checksum_work $h/ip/afifo_16_32_256.v $h/ip/afifo_32_16_256.v $h/SD/zoom_source_cache.v
vlog -work checksum_work -sv tb_checksum.sv
vsim -voptargs=+acc -onfinish stop checksum_work.tb_checksum
run -all
if {[examine -radix unsigned /tb_checksum/test_pass] != 1} {quit -code 1 -force}
quit -code 0 -force
