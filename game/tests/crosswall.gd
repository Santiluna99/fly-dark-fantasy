# Hollowfly - Copyright (C) 2026 Santiluna99
# Software libre bajo la GNU GPL v3 (ver LICENSE y NOTICE).
extends Node
var main: Node
var t := 0.0
var cases: Array = []
func _ready() -> void:
	seed(3)
	main = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(main)
func _physics_process(dt: float) -> void:
	t += dt
	main.fly.immortal = true
	main.fly.energy = 100.0
	main.fly.global_position = Vector3(-110, 20, -110)
	main.fly.set_physics_process(false)
	if cases.is_empty() and t > 3.0:
		var ss: PhysicsDirectSpaceState3D = main.get_world_3d().direct_space_state
		var mobs: Array = get_tree().get_nodes_in_group("mobs")
		var k := 0
		for zz in [-30, -15, -5, 5, 15, 30, -45, 45]:
			var r := ss.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(60, 4, zz), Vector3(0, 4, zz), 1))
			if r.is_empty() or absf((r.normal as Vector3).y) > 0.5: continue
			var dirv: Vector3 = -(r.normal as Vector3); dirv.y = 0; dirv = dirv.normalized()
			var m = mobs[k]; k += 1
			m.faction = 2
			m.home = r.position - dirv * 6.0
			m.global_position = r.position - dirv * 5.0 + Vector3(0, 1.0, 0)
			cases.append([m, r.position, dirv])
	for c in cases:
		var m = c[0]
		m.wp = c[1] + c[2] * 10.0
		m.tgt = null
		m.hp = m.max_hp
	if t > 33.0:
		var crossed := 0
		var minside := 0.0
		for c in cases:
			var s: float = ((c[0].global_position - c[1]) as Vector3).dot(c[2])
			if s > 1.5: crossed += 1
		print("ATRAVESARON ", crossed, " de ", cases.size(), " muros")
		get_tree().quit()
