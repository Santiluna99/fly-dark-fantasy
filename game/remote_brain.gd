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


## Intenta conectar con el servidor.
func start(p: int = 9009) -> void:
	port = p
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
		var q := {"orn": [orr, ol] if mirror else [ol, orr], "loom": [x[3], x[2]] if mirror else [x[2], x[3]], "hunger": x[4] / 0.3, "reset": _reset}
		_reset = false
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
			break


## Al renacer: pide al servidor que apague la actividad.
func reset() -> void:
	super.reset()
	_reset = true
