# Hollowfly - Copyright (C) 2026 Santiluna99
# Software libre bajo la GNU GPL v3 (ver LICENSE y NOTICE).
class_name RemoteBrain extends FlyBrain
## CEREBRO REAL (conectoma FlyWire, 138.639 neuronas) a través de un servidor Python local.
## Hereda de FlyBrain para que Fly.gd y NeuroView lo usen igual que al cerebro de 80 neuronas.
## Cada ~50 ms envía los sentidos (olor izq/der, amenaza izq/der, hambre) y recibe giro, avance y actividad.
## Si el servidor no está disponible la mosca se queda quieta esperando (live = false) y se reintenta la conexión cada 3 s.
## Servidor: carpeta "cerebro_real/" -> python fly_server.py

const SEND_MS := 50          # intervalo de envío de sentidos
const TURN_RATE := 0.14      # giro maximo: ~1.5 rad/s (con TURN_GAIN de fly.gd); mas alto = vueltas cerradas sobre el sitio
const FWD_RATE := 0.23       # rate[77] con avance maximo
const CONTRAST := 12.0       # realce de la diferencia de olor entre antenas (el lector olfativo ya lateraliza con ~10% de diferencia)
var sock := StreamPeerTCP.new()
var port := 9009
var status := "desconectado"   # texto para el HUD
var t_ms := 0.0                # tiempo propio del cerebro (ms)
var live := false              # ¿hay servidor conectado y respondiendo?
var _buf := ""
var _sent := 0
var _retry := 0
var _reset := false
var _tgt: Dictionary = {}      # última respuesta del servidor
var _view := PackedFloat32Array()
var conc_l := -1.0             # concentración de olor SIN saturar en cada antena (la rellena Fly.gd); -1 = no disponible
var conc_r := -1.0
# SIMETRÍA: el conectoma real no es perfectamente simétrico y, cerca de la fruta, la mosca acababa girando casi siempre a la izquierda.
# Cada 6-12 s se "espeja" el cerebro: se intercambian las entradas izquierda/derecha (olor y amenaza) y se invierte el giro que sale.
# El comportamiento sigue siendo correcto (va hacia el olor y huye de la amenaza), pero cualquier sesgo propio del cerebro cambia de signo
# cada pocos segundos y se compensa, así que gira parejo a ambos lados.
var mirror := false
var _mirror_t := 9.0
# DROGAS: Fly.gd fija drug_id/drug_level; el servidor cambia las sinapsis (ver brain_server/fly_server.py). Solo se envía cuando cambia.
var drug_id := ""
var drug_level := 0.0
var _drug_sent_id := ""
var _drug_sent_level := 0.0
var _drug_dirty := false
# LESIONES: Fly.gd fija lesion_ids; el servidor silencia esos grupos de neuronas. Solo se envía cuando cambia.
var lesion_ids: Array = []
var _lesion_sent: Array = []
var _lesion_dirty := false
# CEREBRO EN VIVO (lo que dibuja brain_view.gd): mapa del cerebro por casillas y medidas de la última respuesta.
var grid_w := 0
var grid_h := 0
var dens := PackedByteArray()      # densidad de neuronas por casilla (0..35)
var les_mask := PackedByteArray()  # parte de cada casilla que está lesionada (0..35)
var px := PackedByteArray()        # actividad por casilla (0..35)
var hz := 0.0                      # disparos por segundo de todo el cerebro
var map_v := -1                    # versión del mapa que tenemos (si no coincide con la del servidor, se pide)
var _srv_v := 0
var sense := [0.0, 0.0, 0.0, 0.0, 0.0]   # lo que siente la mosca: olor izq/der, amenaza izq/der, hambre (lados del mundo, sin espejo)
var out_turn := 0.0                # orden de giro del cerebro (-1 izquierda .. +1 derecha), ya sin espejo
var out_fwd := 0.0                 # avance (0..1)
var out_gf := 0.0                  # fibra gigante de escape (0..1)
var out_kc := 0.0                  # fracción de células de Kenyon activas


