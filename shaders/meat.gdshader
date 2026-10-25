shader_type spatial;
// 肉の焼き色：生 → 灰色っぽく火が通る → こんがり → 焦げ。面ごと（上・下）に別々の焼け具合を持つ

uniform vec3 raw_color : source_color = vec3(0.7, 0.2, 0.2);
uniform vec3 fat_color : source_color = vec3(0.95, 0.86, 0.82);
uniform float marbling = 0.3;
uniform float sear_top = 0.0;
uniform float sear_bottom = 0.0;
uniform float mark_top = 0.0;
uniform float mark_bottom = 0.0;
uniform float core = 0.0;
uniform float fat = 1.0;
uniform float seed = 0.0;
uniform float dirty = 0.0;

varying vec3 lp;
varying float ny;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int k = 0; k < 4; k++) { v += a * vnoise(p); p *= 2.03; a *= 0.5; }
	return v;
}

void vertex() {
	lp = VERTEX;
	ny = NORMAL.y;
}

vec3 cooked(vec3 base, float s, float n) {
	vec3 grey = vec3(0.52, 0.36, 0.28);
	vec3 brown = vec3(0.42, 0.21, 0.09);
	vec3 charc = vec3(0.045, 0.032, 0.028);
	vec3 c = mix(base, grey * (0.9 + 0.2 * n), smoothstep(0.08, 0.5, s));
	c = mix(c, brown * (0.75 + 0.5 * n), smoothstep(0.45, 0.95, s));
	c = mix(c, charc, smoothstep(0.95, 1.35, s + (n - 0.5) * 0.3));
	return c;
}

void fragment() {
	vec2 q = lp.xz * 55.0 + vec2(seed * 13.0, seed * 7.0);
	float m = fbm(q);
	float streak = smoothstep(0.58 - marbling * 0.2, 0.66 - marbling * 0.2, fbm(q * vec2(1.0, 2.6) + 3.1));
	vec3 base = mix(raw_color * (0.82 + 0.36 * m), fat_color, clamp(streak * marbling * 1.3, 0.0, 1.0));
	float s;
	float mk;
	// 網に当たっていない面も、中まで火が通るにつれて色が変わる
	float through = core * 0.62;
	if (ny > 0.5) { s = max(sear_top, through); mk = mark_top; }
	else if (ny < -0.5) { s = max(sear_bottom, through); mk = mark_bottom; }
	else { s = max(core * 0.85, max(sear_top, sear_bottom) * 0.55); mk = 0.0; }
	vec3 col = cooked(base, s, m);
	float stripe = smoothstep(0.82, 0.97, abs(sin(lp.x * 262.0)));
	col = mix(col, col * 0.22, stripe * clamp(mk, 0.0, 1.0) * 0.9);
	ALBEDO = col;
	float wet = clamp(fat, 0.0, 1.0) * (1.0 - smoothstep(0.9, 1.3, s));
	ROUGHNESS = mix(0.8, 0.22, wet * (0.6 + 0.4 * m));
	SPECULAR = 0.55;
	BACKLIGHT = raw_color * 0.15 * (1.0 - smoothstep(0.1, 0.6, s));
}
