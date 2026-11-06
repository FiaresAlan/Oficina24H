"""Prévia dos GLBs tratados: blender -b -P pipeline/blender_preview_out.py -- <pasta_glb> <pasta_png> [x_cam y_cam]
Câmera em 3/4 pelo lado +Y (frente presumida) por padrão; passe o sinal para ver o outro lado."""
import bpy, sys, os, glob, mathutils

argv = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT = argv[0], argv[1]
sx = float(argv[2]) if len(argv) > 2 else 0.7
sy = float(argv[3]) if len(argv) > 3 else 0.9
os.makedirs(OUT, exist_ok=True)
for path in sorted(glob.glob(os.path.join(SRC, "*.glb"))):
    name = os.path.splitext(os.path.basename(path))[0]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    ms = [o for o in bpy.data.objects if o.type == "MESH"]
    mn = mathutils.Vector((1e9,) * 3); mx = mathutils.Vector((-1e9,) * 3)
    for o in ms:
        for c in o.bound_box:
            v = o.matrix_world @ mathutils.Vector(c)
            mn = mathutils.Vector((min(mn.x, v.x), min(mn.y, v.y), min(mn.z, v.z)))
            mx = mathutils.Vector((max(mx.x, v.x), max(mx.y, v.y), max(mx.z, v.z)))
    center = (mn + mx) / 2
    diag = (mx - mn).length
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sh = sc.display.shading
    sh.light = "STUDIO"; sh.color_type = "TEXTURE"; sh.show_shadows = True
    sc.world = bpy.data.worlds.new("w"); sc.world.color = (0.6, 0.68, 0.78)
    sc.render.resolution_x, sc.render.resolution_y = 480, 320
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.lens = 40
    sc.collection.objects.link(cam); sc.camera = cam
    off = mathutils.Vector((sx, sy, 0.42)); off.normalize()
    cam.location = center + off * diag * 1.25
    cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = os.path.join(OUT, name + ".png")
    bpy.ops.render.render(write_still=True)
    print("OK", name)
