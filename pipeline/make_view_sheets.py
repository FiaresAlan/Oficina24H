"""Monta uma imagem por carro com as 3 vistas e grade de coordenadas (para marcar pontos em brand_patches.json).
Uso: python pipeline/make_view_sheets.py <pasta_views> <pasta_saida>   (cada painel 780x495; coordenadas locais do painel)"""
import os, sys
from PIL import Image, ImageDraw

PW, PH = 780, 495
src, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
names = sorted({f.rsplit("_", 1)[0] for f in os.listdir(src) if f.endswith(".png")})
for n in names:
    sheet = Image.new("RGB", (PW * 2, PH * 2), (30, 30, 30))
    d = ImageDraw.Draw(sheet)
    labels = {0: ("FRENTE (vista 0)", 0, 0), 1: ("TRASEIRA (vista 1)", PW, 0), 2: ("LADO (vista 2)", 0, PH)}
    for k, (label, ox, oy) in labels.items():
        p = os.path.join(src, "%s_%d.png" % (n, k))
        if not os.path.exists(p):
            continue
        sheet.paste(Image.open(p).convert("RGB"), (ox, oy))
        for x in range(100, PW, 100):
            d.line([(ox + x, oy), (ox + x, oy + PH)], fill=(255, 255, 0), width=1)
            d.text((ox + x + 2, oy + 2), str(x), fill=(255, 255, 0))
        for y in range(100, PH, 100):
            d.line([(ox, oy + y), (ox + PW, oy + y)], fill=(0, 255, 255), width=1)
            d.text((ox + 2, oy + y + 2), str(y), fill=(0, 255, 255))
        d.text((ox + 6, oy + PH - 14), "%s  %s" % (n, label), fill=(255, 255, 255))
    sheet.save(os.path.join(out, n + ".png"))
print("folhas:", len(names))
