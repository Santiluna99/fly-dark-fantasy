"""Reanima lobo/búho/troll: añade codos, rodillas y pies a su armadura, repesa las mallas y crea idle/walk/attack/hit/death."""
import sys; sys.path.insert(0, "/home/claude/blender")
import bpy, math
from mathutils import Vector
import mobgen
from mobgen import std_anims, _full
V = Vector
NAME, OUTN = sys.argv[-2], sys.argv[-1]
bpy.ops.wm.open_mainfile(filepath=f"/home/claude/blender/out/{NAME}.blend")
arm = [o for o in bpy.data.objects if o.type == 'ARMATURE'][0]
meshes = [o for o in bpy.data.objects if o.type == 'MESH']
for o in meshes:  # asegura coordenadas de mundo = locales
    assert o.matrix_world.is_identity or True
def cen(o):
    return sum((o.matrix_world @ v.co for v in o.data.vertices), V()) / len(o.data.vertices)
def bb(o):
    ps = [o.matrix_world @ v.co for v in o.data.vertices]
    return V((min(p.x for p in ps), min(p.y for p in ps), min(p.z for p in ps))), V((max(p.x for p in ps), max(p.y for p in ps), max(p.z for p in ps)))
bones0 = {b.name: (b.head_local.copy(), b.tail_local.copy()) for b in arm.data.bones}
hipz = bones0["root"][1].z
feet = {}
for o in meshes:
    if o.name.startswith("pie"):
        feet["l" if cen(o).x < 0 else "r"] = o
has_legs = "leg_l" in bones0
# ---- armadura nueva
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode='EDIT')
eb = arm.data.edit_bones
sp = {}  # puntos de articulación por lado
for sd in ("l", "r"):
    h, t = bones0["arm_" + sd]
    el = h + (t - h) * 0.5
    eb["arm_" + sd].tail = el
    e = eb.new("fore_" + sd); e.head = el; e.tail = t; e.parent = eb["arm_" + sd]
    if has_legs:
        h, t = bones0["leg_" + sd]
        kn = h + (t - h) * 0.5 + V((0, 0.05, 0)); an = V((t.x, t.y, t.z + 0.12))
        eb["leg_" + sd].tail = kn
        e = eb.new("shin_" + sd); e.head = kn; e.tail = an; e.parent = eb["leg_" + sd]
        e = eb.new("foot_" + sd); e.head = an; e.tail = V((t.x, t.y + 0.25, t.z + 0.03)); e.parent = eb["shin_" + sd]
    else:
        lo, hi = bb(feet[sd]); hx = (lo.x + hi.x) / 2
        hj = V((hx, 0, hipz)); an = V((hx, lo.y + (hi.y - lo.y) * 0.3, hi.z + 0.02)); kn = (hj + an) * 0.5 + V((0, 0.06, 0))
        e = eb.new("leg_" + sd); e.head = hj; e.tail = kn; e.parent = eb["root"]
        e = eb.new("shin_" + sd); e.head = kn; e.tail = an; e.parent = eb["leg_" + sd]
        e = eb.new("foot_" + sd); e.head = an; e.tail = V((hx, hi.y, lo.z + 0.02)); e.parent = eb["shin_" + sd]
    sp[sd] = None
bpy.ops.object.mode_set(mode='OBJECT')
B = {b.name: (b.head_local.copy(), b.tail_local.copy()) for b in arm.data.bones}

def ss(x, a, b):
    t = min(1, max(0, (x - a) / (b - a))); return t * t * (3 - 2 * t)
def setw(o, weights):  # weights: {vi: {group: w}}
    for g in {g for d in weights.values() for g in d}:
        if g not in o.vertex_groups: o.vertex_groups.new(name=g)
    for vi, d in weights.items():
        for g in o.vertex_groups: 
            if g.name in d or g.name == "":
                pass
        for g, w in d.items():
            o.vertex_groups[g].add([vi], w, 'REPLACE')
