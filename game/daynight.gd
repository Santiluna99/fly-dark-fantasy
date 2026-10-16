class_name DayNight extends Node
## CICLO DE DÍA Y NOCHE. La hora (0-24) interpola entre fotogramas clave que definen cielo, sol/luna,
## luz ambiente, niebla, saturación y lluvia. Teclas: T = siguiente momento (mañana/día/tarde/noche), Y = tiempo automático.

const PRESETS := ["Mañana", "Día", "Tarde", "Noche"]
const PRESET_HOUR := [7.8, 13.0, 17.8, 23.5]
# Fotogramas clave: hora, cenit, horizonte, nubes, estrellas, luz (color, energía), ambiente (color, energía),
# niebla (color, densidad), saturación, brillo, lluvia (0/1), "noche" (0-1: cuánto brillan antorchas y ventanas).
const KEYS := [
	{"h": 0.0, "top": Color(.008, .012, .03), "hor": Color(.14, .165, .165), "cl": Color(.16, .2, .23), "st": 1.0, "lc": Color(.62, .72, .8), "le": .8, "ac": Color(.2, .24, .26), "ae": 1.6, "fc": Color(.13, .15, .15), "fd": .013, "sat": .62, "br": .95, "rain": 1.0, "night": 1.0},
	{"h": 5.0, "top": Color(.01, .015, .035), "hor": Color(.15, .17, .17), "cl": Color(.17, .2, .23), "st": 1.0, "lc": Color(.62, .72, .8), "le": .8, "ac": Color(.2, .24, .26), "ae": 1.6, "fc": Color(.13, .15, .15), "fd": .013, "sat": .62, "br": .95, "rain": 1.0, "night": 1.0},
	{"h": 6.6, "top": Color(.16, .2, .28), "hor": Color(.62, .46, .38), "cl": Color(.68, .5, .42), "st": .15, "lc": Color(.95, .62, .45), "le": .9, "ac": Color(.3, .3, .32), "ae": 1.5, "fc": Color(.5, .42, .38), "fd": .018, "sat": .72, "br": 1.0, "rain": 0.0, "night": .6},
	{"h": 8.5, "top": Color(.3, .4, .5), "hor": Color(.62, .66, .62), "cl": Color(.78, .78, .74), "st": 0.0, "lc": Color(1, .9, .72), "le": 1.25, "ac": Color(.38, .4, .4), "ae": 1.6, "fc": Color(.6, .64, .62), "fd": .013, "sat": .72, "br": 1.0, "rain": 0.0, "night": .25},
	{"h": 13.0, "top": Color(.27, .41, .57), "hor": Color(.66, .72, .72), "cl": Color(.86, .87, .85), "st": 0.0, "lc": Color(1, .97, .88), "le": 2.1, "ac": Color(.5, .54, .56), "ae": 2.3, "fc": Color(.63, .69, .69), "fd": .006, "sat": .85, "br": 1.08, "rain": 0.0, "night": .1},
	{"h": 17.0, "top": Color(.3, .36, .46), "hor": Color(.72, .62, .48), "cl": Color(.9, .72, .55), "st": 0.0, "lc": Color(1, .74, .45), "le": 1.5, "ac": Color(.42, .38, .34), "ae": 1.8, "fc": Color(.62, .52, .42), "fd": .01, "sat": .78, "br": 1.0, "rain": 0.0, "night": .25},
	{"h": 19.2, "top": Color(.14, .14, .24), "hor": Color(.8, .4, .22), "cl": Color(.85, .4, .28), "st": .15, "lc": Color(1, .5, .25), "le": .85, "ac": Color(.28, .24, .28), "ae": 1.5, "fc": Color(.42, .26, .2), "fd": .015, "sat": .8, "br": .98, "rain": 0.0, "night": .65},
	{"h": 20.8, "top": Color(.03, .04, .1), "hor": Color(.28, .2, .24), "cl": Color(.2, .18, .22), "st": .7, "lc": Color(.6, .58, .72), "le": .65, "ac": Color(.2, .2, .26), "ae": 1.6, "fc": Color(.16, .14, .17), "fd": .014, "sat": .66, "br": .95, "rain": 1.0, "night": .92},
	{"h": 24.0, "top": Color(.008, .012, .03), "hor": Color(.14, .165, .165), "cl": Color(.16, .2, .23), "st": 1.0, "lc": Color(.62, .72, .8), "le": .8, "ac": Color(.2, .24, .26), "ae": 1.6, "fc": Color(.13, .15, .15), "fd": .013, "sat": .62, "br": .95, "rain": 1.0, "night": 1.0},
]

var hour := 23.5            # hora actual (0-24)
var auto := false           # ¿avanza sola?
var hours_per_sec := 0.05   # 1 hora de juego cada 20 s
var night := 1.0            # 0 = pleno día, 1 = noche (lo usan las antorchas)
var rain_on := true         # lluvia según el momento (se puede cambiar con R)
var rain_auto := true
var env: Environment
var sky_mat: ShaderMaterial
var sun: DirectionalLight3D
var rain_node: GPUParticles3D
var _target := -1.0


