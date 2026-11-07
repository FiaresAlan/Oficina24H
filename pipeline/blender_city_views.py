"""Vistas da cena-cidade (Workbench) + estatística:  blender -b <arquivo.blend> -P pipeline/blender_city_views.py -- <pasta_saida>
Gera topo.png (ortográfica de cima, com grade a cada 10 unidades) e perspectiva.png; imprime limites da cena.
"""
import bpy, sys, os, math, mathutils

out = sys.argv[sys.argv.index("--") + 1]
os.makedirs(out, exist_ok=True)
scene = bpy.context.scene
mn = mathutils.Vector((1e9,) * 3)
mx = mathutils.Vector((-1e9,) * 3)
for o in scene.objects:
    if o.type not in ("MESH", "CURVE", "FONT"):
        continue
    for c in o.bound_box:
        v = o.matrix_world @ mathutils.Vector(c)
        mn = mathutils.Vector((min(mn.x, v.x), min(mn.y, v.y), min(mn.z, v.z)))
        mx = mathutils.Vector((max(mx.x, v.x), max(mx.y, v.y), max(mx.z, v.z)))
print("BOUNDS", tuple(round(a, 2) for a in mn), tuple(round(a, 2) for a in mx))
center = (mn + mx) / 2
span = max(mx.x - mn.x, mx.y - mn.y)

scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.light = "STUDIO"
scene.display.shading.color_type = "MATERIAL"
scene.render.resolution_x = 1600
scene.render.resolution_y = 1600
scene.render.film_transparent = False

cam_data = bpy.data.cameras.new("TopCam")
cam_data.type = "ORTHO"
cam_data.ortho_scale = span * 1.02
cam_data.clip_end = 100000
cam = bpy.data.objects.new("TopCam", cam_data)
scene.collection.objects.link(cam)
cam.location = (center.x, center.y, mx.z + 50)
cam.rotation_euler = (0, 0, 0)
scene.camera = cam
scene.render.filepath = os.path.join(out, "topo.png")
bpy.ops.render.render(write_still=True)

cam_data.type = "PERSP"
cam_data.lens = 28
cam.location = (center.x - span * 0.45, center.y - span * 0.45, mx.z + span * 0.35)
direction = center - cam.location
cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
scene.render.resolution_x = 1920
scene.render.resolution_y = 1080
scene.render.filepath = os.path.join(out, "perspectiva.png")
bpy.ops.render.render(write_still=True)
print("ok")
