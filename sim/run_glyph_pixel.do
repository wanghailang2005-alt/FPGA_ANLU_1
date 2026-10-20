# Run from osd_dev/sim; exit nonzero on compilation/runtime/test failure.
onerror {quit -code 1 -force}
onbreak {resume}
file mkdir ../evidence
if {![info exists log_file]} {set log_file ../evidence/modelsim_glyph_pixel.log}
if {![info exists sim_args]} {set sim_args {}}
transcript file $log_file
transcript on
if {[file exists work]} {
    vmap work work
} else {
    vlib work
    vmap work work
}
vlog -work work ../rtl/osd_font_rom.v ../rtl/osd_glyph_pixel.v
vlog -sv -work work tb_osd_glyph_pixel.sv
eval vsim -voptargs=+acc -onfinish stop work.tb_osd_glyph_pixel $sim_args
run -all
if {[examine -radix unsigned /tb_osd_glyph_pixel/test_passed] != 1} {
    echo "FAIL: glyph pixel self-check did not complete successfully"
    quit -code 1 -force
}
quit -code 0 -force
