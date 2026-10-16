# Hollowfly - Copyright (C) 2026 Santiluna99
# Software libre bajo la GNU GPL v3 (ver LICENSE y NOTICE).
class_name Projectile extends Node3D
## Hechizo en vuelo: fuego, escarcha (ralentiza), sombra (roba vida), luz (cura)

var vel := Vector3.ZERO
var kind := ""
var src: Mob
var life := 2.0
var alive := true


## Crea la bola de luz (esfera brillante + luz) y le da velocidad hacia el objetivo (20 m/s).
func setup(s: Mob, to: Vector3, k: String) -> void:
	src = s
	kind = k
	add_to_group("proj")
	global_position = s.global_position + Vector3.UP * 1.2
	vel = (to - global_position).normalized() * 20.0
	var col: Color = Mob.SPELLS[k]["c"]
	var sph := SphereMesh.new()
	sph.radius = 0.25; sph.height = 0.5; sph.radial_segments = 6; sph.rings = 3
	var m := MeshInstance3D.new()
	m.mesh = sph
	m.material_override = s.world.mat(col, 2.5)
	add_child(m)
	var l := OmniLight3D.new()
	l.light_color = col
	l.omni_range = 7.0
	add_child(l)


## Destruye el hechizo.
func _end() -> void:
	alive = false
	queue_free()


## Vuela en línea recta. Se destruye por tiempo, por tocar el suelo o al impactar:
## luz = cura aliados; fuego = daño; escarcha = daño + ralentiza; sombra = daño + roba vida.
## También mata a la mosca si la toca.
func _physics_process(dt: float) -> void:
	if not alive:
		return
	if not is_instance_valid(src):
		_end()
		return
	global_position += vel * dt
	life -= dt
	if life <= 0.0 or global_position.y < src.world.height_at(global_position.x, global_position.z):
		_end()
		return
	var dmg: float = Mob.SPELLS[kind]["d"]
	for n in get_tree().get_nodes_in_group("mobs"):
		var o := n as Mob
		if o == src or not o.alive:
			continue
		if o.global_position.distance_to(global_position - Vector3.UP * 0.8) < 1.5:
			if kind == "luz":
				if o.faction == src.faction and o.hp < o.max_hp:
					o.damage(dmg, src)
					_end()
					return
			elif Mob.hostile(src.faction, o.faction):
				o.damage(dmg, src)
				if kind == "escarcha":
					o.slow = 3.0
				elif kind == "sombra":
					src.hp = minf(src.max_hp, src.hp + 3.0)
				_end()
				return
	var f = src.world.fly
	if kind != "luz" and f.alive and f.global_position.distance_to(global_position) < 0.8:
		f.die("un hechizo de " + kind)
		_end()
