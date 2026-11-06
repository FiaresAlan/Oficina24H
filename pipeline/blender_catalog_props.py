"""Cataloga e renderiza prévias de GLBs (props/prédios). blender -b -P pipeline/blender_catalog_props.py -- <pasta_saida> <glb> [<glb> ...]
Grava <saida>/<arquivo>.png (3/4) e imprime CAT arquivo|tris|partes|materiais|imagens|largura x altura x profundidade."""
import bpy, sys, os, mathutils

argv = sys.argv[sys.argv.index("--") + 1:]
OUT = argv[0]
os.makedirs(OUT, exist_ok=True)
for path in argv[1:]:
    name = os.path.splitext(os.path.basename(path))[0]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    try:
        bpy.ops.import_scene.gltf(filepath=path)
    except Exception as e:
        print("CAT", name, "FALHOU", repr(e)[:80])
        continue
    ms = [o for o in bpy.data.objects if o.type == "MESH"]
    tris = 0
    mn = mathutils.Vector((1e9,) * 3); mx = mathutils.Vector((-1e9,) * 3)
    for o in ms:
        o.data.calc_loop_triangles()
        tris += len(o.data.loop_triangles)
        for c in o.bound_box:
            v = o.matrix_world @ mathutils.Vector(c)
            mn = mathutils.Vector((min(mn.x, v.x), min(mn.y, v.y), min(mn.z, v.z)))
            mx = mathutils.Vector((max(mx.x, v.x), max(mx.y, v.y), max(mx.z, v.z)))
    s = mx - mn
    print("CAT %s|%d|%d|%d|%d|%.1f x %.1f x %.1f" % (name, tris, len(ms), len(bpy.data.materials), len(bpy.data.images), s.x, s.z, s.y))
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sh = sc.display.shading
    sh.light = "STUDIO"; sh.color_type = "TEXTURE"; sh.show_shadows = True
    sc.world = bpy.data.worlds.new("w"); sc.world.color = (0.62, 0.7, 0.8)
    sc.render.resolution_x, sc.render.resolution_y = 320, 240
    center = (mn + mx) / 2
    diag = s.length
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.lens = 40
    sc.collection.objects.link(cam); sc.camera = cam
    off = mathutils.Vector((0.8, -1.0, 0.7)); off.normalize()
    cam.location = center + off * diag * 1.5
    cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = os.path.join(OUT, name + ".png")
    bpy.ops.render.render(write_still=True)
