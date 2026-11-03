# -*- coding: utf-8 -*-
"""把任意中文短句转换成 16x16 点阵，并输出可直接粘贴进 osd_overlay.v 的 Verilog。

用法:
    python gen_zh_font.py "黄山四绝 奇松 怪石 云海 温泉"
    python gen_zh_font.py --font C:/Windows/Fonts/simhei.ttf "你好世界"

输出两部分:
  1) zh_bitmap_row 里 4'dN: bmp = 256'h...;  的 case 项（去重后的字形表）
  2) zh_slot_of 里 4'dM: zh_slot_of = 4'dN; 的槽位映射（每个字格对应哪个字形）

注意: 槽位数必须 <= 16（即最多 16 个字格，含空格），对应画面宽度 16*16=256 像素。
"""
import sys
from PIL import Image, ImageDraw, ImageFont

DEFAULT_FONTS = [
    r"C:\Windows\Fonts\simsun.ttc",
    r"C:\Windows\Fonts\simhei.ttf",
    r"C:\Windows\Fonts\msyh.ttc",
]
BLANK_INDEX = 12          # 空白字模占用的下标，与 RTL 保持一致


def pick_font(path):
    for cand in ([path] if path else DEFAULT_FONTS):
        if cand and cand != "None":
            try:
                return ImageFont.truetype(cand, 16)
            except Exception:
                continue
    raise SystemExit("找不到可用的中文字体，请用 --font 指定一个 .ttf/.ttc")


def glyph(font, ch):
    img = Image.new("L", (16, 16), 0)
    ImageDraw.Draw(img).text((-1, -1), ch, font=font, fill=255)
    rows = []
    for y in range(16):
        v = 0
        for x in range(16):
            if img.getpixel((x, y)) >= 110:
                v |= 1 << (15 - x)
        rows.append(v)
    return rows


def main():
    args = sys.argv[1:]
    font_path = None
    if "--font" in args:
        i = args.index("--font")
        font_path = args[i + 1]
        del args[i:i + 2]
    text = args[0] if args else "黄山四绝 奇松 怪石 云海 温泉"
    if len(text) > 16:
        raise SystemExit("最多 16 个字格，当前 %d 个" % len(text))

    font = pick_font(font_path)
    uniq = []
    for ch in text:
        if ch != " " and ch not in uniq:
            uniq.append(ch)
    if len(uniq) > BLANK_INDEX:
        raise SystemExit("不同汉字超过 %d 个，请缩短字幕" % BLANK_INDEX)

    rows = {ch: glyph(font, ch) for ch in uniq}

    print("// ---- 粘贴到 zh_bitmap_row 的 case 内 ----")
    for i, ch in enumerate(uniq):
        v = 0
        for r in rows[ch]:
            v = (v << 16) | r
        print("                4'd%-2d: bmp = 256'h%064x; // %s" % (i, v, ch))
    print("                default: bmp = 256'h0;")
    print()
    print("// ---- 粘贴到 zh_slot_of 的 case 内（%d 个字格）----" % len(text))
    for i, ch in enumerate(text):
        idx = BLANK_INDEX if ch == " " else uniq.index(ch)
        print("                4'd%-2d: zh_slot_of = 4'd%d;   // %s"
              % (i, idx, ch if ch != " " else "空"))
    for i in range(len(text), 16):
        print("                4'd%-2d: zh_slot_of = 4'd%d;   // 空" % (i, BLANK_INDEX))
    print("                default: zh_slot_of = 4'd%d;" % BLANK_INDEX)


if __name__ == "__main__":
    main()
