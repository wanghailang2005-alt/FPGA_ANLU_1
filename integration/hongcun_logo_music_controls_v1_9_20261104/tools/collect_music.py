"""Collect implementation evidence; publish a named bit only after timing passes."""
from pathlib import Path
import hashlib,json,re,shutil,argparse
R=Path(__file__).resolve().parents[1]
N='HDMI1.4b_Transmitter_v1.0'
P=R/f'src/td_project/{N}_Runs/phy_1'
S=R/f'src/td_project/{N}_Runs/syn_1'
args=argparse.ArgumentParser();args.add_argument('--attempt',default='final');opt=args.parse_args()
O=R/'music_evidence'/opt.attempt;O.mkdir(parents=True,exist_ok=True)
t=(P/'final_timing.rpt').read_text(encoding='utf-8')
values={name:float(re.search(name+r':\s*([\d.-]+)ns',t)[1]) for name in ['SWNS','STNS','HWNS','HTNS']}
passed=values['SWNS']>=0 and values['HWNS']>=0 and values['STNS']==0 and values['HTNS']==0
for src,dest in [(P/'final_timing.rpt','routed_timing.rpt'),(P/(N+'_phy.area'),'routed_area.rpt'),
                 (P/(N+'_exception.timing'),'timing_exceptions.rpt'),
                 (P/'music_implementation_console.log','implementation.log'),
                 (S/'music_synthesis_console.log','synthesis.log'),(P/'settings.cfg','settings.cfg')]:
    if src.exists():shutil.copy2(src,O/dest)
area=(O/'routed_area.rpt').read_text(encoding='utf-8')
resources={k:int(re.search(r'^#'+k+r'\s+(\d+)',area,re.M)[1]) for k in ['lut','reg','bram','dsp']}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
changed=['src/user_source/hdl_source/top_tf_hdmi_audio.v','src/user_source/hdl_source/user_control.v',
         'src/user_source/hdl_source/SD/sd_card_bmp.v','src/user_source/hdl_source/AUDIO_MUSIC/tf_music_player.v',
         'src/user_source/hdl_source/AUDIO_MUSIC/sd_music_arbiter.v',
         'src/user_source/hdl_source/OSD/osd_status_cdc.v',
         'src/user_source/hdl_source/SD/image_transition.v',
         'src/user_source/hdl_source/SD/frame_fifo_read.v',
         'src/user_source/hdl_source/SD/frame_fifo_write.v',
         'src/user_source/hdl_source/SD/video_timing_data.v',
         'src/user_source/hdl_source/SD/zoom_source_cache.v',
         'src/user_source/constraints_source/timing.sdc','src/td_project/'+N+'.al']
result=dict(timing=values,resources=resources,timing_pass=passed,board='UNVERIFIED',
            sources={p:sha(R/p) for p in changed},
            simulations={p:('PASS' if 'PASS ' in (R/'music_sim'/p).read_text(encoding='utf-8') else 'FAIL')
                         for p in ['music.log','real_music.log','keys.log','cdc.log']})
result['media_manifest_sha256']=sha(R/'music_media/manifest.json')
result['card_image']=json.loads((R/'music_media/manifest.json').read_text(encoding='utf-8'))['image']
result['card_image_sha256']=sha(R/'music_media'/result['card_image'])
if (R/'music_evidence/post_route_hold.log').exists():
    result['post_route_hold_log']='post_route_hold.log'
if passed and all(v=='PASS' for v in result['simulations'].values()):
    target=R/'HONGCUN_2_MUSIC_K3_20261103.bit';shutil.copy2(P/(N+'.bit'),target)
    result['bitstream']=target.name;result['bitstream_sha256']=sha(target)
    target.with_suffix('.bit.sha256').write_text(sha(target)+'  '+target.name+'\n',encoding='ascii')
    for p in O.iterdir():
        if p.is_file() and p.name!='summary.json':shutil.copy2(p,R/'music_evidence'/p.name)
    (R/'music_evidence/summary.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
(O/'summary.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps(result,indent=2))
