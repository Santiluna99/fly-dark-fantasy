extends Node
var m: Node
var t := 0.0
var nxt := 2.0
var deaths := 0
func _ready() -> void:
	m = (load("res://main.tscn") as PackedScene).instantiate(); add_child(m)
	Engine.time_scale = 3.0
func _process(dt: float) -> void:
	t += dt
	if t > nxt:
		nxt += 1.5
		var ms := get_tree().get_nodes_in_group("mobs")
		if ms.size() > 3:
			var a = ms[randi() % ms.size()]
			if a.alive:
				a.damage(3.0, null)
			var b = ms[randi() % ms.size()]
			if b.alive and randf() < 0.5:
				b.damage(9999.0, null); deaths += 1
	if t > 40.0:
		var alive := 0
		var anim_ok := 0
		for o in get_tree().get_nodes_in_group("mobs"):
			if o.alive: alive += 1
			if o.anim: anim_ok += 1
		print("SOAK5_OK muertes=", deaths, " vivos=", alive, " con_anim=", anim_ok)
		get_tree().quit()
