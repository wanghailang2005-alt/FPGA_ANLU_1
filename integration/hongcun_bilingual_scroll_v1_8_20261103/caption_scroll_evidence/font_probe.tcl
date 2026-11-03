set root [file normalize [file join [file dirname [info script]] ..]]
set gate [file join $root src td_project HDMI1.4b_Transmitter_v1.0_Runs syn_1 HDMI1.4b_Transmitter_v1.0_gate.db]
set output [file join $root caption_scroll_evidence font_gate_probe.v]
if {[catch {
 import_device eagle_s20.db -package EG4S20BG256
 import_db $gate
 write_verilog $output -nolf -constnet
} result]} {puts stderr $result;exit 1}
exit 0
