// Hollowfly - Copyright (C) 2026 Santiluna99
// Software libre bajo la GNU GPL v3 (ver LICENSE y NOTICE).
// SHADER PS1: da el aspecto de PlayStation 1 a todo el juego.
//  - Los vértices se "pegan" a una rejilla de pantalla (el temblor típico de PS1).
//  - La paleta se reduce (posterizado) y las texturas no se suavizan.
//  - "pattern" elige el aspecto: 0 ruido, 1 ladrillo, 2 cascada, 3 relieve, 4 agua, 5 textura PNG, 6 terreno.
shader_type spatial;
render_mode cull_back, specular_disabled, vertex_lighting, diffuse_lambert;

uniform vec4 tint : source_color = vec4(1.0);
uniform float snap = 80.0;   // baja = más "temblor" PS1
uniform float grain = 0.35;
uniform float emit = 0.0;
uniform float texscale = 1.5;
uniform bool object_space = false;
uniform int pattern = 0;     // 0 ruido · 1 ladrillos · 2 cascada · 3 relieve · 4 agua · 5 textura · 6 terreno · 7 color de vértice (personajes .glb)
uniform sampler2D tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D tex2 : source_color, filter_nearest_mipmap, repeat_enable;
uniform float tex_scale = 0.25;
uniform float tex_gain = 1.0;
varying vec3 wpos;
varying vec3 lpos;
varying vec3 wn;
varying vec3 ln;

// Número aleatorio estable a partir de una coordenada 2D.
float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Ruido de valor suave (interpolado) 2D.
float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Textura "triplanar": proyecta la textura por los 3 ejes y mezcla según la normal (sin estirarse en paredes).
vec3 tri(sampler2D t, vec3 p, vec3 n, float sc) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z + 0.0001);
	return texture(t, p.zy * sc).rgb * w.x + texture(t, p.xz * sc).rgb * w.y + texture(t, p.xy * sc).rgb * w.z;
}

// Etapa de vértices: aplica el temblor PS1 y pasa posición/normal en mundo y en local al fragmento.
void vertex() {
	// Vertex snapping: los vértices se redondean a una rejilla de pantalla
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 ndc = clip.xyz / clip.w;
	ndc.xy = floor(ndc.xy * snap + 0.5) / snap;
	POSITION = vec4(ndc * clip.w, clip.w);
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	lpos = VERTEX;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	ln = NORMAL;
}

// Etapa de píxel: calcula el color según "pattern", lo posteriza y lo emite (EMISSION) si es luminoso.
void fragment() {
	vec3 c = tint.rgb * COLOR.rgb;
	float em7 = 0.0;   // brillo propio de las zonas muy claras en el patrón 7
	if (pattern == 1) {
		// Mampostería: ladrillos con juntas, variación por pieza, bisel y musgo
		vec3 an = abs(wn);
		vec2 uv = an.y > 0.7 ? wpos.xz : (an.x > an.z ? wpos.zy : wpos.xy);
		float row = floor(uv.y / 0.5);
		float bx = uv.x + mod(row, 2.0) * 0.5;
		vec2 id = vec2(floor(bx), row);
		float fx = fract(bx);
		float fy = fract(uv.y / 0.5);
		float mortar = (fx < 0.08 || fy < 0.14) ? 1.0 : 0.0;
		float v = h21(id);
		vec3 b = tint.rgb * (0.6 + 0.8 * v);
		b *= 0.78 + 0.44 * h21(floor(uv * 7.0));
		b *= 1.0 + 0.3 * step(0.8, fy) * (1.0 - mortar);
		b = mix(b, vec3(0.12, 0.3, 0.1) * (0.6 + v), step(0.85, h21(id + 3.0)) * 0.65);
		c = mix(b, tint.rgb * 0.18, mortar);
	} else if (pattern == 2) {
		// Cascada: vetas que caen
		float u = (wpos.x + wpos.z) * 5.0;
		float s = h21(vec2(floor(u), floor(wpos.y * 2.5 + TIME * 7.0)));
		float s2 = h21(vec2(floor(u * 0.5) + 9.0, floor(wpos.y * 1.2 + TIME * 4.0)));
		c = tint.rgb * (0.4 + 1.5 * s * s2 + 0.3 * s);
	} else if (pattern == 3) {
		// Relieve: ruido suave multi-escala + vetas, para romper las caras planas
		vec2 p = wpos.xz + vec2(wpos.y * 0.7, wpos.y * 0.4);
		float n = vn(p * 0.35) * 0.5 + vn(p * 1.3) * 0.3 + vn(p * 4.0) * 0.2;
		float vein = vn(vec2(p.x * 0.5, wpos.y * 3.0 + p.y * 0.2));
		c *= (0.5 + 1.0 * n) * (0.85 + 0.3 * vein);
		c *= 0.9 + 0.2 * h21(floor(wpos.xz * 3.0 + wpos.y));
	} else if (pattern == 7) {
		// Personaje exportado desde Blender: el color ya viene pintado por vértice; lo muy brillante (ojos, libro) emite luz
		c = pow(tint.rgb * COLOR.rgb, vec3(0.72));   // levanta los tonos oscuros sin perder el tono de color
		em7 = 0.55 + smoothstep(0.55, 0.9, max(c.r, max(c.g, c.b))) * 1.4;   // luz propia mínima + brillo en zonas claras
	} else if (pattern == 5) {
		vec3 p5 = object_space ? lpos : wpos;
		vec3 n5 = object_space ? ln : wn;
		c = tint.rgb * COLOR.rgb * tri(tex, p5, n5, tex_scale) * tex_gain;
	} else if (pattern == 6) {
		// Terreno: el color viene del vértice; las texturas aportan el detalle de luminancia
		float steep = smoothstep(0.35, 0.65, 1.0 - abs(wn.y));
		vec3 ta = tri(tex, wpos, wn, tex_scale);
		vec3 tb = tri(tex2, wpos, wn, tex_scale * 0.5);
		float lum = mix(dot(ta, vec3(0.333)), dot(tb, vec3(0.333)), steep);
		c = COLOR.rgb * (0.25 + 2.0 * lum * tex_gain);
	} else if (pattern == 4) {
		// Agua: un solo color, con manchas muy suaves y grandes que se mueven despacio y un brillo mínimo
		vec2 p = wpos.xz;
		float n1 = vn(p * 0.06 + vec2(TIME * 0.02, TIME * 0.012));
		float n2 = vn(p * 0.17 - vec2(TIME * 0.03, -TIME * 0.02));
		float m = 0.94 + 0.12 * (n1 * 0.65 + n2 * 0.35);
		float glint = smoothstep(0.86, 1.0, vn(p * 0.8 + vec2(TIME * 0.15, TIME * 0.1))) * 0.04;
		c = tint.rgb * m + vec3(0.05, 0.1, 0.14) * glint;
	} else {
		// Textura pixelada procedural (sin filtrar) anclada al mundo u objeto
		vec3 q = floor((object_space ? lpos : wpos) * texscale);
		float n = fract(sin(dot(q, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
		vec3 q2 = floor(q * 0.5) + 7.0;
		float n2 = fract(sin(dot(q2, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
		c *= 1.0 - grain + grain * (1.2 * n + 0.8 * n2);
	}
	// Posterizado (paleta reducida)
	c = floor(c * 24.0) / 24.0;
	ALBEDO = c;
	EMISSION = c * (emit + em7);
}
