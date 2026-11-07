"""Separa uma cena-cidade "sopa de objetos" em peças (prédios, árvores, postes...) — Blender headless:

    blender -b <cidade.blend> -P pipeline/blender_split_city.py -- <pasta_saida> [--export]

1. Descarta textos (FONT: letreiros com marcas) e curvas; descarta peças planas grandes (chão, ruas, calçadas).
2. Agrupa os objetos restantes cujas caixas se tocam no plano XY (union-find) = um prédio / uma árvore / um poste.
3. Grava clusters.json (caixa, altura, triângulos, objetos) e uma folha de miniaturas (sheet_XX.png) numerada.
4. Com --export, grava cada cluster como GLB cru (cluster_NNN.glb) para o blender_process_prop.py tratar.
"""
import bpy, sys, os, json, math, mathutils

args = sys.argv[sys.argv.index("--") + 1:]
OUT = args[0]
EXPORT = "--export" in args
os.makedirs(OUT, exist_ok=True)

scene = bpy.context.scene
for o in list(scene.objects):
    if o.type in ("FONT", "CURVE", "CAMERA", "LIGHT"):
        bpy.data.objects.remove(o, do_unlink=True)
for o in scene.objects:
    if o.parent:
        m = o.matrix_world.copy()
        o.parent = None
        o.matrix_world = m

meshes = [o for o in scene.objects if o.type == "MESH"]


def box(o):
    pts = [o.matrix_world @ mathutils.Vector(c) for c in o.bound_box]
    return (min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts),
            max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts))


boxes = {o.name: box(o) for o in meshes}
ground_z = sorted(b[2] for b in boxes.values())[len(boxes) // 10]  # chão típico
flat, solid = [], []
for o in meshes:
    b = boxes[o.name]
    dx, dy, dz = b[3] - b[0], b[4] - b[1], b[5] - b[2]
    if (dz < 0.12 and max(dx, dy) > 2.5) or (max(dx, dy) > 8 and dz < 1.5) or dx * dy > 80:
        flat.append(o)  # chão / rua / calçada / viaduto / placa-base
    else:
        solid.append(o)

parent = {o.name: o.name for o in solid}


def find(a):
    while parent[a] != a:
        parent[a] = parent[parent[a]]
        a = parent[a]
    return a


TOL = 0.005
names = [o.name for o in solid]
order = sorted(names, key=lambda n: boxes[n][0])
for i, a in enumerate(order):
    ba = boxes[a]
    for b_name in order[i + 1:]:
        bb = boxes[b_name]
        if bb[0] > ba[3] + TOL:
            break
        if bb[1] <= ba[4] + TOL and bb[4] >= ba[1] - TOL:
            ra, rb = find(a), find(b_name)
            if ra != rb:
                parent[ra] = rb

clusters = {}
for n in names:
    clusters.setdefault(find(n), []).append(n)


def tris(objs):
    t = 0
    for o in objs:
        o.data.calc_loop_triangles()
        t += len(o.data.loop_triangles)
    return t


rows = []
for i, (root, members) in enumerate(sorted(clusters.items(), key=lambda kv: -len(kv[1]))):
    bs = [boxes[m] for m in members]
    mn = [min(b[k] for b in bs) for k in range(3)]
    mx = [max(b[k + 3] for b in bs) for k in range(3)]
    objs = [bpy.data.objects[m] for m in members]
    rows.append({
        "id": "c%03d" % i, "n": len(members), "tris": tris(objs),
        "min": [round(v, 3) for v in mn], "max": [round(v, 3) for v in mx],
        "size": [round(mx[k] - mn[k], 3) for k in range(3)],
        "names": members[:8],
        "_members": members,
    })

# folha de miniaturas (Workbench), 6x5 por imagem
scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.light = "STUDIO"
scene.display.shading.color_type = "MATERIAL"
scene.render.resolution_x = 320
scene.render.resolution_y = 320
cam_data = bpy.data.cameras.new("ThumbCam")
cam_data.lens = 35
cam = bpy.data.objects.new("ThumbCam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam
all_objs = list(scene.objects)
thumbs = os.path.join(OUT, "_thumbs")
os.makedirs(thumbs, exist_ok=True)
for r in rows:
    if r["size"][2] < 0.25 and max(r["size"][0], r["size"][1]) < 0.4:
        r["thumb"] = None
        continue
    keep = set(r["_members"])
    for o in all_objs:
        if o.type == "MESH":
            o.hide_render = o.name not in keep
    c = mathutils.Vector([(r["min"][k] + r["max"][k]) / 2 for k in range(3)])
    rad = max(r["size"]) * 0.9 + 0.05
    cam.location = c + mathutils.Vector((-rad * 1.3, -rad * 1.6, rad * 1.1))
    cam.rotation_euler = (c - cam.location).to_track_quat("-Z", "Y").to_euler()
    path = os.path.join(thumbs, r["id"] + ".png")
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    r["thumb"] = path

def opt(flag):
    if flag in args:
        return set(args[args.index(flag) + 1].split(","))
    return set()


ONLY = opt("--ids")  # exporta só estes clusters
SINGLE = opt("--single")  # destes, só uma unidade (fileira de árvores / par de postes -> 1)


def single_unit(members):
    """Separa em partes soltas e devolve só a unidade de menor X (partes a até 0,35 no plano XY)."""
    bpy.ops.object.select_all(action="DESELECT")
    for m in members:
        bpy.data.objects[m].select_set(True)
    bpy.context.view_layer.objects.active = bpy.data.objects[members[0]]
    bpy.ops.object.make_single_user(object=True, obdata=True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.separate(type="LOOSE")
    bpy.ops.object.mode_set(mode="OBJECT")
    parts = list(bpy.context.selected_objects)
    centers = {}
    for p in parts:
        b = box(p)
        centers[p.name] = ((b[0] + b[3]) / 2, (b[1] + b[4]) / 2)
    first = min(parts, key=lambda p: centers[p.name][0])
    fx, fy = centers[first.name]
    return [p.name for p in parts if math.hypot(centers[p.name][0] - fx, centers[p.name][1] - fy) < 0.35]


if EXPORT:
    for r in rows:
        if ONLY and r["id"] not in ONLY:
            continue
        keep = set(single_unit(r["_members"]) if r["id"] in SINGLE else r["_members"])
        bpy.ops.object.select_all(action="DESELECT")
        for m in keep:
            bpy.data.objects[m].select_set(True)
        bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, r["id"] + ".glb"), export_format="GLB", use_selection=True,
                                  export_apply=True, export_yup=True, export_materials="EXPORT", export_cameras=False,
                                  export_lights=False)

for r in rows:
    r.pop("_members")
json.dump({"ground_z": ground_z, "flat": len(flat), "clusters": rows}, open(os.path.join(OUT, "clusters.json"), "w"), indent=1)
print("CLUSTERS", len(rows), "flat", len(flat), "ground", round(ground_z, 3))
