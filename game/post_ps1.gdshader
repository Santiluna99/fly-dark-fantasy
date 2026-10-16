// Hollowfly - Copyright (C) 2026 Santiluna99
// Software libre bajo la GNU GPL v3 (ver LICENSE y NOTICE).
// POST-PROCESO PS1 / DARK FANTASY: paleta reducida con dithering ordenado (Bayer 4x4), viñeta oscura,
// grano de película y un ligero tinte verde-ceniza en sombras. Se dibuja sobre la imagen 3D, debajo del HUD.
shader_type canvas_item;
uniform sampler2D scr : hint_screen_texture, filter_nearest;
uniform float levels = 22.0;     // niveles por canal (PS1 ≈ 32 por 5 bits; menos = más posterizado)
uniform float dither = 1.0;
uniform float vignette = 0.75;
uniform float grain = 0.035;

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int i = x + y * 4;
	float m[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return m[i] / 16.0 - 0.5;
}
float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	vec2 px = floor(FRAGCOORD.xy);
	vec3 c = texture(scr, SCREEN_UV).rgb;
	// sombras hacia verde-ceniza, luces cálidas intactas
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, c * vec3(0.9, 1.0, 0.96), (1.0 - smoothstep(0.0, 0.35, l)) * 0.6);
	// azules fríos -> gris verdoso (agua, tejados); los cálidos (antorchas, ventanas) se conservan
	float bl = clamp((c.b - max(c.r, c.g)) * 3.0, 0.0, 1.0);
	c = mix(c, vec3(l * 1.05, l * 1.1, l * 1.0) + vec3(0.0, 0.01, 0.0), bl * 0.7);
	// grano
	c += (h21(px + floor(TIME * 12.0)) - 0.5) * grain;
	// cuantización con dithering
	c = floor(c * levels + 0.5 + bayer4(px) * dither) / levels;
	// viñeta
	vec2 q = SCREEN_UV - 0.5;
	c *= 1.0 - vignette * dot(q, q) * 1.6;
	COLOR = vec4(c, 1.0);
}
