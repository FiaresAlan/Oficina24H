"""Tratamento de carros para o Roblox (rodar no Blender em modo headless):

    blender -b -P pipeline/blender_process_car.py -- <config.json> <pasta_saida> [--views] [Nome ...]

Segue a skill fwjelaa-asset-import: escala e orientação corrigidas na origem (1 unidade = 1 stud), transformações aplicadas,
pivô no centro da base, malhas unidas por material (poucos MeshParts), polígonos reduzidos, texturas <= 1024, vidro com
transparência, GLB sem compressão meshopt (o importador do Roblox não lê EXT_meshopt_compression).

Remoção de marcas (pedido do Product Owner: nenhuma marca de carro no jogo):
  1) apaga peças cujo nome indica emblema/logo/placa (BRAND_OBJ);
  2) apaga "à mão" os pontos marcados em pipeline/brand_patches.json (emblemas pintados na textura): para cada ponto
     (vista, x, y, raio em pixels da vista) um raio é lançado na cena; no ponto de textura atingido a região é preenchida com
     a cor do entorno. Com --views o script só normaliza e grava as 3 vistas ortográficas (frente, traseira, lado) em
     <saida>/views/<Nome>.png para marcar os pontos (cada painel tem 780 x 495 px; vistas: 0 frente, 1 traseira, 2 lado).

Convenção de saída: comprimento ao longo de Y (frente em +Y), largura em X, altura em Z, base em Z=0.
"""
import bpy, sys, os, re, json, math, mathutils

argv = sys.argv[sys.argv.index("--") + 1:]
CONFIG = json.load(open(argv[0], encoding="utf-8"))
OUT = argv[1]
VIEWS_ONLY = "--views" in argv
ONLY = set(a for a in argv[2:] if not a.startswith("--"))
os.makedirs(OUT, exist_ok=True)
SRC = CONFIG["source_dir"]
PATCH_FILE = os.path.join(os.path.dirname(os.path.abspath(argv[0])), "brand_patches.json")
PATCHES = json.load(open(PATCH_FILE, encoding="utf-8")) if os.path.exists(PATCH_FILE) else {}
HELPER = re.compile(r"shadow|sombra|ground|floor|chao|platform|pedestal|turntable|backdrop|background|studio|plate_base|base_plane", re.I)
BRAND_OBJ = re.compile(r"emblem|emblema|logo|badge|marca|numberplate|license|licence|placa|nameplate|lettering|plates\d", re.I)
PROXY = re.compile(r"colider|collider|collision|hitbox|proxy|_col$|^col_", re.I)
GLASS = re.compile(r"glass|window|vidro|cristal|windshield|parabrisa|lens_clear", re.I)
PW, PH = 780, 495


def world_bounds(objs):
    mn = mathutils.Vector((1e9,) * 3)
    mx = mathutils.Vector((-1e9,) * 3)
    for o in objs:
        for c in o.bound_box:
            v = o.matrix_world @ mathutils.Vector(c)
            mn = mathutils.Vector((min(mn.x, v.x), min(mn.y, v.y), min(mn.z, v.z)))
            mx = mathutils.Vector((max(mx.x, v.x), max(mx.y, v.y), max(mx.z, v.z)))
    return mn, mx


def meshes():
    return [o for o in bpy.data.objects if o.type == "MESH"]


def tri_count(objs):
    n = 0
    for o in objs:
        o.data.calc_loop_triangles()
        n += len(o.data.loop_triangles)
    return n


def delete(objs):
    for o in list(objs):
        bpy.data.objects.remove(o, do_unlink=True)


