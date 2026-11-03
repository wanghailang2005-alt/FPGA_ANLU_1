onerror {quit -code 1 -force}
onbreak {resume}
if {![file exists work]} {vlib work}
vlog ../src/user_source/hdl_source/OSD/osd_overlay.v
vlog -sv tb_music_sidebar.sv
vsim -voptargs=+acc -onfinish stop work.tb_music_sidebar
run -all
if {[examine -radix unsigned /tb_music_sidebar/test_pass] != 1} {quit -code 1 -force}
quit -code 0 -force
