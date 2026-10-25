"""Build named fixed/legacy and dynamic diagnostic bits; restore selected default.

Usage: python integration/build_stall_diagnostics.py
No programming of hardware. Only the isolated candidate is modified.
"""
from pathlib import Path
import hashlib
import json
import re
import shutil
import subprocess
import time

repo=Path(__file__).resolve().parents[1]
candidate=repo.parent/'lab_ex5_i2s_osd'
hdl=candidate/'src/user_source/hdl_source'
top=hdl/'top_tf_hdmi_audio.v'
project='HDMI1.4b_Transmitter_v1.0'
runs=candidate/'src/td_project'/f'{project}_Runs'
td=Path('E:/Anlogic/TD_6.2.1_Engineer_6.2.168.116/bin/td_commands_prompt.exe')
flow=repo/'integration/build_td.tcl'
evidence=repo/'evidence'
sha=lambda p: hashlib.sha256(p.read_bytes()).hexdigest()

def set_mode(mode):
    s=top.read_text(encoding='utf-8-sig')
    s,n=re.subn(r'parameter OSD_STATUS_MODE = [01];',f'parameter OSD_STATUS_MODE = {mode};',s)
    if n!=1: raise RuntimeError('Unexpected top-level mode parameter')
    top.write_text(s,encoding='utf-8')

original_mode=int(re.search(r'parameter OSD_STATUS_MODE = ([01]);',top.read_text(encoding='utf-8-sig')).group(1))
results=[]
try:
    for name,mode in [('FIXED_LEGACY',0),('DYNAMIC',1)]:
        set_mode(mode)
        # GUI caches AutoExcluded for the last elaborated parameter mode.
        # Each A/B build must re-enable both generate branches for analysis.
        for prj in runs.glob('*/*.prj'):
            text=prj.read_text(encoding='utf-8-sig')
            def enable_osd(match):
                return re.sub(r'\s*<Attr Name="AutoExcluded" Val="true"/>','',match.group(0))
            text=re.sub(r'<File Path="[^"]*/OSD/[^"]+">[\s\S]*?</File>',enable_osd,text)
            prj.write_text(text,encoding='utf-8')
        print(f'{name}: build starting',flush=True)
        hashes={p.relative_to(candidate).as_posix():sha(p) for p in
                [top,hdl/'SD/sd_card_bmp.v',hdl/'SD/frame_fifo_read.v',hdl/'SD/frame_read_write.v']}
        for stage,marker,finish in [('syn_1','.opt_gate.end.f','finish command "optimize_gate'),
                                    ('phy_1','.bitgen.end.f','finish command "bitgen')]:
            start=time.time()
            log=evidence/f'diag_{name.lower()}_{stage}.log'
            with log.open('w',encoding='utf-8') as out:
                process=subprocess.run([str(td),flow.as_posix()],cwd=runs/stage,
                                       stdout=out,stderr=subprocess.STDOUT)
            data=log.read_text(encoding='utf-8',errors='replace')
            end=runs/stage/marker
            if process.returncode or not end.exists() or end.stat().st_mtime<start-2 or finish not in data:
                raise RuntimeError(f'{name} {stage} failed, see {log}')
            print(f'{name}: {stage} completed',flush=True)
        bit=runs/'phy_1'/f'{project}.bit'
        named=candidate/f'OSD_DIAG_{name}_20261025.bit'
        shutil.copy2(bit,named)
        summary=(runs/'phy_1'/f'{project}_phy.ts').read_text(encoding='utf-8-sig')
        (evidence/f'diag_{name.lower()}_timing.txt').write_text(summary,encoding='utf-8')
        area=(runs/'phy_1'/f'{project}_phy.area').read_text(encoding='utf-8-sig').split('Detailed IO Report')[0]
        (evidence/f'diag_{name.lower()}_utilization.txt').write_text(area,encoding='utf-8')
        results.append({'variant':name,'mode':mode,'bit':named.name,'sha256':sha(named),
                        'bytes':named.stat().st_size,'timing':summary,'source_sha256':hashes,
                        'board':'UNVERIFIED'})
        (evidence/'stall_diagnostic_builds.json').write_text(json.dumps(results,indent=2),encoding='utf-8')
        print(f'{name}: {named.name}, sha256={sha(named)}',flush=True)
finally:
    set_mode(original_mode)
