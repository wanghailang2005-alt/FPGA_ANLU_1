onerror {quit -code 1 -force}
onbreak {resume}
vlog ../src/user_source/hdl_source/OSD/osd_overlay.v
vlog -sv tb_caption_ui.sv
vsim -voptargs=+acc -onfinish stop work.tb_caption_ui
run -all
if {[examine -radix unsigned /tb_caption_ui/test_pass] != 1} {quit -code 1 -force}
quit -code 0 -force
