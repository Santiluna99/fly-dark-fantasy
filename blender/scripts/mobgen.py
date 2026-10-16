# Generador de personajes ORGÁNICOS para Nocturnia (sin hoja de referencia).
#  - Cuerpo: esqueleto de nodos -> modificador Skin + Subsurf -> malla continua low-poly, con relieve por ruido.
#  - Accesorios (cabeza, ropa, armadura, armas): mallas esculpidas con bmesh (esferas deformadas, tubos cónicos, losas biseladas).
#  - Colores por vértice sucios (ruido, suciedad abajo, cavidades oscuras).  - Armadura con pesos automáticos + idle/walk/attack.
import bpy, bmesh, math, random, sys
from mathutils import Vector, Matrix, Euler, noise

OUT = "/home/claude/blender/out/"
V = Vector


def lin(c):
    return tuple(max(0.0, x) ** 2.2 for x in c)


def fbm(p, f=1.0):
    q = V(p) * f
    return 0.5 + 0.5 * (noise.noise(q) * 0.65 + noise.noise(q * 2.3) * 0.35)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


# ------------------------------------------------------------------ utilidades de malla
def _obj(name, bm, bone="spine", smooth=False):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    for p in me.polygons:
        p.use_smooth = smooth
    o["bone"] = bone
    return o


def _xf(bm, c, r=(1, 1, 1), rot=(0, 0, 0)):
    bmesh.ops.scale(bm, vec=r, verts=bm.verts)
    bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=Euler(tuple(math.radians(a) for a in rot)).to_matrix(), verts=bm.verts)
    bmesh.ops.translate(bm, vec=c, verts=bm.verts)


def blob(name, c, r, rot=(0, 0, 0), seg=10, rings=6, bone="spine", col=(.5, .5, .5), amp=0.012, emit=False, fn=None):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=1.0)
    _xf(bm, c, r, rot)
    o = _obj(name, bm, bone)
    paint(o, col, amp, fn, emit)
    return o


def tube(name, p0, p1, r0, r1, seg=8, bone="spine", col=(.5, .5, .5), cap=True, amp=0.008, fn=None, emit=False):
    p0, p1 = V(p0), V(p1)
    d = p1 - p0
    L = d.length
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=cap, cap_tris=False, segments=seg, radius1=r0, radius2=r1, depth=L)
    q = V((0, 0, 1)).rotation_difference(d.normalized()).to_matrix()
    bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=q, verts=bm.verts)
    bmesh.ops.translate(bm, vec=(p0 + p1) / 2, verts=bm.verts)
    o = _obj(name, bm, bone)
    paint(o, col, amp, fn, emit)
    return o


def slab(name, c, size, rot=(0, 0, 0), bone="spine", col=(.5, .5, .5), bev=0.012, amp=0.006, fn=None, emit=False):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    _xf(bm, c, size, rot)
    if bev > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bev, segments=1, affect='EDGES')
    o = _obj(name, bm, bone)
    paint(o, col, amp, fn, emit)
    return o


def jag(o, zthr, amp, freq=9.0, seed=1.0):
    """Borde inferior irregular (faldas y capas rotas): baja los vértices por debajo de zthr según el ángulo."""
    me = o.data
    for v in me.vertices:
        if v.co.z < zthr:
            a = math.atan2(v.co.y, v.co.x)
            v.co.z -= amp * (0.5 + 0.5 * math.sin(a * freq + seed) * math.cos(a * 3.1 + seed * 2)) * (1.0 if abs(math.sin(a * freq / 2 + seed)) > 0.25 else 0.2)
    o.data.update()
    return o


def displace(o, amp, freq=6.0, seed=0.0):
    """Relieve de 'esculpido': mueve cada vértice a lo largo de su normal con ruido."""
    me = o.data
    me.update()
    for v in me.vertices:
        n = noise.noise(v.co * freq + V((seed, seed * 1.7, seed * 0.3)))
        v.co += v.normal * n * amp
    me.update()


