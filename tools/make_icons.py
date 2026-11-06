"""Gera os ícones do HUD (PNG 256x256, vetor desenhado por nós: sem licença de terceiros).
Glifo branco com contorno azul-marinho escuro, no estilo da referência. Uso: python make_icons.py <pasta_saida>"""
import math
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

S = 1024  # supersampling
OUT = 256
NAVY = (14, 30, 66, 255)
WHITE = (255, 255, 255, 255)
GOLD = (255, 190, 40, 255)


def canvas():
    return Image.new("RGBA", (S, S), (0, 0, 0, 0))


def finish(glyph, outline=34, name="icon", out_dir=".", shadow=True):
    """Aplica contorno escuro (dilatação do alfa) sob o glifo e salva reduzido."""
    alpha = glyph.split()[3]
    size = outline * 2 + 1
    grown = alpha.filter(ImageFilter.MaxFilter(size if size % 2 else size + 1))
    base = Image.new("RGBA", (S, S), NAVY)
    base.putalpha(grown)
    if shadow:
        sh = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        sh.paste(Image.new("RGBA", (S, S), (0, 0, 0, 110)), (0, 18), grown)
        base = Image.alpha_composite(sh, base)
    result = Image.alpha_composite(base, glyph)
    result = result.resize((OUT, OUT), Image.LANCZOS)
    result.save(os.path.join(out_dir, name + ".png"))


def rrect(d, box, r, fill):
    d.rounded_rectangle(box, radius=r, fill=fill)


def clipboard():
    im = canvas(); d = ImageDraw.Draw(im)
    rrect(d, (200, 150, 824, 940), 90, WHITE)
    rrect(d, (340, 70, 684, 260), 60, WHITE)
    d.ellipse((472, 110, 552, 190), fill=NAVY)
    for y in (400, 580, 760):
        rrect(d, (290, y, 370, y + 80), 16, NAVY)
        rrect(d, (440, y + 10, 740, y + 70), 28, NAVY)
    return im


def cap():
    im = canvas(); d = ImageDraw.Draw(im)
    d.polygon([(512, 190), (980, 420), (512, 650), (44, 420)], fill=WHITE)
    d.polygon([(250, 560), (512, 690), (774, 560), (774, 770), (512, 900), (250, 770)], fill=WHITE)
    d.line([(250, 560), (512, 690), (774, 560)], fill=NAVY, width=28)
    d.line([(930, 450), (930, 740)], fill=WHITE, width=40)
    d.ellipse((890, 720, 970, 800), fill=WHITE)
    return im


def shop():
    im = canvas(); d = ImageDraw.Draw(im)
    rrect(d, (150, 440, 874, 900), 40, WHITE)
    rrect(d, (400, 580, 624, 900), 20, NAVY)
    rrect(d, (200, 520, 350, 680), 16, NAVY)
    rrect(d, (674, 520, 824, 680), 16, NAVY)
    # toldo listrado
    d.polygon([(190, 150), (834, 150), (970, 440), (54, 440)], fill=WHITE)
    for i in range(1, 6, 2):
        x0 = 54 + i * 152.7
        d.polygon([(190 + i * 107.3, 150), (190 + (i + 1) * 107.3, 150), (x0 + 152.7, 440), (x0, 440)], fill=NAVY)
    for i in range(6):
        cx = 54 + 76 + i * 152.7
        d.ellipse((cx - 76, 380, cx + 76, 520), fill=WHITE if i % 2 == 0 else NAVY)
    return im


def box():
    im = canvas(); d = ImageDraw.Draw(im)
    d.polygon([(512, 90), (950, 320), (512, 540), (74, 320)], fill=WHITE)
    d.polygon([(74, 380), (490, 600), (490, 950), (74, 740)], fill=WHITE)
    d.polygon([(534, 600), (950, 380), (950, 740), (534, 950)], fill=WHITE)
    d.polygon([(400, 150), (512, 95), (700, 190), (590, 250)], fill=NAVY)  # fita
    d.polygon([(260, 280), (380, 225), (560, 310), (440, 365)], fill=NAVY)
    return im


def person():
    im = canvas(); d = ImageDraw.Draw(im)
    d.ellipse((312, 90, 712, 490), fill=WHITE)
    d.pieslice((110, 560, 914, 1260), 180, 360, fill=WHITE)
    d.rectangle((110, 920, 914, 940), fill=WHITE)
    return im


