set prj {D:/2026FPGA_1/HX4S20_Contest_202606/7_lab_ex_2026_nosoft/lab_ex5_i2s_osd/src/td_project/HDMI1.4b_Transmitter_v1.0.al}
if {[catch {
 import_device eagle_s20.db -package EG4S20BG256
 cd [file dirname $prj]
 open_project $prj -single_run
 elaborate -top top
 close_project
} result]} {puts stderr "REOPEN CHECK FAILED: $result"; exit 1}
puts {PASS: repaired .al reopened, all modules analyzed and top elaborated}
exit 0