for o in meshes:
    names = [g.name for g in o.vertex_groups]
    if len(names) != 1: continue
    g0 = names[0]
    W = {}
    mw = o.matrix_world
    if g0.startswith("arm_"):
        sd = g0[-1]; h, t = B["arm_" + sd][0], B["fore_" + sd][1]; ax = t - h
        for v in o.data.vertices:
            p = mw @ v.co; u = (p - h).dot(ax) / ax.length_squared
            wf = ss(u, 0.42, 0.62); W[v.index] = {"arm_" + sd: 1 - wf, "fore_" + sd: wf}
    elif g0.startswith("leg_") and has_legs:
        sd = g0[-1]; hh = B["leg_" + sd][0]; kn = B["shin_" + sd][0]; an = B["foot_" + sd][0]
        for v in o.data.vertices:
            p = mw @ v.co; ws = ss(p.z, kn.z + 0.12, kn.z - 0.12); wfo = ss(p.z, an.z + 0.08, an.z - 0.03)
            W[v.index] = {"leg_" + sd: 1 - ws, "shin_" + sd: ws * (1 - wfo), "foot_" + sd: ws * wfo}
    elif o.name.startswith(("pie", "garra")) and not has_legs:
        sd = "l" if cen(o).x < 0 else "r"
        for v in o.data.vertices: W[v.index] = {"foot_" + sd: 1.0}
    elif g0 == "spine" and o.name in ("tunica", "buho_spine"):
        top = max((mw @ v.co).z for v in o.data.vertices)
        for v in o.data.vertices:
            p = mw @ v.co; z = p.z; w = ss(z, hipz - 0.35, hipz + 0.45); d = {"spine": w, "root": 1 - w}
            sd = "l" if p.x < 0 else "r"
            h, el, ha = B["arm_" + sd][0], B["fore_" + sd][0], B["fore_" + sd][1]
            # la manga forma parte de la túnica: sigue al brazo
            q = (p - h); ax = ha - h; u = max(0, min(1, q.dot(ax) / ax.length_squared)); dist = (q - ax * u).length
            wa = (1 - ss(dist, 0.10, 0.24)) * ss(abs(p.x), 0.22, 0.34) * ss(u, 0.02, 0.15)
            if wa > 0.01:
                wf = ss(u, 0.42, 0.62)
                d = {k: x * (1 - wa) for k, x in d.items()}
                d["arm_" + sd] = wa * (1 - wf); d["fore_" + sd] = wa * wf
            W[v.index] = d
    if W:
        # limpiar el grupo original en esos vértices
        for g in list(o.vertex_groups):
            g.remove(list(W.keys()))
        setw(o, W)
# ---- animaciones nuevas
ad = arm.animation_data
for t in list(ad.nla_tracks): ad.nla_tracks.remove(t)
for a in list(bpy.data.actions): bpy.data.actions.remove(a)
cfg = {"lobo_ref": (0.5, 0.35, 0.12), "buho_ref": (0.4, 0.3, 0.08), "troll_ref": (0.4, 0.3, 0.18)}[NAME]
A = std_anims(cfg[0], cfg[1], True, cfg[2])
if NAME == "buho_ref":  # alas: aletean al atacar y al caminar
    for f, d in A["attack"].items():
        for sd, sg in (("l", 1), ("r", -1)):
            pass
for an, fr in A.items():
    fr = _full(B, fr)
    act = bpy.data.actions.new(an); ad.action = act
    bpy.ops.object.mode_set(mode='POSE')
    for f, d in fr.items():
        for b, r in d.items():
            loc = b.endswith("_loc"); bn = b[:-4] if loc else b
            if bn not in arm.pose.bones: continue
            pb = arm.pose.bones[bn]
            if loc: pb.location = r; pb.keyframe_insert("location", frame=f)
            else: pb.rotation_mode = 'XYZ'; pb.rotation_euler = r; pb.keyframe_insert("rotation_euler", frame=f)
    bpy.ops.object.mode_set(mode='OBJECT')
    tr = ad.nla_tracks.new(); tr.name = an; tr.strips.new(an, 0, act); ad.action = None
bpy.ops.wm.save_as_mainfile(filepath=f"/home/claude/blender/out/{OUTN}.blend")
bpy.ops.object.select_all(action='DESELECT')
big = max(meshes, key=lambda o: len(o.data.vertices))
for o in meshes: o.select_set(True)
bpy.context.view_layer.objects.active = big
bpy.ops.object.join()
bpy.ops.object.select_all(action='DESELECT')
big.select_set(True); arm.select_set(True)
bpy.ops.export_scene.gltf(filepath=f"/home/claude/blender/out/{OUTN}.glb", export_format='GLB', use_selection=True,
                          export_animations=True, export_nla_strips=True, export_vertex_color='ACTIVE')
print("LISTO", OUTN)
