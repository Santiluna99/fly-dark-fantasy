class_name Mob extends CharacterBody3D
## Facciones: 0 Aldeano, 1 Caballero, 2 Culto, 3 Monstruo

# Colores de cada facción, sus nombres, los hechizos (daño d y coste de maná m), nombres y frases.
const FCOL := [Color(0.29, 0.49, 1.0), Color(0.72, 0.74, 0.82), Color(0.14, 0.14, 0.88), Color(0.25, 0.75, 0.25)]
const FNAME := ["Aldeano", "Caballero", "Culto", "Monstruo"]
const SPELLS := {
	"fuego": {"c": Color(1.0, 0.42, 0.16), "d": 12.0, "m": 20.0},
	"escarcha": {"c": Color(0.5, 0.9, 1.0), "d": 6.0, "m": 12.0},
	"sombra": {"c": Color(0.69, 0.38, 1.0), "d": 9.0, "m": 15.0},
	"luz": {"c": Color(1.0, 0.9, 0.54), "d": -10.0, "m": 14.0}}
const NAMES := [["Mora", "Brann", "Isolde", "Tomás"], ["Sir Alaric", "Sir Edric", "Sir Voss"],
	["Acólito Mor", "Cabra Ciega", "Hermano Beh"], ["Trasgo", "Goblin", "Gul"]]
const VNAMES := {"skeleton": "Esqueleto", "ghoul": "Necrófago", "wraith": "Espectro", "plague": "Médico de la peste"}
const VLINES := {
	"skeleton": ["Clac... clac...", "Huesos fríos.", "Sin carne no hay hambre."],
	"ghoul": ["Ñam...", "Frescos...", "Hambre vieja."],
	"wraith": ["Susurro de sombras.", "Tu nombre se apaga.", "Frío..."],
	"plague": ["Nadie se salva.", "Respira poco.", "El aire está enfermo."]}
const LINES := [
	["Otra noche de lluvia...", "¿Pan o vino?", "No mires al bosque.", "El cabrero no vuelve."],
	["Por el rey.", "El castillo resiste.", "Ese faro parece vivo."],
	["Beeeh... la luna llama.", "El cuenco está vacío.", "Bendito el laberinto."],
	["GRRR", "Hambre...", "Carne."]]

# --- Estado de cada mob ---
# world = referencia al mundo (main.gd)   faction = 0 aldeano, 1 caballero, 2 culto, 3 monstruo
# big = es un ogro gigante   hp/max_hp = vida   gold = monedas (se roban al derrotar)
# mana/spell = recurso y hechizo que lanza ("" = ninguno)   cd = enfriamiento del ataque
# talk_cd = enfriamiento para hablar   slow = segundos ralentizado por escarcha
var world
var faction := 0
var big := false
var hp := 30.0
var max_hp := 30.0
var gold := 10
var mana := 40.0
var spell := ""
var cd := 0.0
var talk_cd := 0.0
var slow := 0.0
# home = punto donde vive/reaparece   wp = destino actual del paseo   leash = radio máximo de paseo (-1 = el de su facción)
var home := Vector3.ZERO
var wp := Vector3.ZERO
var mob_name := ""
var eye_height := 1.6
var alive := true
var respawn_t := 0.0
var hit_t := 0.0
var _lod_dt := 0.0
var _water_ahead := false
var label: Label3D
# scan_t = temporizador para mirar alrededor (no cada tick)   tgt/ally/hurt = enemigo, aliado y aliado herido más cercanos
var scan_t := 0.0
var tgt: Mob
var ally: Mob
var hurt: Mob
# Partes del modelo (las crea MobModel) usadas por la animación de caminar/atacar.
var variant := "human"
var leash := -1.0
var body: Node3D
var armL: Node3D
var armR: Node3D
var legL: Node3D
var legR: Node3D
var head: Node3D
var arm_base := 0.0
var phase := 0.0
var atk_t := 0.0
var anim: AnimationPlayer   # solo para modelos .glb de Blender (lobo, búho, troll)


## ¿Son enemigas dos facciones? Los monstruos (3) atacan a todos; caballeros (1) y culto (2) se odian.
static func hostile(a: int, b: int) -> bool:
	if a == b:
		return false
	var lo := mini(a, b)
	var hi := maxi(a, b)
	return hi == 3 or (lo == 1 and hi == 2)


