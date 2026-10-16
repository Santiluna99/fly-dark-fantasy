# Hollowfly - Copyright (C) 2026 Santiluna99
# Software libre bajo la GNU GPL v3 (ver LICENSE y NOTICE).
extends Node
var main: Node
var t := 0.0
var contact := 0
var ticks := 0
var streak := 0
var longest := 0
var long_streaks := 0
var episodes := 0
var last_blk := -1
func _ready() -> void:
	seed(int(OS.get_cmdline_user_args()[0]))
	main = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(main)
	Engine.time_scale = 1.0
	main.fly.real_brain.start(9009)
	var pt := int(OS.get_cmdline_user_args()[2])
	main.fly.persist_learning = false
	main.fly.learn_enabled = (OS.get_cmdline_user_args()[1] == "1")
	main.fly.real_brain.start(pt)
func _physics_process(dt: float) -> void:
	t += dt
	if t < 3.0: return
	var fly = main.fly
	fly.immortal = true
	fly.persist_learning = false
	if OS.get_cmdline_user_args().size() > 1: fly.learn_enabled = (OS.get_cmdline_user_args()[1] == "1")
	fly.energy = 100.0
	ticks += 1
	var touching := false
	for i in fly.get_slide_collision_count():
		if absf(fly.get_slide_collision(i).get_normal().y) < 0.7: touching = true
	if touching:
		contact += 1
		if streak == 0: episodes += 1
		streak += 1
	else:
		if streak > 60: long_streaks += 1
		streak = 0
	longest = maxi(longest, streak)
	if int(t) % 60 == 0 and int(t) != last_blk:
		last_blk = int(t); print("BLK t=", last_blk, " contacto%=", snappedf(100.0 * contact / ticks, 0.1), " dolores=", fly.pain_events, " miedo=", snappedf(fly.wall_fear, 0.01))
	if t > 183.0:
		print("PEGADA contacto=", snappedf(100.0 * contact / ticks, 0.1), "% episodios=", episodes, " racha_mas_larga_s=", snappedf(longest / 60.0, 0.1), " rachas_mayores_1s=", long_streaks, " frutas=", fly.eaten)
		get_tree().quit()