## Fija la droga que debe aplicar el servidor (id "" o nivel 0 = ninguna).
func set_drug(id: String, level: float) -> void:
	drug_id = id
	drug_level = level


## Fija los grupos de neuronas silenciados (lista de ids; vacía = cerebro sano).
func set_lesion(ids: Array) -> void:
	lesion_ids = ids


## ¿Hay alguna lesión de un solo lado? (entonces no se puede espejar el cerebro: la lesión cambiaría de lado)
func _lateral_lesion() -> bool:
	for id in lesion_ids:
		if str(id).ends_with("_l") or str(id).ends_with("_r"):
			return true
	return false


## Intenta conectar con el servidor.
func start(p: int = 9009) -> void:
	port = p
	_drug_dirty = true      # si el servidor se reinicia, vuelve a recibir el estado de la droga
	_lesion_dirty = true    # ... y el de las lesiones
	map_v = -1
	sock = StreamPeerTCP.new()
	sock.connect_to_host("127.0.0.1", port)
	status = "conectando…"
	_retry = Time.get_ticks_msec() + 3000


## Un paso: manda sentidos, lee la última respuesta y rellena rate[] (lo que usan el cuerpo y el panel).
func step(x: PackedFloat32Array) -> void:
	sock.poll()
	var st := sock.get_status()
	if st != StreamPeerTCP.STATUS_CONNECTED:
		live = false
		if st == StreamPeerTCP.STATUS_ERROR or st == StreamPeerTCP.STATUS_NONE:
			if Time.get_ticks_msec() > _retry:
				start(port)
		status = "SIN SERVIDOR: ejecuta brain_server (python fly_server.py)"
		rate.fill(0.0)
		return
	var now := Time.get_ticks_msec()
	if now - _sent >= SEND_MS:
		_sent = now
		# Realce de contraste entre antenas: la diferencia izq/der real es de un par de %, y el cerebro necesita
		# una diferencia mayor para lateralizar. Se mantiene la intensidad total y se amplifica la diferencia relativa.
		var ol := x[0]
		var orr := x[1]
		if conc_l >= 0.0:
			# curva que no satura (Michaelis-Menten): cerca de la fruta sigue habiendo diferencia entre antenas
			ol = 0.8 * conc_l / (conc_l + 0.25)
			orr = 0.8 * conc_r / (conc_r + 0.25)
		var sm := ol + orr
		if sm > 0.001:
			var k := clampf(1.0 + CONTRAST * (ol - orr) / sm, 0.15, 1.85)
			ol = sm * 0.5 * k
			orr = sm * 0.5 * (2.0 - k)
		_mirror_t -= SEND_MS / 1000.0
		if _mirror_t <= 0.0:
			mirror = not mirror
			_mirror_t = randf_range(6.0, 12.0)
		if _lateral_lesion():
			mirror = false
		sense = [ol, orr, x[2], x[3], x[4] / 0.3]
		var q := {"orn": [orr, ol] if mirror else [ol, orr], "loom": [x[3], x[2]] if mirror else [x[2], x[3]], "hunger": x[4] / 0.3, "reset": _reset}
		_reset = false
		if _drug_dirty or drug_id != _drug_sent_id or absf(drug_level - _drug_sent_level) >= 0.04 or (drug_level <= 0.001 and _drug_sent_level > 0.001):
			if drug_id == "" or drug_level <= 0.001:
				if _drug_sent_level > 0.001 or _drug_dirty:
					q["drug"] = null
			else:
				q["drug"] = {"name": drug_id, "level": snappedf(drug_level, 0.01)}
			_drug_sent_id = drug_id
			_drug_sent_level = drug_level if drug_id != "" else 0.0
			_drug_dirty = false
		if _lesion_dirty or lesion_ids != _lesion_sent:
			q["lesion"] = lesion_ids
			_lesion_sent = lesion_ids.duplicate()
			_lesion_dirty = false
		if map_v != _srv_v:
			q["map"] = true
		sock.put_data((JSON.stringify(q) + "\n").to_utf8_buffer())
	_read()
	if _tgt.is_empty():
		status = "esperando al servidor…"
		live = false
		rate.fill(0.0)
		return
	live = true
	status = "REAL, 138.639 neuronas (t=%.1f s)" % (t_ms / 1000.0)
	# Giro y avance: respuesta del conectoma + el vagabundeo aleatorio que ya añade Fly.gd (x[75], x[76])
	var raw_turn := float(_tgt["turn"])
	if mirror:
		raw_turn = -raw_turn           # deshace el espejo: el cerebro "cree" que gira al revés
	if absf(raw_turn) < 0.1:
		raw_turn = 0.0   # zona muerta: el ruido del cerebro no debe hacerla girar sin motivo
	var turn := clampf(raw_turn + (x[76] - x[75]) * 0.8, -1.0, 1.0)
	var fwd := clampf(0.05 + float(_tgt["fwd"]) * 1.7 + float(_tgt["gf"]) * 0.3, 0.0, 1.0)
	out_turn = raw_turn
	out_fwd = float(_tgt["fwd"])
	out_gf = float(_tgt["gf"])
	out_kc = float(_tgt["kc"])
	# cerca de la fruta (olor fuerte) frena para poder encararla sin pasarse de largo ni orbitarla
	var near := smoothstep(0.15, 0.45, maxf(conc_l, conc_r))
	fwd *= lerpf(1.0, 0.5, near)
	var tg_l := maxf(0.0, -turn) * TURN_RATE
	var tg_r := maxf(0.0, turn) * TURN_RATE
	var tg_f := fwd * FWD_RATE
	# Suaviza (la respuesta llega a ~20 Hz y el juego corre a 60 Hz)
	for i in N:
		var tv: float = _view[i] if i < _view.size() else 0.0
		rate[i] = lerpf(rate[i], tv, 0.25)
	rate[75] = lerpf(rate[75], tg_l, 0.3)
	rate[76] = lerpf(rate[76], tg_r, 0.3)
	rate[77] = lerpf(rate[77], tg_f, 0.3)


