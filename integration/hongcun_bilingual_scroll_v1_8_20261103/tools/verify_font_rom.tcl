# Read-only synthesis-database probe. No project is opened or saved, and no
# placement, routing, synthesis or bitstream command is executed here.
set probeRoot [file normalize [file join [file dirname [info script]] ..]]
set probeDir [file join $probeRoot spectrum_sim rom_init_probe]
set probeGate [file join $probeRoot src td_project HDMI1.4b_Transmitter_v1.0_Runs syn_1 HDMI1.4b_Transmitter_v1.0_gate.db]
set probeNetlist [file join $probeDir font_gate_probe.v]
if {[catch {
    if {![file isfile $probeGate]} {error "Missing completed synthesis database: $probeGate"}
    file mkdir $probeDir
    cd $probeDir
    import_device eagle_s20.db -package EG4S20BG256
    import_db $probeGate
    write_verilog $probeNetlist -nolf -constnet
} probeResult]} {
    puts stderr "FONT PROBE FAILED: $probeResult"
    exit 1
}
puts "FONT PROBE EXPORT COMPLETE; run tools/verify_font_rom.py to verify and remove the temporary netlist."
exit 0
