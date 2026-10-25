onerror {quit -code 1 -force}
onbreak {resume}
transcript file ../evidence/modelsim_status_source.log
transcript on
if {[file exists work]} {vmap work work} else {vlib work; vmap work work}
set sd ../../lab_ex5_i2s_osd/src/user_source/hdl_source/SD
vlog -work work $sd/sd_card_bmp.v $sd/bmp_read.v $sd/sd_card_top.v $sd/sd_card_cmd.v $sd/sd_card_sec_read_write.v $sd/spi_master.v
vlog -sv -work work tb_status_source.sv
vsim -voptargs=+acc -onfinish stop work.tb_status_source
run -all
if {[examine -radix unsigned /tb_status_source/test_passed] != 1} {quit -code 1 -force}
quit -code 0 -force
