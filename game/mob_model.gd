# Hollowfly - Copyright (C) 2026 Santiluna99
# Software libre bajo la GNU GPL v3 (ver LICENSE y NOTICE).
class_name MobModel
## Personajes low-poly con rostro, manos, ropa y extremidades animables.
## Variantes: human, knight, goat, owl (culto), goblin, ogre (monstruos)

# Cachés (mallas y materiales compartidos entre todos los mobs, para ir rápido).
# force_variant solo sirve para pruebas y capturas.
static var _meshes := {}
static var _mats := {}
static var force_variant := ""   # solo para pruebas/capturas
# Color casi negro usado para pupilas, botas y detalles.
const DARK := Color(0.06, 0.05, 0.07)


## Elige el modelo según la facción: humano, caballero, (búho|cabra|lobo), (goblin|ogro).
static func pick_variant(f: int, big: bool) -> String:
	if force_variant != "":
		return force_variant
	match f:
		0: return "human"
		1: return "knight"
		2: return ["owl", "goat", "wolf", "wolf", "plague"].pick_random()
	return "ogre" if big else ["goblin", "goblin", "skeleton", "ghoul", "wraith"].pick_random()


## Malla primitiva compartida: box, sph (esfera), cyl, cone, frust (tronco de cono).
static func _mesh(k: String) -> Mesh:
	if _meshes.has(k):
		return _meshes[k]
	var m: Mesh
	if k == "box":
		var b := BoxMesh.new()
		b.size = Vector3.ONE
		m = b
	elif k == "sph":
		var s := SphereMesh.new()
		s.radius = 0.5
		s.height = 1.0
		s.radial_segments = 8
		s.rings = 5
		m = s
	else:
		var c := CylinderMesh.new()
		c.height = 1.0
		c.rings = 1
		c.radial_segments = 8
		c.bottom_radius = 0.5
		c.top_radius = 0.0 if k == "cone" else (0.28 if k == "frust" else 0.5)
		m = c
	_meshes[k] = m
	return m


## Envejece un color (sucio, apagado): menos saturación y algo más oscuro. Los emisivos no pasan por aquí.
static func _age(c: Color) -> Color:
	var l := c.get_luminance()
	var g := Color(l, l, l)
	var o := c.lerp(g, 0.38)
	return Color(o.r * 0.93, o.g * 0.97, o.b * 0.92, c.a)


## Material de una pieza del personaje. Elige textura según el color: pelaje, tela, metal o piel.
static func mat(w, col: Color, emit := 0.0, grain := 0.45) -> ShaderMaterial:
	var key := "%s|%s|%s" % [col.to_html(false), emit, grain]
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = w.shader
	m.set_shader_parameter("emit", emit)
	m.set_shader_parameter("object_space", true)
	if emit > 0.0 or grain <= 0.0 or Assets.tex("cloth") == null:
		m.set_shader_parameter("tint", col if emit > 0.0 else _age(col))
		m.set_shader_parameter("grain", grain)
		m.set_shader_parameter("texscale", 14.0)
	else:
		var tn := "cloth"
		if grain >= 0.6:
			tn = "fur"
		elif absf(col.r - col.g) < 0.08 and col.b >= col.r - 0.02 and col.get_luminance() > 0.25:
			tn = "metal"
		elif col.r > col.g and col.g > col.b and col.r - col.b > 0.2 and col.get_luminance() > 0.3:
			tn = "skin"
		m.set_shader_parameter("pattern", 5)
		m.set_shader_parameter("tex", Assets.tex(tn))
		m.set_shader_parameter("tint", _age(col))
		m.set_shader_parameter("tex_scale", 2.6)
		m.set_shader_parameter("tex_gain", 2.0)
	_mats[key] = m
	return m


## Malla esculpida (assets/models) + ojos emisivos. Devuelve false si no existe el archivo.
static func _sculpt(parent: Node3D, w, name: String, pos: Vector3, scl: float) -> bool:
	var d: Dictionary = Assets.model(name)
	if d.is_empty() or Assets.tex("fur") == null:
		return false
	var key := "sculpt|%s" % [name]
	var m: ShaderMaterial
	if _mats.has(key):
		m = _mats[key]
	else:
		m = ShaderMaterial.new()
		m.shader = w.shader
		m.set_shader_parameter("pattern", 5)
		m.set_shader_parameter("object_space", true)
		m.set_shader_parameter("tex", Assets.tex("fur"))
		m.set_shader_parameter("tint", Color(1, 1, 1))
		m.set_shader_parameter("tex_scale", 5.0)
		m.set_shader_parameter("tex_gain", 1.9)
		_mats[key] = m
	var mi := MeshInstance3D.new()
	mi.mesh = d["mesh"]
	mi.material_override = m
	mi.position = pos
	mi.scale = Vector3.ONE * scl
	parent.add_child(mi)
	var meta: Dictionary = d["meta"]
	var ec := Color(meta["eye_color"][0], meta["eye_color"][1], meta["eye_color"][2])
	for e in meta["eyes"]:
		var p := Vector3(e[0], e[1], e[2]) * scl
		var r: float = float(e[3]) * scl
		part(parent, w, "sph", pos + p, Vector3.ONE * r * 1.8, ec, float(meta["eye_emit"]), Vector3.ZERO, 0.0)
		part(parent, w, "sph", pos + p + Vector3(0, 0, -r * 0.55), Vector3.ONE * r * 0.7, DARK, 0.0, Vector3.ZERO, 0.0)
	return true


## Añade una pieza (caja/esfera/cono...) a un personaje con posición, escala, color, brillo y rotación.
static func part(parent: Node3D, w, kind: String, pos: Vector3, scl: Vector3, col: Color,
		emit := 0.0, rot := Vector3.ZERO, grain := 0.45) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh(kind)
	mi.material_override = mat(w, col, emit, grain)
	mi.position = pos
	mi.scale = scl
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi


