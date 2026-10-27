onerror {quit -code 1 -force}
onbreak {resume}
transcript file simulation.log
if {![file exists work]} {vlib work}
vmap work work
set hdl ../../../../lab_ex5_i2s_osd_transition/src/user_source/hdl_source
vlog $hdl/SD/image_transition.v
vlog $hdl/OSD/osd_overlay.v $hdl/OSD/osd_status_layout.v $hdl/OSD/osd_fixed_layout.v $hdl/OSD/osd_glyph_pixel.v $hdl/OSD/osd_font_rom.v
vlog -sv tb_integrated.sv
vsim -voptargs=+acc -onfinish stop work.tb_integrated
run -all
if {[examine -radix unsigned /tb_integrated/test_passed] != 1} {quit -code 1 -force}
quit -sim
vlog $hdl/SD/sd_card_bmp.v $hdl/SD/bmp_read.v $hdl/SD/sd_card_top.v $hdl/SD/sd_card_cmd.v $hdl/SD/sd_card_sec_read_write.v $hdl/SD/spi_master.v
vlog -sv tb_control.sv
vsim -voptargs=+acc -onfinish stop work.tb_control
run -all
if {[examine -radix unsigned /tb_control/test_passed] != 1} {quit -code 1 -force}
quit -sim
vlog $hdl/OSD/osd_status_cdc.v $hdl/SD/frame_fifo_read.v
vlog -sv tb_transport.sv
vsim -voptargs=+acc -onfinish stop work.tb_transport
run -all
if {[examine -radix unsigned /tb_transport/test_passed] != 1} {quit -code 1 -force}
quit -code 0 -force