def normalize(entry):
    """Importa, limpa auxiliares, orienta (frente em +Y), escala e põe o pivô na base. Retorna lista de objetos removidos."""
    cid = entry["id"]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if entry.get("fbx"):
        bpy.ops.import_scene.fbx(filepath=entry["fbx"])
    else:
        bpy.ops.import_scene.gltf(filepath=os.path.join(SRC, cid + ".glb"))
    for o in bpy.data.objects:
        if o.parent:
            m = o.matrix_world.copy()
            o.parent = None
            o.matrix_world = m
    delete([o for o in bpy.data.objects if o.type != "MESH"])
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes():
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes()[0]
    bpy.ops.object.make_single_user(object=True, obdata=True)  # rodas instanciadas (malha compartilhada) não aceitam apply
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    removed = []
    drops = entry.get("drop", [])
    for o in meshes():
        if HELPER.search(o.name) or PROXY.search(o.name) or BRAND_OBJ.search(o.name) or any(d.lower() in o.name.lower() for d in drops):
            removed.append(o.name)
    delete([bpy.data.objects[n] for n in removed])
    ms = meshes()

    def dims(o):
        a, b = world_bounds([o])
        return b - a

    body = [o for o in ms if min(dims(o)) >= 0.02 * max(dims(o))]
    if body:
        bmn, bmx = world_bounds(body)
        blen = max((bmx - bmn).x, (bmx - bmn).y)
        flat_big = [o.name for o in ms if min(dims(o)) < 0.02 * max(dims(o)) and max(dims(o).x, dims(o).y) > 1.15 * blen]
        delete([bpy.data.objects[n] for n in flat_big])
        removed += flat_big

    ms = meshes()
    mn, mx = world_bounds(ms)
    s = mx - mn
    bpy.ops.object.select_all(action="DESELECT")
    for o in ms:
        o.select_set(True)
    if s.x > s.y:
        bpy.ops.transform.rotate(value=math.radians(90), orient_axis="Z")
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if entry.get("flip"):
        bpy.ops.transform.rotate(value=math.radians(180), orient_axis="Z")
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    mn, mx = world_bounds(meshes())
    k = entry["length"] / (mx - mn).y
    bpy.ops.transform.resize(value=(k, k, k))
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    mn, mx = world_bounds(meshes())
    off = mathutils.Vector((-(mn.x + mx.x) / 2, -(mn.y + mx.y) / 2, -mn.z))
    for o in meshes():
        o.location += off
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return removed


# ---- vistas ortográficas (frente, traseira, lado) -------------------------------------------------------------------
def view_setup():
    mn, mx = world_bounds(meshes())
    size = mx - mn
    center = (mn + mx) / 2
    d = max(size) * 3
    aspect = PW / PH
    scales = {
        0: max(size.x * 1.15, size.z * 1.15 * aspect),  # frente
        1: max(size.x * 1.15, size.z * 1.15 * aspect),  # traseira
        2: max(size.y * 1.1, size.z * 1.15 * aspect),   # lado esquerdo (olhando para +X a partir de -X)
    }
    dirs = {0: mathutils.Vector((0, -1, 0)), 1: mathutils.Vector((0, 1, 0)), 2: mathutils.Vector((1, 0, 0))}
    ups = mathutils.Vector((0, 0, 1))
    cams = {}
    for k in range(3):
        fwd = dirs[k]
        loc = center - fwd * d
        right = fwd.cross(ups).normalized()
        cams[k] = {"loc": loc, "fwd": fwd, "right": right, "up": ups, "scale": scales[k]}
    return center, cams


def render_views(name):
    center, cams = view_setup()
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sh = sc.display.shading
    sh.light = "STUDIO"; sh.color_type = "TEXTURE"; sh.show_shadows = False
    sc.world = bpy.data.worlds.new("w"); sc.world.color = (0.6, 0.68, 0.78)
    sc.render.resolution_x, sc.render.resolution_y = PW, PH
    tmp = os.path.join(OUT, "views")
    os.makedirs(tmp, exist_ok=True)
    cam_data = bpy.data.cameras.new("c"); cam_data.type = "ORTHO"
    cam = bpy.data.objects.new("c", cam_data)
    sc.collection.objects.link(cam); sc.camera = cam
    files = []
    for k in range(3):
        c = cams[k]
        cam_data.ortho_scale = c["scale"]
        cam.location = c["loc"]
        cam.rotation_euler = c["fwd"].to_track_quat("-Z", "Y").to_euler()
        p = os.path.join(tmp, "%s_%d.png" % (name, k))
        sc.render.filepath = p
        bpy.ops.render.render(write_still=True)
        files.append(p)
    return files


