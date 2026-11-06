"""Envia os sprites do HUD (assets/hud_sprites/*.png) ao Roblox como Decal pela Open Cloud e grava os ids em
assets/hud_sprites/_decal_ids.json. A chave vem de ROBLOX_OPEN_CLOUD_API_KEY (arquivo fora do repositório
~/.oficina24h/secrets.env) e nunca é impressa. Uso: python tools/upload_hud_sprites.py [nome ...] [--ops nome=operationId ...]"""
import json
import mimetypes
import os
import sys
import time
import urllib.error
import urllib.request
import uuid

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPRITES = os.path.join(ROOT, "assets", "hud_sprites")
IDS_FILE = os.path.join(SPRITES, "_decal_ids.json")
USER_ID = "11072958195"
BASE = "https://apis.roblox.com/assets/v1"


def api_key():
    path = os.path.join(os.path.expanduser("~"), ".oficina24h", "secrets.env")
    with open(path, encoding="utf-8") as f:
        for line in f:
            if line.startswith("ROBLOX_OPEN_CLOUD_API_KEY="):
                return line.split("=", 1)[1].strip()
    raise SystemExit("chave não encontrada")


def request(method, url, key, data=None, headers=None):
    req = urllib.request.Request(url, data=data, method=method, headers={"x-api-key": key, **(headers or {})})
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return json.loads(r.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        raise SystemExit(f"HTTP {e.code} em {url.split('?')[0]}: {e.read().decode('utf-8', 'replace')[:300]}")


def upload(name, key):
    path = os.path.join(SPRITES, name + ".png")
    boundary = uuid.uuid4().hex
    meta = json.dumps({"assetType": "Decal", "displayName": "Oficina24H_HUD_" + name, "description": "HUD sprite",
                       "creationContext": {"creator": {"userId": USER_ID}}})
    body = b""
    body += f'--{boundary}\r\nContent-Disposition: form-data; name="request"\r\nContent-Type: application/json\r\n\r\n{meta}\r\n'.encode()
    body += f'--{boundary}\r\nContent-Disposition: form-data; name="fileContent"; filename="{name}.png"\r\nContent-Type: image/png\r\n\r\n'.encode()
    body += open(path, "rb").read() + f"\r\n--{boundary}--\r\n".encode()
    res = request("POST", BASE + "/assets", key, body, {"Content-Type": "multipart/form-data; boundary=" + boundary})
    return res["operationId"]


def wait(op, key):
    for _ in range(40):
        res = request("GET", f"{BASE}/operations/{op}", key)
        if res.get("done"):
            r = res.get("response", {})
            if r.get("moderationResult", {}).get("moderationState") not in (None, "Approved"):
                raise SystemExit("moderação: " + json.dumps(r.get("moderationResult")))
            return r["assetId"]
        time.sleep(2)
    raise SystemExit("tempo esgotado " + op)


def main():
    key = api_key()
    ids = json.load(open(IDS_FILE)) if os.path.exists(IDS_FILE) else {}
    args = sys.argv[1:]
    ops = {}
    if "--ops" in args:
        i = args.index("--ops")
        for pair in args[i + 1:]:
            n, o = pair.split("=")
            ops[n] = o
        args = args[:i]
    names = args or sorted(f[:-4] for f in os.listdir(SPRITES) if f.endswith(".png"))
    for name in names:
        if name in ids:
            continue
        ops[name] = ops.get(name) or upload(name, key)
    for name, op in ops.items():
        if name not in ids:
            ids[name] = wait(op, key)
            print(name, ids[name])
            json.dump(ids, open(IDS_FILE, "w"), indent=1)
    print("total", len(ids))


if __name__ == "__main__":
    main()
