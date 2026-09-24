## SlashFx — kılıç izi: zeminde parlayıp sönen bir yay (normal vuruş) ya da halka (Dönen kesik).
extends Node2D

const LIFETIME := 0.16

var _facing: Vector2 = Vector2.RIGHT
var _radius: float = 1.5
var _arc: float = 110.0
var _heavy: bool = false
var _t: float = 0.0


func setup(facing_cart: Vector2, radius_tiles: float, arc_degrees: float, heavy: bool) -> void:
	_facing = facing_cart
	_radius = radius_tiles
	_arc = arc_degrees
	_heavy = heavy
	z_index = 5


func _process(delta: float) -> void:
	_t += delta
	if _t >= (LIFETIME * (1.6 if _heavy else 1.0)):
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var life := LIFETIME * (1.6 if _heavy else 1.0)
	var k := clampf(_t / life, 0.0, 1.0)
	var alpha := 1.0 - k
	if _heavy:
		# Dönen kesik: dışa doğru genişleyen parlak halka
		var outer := _radius * (0.55 + 0.45 * k)
		var poly := Shapes.iso_arc(_facing, outer, 360.0, outer * 0.72, 32)
		draw_colored_polygon(poly, Color(1.0, 0.95, 0.8, 0.55 * alpha))
		var edge := Shapes.iso_ellipse(outer, 32)
		edge.append(edge[0])
		draw_polyline(edge, Color(1, 1, 1, alpha), 3.0)
	else:
		# Normal vuruş: yayın açısı kısa sürede süpürülür
		var swept := _arc * clampf(k * 2.5, 0.25, 1.0)
		var start_dir := _facing.rotated(deg_to_rad(-_arc * 0.5 + swept * 0.5))
		var poly2 := Shapes.iso_arc(start_dir, _radius, swept, _radius * 0.45, 16)
		draw_colored_polygon(poly2, Color(1.0, 1.0, 1.0, 0.55 * alpha))
		var outer_edge := Shapes.iso_arc(start_dir, _radius, swept, _radius * 0.98, 16)
		draw_colored_polygon(outer_edge, Color(1, 1, 1, alpha))