# ------------------------------------------------------------------ color
def shade(p, n, base, grime=1.0):
    f = 0.78 + 0.44 * fbm(p, 9.0)
    f *= 0.88 + 0.24 * fbm(p, 2.5)
    c = [x * f for x in base]
    if n.z < -0.25:
        c = [x * 0.62 for x in c]               # cavidades
    k = 1.0 - grime * 0.35 * max(0.0, 1.0 - p.z / 0.55)   # suciedad cerca del suelo
    return tuple(x * k for x in c)


def paint(o, col, amp=0.0, fn=None, emit=False):
    me = o.data
    me.update()
    if amp > 0:
        displace(o, amp, 14.0, random.random() * 10)
    if "Col" in me.color_attributes:
        me.color_attributes.remove(me.color_attributes["Col"])
    ca = me.color_attributes.new("Col", 'FLOAT_COLOR', 'POINT')
    for v in me.vertices:
        if emit:
            c = col
        else:
            base = fn(v.co) if fn else col
            c = shade(v.co, v.normal, base)
        ca.data[v.index].color = (*lin(c), 1.0)


# ------------------------------------------------------------------ cuerpo con Skin
def skin_body(name, nodes, edges, sub=1, bone="spine", fn=None, amp=0.012, root="hip"):
    ids = list(nodes)
    ix = {k: i for i, k in enumerate(ids)}
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(nodes[k][:3]) for k in ids], [(ix[a], ix[b]) for a, b in edges], [])
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.modifier_add(type='SKIN')
    for k in ids:
        sv = me.skin_vertices[0].data[ix[k]]
        sv.radius = (nodes[k][3], nodes[k][4])
    me.skin_vertices[0].data[ix[root]].use_root = True
    ob.modifiers["Skin"].use_smooth_shade = False
    ss = ob.modifiers.new("Subsurf", 'SUBSURF')
    ss.levels = sub
    ss.render_levels = sub
    bpy.ops.object.modifier_apply(modifier="Skin")
    bpy.ops.object.modifier_apply(modifier="Subsurf")
    ob.select_set(False)
    for p in me.polygons:
        p.use_smooth = False
    ob["bone"] = bone
    displace(ob, amp, 7.0, random.random() * 10)
    me = ob.data
    for ca in list(me.color_attributes):
        me.color_attributes.remove(ca)
    ca = me.color_attributes.new("Col", 'FLOAT_COLOR', 'POINT')
    for v in me.vertices:
        c = shade(v.co, v.normal, fn(v.co) if fn else (.5, .5, .5))
        ca.data[v.index].color = (*lin(c), 1.0)
    return ob


def mirror(d, name, x, y, z, rx, ry):
    d[name + "_l"] = (-x, y, z, rx, ry)
    d[name + "_r"] = (x, y, z, rx, ry)


