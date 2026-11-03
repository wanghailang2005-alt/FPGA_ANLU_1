"""Collect a fresh, simulated, routed candidate; never inherit BOARD PASS."""
from pathlib import Path
import hashlib
import json
import re
import shutil
import struct
import zlib

ROOT = Path(__file__).resolve().parents[1]
NAME = 'HDMI1.4b_Transmitter_v1.0'
EVIDENCE = ROOT / 'spectrum_evidence'
RUNS = ROOT / 'src/td_project' / (NAME + '_Runs')
sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()


def preview_from_ppm(source, destination):
    # Lossless encoding of the RTL-produced pixels, not an illustrative mockup.
    with source.open('rb') as stream:
        assert stream.readline().strip() == b'P6'
        width, height = map(int, stream.readline().split())
        assert stream.readline().strip() == b'255'
        pixels = stream.read()
    assert (width, height) == (640, 480) and len(pixels) == width * height * 3
    def chunk(kind, data):
        return (struct.pack('>I', len(data)) + kind + data +
                struct.pack('>I', zlib.crc32(kind + data) & 0xffffffff))
    scanlines = b''.join(b'\0' + pixels[row * width * 3:(row + 1) * width * 3]
                         for row in range(height))
    destination.write_bytes(b'\x89PNG\r\n\x1a\n' +
                            chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0)) +
                            chunk(b'IDAT', zlib.compress(scanlines)) + chunk(b'IEND', b''))


