# Hollowfly - Copyright (C) 2026 Santiluna99
# Software libre bajo la GNU GPL v3 (ver LICENSE y NOTICE).
extends Control
## CEREBRO EN VIVO (tecla B): lo que hace el conectoma real mientras la mosca decide.
##   - Mapa del cerebro visto de frente: cada casilla agrupa las neuronas que están ahí de verdad (posiciones de FlyWire).
##     El brillo es su actividad en este momento; en rojo, las casillas con neuronas lesionadas.
##   - Disparos por segundo de las 138.639 neuronas.
##   - Lo que siente (olor, amenaza) y lo que ordena el cerebro (giro, avance, escape, cuerpos de hongo).
##   - Los últimos 12 s de esas órdenes.
## Todo sale de las respuestas del servidor del cerebro (remote_brain.gd); este panel solo dibuja.

const W := 232.0
const H := 310.0                  # deja a la vista el aviso legal de abajo a la derecha
const MAP_POS := Vector2(8, 20)
const MAP_SIZE := Vector2(216, 93)   # el cerebro real es ~2,3 veces más ancho que alto
const HIST := 240                 # muestras de la línea de tiempo (12 s a 20 por segundo)
const C_BG := Color(0.05, 0.04, 0.09, 0.93)
const C_EDGE := Color(0.6, 0.5, 0.9)
const C_TXT := Color(0.9, 0.88, 1.0)
const C_DIM := Color(0.62, 0.6, 0.78)
const C_SMELL := Color(0.3, 0.75, 1.0)
const C_THREAT := Color(1.0, 0.36, 0.36)
const C_TURN := Color(1.0, 0.85, 0.3)
const C_FWD := Color(0.55, 1.0, 0.3)
const C_MB := Color(0.72, 0.5, 1.0)
const C_OFF := Color(0.4, 0.22, 0.26)

var fly
var _img: Image
var _tex: ImageTexture
var _act := PackedFloat32Array()      # actividad suavizada por casilla (0..1)
var _h_fwd := PackedFloat32Array()
var _h_turn := PackedFloat32Array()
var _h_gf := PackedFloat32Array()
var _hpos := 0
var _acc := 0.0
var _hz := 0.0
var _font: Font


func build(f) -> void:
	fly = f
	size = Vector2(W, H)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = get_theme_default_font()
	_h_fwd.resize(HIST)
	_h_turn.resize(HIST)
	_h_gf.resize(HIST)


func _process(dt: float) -> void:
	if not visible or fly == null:
		return
	var rb = fly.real_brain
	_hz = lerpf(_hz, rb.hz if rb.live else 0.0, 0.2)
	_acc += dt
	if _acc >= 0.05:              # 20 veces por segundo: muestra para la línea de tiempo y mapa nuevo
		_acc = 0.0
		_h_fwd[_hpos] = rb.out_fwd if rb.live else 0.0
		_h_turn[_hpos] = rb.out_turn if rb.live else 0.0
		_h_gf[_hpos] = rb.out_gf if rb.live else 0.0
		_hpos = (_hpos + 1) % HIST
		_update_map(rb)
	queue_redraw()


