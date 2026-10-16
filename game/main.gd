extends Node3D
## Nocturnia: mundo dark fantasy PS1. Todo se genera por código.
## Cámaras: C = primera / tercera / libre · N = siguiente ser · F = volver a la mosca · V = velocidad

# =====================================================================
# AJUSTES DEL MUNDO
# =====================================================================
const HALF := 128.0
# Celdas por lado de la malla del terreno (más = más detalle pero más lento de generar).
const CELLS := 192
# Altura (Y) del nivel del agua. Por debajo de esto el terreno es lecho de lago/río.
const WATER := -1.0
# Centros (x, z) de las cuatro aldeas, una en cada esquina del mapa.
const VILLAGES := [Vector2(-90, -80), Vector2(90, -70), Vector2(-80, 90), Vector2(85, 85)]
# Nombres de los modos de cámara (para el HUD) y de los biomas (los usa biome_name()).
const MODES := ["Primera persona", "Tercera persona", "Cámara libre"]
const BIOMES := ["Lecho", "Nieve", "Pantano", "Bosque", "Páramo", "Llanura"]

# ---------------- Generadores de ruido del terreno ----------------
# elev  = altura base          moist  = humedad (decide pantano/bosque/páramo)
# ridge = crestas de montaña   warp   = deforma las coordenadas (acantilados irregulares)
# detail = rugosidad fina del suelo
var elev := FastNoiseLite.new()
var moist := FastNoiseLite.new()
var ridge := FastNoiseLite.new()
var warp := FastNoiseLite.new()
var detail := FastNoiseLite.new()
# (sin uso: el cielo ahora es un shader de tipo "sky", ver _env y sky.gdshader)
var sky_dome: MeshInstance3D
# Shader PS1 compartido por todos los materiales (ps1.gdshader).
var shader: Shader
# La mosca, la cámara y las partículas de lluvia.
var fly: Fly
var cam: Camera3D
var rain: GPUParticles3D
# Modo de cámara: 0 = primera persona, 1 = tercera persona, 2 = libre.
var mode := 1
# foc = ser al que sigue la cámara (la mosca o cualquier mob).  prev_body = cuerpo que se
# ocultó en primera persona (para volver a mostrarlo al cambiar de cámara).
var foc: Node3D
var prev_body: Node3D
# Giro extra de la cámara con el ratón (alrededor del personaje seguido).
var off_yaw := 0.0
var off_pitch := 0.0
# Orientación de la cámara libre.
var free_yaw := 0.0
var free_pitch := -0.3
# Registro de eventos (los últimos 6) que se muestra abajo a la izquierda; hud = texto superior.
var logs: Array[String] = []
var hud: Label
var nv: NeuroView   # panel de actividad neuronal (se reasigna al cambiar de cerebro)
var logl: Label
# speed_i = índice de velocidad del juego (x1, x3, x8);  fire_lights = luces de fuego que parpadean.
var speed_i := 0
var fire_lights: Array[OmniLight3D] = []
# Ciclo de día/noche (daynight.gd) y objetos que controla.
var lighthouse_pos := Vector2.ZERO
var drowned := 0              # mobs ahogados (estadística)
var show_fps := true
var cam_yaw := 0.0              # giro suavizado de la cámara (evita tirones al chocar o girar de golpe)
var cam_foc: Node3D
var minimap: MapView
var bigmap: MapView
var map_layer: CanvasLayer
var free_speed := 30.0
var dn: DayNight
var env: Environment
var sky_mat: ShaderMaterial
var sun_light: DirectionalLight3D


## Arranque. Configura los ruidos y construye el mundo EN ESTE ORDEN:
## entorno -> terreno -> árboles -> rocas -> hierba -> castillo -> aldeas -> faro -> ruinas -> cielo -> lluvia,
## y por último la cámara, los habitantes (mobs + mosca) y la interfaz.
func _ready() -> void:
	randomize()
	Engine.max_physics_steps_per_frame = 5   # si un frame tarda, el juego se ralentiza en vez de acumular ticks y desplomar los FPS
	# Cargamos el shader PS1 y configuramos los 5 generadores de ruido (semillas fijas: el mapa es siempre el mismo).
	shader = load("res://ps1.gdshader")
	elev.noise_type = FastNoiseLite.TYPE_SIMPLEX
	elev.frequency = 0.011
	elev.fractal_octaves = 4
	elev.seed = 7
	moist.noise_type = FastNoiseLite.TYPE_SIMPLEX
	moist.frequency = 0.02
	moist.seed = 99
	ridge.noise_type = FastNoiseLite.TYPE_SIMPLEX
	ridge.frequency = 0.009
	ridge.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	ridge.fractal_octaves = 4
	ridge.seed = 21
	warp.noise_type = FastNoiseLite.TYPE_SIMPLEX
	warp.frequency = 0.02
	warp.seed = 5
	detail.noise_type = FastNoiseLite.TYPE_SIMPLEX
	detail.frequency = 0.15
	detail.seed = 77
	# Construcción del mundo, de lo grande a lo pequeño.
	_env()
	_terrain()
	_trees()
	_rocks()
	_grass()
	_castle()
	for v in VILLAGES:
		_village(v)
	_lighthouse()
	_ruins()
	_sky()
	_rain()
	dn = DayNight.new()
	add_child(dn)
	dn.setup(env, sky_mat, sun_light, rain)
	# Cámara única: main.gd la mueve cada frame según el modo (ver _process).
	cam = Camera3D.new()
	cam.far = 900.0
	add_child(cam)
	cam.make_current()
	# Aparecen mobs, frutas y la mosca; luego se crea la interfaz.
	_population()
	_ui()
	log_msg("La lluvia cae sobre Nocturnia...")


# ---------- utilidades ----------
## Material con una textura PNG (assets/textures). Si la textura no existe, cae al ruido procedural.
## sc = escala de repetición, gain = brillo de la textura, obj = proyectar en espacio del objeto en vez del mundo.
func mat_tex(tname: String, tint: Color, e := 0.0, sc := 0.25, gain := 1.0, obj := false) -> ShaderMaterial:
	var t: Texture2D = Assets.tex(tname)
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter("emit", e)
	if t == null:
		m.set_shader_parameter("tint", tint)   # sin textura: cae al ruido procedural
		return m
	m.set_shader_parameter("pattern", 5)
	m.set_shader_parameter("tex", t)
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("tex_scale", sc)
	m.set_shader_parameter("tex_gain", gain)
	m.set_shader_parameter("object_space", obj)
	return m


## Material del terreno: color por vértice (bioma/pendiente) + detalle de pasto y roca (mezcla según la pendiente).
func mat_terrain() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	if Assets.tex("grass") == null:
		m.set_shader_parameter("pattern", 3)
		return m
	m.set_shader_parameter("pattern", 6)
	m.set_shader_parameter("tex", Assets.tex("grass"))
	m.set_shader_parameter("tex2", Assets.tex("rock"))
	m.set_shader_parameter("tex_scale", 0.2)
	return m


## Material genérico. pat: 0 ruido, 1 ladrillo de piedra, 2 cascada, 3 relieve, 4 agua,
## 7 pizarra (tejados), 8 tablones. Con textura disponible usa la PNG; si no, el patrón procedural del shader.
func mat(c: Color, e := 0.0, pat := 0) -> ShaderMaterial:
	var avg := (c.r + c.g + c.b) / 3.0
	if pat == 1 and Assets.tex("stone_brick"):
		var k := (c.r + c.g + c.b) / (STONE.r + STONE.g + STONE.b)
		return mat_tex("stone_brick", Color(k, k, k) * 1.15, e, 0.25, 1.0)
	if pat == 7 and Assets.tex("slate"):
		var k7 := clampf(avg / 0.18, 0.5, 1.3)
		return mat_tex("slate", Color(1.1, 1.1, 1.3) * k7, e, 0.25, 1.0)
	if pat == 8 and Assets.tex("plank"):
		var k8 := clampf(avg / 0.25, 0.6, 1.4)
		return mat_tex("plank", Color(1.1, 1.0, 0.95) * k8, e, 0.3, 1.0)
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter("tint", c)
	m.set_shader_parameter("emit", e)
	m.set_shader_parameter("pattern", pat if pat < 7 else 0)
	return m



