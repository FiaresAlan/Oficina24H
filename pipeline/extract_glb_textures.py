"""Extrai as texturas embutidas de GLBs para inspeção (QR code, links, textos de outras plataformas violam as regras do Roblox).
Uso: python pipeline/extract_glb_textures.py <pasta_com_glb> <pasta_saida> [--qr]
Gera <saida>/<modelo>__<n>.<ext> e, com --qr, tenta detectar QR codes (OpenCV, se instalado).
"""
import json, os, struct, sys, glob

src, out = sys.argv[1], sys.argv[2]
want_qr = "--qr" in sys.argv
os.makedirs(out, exist_ok=True)
cv2 = None
if want_qr:
    try:
        import cv2  # type: ignore
        import numpy as np  # type: ignore
    except Exception as e:
        print("OpenCV indisponível:", e)
        cv2 = None
total = 0
for path in sorted(glob.glob(os.path.join(src, "*.glb"))):
    name = os.path.splitext(os.path.basename(path))[0]
    with open(path, "rb") as f:
        f.read(12)
        clen, _ = struct.unpack("<II", f.read(8))
        j = json.loads(f.read(clen).decode("utf-8"))
        blen, _ = struct.unpack("<II", f.read(8))
        blob = f.read(blen)
    for i, img in enumerate(j.get("images", [])):
        bv = j["bufferViews"][img["bufferView"]] if "bufferView" in img else None
        if bv is None:
            continue
        data = blob[bv.get("byteOffset", 0): bv.get("byteOffset", 0) + bv["byteLength"]]
        ext = "png" if img.get("mimeType", "").endswith("png") else "jpg"
        p = os.path.join(out, "%s__%d.%s" % (name, i, ext))
        open(p, "wb").write(data)
        total += 1
        if cv2 is not None:
            arr = cv2.imdecode(np.frombuffer(data, np.uint8), cv2.IMREAD_COLOR)
            if arr is not None:
                val, pts, _ = cv2.QRCodeDetector().detectAndDecode(arr)
                if pts is not None or val:
                    print("POSSIVEL QR:", p, repr(val)[:80])
print("texturas extraídas:", total)
