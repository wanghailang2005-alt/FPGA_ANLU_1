onerror {quit -code 1 -force}
onbreak {resume}
vlog -sv tb_ui_cached.sv
vsim -voptargs=+acc -onfinish stop work.tb_cached
run -all
if {[examine -radix unsigned /tb_cached/test_pass] != 1} {quit -code 1 -force}
quit -code 0 -force