## ALTURA DEL TERRENO en (x, z). Es la función central del relieve y la usan todos:
## terreno, árboles, mobs, mosca. Combina ruido base + crestas de montaña + terrazas (acantilados),
## baja los bordes para formar el mar y aplana el castillo, las aldeas y las cascadas.
func height_at(x: float, z: float) -> float:
	var wx := x + warp.get_noise_2d(x, z) * 16.0
	var wz := z + warp.get_noise_2d(x + 137.0, z - 71.0) * 16.0
	var e := elev.get_noise_2d(wx, wz)
	var r := clampf(ridge.get_noise_2d(wx, wz) * 0.5 + 0.5, 0.0, 1.0)
	var mt := smoothstep(0.05, 0.55, e)
	# Relieve suave: colinas bajas y alguna loma; sin terrazas ni acantilados (la mosca vuela libre y casi no choca)
	var h := e * 9.0 + 1.0 + mt * r * 6.0
	h += detail.get_noise_2d(x, z) * (0.5 + 0.5 * mt)
	var d := maxf(absf(x), absf(z)) / HALF
	if d > 0.8:
		h -= (d - 0.8) * 90.0
	var c := Vector2(x, z)
	h = lerpf(h, 1.5, smoothstep(34.0, 22.0, c.length()))
	for v in VILLAGES:
		h = lerpf(h, 1.5, smoothstep(24.0, 14.0, c.distance_to(v)))
	h = lerpf(h, 1.5, smoothstep(26.0, 18.0, c.distance_to(FALLS)))
	return h


## ¿Hay agua en este punto? (lo usan los mobs para no meterse al lago).
func is_water(p: Vector3) -> bool:
	return height_at(p.x, p.z) < WATER + 0.3


## Índice de bioma según altura h y humedad m: 0 lecho, 1 nieve, 2 pantano, 3 bosque, 4 páramo, 5 llanura.
func biome_idx(h: float, m: float) -> int:
	if h < WATER + 0.4: return 0
	if h > 10.5: return 1
	if h < 1.0 and m > 0.1: return 2
	if m > 0.12: return 3
	if m < -0.15: return 4
	return 5


## Nombre del bioma bajo un punto (se muestra en el HUD).
func biome_name(p: Vector3) -> String:
	return BIOMES[biome_idx(height_at(p.x, p.z), moist.get_noise_2d(p.x, p.z))]


## Busca un punto aleatorio de tierra firme que cumpla pred(x, z, h). Devuelve (x, h+1, z).
func land_spot(pred: Callable, tries := 500) -> Vector3:
	for i in tries:
		var x := randf_range(-HALF + 8, HALF - 8)
		var z := randf_range(-HALF + 8, HALF - 8)
		var h := height_at(x, z)
		if h > WATER + 0.6 and pred.call(x, z, h):
			return Vector3(x, h + 1.0, z)
	return Vector3(0, 3, 34)


## ¿Es un sitio seguro para dejar un mob? Terreno poco inclinado y sin agua a menos de 6 m (si no resbala por la ladera y se ahoga).
func is_safe_spot(x: float, z: float) -> bool:
	var h0 := height_at(x, z)
	if h0 < WATER + 1.5:
		return false
	for k in 8:
		var a := k * TAU / 8.0
		var h := height_at(x + cos(a) * 6.0, z + sin(a) * 6.0)
		if h < WATER + 0.8 or absf(h - h0) > 2.6:
			return false
	return true


## land_spot que además exige is_safe_spot.
func safe_spot(pred: Callable) -> Vector3:
	var p := land_spot(func(x, z, h): return pred.call(x, z, h) and is_safe_spot(x, z), 400)
	return p if p != Vector3(0, 3, 34) else land_spot(pred)


## Puntos ya ocupados por mobs salvajes (para repartirlos).
var spread_pts: Array[Vector2] = []

## Como land_spot, pero entre 40 candidatos válidos elige el más lejos de los puntos ya ocupados (reparto uniforme).
func spread_spot(pred: Callable) -> Vector3:
	var best := Vector3.ZERO
	var bd := -1.0
	var found := 0
	for i in 600:
		var x := randf_range(-HALF + 8, HALF - 8)
		var z := randf_range(-HALF + 8, HALF - 8)
		var h := height_at(x, z)
		if h <= WATER + 0.6 or not pred.call(x, z, h) or not is_safe_spot(x, z):
			continue
		var d := 1e9
		for p in spread_pts:
			d = minf(d, Vector2(x, z).distance_to(p))
		if d > bd:
			bd = d
			best = Vector3(x, h + 1.0, z)
		found += 1
		if found >= 40:
			break
	if bd < 0.0:
		best = land_spot(pred)       # nada seguro que cumpla: se conforma con cualquier tierra
	spread_pts.append(Vector2(best.x, best.z))
	return best


## Añade un mensaje al registro de eventos de la pantalla.
## Aviso de muerte de la mosca: pantalla en negro que se aclara y un texto central, para que el cambio de lugar no parezca un teletransporte.
var _dflash: ColorRect
var _dlabel: Label
func flash_death(why: String) -> void:
	if _dflash == null:
		var cl := CanvasLayer.new()
		cl.layer = 4
		add_child(cl)
		_dflash = ColorRect.new()
		_dflash.color = Color(0, 0, 0, 1)
		_dflash.set_anchors_preset(Control.PRESET_FULL_RECT)
		_dflash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cl.add_child(_dflash)
		_dlabel = Label.new()
		_dlabel.set_anchors_preset(Control.PRESET_FULL_RECT)
		_dlabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_dlabel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_dlabel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_dlabel.add_theme_font_size_override("font_size", 22)
		_dlabel.add_theme_color_override("font_color", Color(0.85, 0.35, 0.3))
		cl.add_child(_dlabel)
	_dlabel.text = "La mosca murió por %s\nrenace en otro lugar" % why
	_dflash.color.a = 1.0
	_dlabel.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.1)
	tw.set_parallel(true)
	tw.tween_property(_dflash, "color:a", 0.0, 0.9)
	tw.tween_property(_dlabel, "modulate:a", 0.0, 0.9)


func log_msg(s: String) -> void:
	if not s.begins_with("Mosca"):
		return                      # el registro muestra solo lo que hace la mosca
	logs.push_front(s)
	if logs.size() > 6:
		logs.pop_back()
	if logl:
		logl.text = "\n".join(PackedStringArray(logs))


# ---------- mundo ----------
## Entorno: cielo (shader), luz ambiente azulada, niebla azul y la luz de luna.
func _env() -> void:
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var skm := ShaderMaterial.new()
	skm.shader = load("res://sky.gdshader")
	sky.sky_material = skm
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.20, 0.24, 0.26)   # gris verdoso apagado (antes azul saturado)
	e.ambient_light_energy = 1.6
	e.fog_enabled = true
	e.fog_light_color = Color(0.13, 0.15, 0.15)      # niebla sucia del color del horizonte
	e.fog_density = 0.013
	e.fog_sky_affect = 0.9
	e.adjustment_enabled = true                        # color grading: menos saturación y más contraste
	e.adjustment_saturation = 0.62
	e.adjustment_contrast = 1.12
	e.adjustment_brightness = 0.95
	env = e
	sky_mat = skm
	var we := WorldEnvironment.new()
	we.environment = e
	add_child(we)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.62, 0.72, 0.8)
	moon.light_energy = 0.8
	moon.rotation_degrees = Vector3(-40, 30, 0)
	add_child(moon)
	sun_light = moon
	_post()


