"""Envia GLBs tratados ao Roblox como Model via Open Cloud (conta do Product Owner). A chave fica FORA do repositório
(C:\\Users\\Administrador\\.oficina24h\\secrets.env). Uso:  python pipeline/upload_models.py <pasta_glb> <saida.json> [Nome ...]
"""
import json, os, sys, time, uuid, urllib.request, urllib.error

CREATOR_USER_ID = "11072958195"
secrets = {}
for line in open(r"C:\Users\Administrador\.oficina24h\secrets.env", encoding="utf-8"):
    if "=" in line:
        k, v = line.strip().split("=", 1)
        secrets[k] = v
KEY = secrets["ROBLOX_OPEN_CLOUD_API_KEY"]
src, out_json = sys.argv[1], sys.argv[2]
only = set(sys.argv[3:])
ids = json.load(open(out_json, encoding="utf-8")) if os.path.exists(out_json) else {}


def upload(path, name):
    boundary = uuid.uuid4().hex
    meta = json.dumps({
        "assetType": "Model", "displayName": name[:50], "description": "Oficina 24H - asset 3D (origem em docs/ORIGEM_ASSETS.md)",
        "creationContext": {"creator": {"userId": CREATOR_USER_ID}},
    })
    data = open(path, "rb").read()
    body = (
        ("--%s\r\nContent-Disposition: form-data; name=\"request\"\r\nContent-Type: application/json\r\n\r\n%s\r\n" % (boundary, meta)).encode()
        + ("--%s\r\nContent-Disposition: form-data; name=\"fileContent\"; filename=\"%s.glb\"\r\nContent-Type: model/gltf-binary\r\n\r\n" % (boundary, name)).encode()
        + data + ("\r\n--%s--\r\n" % boundary).encode()
    )
    req = urllib.request.Request("https://apis.roblox.com/assets/v1/assets", data=body, method="POST", headers={
        "x-api-key": KEY, "Content-Type": "multipart/form-data; boundary=" + boundary})
    try:
        resp = json.loads(urllib.request.urlopen(req, timeout=120).read().decode())
    except urllib.error.HTTPError as e:
        return None, "HTTP %d %s" % (e.code, e.read().decode()[:300])
    op = resp.get("path") or resp.get("operationId")
    for _ in range(60):
        time.sleep(3)
        r = urllib.request.Request("https://apis.roblox.com/assets/v1/" + op, headers={"x-api-key": KEY})
        try:
            st = json.loads(urllib.request.urlopen(r, timeout=60).read().decode())
        except urllib.error.HTTPError as e:
            return None, "poll HTTP %d" % e.code
        if st.get("done"):
            if "response" in st:
                return st["response"].get("assetId"), "ok"
            return None, json.dumps(st.get("error", st))[:300]
    return None, "timeout"


for f in sorted(os.listdir(src)):
    if not f.endswith(".glb"):
        continue
    name = f[:-4]
    if (only and name not in only) or name in ids:
        continue
    asset, status = upload(os.path.join(src, f), name)
    print(name, "->", asset, status, flush=True)
    if asset:
        ids[name] = asset
        json.dump(ids, open(out_json, "w", encoding="utf-8"), indent=1)
