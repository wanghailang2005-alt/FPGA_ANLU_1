onerror {quit -code 1 -force}
onbreak {resume}
set h ../src/user_source/hdl_source
vlog $h/hdmi_audio_tone_i2s_64fs.v $h/I2S_receiver.v $h/video_rgb_to_axis_640x480.v
vlog -sv tb_ui_scene.sv
vsim -voptargs=+acc -onfinish stop work.tb_scene
run -all
if {[examine -radix unsigned /tb_scene/test_pass] != 1} {quit -code 1 -force}
quit -code 0 -force
