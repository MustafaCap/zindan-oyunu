## XRayMarker — karakter bir duvarın arkasında kalınca görünen yarı saydam siluet (Aşama 4).
## İzometrik duvarlar önlerindeki karakteri örtebilir; bu düğüm her şeyin üstünde (yüksek z) çizilir ve yalnızca
## `occluded` true iken görünür. Karakterin PlaceholderBody'siyle aynı ölçülerde gövde + kafa çizer.
class_name XRayMarker
extends Node2D

var color: Color = Color(0.6, 0.85, 1.0)
var body: PlaceholderBody
var occluded: bool = false:
	set(v):
		if v != occluded:
			occluded = v
			visible = v


func _ready() -> void:
	z_index = 60
	z_as_relative = false
	visible = false


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	if body == null:
		return
	var h := body.body_height
	var w := body.body_width * 0.5
	draw_set_transform(body.position, 0.0, body.scale)
	var off := Vector2.ZERO
	var fill := Color(color, 0.28)
	var line := Color(color, 0.85)
	var pts := PackedVector2Array([off + Vector2(-w, -4), off + Vector2(-w * 0.85, -h + 8), off + Vector2(w * 0.85, -h + 8),
		off + Vector2(w, -4), off + Vector2(0, 2)])
	draw_colored_polygon(pts, fill)
	draw_polyline(pts + PackedVector2Array([pts[0]]), line, 2.0)
	draw_circle(off + Vector2(0, -h + 2), 8.0, fill)
	draw_arc(off + Vector2(0, -h + 2), 8.0, 0, TAU, 20, line, 2.0)
