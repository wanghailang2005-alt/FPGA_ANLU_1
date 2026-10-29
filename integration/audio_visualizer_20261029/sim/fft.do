onerror {quit -code 1 -force}
onbreak {resume}
if {![file exists work]} {vlib work}
set h ../user_source/hdl_source
vlog -work work $h/AUDIO_VIS/audio_fft512.v
vlog -work work -sv tb_fft.sv
vsim -voptargs=+acc -onfinish stop work.tb_fft
run -all
if {[examine -radix unsigned /tb_fft/test_pass] != 1} {quit -code 1 -force}
quit -code 0 -force
