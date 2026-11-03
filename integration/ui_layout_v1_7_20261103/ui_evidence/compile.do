onerror {quit -code 1 -force}
if {![file exists work]} {vlib work}
set h ../src/user_source/hdl_source
vlog $h/OSD/osd_overlay.v $h/OSD/osd_font_rom.v $h/OSD/osd_glyph_pixel.v $h/AUDIO_VIS/audio_fft512.v $h/AUDIO_VIS/audio_visualizer.v $h/AUDIO_VIS/audio_spectrum_overlay.v $h/SD/scale_on_load.v $h/SD/zoom_animation.v $h/SD/zoom_cached_scaler.v $h/SD/image_transition.v
quit -code 0 -force
