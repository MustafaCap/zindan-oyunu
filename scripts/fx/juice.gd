## Juice — vuruş hissi merkezi: hitstop, ekran sarsıntısı, uçan hasar sayıları, kıvılcım ve kemik tozu.
## Events sinyallerini dinler; savaş kodu yalnızca sinyal yayar, efektleri bu düğüm üretir.
class_name Juice
extends Node2D

var camera: Camera2D
var _feel: Dictionary
var _trauma: float = 0.0
var _hitstop_until_usec: int = 0
var _last_usec: int = 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_feel = DataDB.get_value("progression", "feel")
	z_index = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	Events.hit_landed.connect(_on_hit_landed)
	Events.damage_number.connect(_on_damage_number)
	Events.enemy_died_fx.connect(_on_enemy_died)
	Events.player_damaged.connect(_on_player_damaged)
	_last_usec = Time.get_ticks_usec()


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _process(_delta: float) -> void:
	# Gerçek zaman kullanılır: hitstop sırasında oyun zamanı neredeyse durur.
	var now := Time.get_ticks_usec()
	var real_dt := float(now - _last_usec) / 1_000_000.0
	_last_usec = now
	if _hitstop_until_usec > 0 and now >= _hitstop_until_usec:
		Engine.time_scale = 1.0
		_hitstop_until_usec = 0
	if camera:
		_trauma = maxf(_trauma - float(_feel["shake_decay"]) * real_dt, 0.0)
		camera.offset = Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * _trauma


func hitstop(seconds: float) -> void:
	if seconds <= 0.0:
		return
	Engine.time_scale = 0.02
	_hitstop_until_usec = maxi(_hitstop_until_usec, Time.get_ticks_usec() + int(seconds * 1_000_000.0))


func shake(amount: float) -> void:
	_trauma = maxf(_trauma, amount)


func _on_hit_landed(pos: Vector2, _amount: float, is_crit: bool, heavy: bool, dir_cart: Vector2) -> void:
	hitstop(float(_feel["hitstop_heavy_sec"] if (heavy or is_crit) else _feel["hitstop_sec"]))
	shake(float(_feel["shake_heavy"] if (heavy or is_crit) else _feel["shake_hit"]))
	_sparks(pos, dir_cart, Color(1.0, 0.92, 0.6), 14 if is_crit else 9)


func _on_player_damaged(_amount: float) -> void:
	shake(float(_feel["shake_player_hurt"]))


func _on_enemy_died(pos: Vector2, dir_cart: Vector2) -> void:
	_sparks(pos, dir_cart, Color(0.85, 0.83, 0.75), 22, 1.4)


func _on_damage_number(pos: Vector2, amount: float, is_crit: bool, is_player: bool) -> void:
	var label := Label.new()
	label.text = ("%d!" % roundi(amount)) if is_crit else str(roundi(amount))
	var size := 34 if is_crit else 22
	var color := Color(1.0, 0.75, 0.15) if is_crit else Color.WHITE
	if is_player:
		color = Color(1.0, 0.35, 0.35)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 6)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(120, 40)
	label.pivot_offset = label.size * 0.5
	add_child(label)
	label.global_position = pos - label.size * 0.5 + Vector2(_rng.randf_range(-10, 10), 0)
	label.scale = Vector2(1.6, 1.6) if is_crit else Vector2(1.2, 1.2)
	var tw := label.create_tween()
	tw.tween_property(label, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK)
	tw.parallel().tween_property(label, "position:y", label.position.y - (50.0 if is_crit else 36.0), 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 0.3).set_delay(0.35)
	tw.tween_callback(label.queue_free)


func _sparks(pos: Vector2, dir_cart: Vector2, color: Color, amount: int, speed_mult: float = 1.0) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = 0.35
	p.explosiveness = 1.0
	p.direction = Iso.to_screen(dir_cart).normalized() if dir_cart.length() > 0.01 else Vector2.UP
	p.spread = 55.0
	p.initial_velocity_min = 140.0 * speed_mult
	p.initial_velocity_max = 320.0 * speed_mult
	p.gravity = Vector2(0, 500)
	p.damping_min = 200.0
	p.damping_max = 400.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color = color
	var ramp := Gradient.new()
	ramp.set_color(0, color)
	ramp.set_color(1, Color(color.r, color.g, color.b, 0.0))
	p.color_ramp = ramp
	add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(0.8, true, false, true).timeout.connect(p.queue_free)
