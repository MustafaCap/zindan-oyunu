// Lav (Aşama 8): akan, çatlaklarından parlayan erimiş kaya. Ateş birikintileri ve Kordrak'ın lav kanalları.
// Çokgenlere (draw_colored_polygon) uygulanır: desen yerel konumdan üretilir. Işıktan etkilenmez.
shader_type canvas_item;
render_mode unshaded;
#include "res://assets/shaders/noise.gdshaderinc"

uniform float intensity : hint_range(0.0, 1.5) = 1.0;
varying vec2 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	vec2 p = lp * vec2(0.035, 0.07);
	float n = fx_fbm(p + vec2(TIME * 0.12, TIME * 0.07));
	float m = fx_fbm(p * 1.7 - vec2(TIME * 0.05, TIME * 0.11));
	float v = n * 0.65 + m * 0.35;
	vec3 crust = vec3(0.18, 0.04, 0.02);
	vec3 hot = vec3(1.0, 0.42, 0.06);
	vec3 white = vec3(1.0, 0.86, 0.45);
	vec3 col = mix(crust, hot, smoothstep(0.42, 0.58, v));
	col = mix(col, white, smoothstep(0.66, 0.8, v));
	COLOR = vec4(col * intensity, max(COLOR.a, 0.85));
}
