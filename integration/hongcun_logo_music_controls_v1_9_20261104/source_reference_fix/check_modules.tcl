# Analyze and elaborate only. Do not run placement/routing or generate a bit.
set root [file normalize [file join [file dirname [info script]] ..]]
cd [file join $root src td_project HDMI1.4b_Transmitter_v1.0_Runs syn_1]
if {[catch {
 import_device eagle_s20.db -package EG4S20BG256
 open_project HDMI1.4b_Transmitter_v1.0.prj
 elaborate -top top
} result options]} {
 puts stderr "MODULE CHECK FAILED: $result"
 exit 1
}
puts "MODULE CHECK PASS: both TF music modules resolved by top-level elaboration"
exit 0
