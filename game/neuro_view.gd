# Hollowfly - Copyright (C) 2026 Santiluna99
# Software libre bajo la GNU GPL v3 (ver LICENSE y NOTICE).
class_name NeuroView extends Control
## Panel con la actividad de las 80 neuronas (brillo = tasa de disparo)

var brain: FlyBrain


## Pide redibujar el panel cada frame.
func _process(_d: float) -> void:
	queue_redraw()


## Dibuja 80 cuadraditos (20 por fila); el brillo de cada uno es su tasa de disparo.
func _draw() -> void:
	if brain == null:
		return
	for i in FlyBrain.N:
		var c := FlyBrain.group_color(i)
		var a := clampf(brain.rate[i] * 6.0, 0.08, 1.0)
		draw_rect(Rect2((i % 20) * 9, (i / 20) * 9, 7, 7), Color(c.r, c.g, c.b, a))