## Inicializa el mob: vida según facción, hechizo, nombre, capas de colisión, y construye el modelo.
func setup(w, f: int, pos: Vector3, is_big := false) -> void:
	world = w
	faction = f
	big = is_big
	position = pos
	home = pos
	wp = pos
	max_hp = 120.0 if big else [20.0, 45.0, 32.0, 28.0][f]
	hp = max_hp
	gold = randi_range(5, 30)
	eye_height = 3.4 if big else 1.6
	scan_t = randf() * 0.3
	match f:
		0: spell = "escarcha" if randf() < 0.12 else ""
		1: spell = "luz" if randf() < 0.35 else ""
		2: spell = ["sombra", "fuego", "sombra"].pick_random()
	mob_name = "Monstruo verde" if big else NAMES[f].pick_random()
	collision_layer = 2
	collision_mask = 1
	add_to_group("mobs")
	_build()


## Crea el cuerpo visual (MobModel.build), la cápsula de colisión y la etiqueta flotante de diálogo.
func _build() -> void:
	body = Node3D.new()
	body.name = "Body"
	add_child(body)
	variant = MobModel.pick_variant(faction, big)
	var rig := MobModel.build(body, world, variant, big)
	# Ajustes por variante nueva: nombre, vida y hechizo
	if VNAMES.has(variant):
		mob_name = VNAMES[variant]
	match variant:
		"skeleton": max_hp = 36.0; hp = max_hp
		"ghoul": max_hp = 40.0; hp = max_hp
		"wraith": max_hp = 24.0; hp = max_hp; spell = "sombra"
		"plague": spell = ["escarcha", "sombra"].pick_random()
	eye_height = rig["eye"]
	arm_base = rig["arm_base"]
	armL = rig["armL"]
	armR = rig["armR"]
	head = rig["head"]
	legL = rig.get("legL")
	legR = rig.get("legR")
	anim = rig.get("anim")
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = rig["r"]
	cap.height = maxf(rig["h"], rig["r"] * 2.0 + 0.1)
	cs.shape = cap
	cs.position = Vector3(0, cap.height / 2.0, 0)
	add_child(cs)
	label = Label3D.new()
	label.position = Vector3(0, rig["h"] + 0.5, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.012
	label.font_size = 28
	label.outline_size = 8
	label.no_depth_test = true
	add_child(label)


## Animación procedural: balancea piernas/brazos al caminar, rebota, levanta el brazo al atacar y mueve la cabeza.
func _animate(dt: float) -> void:
	var sp := Vector2(velocity.x, velocity.z).length()
	var k := clampf(sp / 1.5, 0.0, 1.0)
	if sp > 0.1:
		phase += dt * (4.0 + sp * 2.5)
	var prev_atk := atk_t
	atk_t = maxf(0.0, atk_t - dt)
	# Modelo de Blender: se eligen las animaciones del propio archivo (idle / walk / attack)
	if anim:
		# LOD: lejos de la cámara se congela la animación (ahorra CPU); al acercarse sigue donde estaba
		var cam := get_viewport().get_camera_3d()
		if cam and alive and global_position.distance_squared_to(cam.global_position) > 3600.0:
			if anim.is_playing(): anim.pause()
			return
		if cam and not anim.is_playing() and alive:
			anim.play(anim.current_animation if anim.current_animation != "" else "idle")
		hit_t = maxf(0.0, hit_t - dt)
		var want := "walk" if sp > 0.1 else "idle"
		if hit_t > 0.0 and anim.has_animation("hit"):
			want = "hit"
		if atk_t > 0.0:
			want = "attack"
		if not alive and anim.has_animation("death"):
			want = "death"
		if anim.has_animation(want) and (anim.current_animation != want or (want == "attack" and prev_atk <= 0.0)):
			if want == "death" or want == "hit" or want == "attack":
				anim.play(want, 0.08)
			else:
				anim.play(want, 0.25)     # mezcla suave entre idle y caminar
		anim.speed_scale = clampf(sp / 1.5, 0.6, 2.0) if want == "walk" else 1.0
		return
	var sw := sin(phase) * 0.75 * k
	body.position.y = absf(sin(phase)) * 0.05 * k
	if legL:
		legL.rotation.x = sw
		legR.rotation.x = -sw
	else:
		body.rotation.z = sin(phase) * 0.05 * k
	var swing := 0.0 if arm_base > 0.0 else 0.8
	var up := sin(clampf(atk_t / 0.4, 0.0, 1.0) * PI) * 1.6
	armL.rotation.x = arm_base - sw * swing
	armR.rotation.x = arm_base + sw * swing + up
	var t := Time.get_ticks_msec() * 0.001
	head.rotation.y = sin(t * 0.7 + float(get_instance_id() % 13)) * 0.15


## Velocidad de caminar en m/s según facción (los ogros son más lentos).
func _speed() -> float:
	return 1.8 if big else [2.0, 2.2, 1.9, 1.9][faction]


## Muestra una frase sobre la cabeza durante 3 segundos.
func say(s: String) -> void:
	label.text = s
	get_tree().create_timer(3.0).timeout.connect(func(): if label.text == s: label.text = "")


## Recibe daño (o cura si amount < 0). Al morir se oculta 10 s y reaparece; el que lo mató se queda con su oro.
func damage(amount: float, by: Mob) -> void:
	# 0) Muerto: cuenta atrás y reaparece en su casa.
	if not alive:
		return
	if amount < 0.0:
		hp = minf(max_hp, hp - amount)
		return
	hp -= amount
	hit_t = 0.45
	if hp <= 0.0:
		alive = false
		respawn_t = 10.0
		# con modelo animado se queda visible mientras cae (se oculta en _physics_process)
		visible = not (anim and anim.has_animation("death"))
		collision_layer = 0
		if by:
			by.gold += gold
			world.log_msg("%s derrotó a %s" % [by.mob_name, mob_name])


## Lanza un hechizo (Projectile) hacia el objetivo, gasta maná y activa el brazo de ataque.
func cast(target: Mob, key: String) -> void:
	mana -= SPELLS[key]["m"]
	cd = 0.75
	atk_t = 0.45
	var p := Projectile.new()
	world.add_child(p)
	p.setup(self, target.global_position + Vector3.UP, key)
	say(key.capitalize() + "!")


## Mira alrededor y guarda: enemigo más cercano (tgt), aliado más cercano (ally) y aliado herido (hurt).
func _scan() -> void:
	tgt = null
	ally = null
	hurt = null
	var td := 999.0
	var ad := 999.0
	var hd := 999.0
	for n in get_tree().get_nodes_in_group("mobs"):
		var o := n as Mob
		if o == self or not o.alive:
			continue
		var d := global_position.distance_to(o.global_position)
		if Mob.hostile(faction, o.faction):
			if d < td:
				td = d
				tgt = o
		else:
			if d < ad and (faction != 3 or o.faction == 3):
				ad = d
				ally = o
			if o.hp < o.max_hp * 0.6 and d < hd:
				hd = d
				hurt = o


## Conversación: dice una frase y a veces comercia (transfiere monedas) con el aliado cercano.
func _interact() -> void:
	talk_cd = 6.0
	ally.talk_cd = 6.0
	say((VLINES[variant] if VLINES.has(variant) else LINES[faction]).pick_random())
	if faction != 3 and randf() < 0.5 and gold > 3:
		var a := mini(gold, randi_range(2, 6))
		gold -= a
		ally.gold += a
		if randf() < 0.5:
			world.log_msg("%s comercia con %s (%d monedas)" % [mob_name, ally.mob_name, a])


## CEREBRO DEL MOB. Se ejecuta 60 veces por segundo. Ver los pasos numerados dentro.
func _physics_process(dt: float) -> void:
	if not alive:
		respawn_t -= dt
		if anim and visible:
			_animate(dt)
			if respawn_t < 6.5:        # ya cayó y yació unos segundos: desaparece
				visible = false
		if respawn_t <= 0.0:
			alive = true
			if anim:
				anim.play("idle")
			hp = max_hp
			mana = 40.0
			# renace en un punto al azar del mapa (en tierra firme, lejos de la orilla) y se queda a vivir ahí
			var rp: Vector3 = world.safe_spot(func(_x, _z, h): return h > 1.0)
			home = rp
			wp = rp
			velocity = Vector3.ZERO
			global_position = rp + Vector3(0, 0.5, 0)
			visible = true
			collision_layer = 2
		return
	# Caer al agua mata: si los pies quedan por debajo de la superficie, se ahoga
	if global_position.y < world.WATER - 0.3:
		world.drowned += 1
		world.log_msg("%s se ahogó" % mob_name)
		damage(99999.0, null)
		return
	# LOD: los mobs lejos de la cámara piensan 1 de cada 6 ticks (con 6 veces el paso) -> mucho menos CPU
	var lod := 1.0
	var cam := get_viewport().get_camera_3d()
	var cd2 := global_position.distance_squared_to(cam.global_position) if cam else 0.0
	if cd2 > 625.0:                                  # más de 25 m: baja la frecuencia (3 ticks hasta 40 m, 6 más allá)
		var every := 6 if cd2 > 1600.0 else 3
		_lod_dt += dt
		if (Engine.get_physics_frames() + get_instance_id()) % every != 0:
			return
		dt = _lod_dt
		_lod_dt = 0.0
		lod = float(every)
	# 1) Temporizadores: enfriamientos, recuperación de maná y chequeo periódico del entorno (cada 0,25 s).
	cd -= dt
	talk_cd -= dt
	slow -= dt
	mana = minf(60.0, mana + 2.4 * dt)
	scan_t -= dt
	if scan_t <= 0.0:
		scan_t = 0.25 + randf() * 0.1      # desfasado para que no escaneen todos en el mismo tick
		_scan()
	# 2) Decidir qué hacer. "desired" = dirección en la que quiere moverse.
	var sight := 16.0 if faction == 3 else 14.0
	var desired := Vector3.ZERO
	var d := 999.0
	if tgt and tgt.alive:
		d = global_position.distance_to(tgt.global_position)
	if d < sight:
		# Enemigo a la vista: huye si es aldeano sin magia o está casi muerto; si no, ataca con magia o cuerpo a cuerpo.
		var flee := (faction == 0 and spell == "") or (hp < max_hp * 0.3 and faction != 3)
		if flee:
			desired = (global_position - tgt.global_position).normalized() * 1.3
		else:
			var can_cast: bool = spell != "" and spell != "luz" and mana >= SPELLS[spell]["m"]
			if can_cast and d < 16.0 and cd <= 0.0:
				cast(tgt, spell)
			elif d > 2.0:
				desired = (tgt.global_position - global_position).normalized() * 1.15
			elif cd <= 0.0:
				tgt.damage(12.0 if big else (7.0 if faction == 1 else 4.0), self)
				cd = 0.5
				atk_t = 0.4
	# Sin enemigos: los sanadores curan a un aliado herido.
	elif spell == "luz" and hurt and hurt.alive and mana >= 14.0 and cd <= 0.0 \
			and global_position.distance_to(hurt.global_position) < 16.0:
		cast(hurt, "luz")
	# Si hay un aliado muy cerca: habla/comercia.
	elif ally and ally.alive and talk_cd <= 0.0 and global_position.distance_to(ally.global_position) < 3.0:
		_interact()
	else:
		# Si no hay nada que hacer: pasea hacia puntos aleatorios cerca de su casa.
		if global_position.distance_to(wp) < 1.5 or randf() < 0.004:
			var r := leash if leash > 0.0 else (10.0 if faction == 0 else (14.0 if faction == 1 else 48.0))
			wp = home + Vector3(randf_range(-r, r), 0, randf_range(-r, r))
		desired = wp - global_position
		desired.y = 0.0
		desired = desired.normalized() * 0.6
	desired.y = 0.0
	# 3) No meterse al agua: si el siguiente paso es agua, se detiene y vuelve a casa.
	if desired.length() > 0.01 and (Engine.get_physics_frames() + get_instance_id()) % 4 == 0:
		_water_ahead = world.is_water(global_position + desired.normalized() * 1.5)   # caro: se comprueba cada 4 ticks
	if _water_ahead and desired.length() > 0.01:
		desired = Vector3.ZERO
		wp = home
		_water_ahead = false
	# 4) Moverse. move_and_slide() hace que choque contra muros, árboles y rocas (son sólidos).
	var v := desired * _speed() * (0.4 if slow > 0.0 else 1.0)
	velocity.x = v.x * lod       # lejos: se mueve 6 veces más por paso para compensar los ticks saltados
	velocity.z = v.z * lod
	if lod > 4.0:
		# Lejos de la cámara no hace falta el motor de física (move_and_slide es lo más caro del juego):
		# se coloca sobre el terreno directamente, cada 6 ticks, a 6 veces el paso.
		velocity.y = 0.0
		var np := global_position + Vector3(velocity.x, 0.0, velocity.z) * get_physics_process_delta_time()
		np.y = world.height_at(np.x, np.z) + 0.05
		if np.y > world.WATER + 0.3 or global_position.y < world.WATER:
			# un rayo comprueba que no atraviese muros, torres, árboles ni rocas
			var blocked := false
			var ssp := get_world_3d().direct_space_state
			for hy in [0.3, 1.0, 1.9]:
				var rq := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, hy, 0), np + Vector3(0, hy, 0), 1, [get_rid()])
				var hit := ssp.intersect_ray(rq)
				if not hit.is_empty() and absf((hit["normal"] as Vector3).y) < 0.7:
					blocked = true
					break
			if not blocked:
				global_position = np
			else:
				wp = home                  # chocó con algo sólido: elige otro rumbo
	else:
		velocity.y -= 25.0 * dt
		move_and_slide()
	_animate(dt)
	if v.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(-v.x, -v.z), 8.0 * dt)
	# 5) Peligro para la mosca: tiene una pequeña probabilidad de aplastarla si está pegada a él.
	var f = world.fly
	if f and f.alive and faction != 3 and randf() < 0.0004 \
			and global_position.distance_to(f.global_position) < 2.0:
		f.die("un manotazo de " + mob_name)
