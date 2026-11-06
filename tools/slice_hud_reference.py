"""Recorta os sprites do HUD direto da imagem de referência (assets/hud_ref/reference.webp, com alfa) e gera PNGs
transparentes e ampliados em assets/hud_sprites/. Fundo removido por diferença de cor para o fundo local da peça.
Uso: python tools/slice_hud_reference.py"""
import os

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "hud_ref", "reference.webp")
OUT = os.path.join(ROOT, "assets", "hud_sprites")
SCALE = 4

# nome: (x0, y0, x1, y1, tipo)  tipo: "matte" tira o fundo; "photo" mantém retangular
BOXES = {
    "logo": (50, 25, 132, 105, "white"),
    "star_level": (332, 40, 386, 92, "matte"),
    "dollar": (640, 38, 694, 94, "matte"),
    "trophy_top": (884, 38, 940, 94, "matte"),
    "bell": (1452, 34, 1500, 80, "white"),
    "gear": (1530, 32, 1578, 76, "white"),
    "exit": (1600, 32, 1646, 76, "white"),
    "clipboard": (46, 198, 94, 252, "matte"),
    "cap": (44, 284, 98, 336, "white"),
    "store": (42, 364, 96, 414, "white"),
    "box": (44, 444, 96, 496, "white"),
    "person": (46, 518, 94, 572, "white"),
    "b_clipboard": (588, 810, 628, 858, "white"),
    "b_cap": (704, 814, 760, 860, "white"),
    "b_cart": (822, 812, 876, 862, "white"),
    "b_box": (930, 814, 982, 860, "white"),
    "b_trophy": (1038, 812, 1092, 862, "matte"),
    "car_icon": (1214, 370, 1260, 404, "white"),
    "people": (1214, 616, 1260, 654, "white"),
    "check_ok": (42, 662, 98, 720, "matte"),
    "star_gold": (114, 698, 146, 726, "matte"),
    "chart": (1578, 672, 1640, 774, "matte"),
    "photo_hood": (1482, 416, 1646, 584, "photo"),
    "photo_shop": (1214, 668, 1358, 774, "photo"),
    "photo_blue": (1214, 170, 1382, 291, "photo"),
}


def border_color(arr):
    h, w, _ = arr.shape
    ring = np.concatenate([arr[0, :, :3], arr[-1, :, :3], arr[:, 0, :3], arr[:, -1, :3]])
    return np.median(ring, axis=0)


def matte(crop):
    arr = np.array(crop.convert("RGBA")).astype(np.float32)
    bg = border_color(arr)
    diff = np.abs(arr[:, :, :3] - bg).max(axis=2)
    alpha = np.clip((diff - 22.0) / (80.0 - 22.0), 0, 1)
    out = arr.copy()
    out[:, :, 3] = alpha * 255
    return Image.fromarray(out.astype(np.uint8), "RGBA")


def white(crop):
    """Glifo branco sobre fundo escuro/azul: alfa pela 'brancura' (menor canal)."""
    arr = np.array(crop.convert("RGBA")).astype(np.float32)
    minc = arr[:, :, :3].min(axis=2)
    alpha = np.clip((minc - 110.0) / (215.0 - 110.0), 0, 1)
    out = np.zeros_like(arr)
    out[:, :, :3] = 255
    out[:, :, 3] = alpha * 255
    return Image.fromarray(out.astype(np.uint8), "RGBA")


def main():
    os.makedirs(OUT, exist_ok=True)
    ref = Image.open(SRC).convert("RGBA")
    for name, (x0, y0, x1, y1, kind) in BOXES.items():
        crop = ref.crop((x0, y0, x1, y1))
        if kind == "matte":
            crop = matte(crop)
        elif kind == "white":
            crop = white(crop)
        crop = crop.resize((crop.width * SCALE, crop.height * SCALE), Image.LANCZOS)
        if kind in ("matte", "white"):
            a = crop.split()[3].filter(ImageFilter.GaussianBlur(1.2))
            crop.putalpha(a)
            bbox = crop.getbbox()
            if bbox:
                pad = 8
                crop = crop.crop((max(0, bbox[0] - pad), max(0, bbox[1] - pad), min(crop.width, bbox[2] + pad), min(crop.height, bbox[3] + pad)))
        crop.save(os.path.join(OUT, name + ".png"))
    print("sprites:", len(BOXES), "->", OUT)


if __name__ == "__main__":
    main()