# ------------------------------------------------------------------ rig + export
def export(name, body, parts, bones, anims):
    allp = [body] + parts
    _regroup(parts, bones)
    anims = {k: _full(bones, v) for k, v in anims.items()}
    bpy.ops.object.select_all(action='DESELECT')
    arm_d = bpy.data.armatures.new("Rig")
    arm = bpy.data.objects.new("Rig", arm_d)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode='EDIT')
    eb = arm_d.edit_bones
    for n, (h, t, p) in bones.items():
        e = eb.new(n)
        e.head = h
        e.tail = t
        if p:
            e.parent = eb[p]
    bpy.ops.object.mode_set(mode='OBJECT')
    # material: color de vértice
    m = bpy.data.materials.new("vc")
    m.use_nodes = True
    nt = m.node_tree
    bs = nt.nodes["Principled BSDF"]
    vc = nt.nodes.new("ShaderNodeVertexColor")
    vc.layer_name = "Col"
    nt.links.new(vc.outputs["Color"], bs.inputs["Base Color"])
    for o in allp:
        o.data.materials.append(m)
    # cuerpo: pesos automáticos
    bpy.ops.object.select_all(action='DESELECT')
    body.select_set(True)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.parent_set(type='ARMATURE_AUTO')
    # accesorios: pesos rígidos al hueso
    for o in parts:
        vg = o.vertex_groups.new(name=o["bone"])
        vg.add(list(range(len(o.data.vertices))), 1.0, 'REPLACE')
        o.modifiers.new("Arm", 'ARMATURE').object = arm
        o.parent = arm
    for an, fr in anims.items():
        arm.animation_data_create()
        act = bpy.data.actions.new(an)
        arm.animation_data.action = act
        bpy.context.view_layer.objects.active = arm
        bpy.ops.object.mode_set(mode='POSE')
        for f, d in fr.items():
            for b, r in d.items():
                loc = b.endswith("_loc")
                bn = b[:-4] if loc else b
                if bn not in arm.pose.bones:
                    continue
                pb = arm.pose.bones[bn]
                if loc:
                    pb.location = r
                    pb.keyframe_insert("location", frame=f)
                else:
                    pb.rotation_mode = 'XYZ'
                    pb.rotation_euler = r
                    pb.keyframe_insert("rotation_euler", frame=f)
        bpy.ops.object.mode_set(mode='OBJECT')
        tr = arm.animation_data.nla_tracks.new()
        tr.name = an
        tr.strips.new(an, 0, act)
        arm.animation_data.action = None
    bpy.ops.wm.save_as_mainfile(filepath=OUT + name + ".blend")
    # une todas las mallas en una sola (1 llamada de dibujo por personaje en vez de ~25)
    bpy.ops.object.select_all(action='DESELECT')
    for o in allp:
        o.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.join()
    bpy.ops.object.select_all(action='DESELECT')
    body.select_set(True)
    arm.select_set(True)
    bpy.ops.export_scene.gltf(filepath=OUT + name + ".glb", export_format='GLB', use_selection=True,
                              export_animations=True, export_nla_strips=True, export_vertex_color='ACTIVE')
    tris = len(body.data.polygons)
    print("LISTO", name, "polígonos:", tris)


def std_bones(P):
    """Huesos de humanoide con codos, rodillas y pies a partir de puntos clave P."""
    B = {"root": (V((0, 0, 0)), V((0, 0, P["hip"][2])), None),
         "spine": (V(P["hip"]), V(P["neck"]), "root"),
         "head": (V(P["neck"]), V(P["headtop"]), "spine")}
    for sd in ("l", "r"):
        sh, ha = V(P["sh_" + sd]), V(P["hand_" + sd])
        el = (sh + ha) * 0.5 + V((0, -0.015, 0))
        B["arm_" + sd] = (sh, el, "spine")
        B["fore_" + sd] = (el, ha, "arm_" + sd)
    if "hipj_l" in P:
        ah = 0.07 if P["hip"][2] > 0.8 else 0.04
        for sd in ("l", "r"):
            hj, ft = V(P["hipj_" + sd]), V(P["foot_" + sd])
            an = V((ft.x, ft.y - 0.01, max(ft.z, 0) + ah))
            kn = (hj + an) * 0.5 + V((0, 0.02, 0))
            B["leg_" + sd] = (hj, kn, "root")
            B["shin_" + sd] = (kn, an, "leg_" + sd)
            B["foot_" + sd] = (an, V((ft.x, ft.y + 0.15 * (1 if ah > .05 else .7), max(ft.z, 0) + 0.01)), "shin_" + sd)
    return B


def _regroup(parts, bones):
    """Reasigna accesorios rígidos al hueso del segmento (brazo/antebrazo, muslo/pantorrilla/pie)."""
    for o in parts:
        b = o["bone"]
        if b[:4] not in ("arm_", "leg_") or ("fore_" + b[-1]) not in bones and ("shin_" + b[-1]) not in bones:
            continue
        c = sum((v.co for v in o.data.vertices), Vector()) / max(1, len(o.data.vertices))
        sd = b[-1]
        if b.startswith("arm_"):
            h, t = bones["arm_" + sd][0], bones["fore_" + sd][1]
            ax = t - h
            if (c - h).dot(ax) / ax.length_squared > 0.5:
                o["bone"] = "fore_" + sd
        else:
            kn, an = bones["shin_" + sd][0], bones["foot_" + sd][0]
            if c.z < an.z - 0.005 or (c.z < an.z + 0.04 and c.y > an.y + 0.03):
                o["bone"] = "foot_" + sd
            elif c.z < kn.z:
                o["bone"] = "shin_" + sd


