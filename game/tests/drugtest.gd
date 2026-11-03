# Hollowfly - Copyright (C) 2026 Santiluna99
# Software libre bajo la GNU GPL v3 (ver LICENSE y NOTICE).
extends Node
## Prueba de drogas en tiempo real con el cerebro real: velocidad media de la mosca por tramos (sin droga / con droga / tras quitarla).
## Uso: godot --headless res://drugtest.tscn -- <droga> <dosis> <seed>
var main: Node
var fly
var t := 0.0
var live_t := -1.0
var drug_id := "anfetamina"
var dose := 0.8
var seg := {}
var last_pos := Vector3.ZERO
var phase := 0
var log_next := 0.0
var rot_acc := 0.0
var last_rot := 0.0
func _ready() -> void:
	var ua := OS.get_cmdline_user_args()
	if ua.size() > 0: drug_id = ua[0]
	if ua.size() > 1: dose = float(ua[1])
	seed(int(ua[2]) if ua.size() > 2 else 5)
	main = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(main)
	fly = main.fly
	fly.persist_learning = false
	fly.immortal = true
	main.dn.set_preset(1); main.dn.auto = false
func _acc(name: String, dt: float) -> void:
	if not seg.has(name): seg[name] = [0.0, 0.0, 0.0, 0.0]
	var d: Vector3 = fly.global_position - last_pos
	seg[name][0] += Vector2(d.x, d.z).length()
	seg[name][1] += dt
	seg[name][2] += absf(angle_difference(last_rot, fly.rotation.y))
	seg[name][3] += fly.brain.rate[77]
func _physics_process(dt: float) -> void:
	if live_t < 0.0:
		if fly.real_brain.live:
			live_t = t
			last_pos = fly.global_position
			last_rot = fly.rotation.y
			fly.energy = 100.0
			print("DT_LIVE t=", t)
		t += dt
		return
	t += dt
	var n := t - live_t
	_acc(["base", "droga", "salida", "post"][phase] if phase < 4 else "post", dt)
	last_pos = fly.global_position
	last_rot = fly.rotation.y
	fly.energy = 100.0
	if n > log_next:
		log_next += 5.0
		print("DT t=%3d fase=%d droga=%s nivel=%.2f vel_media_seg=%.2f" % [int(n), phase, fly.drug.phase, fly.drug.level, fly.velocity.length()])
	if phase == 0 and n > 25.0:
		phase = 1
		fly.drug.apply(drug_id, dose, 0.0)       # hasta quitarla
		print("DT aplica ", drug_id, " dosis ", dose)
	elif phase == 1 and n > 25.0 + 6.0 + 25.0:
		phase = 2
		fly.drug.remove()
		print("DT quita (bajada rápida)")
	elif phase == 2 and n > 25.0 + 6.0 + 25.0 + 8.0:
		phase = 3
	elif phase == 3 and n > 25.0 + 6.0 + 25.0 + 8.0 + 25.0:
		for k in seg:
			var s: Array = seg[k]
			print("DT_RES %-6s vel=%.2f m/s giro=%.2f rad/s avance_cerebro=%.3f (%.0f s)" % [k, s[0] / s[1], s[2] / s[1], s[3] / maxf(1.0, s[1] * 60.0), s[1]])
		print("DT_FIN drug.phase=", fly.drug.phase, " nivel=", fly.drug.level, " sent=", fly.real_brain.drug_id, "/", fly.real_brain.drug_level)
		get_tree().quit()
