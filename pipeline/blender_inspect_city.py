"""Inventário de uma cena-cidade (Blender headless):  blender -b <arquivo.blend> -P pipeline/blender_inspect_city.py -- <saida.json>
Lista coleções e objetos de topo (pais) com tamanho (unidades Blender), posição, triângulos e materiais.
"""
import bpy, sys, json, mathutils

out = sys.argv[sys.argv.index("--") + 1]


def bounds(objs):
    mn = mathutils.Vector((1e9,) * 3)
    mx = mathutils.Vector((-1e9,) * 3)
    for o in objs:
        if o.type != "MESH":
            continue
        for c in o.bound_box:
            v = o.matrix_world @ mathutils.Vector(c)
            mn = mathutils.Vector((min(mn.x, v.x), min(mn.y, v.y), min(mn.z, v.z)))
            mx = mathutils.Vector((max(mx.x, v.x), max(mx.y, v.y), max(mx.z, v.z)))
    return mn, mx


def tris(objs):
    n = 0
    for o in objs:
        if o.type == "MESH":
            o.data.calc_loop_triangles()
            n += len(o.data.loop_triangles)
    return n


def family(o):
    res = [o]
    for c in o.children_recursive:
        res.append(c)
    return res


report = {"unit_scale": bpy.context.scene.unit_settings.scale_length, "collections": [], "roots": []}
for col in bpy.data.collections:
    report["collections"].append({"name": col.name, "objects": len(col.objects), "children": [c.name for c in col.children]})
roots = [o for o in bpy.context.scene.objects if o.parent is None]
for o in roots:
    fam = family(o)
    mn, mx = bounds(fam)
    mats = sorted({s.material.name for f in fam if f.type == "MESH" for s in f.material_slots if s.material})
    report["roots"].append({
        "name": o.name, "type": o.type, "collections": [c.name for c in o.users_collection],
        "n": len(fam), "tris": tris(fam),
        "size": [round(mx.x - mn.x, 2), round(mx.y - mn.y, 2), round(mx.z - mn.z, 2)] if mn.x < 1e8 else None,
        "center": [round((mx.x + mn.x) / 2, 2), round((mx.y + mn.y) / 2, 2), round(mn.z, 2)] if mn.x < 1e8 else None,
        "mats": mats[:12], "nmats": len(mats),
    })
report["total_tris"] = sum(r["tris"] for r in report["roots"])
report["images"] = [{"name": i.name, "size": list(i.size), "file": i.filepath} for i in bpy.data.images]
json.dump(report, open(out, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
print("roots", len(roots), "tris", report["total_tris"])
