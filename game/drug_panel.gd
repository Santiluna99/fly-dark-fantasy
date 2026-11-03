# Hollowfly - Copyright (C) 2026 Santiluna99
# Software libre bajo la GNU GPL v3 (ver LICENSE y NOTICE).
extends Control
## Panel para dar compuestos químicos a la mosca (tecla P): ventana en el centro con la droga, la cantidad (escala de 5 pasos) y la duración.
## "Aplicar" y "Quitar droga" cierran el panel (Esc o clic fuera también). El efecto lo calcula el conectoma real;
## al quitarla (o al terminar) las sinapsis vuelven EXACTAMENTE a las originales.

const Drugs := preload("res://drugs.gd")
const AMOUNTS := [["Mínima", 0.2], ["Baja", 0.4], ["Media", 0.6], ["Alta", 0.8], ["Máxima", 1.0]]
const AMOUNT_SHORT := ["Mín.", "Baja", "Media", "Alta", "Máx."]
const DURS := [["30 segundos", 30.0], ["60 segundos", 60.0], ["2 minutos", 120.0], ["Hasta quitarla", 0.0]]
const W := 340.0
const H := 296.0
var fly
var _sel := 0
var _amount := 2           # índice en AMOUNTS (3 = media)
var _info: Label
var _amount_l: Label
var _dur: OptionButton
var _box: Panel


func _flat(bg: Color, border: Color, bw := 1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	return sb


func _style(b: Control, toggle := false) -> void:
	b.add_theme_stylebox_override("normal", _flat(Color(0.15, 0.13, 0.22), Color(0.38, 0.33, 0.55)))
	b.add_theme_stylebox_override("hover", _flat(Color(0.22, 0.19, 0.33), Color(0.6, 0.52, 0.85)))
	b.add_theme_stylebox_override("pressed", _flat(Color(0.42, 0.28, 0.68), Color(0.85, 0.75, 1.0), 2))
	b.add_theme_stylebox_override("hover_pressed", _flat(Color(0.48, 0.33, 0.75), Color(0.9, 0.8, 1.0), 2))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_size_override("font_size", 12)


func _label(text: String, pos: Vector2, size_px := 12, col := Color(0.9, 0.88, 1.0)) -> Label:
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
	# fondo oscurecido: un clic fuera de la ventana la cierra
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			close())
	add_child(dim)
	_box = Panel.new()
	_box.position = Vector2((640.0 - W) * 0.5, 22.0)
	_box.size = Vector2(W, H)
	_box.add_theme_stylebox_override("panel", _flat(Color(0.06, 0.05, 0.1, 0.97), Color(0.6, 0.5, 0.9), 2))
	add_child(_box)
	_label("COMPUESTOS", Vector2(16, 8), 15, Color(0.85, 0.75, 1.0))
	_label("Esc: cerrar", Vector2(W - 78, 11), 10, Color(0.6, 0.58, 0.75))
	# 1) droga
	var grp := ButtonGroup.new()
	for i in Drugs.LIST.size():
		var b := Button.new()
		b.text = Drugs.LIST[i][1]
		b.toggle_mode = true
		b.button_group = grp
		b.button_pressed = (i == _sel)
		b.position = Vector2(16 + (i % 2) * 156, 34 + (i / 2) * 29)
		b.size = Vector2(152, 25)
		_style(b)
		var idx := i
		b.pressed.connect(func():
			_sel = idx
			_info.text = _cap(Drugs.LIST[idx][2]))
		_box.add_child(b)
	_info = _label(_cap(Drugs.LIST[_sel][2]), Vector2(16, 154), 11, Color(0.7, 0.68, 0.85))
	_info.size = Vector2(W - 32, 18)
	# 2) cantidad
	_amount_l = _label("", Vector2(16, 182), 12)
	var sgrp := ButtonGroup.new()
	for i in AMOUNTS.size():
		var sb := Button.new()
		sb.text = AMOUNT_SHORT[i]
		sb.toggle_mode = true
		sb.button_group = sgrp
		sb.button_pressed = (i == _amount)
		sb.position = Vector2(16 + i * 61, 202)
		sb.size = Vector2(57, 25)
		_style(sb)
		var ai := i
		sb.pressed.connect(func():
			_amount = ai
			_update_amount())
		_box.add_child(sb)
	_update_amount()
	# 3) duración
	_label("Duración", Vector2(16, 240), 12)
	_dur = OptionButton.new()
	for d in DURS:
		_dur.add_item(d[0])
	_dur.select(1)
	_dur.position = Vector2(86, 235)
	_dur.size = Vector2(160, 25)
	_style(_dur)
	_box.add_child(_dur)
	# 4) acciones
	var ap := Button.new()
	ap.text = "Aplicar"
	ap.position = Vector2(16, 266)
	ap.size = Vector2(150, 24)
	_style(ap)
	ap.pressed.connect(_apply)
	_box.add_child(ap)
	var qt := Button.new()
	qt.text = "Quitar compuesto"
	qt.position = Vector2(174, 266)
	qt.size = Vector2(150, 24)
	_style(qt)
	qt.pressed.connect(_remove)
	_box.add_child(qt)


func _cap(t: String) -> String:
	return t.substr(0, 1).to_upper() + t.substr(1)


func close() -> void:
	visible = false


func _update_amount() -> void:
	_amount_l.text = "Cantidad: %s (%d%%)" % [AMOUNTS[_amount][0], int(AMOUNTS[_amount][1] * 100.0)]


func _apply() -> void:
	fly.drug.apply(Drugs.LIST[_sel][0], AMOUNTS[_amount][1], DURS[_dur.selected][1])
	fly.world.log_msg("Mosca: toma %s (cantidad %s)" % [Drugs.LIST[_sel][1], AMOUNTS[_amount][0].to_lower()])
	close()


func _remove() -> void:
	if fly.drug.active():
		fly.world.log_msg("Mosca: se le quita el compuesto")
	fly.drug.remove()
	close()
