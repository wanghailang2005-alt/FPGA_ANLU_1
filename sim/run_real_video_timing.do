onerror {quit -code 1 -force}
onbreak {resume}
file mkdir ../evidence
if {![info exists log_file]} {set log_file ../evidence/modelsim_real_video_timing.log}
transcript file $log_file
transcript on
if {[file exists work]} {vmap work work} else {vlib work; vmap work work}
set candidate ../../lab_ex5_i2s_osd/src/user_source/hdl_source
vlog -work work +incdir+$candidate/SD $candidate/SD/color_bar.v $candidate/SD/video_timing_data.v $candidate/SD/video_delay.v
vlog -work work $candidate/OSD/osd_font_rom.v $candidate/OSD/osd_glyph_pixel.v $candidate/OSD/osd_fixed_layout.v $candidate/OSD/osd_overlay.v $candidate/OSD/osd_video_position.v $candidate/video_rgb_to_axis_640x480.v
vlog -sv +incdir+../integration -work work tb_real_video_timing.sv
if {[info exists negative_test]} {
    vsim -voptargs=+acc -onfinish stop work.tb_real_video_timing +NO_OSD
} else {
    vsim -voptargs=+acc -onfinish stop work.tb_real_video_timing
}
run -all
if {[examine -radix unsigned /tb_real_video_timing/test_passed] != 1} {quit -code 1 -force}
quit -code 0 -force
