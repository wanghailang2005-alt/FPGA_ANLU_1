"""Create an isolated vendor-project copy and apply only reviewed OSD changes.

No vendor source is included in this repository. Supply your local lab_ex5_i2s.
Destination must not exist; the script never deletes or replaces a project.
"""
import argparse
import hashlib
import json
import pathlib
import re
import shutil

MODULES = ['osd_font_rom.v', 'osd_glyph_pixel.v', 'osd_fixed_layout.v',
           'osd_overlay.v', 'osd_video_position.v']
PROJECT = 'HDMI1.4b_Transmitter_v1.0'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def add_sources(text, prefix):
    records = []
    for i, name in enumerate(MODULES, 200):
        records.append(
            f'            <File Path="{prefix}/OSD/{name}">\n'
            '                <FileInfo>\n'
            '                    <Attr Name="UsedInSyn" Val="true"/>\n'
            '                    <Attr Name="UsedInP&R" Val="true"/>\n'
            '                    <Attr Name="BelongTo" Val="design_1"/>\n'
            f'                    <Attr Name="CompileOrder" Val="{i}"/>\n'
            '                </FileInfo>\n'
            '            </File>\n')
    if text.count('</Verilog>') != 1:
        raise ValueError('Unexpected project source list')
    return text.replace('</Verilog>', ''.join(records) + '        </Verilog>', 1)


def check_paths(project, allowed_root):
    # TD's own XML-like format includes raw '&' in attribute values.
    # Preserve it verbatim rather than normalizing with a generic XML writer.
    for value in re.findall(r'<File Path="([^"]+)"', project.read_text(encoding='utf-8-sig')):
        path = (project.parent / value).resolve()
        if not path.is_relative_to(allowed_root):
            raise ValueError(f'Source escapes candidate: {value}')
        if not path.is_file():
            raise FileNotFoundError(path)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--source', type=pathlib.Path, required=True)
    parser.add_argument('--dest', type=pathlib.Path, required=True)
    parser.add_argument('--fix-axis', action='store_true',
                        help='Apply separately approved candidate-only LAST correction')
    args = parser.parse_args()
    source, dest = args.source.resolve(), args.dest.resolve()
    repo = pathlib.Path(__file__).resolve().parent.parent
    if not source.is_dir() or dest.exists():
        raise ValueError('Source must exist and destination must not exist')
    if dest.is_relative_to(source) or source.is_relative_to(dest):
        raise ValueError('Source and destination must be disjoint')
    old_project = source / 'src/td_project' / (PROJECT + '.al')
    if not old_project.is_file():
        raise FileNotFoundError(old_project)
    # Snapshot precisely the source/IP tree being copied (excluding old runs).
    source_files = [p for p in (source/'src').rglob('*') if p.is_file()
                    and not any(part.endswith('_Runs') for part in p.parts)]
    baseline = {p.relative_to(source).as_posix(): sha(p) for p in source_files}
    shutil.copytree(source/'src', dest/'src',
                    ignore=shutil.ignore_patterns('*_Runs', '.git'))
    hdl = dest/'src/user_source/hdl_source'
    (hdl/'OSD').mkdir()
    for name in MODULES:
        shutil.copy2(repo/'rtl'/name, hdl/'OSD'/name)
    top = hdl/'top_tf_hdmi_audio.v'
    before = top.read_text(encoding='utf-8-sig')
    anchor = 'video_rgb_to_axis_640x480 u_video_rgb_to_axis_640x480('
    if before.count(anchor) != 1:
        raise ValueError('Unexpected top-level adapter instance')
    snippet = (repo/'integration/top_osd_insert.vh').read_text(encoding='utf-8')
    after = before.replace(anchor, snippet+'\n'+anchor)
    for signal, replacement in [('vs','osd_video_vs'), ('de','osd_video_de'),
                                ('rgb','osd_video_rgb')]:
        pattern = rf'(\.I_{signal}\s*\(\s*)' + ('vout_data' if signal=='rgb' else signal) + r'(\s*\))'
        after, count = re.subn(pattern, rf'\g<1>{replacement}\2', after)
        if count != 1:
            raise ValueError(f'Unexpected I_{signal} connections: {count}')
    top.write_text(after, encoding='utf-8', newline='\n')
    axis = hdl/'video_rgb_to_axis_640x480.v'
    if args.fix_axis:
        raw = axis.read_text(encoding='utf-8-sig')
        raw, count = re.subn(r'(if\s*\(!S_de_1d\)\s*begin[\s\S]*?S_x_cnt\s*<=\s*)11\x27d0',
                             r"\g<1>11'd1", raw, count=1)
        if count != 1:
            raise ValueError('Unexpected candidate AXIS counter')
        axis.write_text(raw, encoding='utf-8', newline='\n')

    project = dest/'src/td_project'/(PROJECT+'.al')
    raw = project.read_text(encoding='utf-8-sig')
    raw = re.sub(r'(<Project\b[^>]*\bPath=")[^"]*',
                 lambda m: m.group(1)+project.parent.as_posix(), raw, count=1)
    project.write_text(add_sources(raw, '../user_source/hdl_source'),
                       encoding='utf-8', newline='\n')
    check_paths(project, dest)
    for stage in ['syn_1', 'phy_1']:
        old_run = source/'src/td_project'/(PROJECT+'_Runs')/stage
        run = dest/'src/td_project'/(PROJECT+'_Runs')/stage
        run.mkdir(parents=True)
        for file in [PROJECT+'.prj', 'settings.cfg']:
            original = old_run/file
            if not original.exists():
                raise FileNotFoundError(original)
            if file.endswith('.prj'):
                text = add_sources(original.read_text(encoding='utf-8-sig'),
                                   '../../../user_source/hdl_source')
                (run/file).write_text(text, encoding='utf-8', newline='\n')
                check_paths(run/file, dest)
            else:
                shutil.copy2(original, run/file)
    unchanged = all(sha(source/p) == value for p,value in baseline.items())
    if not unchanged:
        raise RuntimeError('Baseline changed during copy')
    manifest = {'baseline_source_files': baseline, 'baseline_unchanged': unchanged,
                'candidate_project': project.relative_to(dest).as_posix(),
                'axis_fix_applied': args.fix_axis,
                'osd_source_sha256': {name: sha(repo/'rtl'/name) for name in MODULES}}
    (dest/'baseline_manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
    print(f'Candidate: {project}')
    print(f'Baseline files unchanged: {len(baseline)}; candidate references all local')


if __name__ == '__main__':
    main()
