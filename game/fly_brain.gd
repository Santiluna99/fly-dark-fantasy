class_name FlyBrain extends RefCounted
## Red LIF de 80 neuronas con la arquitectura del olfato/escape de Drosophila.
## 0-1 ORN (antenas) | 2-3 looming | 4 hambre | 5-12 PN | 13-72 células de Kenyon
## 73-74 MBON (acercar/evitar) | 75-76 DN giro izq/der | 77 DN avance | 78-79 fibra gigante
# Nº total de neuronas. Mapa: 0-1 olfato | 2-3 amenaza | 4 hambre | 5-12 PN | 13-72 Kenyon |
# 73-74 MBON | 75-76 giro | 77 avance | 78-79 fibra gigante de escape.
const N := 80

# v = voltaje de cada neurona   spk = ¿disparó en este tick?   rate = tasa de disparo suavizada (lo que usa el cuerpo)
# trace = rastro reciente de cada célula de Kenyon (para el aprendizaje)   syn_b/syn_w = destino y peso de cada sinapsis
# out = sinapsis salientes por neurona (solo se recorren las neuronas que disparan)   kc_app/kc_av = sinapsis que aprende la dopamina
var v := PackedFloat32Array()
var spk := PackedByteArray()
var rate := PackedFloat32Array()
var trace := PackedFloat32Array()
var syn_b := PackedInt32Array()
var syn_w := PackedFloat32Array()
var out: Array = []            # por neurona: índices de sinapsis salientes (event-driven)
var kc_app := PackedInt32Array()
var kc_av := PackedInt32Array()


## Cablea la red: antena -> PN -> Kenyon (cada Kenyon recibe 4 PN al azar) -> MBON; vías de giro, avance
## y escape (looming -> fibra gigante -> giro/avance). Los pesos Kenyon -> MBON empiezan bajos: los modifica el aprendizaje.
func _init() -> void:
	v.resize(N); spk.resize(N); rate.resize(N); trace.resize(60)
	for i in N:
		out.append([])
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 4:
		_link(0, 5 + i, 0.6)
		_link(1, 9 + i, 0.6)
	for k in 60:
		var used := {}
		while used.size() < 4:
			used[5 + rng.randi_range(0, 7)] = true
		for p in used.keys():
			_link(p, 13 + k, 0.5)
		kc_app.append(_link(13 + k, 73, 0.04))
		kc_av.append(_link(13 + k, 74, 0.03))
	_link(0, 75, 0.5); _link(1, 75, -0.2)
	_link(1, 76, 0.5); _link(0, 76, -0.2)
	_link(0, 77, 0.3); _link(1, 77, 0.3); _link(4, 77, 0.4)
	_link(73, 77, 0.5); _link(74, 77, -0.6)
	_link(2, 78, 0.8); _link(3, 79, 0.8)
	_link(78, 76, 1.0); _link(79, 75, 1.0)
	_link(78, 77, 1.0); _link(79, 77, 1.0)


## Crea una sinapsis a -> b con peso w y devuelve su índice.
func _link(a: int, b: int, w: float) -> int:
	syn_b.append(b)
	syn_w.append(w)
	var idx := syn_b.size() - 1
	out[a].append(idx)
	return idx


## Un paso de simulación (neuronas "integra y dispara"): 1) suma las corrientes de entrada y las sinapsis
## de las neuronas que dispararon, 2) el voltaje se filtra (x0.85) y si supera 1.0 la neurona dispara y se reinicia,
## 3) actualiza la tasa de disparo y el rastro de las células de Kenyon.
func step(x: PackedFloat32Array) -> void:
	var cur := x.duplicate()
	for i in N:
		if spk[i] == 1:
			for s in out[i]:
				cur[syn_b[s]] += syn_w[s]
	for i in N:
		v[i] = v[i] * 0.85 + cur[i]
		if v[i] > 1.0:
			spk[i] = 1
			v[i] = 0.0
		else:
			spk[i] = 0
		rate[i] = rate[i] * 0.9 + spk[i] * 0.1
		if i >= 13 and i < 73:
			trace[i - 13] = trace[i - 13] * 0.98 + spk[i]


## Dopamina: refuerza KC -> MBON "acercar" según la traza reciente de cada KC
func reward() -> void:
	for k in 60:
		var i := kc_app[k]
		syn_w[i] = minf(0.35, syn_w[i] + 0.015 * minf(trace[k], 4.0))


## Castigo: refuerza KC -> MBON "evitar"
func punish() -> void:
	for k in 60:
		var i := kc_av[k]
		syn_w[i] = minf(0.35, syn_w[i] + 0.02 * minf(trace[k], 4.0))


## Apaga toda la actividad (al renacer). NO borra los pesos: la memoria se conserva.
func reset() -> void:
	v.fill(0.0)
	spk.fill(0)


## Color de cada grupo de neuronas para el panel de actividad.
static func group_color(i: int) -> Color:
	if i < 5: return Color(0.3, 0.5, 1.0)
	if i < 13: return Color(0.3, 0.88, 1.0)
	if i < 73: return Color(0.63, 0.44, 1.0)
	if i < 75: return Color(1.0, 0.82, 0.3)
	if i < 78: return Color(0.36, 1.0, 0.54)
	return Color(1.0, 0.31, 0.31)
