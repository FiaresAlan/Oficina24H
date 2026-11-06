"""Tratamento de props/prédios/equipamentos para o Roblox (Blender headless):

    blender -b -P pipeline/blender_process_prop.py -- <config.json> <pasta_saida> [Nome ...]

config.json: {"props": [{"name", "file", "scale": 1.0, "max_tris": 8000}]}  (file = caminho do GLB)
Segue a skill fwjelaa-asset-import: escala aplicada na origem, transformações aplicadas, pivô no centro da BASE, malhas unidas por
material (poucos MeshParts), cor lisa -> mini-textura (o importador do Roblox ignora cor de material sem textura), transparência
no vidro, polígonos reduzidos só se passar do limite, GLB sem compressão. Orientação mantida (frente = -Y do Blender = +Z no glTF).
"""
import bpy, sys, os, re, json, math, mathutils

argv = sys.argv[sys.argv.index("--") + 1:]
CONFIG = json.load(open(argv[0], encoding="utf-8"))
OUT = argv[1]
ONLY = set(argv[2:])
os.makedirs(OUT, exist_ok=True)
GLASS = re.compile(r"glass|window|vidro|cristal|windshield|visor", re.I)


def meshes():
    return [o for o in bpy.data.objects if o.type == "MESH"]


def world_bounds(objs):
    mn = mathutils.Vector((1e9,) * 3)
    mx = mathutils.Vector((-1e9,) * 3)
    for o in objs:
        for c in o.bound_box:
            v = o.matrix_world @ mathutils.Vector(c)
            mn = mathutils.Vector((min(mn.x, v.x), min(mn.y, v.y), min(mn.z, v.z)))
            mx = mathutils.Vector((max(mx.x, v.x), max(mx.y, v.y), max(mx.z, v.z)))
    return mn, mx


def tri_count(objs):
    n = 0
    for o in objs:
        o.data.calc_loop_triangles()
        n += len(o.data.loop_triangles)
    return n


def to_srgb(c):
    c = max(0.0, min(1.0, c))
    return 12.92 * c if c <= 0.0031308 else 1.055 * (c ** (1 / 2.4)) - 0.055


def flat_colors_to_textures(tmpdir):
    made = 0
    for mat in bpy.data.materials:
        if not mat.use_nodes:
            continue
        b = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if not b or b.inputs["Base Color"].is_linked:
            continue
        col = list(b.inputs["Base Color"].default_value)
        alpha = 1.0 if b.inputs["Alpha"].is_linked else float(b.inputs["Alpha"].default_value)
        trans = b.inputs.get("Transmission Weight")
        if trans is not None and not trans.is_linked and trans.default_value > 0.5:
            alpha = min(alpha, 0.35)
        if GLASS.search(mat.name):
            alpha = min(alpha, 0.35)
        path = os.path.join(tmpdir, re.sub(r"[^A-Za-z0-9_]", "_", mat.name)[:40] + "_%d.png" % made)
        gen = bpy.data.images.new("gen_%d" % made, 4, 4, alpha=True)
        gen.pixels = [to_srgb(col[0]), to_srgb(col[1]), to_srgb(col[2]), alpha] * 16
        gen.filepath_raw = path
        gen.file_format = "PNG"
        gen.save()
        bpy.data.images.remove(gen)
        img = bpy.data.images.load(path)  # imagem de arquivo: o exportador lê os pixels corretamente
        img.colorspace_settings.name = "sRGB"
        img.alpha_mode = "STRAIGHT"
        img.pack()
        tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image = img
        tex.interpolation = "Closest"
        mat.node_tree.links.new(tex.outputs["Color"], b.inputs["Base Color"])
        if alpha < 0.99:
            mat.node_tree.links.new(tex.outputs["Alpha"], b.inputs["Alpha"])
            try:
                mat.surface_render_method = "BLENDED"
            except Exception:
                pass
        made += 1
    for o in meshes():
        if not o.data.uv_layers:
            o.data.uv_layers.new(name="UVMap")
    return made


def process(entry):
    name = entry["name"]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=entry["file"])
    for o in bpy.data.objects:
        if o.parent:
            m = o.matrix_world.copy()
            o.parent = None
            o.matrix_world = m
    for o in [o for o in bpy.data.objects if o.type != "MESH"]:
        bpy.data.objects.remove(o, do_unlink=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes():
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes()[0]
    bpy.ops.object.make_single_user(object=True, obdata=True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    k = float(entry.get("scale", 1.0))
    if abs(k - 1.0) > 1e-6:
        bpy.ops.transform.resize(value=(k, k, k))
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    mn, mx = world_bounds(meshes())
    off = mathutils.Vector((-(mn.x + mx.x) / 2, -(mn.y + mx.y) / 2, -mn.z))
    for o in meshes():
        o.location += off
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    tmpdir = os.path.join(OUT, "_flat")
    os.makedirs(tmpdir, exist_ok=True)
    flats = flat_colors_to_textures(tmpdir)
    groups = {}
    for o in meshes():
        key = o.material_slots[0].material.name if o.material_slots and o.material_slots[0].material else "_sem_material"
        groups.setdefault(key, []).append(o)
    for key, objs in groups.items():
        bpy.ops.object.select_all(action="DESELECT")
        for o in objs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        if len(objs) > 1:
            bpy.ops.object.join()
        bpy.context.view_layer.objects.active.name = key[:40]
    total = tri_count(meshes())
    limit = int(entry.get("max_tris", 8000))
    if total > limit:
        ratio = limit / total
        for o in meshes():
            if tri_count([o]) < 300:
                continue
            mod = o.modifiers.new("dec", "DECIMATE")
            mod.decimate_type = "COLLAPSE"
            mod.ratio = ratio
            mod.use_collapse_triangulate = True
            mod.delimit = {"UV"}
            with bpy.context.temp_override(object=o, active_object=o):
                bpy.ops.object.modifier_apply(modifier=mod.name)
    final = tri_count(meshes())
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes():
        o.select_set(True)
    out = os.path.join(OUT, name + ".glb")
    bpy.ops.export_scene.gltf(
        filepath=out, export_format="GLB", use_selection=True, export_apply=True, export_yup=True,
        export_image_format="AUTO", export_texcoords=True, export_normals=True, export_materials="EXPORT",
        export_cameras=False, export_lights=False,
    )
    mn, mx = world_bounds(meshes())
    print("REPORT " + json.dumps({"name": name, "tris_before": total, "tris_after": final, "parts": len(meshes()), "flat_tex": flats,
                                  "size_x_y_z": [round(v, 1) for v in (mx - mn)], "file_kb": os.path.getsize(out) // 1024}))


for entry in CONFIG["props"]:
    if ONLY and entry["name"] not in ONLY:
        continue
    try:
        process(entry)
    except Exception as e:
        import traceback
        print("FAIL", entry.get("name"), repr(e)[:300], traceback.format_exc()[-300:])
