# Hollowfly - Copyright (C) 2026 Santiluna99
# Software libre bajo la GNU GPL v3 (ver LICENSE y NOTICE).
extends RefCounted
## Estado de la droga que tiene la mosca: cuál, qué dosis, cuánto dura y cuánto efecto hay en cada momento.
## El efecto en sí lo calcula el conectoma real (el servidor cambia las sinapsis por neurotransmisor); aquí solo
## se maneja la curva en el tiempo: sube (ONSET s), se mantiene (duración) y baja (OFFSET s) hasta 0 = mosca normal.
## "Quitar droga" hace la bajada rápida (QUICK s) desde el nivel que tenga en ese momento.

## id para el servidor, nombre, descripción corta (qué sistema toca), frenado motor a dosis 1 (0 = ninguno)
## El cerebro en reposo está en silencio, así que "frenar" no sale solo del conectoma: los sedantes añaden ese freno
## en el cuerpo (solo mientras dura la droga; el resto -giro, olfato, huida- sí lo decide el conectoma).
const LIST := [
	["alcohol", "Alcohol", "más inhibición GABA, menos excitación, ruido", 0.3],
	["cafeina", "Cafeína", "más excitación, menos inhibición, dopamina", 0.0],
	["cocaina", "Estimulante medio", "dopamina y octopamina altas", 0.0],
	["anfetamina", "Estimulante fuerte", "dopamina y octopamina muy altas", 0.0],
	["nicotina", "Nicotina", "más excitación colinérgica", 0.0],
	["sedante", "Sedante", "mucha inhibición GABA", 0.6],
	["lsd", "Serotoninérgico", "serotonina alta y ruido", 0.0],
	["anestesico", "Anestésico", "inhibición fuerte y excitación baja", 0.92],
]
const ONSET := 6.0        # s hasta el efecto pleno
const OFFSET := 20.0      # s de bajada natural al terminar la duración
const QUICK := 3.0        # s de bajada al pulsar "Quitar droga"

var id := ""              # droga activa ("" = ninguna)
var dose := 0.6           # 0.1..1.0
var duration := 60.0      # s en meseta; <= 0 = hasta quitarla
var level := 0.0          # efecto actual 0..1 (lo que se manda al servidor)
var phase := "ninguna"    # ninguna | subiendo | activa | saliendo
var _t := 0.0
var _from := 0.0
var _fade := OFFSET


func apply(drug_id: String, d: float, dur: float) -> void:
	id = drug_id
	dose = clampf(d, 0.05, 1.0)
	duration = dur
	_t = 0.0
	_from = level          # si ya había otra droga, sube desde donde estaba
	phase = "subiendo"


## Retira la droga: baja rápido hasta 0 y todo vuelve a la normalidad.
func remove() -> void:
	if phase == "ninguna":
		return
	_from = level
	_t = 0.0
	_fade = QUICK
	phase = "saliendo"


## Muerte / reinicio: la mosca que renace está limpia.
func hard_reset() -> void:
	id = ""
	level = 0.0
	phase = "ninguna"
	_t = 0.0


func active() -> bool:
	return phase != "ninguna"


func tick(dt: float) -> void:
	if phase == "ninguna":
		return
	_t += dt
	match phase:
		"subiendo":
			level = lerpf(_from, dose, smoothstep(0.0, 1.0, _t / ONSET))
			if _t >= ONSET:
				phase = "activa"
				_t = 0.0
		"activa":
			level = dose
			if duration > 0.0 and _t >= duration:
				_from = level
				_t = 0.0
				_fade = OFFSET
				phase = "saliendo"
		"saliendo":
			level = _from * (1.0 - smoothstep(0.0, 1.0, _t / _fade))
			if _t >= _fade:
				level = 0.0
				phase = "ninguna"
				id = ""


## Fracción de velocidad que se pierde por el frenado motor de la droga (0 si no hay droga).
func slow() -> float:
	for d in LIST:
		if d[0] == id:
			return clampf(level * float(d[3]), 0.0, 0.95)
	return 0.0


func drug_name() -> String:
	for d in LIST:
		if d[0] == id:
			return d[1]
	return ""


## Texto de estado para el panel.
func status_text() -> String:
	if phase == "ninguna":
		return "Sin compuesto · actividad normal"
	var s := "%s · efecto %d%% · " % [drug_name(), int(round(level * 100.0))]
	match phase:
		"subiendo": s += "subiendo"
		"activa": s += "activa" + ("" if duration <= 0.0 else " (quedan %d s)" % maxi(0, int(ceil(duration - _t))))
		"saliendo": s += "saliendo (%d s)" % maxi(0, int(ceil(_fade - _t)))
	return s