def delete_island(me, idx, name, label, loc=None, r_world=0.0):
    """Apaga a ilha de faces (emblema/letreiro modelado como geometria) ligada à face idx, se for pequena."""
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.faces.ensure_lookup_table()
    seen, stack = {idx}, [bm.faces[idx]]
    while stack and len(seen) < 1200:
        f = stack.pop()
        for e in f.edges:
            for g in e.link_faces:
                if g.index not in seen:
                    seen.add(g.index)
                    stack.append(g)
    ok = False
    if len(seen) < 1200:
        mn_i = mathutils.Vector((1e9,) * 3); mx_i = mathutils.Vector((-1e9,) * 3)
        for fi in seen:
            for vtx in bm.faces[fi].verts:
                mn_i = mathutils.Vector((min(mn_i.x, vtx.co.x), min(mn_i.y, vtx.co.y), min(mn_i.z, vtx.co.z)))
                mx_i = mathutils.Vector((max(mx_i.x, vtx.co.x), max(mx_i.y, vtx.co.y), max(mx_i.z, vtx.co.z)))
        diag = (mx_i - mn_i).length
        if diag < 0.45:  # tamanho de emblema/letreiro, não de grade ou para-choque
            bmesh.ops.delete(bm, geom=[bm.faces[fi] for fi in seen], context="FACES")
            bm.to_mesh(me)
            me.update()
            ok = True
            print("PATCH geometria removida:", name, label, "faces", len(seen), "diag %.2f" % diag)
    if not ok and loc is not None:
        # emblema dentro de uma malha grande (ex.: anéis na grade): apaga as faces do MESMO material no raio do emblema;
        # atrás delas fica a peça de baixo (grade, porta-malas), então não abre buraco.
        mat_i = bm.faces[idx].material_index
        near = [f for f in bm.faces if f.material_index == mat_i and (f.calc_center_median() - loc).length <= r_world * 1.15]
        if 0 < len(near) <= 400:
            bmesh.ops.delete(bm, geom=near, context="FACES")
            bm.to_mesh(me)
            me.update()
            ok = True
            print("PATCH faces no raio removidas:", name, label, "faces", len(near), "raio %.3f" % r_world)
    bm.free()
    if not ok:
        print("PATCH ilha grande, mantida:", name, label)
    return ok


def delete_sphere(loc, radius, max_faces=220):
    """Apaga, em TODAS as malhas, as faces cujo centro cai na esfera do emblema (emblema em peça/material vizinho)."""
    import bmesh
    total = 0
    for o in meshes():
        me = o.data
        bm = bmesh.new()
        bm.from_mesh(me)
        near = [f for f in bm.faces if (f.calc_center_median() - loc).length <= radius]
        if 0 < len(near) <= max_faces:
            bmesh.ops.delete(bm, geom=near, context="FACES")
            bm.to_mesh(me)
            me.update()
            total += len(near)
        bm.free()
    if total:
        print("PATCH esfera: %d faces apagadas (raio %.3f)" % (total, radius))
    return total


