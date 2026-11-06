"""Baixa kits CC0 de bairro: Kenney (zip pelo botão da página) e Shuriken (rota /download). Só arquivos .zip/.glb de downloads
GRATUITOS; nada é executado, só extraído em pasta própria. python pipeline/fetch_kits.py <pasta_saida>"""
import os, re, sys, urllib.request, zipfile, io

OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)
UA = {"User-Agent": "Mozilla/5.0 (compatible; asset-research)"}


def get(url, binary=False):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=120) as r:
        data = r.read()
        return data if binary else data.decode("utf-8", "replace")


for name in ():
    html = get("https://kenney.nl/assets/" + name)
    links = set(re.findall(r"https?://[^\"'\s<>]+\.zip", html)) | set("https://kenney.nl" + m for m in re.findall(r"[\"'](/media/[^\"'\s<>]+\.zip)", html))
    print(name, "links zip:", sorted(links)[:3])
    for u in sorted(links)[:1]:
        data = get(u, True)
        if data[:2] != b"PK":
            print("  não é zip:", u)
            continue
        d = os.path.join(OUT, name)
        os.makedirs(d, exist_ok=True)
        zipfile.ZipFile(io.BytesIO(data)).extractall(d)
        print("  ok:", u, len(data) // 1024, "KB ->", d)

for kit in ("town-streets", "houses", "shops-and-restaurants", "city"):
    try:
        data = get("https://shuriken.studio/kits/%s/download" % kit, True)
        print("shuriken", kit, len(data) // 1024, "KB, inicia com", data[:2])
        if data[:2] == b"PK":
            d = os.path.join(OUT, "shuriken-" + kit)
            os.makedirs(d, exist_ok=True)
            zipfile.ZipFile(io.BytesIO(data)).extractall(d)
    except Exception as e:
        print("shuriken", kit, "erro:", repr(e)[:160])
