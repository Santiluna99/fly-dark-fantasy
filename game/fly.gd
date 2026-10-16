class_name Fly extends CharacterBody3D
## LA MOSCA
## Es un cuerpo físico (CharacterBody3D) que vuela. Sus sentidos (olor, "visión" de amenazas,
## hambre) alimentan la red neuronal FlyBrain; las neuronas motoras de esa red deciden hacia
## dónde gira y a qué velocidad avanza. Choca con muros, torres, árboles, rocas y terreno.

# ---------------------------------------------------------------- AJUSTES (toca aquí)
const SPEED_MIN := 0.8        # m/s: velocidad de crucero mínima
const SPEED_MAX := 3.0        # m/s: velocidad máxima (antes llegaba a ~10 m/s: demasiado rápida)
const TURN_GAIN := 0.18       # cuánto gira por tick según (neurona giro der - giro izq)
const CLIMB_RATE := 2.5       # m/s máximos al subir o bajar para mantener la altura
const HOVER_HEIGHT := 1.3     # altura de vuelo sobre el suelo
const HUNGER_RATE := 0.45     # energía que pierde por segundo (aguanta ~220 s sin comer)
const SMELL_RANGE := 60.0     # a qué distancia "huele" la fruta
const THREAT_RANGE := 8.0     # a qué distancia "ve" amenazas (mobs y hechizos)

# ---------------------------------------------------------------- ESTADO
var world                      # referencia a main.gd (el mundo): terreno, mat(), log_msg()...
var brain: FlyBrain = FlyBrain.new()   # el cerebro en uso: local (80 neuronas) o REAL (RemoteBrain, conectoma)
var local_brain: FlyBrain = brain      # el cerebro de 80 neuronas (con aprendizaje)
var real_brain := RemoteBrain.new()    # el cerebro real: se conecta a cerebro_real/fly_server.py
var use_real := false
var alive := true              # los hechizos y mobs comprueban esto antes de interactuar
var energy := 100.0            # 0 = muere de hambre
var gen := 1                   # nº de vida actual (al morir renace y conserva lo aprendido)
var eaten := 0                 # frutas comidas en esta vida
var age := 0.0                 # segundos vividos en esta vida
var eye_height := 0.05         # altura de los ojos para la cámara en primera persona
var ou1 := 0.0                 # ruido lento (Ornstein-Uhlenbeck) que hace girar a la mosca al azar
var ou2 := 0.0                 # idem para el otro lado
var pun_t := 0.0               # temporizador del "castigo" por estar cerca de peligro
var bump_t := 0.0              # >0 justo después de chocar: sube un poco para sortear el obstáculo
var pain := 0.0                # dolor (1 = recién chocó); decae en ~0,8 s y activa la huida del lado golpeado
var pain_side := 0.0           # lado del golpe: -1 izquierda, +1 derecha
var wall_mem: Array = []       # memoria del dolor: [posición del choque, edad en s]; se evita ese sitio durante ~10 s
var last_pain_msg := -10.0
# --- APRENDIZAJE POR DOLOR (condicionamiento): "bigotes" = 3 rayos al frente que miden la cercanía de una pared.
# Al principio la mosca es ingenua (miedo = 0 y no reacciona a lo que ve). Cada vez que se golpea con la pared a la vista,
# sube su miedo y aprende a asociar "pared cercana" -> peligro. Funciona con cualquier cerebro (local o real) porque
# actúa en la entrada del cerebro. Se guarda en disco: lo aprendido sobrevive a morir y a cerrar el juego.
const WHISKER_LEN := 9.0
var wall_fear := 0.0            # 0 = ingenua, 1.5 = muy cautelosa
var pain_events := 0
var learn_enabled := true
var persist_learning := true
var prox_l := 0.0
var prox_c := 0.0
var prox_r := 0.0
var c_side := 1.0
var _save_t := 0.0
const LEARN_FILE := "user://mosca_aprendizaje.json"
var _say_t := {}                # enfriamiento por tipo de mensaje del registro
var contact_t := 0.0            # tiempo seguido rozando una pared
var back_t := 0.0               # >0: retrocede y se aleja de la pared
var wall_n := Vector3.ZERO      # normal de la última pared tocada
var immortal := false          # para grabar videos: no muere
var bump_turn := 0.0           # giro pendiente tras un choque (se aplica poco a poco, no de golpe)
var bump_dir := 1.0            # lado hacia el que gira tras un choque (+1 / -1)
var wl: MeshInstance3D         # ala izquierda (se anima aleteando)
var wr: MeshInstance3D         # ala derecha
var fruits: Array = []         # nodos fruta del grupo "fruit" (se cargan en el primer tick)


