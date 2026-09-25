## GroundEffect — yerde çıkan alan saldırıları (placeholder çizim): önce yerde işaret görünür, sonra vurur.
##   blast  — gecikmeyle tek patlama (Rün sol tık)
##   pulses — gecikmeden sonra aralıklı birkaç vuruş (Ok yağmuru, Element fırtınası)
##   trap   — kurulur, üstüne düşman basınca patlar; süresi dolunca söner (Rün tuzağı)
## Vuruşlar Player.deal_hit üzerinden HitResolver'a gider (element, kombo, özellikler dahil).
class_name GroundEffect
extends Node2D

signal finished

var player: Player
var weapon: Weapon
var source: String = "light"
var skill_mult: float = 1.0
var mode: String = "blast"
var look: String = "rune"         ## çizim: rune, rain, storm
var radius: float = 1.0
var delay: float = 0.3
var pulses: int = 1
var interval: float = 0.3
var arm_time: float = 0.5
var trigger_radius: float = 1.0
var lifetime: float = 10.0
var color: Color = Color.WHITE

var _t: float = 0.0
var _pulses_done: int = 0
var _next_pulse: float = 0.0
var _armed: bool = false
var _done: bool = false
var _rng := RandomNumberGenerator.new()
var _streaks: Array = []          ## Ok yağmuru çizgileri: [konum, kalan süre]


func _ready() -> void:
	z_index = -2
	_next_pulse = delay if mode != "trap" else 0.0
	_rng.seed = get_instance_id()


func _physics_process(delta: float) -> void:
	if _done:
		return
	_t += delta
	for s: Array in _streaks:
		s[1] = float(s[1]) - delta
	_streaks = _streaks.filter(func(s: Array) -> bool: return float(s[1]) > 0.0)
	match mode:
		"blast", "pulses":
			if _t >= _next_pulse and _pulses_done < maxi(pulses, 1):
				_pulse()
				_pulses_done += 1
				_next_pulse += interval
				if _pulses_done >= maxi(pulses, 1):
					_finish_after(0.25)
		"trap":
			if not _armed and _t >= arm_time:
				_armed = true
			if _armed and not player.enemies_in_circle(global_position, trigger_radius).is_empty():
				_pulse()
				_finish_after(0.2)
			elif _t >= lifetime:
				_finish_after(0.0)
	queue_redraw()


## Tuzağı kaldırır (yenisi kurulunca).
func dismiss() -> void:
	_finish_after(0.0)


func _pulse() -> void:
	if player == null or not is_instance_valid(player):
		return
	var attack_id := player.next_attack_id()
	Events.area_pulse.emit(global_position, radius, color)
	if look == "rain":
		for i: int in 7:
			var a := _rng.randf() * TAU
			var r := sqrt(_rng.randf()) * radius
			_streaks.append([Iso.to_screen(Vector2(cos(a), sin(a)) * Iso.tiles(r)), 0.18])
	for e: Node2D in player.enemies_in_circle(global_position, radius):
		var d := Iso.to_cart(e.global_position - global_position)
		var opts := {"dir": d.normalized() if d.length() > 0.01 else Vector2.RIGHT, "heavy": mode != "pulses", "area": true}
		player.deal_hit(e, weapon, source, skill_mult, attack_id, opts)


func _finish_after(sec: float) -> void:
	if _done:
		return
	_done = true
	var tw := create_tween()
	tw.tween_interval(sec)
	tw.tween_property(self, "modulate:a", 0.0, 0.15)
	tw.tween_callback(func() -> void:
		finished.emit()
		queue_free())


func _draw() -> void:
	var ring := Shapes.iso_ellipse(radius, 32)
	var edge := ring.duplicate()
	edge.append(ring[0])
	match mode:
		"trap":
			var a := 0.35 if _armed else 0.15
			draw_colored_polygon(ring, Color(color, a * (0.7 + 0.3 * sin(_t * 5.0))))
			draw_polyline(edge, Color(color.lightened(0.3), 0.9), 2.0)
			var trig := Shapes.iso_ellipse(trigger_radius, 20)
			trig.append(trig[0])
			draw_polyline(trig, Color(1, 1, 1, 0.5 if _armed else 0.2), 1.5)
			_draw_rune_glyph(Iso.tiles(minf(trigger_radius, radius)) * 0.55)
		_:
			# Uyarı: işaret dolarak vuruş anını gösterir
			var k := clampf(_t / maxf(delay, 0.01), 0.0, 1.0) if _pulses_done == 0 else 1.0
			draw_colored_polygon(ring, Color(color, 0.12 + 0.12 * k))
			var inner := Shapes.iso_ellipse(radius * k, 32)
			draw_colored_polygon(inner, Color(color, 0.18))
			draw_polyline(edge, Color(color.lightened(0.2), 0.85), 2.0)
			if look == "rune":
				_draw_rune_glyph(Iso.tiles(radius) * 0.5)
			elif look == "storm":
				for i: int in 5:
					var ang := _t * 3.0 + TAU * i / 5.0
					var p := Iso.to_screen(Vector2(cos(ang), sin(ang)) * Iso.tiles(radius * 0.6))
					draw_circle(p + Vector2(0, -10), 4.0, color.lightened(0.4))
	for s: Array in _streaks:
		var p2: Vector2 = s[0]
		var k2 := float(s[1]) / 0.18
		draw_line(p2 + Vector2(0, -120 * k2 - 20), p2 + Vector2(0, -120 * k2), Color(0.95, 0.9, 0.75), 2.0)


func _draw_rune_glyph(r: float) -> void:
	var pts := PackedVector2Array()
	for i: int in 6:
		var a := _t * 1.5 + TAU * i / 6.0
		pts.append(Iso.to_screen(Vector2(cos(a), sin(a)) * r))
	for i: int in 6:
		draw_line(pts[i], pts[(i + 2) % 6], Color(color.lightened(0.4), 0.9), 2.0)
