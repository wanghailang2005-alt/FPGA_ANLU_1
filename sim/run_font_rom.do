# Run from osd_dev/sim. No vendor simulation libraries required.
onerror {quit -code 1 -force}
# Both $finish and $fatal can break run; inspect the explicit success flag.
onbreak {resume}
file mkdir ../evidence
if {![info exists log_file]} {set log_file ../evidence/modelsim_font_rom.log}
if {![info exists sim_args]} {set sim_args {}}
transcript file $log_file
transcript on
if {[file exists work]} {
    vmap work work
} else {
    vlib work
    vmap work work
}
vlog -work work ../rtl/osd_font_rom.v
vlog -sv -work work tb_osd_font_rom.sv
eval vsim -voptargs=+acc -onfinish stop work.tb_osd_font_rom $sim_args
run -all
if {[examine -radix unsigned /tb_osd_font_rom/test_passed] != 1} {
    echo "FAIL: testbench did not complete successfully"
    quit -code 1 -force
}
quit -code 0 -force
