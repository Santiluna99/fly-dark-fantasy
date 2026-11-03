# Hollowfly - Copyright (C) 2026 Santiluna99
# Software libre bajo la GNU GPL v3 (ver LICENSE y NOTICE).
extends Node
## Dosis-respuesta en tiempo real con el cerebro real: velocidad media y giro por nivel de cantidad. Uso: godot --headless res://dosetest.tscn -- <droga> <semilla>
var main: Node
var fly
var t := 0.0
var live_t := -1.0
var drug_id := "alcohol"
const LEVELS := [0.0, 0.2, 0.6, 1.0]
const RAMP := 7.0
const MEAS := 22.0
var acc := {}
var last_pos := Vector3.ZERO
var last_rot := 0.0
var stage := -1
func _ready() -> void:
	var ua := OS.get_cmdline_user_args()
	if ua.size() > 0: drug_id = ua[0]
	seed(int(ua[1]) if ua.size() > 1 else 5)
	main = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(main)
	fly = main.fly
	fly.persist_learning = false
	fly.immortal = true
	main.dn.set_preset(1); main.dn.auto = false
func _physics_process(dt: float) -> void:
	if live_t < 0.0:
		if fly.real_brain.live:
			live_t = t; last_pos = fly.global_position; last_rot = fly.rotation.y
		t += dt
		return
	t += dt
	var n := t - live_t
	fly.energy = 100.0
	var st := int(n / (RAMP + MEAS))
	if st >= LEVELS.size():
		for k in acc:
			var a: Array = acc[k]
			print("DOSE_RES %s nivel=%.1f vel=%.2f m/s giro=%.2f rad/s (%.0f s)" % [drug_id, LEVELS[k], a[0] / a[2], a[1] / a[2], a[2]])
		fly.drug.remove()
		get_tree().quit()
		return
	if st != stage:
		stage = st
		if LEVELS[st] > 0.0: fly.drug.apply(drug_id, LEVELS[st], 0.0)
	var local := n - st * (RAMP + MEAS)
	if local > RAMP:
		if not acc.has(st): acc[st] = [0.0, 0.0, 0.0]
		var d: Vector3 = fly.global_position - last_pos
		acc[st][0] += Vector2(d.x, d.z).length()
		acc[st][1] += absf(angle_difference(last_rot, fly.rotation.y))
		acc[st][2] += dt
	last_pos = fly.global_position
	last_rot = fly.rotation.y