## Cambia entre el cerebro local (80 neuronas) y el real (conectoma por servidor). Devuelve el cerebro activo.
func set_real_brain(on: bool) -> FlyBrain:
	use_real = on
	if on:
		real_brain.start()
		brain = real_brain
	else:
		brain = local_brain
	return brain


## Construye el cuerpo visual (abdomen, ojos rojos, alas), la luz y la colisión.
func setup(w) -> void:
	world = w
	# --- Colisión: una esfera pequeña. Capa 4 (la mosca), choca con capa 1 (mundo estático).
	# Los mobs están en la capa 2 y la máscara de la mosca no la incluye, así que los atraviesa.
	collision_layer = 4
	collision_mask = 1
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING   # vuela: no hay "suelo" ni gravedad
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.3
	cs.shape = sh
	add_child(cs)
	# --- Cuerpo visual. El nodo "Body" lo oculta main.gd en primera persona.
	var body := Node3D.new()
	body.name = "Body"
	add_child(body)
	var sm := SphereMesh.new()
	sm.radius = 0.18; sm.height = 0.36; sm.radial_segments = 6; sm.rings = 3
	var b := MeshInstance3D.new()
	b.mesh = sm; b.material_override = world.mat(Color(0.5, 0.47, 0.42), 0.5)   # cuerpo ceniza, sucio
	body.add_child(b)
	# --- Ojos rojos (dos esferas emisivas)
	for sx in [-1.0, 1.0]:
		var e := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.09; em.height = 0.18; em.radial_segments = 5; em.rings = 2
		e.mesh = em; e.material_override = world.mat(Color(0.95, 0.12, 0.08), 2.4)
		e.position = Vector3(sx * 0.1, 0.05, -0.15)
		body.add_child(e)
	# --- Alas: dos planos translúcidos
	var wm := StandardMaterial3D.new()
	wm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.albedo_color = Color(0.62, 0.7, 0.68, 0.4)
	wm.cull_mode = BaseMaterial3D.CULL_DISABLED
	var q := QuadMesh.new()
	q.size = Vector2(0.45, 0.16)
	q.orientation = PlaneMesh.FACE_Y
	wl = MeshInstance3D.new(); wl.mesh = q; wl.material_override = wm; wl.position = Vector3(-0.3, 0.15, 0.05)
	wr = MeshInstance3D.new(); wr.mesh = q; wr.material_override = wm; wr.position = Vector3(0.3, 0.15, 0.05)
	body.add_child(wl); body.add_child(wr)
	# --- Pequeña luz azulada para que se vea de noche
	var l := OmniLight3D.new()
	l.light_color = Color(0.75, 0.85, 0.78); l.omni_range = 5.0; l.light_energy = 0.7
	body.add_child(l)


## Cada frame: solo anima el aleteo (visual). La lógica va en _physics_process.
func _process(_d: float) -> void:
	var f := sin(Time.get_ticks_msec() * 0.06) * 0.6
	wl.rotation.z = f
	wr.rotation.z = -f


## Intensidad del olor a fruta en un punto: suma de 1/(1+d/6)^2 de todas las frutas cercanas.
var occl := {}                  # fruta (id) -> ¿hay un muro/terreno entre ella y la mosca? (se refresca cada pocos ticks)

## El olor no atraviesa muros: una fruta tapada llega muy atenuada (el aire rodea el obstáculo, pero con poca fuerza).
func _refresh_occlusion() -> void:
	var ss := get_world_3d().direct_space_state
	for n in fruits:
		var fnode := n as Node3D
		var tp := fnode.global_position + Vector3(0, 0.5, 0)
		if global_position.distance_to(tp) > 45.0:
			occl[fnode.get_instance_id()] = false
			continue
		var q := PhysicsRayQueryParameters3D.create(global_position, tp, 1, [get_rid()])
		var h := ss.intersect_ray(q)
		occl[fnode.get_instance_id()] = (not h.is_empty()) and global_position.distance_to(h["position"]) < global_position.distance_to(tp) - 1.5