def _full(bones, fr):
    """Rellena todos los huesos en cada fotograma (rotación 0 por defecto)."""
    return {f: {b: d.get(b, (0, 0, 0)) for b in bones if not b.endswith("_loc")} | {k: v for k, v in d.items() if k.endswith("_loc")} for f, d in fr.items()}


def std_anims(s=0.55, arm_s=0.4, legs=True, hunch=0.0, fly=False):
    """Animaciones: idle, walk, attack, hit, death. Valores en radianes; *_loc = desplazamiento del hueso."""
    names = ["root", "spine", "head", "arm_l", "arm_r", "fore_l", "fore_r"] + (["leg_l", "leg_r", "shin_l", "shin_r", "foot_l", "foot_r"] if legs else [])
    C = math.cos; S = math.sin; PI = math.pi

    def Z(**kw):
        d = {n: (0, 0, 0) for n in names}
        for k, v in kw.items():
            d[k] = v
        return d

    # ---------------- walk (32 fotogramas, 8 muestras)
    walk = {}
    for i in range(9):
        ph = i / 8.0
        a = 2 * PI * ph
        sw = C(a)
        d = Z()
        if legs:
            for sd, sg in (("l", 1), ("r", -1)):
                x = s * sg * C(a)
                swing = max(0.0, -sg * S(a))          # pierna en el aire (hacia delante)
                knee = -(0.25 * s + 1.3 * s * swing)
                d["leg_" + sd] = (x, 0, 0)
                d["shin_" + sd] = (knee, 0, 0)
                d["foot_" + sd] = (-(x + knee) * 0.75 - 0.1 * max(0, -sg * C(a)), 0, 0)
        for sd, sg in (("l", -1), ("r", 1)):
            x = arm_s * sg * C(a)
            d["arm_" + sd] = (x, 0, 0.06 if sd == "l" else -0.06)
            d["fore_" + sd] = (0.35 + 0.45 * max(0.0, sg * C(a)) + 0.1, 0, 0)
        d["spine"] = (0.05 + hunch, 0.14 * C(a), 0.04 * S(a))
        d["head"] = (-0.04 + 0.03 * C(2 * a), -0.1 * C(a), 0)
        d["root_loc"] = (0.015 * S(a), 0.03 * (1 - C(2 * a)) / 2 - 0.02, 0)
        if fly:
            d["root_loc"] = (0.02 * S(a), 0.06 * S(a * 0.5) + 0.03, 0)
            d["spine"] = (0.12 + hunch, 0.1 * C(a), 0.08 * S(a))
        walk[1 + i * 4] = d

    # ---------------- idle (72 fotogramas): respirar, mirar, balanceo de peso
    idle = {}
    for i, f in enumerate(range(1, 74, 12)):
        ph = (f - 1) / 72.0
        a = 2 * PI * ph
        d = Z()
        d["spine"] = (hunch + 0.025 * S(a), 0.05 * S(a), 0.02 * S(a))
        d["head"] = (-0.03 * S(a + 1), 0.28 * S(a), 0.04 * S(a * 2))
        d["arm_l"] = (0.06 * S(a + 0.5) - 0.03, 0, 0.05 + 0.02 * S(a))
        d["arm_r"] = (0.06 * S(a + 2.5) - 0.03, 0, -0.05 - 0.02 * S(a))
        d["fore_l"] = (0.18 + 0.1 * S(a + 1.0), 0, 0)
        d["fore_r"] = (0.18 + 0.1 * S(a + 3.0), 0, 0)
        if legs:
            d["leg_l"] = (0.04 * S(a), 0, 0)
            d["leg_r"] = (-0.04 * S(a), 0, 0)
            d["shin_l"] = (-0.05 - 0.04 * max(0, S(a)), 0, 0)
            d["shin_r"] = (-0.05 - 0.04 * max(0, -S(a)), 0, 0)
            d["foot_l"] = (0.03, 0, 0)
            d["foot_r"] = (0.03, 0, 0)
        d["root_loc"] = (0.02 * S(a), 0.012 * S(2 * a) - (0.015 if legs else 0), 0)
        if fly:
            d["root_loc"] = (0.02 * S(a), 0.05 * S(2 * a) + 0.03, 0)
        idle[f] = d

    # ---------------- attack (30): armar, golpear, recuperar
    def A(f, **kw):
        return f, Z(**kw)
    atk = dict([
        A(1, spine=(hunch, 0, 0), arm_r=(0, 0, 0)),
        A(9, spine=(hunch - 0.28, -0.5, 0), head=(0.1, 0.3, 0), arm_r=(2.7, 0, -0.15), fore_r=(1.3, 0, 0), arm_l=(-0.7, 0, 0.1), fore_l=(0.6, 0, 0),
          **({"leg_l": (-0.15, 0, 0), "leg_r": (0.35, 0, 0), "shin_l": (-0.3, 0, 0), "shin_r": (-0.55, 0, 0), "foot_l": (0.1, 0, 0), "foot_r": (0.1, 0, 0)} if legs else {}), root_loc=(0, -0.05, 0)),
        A(14, spine=(hunch + 0.42, 0.55, 0), head=(-0.15, -0.3, 0), arm_r=(0.2, 0, 0.1), fore_r=(0.15, 0, 0), arm_l=(-1.0, 0, 0.1), fore_l=(0.9, 0, 0),
          **({"leg_l": (0.7, 0, 0), "leg_r": (-0.4, 0, 0), "shin_l": (-0.35, 0, 0), "shin_r": (-0.2, 0, 0), "foot_l": (-0.3, 0, 0), "foot_r": (0.3, 0, 0)} if legs else {}), root_loc=(0, -0.09, 0.0)),
        A(22, spine=(hunch + 0.2, 0.25, 0), arm_r=(0.8, 0, 0), fore_r=(0.5, 0, 0), arm_l=(-0.4, 0, 0), fore_l=(0.5, 0, 0),
          **({"leg_l": (0.5, 0, 0), "leg_r": (-0.25, 0, 0), "shin_l": (-0.3, 0, 0), "shin_r": (-0.2, 0, 0)} if legs else {}), root_loc=(0, -0.05, 0)),
        A(30, spine=(hunch, 0, 0), arm_r=(0, 0, 0)),
    ])

    # ---------------- hit (18): retroceso
    hit = dict([
        A(1),
        A(5, spine=(hunch - 0.4, 0.2, 0.1), head=(-0.45, -0.3, 0), arm_l=(-0.5, 0, 0.5), arm_r=(-0.5, 0, -0.5), fore_l=(0.4, 0, 0), fore_r=(0.4, 0, 0),
          **({"leg_l": (-0.25, 0, 0), "leg_r": (0.2, 0, 0), "shin_l": (-0.4, 0, 0), "shin_r": (-0.5, 0, 0)} if legs else {}), root_loc=(0, -0.06, 0.06)),
        A(11, spine=(hunch - 0.15, 0.08, 0), head=(-0.15, -0.1, 0), arm_l=(-0.2, 0, 0.2), arm_r=(-0.2, 0, -0.2), fore_l=(0.5, 0, 0), fore_r=(0.5, 0, 0), root_loc=(0, -0.03, 0.03)),
        A(18),
    ])

    # ---------------- death (44): tambalea, se arrodilla y cae de espaldas (no se repite)
    dth = dict([
        A(1),
        A(8, spine=(hunch - 0.3, 0.2, 0), head=(-0.5, 0.4, 0), arm_l=(-0.6, 0, 0.6), arm_r=(-0.6, 0, -0.6), fore_l=(0.3, 0, 0), fore_r=(0.3, 0, 0),
          **({"leg_l": (0.3, 0, 0), "leg_r": (-0.2, 0, 0), "shin_l": (-0.6, 0, 0), "shin_r": (-0.6, 0, 0)} if legs else {}), root_loc=(0, -0.08, 0)),
        A(20, spine=(hunch + 0.45, 0, 0.1), head=(0.5, 0.2, 0), arm_l=(0.2, 0, 0.3), arm_r=(0.3, 0, -0.3), fore_l=(0.6, 0, 0), fore_r=(0.5, 0, 0),
          **({"leg_l": (1.2, 0, 0), "leg_r": (1.1, 0, 0), "shin_l": (-1.9, 0, 0), "shin_r": (-1.9, 0, 0), "foot_l": (0.2, 0, 0), "foot_r": (0.2, 0, 0)} if legs else {}), root_loc=(0, -0.42 if legs else -0.1, 0)),
        A(34, root=(1.35, 0, 0), spine=(hunch - 0.2, 0, 0), head=(-0.3, 0, 0), arm_l=(-0.8, 0, 0.8), arm_r=(-0.8, 0, -0.8), fore_l=(0.3, 0, 0), fore_r=(0.3, 0, 0),
          **({"leg_l": (0.4, 0, 0), "leg_r": (0.2, 0, 0.1), "shin_l": (-0.4, 0, 0), "shin_r": (-0.2, 0, 0)} if legs else {}), root_loc=(0, 0.12, 0)),
        A(44, root=(1.5, 0, 0), spine=(0, 0, 0), arm_l=(-0.9, 0, 0.9), arm_r=(-0.9, 0, -0.9), root_loc=(0, 0.14, 0)),
    ])
    return {"idle": idle, "walk": walk, "attack": atk, "hit": hit, "death": dth}


