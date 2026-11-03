onerror {quit -code 1 -force}
onbreak {resume}
if {![file exists work]} {vlib work}
set h ../src/user_source/hdl_source
vlog $h/OSD/osd_status_cdc.v $h/AUDIO_MUSIC/tf_music_player.v $h/AUDIO_MUSIC/sd_music_arbiter.v $h/I2S_receiver.v
vlog -sv tb_music.sv
vsim -gREAL_PCM=1 -voptargs=+acc -onfinish stop work.tb_music
run -all
if {[examine -radix unsigned /tb_music/test_pass] != 1} {quit -code 1 -force}
quit -code 0 -force