func _conc(p: Vector3) -> float:
	var c := 0.0
	for n in fruits:
		var d := p.distance_to((n as Node3D).global_position)
		if d < SMELL_RANGE:
			var q := 1.0 + d / 6.0
			var w := 0.15 if occl.get((n as Node3D).get_instance_id(), false) else 1.0
			c += w / (q * q)
	return c


var _learn_loaded := false

func _load_learning() -> void:
	_learn_loaded = true
	if not persist_learning or not FileAccess.file_exists(LEARN_FILE):
		return
	var f := FileAccess.open(LEARN_FILE, FileAccess.READ)
	if f:
		var d = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			wall_fear = clampf(float(d.get("wall_fear", 0.0)), 0.0, 1.5)
			pain_events = int(d.get("pain_events", 0))


func _save_learning() -> void:
	if not persist_learning:
		return
	var f := FileAccess.open(LEARN_FILE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"wall_fear": wall_fear, "pain_events": pain_events}))


## Un rayo de "bigote": cercanía 0..1 de la pared más próxima en esa dirección (solo superficies verticales).
func _whisker(dir: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(global_position, global_position + dir * WHISKER_LEN, collision_mask, [get_rid()])
	var h := get_world_3d().direct_space_state.intersect_ray(q)
	if h.is_empty() or absf((h["normal"] as Vector3).y) >= 0.7:
		return 0.0
	return 1.0 - global_position.distance_to(h["position"]) / WHISKER_LEN


## Mensaje del registro con enfriamiento (para no repetirlo a cada tick).
func _say(key: String, msg: String, cooldown: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_say_t.get(key, -1000.0)) >= cooldown:
		_say_t[key] = now
		world.log_msg(msg)


## Un tick de vida: sentir -> pensar (red neuronal) -> moverse (con colisiones) -> comer.
func _physics_process(dt: float) -> void:
	if not alive:
		return
	if fruits.is_empty():
		fruits = get_tree().get_nodes_in_group("fruit")
	if not _learn_loaded:
		_load_learning()
	age += dt
	energy -= HUNGER_RATE * dt
	if energy <= 0.0:
		die("hambre")
		return

	# ================= 1) SENTIDOS =================
	var b := global_transform.basis
	var fwd := -b.z               # hacia dónde mira
	var right := b.x
	# Las dos "antenas": un punto delante-izquierda y otro delante-derecha. Comparar el olor
	# entre ambas es lo que permite girar hacia la fruta.
	var pl := global_position + fwd * 0.6 - right * 0.8     # antenas separadas 1.6 m: mas diferencia de olor entre ambos lados
	var pr := global_position + fwd * 0.6 + right * 0.8
	var hun := 1.0 - energy / 100.0     # 0 = saciada, 1 = hambrienta
	var ll := 0.0                        # amenaza detectada por la izquierda
	var lr := 0.0                        # amenaza detectada por la derecha
	var near := 999.0                    # distancia a la amenaza más cercana
	var threats: Array = get_tree().get_nodes_in_group("mobs") + get_tree().get_nodes_in_group("proj")
	for n in threats:
		var t := n as Node3D
		var act: bool = t.get("alive")
		if not act:
			continue
		var rel: Vector3 = t.global_position - global_position
		var d := rel.length()
		near = minf(near, d)
		# solo ve lo que está delante o a los lados (no justo detrás)
		if d < THREAT_RANGE and d > 0.01 and rel.dot(fwd) / d > -0.6:
			var s := (1.0 - d / THREAT_RANGE) * 0.9      # más cerca = más intenso
			if rel.dot(right) < 0.0:
				ll = maxf(ll, s)
			else:
				lr = maxf(lr, s)
	# DOLOR: un choque contra una pared activa los detectores de amenaza del lado golpeado (el cerebro huye de ahí)
	# y deja una memoria del lugar: durante unos segundos esos puntos cuentan como peligro delante de la mosca.
	pain = maxf(0.0, pain - dt / 0.8)
	if pain > 0.0:
		if pain_side < 0.0:
			ll = maxf(ll, 0.9 * pain)
		else:
			lr = maxf(lr, 0.9 * pain)
	for k in range(wall_mem.size() - 1, -1, -1):
		wall_mem[k][1] += dt
		if wall_mem[k][1] > 10.0:
			wall_mem.remove_at(k)
			continue
		var wrel: Vector3 = (wall_mem[k][0] as Vector3) - global_position
		var wd := wrel.length()
		if wd < 6.0 and wd > 0.01 and wrel.dot(fwd) / wd > -0.2:
			var ws: float = (1.0 - wd / 6.0) * 0.8 * (1.0 - wall_mem[k][1] / 10.0)
			if wrel.dot(right) < 0.0:
				ll = maxf(ll, ws)
			else:
				lr = maxf(lr, ws)
	# BIGOTES: lo que la mosca ha aprendido a temer (wall_fear) convierte la cercanía de una pared en amenaza.
	if learn_enabled:
		var yaw_l := fwd.rotated(Vector3.UP, 0.6)
		var yaw_r := fwd.rotated(Vector3.UP, -0.6)
		prox_l = _whisker(yaw_l)
		prox_r = _whisker(yaw_r)
		prox_c = _whisker(fwd)
		if absf(prox_l - prox_r) > 0.05:
			c_side = 1.0 if prox_l > prox_r else -1.0   # el frente se reparte hacia el lado más cerrado: gira hacia el abierto
		ll = maxf(ll, wall_fear * (prox_l + (prox_c if c_side > 0.0 else 0.0)) * 0.9)
		lr = maxf(lr, wall_fear * (prox_r + (prox_c if c_side < 0.0 else 0.0)) * 0.9)
		_save_t += dt
		if _save_t > 15.0:
			_save_t = 0.0
			_save_learning()
	# ruido lento que la hace "deambular" cuando no huele nada
	ou1 = ou1 * 0.97 + randf_range(-0.03, 0.03)
	ou2 = ou2 * 0.97 + randf_range(-0.03, 0.03)

	# ================= 2) CEREBRO =================
	# Vector de entrada: una corriente por neurona (ver el mapa de neuronas en fly_brain.gd)
	var x := PackedFloat32Array()
	x.resize(FlyBrain.N)
	if Engine.get_physics_frames() % 8 == 0:
		_refresh_occlusion()
	var cl_ := _conc(pl)
	var cr_ := _conc(pr)
	x[0] = minf(0.8, 3.0 * cl_)            # neurona olfativa de la antena izquierda
	x[1] = minf(0.8, 3.0 * cr_)            # neurona olfativa de la antena derecha
	if brain is RemoteBrain:
		(brain as RemoteBrain).conc_l = cl_   # el cerebro real recibe la concentración sin saturar
		(brain as RemoteBrain).conc_r = cr_
	x[2] = ll                               # detector de amenaza (looming) izquierdo
	x[3] = lr                               # detector de amenaza derecho
	x[4] = hun * 0.3                        # neurona de hambre
	x[75] = maxf(0.0, 0.09 + ou1 * (1.0 + 2.0 * hun))   # empuje aleatorio al giro izquierdo
	x[76] = maxf(0.0, 0.09 + ou2 * (1.0 + 2.0 * hun))   # empuje aleatorio al giro derecho
	brain.step(x)
	if max(cl_, cr_) > 0.3:
		_say("olor", "Mosca: huele una fruta y se acerca", 12.0)
	if near < 5.0:
		_say("huir", "Mosca: huye de un mob cercano", 8.0)
	if energy < 50.0:
		_say("hambre", "Mosca: tiene hambre, busca comida", 30.0)

	# ================= 3) MOVIMIENTO =================
	# Giro: diferencia entre las neuronas motoras derecha (76) e izquierda (75)
	rotation.y -= (brain.rate[76] - brain.rate[75]) * TURN_GAIN
	if absf(bump_turn) > 0.001:           # rebote suave: ~3 rad/s hasta completar el giro
		var stp := clampf(bump_turn, -3.0 * dt, 3.0 * dt)
		rotation.y += stp
		bump_turn -= stp
	# Velocidad: neurona de avance (77) entre SPEED_MIN y SPEED_MAX
	var spd := SPEED_MIN + minf(SPEED_MAX - SPEED_MIN, brain.rate[77] * 8.0)
	fwd = -global_transform.basis.z       # recalcular tras girar
	# No salirse del mapa: si el siguiente paso cae fuera del borde, gira en vez de avanzar
	var lim: float = world.HALF - 4.0
	var nxt := global_position + fwd * spd * dt
	if absf(nxt.x) > lim or absf(nxt.z) > lim:
		# gira hacia el centro del mapa (hacia el lado donde queda el centro), no siempre a la izquierda
		rotation.y += 0.08 if (-global_position).dot(global_transform.basis.x) < 0.0 else -0.08
		spd = 0.0
	# Altura deseada: sobre el terreno (y nunca por debajo del agua), con un leve vaivén
	bump_t = maxf(0.0, bump_t - dt)
	# mira el terreno por delante (3 y 7 m) para empezar a subir antes de llegar a una loma
	var gh: float = world.height_at(global_position.x, global_position.z)
	var ty: float = gh + HOVER_HEIGHT + 0.5 * sin(age * 2.0)
	ty = maxf(ty, world.WATER + 1.0)
	if bump_t > 0.0 or back_t > 0.0:
		ty += 3.0                         # tras un choque sube para sortear el obstáculo
	back_t = maxf(0.0, back_t - dt)
	if back_t > 0.0:
		spd = -5.0                       # marcha atrás: se despega de la pared
	velocity = fwd * spd
	velocity.y = clampf((ty - global_position.y) * 2.0, -CLIMB_RATE, CLIMB_RATE)
	move_and_slide()                      # aquí el motor de física frena contra lo sólido
	# Si chocó de lado con algo (muro, tronco, roca, risco): siente dolor, recuerda el sitio y rebota girando
	var touched := false
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		if absf(col.get_normal().y) < 0.7:
			touched = true
			wall_n = col.get_normal()
			var rel2: Vector3 = col.get_position() - global_position
			var rt := global_transform.basis.x
			pain = 1.0
			pain_side = (1.0 if rel2.dot(rt) > 0.0 else -1.0) if absf(rel2.dot(rt)) > 0.05 else (1.0 if randf() < 0.5 else -1.0)   # choque de frente: lado al azar
			var known := false
			for w in wall_mem:
				if (w[0] as Vector3).distance_to(col.get_position()) < 2.5:
					w[1] = 0.0
					known = true
					break
			if not known:
				wall_mem.append([col.get_position(), 0.0])
				if wall_mem.size() > 14:
					wall_mem.remove_at(0)
			if Time.get_ticks_msec() / 1000.0 - last_pain_msg > 4.0:
				last_pain_msg = Time.get_ticks_msec() / 1000.0
				world.log_msg("Mosca: ¡ay! chocó con una pared (dolor)")
			pain_events += 1
			if learn_enabled:
				# APRENDE: cuanto más a la vista estaba la pared (cercanía) mejor asocia el cue con el dolor.
				var cue := maxf(prox_c, maxf(prox_l, prox_r))
				wall_fear = minf(1.5, wall_fear + 0.12 + 0.2 * cue)
				if pain_events % 5 == 0:
					_save_learning()
			brain.punish()
			if bump_t <= 0.0:
				bump_dir = -pain_side
				bump_turn = bump_dir * 0.9
				bump_t = 1.2
			break
	contact_t = contact_t + dt if touched else 0.0
	if contact_t > 0.5 and back_t <= 0.0:
		# pegada a la pared: dolor fuerte, retrocede y gira hacia afuera (a lo largo de la normal)
		contact_t = 0.0
		back_t = 0.9
		var away := atan2(-wall_n.x, -wall_n.z)
		bump_turn = wrapf(away - rotation.y, -PI, PI)
		bump_t = 1.5
		pain = 1.0

	# ================= 4) COMER =================
	for f in fruits:
		var fn := f as Node3D
		if global_position.distance_to(fn.global_position) < 1.5:
			energy = minf(100.0, energy + 35.0)
			eaten += 1
			brain.reward()                # dopamina: refuerza el olor que acababa de oler
			world.log_msg("Mosca: comió fruta, la dopamina refuerza el olor")
			world.place_fruit(fn)         # la fruta reaparece en otro sitio
			break
	# Estar cerca de un peligro durante >1 s "castiga" y refuerza la vía de evitar
	if near < 2.5:
		pun_t += dt
		if pun_t > 1.0:
			pun_t = 0.0
			brain.punish()


## Muerte: se registra, renace en un punto aleatorio y reinicia la actividad (pero NO los pesos
## sinápticos: lo aprendido se conserva entre vidas).
func die(why: String) -> void:
	if immortal:
		return
	world.log_msg("Mosca murió por %s (gen %d)" % [why, gen])
	world.flash_death(why)
	gen += 1
	var p: Vector3 = world.land_spot(func(_x, _z, h): return h < 10.0)
	global_position = p + Vector3(0, 2, 0)
	velocity = Vector3.ZERO
	rotation.y = randf() * TAU
	energy = 70.0
	eaten = 0
	age = 0.0
	bump_t = 0.0
	brain.reset()