## Pinta el mapa en una imagen pequeña (una casilla = un píxel) que luego se dibuja ampliada.
func _update_map(rb) -> void:
	var n: int = rb.grid_w * rb.grid_h
	if n <= 0 or rb.dens.size() != n:
		return
	if _img == null or _img.get_width() != rb.grid_w or _img.get_height() != rb.grid_h:
		_img = Image.create(rb.grid_w, rb.grid_h, false, Image.FORMAT_RGBA8)
		_tex = ImageTexture.create_from_image(_img)
		_act.resize(n)
		_act.fill(0.0)
	var has_px: bool = rb.px.size() == n and rb.live
	var has_les: bool = rb.les_mask.size() == n
	for i in n:
		var d := float(rb.dens[i]) / 35.0
		if d <= 0.0:
			_img.set_pixel(i % rb.grid_w, i / rb.grid_w, Color(0, 0, 0, 0))
			continue
		var a := float(rb.px[i]) / 35.0 if has_px else 0.0
		_act[i] = lerpf(_act[i], a, 0.5)
		a = _act[i]
		var c := Color(0.17, 0.13, 0.33).lerp(Color(0.3, 0.24, 0.55), d)      # tejido en reposo: más claro donde hay más neuronas
		if has_les and rb.les_mask[i] > 0:
			c = c.lerp(Color(0.8, 0.1, 0.14), 0.35 + 0.65 * float(rb.les_mask[i]) / 35.0)
		if a > 0.01:
			c = c.lerp(Color(0.5, 1.0, 0.25), minf(1.0, a * 1.6))            # activo: verde ácido
			if a > 0.6:
				c = c.lerp(Color(1, 1, 0.9), (a - 0.6) / 0.4)                 # muy activo: casi blanco
		_img.set_pixel(i % rb.grid_w, i / rb.grid_w, c)
	_tex.update(_img)


