// Karakter shader'ı (vuruş flaşı + Aşama 8: malzeme tonu, eriyerek ölme ve dış hat).
// flash = 1 iken çizim tamamen flash_color olur (varsayılan beyaz).
// tint_amount > 0: renk, parlaklığı korunarak tint rengine çekilir (taş, alevli, zehirli, hayalet varyantları).
// dissolve 0 → 1: gürültüye göre pikseller kaybolur; kaybolma kenarı edge_color renginde yanar (eriyerek ölme).
// Godot 4'te parça (fragment) COLOR'u zaten doku rengi × modulate'tir (doku ikinci kez çarpılmaz).
shader_type canvas_item;

uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float tint_amount : hint_range(0.0, 1.0) = 0.0;
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform vec4 edge_color : source_color = vec4(0.6, 0.05, 0.03, 1.0);
// Dış hat (elit: aura rengi, öncelikli hedef: sarı). outline_width doku pikseli; 0 = kapalı.
uniform vec4 outline_color : source_color = vec4(1.0, 0.8, 0.2, 1.0);
uniform float outline_width = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec4 c = COLOR;
	bool rim = false;
	if (outline_width > 0.0 && c.a < 0.5) {
		vec2 px = TEXTURE_PIXEL_SIZE * outline_width;
		float na = max(max(texture(TEXTURE, UV + vec2(px.x, 0.0)).a, texture(TEXTURE, UV - vec2(px.x, 0.0)).a),
			max(texture(TEXTURE, UV + vec2(0.0, px.y)).a, texture(TEXTURE, UV - vec2(0.0, px.y)).a));
		rim = na > 0.5;
	}
	if (tint_amount > 0.0) {
		float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
		c.rgb = mix(c.rgb, lum * tint.rgb * 1.5, tint_amount);
	}
	if (dissolve > 0.0) {
		float n = noise(UV / TEXTURE_PIXEL_SIZE * 0.08) * 0.7 + noise(UV / TEXTURE_PIXEL_SIZE * 0.3) * 0.3;
		if (n < dissolve) {
			discard;
		}
		c.rgb = mix(c.rgb, edge_color.rgb, smoothstep(0.08, 0.0, n - dissolve));
	}
	if (rim) {
		c = outline_color;
	}
	COLOR = vec4(mix(c.rgb, flash_color.rgb, flash), c.a);
}
