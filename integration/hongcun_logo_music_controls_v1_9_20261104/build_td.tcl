# Invoke td_commands_prompt.exe on this file from a candidate syn_1 or phy_1.
set tdRoot [file normalize [file join [file dirname [info nameofexecutable]] ..]]
set flow [file join $tdRoot doc scripts DefaultFlow.tcl]
if {[catch {source $flow} result options]} {
    puts stderr "BUILD FAILED: $result"
    if {[dict exists $options -errorinfo]} {puts stderr [dict get $options -errorinfo]}
    exit 1
}
exit 0
