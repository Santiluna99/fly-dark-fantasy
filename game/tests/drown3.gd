# Hollowfly - Copyright (C) 2026 Santiluna99
# Software libre bajo la GNU GPL v3 (ver LICENSE y NOTICE).
extends Node
var main: Node
var t := 0.0
func _ready() -> void:
	seed(4242)
	main = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(main)
	Engine.time_scale = 4.0
func _physics_process(dt: float) -> void:
	t += dt
	if t > 240.0:
		print("AHOGADOS_en_", int(t), "s_simulados=", main.drowned)
		get_tree().quit()
