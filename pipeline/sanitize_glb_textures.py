"""Sanitiza texturas embutidas em GLBs ANTES de enviar ao Roblox (regras de comunidade: nada de links, QR code, redes sociais,
assinaturas/handles de terceiros, placas legíveis reais). Uso: python pipeline/sanitize_glb_textures.py <glb_in> <glb_out> <pasta_de_referencias>

Regras (decididas por inspeção visual das texturas, ver docs/ORIGEM_ASSETS.md):
  "plate"  -> a imagem inteira vira uma placa genérica fictícia (sem bandeira, sem texto pequeno)
  "box"    -> retângulo relativo (x0,y0,x1,y1 em 0..1) preenchido com a cor do entorno (apaga assinatura/crédito)
Imagens sem regra passam intactas. Qualquer carro novo precisa de inspeção visual antes de entrar aqui.
"""
import io, json, os, struct, sys
from PIL import Image, ImageDraw, ImageFont

# Regras por CONTEÚDO (não por posição: a ordem das imagens exportadas muda a cada tratamento). Cada regra aponta para uma
# imagem de referência já inspecionada (pasta de referências, arquivos "<Carro>__<n>.png|jpg") e vale para toda imagem do GLB
# que se pareça com ela (miniatura 32x32, diferença média < LIMIAR).
RULES = {
    "Picape_Toro": [("Picape_Toro__1.png", ["plate"])],
    "Picape_Ram": [("Picape_Ram__2.jpg", ["plate"])],
    "Picape_L200": [("Picape_L200__1.png", ["plate"])],
    "SUV_EcoSport": [("SUV_EcoSport__3.png", ["plate"])],
    "SUV_Velar": [("SUV_Velar__0.png", ["plate"])],
    "Sedan_Voyage": [("Sedan_Voyage__7.png", ["plate"])],
    "SUV_Wrangler": [("SUV_Wrangler__0.png", [("box", 0.78, 0.0, 1.0, 0.13)])],
    "Sedan_AudiA6": [("Sedan_AudiA6__1.png", [("box", 0.70, 0.92, 0.95, 0.985)])],
    "Hatch_Yaris": [("Hatch_Yaris__1.png", [("box", 0.56, 0.88, 0.83, 0.985)]), ("Hatch_Yaris__2.jpg", [("box", 0.0, 0.0, 0.24, 0.14)])],
    "Sedan_City": [("Sedan_City__1.jpg", ["flat"]), ("Sedan_City__2.jpg", [("box", 0.72, 0.40, 1.0, 0.80)])],
    "Hatch_Prius": [("Hatch_Prius__8.jpg", ["flat"]), ("Hatch_Prius__0.png", [("box", 0.0, 0.62, 0.55, 0.96), ("box", 0.55, 0.52, 1.0, 0.82), ("box", 0.6, 0.18, 1.0, 0.52)])],
}
LIMIAR = 14.0


def thumb(im):
    return list(im.convert("L").resize((32, 32)).getdata())


def similar(a, b):
    return sum(abs(x - y) for x, y in zip(a, b)) / len(a)


