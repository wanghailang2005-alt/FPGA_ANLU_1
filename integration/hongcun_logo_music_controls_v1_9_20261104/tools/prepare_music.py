"""Convert actual RIFF data (including streaming-size headers) and build raw TF image.

Only creates files. Never opens or writes a physical disk.
"""
from pathlib import Path
import array,struct,json,hashlib,wave,sys,shutil
R=Path(__file__).resolve().parents[1]
O=R/'music_media';O.mkdir(exist_ok=True)
SRC=Path('C:/Users/Wang/AppData/Local/Temp')
names=['01_松风抚琴_古琴 (1).wav','04_古道笛韵_竹笛.wav']
tracks=[]
for index,name in enumerate(names):
    original=O/'original'/name
    original.parent.mkdir(exist_ok=True)
    if not original.exists():shutil.copy2(SRC/name,original)
    raw=original.read_bytes()
    assert raw[:4]==b'RIFF' and raw[8:12]==b'WAVE'
    pos=12;fmt=None;pcm=None;declared=None
    while pos+8<=len(raw):
        tag=raw[pos:pos+4];n=struct.unpack_from('<I',raw,pos+4)[0]
        if tag==b'fmt ': fmt=struct.unpack_from('<HHIIHH',raw,pos+8)
        if tag==b'data':
            declared=n;pcm=raw[pos+8:min(pos+8+n,len(raw))];break
        pos+=8+n+(n&1)
    assert fmt is not None and pcm is not None
    code,ch,rate,_,align,bits=fmt
    assert code==1 and bits==16 and align==2*ch
    usable=len(pcm)//align;assert usable>=rate*30,(name,usable/rate)
    data=array.array('h');data.frombytes(pcm[:usable*align])
    if sys.byteorder!='little': data.byteswap()
    mono=[sum(data[i*ch:(i+1)*ch])//ch for i in range(min(usable,rate*30+1))]
    out=array.array('h')
    # Linear interpolation for 40k -> 48k upsampling; no DSP in FPGA.
    for i in range(48000*30):
        a,rem=divmod(i*rate,48000);b=min(a+1,len(mono)-1)
        value=(mono[a]*(48000-rem)+mono[b]*rem)//48000
        # 5ms fades reduce hard discontinuities when the 30s segment loops.
        fade=min(i,48000*30-1-i,240)
        out.append(value*fade//240)
    if sys.byteorder!='little':out.byteswap()
    payload=out.tobytes();stem=f'{index+1:02d}_'+('songfeng_guqin' if index==0 else 'gudao_dizi')
    (O/(stem+'.pcm')).write_bytes(payload)
    with wave.open(str(O/(stem+'_30s.wav')),'wb') as w:
        w.setparams((1,2,48000,0,'NONE','not compressed'));w.writeframes(payload)
    tracks.append(dict(source=name,source_rate=rate,source_channels=ch,actual_seconds=usable/rate,
                       declared_data_bytes=declared,actual_data_bytes=len(pcm),
                       frames=1440000,lba=131072+index*5625,sectors=5625,
                       file=stem+'.pcm',sha256=hashlib.sha256(payload).hexdigest()))
image=O/'HONGCUN_5_IMAGES_2_MUSIC_TF.img'
bmps=[R.parent/'media/hongcun_guide_demo_20261103/05_宏村文化导览_480x360.bmp']
bmps+=sorted((R.parent/'media/hongcun_mixed_sizes_20261103').glob('0*.bmp'))
assert len(bmps)==5
images=[]
with image.open('wb') as f:
    for p in bmps:
        data=p.read_bytes();assert data[:2]==b'BM'
        images.append(dict(name=p.name,lba=f.tell()//512,bytes=len(data)))
        f.write(data);f.write(bytes((-len(data))%512))
    assert f.tell()<131072*512
    f.seek(131072*512)
    for t in tracks:f.write((O/t['file']).read_bytes())
manifest=dict(format='raw sectors, NOT a FAT filesystem image',sample_rate=48000,bits=16,channels=1,
              tracks=tracks,images=images,image=image.name,image_bytes=image.stat().st_size,
              image_sha256=hashlib.sha256(image.read_bytes()).hexdigest())
(O/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(manifest,ensure_ascii=True,indent=2))
reference=[]
for t in tracks:
    data=(O/t['file']).read_bytes()[:4096]
    reference.extend(f'{v:04x}' for (v,) in struct.iter_unpack('<H',data))
(R/'music_sim/real_pcm.hex').write_text('\n'.join(reference)+'\n',encoding='ascii')