## Lee las líneas JSON que haya llegado y se queda con la última.
func _read() -> void:
	var n := sock.get_available_bytes()
	if n <= 0:
		return
	var r := sock.get_data(n)
	if r[0] != OK:
		return
	_buf += (r[1] as PackedByteArray).get_string_from_utf8()
	var lines := _buf.split("\n")
	_buf = lines[lines.size() - 1]
	for k in range(lines.size() - 2, -1, -1):
		var d = JSON.parse_string(lines[k])
		if d is Dictionary:
			_tgt = d
			t_ms = float(d.get("t_ms", 0.0))
			var v: Array = d.get("view", [])
			_view.resize(v.size())
			for i in v.size():
				_view[i] = float(v[i])
			hz = float(d.get("hz", 0.0))
			_srv_v = int(d.get("lv", 0))
			if d.has("px"):
				px = _levels(str(d["px"]))
			if d.has("grid"):
				var g: Dictionary = d["grid"]
				grid_w = int(g.get("w", 0))
				grid_h = int(g.get("h", 0))
				dens = _levels(str(g.get("dens", "")))
				les_mask = _levels(str(g.get("les", "")))
				map_v = _srv_v
			break


## Convierte el texto del mapa (una letra 0-9a-z por casilla) en niveles 0..35.
func _levels(s: String) -> PackedByteArray:
	var b := s.to_ascii_buffer()
	for i in b.size():
		b[i] = b[i] - 48 if b[i] < 58 else b[i] - 87
	return b


## Al renacer: pide al servidor que apague la actividad.
func reset() -> void:
	super.reset()
	_reset = true
