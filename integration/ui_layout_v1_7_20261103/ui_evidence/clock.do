onerror {quit -code 1 -force}
onbreak {resume}
vlog -sv tb_clock_ui.sv
vsim -voptargs=+acc -onfinish stop work.tb_clock_ui
run -all
if {[examine -radix unsigned /tb_clock_ui/test_pass] != 1} {quit -code 1 -force}
quit -code 0 -force
