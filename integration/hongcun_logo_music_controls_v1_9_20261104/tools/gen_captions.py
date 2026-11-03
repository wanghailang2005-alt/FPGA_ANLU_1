# -*- coding: utf-8 -*-
"""Generate five bilingual caption tables, preserving the video pipeline."""
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
ROOT = Path(__file__).resolve().parents[1]
RTL = ROOT / 'src/user_source/hdl_source/OSD/osd_overlay.v'
DATA = ROOT / 'docs/HONGCUN_CAPTIONS_5.json'
FONT = r'C:\Windows\Fonts\simsun.ttc'

def glyph(font,ch):
    img=Image.new('L',(16,16),0)
    ImageDraw.Draw(img).text((-1,-1),ch,font=font,fill=255)
    return [sum(1 << (15-x) for x in range(16) if img.getpixel((x,y))>=110) for y in range(16)]

def table(name,bits,input_bits,entries,default=0):
    return [f'    function [{bits-1}:0] {name};',f'        input [{input_bits-1}:0] idx;','        begin','            case (idx)'] + [f"                {input_bits}'d{i}: {name} = {bits}'d{v};" for i,v in enumerate(entries)] + [f"                default: {name} = {bits}'d{default};",'            endcase','        end','    endfunction','']

def main():
    captions=json.loads(DATA.read_text(encoding='utf-8'))['captions']
    assert len(captions)==5 and [c['index'] for c in captions]==list(range(5))
    zh=[c['zh'] for c in captions];en=[c['en'].upper() for c in captions]
    chars=list(dict.fromkeys(''.join(zh)))
    assert len(chars)<=128 and sum(map(len,zh))<=256
    assert all(0<len(s)<=255 for s in en) and sum(map(len,en))<=1024
    assert set(''.join(en))<=set('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ,.-/:;+=')
    font=ImageFont.truetype(FONT,16)
    lines=['    // ==== 以下由 tools/gen_captions.py 自动生成，请勿手工修改 ====','    // Order: guide, Moon Pond, woodcarving, historic photo, horse-head wall.',f'    localparam integer ZH_TOTAL = {sum(map(len,zh))};',f'    localparam integer ZH_GLYPHS = {len(chars)};','']
    for prefix,strings,start_bits in [('cap',zh,8),('en',en,10)]:
        starts=[];pos=0
        for s in strings:starts.append(pos);pos+=len(s)
        lines+=table(prefix+'_start',start_bits,3,starts)
        lines+=table(prefix+'_len',8,3,list(map(len,strings)))
    lines+=table('cap_char',7,8,[chars.index(ch) for ch in ''.join(zh)])
    lines+=['    function [15:0] zh_glyph_row;','        input [6:0] g;','        input [3:0] row;','        reg [255:0] bmp;','        begin','            case (g)']
    for i,ch in enumerate(chars):
        bitmap=0
        for row in glyph(font,ch):bitmap=(bitmap<<16)|row
        lines.append(f"                7'd{i}: bmp = 256'h{bitmap:064x}; // {ch}")
    lines+=["                default: bmp = 256'h0;",'            endcase',"            zh_glyph_row = bmp[255 - {row, 4'b0000} -: 16];",'        end','    endfunction','']
    # Combinational character lookup feeds the existing two-stage glyph path.
    # No new video stage or external file dependency is introduced.
    lines+=table('en_char',8,10,[ord(ch) for ch in ''.join(en)],32)
    lines+=['    // ==== 生成区结束 ====','']
    text=RTL.read_text(encoding='utf-8');start=text.index('    // ==== 以下由 tools/gen_captions.py');end=text.index('\n',text.index('    // ==== 生成区结束 ====',start))+1
    RTL.write_text(text[:start]+'\n'.join(lines)+text[end:],encoding='utf-8')
    print(f'Generated {len(captions)} captions, {len(chars)} Chinese glyphs; EN lengths {[len(s) for s in en]}')

if __name__=='__main__':main()
