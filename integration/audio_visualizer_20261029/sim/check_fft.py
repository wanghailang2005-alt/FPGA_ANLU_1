"""Bit-exact independent integer FFT, plus a floating FFT error bound.

No third-party Python dependencies. Also converts simulation PPM into PNG.
"""
from pathlib import Path
import cmath, json, math, random, struct, sys, zlib
R=Path(__file__).resolve().parent
def vectors():
    rng=random.Random(20261029)
    all_samples=[
        [0]*512,
        [12000]*512,
        [0]*256+[32767]+[0]*255,
        [round(24000*math.sin(2*math.pi*16*n/512)) for n in range(512)],
        [round(22000*math.sin(2*math.pi*4.693*n/512)) for n in range(512)],
        [round(13000*math.sin(2*math.pi*8*n/512)+9000*math.cos(2*math.pi*73*n/512)) for n in range(512)],
        [rng.randint(-32768,32767) for _ in range(512)],
        [-32768 if n%2 else 32767 for n in range(512)],
    ]
    (R/'samples.hex').write_text('\n'.join(f'{v&65535:04x}' for a in all_samples for v in a)+'\n')
    (R/'samples.json').write_text(json.dumps(all_samples))

def sat(x):return min(32767,max(-32768,x))
def integer_fft(samples,t):
    a=[(0,0)]*512
    for n,v in enumerate(samples):
        a[int(f'{n:09b}'[::-1],2)]=(sat(v*t['hann'][n]>>15),0)
    m=2
    while m<=512:
        for base in range(0,512,m):
            for j in range(m//2):
                k=j*512//m
                ar,ai=a[base+j];br,bi=a[base+j+m//2]
                wr,wi=t['wr'][k],t['wi'][k]
                tr=(br*wr-bi*wi)>>15;ti=(br*wi+bi*wr)>>15
                a[base+j]=(sat((ar+tr)>>1),sat((ai+ti)>>1))
                a[base+j+m//2]=(sat((ar-tr)>>1),sat((ai-ti)>>1))
        m*=2
    return a

def float_fft(a):
    if len(a)==1:return a
    ev=float_fft(a[::2]);od=float_fft(a[1::2]);n=len(a)
    z=[cmath.exp(-2j*math.pi*k/n)*od[k] for k in range(n//2)]
    return [ev[k]+z[k] for k in range(n//2)]+[ev[k]-z[k] for k in range(n//2)]

def check():
    samples=json.loads((R/'samples.json').read_text());t=json.loads((R/'tables.json').read_text())
    rows=[list(map(int,x.split())) for x in (R/'fft_output.txt').read_text().splitlines()]
    assert len(rows)==2048,len(rows)
    maxerr=0;peaks=[]
    for f,a in enumerate(samples):
        ref=integer_fft(a,t)
        floating=float_fft([v*(.5-.5*math.cos(2*math.pi*n/512)) for n,v in enumerate(a)])
        for k in range(256):
            row=rows[f*256+k]
            assert row[:2]==[f,k] and tuple(row[2:])==ref[k],(f,k,row,ref[k])
            maxerr=max(maxerr,abs(complex(*ref[k])-floating[k]/512))
        peaks.append(max(range(1,256),key=lambda k:abs(complex(*ref[k]))))
    assert maxerr<12,maxerr
    assert peaks[3]==16 and peaks[5]==8,peaks
    result=dict(status='PASS',frames=8,complex_bins=2048,bit_exact=True,
                max_complex_error_lsb=maxerr,allowed_complex_error_lsb=12,peak_bins=peaks)
    (R/'fft_reference_result.json').write_text(json.dumps(result,indent=2))
    print(json.dumps(result))

def png():
    p=R/'visualizer.ppm'
    with p.open('rb') as f:
        assert f.readline().strip()==b'P6'
        w,h=map(int,f.readline().split());assert f.readline().strip()==b'255';pixels=f.read()
    assert len(pixels)==w*h*3,len(pixels)
    def chunk(t,b):return struct.pack('>I',len(b))+t+b+struct.pack('>I',zlib.crc32(t+b)&0xffffffff)
    data=b''.join(b'\0'+pixels[y*w*3:(y+1)*w*3] for y in range(h))
    (R.parent/'AUDIO_VIS_SIM_PREVIEW.png').write_bytes(b'\x89PNG\r\n\x1a\n'+
        chunk(b'IHDR',struct.pack('>IIBBBBB',w,h,8,2,0,0,0))+
        chunk(b'IDAT',zlib.compress(data))+chunk(b'IEND',b''))
    print('Saved simulation-derived 640x480 PNG')

if __name__=='__main__':
    if '--generate' in sys.argv:vectors()
    elif '--png' in sys.argv:png()
    else:check()
