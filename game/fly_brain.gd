class_name FlyBrain extends RefCounted
## Interfaz común del cerebro de la mosca. El cerebro es el REAL (conectoma de FlyWire, ver remote_brain.gd);
## esta clase solo define lo que usan la mosca y el panel de actividad:
##   rate[0..79]  tasa de disparo por grupo (la mosca lee rate[75..77]: giro izq/der y avance)
##   step(x)      un tick con las 80 entradas de los sentidos
## Mapa de los 80 grupos (mismo orden que el servidor): 0-1 olfato | 2-3 amenaza | 4 hambre | 5-12 PN | 13-72 Kenyon |
## 73-74 MBON | 75-76 giro | 77 avance | 78-79 fibra gigante de escape.
const N := 80

var rate := PackedFloat32Array()


func _init() -> void:
	rate.resize(N)


## Un paso del cerebro (lo implementa RemoteBrain).
func step(_x: PackedFloat32Array) -> void:
	pass


## Apaga toda la actividad (al renacer).
func reset() -> void:
	rate.fill(0.0)


## Color de cada grupo de neuronas para el panel de actividad.
static func group_color(i: int) -> Color:
	if i < 5: return Color(0.3, 0.5, 1.0)
	if i < 13: return Color(0.3, 0.88, 1.0)
	if i < 73: return Color(0.63, 0.44, 1.0)
	if i < 75: return Color(1.0, 0.82, 0.3)
	if i < 78: return Color(0.36, 1.0, 0.54)
	return Color(1.0, 0.31, 0.31)