## Nodo vacío articulado (hombro, cadera, cuello) para poder girar un miembro entero al animar.
static func pivot(parent: Node3D, pname: String, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = pname
	n.position = pos
	parent.add_child(n)
	return n


## Construye el personaje completo según la variante y devuelve su "rig": nodos de brazos, piernas y cabeza,
## altura de ojos, radio y alto de colisión. Aplica el factor de escala (ogro grande, goblin pequeño).
static func build(body: Node3D, w, variant: String, big: bool) -> Dictionary:
	var rig := {"eye": 1.6, "r": 0.35, "h": 1.8, "k": 1.0, "arm_base": 0.0}
	# Si existe el modelo de Blender (.glb) de esta variante se usa ese; si no, el modelo de primitivas.
	# variante -> [archivo .glb, escala, altura de ojos, radio y alto de colisión]. Si falta el archivo, se usan las primitivas.
	var glb := {"wolf": ["char_wolf", 0.80, 2.2, 0.55, 2.6], "owl": ["char_owl", 0.82, 2.2, 0.55, 2.6], "ogre": ["char_troll", 0.95, 2.2, 0.55, 2.6],
		"skeleton": ["mob_skeleton", 1.0, 1.75, 0.3, 1.9], "ghoul": ["mob_ghoul", 1.0, 1.5, 0.38, 1.6], "wraith": ["mob_wraith", 1.0, 1.8, 0.4, 2.0],
		"plague": ["mob_plague", 1.0, 1.75, 0.33, 1.95], "human": ["mob_human_%d" % (randi() % 3), 1.0, 1.65, 0.32, 1.8], "knight": ["mob_knight", 1.0, 1.7, 0.36, 1.9],
		"goblin": ["mob_goblin_%d" % (randi() % 2), 1.0, 1.0, 0.25, 1.1], "goat": ["mob_goat", 1.0, 1.75, 0.35, 1.95]}
	if glb.has(variant) and _glb(body, w, rig, glb[variant][0], glb[variant][1], glb[variant][2], glb[variant][3], glb[variant][4]):
		var kk: float = rig["k"]
		body.scale = Vector3.ONE * kk
		rig["eye"] = float(rig["eye"]) * kk
		rig["r"] = float(rig["r"]) * kk
		rig["h"] = float(rig["h"]) * kk
		return rig
	match variant:
		"human": _human(body, w, rig, false)
		"knight": _human(body, w, rig, true)
		"goat": _cult(body, w, rig, "goat")
		"owl": _cult(body, w, rig, "owl")
		"wolf": _cult(body, w, rig, "wolf")
		"skeleton": _skeleton(body, w, rig)
		"wraith": _wraith(body, w, rig)
		"ghoul": _ghoul(body, w, rig)
		"plague": _plague(body, w, rig)
		"ogre": _ogre(body, w, rig, false)
		_: _ogre(body, w, rig, true)
	var k: float = rig["k"]
	body.scale = Vector3.ONE * k
	rig["eye"] = float(rig["eye"]) * k
	rig["r"] = float(rig["r"]) * k
	rig["h"] = float(rig["h"]) * k
	return rig


# ------------------------------------------------------------------ humanos
## Aldeano o caballero: torso, piernas, brazos, cabeza con cara; el caballero lleva casco, escudo y espada.
static func _human(b: Node3D, w, rig: Dictionary, knight: bool) -> void:
	var skin: Color = [Color(.74, .62, .52), Color(.6, .47, .37), Color(.8, .68, .58), Color(.46, .35, .28)].pick_random()
	var cloth: Color = [Color(.32, .27, .2), Color(.24, .22, .18), Color(.27, .31, .25), Color(.38, .2, .18)].pick_random()   # tonos de tela gastada
	var hair: Color = [Color(.15, .1, .07), Color(.45, .3, .15), Color(.7, .68, .6), Color(.6, .2, .1)].pick_random()
	var steel := Color(.27, .27, .3) if knight else Color(.5, .5, .52)   # acero oxidado
	var main: Color = steel if knight else cloth
	for s in [-1.0, 1.0]:
		var nm := "legL" if s < 0.0 else "legR"
		var leg := pivot(b, nm, Vector3(s * .13, .85, 0))
		part(leg, w, "cyl", Vector3(0, -.38, 0), Vector3(.2, .76, .2), steel.darkened(.25) if knight else Color(.27, .21, .17))
		part(leg, w, "box", Vector3(0, -.8, -.04), Vector3(.22, .14, .32), DARK)
		rig[nm] = leg
	part(b, w, "box", Vector3(0, 1.1, 0), Vector3(.52, .62, .3), main)
	part(b, w, "box", Vector3(0, .8, 0), Vector3(.54, .09, .32), DARK)
	part(b, w, "frust", Vector3(0, .66, 0), Vector3(.6, .35, .42), main.darkened(.1))
	for s in [-1.0, 1.0]:
		var nm2 := "armL" if s < 0.0 else "armR"
		var arm := pivot(b, nm2, Vector3(s * .35, 1.38, 0))
		part(arm, w, "cyl", Vector3(0, -.2, 0), Vector3(.16, .42, .16), main)
		part(arm, w, "sph", Vector3(0, -.47, 0), Vector3(.13, .13, .13), steel.darkened(.3) if knight else skin)
		rig[nm2] = arm
		if knight:
			part(b, w, "sph", Vector3(s * .37, 1.43, 0), Vector3(.24, .2, .24), steel.lightened(.1))
	var head := pivot(b, "head", Vector3(0, 1.42, 0))
	rig["head"] = head
	part(head, w, "cyl", Vector3(0, .04, 0), Vector3(.12, .12, .12), skin)
	part(head, w, "sph", Vector3(0, .2, 0), Vector3(.3, .34, .32), skin)
	part(head, w, "box", Vector3(0, .17, -.16), Vector3(.05, .08, .07), skin.darkened(.12))
	for s in [-1.0, 1.0]:
		part(head, w, "sph", Vector3(s * .065, .23, -.145), Vector3(.075, .055, .04), Color(.92, .92, .88))
		part(head, w, "sph", Vector3(s * .065, .23, -.165), Vector3(.035, .035, .02), Color(.1, .08, .06))
		part(head, w, "box", Vector3(s * .07, .285, -.15), Vector3(.085, .015, .02), hair.darkened(.3), 0.0, Vector3(0, 0, s * -12))
		part(head, w, "sph", Vector3(s * .15, .2, 0), Vector3(.05, .08, .05), skin)
	part(head, w, "box", Vector3(0, .1, -.15), Vector3(.09, .014, .02), Color(.35, .15, .12))
	if knight:
		part(head, w, "sph", Vector3(0, .22, .01), Vector3(.36, .4, .38), steel)
		part(head, w, "box", Vector3(0, .22, -.19), Vector3(.25, .05, .03), DARK)
		part(head, w, "box", Vector3(0, .13, -.19), Vector3(.05, .18, .03), steel.darkened(.15))
		for s in [-1.0, 1.0]:
			part(head, w, "sph", Vector3(s * .055, .22, -.19), Vector3(.03, .03, .02), Color(.6, .85, .8), 1.8)
		part(head, w, "cone", Vector3(0, .46, .05), Vector3(.1, .3, .25), Color(.3, .06, .06), 0.0, Vector3(-25, 0, 0))
		part(b, w, "box", Vector3(0, 1.0, .18), Vector3(.5, .95, .03), Color(.28, .07, .07))   # capa raída
		var aL: Node3D = rig["armL"]
		part(aL, w, "box", Vector3(-.12, -.3, -.06), Vector3(.06, .52, .4), Color(.26, .09, .09))
		part(aL, w, "box", Vector3(-.16, -.3, -.06), Vector3(.03, .4, .06), Color(.5, .42, .2))
		part(aL, w, "box", Vector3(-.16, -.3, -.06), Vector3(.03, .06, .3), Color(.5, .42, .2))
		var aR: Node3D = rig["armR"]
		part(aR, w, "box", Vector3(0, -.47, -.42), Vector3(.05, .03, .8), Color(.55, .52, .5))   # hoja mellada
		part(aR, w, "box", Vector3(0, -.47, -.05), Vector3(.22, .03, .04), Color(.4, .32, .18))
		rig["eye"] = 1.65
	else:
		var r := randf()
		if r < 0.4:
			part(head, w, "sph", Vector3(0, .24, .08), Vector3(.38, .4, .38), cloth.darkened(.15))
		elif r < 0.8:
			part(head, w, "sph", Vector3(0, .26, .04), Vector3(.33, .28, .34), hair)
		else:
			part(head, w, "cyl", Vector3(0, .36, 0), Vector3(.52, .03, .52), Color(.3, .22, .15))
			part(head, w, "cyl", Vector3(0, .45, 0), Vector3(.26, .2, .26), Color(.3, .22, .15))
		if randf() < 0.3:
			part(head, w, "box", Vector3(0, .05, -.12), Vector3(.16, .14, .08), hair)
		if randf() < 0.5:
			part(b, w, "box", Vector3(.3, .75, .1), Vector3(.22, .22, .14), Color(.35, .25, .15))


# -------------------------------------------------------------------- culto
## Miembros del culto con túnica azul: cabra, búho mago (libro luminoso y luciérnagas) o lobo alquimista.
## Las cabezas usan los modelos esculpidos (assets/models) y, si faltan, una versión hecha con primitivas.
static func _cult(b: Node3D, w, rig: Dictionary, variant: String) -> void:
	var robe := Color(.1, .15, .5)
	if variant == "wolf":
		robe = Color(.06, .09, .36)
	var trim := Color(.55, .45, .2)
	var fur: Color = Color(.78, .78, .8)
	if variant == "owl":
		fur = Color(.72, .7, .68)
	elif variant == "wolf":
		fur = Color(.36, .48, .38)
	part(b, w, "frust", Vector3(0, .75, 0), Vector3(1.0, 1.5, .9), robe)
	for i in 5:
		part(b, w, "box", Vector3((i - 2) * .12, .55, -.39 + absf(i - 2) * .03), Vector3(.04, 1.0, .03), robe.darkened(.35), 0.0, Vector3(0, 0, (i - 2) * 2.5))
	part(b, w, "cyl", Vector3(0, 1.0, 0), Vector3(.75, .07, .68), trim)
	part(b, w, "sph", Vector3(0, 1.42, 0), Vector3(.7, .28, .48), robe.darkened(.08))
	for s in [-1.0, 1.0]:
		var nm := "armL" if s < 0.0 else "armR"
		var arm := pivot(b, nm, Vector3(s * .36, 1.4, 0))
		part(arm, w, "frust", Vector3(0, -.3, 0), Vector3(.36, .6, .36), robe)
		part(arm, w, "sph", Vector3(0, -.62, 0), Vector3(.12, .12, .12), fur.darkened(.1))
		for c in 3:
			part(arm, w, "cone", Vector3((c - 1) * .035, -.7, -.03), Vector3(.025, .09, .025), DARK, 0.0, Vector3(180, 0, 0))
		rig[nm] = arm
		part(b, w, "box", Vector3(s * .14, .04, -.32), Vector3(.12, .07, .24), DARK)
	rig["arm_base"] = 0.9
	var head := pivot(b, "head", Vector3(0, 1.5, 0))
	rig["head"] = head
	if variant == "owl":
		if not _sculpt(head, w, "head_owl", Vector3(0, .22, 0), 1.25):
			part(head, w, "sph", Vector3(0, .22, 0), Vector3(.38, .36, .36), fur, 0.0, Vector3.ZERO, 0.7)
			for s in [-1.0, 1.0]:
				part(head, w, "sph", Vector3(s * .1, .22, -.12), Vector3(.2, .22, .1), Color(.88, .86, .82), 0.0, Vector3.ZERO, 0.55)
				part(head, w, "sph", Vector3(s * .1, .23, -.17), Vector3(.13, .13, .06), Color(1, .55, .05), 2.5)
				part(head, w, "sph", Vector3(s * .1, .23, -.2), Vector3(.06, .06, .03), DARK)
				part(head, w, "box", Vector3(s * .1, .32, -.17), Vector3(.13, .025, .04), Color(.2, .17, .15), 0.0, Vector3(0, 0, s * -20))
				part(head, w, "cone", Vector3(s * .14, .45, 0), Vector3(.08, .22, .06), fur.darkened(.1), 0.0, Vector3(0, 0, s * -25))
			part(head, w, "cone", Vector3(0, .13, -.2), Vector3(.085, .17, .085), Color(.15, .12, .1), 0.0, Vector3(-112, 0, 0))
		# libro brillante + luciérnagas
		part(b, w, "box", Vector3(-.11, 1.05, -.5), Vector3(.22, .02, .3), Color(1, .85, .3), 2.5, Vector3(-30, 0, 12))
		part(b, w, "box", Vector3(.11, 1.05, -.5), Vector3(.22, .02, .3), Color(1, .85, .3), 2.5, Vector3(-30, 0, -12))
		part(b, w, "box", Vector3(0, 1.0, -.47), Vector3(.04, .04, .3), Color(.5, .3, .1))
		var li := OmniLight3D.new()
		li.light_color = Color(1, .8, .3)
		li.light_energy = 1.4
		li.omni_range = 5.0
		li.position = Vector3(0, 1.3, -.6)
		b.add_child(li)
		var pr := CPUParticles3D.new()
		pr.amount = 12
		pr.lifetime = 2.5
		pr.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		pr.emission_sphere_radius = 0.7
		pr.direction = Vector3.UP
		pr.spread = 30.0
		pr.gravity = Vector3(0, 0.15, 0)
		pr.initial_velocity_min = 0.05
		pr.initial_velocity_max = 0.2
		pr.position = Vector3(0, 1.2, -.3)
		var bm := BoxMesh.new()
		bm.size = Vector3.ONE * 0.06
		pr.mesh = bm
		pr.material_override = mat(w, Color(1, .85, .3), 3.0, 0.0)
		b.add_child(pr)
	elif variant == "goat":
		if not _sculpt(head, w, "head_goat", Vector3(0, .2, 0), 1.4):
			part(head, w, "sph", Vector3(0, .2, 0), Vector3(.3, .34, .34), fur)
			part(head, w, "box", Vector3(0, .1, -.27), Vector3(.15, .15, .32), fur)
			part(head, w, "box", Vector3(0, .12, -.44), Vector3(.11, .09, .05), DARK)
			part(head, w, "box", Vector3(0, .03, -.3), Vector3(.1, .03, .25), fur.darkened(.25))
			for s in [-1.0, 1.0]:
				part(head, w, "sph", Vector3(s * .11, .25, -.14), Vector3(.09, .07, .05), Color(1, .75, .15), 2.0)
				part(head, w, "box", Vector3(s * .11, .25, -.175), Vector3(.085, .018, .01), DARK)
				part(head, w, "box", Vector3(s * .11, .31, -.15), Vector3(.12, .02, .03), fur.darkened(.4), 0.0, Vector3(0, 0, s * -18))
				part(head, w, "box", Vector3(s * .25, .27, 0), Vector3(.24, .035, .1), fur, 0.0, Vector3(0, s * -10, s * 20))
				part(head, w, "cone", Vector3(s * .11, .47, .05), Vector3(.09, .34, .09), Color(.85, .82, .7), 0.0, Vector3(-30, 0, s * -15))
				part(head, w, "cone", Vector3(s * .17, .68, .2), Vector3(.07, .26, .07), Color(.8, .77, .65), 0.0, Vector3(-65, 0, s * -30))
			part(head, w, "cone", Vector3(0, -.05, -.3), Vector3(.06, .26, .06), fur.darkened(.2), 0.0, Vector3(180, 0, 0))
		part(head, w, "sph", Vector3(0, .22, .1), Vector3(.46, .5, .44), robe.darkened(.15))
		# cuenco luminoso
		part(b, w, "cyl", Vector3(0, .98, -.5), Vector3(.32, .07, .32), Color(.45, .28, .12))
		part(b, w, "cyl", Vector3(0, 1.02, -.5), Vector3(.26, .02, .26), Color(.9, 1.0, .4), 2.0)
	else:
		if not _sculpt(head, w, "head_wolf", Vector3(0, .2, 0), 1.2):
			var fd := fur.darkened(.45)
			part(head, w, "sph", Vector3(0, .2, 0), Vector3(.3, .3, .36), fur, 0.0, Vector3.ZERO, 0.65)
			part(head, w, "box", Vector3(0, .1, -.3), Vector3(.13, .13, .34), fur, 0.0, Vector3(-4, 0, 0), 0.65)
			part(head, w, "box", Vector3(0, .09, -.5), Vector3(.09, .09, .1), fur.darkened(.2))
			part(head, w, "sph", Vector3(0, .12, -.56), Vector3(.07, .06, .06), DARK)
			part(head, w, "box", Vector3(0, .02, -.3), Vector3(.1, .04, .3), fd)
			for t in 4:
				part(head, w, "cone", Vector3(((t % 2) - .5) * .09, .045, -.36 - (t / 2) * .1), Vector3(.015, .05, .015), Color(.92, .92, .85), 0.0, Vector3(180, 0, 0))
			for s in [-1.0, 1.0]:
				part(head, w, "box", Vector3(s * .1, .26, -.2), Vector3(.1, .035, .04), Color(.85, .95, 1.0), 3.2, Vector3(0, 0, s * -20))
				part(head, w, "box", Vector3(s * .1, .3, -.19), Vector3(.12, .02, .03), fd, 0.0, Vector3(0, 0, s * -20))
				part(head, w, "cone", Vector3(s * .12, .58, .02), Vector3(.13, .44, .05), fd, 0.0, Vector3(0, 0, s * -12), 0.6)
				part(head, w, "cone", Vector3(s * .12, .56, -.01), Vector3(.08, .34, .03), fur.lightened(.2), 0.0, Vector3(0, 0, s * -12))
				part(head, w, "cone", Vector3(s * .17, .12, -.12), Vector3(.07, .2, .05), fur, 0.0, Vector3(0, 0, s * -135), 0.65)
				part(head, w, "cone", Vector3(s * .12, .24, .12), Vector3(.06, .18, .05), fur, 0.0, Vector3(20, 0, s * -80), 0.65)
			part(head, w, "sph", Vector3(0, .0, .02), Vector3(.5, .22, .46), fd, 0.0, Vector3.ZERO, 0.7)
		part(head, w, "sph", Vector3(0, .26, .16), Vector3(.5, .46, .36), robe.darkened(.2))
		part(b, w, "cone", Vector3(0, 1.22, -.3), Vector3(.12, .32, .06), fur, 0.0, Vector3(180, 0, 0), 0.65)
		rig["arm_base"] = 0.5
	rig["eye"] = 1.75
	rig["h"] = 2.0



# ------------------------------------------------------- nuevos monstruos
## Esqueleto: huesos amarillentos, costillar, espada oxidada, harapos en la cadera y ojos verdosos apagados.
static func _skeleton(b: Node3D, w, rig: Dictionary) -> void:
	var bone := Color(.72, .68, .56)
	var bd := bone.darkened(.3)
	for s in [-1.0, 1.0]:
		var nm := "legL" if s < 0.0 else "legR"
		var leg := pivot(b, nm, Vector3(s * .11, .85, 0))
		part(leg, w, "cyl", Vector3(0, -.2, 0), Vector3(.07, .42, .07), bone, 0.0, Vector3.ZERO, 0.0)
		part(leg, w, "sph", Vector3(0, -.42, 0), Vector3(.1, .1, .1), bd, 0.0, Vector3.ZERO, 0.0)
		part(leg, w, "cyl", Vector3(0, -.62, 0), Vector3(.06, .38, .06), bone, 0.0, Vector3.ZERO, 0.0)
		part(leg, w, "box", Vector3(0, -.82, -.06), Vector3(.1, .05, .22), bd, 0.0, Vector3.ZERO, 0.0)
		rig[nm] = leg
	part(b, w, "box", Vector3(0, .88, 0), Vector3(.34, .12, .2), bd, 0.0, Vector3.ZERO, 0.0)         # pelvis
	part(b, w, "cyl", Vector3(0, 1.15, .02), Vector3(.06, .55, .06), bone, 0.0, Vector3.ZERO, 0.0)   # columna
	for i in 4:
		var y := 1.28 + i * .1
		var wd := .42 - i * .05
		part(b, w, "box", Vector3(0, y, -.07), Vector3(wd, .04, .14), bone, 0.0, Vector3.ZERO, 0.0)  # costilla
	part(b, w, "box", Vector3(0, .86, -.02), Vector3(.5, .3, .26), Color(.16, .13, .1), 0.0, Vector3.ZERO, 0.8)   # harapos
	for s in [-1.0, 1.0]:
		var nm2 := "armL" if s < 0.0 else "armR"
		var arm := pivot(b, nm2, Vector3(s * .26, 1.5, 0))
		part(arm, w, "cyl", Vector3(0, -.18, 0), Vector3(.06, .38, .06), bone, 0.0, Vector3.ZERO, 0.0)
		part(arm, w, "cyl", Vector3(0, -.5, 0), Vector3(.05, .3, .05), bone, 0.0, Vector3.ZERO, 0.0)
		part(arm, w, "sph", Vector3(0, -.68, 0), Vector3(.09, .09, .09), bd, 0.0, Vector3.ZERO, 0.0)
		rig[nm2] = arm
	var aR: Node3D = rig["armR"]
	part(aR, w, "box", Vector3(0, -.8, -.34), Vector3(.05, .03, .8), Color(.38, .3, .24), 0.0, Vector3.ZERO, 0.0)   # espada oxidada
	part(aR, w, "box", Vector3(0, -.8, -.0), Vector3(.2, .03, .04), Color(.25, .2, .15), 0.0, Vector3.ZERO, 0.0)
	var head := pivot(b, "head", Vector3(0, 1.62, 0))
	rig["head"] = head
	part(head, w, "sph", Vector3(0, .12, 0), Vector3(.26, .3, .28), bone, 0.0, Vector3.ZERO, 0.0)      # cráneo
	part(head, w, "box", Vector3(0, -.02, -.08), Vector3(.17, .09, .14), bone.darkened(.1), 0.0, Vector3.ZERO, 0.0)   # mandíbula
	for s in [-1.0, 1.0]:
		part(head, w, "sph", Vector3(s * .06, .14, -.12), Vector3(.075, .085, .05), DARK, 0.0, Vector3.ZERO, 0.0)
		part(head, w, "sph", Vector3(s * .06, .14, -.15), Vector3(.03, .03, .02), Color(.55, .95, .7), 2.6)
	part(head, w, "box", Vector3(0, .07, -.14), Vector3(.03, .05, .02), DARK, 0.0, Vector3.ZERO, 0.0)   # nariz
	rig["eye"] = 1.75
	rig["h"] = 1.9
	rig["r"] = .3


## Espectro: capa larga hecha jirones que flota, capucha vacía con dos ojos fríos y manos huesudas de garras.
static func _wraith(b: Node3D, w, rig: Dictionary) -> void:
	var cl := Color(.08, .1, .12)
	for s in [-1.0, 1.0]:                       # sin piernas: pivotes vacíos para que la animación no falle
		var nm := "legL" if s < 0.0 else "legR"
		rig[nm] = pivot(b, nm, Vector3(s * .1, .8, 0))
	part(b, w, "frust", Vector3(0, .85, 0), Vector3(.95, 1.7, .8), cl, 0.0, Vector3.ZERO, 0.8)
	for i in 7:                                 # jirones al final de la capa
		var a := i / 7.0 * TAU
		part(b, w, "cone", Vector3(sin(a) * .36, .12, cos(a) * .3), Vector3(.12, .5 + randf() * .25, .05), cl.darkened(.2), 0.0, Vector3(180, rad_to_deg(a), 0), 0.8)
	part(b, w, "sph", Vector3(0, 1.4, 0), Vector3(.6, .4, .46), cl.lightened(.04), 0.0, Vector3.ZERO, 0.8)   # hombros
	for s in [-1.0, 1.0]:
		var nm2 := "armL" if s < 0.0 else "armR"
		var arm := pivot(b, nm2, Vector3(s * .3, 1.42, 0))
		part(arm, w, "cyl", Vector3(0, -.3, 0), Vector3(.1, .62, .1), cl.lightened(.03), 0.0, Vector3.ZERO, 0.8)
		part(arm, w, "sph", Vector3(0, -.64, 0), Vector3(.1, .1, .1), Color(.5, .52, .5), 0.0, Vector3.ZERO, 0.0)
		for t in 3:
			part(arm, w, "cone", Vector3((t - 1) * .035, -.74, -.02), Vector3(.025, .16, .025), Color(.55, .56, .52), 0.0, Vector3(180, 0, (t - 1) * 15.0), 0.0)
		rig[nm2] = arm
	var head := pivot(b, "head", Vector3(0, 1.55, 0))
	rig["head"] = head
	part(head, w, "sph", Vector3(0, .12, .04), Vector3(.42, .5, .44), cl, 0.0, Vector3.ZERO, 0.8)
	part(head, w, "cone", Vector3(0, .42, .14), Vector3(.24, .34, .24), cl, 0.0, Vector3(-28, 0, 0), 0.8)   # punta de capucha
	part(head, w, "sph", Vector3(0, .1, -.1), Vector3(.28, .34, .2), Color(.01, .01, .02), 0.0, Vector3.ZERO, 0.0)
	for s in [-1.0, 1.0]:
		part(head, w, "sph", Vector3(s * .07, .14, -.2), Vector3(.07, .045, .03), Color(.5, .95, .85), 3.4)
	rig["arm_base"] = 0.45
	rig["eye"] = 1.75
	rig["h"] = 2.0


## Necrófago: encorvado, piel grisácea, brazos larguísimos con garras, cabeza adelantada y dientes amarillos.
static func _ghoul(b: Node3D, w, rig: Dictionary) -> void:
	var sk := Color(.5, .54, .46)
	var sd := sk.darkened(.3)
	for s in [-1.0, 1.0]:
		var nm := "legL" if s < 0.0 else "legR"
		var leg := pivot(b, nm, Vector3(s * .14, .8, 0))
		part(leg, w, "cyl", Vector3(0, -.36, 0), Vector3(.17, .72, .17), Color(.22, .19, .15), 0.0, Vector3.ZERO, 0.8)
		part(leg, w, "box", Vector3(0, -.75, -.07), Vector3(.2, .1, .3), sd)
		rig[nm] = leg
	part(b, w, "box", Vector3(0, .85, -.02), Vector3(.45, .22, .3), Color(.2, .17, .13), 0.0, Vector3.ZERO, 0.8)
	var torso := pivot(b, "torso", Vector3(0, .95, 0))
	torso.rotation_degrees = Vector3(-28, 0, 0)      # encorvado hacia delante
	part(torso, w, "box", Vector3(0, .32, 0), Vector3(.5, .64, .3), sk, 0.0, Vector3.ZERO, 0.6)
	part(torso, w, "box", Vector3(0, .32, .17), Vector3(.1, .6, .06), sd)                       # espina marcada
	for i in 3:
		part(torso, w, "box", Vector3(0, .18 + i * .12, -.15), Vector3(.4, .03, .04), sd)       # costillas
	for s in [-1.0, 1.0]:
		var nm2 := "armL" if s < 0.0 else "armR"
		var arm := pivot(b, nm2, Vector3(s * .36, 1.32, -.28))
		part(arm, w, "cyl", Vector3(0, -.3, 0), Vector3(.12, .6, .12), sk, 0.0, Vector3.ZERO, 0.6)
		part(arm, w, "cyl", Vector3(0, -.75, -.02), Vector3(.1, .45, .1), sk, 0.0, Vector3.ZERO, 0.6)
		part(arm, w, "sph", Vector3(0, -1.0, -.03), Vector3(.14, .14, .14), sd)
		for t in 3:
			part(arm, w, "cone", Vector3((t - 1) * .045, -1.13, -.03), Vector3(.03, .18, .03), Color(.75, .72, .6), 0.0, Vector3(180, 0, 0))
		rig[nm2] = arm
	var head := pivot(b, "head", Vector3(0, 1.38, -.42))
	rig["head"] = head
	part(head, w, "sph", Vector3(0, .1, 0), Vector3(.32, .3, .34), sk, 0.0, Vector3.ZERO, 0.6)
	part(head, w, "box", Vector3(0, -.02, -.1), Vector3(.22, .1, .16), sd)
	part(head, w, "box", Vector3(0, -.03, -.19), Vector3(.2, .03, .03), Color(.12, .03, .03))
	for t in 4:
		part(head, w, "cone", Vector3((t - 1.5) * .045, -.05, -.2), Vector3(.02, .06, .02), Color(.8, .75, .5), 0.0, Vector3(180, 0, 0))
	for s in [-1.0, 1.0]:
		part(head, w, "sph", Vector3(s * .08, .15, -.12), Vector3(.06, .05, .03), Color(1, .85, .2), 2.2)
		part(head, w, "cone", Vector3(s * .17, .1, .0), Vector3(.07, .16, .04), sk, 0.0, Vector3(0, 0, s * -80))
	rig["eye"] = 1.5
	rig["h"] = 1.6
	rig["r"] = .38


# --------------------------------------------------- nuevo miembro del culto
## Médico de la peste: túnica negra, sombrero ancho, máscara de pico con lentes ámbar y bastón con farol.
static func _plague(b: Node3D, w, rig: Dictionary) -> void:
	var rb := Color(.07, .06, .07)
	for s in [-1.0, 1.0]:
		var nm := "legL" if s < 0.0 else "legR"
		var leg := pivot(b, nm, Vector3(s * .12, .8, 0))
		part(leg, w, "cyl", Vector3(0, -.35, 0), Vector3(.17, .7, .17), rb)
		part(leg, w, "box", Vector3(0, -.76, -.05), Vector3(.2, .12, .32), DARK)
		rig[nm] = leg
	part(b, w, "frust", Vector3(0, .95, 0), Vector3(.8, 1.35, .6), rb, 0.0, Vector3.ZERO, 0.8)
	part(b, w, "cyl", Vector3(0, 1.0, 0), Vector3(.62, .06, .5), Color(.3, .22, .15))        # cinturón
	part(b, w, "sph", Vector3(0, 1.48, 0), Vector3(.62, .3, .42), rb.lightened(.03), 0.0, Vector3.ZERO, 0.8)   # capa de hombros
	for s in [-1.0, 1.0]:
		var nm2 := "armL" if s < 0.0 else "armR"
		var arm := pivot(b, nm2, Vector3(s * .33, 1.45, 0))
		part(arm, w, "cyl", Vector3(0, -.28, 0), Vector3(.13, .58, .13), rb, 0.0, Vector3.ZERO, 0.8)
		part(arm, w, "sph", Vector3(0, -.6, 0), Vector3(.11, .11, .11), Color(.25, .2, .16))   # guante de cuero
		rig[nm2] = arm
	var aR: Node3D = rig["armR"]
	part(aR, w, "cyl", Vector3(0, -.6, -.1), Vector3(.035, 1.5, .035), Color(.3, .22, .14), 0.0, Vector3(-8, 0, 0), 0.0)   # bastón
	part(aR, w, "sph", Vector3(0, -1.22, -.2), Vector3(.14, .17, .14), Color(1, .6, .2), 2.2)                           # farol
	var li := OmniLight3D.new()
	li.light_color = Color(1, .6, .22)
	li.light_energy = 0.9
	li.omni_range = 5.0
	li.position = Vector3(0, -1.22, -.2)
	aR.add_child(li)
	var head := pivot(b, "head", Vector3(0, 1.58, 0))
	rig["head"] = head
	part(head, w, "sph", Vector3(0, .1, 0), Vector3(.3, .32, .32), Color(.14, .12, .11), 0.0, Vector3.ZERO, 0.8)           # capucha
	part(head, w, "cone", Vector3(0, .1, -.3), Vector3(.12, .42, .12), Color(.55, .5, .4), 0.0, Vector3(-90, 0, 0), 0.0)   # pico
	for s in [-1.0, 1.0]:
		part(head, w, "sph", Vector3(s * .08, .16, -.14), Vector3(.085, .085, .05), Color(1, .65, .15), 2.4)           # lentes
		part(head, w, "cyl", Vector3(s * .08, .16, -.13), Vector3(.1, .02, .1), Color(.15, .12, .1), 0.0, Vector3(90, 0, 0))
	part(head, w, "cyl", Vector3(0, .27, 0), Vector3(.64, .035, .64), rb, 0.0, Vector3.ZERO, 0.8)                          # ala del sombrero
	part(head, w, "cyl", Vector3(0, .38, 0), Vector3(.3, .2, .3), rb, 0.0, Vector3.ZERO, 0.8)
	rig["eye"] = 1.75
	rig["h"] = 1.95


# ----------------------------------------------------------------- monstruos
## Monstruo verde: ogro grande o goblin pequeño, con colmillos, orejas, musgo y garras.
static func _ogre(b: Node3D, w, rig: Dictionary, small: bool) -> void:
	var g := Color(.3, .37, .18).lightened(randf() * .08)
	if small:
		g = Color(.36, .43, .2).lightened(randf() * .08)
	var gd := g.darkened(.3)
	var gl := g.lightened(.15)
	var eyec := Color(1, .8, .1) if small else Color(.2, .95, .8)
	part(b, w, "box", Vector3(0, .72, 0), Vector3(.62, .34, .46), Color(.3, .2, .12))
	part(b, w, "sph", Vector3(0, 1.12, -.02), Vector3(.96, .9, .78), g, 0.0, Vector3.ZERO, 0.6)
	part(b, w, "sph", Vector3(0, 1.52, 0), Vector3(.9, .62, .7), gl, 0.0, Vector3.ZERO, 0.6)
	for s in [-1.0, 1.0]:
		var nm := "legL" if s < 0.0 else "legR"
		var leg := pivot(b, nm, Vector3(s * .24, .8, 0))
		part(leg, w, "cyl", Vector3(0, -.32, 0), Vector3(.32, .62, .32), gd, 0.0, Vector3.ZERO, 0.6)
		part(leg, w, "box", Vector3(0, -.66, -.07), Vector3(.36, .14, .46), gd)
		for t in 3:
			part(leg, w, "cone", Vector3((t - 1) * .11, -.66, -.3), Vector3(.06, .1, .06), Color(.85, .8, .6), 0.0, Vector3(-90, 0, 0))
		rig[nm] = leg
		var nm2 := "armL" if s < 0.0 else "armR"
		var arm := pivot(b, nm2, Vector3(s * .62, 1.68, 0))
		part(arm, w, "cyl", Vector3(0, -.3, 0), Vector3(.28, .6, .28), g, 0.0, Vector3.ZERO, 0.6)
		part(arm, w, "cyl", Vector3(0, -.75, -.03), Vector3(.26, .5, .26), g, 0.0, Vector3.ZERO, 0.6)
		part(arm, w, "sph", Vector3(0, -1.05, -.05), Vector3(.3, .27, .3), gl)
		for t in 3:
			part(arm, w, "cone", Vector3((t - 1) * .08, -1.2, -.08), Vector3(.05, .1, .05), Color(.85, .8, .6), 0.0, Vector3(180, 0, 0))
		rig[nm2] = arm
		part(b, w, "sph", Vector3(s * .5, 1.78, .05), Vector3(.3, .18, .3), Color(.2, .6, .15), 0.0, Vector3.ZERO, 0.8)
	var head := pivot(b, "head", Vector3(0, 1.9, -.16))
	rig["head"] = head
	if small:
		head.scale = Vector3.ONE * 1.3
	if not _sculpt(head, w, "head_ogre", Vector3(0, .2, 0), 1.1):
		part(head, w, "sph", Vector3(0, .2, 0), Vector3(.48, .44, .48), g, 0.0, Vector3.ZERO, 0.6)
		part(head, w, "box", Vector3(0, .31, -.2), Vector3(.46, .09, .14), gd, 0.0, Vector3(8, 0, 0))
		part(head, w, "sph", Vector3(0, .13, -.24), Vector3(.14, .13, .13), gl)
		part(head, w, "box", Vector3(0, .03, -.2), Vector3(.27, .045, .05), Color(.12, .03, .03))
		part(head, w, "sph", Vector3(0, .36, .02), Vector3(.3, .16, .3), Color(.2, .6, .15), 0.0, Vector3.ZERO, 0.8)
		for s in [-1.0, 1.0]:
			part(head, w, "sph", Vector3(s * .1, .25, -.19), Vector3(.08, .06, .05), eyec, 2.5)
			part(head, w, "sph", Vector3(s * .1, .25, -.22), Vector3(.03, .03, .02), DARK)
			part(head, w, "cone", Vector3(s * .1, .06, -.22), Vector3(.05, .16, .05), Color(.9, .85, .7), 0.0, Vector3(-10, 0, 0))
			part(head, w, "cone", Vector3(s * .28, .25, 0), Vector3(.14, .38 if small else .3, .07), g, 0.0, Vector3(0, 0, s * -75))
	if small:
		rig["k"] = 0.55
		rig["eye"] = 2.3
	else:
		rig["k"] = 1.5
		rig["eye"] = 2.3
	rig["r"] = 0.6
	rig["h"] = 2.4


# ------------------------------------------------------------------ modelos de Blender (.glb)
## Carga assets/models/<name>.glb (malla con color por vértice, esqueleto y animaciones idle/walk/attack),
## le pone el material PS1 (patrón 7 = color de vértice) y rellena el "rig" para que Mob lo anime con su AnimationPlayer.
## "scl" es la escala (los modelos miden ~2.6-2.8 m y los mobs ~2 m). Devuelve false si el archivo no existe.
static func _glb(b: Node3D, w, rig: Dictionary, name: String, scl: float, eye := 2.2, rad := 0.55, hgt := 2.6) -> bool:
	var path := "res://assets/models/%s.glb" % name
	if not ResourceLoader.exists(path):
		return false
	var ps := load(path) as PackedScene
	if ps == null:
		return false
	var key := "glb_mat"
	var m: ShaderMaterial
	if _mats.has(key):
		m = _mats[key]
	else:
		m = ShaderMaterial.new()
		m.shader = w.shader
		m.set_shader_parameter("pattern", 7)
		m.set_shader_parameter("tint", Color(2.7, 2.7, 2.7))   # los colores vienen en lineal y oscuros: se aclaran
		m.set_shader_parameter("snap", 120.0)
		_mats[key] = m
	var inst := ps.instantiate() as Node3D
	b.add_child(inst)
	_apply_mat(inst, m)
	# Altura real del modelo (para colisión y etiqueta) y animaciones en bucle
	var ap := _find_anim(inst)
	if ap:
		for an in ap.get_animation_list():
			if an in ["idle", "walk"]:      # attack / hit / death se reproducen una sola vez
				ap.get_animation(an).loop_mode = Animation.LOOP_LINEAR
		if ap.has_animation("idle"):
			ap.play("idle")
	if name == "mob_plague":   # luz cálida del farol (Blender +Y -> Godot -Z)
		var li := OmniLight3D.new()
		li.light_color = Color(1, .6, .22)
		li.light_energy = 0.9
		li.omni_range = 5.0
		li.position = Vector3(0.35, 1.5, -0.22)
		b.add_child(li)
	rig["k"] = scl
	rig["eye"] = eye
	rig["r"] = rad
	rig["h"] = hgt
	rig["arm_base"] = 0.0
	# Nodos ficticios para que Mob.gd (que espera brazos/cabeza) no falle; la animación real la lleva "anim".
	for n in ["armL", "armR", "head"]:
		var d := Node3D.new()
		d.name = n
		b.add_child(d)
		rig[n] = d
	rig["anim"] = ap
	return true


## Aplica el material a todas las mallas del modelo importado (recursivo).
static func _apply_mat(n: Node, m: Material) -> void:
	if n is MeshInstance3D:
		(n as MeshInstance3D).material_override = m
	for c in n.get_children():
		_apply_mat(c, m)


## Busca el AnimationPlayer dentro del modelo importado.
static func _find_anim(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := _find_anim(c)
		if r:
			return r
	return null
