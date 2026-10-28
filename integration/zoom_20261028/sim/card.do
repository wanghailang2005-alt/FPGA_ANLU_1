onerror {quit -code 1 -force}
onbreak {resume}
if {![file exists card_work]} {vlib card_work}
vlog -work card_work -sv ../src/user_source/hdl_source/SD/scale_on_load.v ../src/user_source/hdl_source/SD/bmp_read.v ../src/user_source/hdl_source/SD/sd_card_bmp.v tb_card.sv
vsim -voptargs=+acc -onfinish stop card_work.tb_card
run -all
if {[examine -radix unsigned /tb_card/test_pass] != 1} {quit -code 1 -force}
quit -code 0 -force
