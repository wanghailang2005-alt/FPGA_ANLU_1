onerror {quit -code 1 -force}
onbreak {resume}
file mkdir ../evidence
if {![info exists log_file]} {set log_file ../evidence/modelsim_candidate_video.log}
if {![info exists axis_source]} {set axis_source ../../lab_ex5_i2s_osd/src/user_source/hdl_source/video_rgb_to_axis_640x480.v}
transcript file $log_file
transcript on
if {[file exists work]} {vmap work work} else {vlib work; vmap work work}
vlog -work work ../rtl/osd_font_rom.v ../rtl/osd_glyph_pixel.v ../rtl/osd_fixed_layout.v ../rtl/osd_overlay.v ../rtl/osd_video_position.v
vlog -work work $axis_source
vlog -sv +incdir+../integration -work work tb_candidate_video.sv
vsim -voptargs=+acc -onfinish stop work.tb_candidate_video
run -all
if {[examine -radix unsigned /tb_candidate_video/test_passed] != 1} {quit -code 1 -force}
quit -code 0 -force