## Post-proceso PS1 (paleta reducida + dithering + viñeta + grano). Capa 0: queda debajo del HUD.
func _post() -> void:
	var pl := CanvasLayer.new()
	pl.layer = 0
	pl.name = "PostPS1"
	add_child(pl)
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	sm.shader = load("res://post_ps1.gdshader")
	r.material = sm
	pl.add_child(r)


## Genera la malla del terreno (triángulos con color por vértice), su colisión sólida (trimesh)
## y el plano de agua animada.
func _terrain() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cs := HALF * 2.0 / CELLS
	var g: Array = []
	for j in CELLS + 1:
		for i in CELLS + 1:
			var x := -HALF + i * cs
			var z := -HALF + j * cs
			g.append(Vector3(x, height_at(x, z), z))
	for j in CELLS:
		for i in CELLS:
			var p00: Vector3 = g[j * (CELLS + 1) + i]
			var p10: Vector3 = g[j * (CELLS + 1) + i + 1]
			var p01: Vector3 = g[(j + 1) * (CELLS + 1) + i]
			var p11: Vector3 = g[(j + 1) * (CELLS + 1) + i + 1]
			_tri(st, p00, p10, p01)
			_tri(st, p10, p11, p01)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat_terrain()
	add_child(mi)
	mi.create_trimesh_collision()
	var pm := PlaneMesh.new()
	pm.size = Vector2(HALF * 4, HALF * 4)
	var w := MeshInstance3D.new()
	w.mesh = pm
	w.material_override = mat(Color(0.05, 0.16, 0.17), 0.6, 4)
	w.position.y = WATER
	add_child(w)


## Añade un triángulo al terreno. El color depende del bioma y de la pendiente:
## las pendientes fuertes se pintan como roca con estratos (bandas de color por altura).
func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var cen := (a + b + c) / 3.0
	var n := (b - a).cross(c - a).normalized()
	var slope := 1.0 - absf(n.y)
	var cols := [Color(0.13, 0.2, 0.22), Color(0.62, 0.68, 0.85), Color(0.14, 0.3, 0.3),
		Color(0.1, 0.3, 0.16), Color(0.42, 0.32, 0.2), Color(0.34, 0.4, 0.16)]
	var bi := biome_idx(cen.y, moist.get_noise_2d(cen.x, cen.z))
	var col: Color = cols[bi]
	var rock_t := smoothstep(0.22, 0.42, slope)
	if bi != 0 and rock_t > 0.0:
		var band := sin(cen.y * 2.3 + sin(cen.x * 0.21) * 2.0) * 0.5 + 0.5
		col = col.lerp(Color(0.3, 0.29, 0.36).lerp(Color(0.52, 0.42, 0.28), band), rock_t)
	var v := 0.8 + 0.4 * fposmod(sin(cen.x * 12.9898 + cen.z * 78.233) * 43758.5453, 1.0)
	col = Color(col.r * v, col.g * v, col.b * v)
	for p in [a, b, c]:
		st.set_color(col)
		st.add_vertex(p)


## Dibuja MUCHAS copias de una malla con un solo MultiMesh (rápido: árboles, rocas, hierba, almenas).
func _mm(mesh: Mesh, xf: Array, material: Material, off: Vector3) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, (xf[i] as Transform3D).translated_local(off))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = material
	add_child(mi)


## Árboles: pinos apilados en bosque, árboles muertos en pantano. Cada uno tiene un cilindro de colisión.
func _trees() -> void:
	var xf: Array = []
	var dead: Array = []
	for i in 2200:
		var x := randf_range(-HALF + 6, HALF - 6)
		var z := randf_range(-HALF + 6, HALF - 6)
		var h := height_at(x, z)
		var mo := moist.get_noise_2d(x, z)
		if h < 0.0 or h > 20.0 or Vector2(x, z).length() < 40.0 or Vector2(x, z).distance_to(FALLS) < 26.0:
			continue
		var near := false
		for v in VILLAGES:
			if Vector2(x, z).distance_to(v) < 20.0:
				near = true
		if near:
			continue
		var sl := absf(height_at(x + 1.5, z) - h) + absf(height_at(x, z + 1.5) - h)
		if sl > 2.2:
			continue
		var t := Transform3D(Basis(Vector3.UP, randf() * TAU).scaled(Vector3.ONE * randf_range(0.8, 1.6)), Vector3(x, h - 0.2, z))
		if h < 1.0 and mo > 0.1:
			dead.append(t)
		elif mo > 0.1:
			xf.append(t)
	var trunk := _cm(0.4, 3.0, 0.3, 5)
	var tm := mat_tex("bark", Color(1.0, 0.95, 0.9), 0.0, 0.4, 1.0)
	var gm := mat_tex("leaf", Color(0.85, 1.0, 0.95), 0.0, 0.35, 1.0)
	_mm(trunk, xf, tm, Vector3(0, 1.5, 0))
	_mm(_cm(2.4, 3.6, 0.0, 6), xf, gm, Vector3(0, 3.6, 0))
	_mm(_cm(1.9, 3.2, 0.0, 6), xf, gm, Vector3(0, 5.6, 0))
	_mm(_cm(1.3, 2.8, 0.0, 6), xf, gm, Vector3(0, 7.4, 0))
	var dm := mat_tex("bark", Color(0.65, 0.6, 0.62), 0.0, 0.4, 1.0)
	_mm(_cm(0.5, 6.5, 0.15, 5), dead, dm, Vector3(0, 3.2, 0))
	var br: Array = []
	for t in dead:
		br.append((t as Transform3D) * Transform3D(Basis.from_euler(Vector3(0, randf() * TAU, 0.9)), Vector3(0, 4.2, 0)))
		br.append((t as Transform3D) * Transform3D(Basis.from_euler(Vector3(0, randf() * TAU, -0.8)), Vector3(0, 5.4, 0)))
		br.append((t as Transform3D) * Transform3D(Basis.from_euler(Vector3(0, randf() * TAU, 1.1)), Vector3(0, 3.2, 0)))
	_mm(_cm(0.18, 2.4, 0.04, 4), br, dm, Vector3(0, 1.1, 0))
	# colisiones: un cilindro por árbol (todos dentro de un único StaticBody3D)
	var body := StaticBody3D.new()
	body.name = "TreeColliders"
	add_child(body)
	for t in xf + dead:
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = 0.9
		sh.height = 7.0
		cs.shape = sh
		cs.position = (t as Transform3D).origin + Vector3(0, 3.5, 0)
		body.add_child(cs)


