onerror {quit -code 1 -force}
onbreak {resume}
if {![file exists display_work]} {vlib display_work}
set h ../src/user_source/hdl_source
vlog -work display_work $h/zoom_diagnostics.v $h/OSD/osd_video_position.v $h/OSD/osd_overlay.v $h/OSD/osd_status_layout.v $h/OSD/osd_fixed_layout.v $h/OSD/osd_glyph_pixel.v $h/OSD/osd_font_rom.v
vlog -work display_work -sv tb_display.sv
vsim -voptargs=+acc -onfinish stop display_work.tb_display
run -all
if {[examine -radix unsigned /tb_display/test_pass] != 1} {quit -code 1 -force}
quit -code 0 -force
