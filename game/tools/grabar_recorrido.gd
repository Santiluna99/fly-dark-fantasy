# Hollowfly - Copyright (C) 2026 Santiluna99
# Software libre bajo la GNU GPL v3 (ver LICENSE y NOTICE).
extends Node
## Graba el recorrido de la mosca alternando 3ª y 1ª persona. Uso: godot --write-movie out.avi --fixed-fps 30 -- <frames>
var main: Node
var fr := 0
var total := 1800
var started := false
var visited := {}
var toured := 0
var guiar := false
const CUTS := [[0.0, 1], [9.0, 0], [15.0, 1], [27.0, 0], [33.0, 1], [45.0, 0], [51.0, 1]]
func _ready() -> void:
	seed(4242)
	var ua := OS.get_cmdline_user_args()
	if ua.size() > 0: total = int(ua[0])
	guiar = "--guiar" in ua
	main = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(main)
	main.show_fps = false
func _process(_dt: float) -> void:
	fr += 1
	if fr == 20 and not started:
		started = true
		_setup()
	if started:
		var t := float(fr - 20) / 30.0
		for c in CUTS:
			if t >= c[0] and main.mode != c[1] and main.mode != 2:
				pass
		var want := 1
		for c in CUTS:
			if t >= c[0]: want = c[1]
		if main.mode != want:
			main.mode = want
	if started:
		if guiar: _steer(_dt)
		else: _count(_dt)
		var tt := float(fr - 20) / 30.0
		if tt > 30.0 and not _tarde:
			_tarde = true
			main.dn.set_preset(2)
	if fr >= total + 20:
		print("REC_FIN mobs_visitados=", toured, " frames=", fr, " muertes=", main.fly.gen - 1, " cerebro=", main.fly.real_brain.status, " frutas=", main.fly.eaten, " pos_fly=", main.fly.global_position)
		get_tree().quit()
var _tarde := false
func _count(_dt: float) -> void:
	for m in get_tree().get_nodes_in_group("mobs"):
		if m.alive and not visited.has(m) and m.global_position.distance_to(main.fly.global_position) < 9.0:
			visited[m] = true; toured += 1

## Guía a la mosca de mob en mob (para que se vean durante el recorrido); el movimiento sigue siendo el de la mosca.
func _steer(dt: float) -> void:
	var fly = main.fly
	var best = null
	var bd := 1e9
	for m in get_tree().get_nodes_in_group("mobs"):
		if not m.alive or visited.has(m): continue
		var d: float = m.global_position.distance_to(fly.global_position)
		if d < 9.0:
			visited[m] = true; toured += 1
			continue
		if d < bd:
			bd = d; best = m
	if best == null:
		visited.clear()
		return
	var rel: Vector3 = best.global_position - fly.global_position
	var yaw := atan2(-rel.x, -rel.z)
	fly.rotation.y = lerp_angle(fly.rotation.y, yaw, 1.0 - exp(-2.2 * dt))


func _setup() -> void:
	var fly = main.fly
	fly.immortal = true
	fly.energy = 100.0
	main.dn.set_preset(1)
	main.dn.auto = false
	# punto de inicio: tierra con más mobs en 60 m (para que se vean durante el recorrido)
	var best := Vector3(0, 6, 34)
	var bs := -1
	for i in 250:
		var p: Vector3 = main.land_spot(func(_x, _z, h): return h < 12.0 and h > 1.0)
		var c := 0
		for m in get_tree().get_nodes_in_group("mobs"):
			if m.alive and m.global_position.distance_to(p) < 45.0: c += 1
		var fr_near := 0
		for f in get_tree().get_nodes_in_group("fruit"):
			if f.global_position.distance_to(p) < 40.0: fr_near += 1
		if fr_near == 0: c = 0
		if c > bs:
			bs = c; best = p
	fly.global_position = best + Vector3(0, 2, 0)
	fly.rotation.y = randf() * TAU
	main.foc = fly
	main.cam_foc = null
	print("REC_INICIO pos=", best, " mobs_cerca=", bs, " cerebro=", fly.real_brain.status)
	Engine.time_scale = 1.8
