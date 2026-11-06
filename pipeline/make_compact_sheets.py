"""Folha compacta (frente + traseira de vários carros) para conferir remoção de marcas. python pipeline/make_compact_sheets.py <pasta_views> <saida_prefixo> [carros_por_folha]"""
import os, sys
from PIL import Image, ImageDraw

src, prefix = sys.argv[1], sys.argv[2]
per = int(sys.argv[3]) if len(sys.argv) > 3 else 8
names = sorted({f.rsplit("_", 1)[0] for f in os.listdir(src) if f.endswith(".png")})
W, H = 520, 330
for s in range(0, len(names), per):
    chunk = names[s:s + per]
    sheet = Image.new("RGB", (W * 3, (H + 16) * len(chunk)), (30, 30, 30))
    d = ImageDraw.Draw(sheet)
    for r, n in enumerate(chunk):
        for k in range(3):
            p = os.path.join(src, "%s_%d.png" % (n, k))
            if os.path.exists(p):
                sheet.paste(Image.open(p).convert("RGB").resize((W, H)), (k * W, r * (H + 16) + 16))
        d.text((4, r * (H + 16) + 2), n, fill=(255, 255, 0))
    out = "%s_%d.png" % (prefix, s // per + 1)
    sheet.save(out)
    print(out, len(chunk))
