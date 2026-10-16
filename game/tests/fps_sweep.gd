extends Node
var main: Node
var pts: Array = []
var i := 0
var fr := 0
var acc := 0.0
var res: Array = []
func _ready() -> void:
	seed(5)
	main = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(main)
	main.fly.immortal = true
	for k in 36:
		var p: Vector3 = main.land_spot(func(x, z, h): return true)
		pts.append(p)
func _process(dt: float) -> void:
	fr += 1
	if fr < 10: return
	var c := fr - 10
	var idx := c / 7
	if idx >= pts.size() * 2:
		res.sort_custom(func(a, b): return a[0] > b[0])
		for r in res.slice(0, 8): print("LENTO ", snappedf(r[0] * 1000.0, 1), "ms modo=", r[1], " pos=", r[2], " bioma=", r[3], " dist_agua=", r[4])
		var s := 0.0
		for r in res: s += r[0]
		print("MEDIA_ms=", snappedf(s / res.size() * 1000.0, 1), " N=", res.size())
		get_tree().quit()
		return
	var pi := idx / 2
	var md := idx % 2
	main.mode = md
	main.fly.global_position = pts[pi] + Vector3(0, 2.0, 0)
	main.fly.rotation.y = float(c % 7) * 0.0 + pi * 0.9
	main.fly.velocity = Vector3.ZERO
	if c % 7 >= 3: acc += dt
	if c % 7 == 6:
		res.append([acc / 4.0, "3a" if md == 0 else "1a", pts[pi].round(), main.biome_name(pts[pi]) if main.has_method("biome_name") else "?", snappedf(main.height_at(pts[pi].x, pts[pi].z), 0.1)])
		acc = 0.0
