// Duvar arkası silüeti (Aşama 8): sprite'ın şekli tek renkle (yarı saydam) çizilir; ışıktan etkilenmez.
shader_type canvas_item;
render_mode unshaded;

uniform vec4 fill : source_color = vec4(0.6, 0.85, 1.0, 0.35);

void fragment() {
	float a = texture(TEXTURE, UV).a;
	COLOR = vec4(fill.rgb, fill.a * step(0.5, a));
}