## Recibe los objetos que controla.
func setup(e: Environment, sm: ShaderMaterial, light: DirectionalLight3D, rain: GPUParticles3D) -> void:
	env = e
	sky_mat = sm
	sun = light
	rain_node = rain
	apply()


## Salta (con transición suave) a Mañana / Día / Tarde / Noche.
func set_preset(i: int) -> void:
	_target = PRESET_HOUR[i]


## Pasa al siguiente momento del día.
func next_preset() -> void:
	var cur := 0
	var best := 99.0
	for i in 4:
		var d := absf(fposmod(hour - PRESET_HOUR[i] + 12.0, 24.0) - 12.0)
		if d < best:
			best = d
			cur = i
	set_preset((cur + 1) % 4)


func preset_name() -> String:
	if hour >= 5.5 and hour < 10.5: return PRESETS[0]
	if hour >= 10.5 and hour < 15.5: return PRESETS[1]
	if hour >= 15.5 and hour < 19.8: return PRESETS[2]
	return PRESETS[3]


func clock() -> String:
	return "%02d:%02d" % [int(hour) % 24, int(fmod(hour, 1.0) * 60.0)]


func _process(dt: float) -> void:
	var real_dt := dt / maxf(Engine.time_scale, 0.001)
	if _target >= 0.0:
		var diff := fposmod(_target - hour + 12.0, 24.0) - 12.0
		var step := signf(diff) * minf(absf(diff), 9.0 * real_dt)   # transición rápida (9 h/s)
		hour = fposmod(hour + step, 24.0)
		if absf(diff) < 0.02:
			_target = -1.0
	elif auto:
		hour = fposmod(hour + hours_per_sec * real_dt, 24.0)
	apply()


func _lerp_key(k: String, a: Dictionary, b: Dictionary, t: float):
	return lerp(a[k], b[k], t)


## Calcula y aplica todos los parámetros para la hora actual.
func apply() -> void:
	var a: Dictionary = KEYS[0]
	var b: Dictionary = KEYS[1]
	for i in KEYS.size() - 1:
		if hour >= KEYS[i]["h"] and hour <= KEYS[i + 1]["h"]:
			a = KEYS[i]
			b = KEYS[i + 1]
			break
	var t := smoothstep(0.0, 1.0, inverse_lerp(a["h"], b["h"], hour))
	var top: Color = a["top"].lerp(b["top"], t)
	var hor: Color = a["hor"].lerp(b["hor"], t)
	var cl: Color = a["cl"].lerp(b["cl"], t)
	var st: float = lerpf(a["st"], b["st"], t)
	var lc: Color = a["lc"].lerp(b["lc"], t)
	var le: float = lerpf(a["le"], b["le"], t)
	night = lerpf(a["night"], b["night"], t)
	# posición del sol (arco de este a oeste entre las 6 y las 18) y de la luna (opuesta)
	var ang := (hour - 6.0) / 12.0 * PI
	var sun_dir := Vector3(cos(ang) * 0.9, sin(ang), -0.35).normalized()
	var day_f := clampf(sun_dir.y * 4.0 + 0.4, 0.0, 1.0)       # el sol sobre el horizonte
	var moon_dir := Vector3(-sun_dir.x, maxf(0.25, -sun_dir.y), sun_dir.z).normalized()
	sky_mat.set_shader_parameter("sky_top", Vector3(top.r, top.g, top.b))
	sky_mat.set_shader_parameter("sky_hor", Vector3(hor.r, hor.g, hor.b))
	sky_mat.set_shader_parameter("cloud_col", Vector3(cl.r, cl.g, cl.b))
	sky_mat.set_shader_parameter("star_amt", st)
	sky_mat.set_shader_parameter("sun_dir", sun_dir)
	sky_mat.set_shader_parameter("sun_amt", day_f)
	sky_mat.set_shader_parameter("sun_col", Vector3(lc.r, lc.g, lc.b) * 1.1)
	sky_mat.set_shader_parameter("moon_dir", moon_dir)
	sky_mat.set_shader_parameter("moon_amt", clampf(st * 1.5, 0.0, 1.0))
	# luz direccional: sol de día, luna de noche
	var ldir := sun_dir if sun_dir.y > 0.05 else moon_dir
	sun.light_color = lc
	sun.light_energy = le
	sun.global_transform = Transform3D(Basis.looking_at(-ldir, Vector3.UP), Vector3.ZERO)
	env.ambient_light_color = a["ac"].lerp(b["ac"], t)
	env.ambient_light_energy = lerpf(a["ae"], b["ae"], t)
	env.fog_light_color = a["fc"].lerp(b["fc"], t)
	env.fog_density = lerpf(a["fd"], b["fd"], t)
	env.adjustment_saturation = lerpf(a["sat"], b["sat"], t)
	env.adjustment_brightness = lerpf(a["br"], b["br"], t)
	if rain_auto and rain_node:
		rain_on = lerpf(a["rain"], b["rain"], t) > 0.5
	if rain_node:
		rain_node.emitting = rain_on
