# Run from osd_dev/sim.
onerror {quit -code 1 -force}
onbreak {resume}
file mkdir ../evidence
if {![info exists log_file]} {set log_file ../evidence/modelsim_status_overlay.log}
if {![info exists sim_args]} {set sim_args {}}
transcript file $log_file
transcript on
if {[file exists work]} {vmap work work} else {vlib work; vmap work work}
vlog -work work ../rtl/osd_font_rom.v ../rtl/osd_glyph_pixel.v ../rtl/osd_fixed_layout.v ../rtl/osd_overlay.v ../rtl/osd_status_layout.v
vlog -sv -work work tb_status_overlay.sv
eval vsim -voptargs=+acc -onfinish stop work.tb_status_overlay $sim_args
run -all
if {[examine -radix unsigned /tb_status_overlay/test_passed] != 1} {
    echo "FAIL: overlay self-check did not complete successfully"
    quit -code 1 -force
}
quit -code 0 -force
