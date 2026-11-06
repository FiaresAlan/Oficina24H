"""Lista as mini-texturas (<=16 px) de um GLB com a cor de cada uma. python pipeline/probe_flat_colors.py <glb> [...]"""
import io, json, struct, sys
from PIL import Image

for path in sys.argv[1:]:
    with open(path, "rb") as f:
        f.read(12)
        clen, _ = struct.unpack("<II", f.read(8))
        j = json.loads(f.read(clen).decode("utf-8"))
        blen, _ = struct.unpack("<II", f.read(8))
        blob = f.read(blen)
    print(path)
    for i, img in enumerate(j.get("images", [])):
        bv = j["bufferViews"][img["bufferView"]]
        data = blob[bv.get("byteOffset", 0): bv.get("byteOffset", 0) + bv["byteLength"]]
        im = Image.open(io.BytesIO(data))
        if max(im.size) <= 16:
            print("   img", i, im.size, im.mode, im.convert("RGBA").getpixel((1, 1)))
