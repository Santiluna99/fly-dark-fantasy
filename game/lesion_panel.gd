# Hollowfly - Copyright (C) 2026 Santiluna99
# Software libre bajo la GNU GPL v3 (ver LICENSE y NOTICE).
extends Control
## Panel de lesiones (tecla L): se marcan uno o varios grupos de neuronas y "Aplicar" los silencia en el conectoma real.
## "Restaurar cerebro" las quita todas. Los dos botones cierran el panel (Esc o clic fuera también).

const Lesions := preload("res://lesions.gd")
const W := 340.0
const H := 252.0
var fly
var _info: Label
var _box: Panel
var _btns: Array = []


func _flat(bg: Color, border: Color, bw := 1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	return sb


func _style(b: Control) -> void:
	b.add_theme_stylebox_override("normal", _flat(Color(0.2, 0.11, 0.13), Color(0.55, 0.3, 0.33)))
	b.add_theme_stylebox_override("hover", _flat(Color(0.3, 0.15, 0.18), Color(0.85, 0.45, 0.5)))
	b.add_theme_stylebox_override("pressed", _flat(Color(0.62, 0.16, 0.2), Color(1.0, 0.7, 0.7), 2))
	b.add_theme_stylebox_override("hover_pressed", _flat(Color(0.7, 0.2, 0.25), Color(1.0, 0.8, 0.8), 2))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_size_override("font_size", 12)


func _label(text: String, pos: Vector2, size_px := 12, col := Color(1.0, 0.9, 0.9)) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", col)
	_box.add_child(l)
	return l


func build(f) -> void:
	fly = f
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			close())
	add_child(dim)
	_box = Panel.new()
	_box.position = Vector2((640.0 - W) * 0.5, 40.0)
	_box.size = Vector2(W, H)
	_box.add_theme_stylebox_override("panel", _flat(Color(0.1, 0.05, 0.06, 0.97), Color(0.9, 0.45, 0.5), 2))
	add_child(_box)
	_label("LESIONES", Vector2(16, 8), 15, Color(1.0, 0.7, 0.7))
	_label("Esc: cerrar", Vector2(W - 78, 11), 10, Color(0.75, 0.6, 0.6))
	_label("Marca lo que quieres apagar (se pueden combinar)", Vector2(16, 30), 10, Color(0.8, 0.68, 0.68))
	for i in Lesions.LIST.size():
		var b := Button.new()
		b.text = Lesions.LIST[i][1]
		b.toggle_mode = true
		b.position = Vector2(16 + (i % 2) * 156, 50 + (i / 2) * 29)
		b.size = Vector2(152, 25)
		_style(b)
		var idx := i
		b.pressed.connect(func(): _info.text = Lesions.LIST[idx][2])
		_box.add_child(b)
		_btns.append(b)
	_info = _label(Lesions.LIST[0][2], Vector2(16, 198), 10, Color(0.85, 0.72, 0.72))
	_info.size = Vector2(W - 32, 16)
	var ap := Button.new()
	ap.text = "Aplicar"
	ap.position = Vector2(16, 220)
	ap.size = Vector2(150, 24)
	_style(ap)
	ap.pressed.connect(_apply)
	_box.add_child(ap)
	var qt := Button.new()
	qt.text = "Restaurar cerebro"
	qt.position = Vector2(174, 220)
	qt.size = Vector2(150, 24)
	_style(qt)
	qt.pressed.connect(_restore)
	_box.add_child(qt)


## Al abrir, los botones reflejan las lesiones que hay ahora mismo.
func open() -> void:
	for i in _btns.size():
		(_btns[i] as Button).button_pressed = fly.lesion.ids.has(Lesions.LIST[i][0])
	visible = true


func close() -> void:
	visible = false


func _apply() -> void:
	var ids: Array = []
	for i in _btns.size():
		if (_btns[i] as Button).button_pressed:
			ids.append(Lesions.LIST[i][0])
	if ids.is_empty():
		_restore()
		return
	fly.lesion.apply(ids)
	fly.world.log_msg("Mosca: lesión en " + fly.lesion.status_text().to_lower())
	close()


func _restore() -> void:
	if fly.lesion.active():
		fly.world.log_msg("Mosca: cerebro restaurado")
	fly.lesion.clear()
	close()
