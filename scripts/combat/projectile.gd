## Projectile — oyuncunun mermileri: ok, cıvata, sayfa, küre, fırlatılan balta ve mızrak (placeholder çizim).
## Zemin (düz) uzayında ilerler; duvar ve sütunlara çarpınca durur. Yoldaki düşmanlara Player.deal_hit ile vurur
## (hasar formülü, element, kombo ve özellikler HitResolver'dan geçer). Aynı düşmana bir uçuşta bir kez vurur.
## Davranışlar (hepsi isteğe bağlı): delme (pierce), güdüm (homing), çarpınca patlama (explode_radius),
## geri dönme (boomerang: balta), saplanıp çağrılınca dönme (stick: mızrak).
class_name Projectile
extends Node2D

signal finished

const WALL_MASK := 1 | 8
const HEIGHT := 20.0   ## mermi yerden bu kadar yukarıda çizilir

var player: Player
var weapon: Weapon
var source: String = "light"   ## "light", "heavy", "q", "e" (hasar kaydı için)
var attack_id: int = 0
var skill_mult: float = 1.0
var extra_opts: Dictionary = {}

var dir_cart: Vector2 = Vector2.RIGHT
var speed_tiles: float = 12.0
var max_range: float = 8.0
var radius_tiles: float = 0.25
var pierce: int = 0            ## kaç düşmanı deler; -1 = hepsini
var kind: String = "arrow"     ## çizim: arrow, bolt, page, orb, axe, spear, big_orb, wave (Ek mermi: kılıç dalgası)
var color: Color = Color.WHITE

var homing_range: float = 0.0  ## > 0 ise en yakın düşmana döner
var turn_rate: float = 6.0     ## rad/sn
var explode_radius: float = 0.0
var boomerang: bool = false
var return_speed: float = 0.0
var stick: bool = false        ## menzil sonunda ya da duvarda saplanır, recall() ile döner
var auto_return_sec: float = 6.0

var state: String = "fly"      ## fly, stuck, return
var _travelled: float = 0.0
var _hit: Dictionary = {}      ## instance_id -> true (bu uçuşta vurulanlar)
var _t: float = 0.0
var _stuck_t: float = 0.0
var _home_target: Node2D


func _ready() -> void:
	z_index = 3
	dir_cart = dir_cart.normalized()
	# Boss özel etkisi Delici: delmeyen mermiler 1 düşman deler (patlayan küre ve saplanan mızrak hariç)
	var pd := GameState.special("piercing")
	if not pd.is_empty() and pierce >= 0 and explode_radius <= 0.0 and not stick:
		pierce += int(pd["pierce"])


func _physics_process(delta: float) -> void:
	_t += delta
	if state == "stuck":
		_stuck_t += delta
		if _stuck_t >= auto_return_sec:
			recall()
		queue_redraw()
		return
	if state == "return":
		_return_step(delta)
		queue_redraw()
		return
	if homing_range > 0.0:
		_steer(delta)
	var step := speed_tiles * delta
	if _travelled + step > max_range:
		step = maxf(max_range - _travelled, 0.0)
	var from := global_position
	var to := from + Iso.to_screen(dir_cart * Iso.tiles(step))
	var wall := _wall_between(from, to)
	if not wall.is_empty():
		to = wall["position"] - Iso.to_screen(dir_cart * 2.0)
	global_position = to
	_travelled += step
	_check_hits()
	if not is_inside_tree() or state != "fly":
		return
	if not wall.is_empty() or _travelled >= max_range - 0.001:
		_end_of_flight()
	queue_redraw()


## Mızrak: saplandıysa oyuncuya geri döner (yoldaki düşmanlara yeniden vurur).
func recall() -> void:
	if state == "return":
		return
	state = "return"
	_hit.clear()


