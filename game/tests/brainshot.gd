# Hollowfly - Copyright (C) 2026 Santiluna99
# Software libre bajo la GNU GPL v3 (ver LICENSE y NOTICE).
extends Node
## (herramienta) Capturas del panel "cerebro en vivo" y del de lesiones con el cerebro real.
## Uso: godot res://tests/brainshot.tscn -- <carpeta salida>
var main: Node
var fly
var t := 0.0
var live_t := -1.0
var step := 0
var out := "/tmp"
var plan := []
func _ready() -> void:
	var ua := OS.get_cmdline_user_args()
	if ua.size() > 0: out = ua[0]
	seed(7)
	main = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(main)
	fly = main.fly
	fly.persist_learning = false
	fly.immortal = true
	main.dn.set_preset(1); main.dn.auto = false
	plan = [
		[3.0, func(): main._toggle_brain()],
		[4.0, func(): _shot("0_barra")],
		[9.0, func(): _shot("1_sano")],
		[9.5, func(): main._toggle_lesions()],
		[10.5, func(): _shot("2_panel_lesiones")],
		[11.0, func():
			main.lesion_panel._btns[0].button_pressed = true
			main.lesion_panel._apply()],
		[19.0, func(): _shot("3_antena_izq")],
		[19.5, func(): fly.lesion.apply(["dn"])],
		[26.0, func(): _shot("4_via_cuerpo")],
		[26.5, func():
			fly.lesion.apply(["loom_l", "loom_r"])
			fly.drug.apply("cafeina", 0.8, 0.0)],
		[35.0, func(): _shot("5_amenaza_y_cafeina")],
		[35.5, func():
			fly.drug.remove()
			fly.lesion.clear()
			main._toggle_brain()],
		[40.0, func(): _shot("6_sin_panel")],
		[40.5, func(): get_tree().quit()],
	]
func _shot(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [out, name])
	print("SHOT ", name, " hz=", fly.real_brain.hz, " lv=", fly.real_brain.map_v, " les=", fly.real_brain.lesion_ids, " fwd=", fly.real_brain.out_fwd)
func _process(dt: float) -> void:
	if live_t < 0.0:
		if fly.real_brain.live:
			live_t = 0.0
		return
	t += dt
	fly.energy = 60.0
	while step < plan.size() and t >= plan[step][0]:
		(plan[step][1] as Callable).call()
		step += 1
