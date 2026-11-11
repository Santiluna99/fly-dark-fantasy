# Hollowfly - Copyright (C) 2026 Santiluna99
# Software libre bajo la GNU GPL v3 (ver LICENSE y NOTICE).
extends Node
## Prueba de lesiones en tiempo real con el cerebro real: tres tramos (sana / lesionada / restaurada) y, en cada uno,
## velocidad, giro, orden de giro del cerebro mientras huele fruta sin amenazas cerca, actividad total y frutas comidas.
## Uso: godot --headless res://tests/lesiontest.tscn -- <lesion[+lesion...]> <seed>
var main: Node
var fly
var t := 0.0
var live_t := -1.0
var ids: Array = ["orn_l"]
var seg := {}
var last_pos := Vector3.ZERO
var last_rot := 0.0
var phase := 0
var eaten0 := 0
const T_BASE := 30.0
const T_LES := 40.0
const T_POST := 30.0
const NAMES := ["sana", "lesion", "restaurada"]
func _ready() -> void:
	var ua := OS.get_cmdline_user_args()
	if ua.size() > 0: ids = Array(ua[0].split("+"))
	seed(int(ua[1]) if ua.size() > 1 else 5)
	main = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(main)
	fly = main.fly
	fly.persist_learning = false
	fly.immortal = true
	main.dn.set_preset(1); main.dn.auto = false
func _acc(dt: float) -> void:
	var k: String = NAMES[phase]
	if not seg.has(k): seg[k] = {"d": 0.0, "t": 0.0, "rot": 0.0, "turn": 0.0, "smell_t": 0.0, "smell_turn": 0.0, "hz": 0.0, "fwd": 0.0, "eat": 0}
	var s: Dictionary = seg[k]
	var d: Vector3 = fly.global_position - last_pos
	var rb = fly.real_brain
	s.d += Vector2(d.x, d.z).length(); s.t += dt
	s.rot += absf(angle_difference(last_rot, fly.rotation.y))
	s.turn += rb.out_turn * dt; s.hz += rb.hz * dt; s.fwd += rb.out_fwd * dt
	# solo cuenta cuando huele fruta y NO hay amenaza (un mob o el dolor de un choque también hacen girar)
	if maxf(rb.sense[0], rb.sense[1]) > 0.1 and maxf(rb.sense[2], rb.sense[3]) < 0.05:
		s.smell_t += dt; s.smell_turn += rb.out_turn * dt
	s.eat = fly.eaten - eaten0
func _physics_process(dt: float) -> void:
	if live_t < 0.0:
		if fly.real_brain.live:
			live_t = t
			last_pos = fly.global_position; last_rot = fly.rotation.y
			print("LT_LIVE")
		t += dt
		return
	t += dt
	var n := t - live_t
	_acc(dt)
	last_pos = fly.global_position; last_rot = fly.rotation.y
	fly.energy = 60.0
	if phase == 0 and n > T_BASE:
		phase = 1; eaten0 = fly.eaten
		fly.lesion.apply(ids)
		print("LT aplica ", ids)
	elif phase == 1 and n > T_BASE + T_LES:
		print("LT en lesion: enviado=", fly.real_brain.lesion_ids, " version mapa=", fly.real_brain.map_v, " casillas lesionadas=", _count(fly.real_brain.les_mask))
		phase = 2; eaten0 = fly.eaten
		fly.lesion.clear()
		print("LT restaura")
	elif phase == 2 and n > T_BASE + T_LES + T_POST:
		for k in NAMES:
			var s: Dictionary = seg[k]
			print("LT_RES %-10s vel=%.2f m/s  giro=%.2f rad/s  orden_giro=%+.2f  oliendo sin amenaza(%2.0f s): orden_giro=%+.2f  avance=%.2f  disparos/s=%6.0f  frutas=%d" % [
				k, s.d / s.t, s.rot / s.t, s.turn / s.t, s.smell_t, s.smell_turn / maxf(0.01, s.smell_t), s.fwd / s.t, s.hz / s.t, s.eat])
		print("LT_FIN lesion=", fly.lesion.ids, " casillas lesionadas=", _count(fly.real_brain.les_mask))
		get_tree().quit()
func _count(m: PackedByteArray) -> int:
	var c := 0
	for v in m:
		if v > 0: c += 1
	return c
