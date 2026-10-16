# Hollowfly - Copyright (C) 2026 Santiluna99
# Software libre bajo la GNU GPL v3 (ver LICENSE y NOTICE).
extends Node
var main: Node
var t := 0.0
var stage := 0
var contact := 0
var ticks := 0
var wallp := Vector3.ZERO
var mind := 1e9
var near3 := 0
var episodes := 0
var was := false
func _ready() -> void:
	seed(int(OS.get_cmdline_user_args()[0]))
	main = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(main)
	Engine.time_scale = 1.0
	main.fly.persist_learning = false
	main.fly.real_brain.start(int(OS.get_cmdline_user_args()[1]))
func _physics_process(dt: float) -> void:
	t += dt
	if t < 3.0: return
	var fly = main.fly
	if stage == 0:
		stage = 1
		fly.immortal = true
		var ss: PhysicsDirectSpaceState3D = fly.get_world_3d().direct_space_state
		var r := ss.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(70, 6, 0), Vector3(0, 6, 0), 1))
		wallp = r.position
		var dirv: Vector3 = -(r.normal as Vector3); dirv.y = 0; dirv = dirv.normalized()
		fly.fruits = get_tree().get_nodes_in_group("fruit")
		for f in fly.fruits: f.global_position = Vector3(0, -400, 0)
		(fly.fruits[0] as Node3D).global_position = wallp + dirv * 6.0 + Vector3(0, 1.5, 0)
		fly.global_position = wallp - dirv * 9.0 + Vector3(0, 1.0, 0)
		fly.rotation.y = atan2(-dirv.x, -dirv.z) + randf_range(-0.5, 0.5)
		return
	fly.energy = 100.0
	ticks += 1
	var touching := false
	for i in fly.get_slide_collision_count():
		if absf(fly.get_slide_collision(i).get_normal().y) < 0.7: touching = true
	if touching: contact += 1
	if touching and not was: episodes += 1
	was = touching
	if fly.global_position.distance_to(wallp) < 3.5: near3 += 1
	mind = minf(mind, fly.global_position.distance_to(wallp))
	if t > 93.0:
		print("PEGADA cerca3.5m=", snappedf(100.0 * near3 / ticks, 0.1), "% episodios_choque=", episodes, " contacto=", snappedf(100.0 * contact / ticks, 0.1), "% del tiempo  | frutas_comidas=", fly.eaten, " dist_final_a_pared=", snappedf(fly.global_position.distance_to(wallp), 0.1))
		get_tree().quit()
