onerror {quit -code 1 -force}
onbreak {resume}
if {![file exists cache_work]} {vlib cache_work}
set h ../user_source/hdl_source
vlog -work cache_work $h/ip/afifo_16_32_256.v $h/ip/afifo_32_16_256.v
vlog -work cache_work -sv $h/SD/zoom_source_cache.v tb_cache.sv
vsim -voptargs=+acc=r+/tb_cache -onfinish stop cache_work.tb_cache
run -all
if {[examine -radix unsigned /tb_cache/test_pass] != 1} {quit -code 1 -force}
quit -code 0 -force

