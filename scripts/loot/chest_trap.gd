## ChestTrap — tuzaklı sandık (GDD: Sandık "bazen tuzaklı"). Açılınca yerde kırmızı işaret belirir ve dolar
## (GDD: saldırılar yerde kırmızı işaretle önceden gösterilir); süre dolunca patlar, alanın içindeki oyuncuya maks
## canının belirli yüzdesi kadar (zırhtan önce) hasar verir. Sayılar economy.json > chest.
class_name ChestTrap
extends Node2D

var radius: float = 2.0
var warning: float = 1.0
var damage_pct: float = 0.2
var _t: float = 0.0
var _done: bool = false


func _ready() -> void:
	z_index = -2
	var c: Dictionary = DataDB.table("economy")["chest"]
	radius = float(c["trap_radius"])
	warning = float(c["trap_warning_sec"])
	damage_pct = float(c["trap_damage_pct"])


func _physics_process(delta: float) -> void:
	if _done:
		return
	_t += delta
	if _t >= warning:
		_explode()
	queue_redraw()


func _explode() -> void:
	_done = true
	Events.area_pulse.emit(global_position, radius, Color(1.0, 0.35, 0.2))
	Events.floating_text.emit(global_position + Vector2(0, -60), "TUZAK!", Color(1.0, 0.4, 0.3), 24)
	var p := get_tree().get_first_node_in_group("player") as Player
	if p and not p.dead and Iso.tile_distance(p.global_position, global_position) <= radius + p.radius_tiles:
		var d := Iso.to_cart(p.global_position - global_position)
		p.take_damage(p.max_hp * damage_pct, d.normalized() if d.length() > 0.01 else Vector2.RIGHT)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.tween_callback(queue_free)


func _draw() -> void:
	var ring := Shapes.iso_ellipse(radius, 32)
	var edge := ring.duplicate()
	edge.append(ring[0])
	var k := clampf(_t / maxf(warning, 0.01), 0.0, 1.0)
	draw_colored_polygon(ring, Color(1.0, 0.15, 0.1, 0.14))
	draw_colored_polygon(Shapes.iso_ellipse(radius * k, 32), Color(1.0, 0.2, 0.1, 0.22))
	draw_polyline(edge, Color(1.0, 0.3, 0.2, 0.9), 2.5)
