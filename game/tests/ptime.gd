# Hollowfly - Copyright (C) 2026 Santiluna99
# Software libre bajo la GNU GPL v3 (ver LICENSE y NOTICE).
extends Node
var main: Node
var t := 0.0
var xs: Array = []
var worst := 0.0
var wi := ""
func _ready() -> void:
	seed(int(OS.get_cmdline_user_args()[0]))
	main = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(main)
	main.fly.persist_learning = false
	var md := OS.get_cmdline_user_args()[2]
	if md == "nomobs":
		for m in get_tree().get_nodes_in_group("mobs"): m.set_physics_process(false)
	if md == "nofly": main.fly.set_physics_process(false)
	main.fly.real_brain.start(int(OS.get_cmdline_user_args()[1]))
func _physics_process(dt: float) -> void:
	t += dt
	if t < 5.0: return
	if t < 5.1 and OS.get_cmdline_user_args()[2] == "nomobs":
		for m in get_tree().get_nodes_in_group("mobs"): m.set_physics_process(false)
	main.fly.immortal = true
	main.fly.energy = 100.0
	var v := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	xs.append(v)
	if v > worst:
		worst = v
		wi = "t=%.1f pos=%s pain=%.1f" % [t, main.fly.global_position.round(), main.fly.pain]
	if t > 45.0:
		xs.sort()
		var n := xs.size()
		print("FISICA_ms p50=", snappedf(xs[n / 2], 0.01), " p99=", snappedf(xs[int(n * 0.99)], 0.01), " max=", snappedf(xs[n - 1], 0.01), " en ", wi, " n=", n, " mobs=", get_tree().get_nodes_in_group("mobs").size())
		get_tree().quit()
