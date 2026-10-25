set prj {D:/2026FPGA_1/HX4S20_Contest_202606/7_lab_ex_2026_nosoft/lab_ex5_i2s_osd/src/td_project/HDMI1.4b_Transmitter_v1.0.al}
if {[catch {
 import_device eagle_s20.db -package EG4S20BG256
 open_project $prj -noanalyze
 add_files {D:/2026FPGA_1/HX4S20_Contest_202606/7_lab_ex_2026_nosoft/lab_ex5_i2s_osd/src/user_source/hdl_source/OSD/osd_status_cdc.v}
 add_files {D:/2026FPGA_1/HX4S20_Contest_202606/7_lab_ex_2026_nosoft/lab_ex5_i2s_osd/src/user_source/hdl_source/OSD/osd_status_layout.v}
 close_project
} result]} {puts stderr "REPAIR FAILED: $result"; exit 1}
set f [open $prj r]; set content [read $f]; close $f
foreach name {osd_status_cdc.v osd_status_layout.v} {
 if {[string first $name $content]<0} {puts stderr "NOT PERSISTED: $name"; exit 2}
}
puts {PASS: TD native add_files persisted both sources}
exit 0
