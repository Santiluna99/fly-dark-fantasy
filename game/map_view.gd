class_name MapView extends Control
## MINIMAPA (esquina, centrado en lo que sigue la cámara) y MAPA COMPLETO (tecla M, clic = viajar con la cámara libre).
## Muestra el terreno por bioma con relieve sombreado, el castillo, aldeas y faro, la mosca (amarillo),
## la cámara (flecha blanca) y todos los mobs vivos como puntos ROJOS.

signal travel(p: Vector2)       # clic en el mapa completo: punto del mundo (x, z)

const N := 256                  # 1 píxel = 1 metro
const PAD := 80                 # margen de mar alrededor para que el minimapa no se salga
const COL := [Color(.1, .17, .22), Color(.86, .89, .9), Color(.24, .3, .2), Color(.13, .27, .14), Color(.42, .37, .31), Color(.3, .38, .2)]
static var _tex: ImageTexture

var main: Node
var big := false
var window_m := 100.0           # metros visibles en el minimapa


## Genera (una sola vez) la textura del terreno a partir de height_at() y la humedad.
func build(m: Node) -> void:
	main = m
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true    # los marcadores (castillo, aldeas, mobs) no deben dibujarse fuera del recuadro del mapa
	if _tex != null:
		return
	var S := N + PAD * 2
	var img := Image.create(S, S, false, Image.FORMAT_RGB8)
	img.fill(COL[0].darkened(0.3))
	var H := PackedFloat32Array()
	H.resize(N * N)
	for j in N:
		for i in N:
			H[j * N + i] = m.height_at(i - N / 2.0, j - N / 2.0)
	for j in N:
		for i in N:
			var h := H[j * N + i]
			var x := i - N / 2.0
			var z := j - N / 2.0
			var c: Color = COL[m.biome_idx(h, m.moist.get_noise_2d(x, z))]
			if h < m.WATER + 0.4:
				c = c.lerp(Color(.04, .08, .12), clampf((m.WATER - h) / 6.0, 0.0, 0.7))
			else:
				var hl := H[j * N + maxi(i - 1, 0)]
				var ht := H[maxi(j - 1, 0) * N + i]
				var sh := clampf((h - hl) * 0.12 + (h - ht) * 0.12, -0.35, 0.35)   # sombreado de relieve (luz desde el noroeste)
				c = c.lightened(maxf(sh, 0.0)).darkened(maxf(-sh, 0.0))
				c = c.lightened(clampf(h / 80.0, 0.0, 0.18))
			img.set_pixel(i + PAD, j + PAD, c)
	_tex = ImageTexture.create_from_image(img)


## Mundo (x, z) -> píxel de la textura.
func _px(p: Vector2) -> Vector2:
	return p + Vector2(N / 2.0 + PAD, N / 2.0 + PAD)


func _process(_dt: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	if main == null or _tex == null:
		return
	var sz := size
	var center := Vector2.ZERO
	var scale := 1.0                # píxeles de pantalla por metro
	if big:
		scale = minf(sz.x, sz.y) / float(N)
		var off := (sz - Vector2(N, N) * scale) / 2.0
		draw_texture_rect_region(_tex, Rect2(off, Vector2(N, N) * scale), Rect2(Vector2(PAD, PAD), Vector2(N, N)))
		center = Vector2.ZERO
		_w2s = func(p: Vector2) -> Vector2: return off + (p + Vector2(N / 2.0, N / 2.0)) * scale
	else:
		var f: Node3D = main.foc if main.foc else main.fly
		center = Vector2(f.global_position.x, f.global_position.z)
		if main.mode == 2:
			center = Vector2(main.cam.global_position.x, main.cam.global_position.z)
		scale = minf(sz.x, sz.y) / window_m
		var src := Rect2(_px(center) - Vector2(window_m, window_m) / 2.0, Vector2(window_m, window_m))
		draw_texture_rect_region(_tex, Rect2(Vector2.ZERO, sz), src)
		_w2s = func(p: Vector2) -> Vector2: return sz / 2.0 + (p - center) * scale
	# lugares de interés
	var s2: Callable = _w2s
	var cs := 22.0 * scale
	var cc: Vector2 = s2.call(Vector2.ZERO)
	draw_rect(Rect2(cc - Vector2(cs, cs), Vector2(cs, cs) * 2.0), Color(.55, .55, .6, 0.55), false, 1.0)
	draw_rect(Rect2(cc - Vector2(cs * .25, cs * .25), Vector2(cs, cs) * .5), Color(.6, .6, .65), true)
	for v in main.VILLAGES:
		var vp: Vector2 = s2.call(v)
		draw_rect(Rect2(vp - Vector2(3, 3), Vector2(6, 6)) if big else Rect2(vp - Vector2(2, 2), Vector2(4, 4)), Color(.75, .55, .3), true)
	if main.lighthouse_pos != Vector2.ZERO:
		var lp: Vector2 = s2.call(main.lighthouse_pos)
		draw_circle(lp, 3.0 if big else 2.0, Color(1, .85, .4))
	# mobs vivos: puntos rojos
	var r := 2.6 if big else 1.8
	for m in main.get_tree().get_nodes_in_group("mobs"):
		if m.alive:
			var q: Vector2 = s2.call(Vector2(m.global_position.x, m.global_position.z))
			if big or Rect2(Vector2.ZERO, sz).has_point(q):
				draw_circle(q, r, Color(.95, .1, .08))
	# ser seguido (aro), mosca y cámara
	var fo: Node3D = main.foc
	if fo != main.fly:
		var fp: Vector2 = s2.call(Vector2(fo.global_position.x, fo.global_position.z))
		draw_arc(fp, r + 2.5, 0, TAU, 12, Color(1, 1, 1), 1.0)
	var flp: Vector2 = s2.call(Vector2(main.fly.global_position.x, main.fly.global_position.z))
	draw_circle(flp, r + 0.8, Color(1, .9, .2))
	var cam: Camera3D = main.cam
	var cp: Vector2 = s2.call(Vector2(cam.global_position.x, cam.global_position.z))
	var fw := -cam.global_basis.z
	var dir := Vector2(fw.x, fw.z).normalized()
	if dir.length() < 0.1:
		dir = Vector2(0, -1)
	var pr := Vector2(-dir.y, dir.x)
	var k := 7.0 if big else 5.0
	draw_colored_polygon(PackedVector2Array([cp + dir * k, cp - dir * k * .6 + pr * k * .55, cp - dir * k * .6 - pr * k * .55]), Color(.9, .95, 1.0))
	# marco y norte
	draw_rect(Rect2(Vector2.ZERO, sz), Color(.5, .44, .32), false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(sz.x / 2.0 - 3, 11), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(.9, .85, .7))


var _w2s: Callable


func _gui_input(e: InputEvent) -> void:
	if big and e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var scale := minf(size.x, size.y) / float(N)
		var off := (size - Vector2(N, N) * scale) / 2.0
		var w: Vector2 = ((e.position as Vector2) - off) / scale - Vector2(N / 2.0, N / 2.0)
		if absf(w.x) <= N / 2.0 and absf(w.y) <= N / 2.0:
			travel.emit(w)
			accept_event()
