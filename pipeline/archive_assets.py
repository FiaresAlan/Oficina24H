"""Arquiva (reversível) assets que EU enviei antes e foram substituídos. python pipeline/archive_assets.py <ids.json>
Usa POST /assets/v1/assets/{id}:archive. Só mexe nos ids do arquivo informado."""
import json, sys, urllib.request, urllib.error

secrets = {}
for line in open(r"C:\Users\Administrador\.oficina24h\secrets.env", encoding="utf-8"):
    if "=" in line:
        k, v = line.strip().split("=", 1)
        secrets[k] = v
KEY = secrets["ROBLOX_OPEN_CLOUD_API_KEY"]
ids = json.load(open(sys.argv[1], encoding="utf-8"))
for name, asset in ids.items():
    req = urllib.request.Request("https://apis.roblox.com/assets/v1/assets/%s:archive" % asset, data=b"{}", method="POST",
                                 headers={"x-api-key": KEY, "Content-Type": "application/json"})
    try:
        urllib.request.urlopen(req, timeout=60).read()
        print(name, asset, "arquivado")
    except urllib.error.HTTPError as e:
        print(name, asset, "HTTP", e.code, e.read().decode()[:150])
