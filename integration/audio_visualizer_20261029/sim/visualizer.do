onerror {quit -code 1 -force}
onbreak {resume}
if {![file exists vis_work]} {vlib vis_work}
set h ../user_source/hdl_source
vlog -work vis_work $h/AUDIO_VIS/audio_fft512.v $h/AUDIO_VIS/audio_visualizer.v $h/AUDIO_VIS/audio_visualizer_overlay.v $h/OSD/osd_glyph_pixel.v $h/OSD/osd_font_rom.v $h/hdmi_audio_tone_i2s_64fs.v $h/I2S_receiver.v $h/video_rgb_to_axis_640x480.v
vlog -work vis_work -sv tb_visualizer.sv
vsim -voptargs=+acc -onfinish stop vis_work.tb_visualizer
run -all
if {[examine -radix unsigned /tb_visualizer/test_pass] != 1} {quit -code 1 -force}
quit -code 0 -force
