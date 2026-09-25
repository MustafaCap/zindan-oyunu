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


## Zemindeki dikdörtgen şerit (ışın, atılma yolu, lav kanalı), ekran uzayında. Merkez (0,0)'dan dir yönünde
## start_tiles'tan başlayıp length_tiles uzar; genişliği width_tiles.
static func iso_rect(dir_cart: Vector2, length_tiles: float, width_tiles: float, start_tiles: float = 0.0) -> PackedVector2Array:
	var d := dir_cart.normalized()
	var n := d.orthogonal() * Iso.tiles(width_tiles) * 0.5
	var a := d * Iso.tiles(start_tiles)
	var b := d * Iso.tiles(start_tiles + length_tiles)
	return PackedVector2Array([Iso.to_screen(a + n), Iso.to_screen(b + n), Iso.to_screen(b - n), Iso.to_screen(a - n)])


## Zemindeki halka (iç ve dış yarıçap), ekran uzayında tek poligon.
static func iso_ring(inner_tiles: float, outer_tiles: float, segments: int = 32) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i: int in segments + 1:
		var a := TAU * i / float(segments)
		pts.append(Iso.to_screen(Vector2(cos(a), sin(a)) * Iso.tiles(outer_tiles)))
	for i: int in range(segments, -1, -1):
		var a := TAU * i / float(segments)
		pts.append(Iso.to_screen(Vector2(cos(a), sin(a)) * Iso.tiles(maxf(inner_tiles, 0.01))))
	return pts


## Düz uzayda p noktasının a→b doğru parçasına uzaklığı (karo cinsinden değil, aynı birimde).
static func segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := 0.0 if ab.length_squared() < 0.0001 else clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)
