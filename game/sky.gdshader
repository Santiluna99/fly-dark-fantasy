// Hollowfly - Copyright (C) 2026 Santiluna99
// Software libre bajo la GNU GPL v3 (ver LICENSE y NOTICE).
// SHADER DE CIELO con ciclo día/noche: degradado cenit->horizonte, nubes que se estiran al horizonte,
// estrellas (solo de noche), sol con halo y luna creciente. Los colores los anima daynight.gd según la hora.
shader_type sky;

uniform vec3 sky_top = vec3(0.008, 0.012, 0.03);
uniform vec3 sky_hor = vec3(0.14, 0.165, 0.165);
uniform vec3 cloud_col = vec3(0.16, 0.2, 0.23);
uniform vec3 sun_col = vec3(1.0, 0.9, 0.7);
uniform float star_amt = 1.0;
uniform float moon_amt = 1.0;
uniform float sun_amt = 0.0;
uniform vec3 sun_dir = vec3(0.0, -1.0, 0.0);
uniform vec3 moon_dir = vec3(-0.5, 0.42, -0.75);

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Se ejecuta por cada dirección de la bóveda celeste (EYEDIR).
void sky() {
	vec3 d = normalize(EYEDIR);
	float up = clamp(d.y, 0.0, 1.0);
	vec3 col = mix(sky_hor, sky_top, pow(up, 0.45));
	// halo del sol sobre el horizonte
	vec3 sd = normalize(sun_dir);
	float sa = max(dot(d, sd), 0.0);
	col += sun_col * (pow(sa, 6.0) * 0.18 + pow(sa, 40.0) * 0.45) * sun_amt;
	// nubes que se estiran hacia el horizonte
	vec2 cp = d.xz / (abs(d.y) + 0.3) * 1.5;
	float cl = vn(cp * 1.2 + vec2(TIME * 0.01, 0.0)) * 0.55 + vn(cp * 2.8 - vec2(TIME * 0.015, 0.0)) * 0.3 + vn(cp * 6.0) * 0.15;
	float m = smoothstep(0.48, 0.78, cl) * smoothstep(-0.02, 0.25, d.y);
	col = mix(col, cloud_col * (0.4 + 0.9 * cl), m * 0.8);
	// estrellas
	vec2 su = vec2(atan(d.x, d.z) * 130.0, d.y * 260.0);
	vec2 sf = fract(su) - 0.5;
	float st = step(0.993, h21(floor(su))) * smoothstep(0.2, 0.05, length(sf)) * smoothstep(0.02, 0.3, d.y) * (1.0 - m);
	col += vec3(0.8, 0.9, 1.0) * st * 0.9 * star_amt;
	// disco solar
	float disc_s = smoothstep(0.9975, 0.9985, dot(d, sd));
	col = mix(col, sun_col * 2.2, disc_s * sun_amt * (1.0 - m * 0.7));
	// luna creciente con halo
	vec3 md = normalize(moon_dir);
	float ca = dot(d, md);
	vec3 side = normalize(cross(vec3(0.0, 1.0, 0.0), md));
	vec3 md2 = normalize(md + side * 0.075 + vec3(0.0, 0.01, 0.0));
	float disc = smoothstep(0.9935, 0.9945, ca);
	float disc2 = smoothstep(0.9935, 0.9945, dot(d, md2));
	float crescent = disc * (1.0 - disc2);
	float halo = pow(max(ca, 0.0), 40.0);
	col += (vec3(0.9, 0.92, 0.85) * crescent * 2.2 + vec3(0.22, 0.28, 0.3) * halo * 0.7) * moon_amt;
	COLOR = col;
}
