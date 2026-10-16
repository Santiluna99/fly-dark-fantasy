# Hollowfly - Copyright (C) 2026 Santiluna99
# Software libre bajo la GNU GPL v3 (ver LICENSE y NOTICE).
extends Node
## Sigue a cada mob con la cámara (primera y tercera persona) y mide cuánto se sacude:
## giro total de la cámara por segundo y número de cambios bruscos de sentido.
var main: Node
var t := 0.0
var mobs: Array = []
var mi := 0
var seg := 0.0
var prev_yaw := 0.0
var prev_d := 0.0
var turn := 0.0
var flips := 0
var jumps := 0
var prev_pos := Vector3.ZERO
var rows: Array = []
const SEG := 4.0
func _ready() -> void:
	seed(int(OS.get_cmdline_user_args()[0]) if OS.get_cmdline_user_args().size() > 0 else 1)
	main = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(main)
	main.fly.persist_learning = false
func _process(dt: float) -> void:
	t += dt
	if t < 3.0: return
	if mobs.is_empty():
		mobs = get_tree().get_nodes_in_group("mobs")
		_start()
		return
	var cam: Camera3D = main.cam
	var y := cam.global_rotation.y
	var d := wrapf(y - prev_yaw, -PI, PI)
	turn += absf(d)
	if absf(d) > 0.02 and absf(prev_d) > 0.02 and signf(d) != signf(prev_d): flips += 1
	if cam.global_position.distance_to(prev_pos) > 2.0: jumps += 1
	prev_d = d
	prev_yaw = y
	prev_pos = cam.global_position
	seg += dt
	if seg >= SEG:
		var m: Mob = mobs[mi / 2]
		var tg: Mob = m.tgt
		rows.append([turn / SEG, flips, jumps, int(main.mode), m.variant, m.mob_name, m.alive, snappedf(m.global_position.distance_to(tg.global_position), 0.1) if tg else -1.0])
		mi += 1
		if mi >= mobs.size() * 2:
			rows.sort_custom(func(a, b): return a[0] > b[0])
			for r in rows.slice(0, 25):
				print("giro=%.2f rad/s cambios=%d saltos=%d modo=%d %s (%s) vivo=%s dist_obj=%s" % r)
			get_tree().quit()
			return
		_start()
func _start() -> void:
	var m: Mob = mobs[mi / 2]
	main.foc = m
	main.mode = mi % 2
	seg = 0.0; turn = 0.0; flips = 0; jumps = 0; prev_d = 0.0
	prev_yaw = main.cam.global_rotation.y
	prev_pos = main.cam.global_position
