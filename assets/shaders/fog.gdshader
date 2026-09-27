// Sis (Aşama 8): yavaşça sürüklenen, delikli bulut (spor bulutu, boşluk yırtığı, oda sisi). Işıktan etkilenmez.
shader_type canvas_item;
render_mode unshaded;
#include "res://assets/shaders/noise.gdshaderinc"

uniform vec4 tint : source_color = vec4(0.6, 0.9, 0.4, 1.0);
uniform float density : hint_range(0.0, 2.0) = 1.0;
varying vec2 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	float n = fx_fbm(lp * vec2(0.025, 0.05) + vec2(TIME * 0.09, -TIME * 0.06));
	float m = fx_fbm(lp * vec2(0.05, 0.1) - vec2(TIME * 0.05, TIME * 0.04));
	float a = smoothstep(0.3, 0.72, n * 0.7 + m * 0.3) * density;
	COLOR = vec4(tint.rgb * (0.8 + 0.4 * m), clamp(COLOR.a * 1.6 * a, 0.0, 0.9));
}
