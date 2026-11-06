"""Mostra como a cor base de cada material é montada (fator x textura). blender -b -P pipeline/blender_inspect_nodes.py -- <glb>"""
import bpy, sys
for path in sys.argv[sys.argv.index("--") + 1:]:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    print("ARQUIVO", path)
    for mat in bpy.data.materials:
        b = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if not b:
            continue
        bc = b.inputs["Base Color"]
        desc = "cor=%s" % (tuple(round(v, 2) for v in bc.default_value),)
        if bc.links:
            n = bc.links[0].from_node
            desc += " <- %s" % n.type
            if n.type == "MIX":
                desc += " mix:" + ",".join("%s=%s" % (i.name, (tuple(round(v, 2) for v in i.default_value) if hasattr(i, "default_value") and hasattr(i.default_value, "__len__") else getattr(i, "default_value", "")) if not i.is_linked else "link<-" + i.links[0].from_node.type) for i in n.inputs[:3])
            if n.type == "TEX_IMAGE" and n.image:
                px = list(n.image.pixels[:])
                k = max(1, len(px) // 4 // 400)
                rs = px[0::4 * k]; gs = px[1::4 * k]; bs = px[2::4 * k]
                desc += " img %dx%d media=(%.2f,%.2f,%.2f)" % (n.image.size[0], n.image.size[1], sum(rs) / len(rs), sum(gs) / len(gs), sum(bs) / len(bs))
        print("  ", mat.name[:36], "|", desc)
