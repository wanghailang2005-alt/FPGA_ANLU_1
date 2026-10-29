onerror {quit -code 1 -force}
onbreak {resume}
if {![file exists analysis_work]} {vlib analysis_work}
set h ../user_source/hdl_source
vlog -work analysis_work $h/AUDIO_VIS/audio_fft512.v $h/AUDIO_VIS/audio_visualizer.v
vlog -work analysis_work -sv tb_analysis.sv
vsim -voptargs=+acc -onfinish stop analysis_work.tb_analysis
run -all
if {[examine -radix unsigned /tb_analysis/test_pass] != 1} {quit -code 1 -force}
quit -code 0 -force
