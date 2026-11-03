onerror {quit -code 1 -force}
onbreak {resume}
vlib work
set h ../src/user_source/hdl_source
vlog $h/OSD/osd_overlay.v $h/OSD/osd_glyph_pixel.v $h/OSD/osd_font_rom.v
vlog -sv tb_captions_scroll.sv
vsim -voptargs=+acc -onfinish stop work.tb_captions_scroll
run -all
if {[examine -radix unsigned /tb_captions_scroll/test_pass] != 1} {quit -code 1 -force}
quit -code 0 -force
