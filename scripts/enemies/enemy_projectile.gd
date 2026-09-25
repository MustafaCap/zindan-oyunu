## EnemyProjectile — düşman ve boss mermileri (ok, zehir tükürüğü, ateş topu, spor, gölge oku; placeholder çizim).
## Zemin (düz) uzayında ilerler; duvar ve sütunlarda durur, oyuncuya değince vurur. warn > 0 ise önce yolunu kırmızı
## çizgiyle gösterip bekler (boss'ların yelpaze saldırıları); normal düşmanlarda hazırlık işaretini Enemy çizer.
## puddle doluysa düştüğü yerde süreli bir zemin tehlikesi (zehir birikintisi, lav) bırakır.
class_name EnemyProjectile
extends Node2D

const WALL_MASK := 1 | 8
const HEIGHT := 20.0

var dir_cart: Vector2 = Vector2.RIGHT
var speed_tiles: float = 9.0
var max_range: float = 8.0
var radius_tiles: float = 0.25
var damage: float = 10.0
var kind: String = DamageCalc.PHYSICAL
var look: String = "arrow"        ## arrow, spit, fireball, spore, shadow
var warn: float = 0.0
var puddle: Dictionary = {}       ## {radius, duration, damage (hazır hasar), kind, warn}
var label: String = ""
var source: Node2D

var _t: float = 0.0
var _travelled: float = 0.0
var _done: bool = false


func _ready() -> void:
	z_index = 3
	dir_cart = dir_cart.normalized()
	add_to_group("enemy_hazards")
	if EnemyHazard.log_enabled:
		EnemyHazard.telegraph_log.append({"label": label, "warn": warn, "shape": "projectile", "mode": "projectile"})


func _physics_process(delta: float) -> void:
	if _done:
		return
	_t += delta
	if _t < warn:
		queue_redraw()
		return
	var step := minf(speed_tiles * delta, max_range - _travelled)
	var from := global_position
	var to := from + Iso.to_screen(dir_cart * Iso.tiles(step))
	var wall := _wall_between(from, to)
	if not wall.is_empty():
		to = wall["position"] - Iso.to_screen(dir_cart * 2.0)
	global_position = to
	_travelled += step
	var p := get_tree().get_first_node_in_group("player") as Player
	if p and not p.dead and not p.is_untargetable() \
			and Iso.tile_distance(global_position, p.global_position) <= radius_tiles + p.radius_tiles:
		p.take_damage(damage, dir_cart, kind)
		_end()
		return
	if not wall.is_empty() or _travelled >= max_range - 0.001:
		_end()
		return
	queue_redraw()


func _end() -> void:
	if _done:
		return
	_done = true
	if not puddle.is_empty() and is_inside_tree():
		var h := EnemyHazard.new()
		h.shape = "circle"
		h.mode = "zone"
		h.radius = float(puddle["radius"])
		h.duration = float(puddle["duration"])
		h.damage = float(puddle["damage"])
		h.kind = str(puddle.get("kind", kind))
		h.warn = float(puddle.get("warn", 0.3))
		h.color = Weapon.kind_color(h.kind)
		h.label = label + "_puddle"
		h.source = source
		get_parent().add_child(h)
		h.global_position = global_position
	queue_free()


func dismiss() -> void:
	_done = true
	queue_free()


func _wall_between(from: Vector2, to: Vector2) -> Dictionary:
	if from.distance_to(to) < 0.01:
		return {}
	var q := PhysicsRayQueryParameters2D.create(from, to, WALL_MASK)
	return get_world_2d().direct_space_state.intersect_ray(q)


func _draw() -> void:
	if _t < warn:
		# Yol uyarısı: menzil boyunca dolan kırmızı çizgi
		var k := clampf(_t / maxf(warn, 0.01), 0.0, 1.0)
		draw_colored_polygon(Shapes.iso_rect(dir_cart, max_range, 0.35), Color(1.0, 0.15, 0.1, 0.12 + 0.12 * k))
		draw_colored_polygon(Shapes.iso_rect(dir_cart, max_range * k, 0.35), Color(1.0, 0.2, 0.1, 0.25))
		return
	var up := Vector2(0, -HEIGHT)
	var d := Iso.to_screen(dir_cart).normalized()
	var col := Weapon.kind_color(kind) if kind != DamageCalc.PHYSICAL else Color(0.9, 0.85, 0.7)
	draw_circle(Vector2.ZERO, 5.0, Color(0, 0, 0, 0.3))
	match look:
		"arrow":
			draw_line(up - d * 12.0, up + d * 10.0, Color(0.85, 0.8, 0.65), 2.5)
			draw_colored_polygon(PackedVector2Array([up + d * 14.0, up + d * 7.0 + d.orthogonal() * 4.0, up + d * 7.0 - d.orthogonal() * 4.0]), Color(1, 0.3, 0.25))
		"fireball":
			draw_circle(up, 9.0, Color(col, 0.5))
			draw_circle(up, 6.0, col.lightened(0.3))
		"shadow":
			draw_circle(up, 8.0, Color(0.35, 0.2, 0.55, 0.7))
			draw_circle(up, 4.0, Color(0.8, 0.6, 1.0))
		_:
			draw_circle(up, 7.0, Color(col, 0.6))
			draw_circle(up + Vector2(2, -2), 3.0, col.lightened(0.4))