## Rocas redondeadas, sobre todo en pendientes. Cada una tiene una esfera de colisión.
func _rocks() -> void:
	var xf: Array = []
	for i in 2500:
		var x := randf_range(-HALF + 6, HALF - 6)
		var z := randf_range(-HALF + 6, HALF - 6)
		var h := height_at(x, z)
		if h < 0.0 or Vector2(x, z).length() < 38.0 or Vector2(x, z).distance_to(FALLS) < 26.0:
			continue
		var near := false
		for v in VILLAGES:
			if Vector2(x, z).distance_to(v) < 22.0:
				near = true
		if near:
			continue
		var sl := absf(height_at(x + 1.5, z) - h) + absf(height_at(x, z + 1.5) - h)
		if sl < 1.6 and randf() > 0.03:
			continue
		var sc := Vector3(randf_range(0.8, 2.8), randf_range(0.6, 2.2), randf_range(0.8, 2.8))
		xf.append(Transform3D(Basis.from_euler(Vector3(randf() * 0.6, randf() * TAU, randf() * 0.6)).scaled(sc), Vector3(x, h - 0.2, z)))
		if xf.size() >= 500:
			break
	var sph := SphereMesh.new()
	sph.radius = 0.5
	sph.height = 1.0
	sph.radial_segments = 6
	sph.rings = 3
	_mm(sph, xf, mat_tex("rock", Color(1.0, 1.0, 1.1), 0.0, 0.2, 1.0), Vector3.ZERO)
	# colisiones: una esfera por roca, del tamaño medio de la roca
	var body := StaticBody3D.new()
	body.name = "RockColliders"
	add_child(body)
	for t in xf:
		var sc := (t as Transform3D).basis.get_scale()
		var cs := CollisionShape3D.new()
		var sh := SphereShape3D.new()
		sh.radius = 0.5 * (sc.x + sc.y + sc.z) / 3.0
		cs.shape = sh
		cs.position = (t as Transform3D).origin
		body.add_child(cs)


## Matas de hierba decorativas (sin colisión).
func _grass() -> void:
	var xf: Array = []
	for i in 9000:
		var x := randf_range(-HALF + 6, HALF - 6)
		var z := randf_range(-HALF + 6, HALF - 6)
		var h := height_at(x, z)
		if h < 0.2 or h > 16.0 or Vector2(x, z).length() < 30.0 or Vector2(x, z).distance_to(FALLS) < 24.0:
			continue
		var bi := biome_idx(h, moist.get_noise_2d(x, z))
		if bi < 3:
			continue
		var sl := absf(height_at(x + 1.5, z) - h) + absf(height_at(x, z + 1.5) - h)
		if sl > 1.2:
			continue
		xf.append(Transform3D(Basis(Vector3.UP, randf() * TAU).scaled(Vector3.ONE * randf_range(0.7, 1.5)), Vector3(x, h, z)))
		if xf.size() >= 3000:
			break
	_mm(_cm(0.2, 0.8, 0.0, 4), xf, mat_tex("grass", Color(1.1, 1.2, 0.9), 0.0, 0.3, 1.0), Vector3(0, 0.4, 0))


## Ruinas de piedra (dos pilares, un arco roto y escombros) repartidas por el mapa. Son sólidas.
func _ruins() -> void:
	for i in 12:
		var p := land_spot(func(x, z, h): return h > 1.0 and h < 20.0 and Vector2(x, z).length() > 48.0 and Vector2(x, z).distance_to(FALLS) > 30.0 and Vector2(x, z).distance_to(VILLAGES[0]) > 28.0 and Vector2(x, z).distance_to(VILLAGES[1]) > 28.0 and Vector2(x, z).distance_to(VILLAGES[2]) > 28.0 and Vector2(x, z).distance_to(VILLAGES[3]) > 28.0)
		var root := Node3D.new()
		root.position = Vector3(p.x, p.y - 1.0, p.z)
		root.rotation.y = randf() * TAU
		add_child(root)
		for s in [-3.0, 3.0]:
			var ph := randf_range(4.0, 7.5)
			_solid_box(_mi(root, _cm(0.9, ph, 0.8, 8), Vector3(s, ph / 2.0 - 0.5, 0), STONE.darkened(0.1), 0.0, 1), Vector3(1.6, ph, 1.6))
			_solid_box(_mi(root, _bm(Vector3(2.0, 0.6, 2.0)), Vector3(s, ph - 0.3, 0), STONE.lightened(0.1), 0.0, 1), Vector3(2.0, 0.6, 2.0))
		_arch(Vector3(0, 5.0, 0), 3.0, 1.8, 9, STONE, root, 0.35)
		for k in 5:
			var rs := Vector3(randf_range(0.8, 1.8), randf_range(0.5, 1.0), randf_range(0.8, 1.8))
			_solid_box(_mi(root, _bm(rs), Vector3(randf_range(-5, 5), 0.0, randf_range(-3, 3)), STONE.darkened(0.15), 0.0, 1, Vector3(randf() * 20, randf() * 90, randf() * 20)), rs)


## Crea una caja visible (y sólida si collide=true). pos = centro, pat = patrón del material.
func box(pos: Vector3, size: Vector3, col: Color, emit := 0.0, collide := true, pat := 0) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.material_override = mat(col, emit, pat)
	m.position = pos
	add_child(m)
	if collide:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		sb.add_child(cs)
		m.add_child(sb)
	return m


## Crea un cilindro/cono visible (y sólido si collide=true). top<0 = cilindro; top=0 = cono.
func cyl(pos: Vector3, r: float, h: float, col: Color, top := -1.0, emit := 0.0, collide := true, seg := 8, pat := 0) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.bottom_radius = r
	c.top_radius = r if top < 0.0 else top
	c.height = h
	c.radial_segments = seg
	m.mesh = c
	m.material_override = mat(col, emit, pat)
	m.position = pos
	add_child(m)
	if collide:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var s := CylinderShape3D.new()
		s.radius = r
		s.height = h
		cs.shape = s
		sb.add_child(cs)
		m.add_child(sb)
	return m


## Convierte en sólido un nodo ya creado: le cuelga un StaticBody3D con forma de caja.
## Hereda la posición y rotación del nodo, así la colisión coincide con lo que se ve.
func _solid_box(node: Node3D, size: Vector3) -> void:
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	sb.add_child(cs)
	node.add_child(sb)


# Color base de la piedra del castillo y FALLS = centro (x, z) del conjunto de cascadas.
const STONE := Color(0.52, 0.48, 0.36)
const FALLS := Vector2(40, 10)


