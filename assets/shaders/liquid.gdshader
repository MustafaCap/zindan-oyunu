// Sıvı (Aşama 8): dalgalanan, parıldayan birikinti (zehir: yeşil, su: mavi). Çokgenlere uygulanır, ışıktan etkilenmez.
shader_type canvas_item;
render_mode unshaded;
#include "res://assets/shaders/noise.gdshaderinc"

uniform vec4 tint : source_color = vec4(0.4, 0.8, 0.2, 1.0);
varying vec2 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	float n = fx_fbm(lp * vec2(0.05, 0.1) + vec2(TIME * 0.15, -TIME * 0.1));
	float ripple = sin(lp.x * 0.09 + lp.y * 0.18 + TIME * 2.2 + n * 7.0) * 0.5 + 0.5;
	vec3 col = tint.rgb * (0.55 + 0.6 * n) + vec3(pow(ripple, 10.0)) * 0.45;
	COLOR = vec4(col, max(COLOR.a, 0.62));
}
