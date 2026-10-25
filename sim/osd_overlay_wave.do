onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_osd_overlay/clk
add wave -noupdate /tb_osd_overlay/enable
add wave -noupdate -radix unsigned /tb_osd_overlay/out_x
add wave -noupdate -radix unsigned /tb_osd_overlay/out_y
add wave -noupdate /tb_osd_overlay/dut/glyph_valid
add wave -noupdate /tb_osd_overlay/dut/pixel_on
add wave -noupdate /tb_osd_overlay/out_de
add wave -noupdate -radix hexadecimal /tb_osd_overlay/out_rgb
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 2} {128105781 ps} 0} {{Cursor 3} {128105781 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 280
configure wave -valuecolwidth 120
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ps
update
WaveRestoreZoom {128630 ns} {129030 ns}
