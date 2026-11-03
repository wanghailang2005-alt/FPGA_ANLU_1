"""Register the compact spectrum sources in the GUI and TD batch projects.

Does not regenerate fonts, FFT tables, vendor IP, or timing/pin constraints.
"""
from pathlib import Path
import json
import re

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / 'src/td_project'
NAME = 'HDMI1.4b_Transmitter_v1.0'


def main():
    project = PROJECT / (NAME + '.al')
    text = project.read_text(encoding='utf-8')
    additions = ['audio_fft512.v', 'audio_visualizer.v', 'audio_spectrum_overlay.v']
    for name in additions:
        relative = '../user_source/hdl_source/AUDIO_VIS/' + name
        if relative not in text:
            entry = (f'\n            <File Path="{relative}"><FileInfo>'
                     '<Attr Name="UsedInSyn" Val="true"/>'
                     '<Attr Name="UsedInP&amp;R" Val="true"/>'
                     '<Attr Name="BelongTo" Val="design_1"/>'
                     '<Attr Name="CompileOrder" Val="0"/></FileInfo></File>')
            text = text.replace('<Verilog>', '<Verilog>' + entry, 1)
    order = iter(range(1000))
    text = re.sub(r'(<Attr Name="CompileOrder" Val=")\d+',
                  lambda match: match[1] + str(next(order)), text)
    project.write_text(text, encoding='utf-8')
    batch = text.split('    <Runs>')[0] + '</Project>\n'
    batch = re.sub(r'(<File Path=")([^"]+)',
                   lambda match: match[1] + ('../../al_ip/' + match[2][6:]
                                            if match[2].startswith('al_ip/')
                                            else '../../' + match[2]), batch)
    for stage in ['syn_1', 'phy_1']:
        run = PROJECT / (NAME + '_Runs') / stage
        (run / (NAME + '.prj')).write_text(batch, encoding='utf-8')
    config = PROJECT / (NAME + '_Runs/phy_1/settings.cfg')
    settings = config.read_text(encoding='utf-8')
    if 'set phyWildParams' not in settings:
        settings += ('\nset phyWildParams {place seed 2 place hold_fix high '
                     'place effort high place opt_timing high route effort high}\n')
        config.write_text(settings, encoding='utf-8')
    # The verified reference suites are included locally; rebuilding this
    # folder must not depend on the sibling audio development project.
    sim = ROOT / 'spectrum_sim'
    for name in ['tb_fft.sv', 'tb_analysis.sv', 'check_fft.py', 'tables.json', 'fft.do', 'analysis.do']:
        assert (sim / name).is_file(), 'Missing bundled verification input: ' + name
    print(json.dumps({'prepared': additions, 'batch_projects': 2,
                      'constraints_modified': False}))


if __name__ == '__main__':
    main()
