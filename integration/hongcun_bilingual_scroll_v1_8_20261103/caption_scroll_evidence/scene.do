onerror {quit -code 1 -force}
onbreak {resume}
set h ../src/user_source/hdl_source
vlog $h/OSD/osd_overlay.v $h/OSD/osd_font_rom.v $h/OSD/osd_glyph_pixel.v $h/AUDIO_VIS/audio_fft512.v $h/AUDIO_VIS/audio_visualizer.v $h/AUDIO_VIS/audio_spectrum_overlay.v $h/hdmi_audio_tone_i2s_64fs.v $h/I2S_receiver.v $h/video_rgb_to_axis_640x480.v
vlog -sv tb_scene.sv
vsim -voptargs=+acc -onfinish stop work.tb_scene
run -all
if {[examine -radix unsigned /tb_scene/test_pass] != 1} {quit -code 1 -force}
quit -code 0 -force