# ------------------------------------------------------------------ cabeza humana reutilizable
def human_head(P, hc, skin, hair=None, bone="head", scale=1.0, eyec=(.12, .1, .08), brow=None, nose=1.0):
    """Cabeza con cráneo, mandíbula, nariz, cejas, ojos, orejas y boca. hc = centro de la cara."""
    s = scale
    h = V(hc)
    SKN = skin
    P.append(blob("cr", h + V((0, .0, .04 * s)), (.088 * s, .1 * s, .105 * s), bone=bone, col=SKN, amp=.004))
    P.append(blob("jaw", h + V((0, .025 * s, -.03 * s)), (.07 * s, .072 * s, .06 * s), bone=bone, col=SKN, amp=.004))
    P.append(blob("nariz", h + V((0, .095 * s, -.0)), (.016 * s, .03 * s * nose, .028 * s * nose), bone=bone, col=tuple(x * .93 for x in SKN)))
    P.append(slab("ceja", h + V((0, .082 * s, .047 * s)), (.105 * s, .03 * s, .016 * s), bone=bone, col=brow or tuple(x * .55 for x in SKN), bev=.004, amp=0))
    for sx in (-1, 1):
        P.append(blob(f"ojb{sx}", h + V((sx * .037 * s, .088 * s, .022 * s)), (.017 * s, .011 * s, .012 * s), bone=bone, col=(.85, .85, .8), emit=True))
        P.append(blob(f"oj{sx}", h + V((sx * .037 * s, .097 * s, .022 * s)), (.008 * s, .005 * s, .008 * s), bone=bone, col=eyec, emit=True))
        P.append(blob(f"or{sx}", h + V((sx * .09 * s, .0, .02 * s)), (.012 * s, .02 * s, .035 * s), bone=bone, col=tuple(x * .95 for x in SKN)))
    P.append(slab("boca", h + V((0, .092 * s, -.05 * s)), (.04 * s, .01 * s, .008 * s), bone=bone, col=(.3, .12, .1), bev=.002, amp=0, emit=True))
    if hair:
        P.append(blob("pelo", h + V((0, -.018 * s, .062 * s)), (.096 * s, .108 * s, .098 * s), bone=bone, col=hair, amp=.007))
    return P
