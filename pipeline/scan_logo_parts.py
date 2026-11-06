"""Procura, em todos os GLBs da biblioteca, modelos cujos emblemas/logos são PEÇAS NOMEADAS (apagáveis sem estragar o carro).
python pipeline/scan_logo_parts.py <pasta_assets> <inventario.csv> <saida.csv>"""
import csv, json, os, re, struct, sys

root, inv, out = sys.argv[1], sys.argv[2], sys.argv[3]
RX = re.compile(r"logo|emblem|emblema|badge|logotipo|simbolo|símbolo|brand|marca|nameplate|lettering|letters|numberplate|license|licence|placa|plate", re.I)
rows = list(csv.DictReader(open(inv, encoding="utf-8")))
res = []
for r in rows:
    path = os.path.join(root, r["id"] + ".glb")
    try:
        with open(path, "rb") as f:
            f.read(12)
            clen, _ = struct.unpack("<II", f.read(8))
            j = json.loads(f.read(clen).decode("utf-8"))
    except Exception:
        continue
    names = [n.get("name", "") for n in j.get("nodes", [])] + [m.get("name", "") for m in j.get("materials", [])]
    hits = sorted({n for n in names if RX.search(n)})
    r2 = dict(r)
    r2["logo_parts"] = len(hits)
    r2["logo_names"] = "|".join(hits)[:200]
    res.append(r2)
with open(out, "w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, fieldnames=list(res[0].keys()))
    w.writeheader()
    w.writerows(res)
print("modelos:", len(res), "| com peças de logo nomeadas:", sum(1 for r in res if r["logo_parts"] > 0))
