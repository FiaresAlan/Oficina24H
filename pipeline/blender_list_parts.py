"""Lista peças (objetos de malha) e materiais dos GLBs de origem, para achar emblemas/letreiros por nome.
blender -b -P pipeline/blender_list_parts.py -- <cars_selection.json> <saida.json>"""
import bpy, sys, json, os
cfg_path, out_path = sys.argv[sys.argv.index("--") + 1:][:2]
cfg = json.load(open(cfg_path, encoding="utf-8"))
res = {}
for car in cfg["cars"]:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(cfg["source_dir"], car["id"] + ".glb"))
    rows = []
    for o in bpy.data.objects:
        if o.type != "MESH":
            continue
        o.data.calc_loop_triangles()
        d = o.dimensions
        rows.append({"obj": o.name, "mats": [m.name if m else None for m in o.data.materials], "tris": len(o.data.loop_triangles),
                     "dim": [round(d.x, 3), round(d.y, 3), round(d.z, 3)]})
    res[car["name"]] = rows
json.dump(res, open(out_path, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print("OK", {k: len(v) for k, v in res.items()})
