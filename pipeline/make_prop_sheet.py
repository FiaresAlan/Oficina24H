"""Folha de contato com rótulo. python pipeline/make_prop_sheet.py <pasta_png> <saida.png> [colunas]"""
import glob, os, sys
from PIL import Image, ImageDraw

src, out = sys.argv[1], sys.argv[2]
cols = int(sys.argv[3]) if len(sys.argv) > 3 else 5
files = sorted(glob.glob(os.path.join(src, "*.png")))
W, H = 320, 240
rows = (len(files) + cols - 1) // cols
sheet = Image.new("RGB", (cols * W, rows * (H + 16)), (30, 30, 30))
d = ImageDraw.Draw(sheet)
for i, f in enumerate(files):
    x, y = (i % cols) * W, (i // cols) * (H + 16)
    sheet.paste(Image.open(f).convert("RGB"), (x, y + 16))
    d.text((x + 3, y + 2), os.path.splitext(os.path.basename(f))[0][:48], fill=(255, 255, 0))
sheet.save(out)
print(out, len(files))