def apply_patches(name):
    pts = PATCHES.get(name, [])
    if not pts:
        return 0
    import numpy as np
    center, cams = view_setup()
    scene = bpy.context.scene
    done = 0
    for view, px, py, rpx in pts:
        c = cams[view]
        ox = ((px / PW) - 0.5) * c["scale"]
        oy = -(((py / PH) - 0.5) * c["scale"] * PH / PW)
        origin = c["loc"] + c["right"] * ox + c["up"] * oy
        hit_info = None
        for _ in range(8):  # atravessa vidro e peças sem textura (malhas auxiliares/invisíveis)
            dg = bpy.context.evaluated_depsgraph_get()
            hit, loc, nor, idx, obj, mat = scene.ray_cast(dg, origin, c["fwd"], distance=1e4)
            if not hit:
                break
            me = obj.data
            m = me.materials[me.polygons[idx].material_index] if me.polygons[idx].material_index < len(me.materials) else None
            glassy = m is not None and (GLASS.search(m.name) is not None)
            if m is not None and m.use_nodes:
                b = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
                if b is not None and not b.inputs["Alpha"].is_linked and b.inputs["Alpha"].default_value < 0.9:
                    glassy = True
            if glassy:
                origin = loc + c["fwd"] * 0.01
                continue
            hit_info = (loc, idx, obj, m)
            break
        if hit_info is None:
            print("PATCH sem acerto utilizavel:", name, view, px, py)
            continue
        loc, idx, obj, slot = hit_info
        me = obj.data
        poly = me.polygons[idx]
        me.calc_loop_triangles()
        tri = next((t for t in me.loop_triangles if t.polygon_index == idx), None)
        uvl = me.uv_layers.active
        if tri is None:
            continue
        r_world = rpx / PW * c["scale"]
        if not uvl:  # sem UV (cor por vértice/material liso): só dá para apagar geometria pequena
            if delete_island(me, idx, name, slot.name if slot else "?", loc, r_world):
                done += 1
            if delete_sphere(loc, r_world * 0.9):
                done += 1
            continue
        verts = [me.vertices[i].co for i in tri.vertices]
        uvs = [uvl.data[l].uv.copy() for l in tri.loops]
        wa = ((verts[1] - verts[0]).cross(verts[2] - verts[0])).length / 2
        ua = abs((uvs[1] - uvs[0]).cross(uvs[2] - uvs[0])) / 2
        img = None
        if slot is not None and slot.use_nodes:
            bsdf = next((n for n in slot.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
            link = bsdf.inputs["Base Color"].links[0].from_node if bsdf and bsdf.inputs["Base Color"].links else None
            img = link.image if link is not None and link.type == "TEX_IMAGE" else None
        if img is None or ua < 1e-12:
            if delete_island(me, idx, name, slot.name if slot else "?", loc, r_world):
                done += 1
            if delete_sphere(loc, r_world * 0.9):
                done += 1
            continue
        w = mathutils.geometry.barycentric_transform(loc, verts[0], verts[1], verts[2], mathutils.Vector((*uvs[0], 0)), mathutils.Vector((*uvs[1], 0)), mathutils.Vector((*uvs[2], 0)))
        u, v = w.x, w.y
        scale = math.sqrt(wa / ua)  # unidades do mundo por unidade de UV
        r_uv = (rpx / PW * c["scale"]) / scale
        W, H = img.size
        px_arr = np.empty(W * H * img.channels, dtype=np.float32)
        img.pixels.foreach_get(px_arr)
        a = px_arr.reshape(H, W, img.channels)
        cx, cy = (u % 1.0) * W, (v % 1.0) * H
        rr = max(3.0, r_uv * W)
        yy, xx = np.ogrid[:H, :W]
        dist = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
        inside = dist <= rr
        ring = (dist > rr * 1.15) & (dist <= rr * 1.6)
        if ring.sum() < 4:
            print("PATCH anel vazio:", name, view, px, py)
            continue
        a[inside] = a[ring].mean(axis=0)
        img.pixels.foreach_set(px_arr)
        img.update()
        img.pack()
        done += 1
    return done


def textures_to_average_colors():
    """Substitui cada textura de cor base pela COR MÉDIA do material (texturas de 4096 px não sobrevivem a uma redução forte).
    Vidro/translúcido ganha alpha. Normal/roughness/metallic são descartados."""
    import numpy as np
    done = 0
    for mat in bpy.data.materials:
        if not mat.use_nodes:
            continue
        b = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if not b:
            continue
        link = b.inputs["Base Color"].links[0].from_node if b.inputs["Base Color"].links else None
        if link is not None and link.type == "TEX_IMAGE" and link.image is not None:
            img = link.image
            if img.size[0] == 0:
                continue
            tmp = img.copy()
            tmp.scale(16, 16)
            arr = np.empty(16 * 16 * tmp.channels, dtype=np.float32)
            tmp.pixels.foreach_get(arr)
            a = arr.reshape(-1, tmp.channels)
            rgb = a[:, :3].mean(axis=0)
            bpy.data.images.remove(tmp)
            def to_lin(c):
                return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
            col = [to_lin(float(c)) for c in rgb]  # pixels de PNG/JPG chegam codificados em sRGB
            for l in list(b.inputs["Base Color"].links):
                mat.node_tree.links.remove(l)
            b.inputs["Base Color"].default_value = (col[0], col[1], col[2], 1.0)
            done += 1
        for sock in ("Normal", "Roughness", "Metallic"):
            for l in list(b.inputs[sock].links) if sock in b.inputs else []:
                mat.node_tree.links.remove(l)
        if "Metallic" in b.inputs:
            b.inputs["Metallic"].default_value = 0.0
        if GLASS.search(mat.name):
            b.inputs["Alpha"].default_value = 0.3
    return done


def flat_colors_to_textures():
    """O importador do Roblox ignora a cor de materiais SEM textura (tudo vira cinza). Cada material liso ganha uma mini-textura
    4x4 da própria cor; vidro/material translúcido ganha alpha na textura (vira SurfaceAppearance com transparência)."""
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
            alpha = min(alpha, 0.30)
        if GLASS.search(mat.name):
            alpha = min(alpha, 0.30)
        def to_srgb(c):  # a cor do material é linear; o pixel do PNG é sRGB
            c = max(0.0, min(1.0, c))
            return 12.92 * c if c <= 0.0031308 else 1.055 * (c ** (1 / 2.4)) - 0.055
        tmpdir = os.path.join(OUT, "_flat")
        os.makedirs(tmpdir, exist_ok=True)
        tmp_path = os.path.join(tmpdir, re.sub(r"[^A-Za-z0-9_]", "_", mat.name)[:40] + "_%d.png" % made)
        gen = bpy.data.images.new("gen_" + str(made), 4, 4, alpha=True)
        gen.pixels = [to_srgb(col[0]), to_srgb(col[1]), to_srgb(col[2]), alpha] * 16
        gen.filepath_raw = tmp_path
        gen.file_format = "PNG"
        gen.save()
        bpy.data.images.remove(gen)
        img = bpy.data.images.load(tmp_path)  # imagem de ARQUIVO: o exportador glTF lê os pixels corretamente
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
    for o in meshes():  # toda malha precisa de UV para amostrar a textura
        if not o.data.uv_layers:
            o.data.uv_layers.new(name="UVMap")
    return made


def process(entry):
    name = entry["name"]
    removed = normalize(entry)
    if VIEWS_ONLY:
        render_views(name)
        print("VIEWS", name)
        return
    patched = apply_patches(name)
    if entry.get("avg_colors"):
        textures_to_average_colors()
    for mat_name, rgb in (entry.get("paint") or {}).items():  # cor da tinta escolhida (linear)
        mat = bpy.data.materials.get(mat_name)
        b = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None) if mat and mat.use_nodes else None
        if b:
            b.inputs["Base Color"].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
    flats = flat_colors_to_textures()
    # vidro com transparência; texturas <= 1024
    for mat in bpy.data.materials:
        if not mat.use_nodes:
            continue
        bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if not bsdf:
            continue
        trans = bsdf.inputs.get("Transmission Weight")
        is_glass = GLASS.search(mat.name) or (trans is not None and trans.default_value > 0.5 and not trans.is_linked)
        if is_glass:
            if trans is not None and not trans.is_linked:
                trans.default_value = 0.0
            a = bsdf.inputs["Alpha"]
            if not a.is_linked:
                a.default_value = 0.30
            try:
                mat.surface_render_method = "BLENDED"
            except Exception:
                pass
    for img in bpy.data.images:
        if img.size[0] > 1024 or img.size[1] > 1024:
            w, h = img.size
            r = 1024 / max(w, h)
            img.scale(max(1, int(w * r)), max(1, int(h * r)))
    # junta por material e reduz polígonos proporcionalmente
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
    ratio = min(1.0, entry["tris"] / max(1, total))
    if ratio < 1.0:
        counts = {o.name: tri_count([o]) for o in meshes()}
        weights = {n: math.sqrt(c) for n, c in counts.items()} if entry.get("alloc") == "sqrt" else None
        wsum = sum(weights.values()) if weights else 1.0
        for o in meshes():
            if counts[o.name] < 300:
                continue
            r = ratio if weights is None else min(1.0, max(0.0005, entry["tris"] * weights[o.name] / wsum / counts[o.name]))
            mod = o.modifiers.new("dec", "DECIMATE")
            mod.decimate_type = "COLLAPSE"
            mod.ratio = r
            mod.use_collapse_triangulate = True
            mod.delimit = set() if entry.get("avg_colors") else {"UV"}  # cor lisa: sem textura a proteger, reduz mais livremente
            before_n = counts[o.name]
            with bpy.context.temp_override(object=o, active_object=o):
                bpy.ops.object.modifier_apply(modifier=mod.name)
            want = max(40, int(counts[o.name] * r))
            if tri_count([o]) > want * 6:
                # milhares de peças soltas (grades/aletas): mantém as maiores até caber, descarta o resto
                import bmesh
                bm = bmesh.new()
                bm.from_mesh(o.data)
                bm.faces.ensure_lookup_table()
                seen, islands = set(), []
                for f0 in bm.faces:
                    if f0.index in seen:
                        continue
                    comp, stack = [], [f0]
                    seen.add(f0.index)
                    while stack:
                        f = stack.pop()
                        comp.append(f)
                        for e in f.edges:
                            for g in e.link_faces:
                                if g.index not in seen:
                                    seen.add(g.index)
                                    stack.append(g)
                    islands.append(comp)
                islands.sort(key=lambda c: -sum(f.calc_area() for f in c))
                kept, budget = 0, want * 5
                drop = []
                for comp in islands:
                    if kept + len(comp) <= budget:
                        kept += len(comp)
                    else:
                        drop.extend(comp)
                if drop:
                    bmesh.ops.delete(bm, geom=drop, context="FACES")
                    bm.to_mesh(o.data)
                    o.data.update()
                    print("ILHAS %s: %d pedaços, descartados %d faces" % (o.name, len(islands), len(drop)))
                bm.free()
            for _pass in range(4):  # malhas com geometria solta podem parar acima do alvo: repete a redução
                now = tri_count([o])
                if now <= want * 1.6:
                    break
                m2 = o.modifiers.new("dec2", "DECIMATE")
                m2.decimate_type = "COLLAPSE"
                m2.ratio = max(0.0005, want / now)
                m2.use_collapse_triangulate = True
                with bpy.context.temp_override(object=o, active_object=o):
                    bpy.ops.object.modifier_apply(modifier=m2.name)
            print("DEC %s %d -> %d (alvo %d)" % (o.name, before_n, tri_count([o]), want))
    # Limpeza (skills blender-asset-qa / blender-game-optimization): solda vértices duplicados, remove faces degeneradas e soltas,
    # dá material às faces sem material e empurra 3 mm as camadas coplanares sobrepostas (z-fighting) ao longo da normal.
    import bmesh
    fallback = None
    for o in meshes():
        if o.data.materials and o.data.materials[0]:
            fallback = o.data.materials[0]
            break
    for o in meshes():
        if not o.data.materials and fallback is not None:
            o.data.materials.append(fallback)
        bm = bmesh.new()
        bm.from_mesh(o.data)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0015)
        bmesh.ops.dissolve_degenerate(bm, dist=1e-4, edges=bm.edges)
        loose = [v for v in bm.verts if not v.link_faces]
        if loose:
            bmesh.ops.delete(bm, geom=loose, context="VERTS")
        bm.normal_update()
        bm.to_mesh(o.data)
        bm.free()
        o.data.update()
    final = tri_count(meshes())
    # texturas opacas viram JPEG (PNG de 1024 pesa 1,5 MB; JPEG ~150 KB). Só mantém PNG quem usa transparência.
    import numpy as np
    for img in bpy.data.images:
        if img.users == 0 or img.size[0] == 0 or max(img.size) <= 64:
            continue
        keep_alpha = False
        if img.channels == 4:
            arr = np.empty(img.size[0] * img.size[1] * 4, dtype=np.float32)
            img.pixels.foreach_get(arr)
            keep_alpha = bool(arr[3::4].min() < 0.99)
        if not keep_alpha:
            img.file_format = "JPEG"
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
    rep = {
        "name": name, "source": entry["id"], "tris_before": total, "tris_after": final, "parts": len(meshes()),
        "materials": len(bpy.data.materials), "size": [round(v, 2) for v in (mx - mn)], "removed": removed[:12],
        "patches": patched, "flat_tex": flats, "file_kb": os.path.getsize(out) // 1024,
    }
    print("REPORT " + json.dumps(rep, ensure_ascii=False))


for entry in CONFIG["cars"]:
    if ONLY and entry["name"] not in ONLY:
        continue
    try:
        process(entry)
    except Exception as e:
        import traceback
        print("FAIL", entry.get("name"), repr(e)[:300], traceback.format_exc()[-400:])
