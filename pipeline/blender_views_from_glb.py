"""Verificação final: renderiza frente/traseira/lado ortográficos dos GLBs JÁ TRATADOS (mesmas câmeras do blender_process_car).
blender -b -P pipeline/blender_views_from_glb.py -- <pasta_glb> <pasta_saida> [Nome ...]"""
import bpy, sys, os, mathutils

argv = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT = argv[0], argv[1]
ONLY = set(argv[2:])
PW, PH = 780, 495
os.makedirs(OUT, exist_ok=True)
for f in sorted(os.listdir(SRC)):
    if not f.endswith(".glb") or (ONLY and f[:-4] not in ONLY):
        continue
    name = f[:-4]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(SRC, f))
    ms = [o for o in bpy.data.objects if o.type == "MESH"]
    mn = mathutils.Vector((1e9,) * 3); mx = mathutils.Vector((-1e9,) * 3)
    for o in ms:
        for c in o.bound_box:
            v = o.matrix_world @ mathutils.Vector(c)
            mn = mathutils.Vector((min(mn.x, v.x), min(mn.y, v.y), min(mn.z, v.z)))
            mx = mathutils.Vector((max(mx.x, v.x), max(mx.y, v.y), max(mx.z, v.z)))
    size, center = mx - mn, (mn + mx) / 2
    asp = PW / PH
    scales = {0: max(size.x * 1.15, size.z * 1.15 * asp), 1: max(size.x * 1.15, size.z * 1.15 * asp), 2: max(size.y * 1.1, size.z * 1.15 * asp)}
    dirs = {0: mathutils.Vector((0, -1, 0)), 1: mathutils.Vector((0, 1, 0)), 2: mathutils.Vector((1, 0, 0))}
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sh = sc.display.shading
    sh.light = "STUDIO"; sh.color_type = "TEXTURE"; sh.show_shadows = False
    sc.world = bpy.data.worlds.new("w"); sc.world.color = (0.6, 0.68, 0.78)
    sc.render.resolution_x, sc.render.resolution_y = PW, PH
    cd = bpy.data.cameras.new("c"); cd.type = "ORTHO"
    cam = bpy.data.objects.new("c", cd)
    sc.collection.objects.link(cam); sc.camera = cam
    for k in range(3):
        cd.ortho_scale = scales[k]
        cam.location = center - dirs[k] * max(size) * 3
        cam.rotation_euler = dirs[k].to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = os.path.join(OUT, "%s_%d.png" % (name, k))
        bpy.ops.render.render(write_still=True)
    print("OK", name)