## Atajo: malla de caja.
func _bm(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


## Atajo: malla de cilindro/cono (r radio, h alto, top radio superior).
func _cm(r: float, h: float, top := -1.0, seg := 8) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.bottom_radius = r
	c.top_radius = r if top < 0.0 else top
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c


## Atajo: malla de esfera.
func _sm(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 8
	s.rings = 5
	return s


## Crea una pieza (MeshInstance3D) colgada de "parent" con material, posición y rotación.
func _mi(parent: Node3D, mesh: Mesh, pos: Vector3, col: Color, emit := 0.0, pat := 0, rot := Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat(col, emit, pat)
	m.position = pos
	m.rotation_degrees = rot
	parent.add_child(m)
	return m


## Luz puntual. Si fire=true parpadea como una llama (ver _process).
func _light(pos: Vector3, col: Color, energy: float, rng: float, fire := false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.position = pos
	add_child(l)
	if fire:
		fire_lights.append(l)
	return l


## Almenas a lo largo de un tramo de muralla (from -> to) + una caja de colisión continua.
func _merlons(from: Vector3, to: Vector3, step := 2.4) -> void:
	var d := to - from
	var dir := d.normalized()
	var ang := atan2(-dir.z, dir.x)
	var xf: Array = []
	for i in int(d.length() / step) + 1:
		xf.append(Transform3D(Basis(Vector3.UP, ang), from + dir * (i * step)))
	_mm(_bm(Vector3(1.3, 1.5, 2.2)), xf, mat(STONE, 0.0, 1), Vector3.ZERO)
	# colisión: una sola caja que cubre todo el tramo de almenas
	var sb := StaticBody3D.new()
	sb.position = from + d / 2.0
	sb.rotation.y = ang
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(d.length() + 1.3, 1.5, 2.2)
	cs.shape = bs
	sb.add_child(cs)
	add_child(sb)


## Arco de piedra hecho de n bloques en semicírculo. skip = probabilidad de omitir bloques (arco en ruinas).
func _arch(c: Vector3, r: float, depth: float, n: int, col: Color, parent: Node3D = null, skip := 0.0) -> void:
	var par: Node3D = parent if parent else self
	for i in n:
		if skip > 0.0 and randf() < skip:
			continue
		var a := PI * (i + 0.5) / n
		var m := _mi(par, _bm(Vector3(r * PI / n * 1.15, 0.9, depth)), c + Vector3(cos(a) * r, sin(a) * r, 0), col, 0.0, 1)
		m.rotation.z = a + PI / 2.0
		_solid_box(m, Vector3(r * PI / n * 1.15, 0.9, depth))


## Ventana ojival en una pared (face = hacia dónde mira). Si lit tiene alpha > 0, está iluminada por dentro.
func _win(p: Vector3, face: Vector3, lit := Color(0, 0, 0, 0), w := 1.1, h := 2.2) -> void:
	var root := Node3D.new()
	root.position = p
	root.rotation.y = atan2(face.x, face.z)
	add_child(root)
	var dk := Color(0.02, 0.03, 0.08)
	_mi(root, _bm(Vector3(w, h, 0.5)), Vector3.ZERO, dk)
	_mi(root, _cm(w / 2.0, 0.5), Vector3(0, h / 2.0, 0), dk, 0.0, 0, Vector3(90, 0, 0))
	if lit.a > 0.0:
		_mi(root, _bm(Vector3(w * 0.55, h * 0.8, 0.55)), Vector3(0, -h * 0.05, 0), lit, 2.2)
		_mi(root, _cm(w * 0.275, 0.55), Vector3(0, h * 0.35, 0), lit, 2.2, 0, Vector3(90, 0, 0))


## Torre redonda con borde, almenas, tejado cónico azul y 3 ventanas iluminadas.
func _tower(cx: float, cz: float, r: float, h: float, g: float) -> void:
	cyl(Vector3(cx, g + h / 2.0, cz), r, h, STONE, -1.0, 0.0, true, 10, 1)
	cyl(Vector3(cx, g + h + 0.4, cz), r + 0.6, 0.8, STONE.lightened(0.1), -1.0, 0.0, true, 10, 1)
	var xf: Array = []
	for i in 10:
		var a := i * TAU / 10.0
		xf.append(Transform3D(Basis(Vector3.UP, -a - PI / 2.0), Vector3(cx + cos(a) * (r + 0.4), g + h + 1.4, cz + sin(a) * (r + 0.4))))
	_mm(_bm(Vector3(1.2, 1.2, 1.0)), xf, mat(STONE, 0.0, 1), Vector3.ZERO)
	cyl(Vector3(cx, g + h + 0.8 + 3.5, cz), r + 0.8, 7.0, Color(0.1, 0.13, 0.3), 0.0, 0.0, true, 10, 7)
	for k in 3:
		var a2 := k * TAU / 3.0 + cx
		_win(Vector3(cx + cos(a2) * (r - 0.05), g + h * 0.72, cz + sin(a2) * (r - 0.05)), Vector3(cos(a2), 0, sin(a2)), Color(1, 0.3, 0.12, 1), 0.9, 1.8)


## El castillo: muralla cuadrada con almenas, 4 torres de esquina, puerta con arco y antorchas,
## torreón central alto con ventanas, y al final llama a _falls() (cascadas).
func _castle() -> void:
	var g := 1.5
	var L := 22.0
	var ty := g + 8.75
	box(Vector3(0, g + 4, -L), Vector3(2 * L, 8, 2), STONE, 0.0, true, 1)
	box(Vector3(-L, g + 4, 0), Vector3(2, 8, 2 * L), STONE, 0.0, true, 1)
	box(Vector3(L, g + 4, 0), Vector3(2, 8, 2 * L), STONE, 0.0, true, 1)
	box(Vector3(-13, g + 4, L), Vector3(18, 8, 2), STONE, 0.0, true, 1)
	box(Vector3(13, g + 4, L), Vector3(18, 8, 2), STONE, 0.0, true, 1)
	_merlons(Vector3(-L, ty, -L), Vector3(L, ty, -L))
	_merlons(Vector3(-L, ty, -L), Vector3(-L, ty, L))
	_merlons(Vector3(L, ty, -L), Vector3(L, ty, L))
	_merlons(Vector3(-L, ty, L), Vector3(-4, ty, L))
	_merlons(Vector3(4, ty, L), Vector3(L, ty, L))
	for x in [-20.0, -12.0, 12.0, 20.0]:
		box(Vector3(x, g + 3.25, L + 1.7), Vector3(1.6, 6.5, 1.6), STONE.darkened(0.1), 0.0, true, 1)
		box(Vector3(x, g + 7.0, L + 1.55), Vector3(1.6, 1.0, 1.3), STONE.lightened(0.1), 0.0, true, 1)
	for x in [-16.0, -8.0, 8.0, 16.0]:
		_win(Vector3(x, g + 5.0, L + 1.0), Vector3(0, 0, 1), Color(1, 0.5, 0.15, 1) if randf() < 0.5 else Color(0, 0, 0, 0))
		_win(Vector3(x, g + 5.0, -L - 1.0), Vector3(0, 0, -1), Color(1, 0.5, 0.15, 1) if randf() < 0.5 else Color(0, 0, 0, 0))
	# puerta ojival con antorchas
	box(Vector3(0, g + 7.0, L), Vector3(8, 2.0, 2), STONE, 0.0, true, 1)
	_arch(Vector3(0, g + 2.4, L), 4.0, 2.4, 9, STONE.lightened(0.15))
	for sx in [-4.6, 4.6]:
		box(Vector3(sx, g + 3.4, L + 1.3), Vector3(0.2, 0.9, 0.2), Color(0.2, 0.12, 0.08), 0.0, false)
		box(Vector3(sx, g + 4.05, L + 1.3), Vector3(0.4, 0.5, 0.4), Color(1, 0.6, 0.15), 3.0, false)
		_light(Vector3(sx, g + 4.2, L + 2.0), Color(1, 0.55, 0.2), 1.8, 12.0, true)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_tower(sx * L, sz * L, 4.0, 16.0, g)
	# torreón central
	box(Vector3(0, g + 8, -6), Vector3(14, 16, 12), STONE.darkened(0.05), 0.0, true, 1)
	_merlons(Vector3(-7, g + 16.75, -12), Vector3(7, g + 16.75, -12))
	_merlons(Vector3(-7, g + 16.75, 0), Vector3(7, g + 16.75, 0))
	_merlons(Vector3(-7, g + 16.75, -12), Vector3(-7, g + 16.75, 0))
	_merlons(Vector3(7, g + 16.75, -12), Vector3(7, g + 16.75, 0))
	_tower(0.0, -6.0, 3.0, 26.0, g)
	for x in [-4.5, 0.0, 4.5]:
		for y in [6.0, 11.5]:
			_win(Vector3(x, g + y, 0.0), Vector3(0, 0, 1), Color(1, 0.4, 0.15, 1), 1.2, 2.4)
	_light(Vector3(0, g + 12, 4), Color(1, 0.3, 0.2), 1.6, 30.0)
	_falls()


## Conjunto de cascadas: muro de fondo, dos cascadas azules animadas, estanque brillante,
## puente de arco, torres laterales, niebla en la base y luz azul.
func _falls() -> void:
	var f := Vector3(FALLS.x, 1.5, FALLS.y)
	var st := STONE.darkened(0.08)
	box(f + Vector3(0, 6, -9), Vector3(24, 12, 3), st, 0.0, true, 1)
	box(f + Vector3(0, 10.5, -4.2), Vector3(24, 3, 6.6), st, 0.0, true, 1)
	for x in [-9.5, 0.0, 9.5]:
		box(f + Vector3(x, 4.5, -3.2), Vector3(3.4, 9, 4.2), st.darkened(0.1), 0.0, true, 1)
	for sx in [-1.0, 1.0]:
		_tower(f.x + sx * 12.5, f.z - 6.0, 2.5, 15.0, 1.5)
		box(f + Vector3(sx * 4.75, 6.1, -0.6), Vector3(4.0, 11.8, 0.25), Color(0.1, 0.3, 1.0), 1.9, false, 2)
		_win(f + Vector3(sx * 4.75, 14.0, -9.0 + 1.55), Vector3(0, 0, 1), Color(0.3, 0.6, 1.0, 1), 1.4, 2.6)
	_merlons(f + Vector3(-11.5, 12.75, -6.8), f + Vector3(11.5, 12.75, -6.8))
	box(f + Vector3(0, 0.15, 5.0), Vector3(26, 0.3, 14), Color(0.04, 0.12, 0.14), 0.9, false, 4)
	box(f + Vector3(0, 7.3, 5.0), Vector3(20, 0.8, 3.4), st.lightened(0.05), 0.0, true, 1)
	_arch(f + Vector3(0, 0.6, 5.0), 5.8, 3.4, 11, st.lightened(0.12))
	for sx in [-1.0, 1.0]:
		box(f + Vector3(sx * 8.4, 3.6, 5.0), Vector3(2.4, 7.2, 3.4), st, 0.0, true, 1)
		box(f + Vector3(sx * 9.7, 8.3, 5.0), Vector3(0.5, 1.3, 3.4), st.lightened(0.1), 0.0, true, 1)
	for sx in [-1.0, 1.0]:
		var pr := CPUParticles3D.new()
		pr.amount = 24
		pr.lifetime = 3.0
		pr.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		pr.emission_sphere_radius = 2.2
		pr.direction = Vector3.UP
		pr.spread = 25.0
		pr.gravity = Vector3.ZERO
		pr.initial_velocity_min = 0.3
		pr.initial_velocity_max = 0.9
		pr.position = f + Vector3(sx * 4.75, 1.2, 0.8)
		var qm := BoxMesh.new()
		qm.size = Vector3(0.9, 0.9, 0.9)
		var sm := StandardMaterial3D.new()
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm.albedo_color = Color(0.5, 0.7, 1.0, 0.22)
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		qm.material = sm
		pr.mesh = qm
		add_child(pr)
	_light(f + Vector3(0, 3.0, 3.0), Color(0.2, 0.35, 1.0), 3.5, 30.0)


## Laboratorio de alquimista en una aldea: chimenea con fuego, caldero con vapor, mesa con pociones y libro.
func _lab(c: Vector2) -> void:
	var o := Vector3(c.x - 3.0, 1.5, c.y - 1.0)
	box(o + Vector3(0, 1.6, -3.4), Vector3(3.6, 3.2, 1.8), STONE, 0.0, true, 1)
	box(o + Vector3(0, 4.6, -3.4), Vector3(1.4, 3.2, 1.2), STONE.darkened(0.1), 0.0, true, 1)
	box(o + Vector3(0, 0.95, -2.45), Vector3(1.8, 1.5, 0.3), Color(0.03, 0.02, 0.02), 0.0, false)
	box(o + Vector3(0, 0.55, -2.4), Vector3(1.3, 0.8, 0.25), Color(1.0, 0.45, 0.08), 3.0, false)
	box(o + Vector3(0.2, 0.85, -2.38), Vector3(0.6, 0.7, 0.25), Color(1.0, 0.85, 0.2), 3.5, false)
	_light(o + Vector3(0, 1.5, -1.4), Color(1, 0.5, 0.15), 2.4, 14.0, true)
	box(o + Vector3(-2.8, 0.45, -0.6), Vector3(2.6, 0.9, 1.3), Color(0.28, 0.18, 0.1), 0.0, true)
	var bk := box(o + Vector3(-3.5, 0.95, -0.6), Vector3(0.7, 0.07, 0.5), Color(1, 0.85, 0.3), 1.8, false)
	bk.rotation.y = 0.3
	var cols := [Color(0.2, 0.4, 1.0), Color(0.2, 1.0, 0.4), Color(1.0, 0.5, 0.1), Color(0.7, 0.3, 1.0)]
	for i in 4:
		var p := o + Vector3(-2.6 + i * 0.28, 0.9, -0.7 + (i % 2) * 0.3)
		_mi(self, _sm(0.2), p + Vector3(0, 0.2, 0), cols[i], 2.0)
		_mi(self, _cm(0.05, 0.22), p + Vector3(0, 0.45, 0), cols[i], 1.5)
		_mi(self, _bm(Vector3(0.1, 0.07, 0.1)), p + Vector3(0, 0.6, 0), Color(0.4, 0.25, 0.1))
	var cp := o + Vector3(0, 0, -1.2)
	_mi(self, _sm(0.75), cp + Vector3(0, 0.75, 0), Color(0.12, 0.13, 0.15), 0.0, 0).scale = Vector3(1.0, 0.8, 1.0)
	_mi(self, _cm(0.62, 0.12), cp + Vector3(0, 1.28, 0), Color(0.2, 0.2, 0.24))
	_mi(self, _cm(0.54, 0.05), cp + Vector3(0, 1.33, 0), Color(0.3, 1.0, 0.5), 2.0)
	for k in 3:
		var a := k * TAU / 3.0
		_mi(self, _bm(Vector3(0.15, 0.4, 0.15)), cp + Vector3(cos(a) * 0.5, 0.2, sin(a) * 0.5), Color(0.1, 0.1, 0.12))
	_mi(self, _bm(Vector3(0.7, 0.2, 0.7)), cp + Vector3(0, 0.12, 0), Color(1, 0.45, 0.1), 3.0)
	_light(cp + Vector3(0, 1.8, 0), Color(0.3, 1.0, 0.5), 1.2, 7.0)
	var st := CPUParticles3D.new()
	st.amount = 14
	st.lifetime = 2.5
	st.direction = Vector3.UP
	st.spread = 15.0
	st.gravity = Vector3.ZERO
	st.initial_velocity_min = 0.3
	st.initial_velocity_max = 0.7
	st.position = cp + Vector3(0, 1.4, 0)
	var qm := BoxMesh.new()
	qm.size = Vector3(0.35, 0.35, 0.35)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = Color(0.7, 0.9, 0.8, 0.25)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.material = sm
	st.mesh = qm
	add_child(st)


## Aldea: 4 casas con tejado de pizarra y ventana naranja, pozo, hoguera central, luz y laboratorio.
func _village(c: Vector2) -> void:
	var g := 1.5
	for o in [Vector2(-9, -9), Vector2(9, -9), Vector2(-9, 9), Vector2(9, 9)]:
		var p := Vector3(c.x + o.x, g, c.y + o.y)
		box(p + Vector3(0, 2, 0), Vector3(6, 4, 6), Color(0.32, 0.24, 0.18), 0.0, true, 8)
		var r := cyl(p + Vector3(0, 5.2, 0), 5.2, 2.5, Color(0.16, 0.12, 0.14), 0.0, 0.0, true, 4, 7)
		r.rotation.y = PI / 4.0
		box(p + Vector3(-signf(o.x) * 3.05, 2.4, 0), Vector3(0.2, 1.2, 1.2), Color(1, 0.6, 0.2), 2.0, false)
	cyl(Vector3(c.x + 3, g + 0.8, c.y + 3), 0.7, 1.6, Color(0.3, 0.18, 0.1))
	box(Vector3(c.x, g + 0.4, c.y), Vector3(0.8, 0.8, 0.8), Color(0.9, 0.3, 0.06), 0.9, false)
	var l := OmniLight3D.new()
	l.light_color = Color(1, 0.55, 0.2)
	l.omni_range = 22.0
	l.position = Vector3(c.x, g + 3, c.y)
	add_child(l)
	_lab(c)


## Faro de piedra en un islote del pantano/costa, con luz que alcanza 45 m.
func _lighthouse() -> void:
	var pos := Vector3(60, 0, -110)
	pos.y = height_at(pos.x, pos.z)
	for i in 500:
		var x := randf_range(-100, 100)
		var z := randf_range(-100, 100)
		var h := height_at(x, z)
		if h > WATER + 0.2 and h < WATER + 1.2 and Vector2(x, z).length() > 60.0:
			pos = Vector3(x, h, z)
			break
	lighthouse_pos = Vector2(pos.x, pos.z)
	cyl(pos + Vector3(0, 9, 0), 2.8, 18.0, Color(0.25, 0.27, 0.35), 1.8)
	cyl(pos + Vector3(0, 19.5, 0), 2.4, 3.0, Color(0.2, 0.2, 0.28))
	cyl(pos + Vector3(0, 23, 0), 3.0, 4.0, Color(0.1, 0.1, 0.16), 0.0, 0.0, true)
	box(pos + Vector3(0, 19.5, 0), Vector3(1.6, 1.6, 1.6), Color(1, 0.8, 0.4), 2.5, false)
	var l := OmniLight3D.new()
	l.light_color = Color(1, 0.8, 0.4)
	l.omni_range = 45.0
	l.position = pos + Vector3(0, 19.5, 0)
	add_child(l)


## (vacía) El cielo ya no es un nodo: es el shader sky.gdshader asignado en _env().
func _sky() -> void:
	pass  # el cielo es un shader de tipo sky (ver _env y sky.gdshader)


## Lluvia: partículas GPU que siguen a la cámara (se recolocan en _process).
func _rain() -> void:
	rain = GPUParticles3D.new()
	rain.amount = 2500
	rain.lifetime = 1.0
	rain.local_coords = false
	rain.visibility_aabb = AABB(Vector3(-30, -30, -30), Vector3(60, 60, 60))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(24, 0.5, 24)
	pm.direction = Vector3(0.15, -1, 0)
	pm.spread = 2.0
	pm.initial_velocity_min = 28.0
	pm.initial_velocity_max = 34.0
	pm.gravity = Vector3.ZERO
	rain.process_material = pm
	var qm := BoxMesh.new()
	qm.size = Vector3(0.03, 0.9, 0.03)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = Color(0.7, 0.8, 1.0, 0.5)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.material = sm
	rain.draw_pass_1 = qm
	add_child(rain)


# ---------- habitantes ----------
## Crea un mob de la facción f en la posición p y lo añade al mundo.
func spawn_mob(f: int, p: Vector3, is_big := false) -> Mob:
	var m := Mob.new()
	m.setup(self, f, p, is_big)
	add_child(m)
	return m


## Coloca (o recoloca tras comerla) una fruta en un punto aleatorio. Verde-azulada en pantano, roja en el resto.
func place_fruit(f: Node3D) -> void:
	var p := land_spot(func(_x, _z, h): return h < 12.0)
	f.position = Vector3(p.x, p.y - 0.4, p.z)
	var wet := p.y < 2.0 and moist.get_noise_2d(p.x, p.z) > 0.1
	((f as MeshInstance3D).material_override as ShaderMaterial).set_shader_parameter(
		"tint", Color(0.2, 0.9, 0.8) if wet else Color(0.95, 0.2, 0.2))


## Puebla el mundo: caballeros en el castillo, aldeanos y un lobo alquimista por aldea, cultistas,
## monstruos y 2 ogros gigantes; 130 frutas; y por último la mosca (con su cerebro).
func _population() -> void:
	for i in 6:
		spawn_mob(1, Vector3(randf_range(-16, 16), 4.0, randf_range(8, 18)))
	for c in VILLAGES:
		for i in 6:
			spawn_mob(0, Vector3(c.x + randf_range(-5, 5), 4.0, c.y + randf_range(-5, 5)))
	for c in VILLAGES:
		MobModel.force_variant = "wolf"
		var wm := spawn_mob(2, Vector3(c.x - 3.0, 4.0, c.y + 1.8))
		MobModel.force_variant = ""
		wm.leash = 5.0
		wm.mob_name = "Alquimista " + wm.mob_name
	# Mobs salvajes repartidos por todo el mapa: cada uno se coloca en el candidato más alejado de los ya puestos,
	# así no se amontonan y la mosca se cruza con alguno en casi cualquier recorrido.
	spread_pts.clear()
	spread_pts.append(Vector2.ZERO)
	for v in VILLAGES:
		spread_pts.append(v)
	for i in 10:
		spawn_mob(2, spread_spot(func(x, z, _h): return moist.get_noise_2d(x, z) > 0.05 and Vector2(x, z).length() > 50.0))
	for i in 20:
		spawn_mob(3, spread_spot(func(x, z, h): return h > 3.0 and Vector2(x, z).length() > 55.0))
	for i in 2:
		spawn_mob(3, spread_spot(func(x, z, h): return h > 6.0 and Vector2(x, z).length() > 60.0), true)
	var sm := SphereMesh.new()
	sm.radius = 0.35; sm.height = 0.7; sm.radial_segments = 6; sm.rings = 3
	for i in 130:
		var f := MeshInstance3D.new()
		f.mesh = sm
		f.material_override = mat(Color(0.95, 0.2, 0.2), 1.2)
		f.add_to_group("fruit")
		add_child(f)
		place_fruit(f)
	fly = Fly.new()
	fly.setup(self)
	add_child(fly)
	fly.position = Vector3(0, 6, 34)
	foc = fly


# ---------- interfaz y cámaras ----------
## Interfaz: texto superior (HUD), registro de eventos, panel de actividad neuronal y los 4 botones.
func _ui() -> void:
	var cl := CanvasLayer.new()
	add_child(cl)
	hud = Label.new()
	hud.position = Vector2(8, 6)
	hud.add_theme_font_size_override("font_size", 12)
	cl.add_child(hud)
	logl = Label.new()
	logl.position = Vector2(8, 215)
	logl.add_theme_font_size_override("font_size", 10)
	cl.add_child(logl)
	nv = NeuroView.new()
	nv.brain = fly.brain
	nv.position = Vector2(448, 8)
	nv.size = Vector2(180, 40)
	cl.add_child(nv)
	# minimapa (esquina) y mapa completo (M); los mobs se ven como puntos rojos
	minimap = MapView.new()
	minimap.position = Vector2(512, 54)
	minimap.size = Vector2(120, 120)
	minimap.build(self)
	cl.add_child(minimap)
	map_layer = CanvasLayer.new()
	map_layer.layer = 5
	map_layer.visible = false
	add_child(map_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.9)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_layer.add_child(dim)
	bigmap = MapView.new()
	bigmap.big = true
	bigmap.position = Vector2(150, 10)
	bigmap.size = Vector2(340, 340)
	bigmap.build(self)
	bigmap.travel.connect(_map_travel)
	map_layer.add_child(bigmap)
	var ml := Label.new()
	ml.text = "MAPA · clic: viajar con la cámara libre · M: cerrar\nPuntos rojos: mobs · amarillo: mosca · flecha: cámara"
	ml.position = Vector2(8, 8)
	ml.add_theme_font_size_override("font_size", 10)
	map_layer.add_child(ml)
	var items := [["Cámara (C)", _cycle_mode], ["Siguiente (N)", next_target], ["Mosca (F)", _to_fly], ["Vel (V)", _cycle_speed], ["Hora (T)", func(): dn.next_preset()], ["Mapa (M)", _toggle_map]]
	for i in items.size():
		var b := Button.new()
		b.text = items[i][0]
		b.position = Vector2(8 + i * 104, 330)
		b.size = Vector2(100, 24)
		b.add_theme_font_size_override("font_size", 11)
		b.pressed.connect(items[i][1])
		cl.add_child(b)


## Pasa de primera persona -> tercera -> cámara libre (tecla C).
func _cycle_mode() -> void:
	mode = (mode + 1) % 3
	off_yaw = 0.0
	off_pitch = 0.0
	if mode == 2:
		free_yaw = cam.rotation.y
		free_pitch = -0.3


## La cámara pasa a seguir al siguiente ser vivo de la lista (tecla N).
func next_target() -> void:
	var arr: Array = [fly]
	for m in get_tree().get_nodes_in_group("mobs"):
		if (m as Mob).alive:
			arr.append(m)
	var i := arr.find(foc)
	foc = arr[(i + 1) % arr.size()]
	off_yaw = 0.0
	off_pitch = 0.0


## Vuelve a seguir a la mosca (tecla F).
func _to_fly() -> void:
	foc = fly


## Cambia la velocidad de simulación x1 -> x3 -> x8 (tecla V).
func _cycle_speed() -> void:
	speed_i = (speed_i + 1) % 3
	Engine.time_scale = [1.0, 3.0, 8.0][speed_i]


## Abre / cierra el mapa completo (tecla M).
func _toggle_map() -> void:
	map_layer.visible = not map_layer.visible


## Clic en el mapa completo: la cámara libre viaja a ese punto, a 25 m sobre el suelo.
func _map_travel(p: Vector2) -> void:
	mode = 2
	off_yaw = 0.0
	off_pitch = 0.0
	free_yaw = cam.rotation.y
	free_pitch = -0.5
	cam.global_position = Vector3(p.x, maxf(height_at(p.x, p.y), WATER) + 25.0, p.y)
	map_layer.visible = false


## Teclado (C, N, F, V, T, Y, R, M) y ratón (arrastrar con el botón izquierdo = girar la cámara).
func _input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_C: _cycle_mode()
			KEY_N: next_target()
			KEY_F: _to_fly()
			KEY_V: _cycle_speed()
			KEY_F11:
				var fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fs else DisplayServer.WINDOW_MODE_FULLSCREEN)
			KEY_T: dn.next_preset()
			KEY_Y: dn.auto = not dn.auto
			KEY_R: dn.rain_auto = false; dn.rain_on = not dn.rain_on
			KEY_M: _toggle_map()
	elif e is InputEventMouseButton and e.pressed and mode == 2 and not map_layer.visible:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP: free_speed = minf(free_speed * 1.2, 400.0)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN: free_speed = maxf(free_speed / 1.2, 3.0)
	elif e is InputEventMouseMotion and (e.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0 and not map_layer.visible:
		if mode == 2:
			free_yaw -= e.relative.x * 0.005
			free_pitch = clampf(free_pitch - e.relative.y * 0.005, -1.4, 1.4)
		else:
			off_yaw -= e.relative.x * 0.005
			off_pitch = clampf(off_pitch - e.relative.y * 0.005, -1.2, 1.2)


## CADA FRAME: mueve el cielo y la lluvia con la cámara, hace parpadear los fuegos y coloca la cámara
## según el modo (primera / tercera con rayo anti-muros / libre). Al final actualiza el HUD.
func _process(dt: float) -> void:
	if sky_dome and cam:
		sky_dome.global_position = cam.global_position
	for i in fire_lights.size():
		# llama viva: varias frecuencias + chispazos aleatorios; el rango y el color también respiran
		var tm := Time.get_ticks_msec() * 0.001
		var fl := 0.5 + 0.28 * sin(tm * 9.0 + i * 2.0) + 0.18 * sin(tm * 23.0 + i * 5.0) + randf() * 0.2
		if randf() < 0.02: fl *= 0.55
		fire_lights[i].light_energy = (1.2 + fl * 1.6) * lerpf(0.35, 1.0, dn.night if dn else 1.0)
		fire_lights[i].omni_range = 10.0 + fl * 5.0
		fire_lights[i].light_color = Color(1.0, 0.45 + 0.12 * fl, 0.12)
	if foc is Mob and not (foc as Mob).alive:
		foc = fly
	if prev_body and is_instance_valid(prev_body):
		prev_body.visible = true
	var body := foc.get_node("Body") as Node3D
	prev_body = body
	if cam_foc != foc:
		cam_foc = foc
		cam_yaw = foc.rotation.y
	cam_yaw = lerp_angle(cam_yaw, foc.rotation.y, 1.0 - exp(-12.0 * dt))
	match mode:
		0:
			body.visible = false
			var b := Basis.from_euler(Vector3(off_pitch, cam_yaw + off_yaw, 0))
			cam.global_transform = Transform3D(b, foc.global_position + Vector3.UP * float(foc.get("eye_height")))
			cam.fov = 100.0 if foc == fly else 80.0
		1:
			var b := Basis.from_euler(Vector3(off_pitch - 0.3, cam_yaw + off_yaw, 0))
			var dist := 3.5 if foc == fly else 6.0
			var origin := foc.global_position + Vector3.UP * (float(foc.get("eye_height")) + 0.5)
			var tp := origin + b.z * dist
			# rayo desde el personaje hasta donde querría estar la cámara: si choca con un
			# muro o el terreno, la cámara se queda justo delante del obstáculo
			var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin, tp, 1))
			if not hit.is_empty():
				tp = (hit["position"] as Vector3) + (hit["normal"] as Vector3) * 0.4
			cam.global_position = cam.global_position.lerp(tp, 1.0 - exp(-10.0 * dt))
			cam.global_basis = b
			cam.fov = 75.0
		2:
			var b := Basis.from_euler(Vector3(free_pitch, free_yaw, 0))
			var dir := Vector3.ZERO
			if Input.is_key_pressed(KEY_W): dir -= b.z
			if Input.is_key_pressed(KEY_S): dir += b.z
			if Input.is_key_pressed(KEY_A): dir -= b.x
			if Input.is_key_pressed(KEY_D): dir += b.x
			if Input.is_key_pressed(KEY_E): dir += Vector3.UP
			if Input.is_key_pressed(KEY_Q): dir -= Vector3.UP
			var sp := free_speed * (4.0 if Input.is_key_pressed(KEY_SHIFT) else (0.25 if Input.is_key_pressed(KEY_CTRL) else 1.0))
			cam.global_position += dir.normalized() * sp * dt / maxf(Engine.time_scale, 1.0)
			cam.global_basis = b
			cam.fov = 75.0
	var gy := height_at(cam.global_position.x, cam.global_position.z) + 0.8
	if mode != 2 and cam.global_position.y < gy:   # la cámara libre atraviesa el terreno si se quiere
		cam.global_position.y = gy
	rain.global_position = cam.global_position + Vector3(0, 14, 0)
	var who := "Mosca" if foc == fly else "%s (%s)" % [(foc as Mob).mob_name, Mob.FNAME[(foc as Mob).faction]]
	hud.text = "%s · %s\nMosca: gen %d · energía %d · frutas %d · %s\nCerebro: %s\n%s %s%s%s" % [
		MODES[mode], who, fly.gen, int(fly.energy), fly.eaten, biome_name(fly.global_position),
		fly.real_brain.status,
		dn.clock(), dn.preset_name(), " (auto)" if dn.auto else "", ("  · cámara libre %d m/s" % int(free_speed)) if mode == 2 else ""] + ("  · %d FPS" % Engine.get_frames_per_second() if show_fps else "")