def trophy():
    im = canvas(); d = ImageDraw.Draw(im)
    d.rectangle((260, 140, 764, 400), fill=WHITE)
    d.pieslice((260, 140, 764, 660), 0, 180, fill=WHITE)
    d.arc((90, 190, 330, 450), 90, 270, fill=WHITE, width=56)
    d.arc((694, 190, 934, 450), 270, 90, fill=WHITE, width=56)
    d.rectangle((450, 600, 574, 790), fill=WHITE)
    rrect(d, (300, 780, 724, 910), 40, WHITE)
    star = [(512 + 90 * math.cos(math.radians(a)), 330 + 90 * math.sin(math.radians(a))) for a in range(-90, 270, 72)]
    pts = []
    for i in range(10):
        r = 110 if i % 2 == 0 else 46
        a = math.radians(-90 + i * 36)
        pts.append((512 + r * math.cos(a), 330 + r * math.sin(a)))
    d.polygon(pts, fill=NAVY)
    return im


def bell():
    im = canvas(); d = ImageDraw.Draw(im)
    d.ellipse((512 - 50, 90, 512 + 50, 190), fill=WHITE)
    d.pieslice((260, 170, 764, 700), 180, 360, fill=WHITE)
    d.polygon([(260, 435), (764, 435), (850, 770), (174, 770)], fill=WHITE)
    rrect(d, (150, 740, 874, 840), 50, WHITE)
    d.ellipse((432, 830, 592, 990), fill=WHITE)
    return im


def gear():
    im = canvas(); d = ImageDraw.Draw(im)
    for k in range(8):
        a = math.radians(k * 45)
        c, s_ = math.cos(a), math.sin(a)
        def pt(x, y):
            return (512 + x * c - y * s_, 512 + x * s_ + y * c)
        d.polygon([pt(-100, -450), pt(100, -450), pt(130, -250), pt(-130, -250)], fill=WHITE)
    d.ellipse((152, 152, 872, 872), fill=WHITE)
    d.ellipse((372, 372, 652, 652), fill=NAVY)
    return im


def exit_icon():
    im = canvas(); d = ImageDraw.Draw(im)
    d.line([(560, 140), (200, 140), (200, 880), (560, 880)], fill=WHITE, width=76, joint="curve")
    rrect(d, (250, 470, 780, 554), 40, WHITE)
    d.polygon([(740, 320), (980, 512), (740, 704)], fill=WHITE)
    return im


def grid():
    im = canvas(); d = ImageDraw.Draw(im)
    for x in (130, 540):
        for y in (130, 540):
            rrect(d, (x, y, x + 354, y + 354), 70, WHITE)
    return im


def car():
    im = canvas(); d = ImageDraw.Draw(im)
    d.polygon([(110, 640), (150, 480), (330, 400), (420, 250), (700, 250), (810, 400), (920, 440), (940, 640)], fill=WHITE)
    d.polygon([(450, 300), (670, 300), (750, 400), (400, 400)], fill=NAVY)
    for cx in (300, 740):
        d.ellipse((cx - 110, 590, cx + 110, 810), fill=NAVY)
        d.ellipse((cx - 70, 630, cx + 70, 770), fill=WHITE)
    return im


def people():
    im = canvas(); d = ImageDraw.Draw(im)
    for cx, r, top in ((330, 130, 200), (700, 150, 160)):
        d.ellipse((cx - r, top, cx + r, top + 2 * r), fill=WHITE)
        d.pieslice((cx - r * 2, top + 2 * r + 60, cx + r * 2, top + 2 * r + 60 + r * 4), 180, 360, fill=WHITE)
    return im


def star():
    im = canvas(); d = ImageDraw.Draw(im)
    pts = []
    for i in range(10):
        r = 450 if i % 2 == 0 else 190
        a = math.radians(-90 + i * 36)
        pts.append((512 + r * math.cos(a), 540 + r * math.sin(a)))
    d.polygon(pts, fill=GOLD)
    return im


def coin():
    im = canvas(); d = ImageDraw.Draw(im)
    d.ellipse((90, 90, 934, 934), fill=GOLD)
    d.ellipse((190, 190, 834, 834), outline=(255, 232, 150, 255), width=34)
    try:
        font = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 520)
        d.text((512, 520), "$", font=font, fill=(150, 90, 0, 255), anchor="mm")
    except OSError:
        d.rectangle((470, 300, 554, 720), fill=(150, 90, 0, 255))
    return im


ICONS = {
    "orders": clipboard, "skills": cap, "shop": shop, "stock": box, "profile": person, "ranking": trophy,
    "bell": bell, "gear": gear, "exit": exit_icon, "grid": grid, "car": car, "people": people, "star": star, "coin": coin,
}

if __name__ == "__main__":
    out_dir = sys.argv[1] if len(sys.argv) > 1 else "icons"
    os.makedirs(out_dir, exist_ok=True)
    for name, fn in ICONS.items():
        finish(fn(), name=name, out_dir=out_dir)
    print("ok", len(ICONS), "ícones em", out_dir)