func _text(pos: Vector2, s: String, sz := 9, col := C_TXT, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	draw_string(_font, pos, s, align, width, sz, col)


## Barra de 0 a 1 que crece desde la izquierda (o desde la derecha si rtl).
func _bar(r: Rect2, v: float, col: Color, rtl := false) -> void:
	draw_rect(r, Color(1, 1, 1, 0.07))
	var w := r.size.x * clampf(v, 0.0, 1.0)
	if w > 0.5:
		draw_rect(Rect2(r.position.x + (r.size.x - w if rtl else 0.0), r.position.y, w, r.size.y), col)


func _draw() -> void:
	if fly == null:
		return
	var rb = fly.real_brain
	draw_rect(Rect2(Vector2.ZERO, size), C_BG)
	draw_rect(Rect2(Vector2.ZERO, size), C_EDGE, false, 1.0)
	_text(Vector2(8, 14), "CEREBRO EN VIVO", 11, Color(0.85, 0.75, 1.0))
	_text(Vector2(8, 14), "conectoma real" if rb.live else "sin servidor", 8, C_DIM if rb.live else C_THREAT, HORIZONTAL_ALIGNMENT_RIGHT, W - 16)
	# --- mapa ---
	draw_rect(Rect2(MAP_POS, MAP_SIZE), Color(0, 0, 0, 0.45))
	if _tex != null:
		draw_texture_rect(_tex, Rect2(MAP_POS, MAP_SIZE), false)
	_text(MAP_POS + Vector2(3, 10), "izq.", 8, C_DIM)
	_text(MAP_POS + Vector2(0, 10), "der.", 8, C_DIM, HORIZONTAL_ALIGNMENT_RIGHT, MAP_SIZE.x - 3)
	_text(MAP_POS + Vector2(0, MAP_SIZE.y - 3), "vista frontal · 138.639 neuronas", 8, C_DIM, HORIZONTAL_ALIGNMENT_CENTER, MAP_SIZE.x)
	# --- contador ---
	var y := MAP_POS.y + MAP_SIZE.y
	_text(Vector2(8, y + 15), "Disparos por segundo", 9, C_DIM)
	_text(Vector2(8, y + 16), _miles(int(round(_hz))), 12, C_FWD, HORIZONTAL_ALIGNMENT_RIGHT, W - 16)
	# --- medidores ---
	y += 24.0
	var bx := 76.0
	var bw := 148.0
	var s: Array = rb.sense
	# (un sentido lesionado se pinta apagado: el estímulo está ahí, pero esas neuronas no lo transmiten)
	var li: Array = fly.lesion.ids
	_text(Vector2(8, y + 8), "Olor  izq | der", 9)
	_bar(Rect2(bx, y + 1, bw * 0.5 - 2, 8), float(s[0]) / 0.8, C_OFF if li.has("orn_l") else C_SMELL, true)
	_bar(Rect2(bx + bw * 0.5 + 2, y + 1, bw * 0.5 - 2, 8), float(s[1]) / 0.8, C_OFF if li.has("orn_r") else C_SMELL)
	y += 13
	_text(Vector2(8, y + 8), "Amenaza", 9)
	_bar(Rect2(bx, y + 1, bw * 0.5 - 2, 8), float(s[2]) / 0.9, C_OFF if li.has("loom_l") else C_THREAT, true)
	_bar(Rect2(bx + bw * 0.5 + 2, y + 1, bw * 0.5 - 2, 8), float(s[3]) / 0.9, C_OFF if li.has("loom_r") else C_THREAT)
	y += 15
	draw_line(Vector2(8, y - 1), Vector2(W - 8, y - 1), Color(1, 1, 1, 0.12))
	_text(Vector2(8, y + 8), "Giro  izq | der", 9)
	var tr: float = rb.out_turn if rb.live else 0.0
	_bar(Rect2(bx, y + 1, bw * 0.5 - 2, 8), -tr, C_TURN, true)
	_bar(Rect2(bx + bw * 0.5 + 2, y + 1, bw * 0.5 - 2, 8), tr, C_TURN)
	y += 13
	_text(Vector2(8, y + 8), "Avance", 9)
	_bar(Rect2(bx, y + 1, bw, 8), rb.out_fwd if rb.live else 0.0, C_FWD)
	y += 13
	_text(Vector2(8, y + 8), "Escape", 9)
	_bar(Rect2(bx, y + 1, bw, 8), rb.out_gf if rb.live else 0.0, C_THREAT)
	y += 13
	_text(Vector2(8, y + 8), "C. de hongo", 9)
	_bar(Rect2(bx, y + 1, bw, 8), (rb.out_kc if rb.live else 0.0) * 60.0, C_MB)
	# --- línea de tiempo ---
	y += 16
	_text(Vector2(8, y + 7), "Últimos 12 s", 8, C_DIM)
	_text(Vector2(118, y + 7), "avance", 8, C_FWD)
	_text(Vector2(154, y + 7), "giro", 8, C_TURN)
	_text(Vector2(180, y + 7), "escape", 8, C_THREAT)
	var cr := Rect2(8, y + 11, W - 16, 48)
	draw_rect(cr, Color(0, 0, 0, 0.45))
	draw_line(Vector2(cr.position.x, cr.position.y + cr.size.y * 0.5), Vector2(cr.end.x, cr.position.y + cr.size.y * 0.5), Color(1, 1, 1, 0.1))
	_trace(cr, _h_fwd, C_FWD, false)
	_trace(cr, _h_gf, C_THREAT, false)
	_trace(cr, _h_turn, C_TURN, true)
	# --- estado ---
	y = cr.end.y + 12
	if fly.lesion.active():
		_text(Vector2(8, y), "Lesión: " + fly.lesion.status_text(), 9, Color(1.0, 0.55, 0.55), HORIZONTAL_ALIGNMENT_LEFT, W - 16)
	else:
		_text(Vector2(8, y), "Cerebro sano", 9, C_DIM)
	if fly.drug.active():
		_text(Vector2(8, y + 12), "Compuesto: %s %d%%" % [fly.drug.drug_name(), int(round(fly.drug.level * 100.0))], 9, C_MB)


## Dibuja una serie de la línea de tiempo (lo más reciente a la derecha). centered: -1..1 alrededor del medio.
func _trace(r: Rect2, h: PackedFloat32Array, col: Color, centered: bool) -> void:
	var pts := PackedVector2Array()
	pts.resize(HIST)
	for k in HIST:
		var v := h[(_hpos + k) % HIST]
		var ny := 0.5 - 0.5 * clampf(v, -1.0, 1.0) if centered else 1.0 - clampf(v, 0.0, 1.0)
		pts[k] = Vector2(r.position.x + r.size.x * float(k) / float(HIST - 1), r.position.y + 1.0 + (r.size.y - 2.0) * ny)
	draw_polyline(pts, col, 1.0)


## 186432 -> "186.432"
func _miles(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out