def generic_plate(size):
    w, h = size
    im = Image.new("RGB", (w, h), (242, 242, 242))
    d = ImageDraw.Draw(im)
    d.rectangle([2, 2, w - 3, h - 3], outline=(30, 30, 30), width=max(3, h // 32))
    try:
        font = ImageFont.truetype("arialbd.ttf", int(h * 0.5))
    except Exception:
        font = ImageFont.load_default()
    text = "ABC1D23"
    bb = d.textbbox((0, 0), text, font=font)
    d.text(((w - (bb[2] - bb[0])) / 2 - bb[0], (h - (bb[3] - bb[1])) / 2 - bb[1]), text, fill=(25, 25, 25), font=font)
    return im


def paint_out(im, box):
    w, h = im.size
    x0, y0, x1, y1 = int(box[0] * w), int(box[1] * h), int(box[2] * w), int(box[3] * h)
    ring = 6
    px = im.load()
    samples = []
    for x in range(max(0, x0 - ring), min(w, x1 + ring)):
        for y in (max(0, y0 - ring), min(h - 1, y1 + ring)):
            samples.append(px[x, y])
    for y in range(max(0, y0 - ring), min(h, y1 + ring)):
        for x in (max(0, x0 - ring), min(w - 1, x1 + ring)):
            samples.append(px[x, y])
    n = len(samples)
    mean = tuple(int(sum(s[i] for s in samples) / n) for i in range(len(samples[0])))
    ImageDraw.Draw(im).rectangle([x0, y0, x1, y1], fill=mean)


def process(path, out_path, rules, refs_dir):
    with open(path, "rb") as f:
        head = f.read(12)
        clen, _ = struct.unpack("<II", f.read(8))
        j = json.loads(f.read(clen).decode("utf-8"))
        blen, _ = struct.unpack("<II", f.read(8))
        blob = bytearray(f.read(blen))
    refs = [(thumb(Image.open(os.path.join(refs_dir, ref))), ops) for ref, ops in rules]
    changed = 0
    for idx, img in enumerate(j.get("images", [])):
        if "bufferView" not in img:
            continue
        bv = j["bufferViews"][img["bufferView"]]
        data = bytes(blob[bv.get("byteOffset", 0): bv.get("byteOffset", 0) + bv["byteLength"]])
        im = Image.open(io.BytesIO(data))
        if min(im.size) < 128:
            continue  # mini-texturas de cor lisa não são arte com marca
        is_png = img.get("mimeType", "") == "image/png" or im.format == "PNG"
        t = thumb(im)
        ops = None
        for rt, rops in refs:
            if similar(t, rt) < LIMIAR:
                ops = rops
                break
        if ops is None and not is_png:
            continue  # JPEG sem regra: fica como está
        mode = "RGBA" if im.mode in ("RGBA", "LA", "P") else "RGB"
        im = im.convert(mode)
        for op in (ops or []):
            if op == "plate":
                im = generic_plate(im.size).convert(mode)
            elif op == "flat":
                im = Image.new(mode, im.size, (90, 90, 90, 255) if mode == "RGBA" else (90, 90, 90))  # atlas só de emblemas
            else:
                paint_out(im, op[1:])
        opaque = mode == "RGB" or im.getchannel("A").getextrema()[0] >= 250
        buf = io.BytesIO()
        if opaque:
            im.convert("RGB").save(buf, "JPEG", quality=88, optimize=True)
            img["mimeType"] = "image/jpeg"
        else:
            im.save(buf, "PNG", optimize=True)
            img["mimeType"] = "image/png"
        new = buf.getvalue()
        if ops is None and len(new) >= len(data):
            continue  # a conversão não compensou
        while len(blob) % 4:
            blob.append(0)
        off = len(blob)
        blob.extend(new)
        j["bufferViews"].append({"buffer": 0, "byteOffset": off, "byteLength": len(new)})
        img["bufferView"] = len(j["bufferViews"]) - 1
        changed += 1
    # compacta: mantém só os bufferViews realmente referenciados (accessors e imagens) e reindexa
    used = set()
    for acc in j.get("accessors", []):
        if "bufferView" in acc:
            used.add(acc["bufferView"])
    for im2 in j.get("images", []):
        if "bufferView" in im2:
            used.add(im2["bufferView"])
    remap, nbv, nblob = {}, [], bytearray()
    for i, bv in enumerate(j["bufferViews"]):
        if i not in used:
            continue
        while len(nblob) % 4:
            nblob.append(0)
        start = bv.get("byteOffset", 0)
        chunk = bytes(blob[start: start + bv["byteLength"]])
        nv = dict(bv)
        nv["byteOffset"] = len(nblob)
        nblob.extend(chunk)
        remap[i] = len(nbv)
        nbv.append(nv)
    for acc in j.get("accessors", []):
        if "bufferView" in acc:
            acc["bufferView"] = remap[acc["bufferView"]]
    for im2 in j.get("images", []):
        if "bufferView" in im2:
            im2["bufferView"] = remap[im2["bufferView"]]
    j["bufferViews"] = nbv
    blob = nblob
    while len(blob) % 4:
        blob.append(0)
    j["buffers"][0]["byteLength"] = len(blob)
    js = json.dumps(j, separators=(",", ":")).encode("utf-8")
    while len(js) % 4:
        js += b" "
    total = 12 + 8 + len(js) + 8 + len(blob)
    with open(out_path, "wb") as f:
        f.write(b"glTF" + struct.pack("<II", 2, total))
        f.write(struct.pack("<II", len(js), 0x4E4F534A) + js)
        f.write(struct.pack("<II", len(blob), 0x004E4942) + bytes(blob))
    return changed


src, out, refs_dir = sys.argv[1], sys.argv[2], sys.argv[3]
os.makedirs(out, exist_ok=True)
for f in sorted(os.listdir(src)):
    if not f.endswith(".glb"):
        continue
    name = f[:-4]
    n = process(os.path.join(src, f), os.path.join(out, f), RULES.get(name, []), refs_dir)
    print("%-16s imagens alteradas: %d" % (name, n))
