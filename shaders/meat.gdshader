shader_type spatial;
// 肉の見た目：赤身の筋・サシ（脂）・濡れたツヤ・半透明感。焼くと灰色→焼き色→焦げ、縮んで縁が反る。
// 面ごと（上・下）に別々の焼け具合を持つ

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
uniform float curl_dir = 1.0;   // 網に当たっている面の反対側へ反る
// 3Dモデルの肉（写真から作ったテクスチャ）を使うとき
uniform bool use_tex = false;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform float radius = 0.05;

varying vec3 lp;
varying float ny;
varying float rr;

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
	for (int k = 0; k < 5; k++) { v += a * vnoise(p); p *= 2.03; a *= 0.5; }
	return v;
}

void vertex() {
	float k = clamp(core, 0.0, 1.3);
	rr = UV2.x;
	// 火が通ると縮んで少しふくらみ、縁が反る
	VERTEX.xz *= 1.0 - 0.11 * k;
	VERTEX.y *= 1.0 + 0.18 * k;
	VERTEX.y += curl_dir * rr * rr * 0.007 * k * k;
	lp = VERTEX;
	ny = NORMAL.y;
}

vec3 cooked(vec3 base, float s, float n) {
	vec3 grey = vec3(0.26, 0.15, 0.11);
	vec3 brown = vec3(0.25, 0.11, 0.045);
	vec3 crust = vec3(0.12, 0.05, 0.02);
	vec3 charc = vec3(0.04, 0.03, 0.025);
	vec3 c = mix(base, grey * (0.85 + 0.3 * n), smoothstep(0.06, 0.5, s));
	c = mix(c, brown * (0.7 + 0.6 * n), smoothstep(0.42, 0.9, s));
	c = mix(c, crust * (0.8 + 0.4 * n), smoothstep(0.85, 1.1, s));
	c = mix(c, charc, smoothstep(1.0, 1.4, s + (n - 0.5) * 0.35));
	return c;
}

float meat_h(vec2 q) {
	// 筋（一方向に伸びた繊維）
	return fbm(q * vec2(0.6, 4.0)) * 0.6 + fbm(q * 1.7) * 0.4;
}

void fragment() {
	vec2 q = lp.xz * 60.0 + vec2(seed * 13.0, seed * 7.0);
	float m = fbm(q);
	float fiber = meat_h(q);
	// サシ：細い網目状の脂と、太めの脂の筋
	float sashi = smoothstep(0.6 - marbling * 0.22, 0.66 - marbling * 0.22, fbm(q * vec2(1.0, 2.4) + 3.1));
	float fine = smoothstep(0.72 - marbling * 0.25, 0.76 - marbling * 0.25, fbm(q * 3.2 + 9.7)) * marbling;
	float fatmask = clamp(sashi * marbling * 1.35 + fine * 0.8, 0.0, 1.0);
	vec3 red = raw_color * (0.72 + 0.5 * fiber);
	if (use_tex) {
		vec3 tc = texture(albedo_tex, UV).rgb;
		float lum = dot(tc, vec3(0.3, 0.5, 0.2));
		fatmask = smoothstep(0.5, 0.72, lum) * (1.0 - smoothstep(0.25, 0.45, tc.r - tc.g));
		red = tc;
	}
	// 写真の明るさのムラ（焼けても残す細かい模様）
	float detail = 1.0;
	if (use_tex) {
		detail = clamp(dot(texture(albedo_tex, UV).rgb, vec3(0.3, 0.5, 0.2)) * 3.0 + 0.55, 0.6, 1.5);
	}
	vec3 base = use_tex ? red : mix(red, fat_color * (0.92 + 0.1 * m), fatmask);

	float s;
	float mk;
	float through = core * 0.62;
	if (ny > 0.5) { s = max(sear_top, through); mk = mark_top; }
	else if (ny < -0.5) { s = max(sear_bottom, through); mk = mark_bottom; }
	else { s = max(core * 0.85, max(sear_top, sear_bottom) * 0.55); mk = 0.0; }
	// 焼きムラ（網の当たり方で場所ごとに違う）
	float patch = fbm(q * 0.35 + 21.0);
	float sl = s * (0.82 + 0.36 * patch);
	// 脂身は焼けると透き通って黄金色に
	vec3 fat_cooked = mix(fat_color, vec3(0.85, 0.62, 0.32), smoothstep(0.2, 0.9, sl));
	if (use_tex) { fat_cooked = mix(red, vec3(0.85, 0.62, 0.32), smoothstep(0.2, 0.9, sl)); }
	vec3 col = mix(cooked(red, sl, m) * mix(1.0, detail, smoothstep(0.05, 0.5, sl)), fat_cooked * (1.0 - smoothstep(1.0, 1.4, sl) * 0.9), fatmask * (1.0 - smoothstep(0.7, 1.2, sl) * 0.6));
	// 網の焼き目
	float stripe = smoothstep(0.8, 0.97, abs(sin(lp.x * 262.0 + sin(lp.z * 90.0) * 0.4)));
	col = mix(col, col * 0.25, stripe * clamp(mk, 0.0, 1.0) * 0.8);
	ALBEDO = col;

	// 表面の凹凸：生は繊維、焼くとカリッとした焼き面
	float e = 0.35;
	float h0 = fiber + fbm(q * 4.0) * sl * 0.8;
	float hx = meat_h(q + vec2(e, 0.0)) + fbm((q + vec2(e, 0.0)) * 4.0) * sl * 0.8;
	float hz = meat_h(q + vec2(0.0, e)) + fbm((q + vec2(0.0, e)) * 4.0) * sl * 0.8;
	float bump = 0.9 + sl * 1.4;
	NORMAL_MAP = normalize(vec3(0.5 - (hx - h0) * bump, 0.5 - (hz - h0) * bump, 1.0)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.0;

	// ツヤ：生は肉汁で濡れて、焼くと脂が浮いて光る
	float raw_wet = 1.0 - smoothstep(0.1, 0.6, s);
	float oil = clamp(fat, 0.0, 1.0) * smoothstep(0.3, 0.8, sl) * (1.0 - smoothstep(1.0, 1.35, sl));
	float wet = max(raw_wet * 0.8, oil);
	ROUGHNESS = mix(0.85, 0.18, wet * (0.55 + 0.45 * m));
	SPECULAR = 0.5 + 0.2 * fatmask;
	CLEARCOAT = wet * 0.7;
	CLEARCOAT_ROUGHNESS = 0.25;
	// 生の肉は光が少し透ける
	SSS_STRENGTH = 0.35 * raw_wet + 0.15 * fatmask;
	BACKLIGHT = raw_color * 0.12 * raw_wet;
}
