## ElementIcons — element ve hasar türü ikonlarını koddan çizer (Aşama 8'de gerçek ikonlarla değişecek).
## Ateş alevi, Su damlası, Yıldırım şimşeği, Zehir kabarcıkları, Buz kar tanesi, Karanlık hilal, Fiziksel kılıç.
## "immune" rozeti üstüne kırmızı çapraz çizgi, "weak" rozeti köşesine yeşil ok ekler.
class_name ElementIcons
extends RefCounted


## canvas: çizim yapılan CanvasItem (_draw içinde). r: rozet yarıçapı (piksel).
static func draw_badge(canvas: CanvasItem, kind: String, c: Vector2, r: float, mode: String = "") -> void:
	var col := Weapon.kind_color(kind)
	canvas.draw_circle(c, r + 1.5, Color(0, 0, 0, 0.85))
	canvas.draw_circle(c, r, Color(0.1, 0.1, 0.13, 0.95))
	canvas.draw_arc(c, r, 0, TAU, 20, col, 1.5, true)
	draw_glyph(canvas, kind, c, r * 0.72, col)
	if mode == "immune":
		var d := Vector2(r, -r) * 0.78
		canvas.draw_line(c - d, c + d, Color(0, 0, 0, 0.9), 4.0, true)
		canvas.draw_line(c - d, c + d, Color(1.0, 0.25, 0.2), 2.2, true)
	elif mode == "weak":
		var a := c + Vector2(r * 0.85, -r * 0.85)
		canvas.draw_colored_polygon(PackedVector2Array([a + Vector2(0, -4), a + Vector2(4, 2), a + Vector2(-4, 2)]), Color(0.4, 1.0, 0.45))


static func draw_glyph(canvas: CanvasItem, kind: String, c: Vector2, s: float, col: Color) -> void:
	match kind:
		"fire":
			var pts := PackedVector2Array([
				c + Vector2(0, -s), c + Vector2(s * 0.35, -s * 0.2), c + Vector2(s * 0.55, -s * 0.55),
				c + Vector2(s * 0.7, s * 0.3), c + Vector2(0, s), c + Vector2(-s * 0.7, s * 0.3),
				c + Vector2(-s * 0.5, -s * 0.35), c + Vector2(-s * 0.2, -s * 0.1)])
			canvas.draw_colored_polygon(pts, col)
		"water":
			var drop := PackedVector2Array([c + Vector2(0, -s)])
			for i: int in 13:
				var a := -PI * 0.25 + (PI * 1.5) * i / 12.0
				drop.append(c + Vector2(0, s * 0.3) + Vector2(cos(a), sin(a)) * s * 0.62)
			canvas.draw_colored_polygon(drop, col)
		"lightning":
			var bolt := PackedVector2Array([
				c + Vector2(s * 0.25, -s), c + Vector2(-s * 0.45, s * 0.1), c + Vector2(-s * 0.02, s * 0.1),
				c + Vector2(-s * 0.25, s), c + Vector2(s * 0.45, -s * 0.15), c + Vector2(s * 0.02, -s * 0.15)])
			canvas.draw_colored_polygon(bolt, col)
		"poison":
			canvas.draw_circle(c + Vector2(-s * 0.3, s * 0.3), s * 0.42, col)
			canvas.draw_circle(c + Vector2(s * 0.38, s * 0.1), s * 0.3, col)
			canvas.draw_circle(c + Vector2(0, -s * 0.5), s * 0.24, col)
		"ice":
			for i: int in 3:
				var d := Vector2.UP.rotated(PI / 3.0 * i) * s
				canvas.draw_line(c - d, c + d, col, 2.0, true)
		"dark":
			canvas.draw_circle(c, s * 0.85, col)
			canvas.draw_circle(c + Vector2(s * 0.4, -s * 0.25), s * 0.7, Color(0.1, 0.1, 0.13))
		"rot":
			canvas.draw_circle(c, s * 0.7, col)
			canvas.draw_circle(c + Vector2(-s * 0.2, -s * 0.1), s * 0.18, Color(0.1, 0.1, 0.13))
			canvas.draw_circle(c + Vector2(s * 0.25, -s * 0.1), s * 0.18, Color(0.1, 0.1, 0.13))
		"steam":
			for i: int in 3:
				var x := (i - 1) * s * 0.45
				canvas.draw_arc(c + Vector2(x, 0), s * 0.35, -PI * 0.5, PI * 0.5, 6, col, 1.6)
		_:
			# Fiziksel: kılıç
			canvas.draw_line(c + Vector2(-s * 0.7, s * 0.7), c + Vector2(s * 0.75, -s * 0.75), col, 2.4, true)
			canvas.draw_line(c + Vector2(-s * 0.55, s * 0.05), c + Vector2(-s * 0.05, s * 0.55), col, 2.0, true)


## Durum ikonlarının rengi (element ya da kombo durumu).
static func status_color(status_id: String) -> Color:
	match status_id:
		"rot": return Color(str(Combos.by_id("rot")["color"]))
		"steam": return Color(str(Combos.by_id("steam")["color"]))
	return Weapon.kind_color(status_id)
