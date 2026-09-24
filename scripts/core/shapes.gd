## Shapes — çarpışma şekli ve çizim için ortak yardımcılar.
class_name Shapes
extends RefCounted


## Ekran uzayında izometrik elips (zemindeki yuvarlak bir tabanın görünüşü).
static func iso_ellipse(radius_tiles: float, segments: int = 12) -> PackedVector2Array:
	var r := Iso.tiles(radius_tiles)
	var pts := PackedVector2Array()
	for i: int in segments:
		var a := TAU * i / float(segments)
		pts.append(Iso.to_screen(Vector2(cos(a), sin(a)) * r))
	return pts


## Zemindeki bir yay (dilim) poligonu, ekran uzayında. Merkez (0,0).
static func iso_arc(facing_cart: Vector2, radius_tiles: float, arc_degrees: float,
		inner_tiles: float = 0.0, segments: int = 18) -> PackedVector2Array:
	var r := Iso.tiles(radius_tiles)
	var ri := Iso.tiles(inner_tiles)
	var base := facing_cart.angle()
	var half := deg_to_rad(minf(arc_degrees, 360.0)) * 0.5
	var pts := PackedVector2Array()
	for i: int in segments + 1:
		var a := base - half + (2.0 * half) * i / float(segments)
		pts.append(Iso.to_screen(Vector2(cos(a), sin(a)) * r))
	for i: int in range(segments, -1, -1):
		var a := base - half + (2.0 * half) * i / float(segments)
		pts.append(Iso.to_screen(Vector2(cos(a), sin(a)) * ri))
	return pts
