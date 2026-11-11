# Hollowfly - Copyright (C) 2026 Santiluna99
# Software libre bajo la GNU GPL v3 (ver LICENSE y NOTICE).
extends RefCounted
## Lesiones de la mosca: grupos de neuronas del conectoma real que están silenciados (no pueden disparar).
## El efecto lo calcula el servidor del cerebro (brain_server/fly_server.py, tabla LESIONS); aquí solo se guarda
## cuáles están activas. Son reversibles: al quitarlas el cerebro vuelve EXACTAMENTE a como estaba.

## id para el servidor, nombre, qué se observa (medido con el cerebro real, ver docs/LESIONES.md)
const LIST := [
	["orn_l", "Antena izquierda", "No huele por la izquierda: gira hacia el lado sano"],
	["orn_r", "Antena derecha", "No huele por la derecha: gira hacia el lado sano"],
	["alpn", "Relevo olfativo", "El olor llega a las antenas pero no al resto del cerebro"],
	["loom_l", "Amenaza izquierda", "No ve lo que se le acerca por la izquierda"],
	["loom_r", "Amenaza derecha", "No ve lo que se le acerca por la derecha"],
	["gf", "Fibra gigante", "Sin la neurona del escape rápido: huye más lento"],
	["kc", "Cuerpos de hongo", "Centro de memoria: la conducta innata sigue igual"],
	["cx", "Complejo central", "Centro de orientación: aquí apenas cambia nada"],
	["dn", "Vía al cuerpo", "Corta cerebro → cuerpo: el cerebro sigue activo, pero no se mueve"],
]

var ids: Array = []       # lesiones activas (ids de LIST)


func apply(new_ids: Array) -> void:
	ids = new_ids.duplicate()
	ids.sort()


## Quita todas las lesiones: cerebro sano.
func clear() -> void:
	ids = []


func active() -> bool:
	return not ids.is_empty()


## ¿Está cortada la vía del cerebro al cuerpo? Entonces el cuerpo no recibe ninguna orden: ni avanza ni gira.
## (La velocidad de crucero y el deambular los pone el juego, no el conectoma; por eso aquí se apagan a mano.)
func cuts_body() -> bool:
	return ids.has("dn")


static func name_of(id: String) -> String:
	for l in LIST:
		if l[0] == id:
			return l[1]
	return id


## Texto de estado para el HUD y el panel.
func status_text() -> String:
	if ids.is_empty():
		return "Cerebro sano"
	var names: Array = []
	for id in ids:
		names.append(name_of(id))
	return ", ".join(names)
