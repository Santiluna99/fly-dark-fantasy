# Hollowfly - Copyright (C) 2026 Santiluna99
# Software libre bajo la GNU GPL v3 (ver LICENSE y NOTICE).
extends Node3D
## Escenario de prueba aislado: suelo, luces y los tres personajes con el shader PS1 del juego.
var shader: Shader = load("res://ps1.gdshader")   # MobModel.build espera "w.shader"
var t := 0.0
var shot := 0
var rigs := []
func _ready() -> void:
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED   # captura a 1280x720 (el juego usa 640x360)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.04, 0.05, 0.1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.5, 0.7)
	env.ambient_light_energy = 0.8
	var we := WorldEnvironment.new(); we.environment = env; add_child(we)
	var dl := DirectionalLight3D.new(); dl.rotation_degrees = Vector3(-35, 25, 0); dl.light_energy = 1.0; add_child(dl)
	var fl := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(30, 30); fl.mesh = pm
	var fm := StandardMaterial3D.new(); fm.albedo_color = Color(0.12, 0.13, 0.15); fl.material_override = fm; add_child(fl)
	var xs := [-3.2, 0.0, 3.2]
	var vs := ["wolf", "owl", "ogre"]
	for i in 3:
		var b := Node3D.new(); b.position = Vector3(xs[i], 0, 0); add_child(b)
		var rig := MobModel.build(b, self, vs[i], vs[i] == "ogre")
		rigs.append(rig)
		print(vs[i], " h=", rig["h"], " anim=", rig.get("anim"))
		var ap: AnimationPlayer = rig.get("anim")
		if ap: ap.play("walk" if i == 1 else "idle")
	var c := Camera3D.new(); add_child(c); c.make_current()
	c.position = Vector3(0, 1.7, -8.0); c.look_at(Vector3(0, 1.2, 0)); c.fov = 45
func _process(dt: float) -> void:
	t += dt
	if t > 1.2 and shot == 0:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://studio_0.png"); shot = 1
	if t > 1.8 and shot == 1:
		# primer plano del lobo
		var c: Camera3D = get_viewport().get_camera_3d()
		c.position = Vector3(-3.2, 1.9, -4.2); c.look_at(Vector3(-3.2, 1.7, 0)); c.fov = 40
		shot = 2
	if t > 2.2 and shot == 2:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://studio_1.png")
		var c: Camera3D = get_viewport().get_camera_3d()
		c.position = Vector3(3.2, 1.9, -5.5); c.look_at(Vector3(3.2, 1.6, 0)); c.fov = 40
		shot = 3
	if t > 2.6 and shot == 3:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://studio_2.png")
		get_tree().quit()
