"""Recorta os ícones e imagens dos cinco painéis da imagem de referência (assets/hud_ref/panels_reference.webp) para
assets/hud_sprites/pn_*.png (mesmo método de slice_hud_reference.py). Uso: python tools/slice_panel_reference.py"""
import os

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "hud_ref", "panels_reference.webp")
OUT = os.path.join(ROOT, "assets", "hud_sprites")
SCALE = 4

W, M, P = "white", "matte", "photo"
BOXES = {
    "h_store": ((40, 28, 98, 84), W), "h_box": ((584, 26, 640, 80), M), "h_cart": ((1072, 28, 1128, 82), M),
    "h_cap": ((40, 518, 102, 574), M), "h_clip": ((842, 516, 890, 570), W),
    "t_home": ((46, 98, 76, 126), W), "t_star": ((176, 98, 202, 126), W), "t_clock": ((298, 98, 324, 126), W),
    "t_trophy": ((412, 98, 440, 126), W), "t_gear": ((594, 98, 626, 126), W), "t_wrench": ((720, 98, 748, 126), W),
    "t_bottle": ((876, 98, 904, 126), W), "t_chest": ((1352, 98, 1380, 126), W), "t_tag": ((1500, 98, 1526, 126), W),
    "search": ((584, 146, 612, 172), W), "chev": ((1000, 148, 1022, 168), W),
    "o_clock": ((892, 584, 926, 614), W), "o_wrench": ((1146, 584, 1180, 614), W), "o_check": ((1442, 584, 1474, 614), M),
    "photo_shop": ((35, 155, 232, 356), P), "pencil": ((194, 318, 226, 348), W), "p_star": ((256, 244, 296, 284), M),
    "p_people": ((258, 298, 296, 336), W), "p_refresh": ((258, 348, 296, 384), W), "empty_box": ((768, 240, 842, 302), M),
    "c_motor": ((1078, 148, 1108, 178), W), "c_susp": ((1080, 194, 1110, 224), W), "c_brake": ((1078, 240, 1108, 270), W),
    "c_elec": ((1080, 286, 1110, 314), W), "c_tire": ((1078, 330, 1110, 360), W), "c_body": ((1078, 370, 1110, 396), W),
    "c_misc": ((1078, 402, 1110, 430), W), "c_cart": ((1078, 442, 1110, 470), W),
    "prod_plug": ((1384, 148, 1480, 228), P), "prod_battery": ((1268, 290, 1336, 376), P),
    "s_motor": ((70, 598, 120, 646), W), "s_susp": ((70, 656, 120, 706), W), "s_wheel": ((70, 714, 120, 764), W),
    "s_elec": ((70, 772, 120, 822), W), "s_paint": ((70, 828, 120, 880), W), "photo_engine": ((370, 582, 510, 714), P),
    "star_o": ((1338, 638, 1370, 668), M), "chat": ((1482, 664, 1512, 692), W), "check_s": ((1478, 710, 1508, 738), M),
    "hourglass": ((1056, 694, 1086, 722), W), "car_empty": ((1220, 780, 1284, 830), M),
}


def matte(crop):
    arr = np.array(crop.convert("RGBA")).astype(np.float32)
    h, w, _ = arr.shape
    ring = np.concatenate([arr[0, :, :3], arr[-1, :, :3], arr[:, 0, :3], arr[:, -1, :3]])
    bg = np.median(ring, axis=0)
    diff = np.abs(arr[:, :, :3] - bg).max(axis=2)
    out = arr.copy()
    out[:, :, 3] = np.clip((diff - 22.0) / 58.0, 0, 1) * 255
    return Image.fromarray(out.astype(np.uint8), "RGBA")


def white(crop):
    arr = np.array(crop.convert("RGBA")).astype(np.float32)
    minc = arr[:, :, :3].min(axis=2)
    out = np.zeros_like(arr)
    out[:, :, :3] = 255
    out[:, :, 3] = np.clip((minc - 110.0) / 105.0, 0, 1) * 255
    return Image.fromarray(out.astype(np.uint8), "RGBA")


def main():
    ref = Image.open(SRC).convert("RGBA")
    for name, (box, kind) in BOXES.items():
        crop = ref.crop(box)
        crop = matte(crop) if kind == M else white(crop) if kind == W else crop
        crop = crop.resize((crop.width * SCALE, crop.height * SCALE), Image.LANCZOS)
        if kind != P:
            crop.putalpha(crop.split()[3].filter(ImageFilter.GaussianBlur(1.2)))
            bbox = crop.getbbox()
            if bbox:
                crop = crop.crop((max(0, bbox[0] - 8), max(0, bbox[1] - 8), min(crop.width, bbox[2] + 8), min(crop.height, bbox[3] + 8)))
        crop.save(os.path.join(OUT, "pn_" + name + ".png"))
    print("sprites:", len(BOXES))


if __name__ == "__main__":
    main()