def main():
    baseline = json.loads((EVIDENCE / 'before/source_sha256.json').read_text())
    changed = [name for name, digest in baseline.items() if sha(ROOT / name) != digest]
    allowed = {'src/user_source/hdl_source/top_tf_hdmi_audio.v',
               'src/user_source/hdl_source/OSD/osd_overlay.v',
               'src/user_source/hdl_source/SD/zoom_source_cache.v'}
    assert set(changed) == allowed, changed
    reference = json.loads((EVIDENCE / 'reused_audio_cores.json').read_text())
    for name, digest in reference['sha256'].items():
        assert sha(ROOT / 'src/user_source/hdl_source/AUDIO_VIS' / name) == digest
    old = (EVIDENCE / 'before/src/user_source/hdl_source/SD/zoom_source_cache.v').read_bytes()
    new = (ROOT / 'src/user_source/hdl_source/SD/zoom_source_cache.v').read_bytes()
    assert old.split(b'// Observation-only')[0] == new.split(b'// Observation-only')[0]
    assert old.split(b'reg row_active,error_mem;')[1] == new.split(b'reg row_active,error_mem;')[1]
    sources = [p for p in (ROOT / 'src/user_source').rglob('*') if p.is_file()]
    for suite in ['fft', 'analysis', 'captions', 'spectrum', 'scene', 'checksum', 'cache']:
        log = ROOT / 'spectrum_sim' / (suite + '.log')
        text = log.read_text(errors='replace')
        assert 'RESULT PASS ' + suite in text, suite
        assert not any(token in text for token in ['** Fatal:', '** Error:', 'Executing ONERROR']), suite
        assert re.search(r'Errors:\s*0, Warnings:\s*\d+\s*$', text.strip()), suite
        if suite not in ['checksum', 'cache']:
            assert re.search(r'Errors:\s*0, Warnings:\s*0\s*$', text.strip()), suite
        shutil.copy2(log, EVIDENCE / log.name)
    ref = json.loads((ROOT / 'spectrum_sim/fft_reference_result.json').read_text())
    assert ref['status'] == 'PASS' and ref['bit_exact']
    shutil.copy2(ROOT / 'spectrum_sim/fft_reference_result.json', EVIDENCE / 'fft_reference_result.json')
    font = json.loads((EVIDENCE / 'font_rom_init.json').read_text())
    assert font['status'] == 'PASS' and font['matched_rows'] == 2048
    assert font['expected_rows_sha256'] == font['netlist_rows_sha256']
    assert font['font_rtl_sha256'] == sha(ROOT / font['font_rtl_path'])
    assert font['netlist_source_sha256'] == sha(ROOT / font['netlist_source'])
    route = RUNS / 'phy_1'
    timing = route / (NAME + '_pr.timing')
    area = route / (NAME + '_phy.area')
    text = timing.read_text(errors='replace')
    metric = lambda name: float(re.search(r'\b' + name + r':\s*([-\d.]+)ns', text)[1])
    assert metric('SWNS') >= 0 and metric('HWNS') >= 0, 'Timing has not closed'
    assert metric('STNS') == 0 and metric('HTNS') == 0
    resource_text = area.read_text(errors='replace')
    resources = {name: int(re.search(r'^\s*#' + name + r'\s+(\d+)', resource_text, re.M)[1])
                 for name in ['lut', 'reg', 'bram9k', 'dsp', 'pll']}
    for name, maximum in [('lut', 19600), ('reg', 19600), ('bram9k', 64), ('dsp', 29), ('pll', 4)]:
        assert resources[name] <= maximum, (name, resources[name])
    bit = route / (NAME + '.bit')
    assert bit.stat().st_mtime >= max(p.stat().st_mtime for p in sources), 'Stale bitstream'
    assert timing.stat().st_mtime >= max(p.stat().st_mtime for p in sources), 'Stale timing'
    for suite, source_names in {
        'captions': ['OSD/osd_overlay.v'],
        'spectrum': ['AUDIO_VIS/audio_spectrum_overlay.v', 'AUDIO_VIS/audio_visualizer.v', 'AUDIO_VIS/audio_fft512.v'],
        'scene': ['OSD/osd_overlay.v', 'AUDIO_VIS/audio_spectrum_overlay.v'],
        'checksum': ['SD/zoom_source_cache.v'],
        'cache': ['SD/zoom_source_cache.v'],
    }.items():
        assert (ROOT / 'spectrum_sim' / (suite + '.log')).stat().st_mtime >= max(
            (ROOT / 'src/user_source/hdl_source' / name).stat().st_mtime for name in source_names)
    implementation_log = (route / 'implementation_console.log').read_text(errors='replace')
    assert 'Generate bitstream completely' in implementation_log, 'Bitgen did not complete'
    output = ROOT / 'SCENIC_SPECTRUM_1001_20261103.bit'
    shutil.copy2(bit, output)
    for source, target in [(timing, 'routed_timing.rpt'), (area, 'routed_area.rpt'),
                           (route / 'implementation_console.log', 'implementation.log'),
                           (RUNS / 'syn_1/synthesis_console.log', 'synthesis.log'),
                           (route / 'settings.cfg', 'phy_1_settings.cfg')]:
        shutil.copy2(source, EVIDENCE / target)
    preview_from_ppm(ROOT / 'spectrum_sim/scene.ppm', ROOT / 'SCENIC_SPECTRUM_SIM_PREVIEW.png')
    manifest = {p.relative_to(ROOT).as_posix(): sha(p) for p in sources}
    summary = dict(status='IMPLEMENTED/TIMING PASS under inherited constraints; BOARD UNVERIFIED',
                   date='2026-11-03', bit=output.name, bit_sha256=sha(output),
                   board_status='UNVERIFIED: new build, not the V1.5 or earlier FFT board-tested bit',
                   switch='1001', fft_size=512, frequency_bands=32, max_bar_height_px=40,
                   source='Existing internal I2S square-wave test scale; real output PCM feeds FFT',
                   spectrum_panel=dict(x0=352, y0=384, width=272, height=64),
                   caption_panel=dict(x0=16, y0=384, width=320, height=64),
                   banner_rows=[448, 463], additional_video_latency_clocks=3,
                   payload_control_alignment='SIM PASS, RGB/DE/HS/VS/X/Y in enabled and bypass paths',
                   resources=resources, setup_wns_ns=metric('SWNS'), hold_wns_ns=metric('HWNS'),
                   setup_tns_ns=metric('STNS'), hold_tns_ns=metric('HTNS'),
                   sta_coverage_percent=float(re.search(r'STA coverage\s*:\s*([\d.]+)', text)[1]),
                   changed_baseline_sources=changed, fft_reference=ref,
                   font_rom_initialization=dict(status='PASS', matched_rows=2048,
                                                evidence='font_rom_init.json'),
                   limitations=['No external music input or TF audio-file playback added',
                                'Existing SDRAM timing exceptions remain; timing pass is under current constraints',
                                'The new bit requires board acceptance'])
    (EVIDENCE / 'source_manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
    (EVIDENCE / 'summary.json').write_text(json.dumps(summary, indent=2), encoding='utf-8')
    versions = dict(version='1.6', date='2026-11-03', board_status='UNVERIFIED',
                    bit=dict(local_path=output.name, bytes=output.stat().st_size, sha256=sha(output)),
                    switch='1001', resources=resources,
                    timing=dict(setup_wns_ns=metric('SWNS'), setup_tns_ns=metric('STNS'),
                                hold_wns_ns=metric('HWNS'), timing_closed_under_inherited_constraints=True),
                    baseline=dict(version='1.5', board_status='BOARD PASS (user reported for prior build)',
                                  metadata='spectrum_evidence/before/versions.json'),
                    evidence='spectrum_evidence/summary.json',
                    preview='SCENIC_SPECTRUM_SIM_PREVIEW.png (RTL simulation, not board photograph)')
    (ROOT / 'versions.json').write_text(json.dumps(versions, indent=2), encoding='utf-8')
    (ROOT / (output.name + '.sha256')).write_text(sha(output) + '  ' + output.name + '\n', encoding='ascii')
    print(json.dumps(summary, indent=2))


if __name__ == '__main__':
    main()
