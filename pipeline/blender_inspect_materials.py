"""Lista os materiais de GLBs: blender -b -P pipeline/blender_inspect_materials.py -- <arquivo.glb> [...]"""
import bpy, sys
for path in sys.argv[sys.argv.index("--") + 1:]:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    print("ARQUIVO", path)
    for mat in bpy.data.materials:
        b = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None) if mat.use_nodes else None
        if not b:
            print("  ", mat.name, "(sem principled)")
            continue
        bc = b.inputs["Base Color"]
        link = bc.links[0].from_node.type if bc.links else None
        img = bc.links[0].from_node.image.name if bc.links and bc.links[0].from_node.type == "TEX_IMAGE" and bc.links[0].from_node.image else None
        col = tuple(round(v, 2) for v in bc.default_value)
        print("  ", mat.name, "| cor", col, "| ligado a", link, img, "| metal", round(b.inputs["Metallic"].default_value, 2),
              "| alpha", round(b.inputs["Alpha"].default_value, 2), "| emissao", tuple(round(v, 2) for v in b.inputs["Emission Color"].default_value[:3]))
    for o in bpy.data.objects:
        if o.type == "MESH":
            print("   malha", o.name, "uv:", len(o.data.uv_layers), "faces:", len(o.data.polygons), "mats:", [m.name for m in o.data.materials])