func _return_step(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		_finish()
		return
	var to_p := Iso.to_cart(player.global_position - global_position)
	var dist := to_p.length() / Iso.KARO
	var step := (return_speed if return_speed > 0.0 else speed_tiles) * delta
	if dist <= step + 0.3:
		_finish()
		return
	dir_cart = to_p.normalized()
	global_position += Iso.to_screen(dir_cart * Iso.tiles(step))
	_check_hits()


func _end_of_flight() -> void:
	if explode_radius > 0.0:
		_explode()
		_finish()
	elif boomerang:
		recall()
	elif stick:
		state = "stuck"
		_stuck_t = 0.0
	else:
		_finish()


func _check_hits() -> void:
	if player == null or not is_instance_valid(player):
		return
	for e: Node2D in player.enemies_in_circle(global_position, radius_tiles):
		var id := e.get_instance_id()
		if _hit.has(id):
			continue
		_hit[id] = true
		if explode_radius > 0.0:
			_explode()
			_finish()
			return
		var opts := extra_opts.duplicate()
		opts["dir"] = dir_cart
		player.deal_hit(e, weapon, source, skill_mult, attack_id, opts)
		if state == "fly" and pierce >= 0:
			if pierce == 0:
				_end_after_hit()
				return
			pierce -= 1


func _end_after_hit() -> void:
	if boomerang:
		recall()
	elif stick:
		state = "stuck"
		_stuck_t = 0.0
	else:
		_finish()


func _explode() -> void:
	Events.area_pulse.emit(global_position, explode_radius, color)
	for e: Node2D in player.enemies_in_circle(global_position, explode_radius):
		var d := Iso.to_cart(e.global_position - global_position)
		var opts := extra_opts.duplicate()
		opts["dir"] = d.normalized() if d.length() > 0.01 else dir_cart
		opts["heavy"] = true
		player.deal_hit(e, weapon, source, skill_mult, attack_id, opts)


func _steer(delta: float) -> void:
	if _home_target == null or not is_instance_valid(_home_target) or _home_target.get("dead"):
		_home_target = null
		var best := homing_range
		for e: Node2D in player.enemies_in_circle(global_position, homing_range):
			if _hit.has(e.get_instance_id()):
				continue
			var d := Iso.tile_distance(global_position, e.global_position)
			if d < best:
				best = d
				_home_target = e
	if _home_target == null:
		return
	var want := Iso.to_cart(_home_target.global_position - global_position).normalized()
	var ang := dir_cart.angle_to(want)
	dir_cart = dir_cart.rotated(clampf(ang, -turn_rate * delta, turn_rate * delta))


func _wall_between(from: Vector2, to: Vector2) -> Dictionary:
	if from.distance_to(to) < 0.01:
		return {}
	var q := PhysicsRayQueryParameters2D.create(from, to, WALL_MASK)
	return get_world_2d().direct_space_state.intersect_ray(q)


func _finish() -> void:
	if state == "done":
		return
	state = "done"
	finished.emit()
	queue_free()


func _draw() -> void:
	var up := Vector2(0, -HEIGHT)
	var d := Iso.to_screen(dir_cart).normalized()
	var n := d.orthogonal()
	var dark := Color(0.05, 0.05, 0.08)
	match kind:
		"arrow", "bolt":
			var length := 26.0 if kind == "arrow" else 18.0
			var tail := up - d * length
			draw_line(tail, up, dark, 4.0)
			draw_line(tail, up, color.lerp(Color(0.85, 0.75, 0.55), 0.4), 2.0)
			draw_colored_polygon(PackedVector2Array([up + d * 7.0, up + n * 4.0, up - n * 4.0]), color.lightened(0.3))
			if kind == "arrow":
				draw_line(tail, tail - d * 5.0 + n * 4.0, Color(0.9, 0.9, 0.9), 2.0)
				draw_line(tail, tail - d * 5.0 - n * 4.0, Color(0.9, 0.9, 0.9), 2.0)
		"pierce_arrow":
			var tail2 := up - d * 34.0
			draw_line(tail2 - d * 20.0, up, Color(color, 0.35), 10.0)
			draw_line(tail2, up, dark, 5.0)
			draw_line(tail2, up, color.lightened(0.5), 3.0)
			draw_colored_polygon(PackedVector2Array([up + d * 10.0, up + n * 6.0, up - n * 6.0]), Color.WHITE)
		"page":
			var r := d.rotated(_t * 12.0) * 7.0
			var rn := r.orthogonal()
			var pts := PackedVector2Array([up + r + rn * 0.7, up + r - rn * 0.7, up - r - rn * 0.7, up - r + rn * 0.7])
			draw_colored_polygon(pts, Color(0.97, 0.94, 0.85))
			draw_polyline(pts + PackedVector2Array([pts[0]]), color, 2.0)
		"orb", "big_orb":
			var rad := 7.0 if kind == "orb" else 14.0 + sin(_t * 18.0) * 1.5
			draw_circle(up, rad * 1.8, Color(color, 0.25))
			draw_circle(up, rad, color.lightened(0.2))
			draw_circle(up - Vector2(rad * 0.3, rad * 0.3), rad * 0.4, Color(1, 1, 1, 0.8))
		"wave":
			# Kılıç dalgası: ilerleme yönüne dik, hilal biçiminde
			var pts := PackedVector2Array()
			for i: int in 9:
				var k := -1.0 + 2.0 * i / 8.0
				pts.append(up + n * k * 16.0 - d * (k * k) * 8.0)
			draw_polyline(pts, Color(color, 0.35), 9.0)
			draw_polyline(pts, color.lightened(0.45), 3.0)
		"axe":
			var a := _t * 22.0
			for i: int in 2:
				var arm := Vector2.RIGHT.rotated(a + PI * i) * 14.0
				draw_line(up - arm, up + arm, dark, 5.0)
				draw_line(up - arm, up + arm, Color(0.55, 0.4, 0.25), 3.0)
			var blade := Vector2.RIGHT.rotated(a) * 14.0
			draw_circle(up + blade, 6.0, color.lerp(Color(0.8, 0.82, 0.88), 0.5))
		"spear":
			var tail3 := up - d * 44.0
			var sy := up if state != "stuck" else up + Vector2(0, 10)
			tail3 = tail3 if state != "stuck" else sy - d * 30.0 + Vector2(0, -22)
			draw_line(tail3, sy, dark, 5.0)
			draw_line(tail3, sy, Color(0.6, 0.45, 0.3), 3.0)
			draw_colored_polygon(PackedVector2Array([sy + d * 10.0, sy + n * 4.0, sy - n * 4.0]), color.lerp(Color(0.85, 0.87, 0.92), 0.4))
			if state == "stuck":
				var pulse := 0.5 + 0.5 * sin(_t * 6.0)
				draw_circle(sy + Vector2(0, -4), 5.0 + pulse * 3.0, Color(color, 0.25))
		_:
			draw_circle(up, 5.0, color)
	# Yerde küçük gölge
	draw_circle(Vector2.ZERO, 3.0, Color(0, 0, 0, 0.3))
