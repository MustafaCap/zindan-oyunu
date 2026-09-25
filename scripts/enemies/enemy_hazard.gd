## EnemyHazard — düşman ve boss'ların yerde çıkan saldırıları (GDD: "saldırıların hepsi yerde kırmızı işaretle önceden
## gösterilir"). Önce warn süresi boyunca işaret dolar, sonra vurur. Yalnızca oyuncuya hasar verir.
##   Şekiller: circle (daire), rect (şerit: ışın, damar, lav kanalı), arc (dilim), ring_wave (genişleyen şok halkası).
##   Modlar:   burst (bir kez vurur), zone (duration boyunca tick saniyede bir vurur), visual (yalnızca işaret).
## Hasar Player.take_damage'den geçer (zırh, direnç, dokunulmazlık; Space'in dokunulmazlığıyla içinden geçilir).
class_name EnemyHazard
extends Node2D

signal fired

## Testler için: açıkken oluşturulan her tehlikenin etiketi ve uyarı süresi kaydedilir.
static var log_enabled: bool = false
static var telegraph_log: Array[Dictionary] = []

var shape: String = "circle"
var mode: String = "burst"
var radius: float = 1.0           ## circle, arc, ring_wave (en büyük yarıçap)
var dir_cart: Vector2 = Vector2.RIGHT
var length: float = 4.0           ## rect
var width: float = 0.8            ## rect
var start: float = 0.0            ## rect: merkezden bu kadar ileride başlar
var arc_degrees: float = 90.0     ## arc
var warn: float = 0.8
var duration: float = 0.0         ## zone
var tick: float = 0.5             ## zone
var damage: float = 10.0
var kind: String = DamageCalc.PHYSICAL
var slow_amount: float = 0.0
var slow_duration: float = 0.0
var wave_speed: float = 6.0       ## ring_wave: karo/sn
var wave_thickness: float = 0.8
var color: Color = Color(1.0, 0.15, 0.1)
var label: String = ""            ## saldırı id'si (test kaydı)
var source: Node2D                ## sahibi (boss ölünce temizlenir)

var _t: float = 0.0
var _tick_t: float = 0.0
var _done: bool = false
var _hit_once: bool = false


func _ready() -> void:
	z_index = -2
	add_to_group("enemy_hazards")
	if log_enabled:
		telegraph_log.append({"label": label, "warn": warn, "shape": shape, "mode": mode})


func _physics_process(delta: float) -> void:
	if _done:
		return
	_t += delta
	if _t >= warn:
		var active_t := _t - warn
		match mode:
			"burst":
				if shape == "ring_wave":
					var r := active_t * wave_speed
					if not _hit_once and _player_on_ring(r):
						_hit_once = true
						_damage_player()
					if r >= radius:
						_finish()
				else:
					fired.emit()
					if contains_player():
						_damage_player()
					Events.area_pulse.emit(global_position, _pulse_radius(), color)
					_finish()
			"zone":
				_tick_t -= delta
				if _tick_t <= 0.0:
					_tick_t = tick
					if contains_player():
						_damage_player()
				if active_t >= duration:
					_finish()
			_:
				if active_t >= duration:
					_finish()
	queue_redraw()


## Uyarı bitti mi (tehlike etkin mi)?
func is_active() -> bool:
	return _t >= warn and not _done


## Oyuncu şeklin içinde mi?
func contains_player() -> bool:
	var p := _player()
	return p != null and contains(p.global_position, p.radius_tiles)


## Bir dünya noktası (margin karo payıyla) şeklin içinde mi?
func contains(pos: Vector2, margin: float = 0.0) -> bool:
	var v := Iso.to_cart(pos - global_position) / Iso.KARO
	match shape:
		"circle":
			return v.length() <= radius + margin
		"rect":
			var d := dir_cart.normalized()
			var a := d * start
			var b := d * (start + length)
			return Shapes.segment_distance(v, a, b) <= width * 0.5 + margin
		"arc":
			if v.length() > radius + margin:
				return false
			if arc_degrees >= 360.0 or v.length() < 0.05:
				return true
			return absf(rad_to_deg(dir_cart.angle_to(v))) <= arc_degrees * 0.5
		"ring_wave":
			return _player_on_ring((_t - warn) * wave_speed)
	return false


func _player_on_ring(r: float) -> bool:
	var p := _player()
	if p == null:
		return false
	var d := Iso.tile_distance(global_position, p.global_position)
	return absf(d - r) <= wave_thickness * 0.5 + p.radius_tiles


func _damage_player() -> void:
	var p := _player()
	if p == null or p.dead:
		return
	var v := Iso.to_cart(p.global_position - global_position)
	p.take_damage(damage, v.normalized() if v.length() > 0.01 else Vector2.RIGHT, kind)
	if slow_amount > 0.0:
		p.apply_slow(slow_duration, slow_amount)


func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


func _pulse_radius() -> float:
	return radius if shape != "rect" else width * 0.5


func dismiss() -> void:
	_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.tween_callback(queue_free)


func _draw() -> void:
	var k := clampf(_t / maxf(warn, 0.01), 0.0, 1.0)
	var active := _t >= warn
	var fill := Color(color, 0.14 + 0.12 * k)
	var edge := Color(color.lightened(0.2), 0.85)
	match shape:
		"circle", "arc":
			var poly := Shapes.iso_ellipse(radius, 32) if shape == "circle" or arc_degrees >= 360.0 \
				else Shapes.iso_arc(dir_cart, radius, arc_degrees, 0.0, 20)
			draw_colored_polygon(poly, Color(color, 0.32) if active and mode == "zone" else fill)
			if not active:
				var inner := Shapes.iso_ellipse(radius * k, 32) if shape == "circle" or arc_degrees >= 360.0 \
					else Shapes.iso_arc(dir_cart, radius * k, arc_degrees, 0.0, 20)
				draw_colored_polygon(inner, Color(color, 0.22))
			var outline := poly.duplicate()
			outline.append(poly[0])
			draw_polyline(outline, edge, 2.0)
		"rect":
			var poly2 := Shapes.iso_rect(dir_cart, length, width, start)
			draw_colored_polygon(poly2, Color(color, 0.4) if active else fill)
			if not active:
				draw_colored_polygon(Shapes.iso_rect(dir_cart, length * k, width, start), Color(color, 0.22))
			var o2 := poly2.duplicate()
			o2.append(poly2[0])
			draw_polyline(o2, edge, 2.0)
		"ring_wave":
			if not active:
				var full := Shapes.iso_ellipse(radius, 40)
				full.append(full[0])
				draw_polyline(full, Color(color, 0.35 + 0.4 * k), 2.0)
				draw_colored_polygon(Shapes.iso_ellipse(1.0 + 0.6 * k, 20), fill)
			else:
				var r := (_t - warn) * wave_speed
				draw_colored_polygon(Shapes.iso_ring(maxf(r - wave_thickness * 0.5, 0.01), r + wave_thickness * 0.5, 40), Color(color, 0.55))
