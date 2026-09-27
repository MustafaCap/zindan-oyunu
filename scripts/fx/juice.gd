## Juice — vuruş hissi merkezi: hitstop, ekran sarsıntısı, uçan hasar sayıları, kıvılcım ve kemik tozu.
## Aşama 2: element renkli sayılar, kombo yazıları, yıldırım/sekme zincirleri ve alan halkaları.
## Events sinyallerini dinler; savaş kodu yalnızca sinyal yayar, efektleri bu düğüm üretir.
class_name Juice
extends Node2D

var camera: Camera2D
## Otomatik testlerde (matris) kapatılır: hitstop gerçek zamana bağlı olduğu için hızlandırılmış simülasyonu yavaşlatır.
var hitstop_enabled: bool = true
var _feel: Dictionary
var _trauma: float = 0.0
var _hitstop_until_usec: int = 0
var _last_usec: int = 0
var _rng := RandomNumberGenerator.new()
var _blood: Dictionary
var _decals: Node2D


func _ready() -> void:
	material = Lighting.unshaded()   # Aşama 8: karanlıkta da okunur (ışıktan etkilenmez)
	_feel = DataDB.get_value("progression", "feel")
	z_index = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	Events.hit_landed.connect(_on_hit_landed)
	Events.damage_number.connect(_on_damage_number)
	Events.enemy_died_fx.connect(_on_enemy_died)
	Events.player_damaged.connect(_on_player_damaged)
	Events.floating_text.connect(_on_floating_text)
	Events.chain_zap.connect(_on_chain_zap)
	Events.area_pulse.connect(_on_area_pulse)
	Events.combo_triggered.connect(_on_combo)
	Events.blood_spilled.connect(_on_blood)
	Events.floor_entered.connect(func(_i: int) -> void: clear_blood())
	_blood = DataDB.get_value("progression", "blood")
	# Yerdeki kan lekeleri zeminin hemen üstünde, karakterlerin altında çizilir
	_decals = Node2D.new()
	_decals.z_as_relative = false
	_decals.z_index = -9
	add_child(_decals)
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
	if seconds <= 0.0 or not hitstop_enabled:
		return
	Engine.time_scale = 0.02
	_hitstop_until_usec = maxi(_hitstop_until_usec, Time.get_ticks_usec() + int(seconds * 1_000_000.0))


func shake(amount: float) -> void:
	_trauma = maxf(_trauma, amount)


func _on_hit_landed(pos: Vector2, amount: float, is_crit: bool, heavy: bool, dir_cart: Vector2) -> void:
	if amount <= 0.0:
		_sparks(pos, dir_cart, Color(0.6, 0.6, 0.65), 5, 0.6)
		return
	hitstop(float(_feel["hitstop_heavy_sec"] if (heavy or is_crit) else _feel["hitstop_sec"]))
	shake(float(_feel["shake_heavy"] if (heavy or is_crit) else _feel["shake_hit"]))
	_sparks(pos, dir_cart, Color(1.0, 0.92, 0.6), 14 if is_crit else 9)


func _on_player_damaged(_amount: float) -> void:
	shake(float(_feel["shake_player_hurt"]))


func _on_enemy_died(pos: Vector2, dir_cart: Vector2) -> void:
	_sparks(pos, dir_cart, Color(0.85, 0.83, 0.75), 22, 1.4)


func _on_damage_number(pos: Vector2, amount: float, is_crit: bool, is_player: bool, kind: String) -> void:
	var text := ("%d!" % roundi(amount)) if is_crit else str(roundi(amount))
	var size := 34 if is_crit else 22
	var color := Weapon.kind_color(kind)
	if kind == DamageCalc.PHYSICAL or kind == "":
		color = Color.WHITE
	if is_crit:
		color = Color(1.0, 0.75, 0.15)
	if is_player:
		color = Color(1.0, 0.35, 0.35)
	if kind == "heal":
		color = Color(0.4, 1.0, 0.45)
		text = "+%d" % roundi(amount)
		size = 18
	elif kind in ["fire", "poison"] and not is_crit and not is_player:
		size = 17  # süreli hasar sayıları daha küçük
	_float_label(pos, text, color, size, is_crit)


func _on_floating_text(pos: Vector2, text: String, color: Color, size: int) -> void:
	_float_label(pos, text, color, size, false)


func _float_label(pos: Vector2, text: String, color: Color, size: int, pop: bool) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 6)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(320, 48)
	label.pivot_offset = label.size * 0.5
	add_child(label)
	label.global_position = pos - label.size * 0.5 + Vector2(_rng.randf_range(-10, 10), 0)
	label.scale = Vector2(1.6, 1.6) if pop else Vector2(1.2, 1.2)
	var tw := label.create_tween()
	tw.tween_property(label, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK)
	tw.parallel().tween_property(label, "position:y", label.position.y - (50.0 if pop else 36.0), 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 0.3).set_delay(0.35)
	tw.tween_callback(label.queue_free)
	return label


## Kombo: büyük renkli yazı, güçlü sarsıntı ve renkli patlama.
func _on_combo(combo_id: String, target: Node) -> void:
	var combo := Combos.by_id(combo_id)
	var t := target as Node2D
	if combo.is_empty() or t == null:
		return
	var color := Color(str(combo["color"]))
	var label := _float_label(t.global_position + Vector2(0, -92), str(combo["name"]).to_upper() + "!", color, 30, true)
	label.add_theme_constant_override("outline_size", 9)
	hitstop(float(_feel["hitstop_heavy_sec"]))
	shake(float(_feel["shake_heavy"]))
	_sparks(t.global_position + Vector2(0, -18), Vector2.ZERO, color, 26, 1.3)


## Yıldırım zinciri, Elektroşok ya da Sekme çizgisi.
func _on_chain_zap(from: Vector2, to: Vector2, color: Color, jagged: bool) -> void:
	var line := Line2D.new()
	var pts := PackedVector2Array([from])
	if jagged:
		var n := 7
		var normal := (to - from).orthogonal().normalized()
		for i: int in range(1, n):
			var p := from.lerp(to, float(i) / n) + normal * _rng.randf_range(-9, 9)
			pts.append(p)
	pts.append(to)
	line.points = pts
	line.width = 4.0 if jagged else 3.0
	line.default_color = color.lightened(0.3)
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	add_child(line)
	var glow := line.duplicate() as Line2D
	glow.width = line.width * 3.0
	glow.default_color = Color(color, 0.35)
	add_child(glow)
	for l: Line2D in [line, glow]:
		var tw := l.create_tween()
		tw.tween_property(l, "modulate:a", 0.0, 0.28)
		tw.tween_callback(l.queue_free)


## Aşama 8 (kanlı oyun): vuruş yönüne kan fışkırır, yere leke düşer; ölümde büyük fışkırma ve
## kan gölü. Lekeler bir süre kalır, sonra solar (progression.json > blood).
func _on_blood(pos: Vector2, dir_cart: Vector2, amount: float, color: Color) -> void:
	var b := _blood
	var n := int(float(b["droplets_per_hit"]) * amount)
	var sp: Array = b["spray_speed"]
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = maxi(n, 1)
	p.lifetime = 0.55
	p.explosiveness = 0.9
	p.direction = (Iso.to_screen(dir_cart).normalized() + Vector2(0, -0.35)).normalized() if dir_cart.length() > 0.01 else Vector2.UP
	p.spread = 38.0 if amount < 2.0 else 75.0
	p.initial_velocity_min = float(sp[0]) * (0.8 + amount * 0.2)
	p.initial_velocity_max = float(sp[1]) * (0.8 + amount * 0.2)
	p.gravity = Vector2(0, 900)
	p.damping_min = 40.0
	p.damping_max = 120.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.5
	var ramp := Gradient.new()
	ramp.set_color(0, color.lightened(0.15))
	ramp.set_color(1, Color(color.darkened(0.4), 0.0))
	p.color_ramp = ramp
	add_child(p)
	p.global_position = pos + Vector2(0, -22)
	p.emitting = true
	get_tree().create_timer(0.9, true, false, true).timeout.connect(p.queue_free)
	# Yere düşen lekeler: vuruş yönünde, biraz geride
	var sr: Array = b["splat_radius_tiles"]
	var splats := int(ceil(float(b["splats_per_hit"]) * amount * 0.6))
	for i: int in splats:
		var off := dir_cart.normalized() * _rng.randf_range(0.2, 0.9 + amount * 0.3) if dir_cart.length() > 0.01 else Vector2.ZERO
		off += Vector2(_rng.randf_range(-0.35, 0.35), _rng.randf_range(-0.35, 0.35))
		_add_decal(pos + Iso.to_screen(off * Iso.KARO), _rng.randf_range(float(sr[0]), float(sr[1])), color)
	if amount >= float(b["death_mult"]) - 0.01:
		var pr: Array = b["pool_radius_tiles"]
		_add_decal(pos, _rng.randf_range(float(pr[0]), float(pr[1])), color.darkened(0.15))


func _add_decal(pos: Vector2, radius_tiles: float, color: Color) -> void:
	var d := BloodDecal.new()
	d.radius_tiles = radius_tiles
	d.color = Color(color.darkened(0.2), 0.85)
	d.seed_value = _rng.randi()
	d.lifetime = float(_blood["decal_lifetime_sec"])
	d.fade = float(_blood["decal_fade_sec"])
	_decals.add_child(d)
	d.global_position = pos
	while _decals.get_child_count() > int(_blood["max_decals"]):
		var old := _decals.get_child(0)
		_decals.remove_child(old)
		old.queue_free()


## Kat değişince yerdeki kanlar temizlenir.
func clear_blood() -> void:
	for c: Node in _decals.get_children():
		c.queue_free()


## Yerdeki kan lekesi: düzensiz izometrik leke ve birkaç damla; ömrü dolunca solar.
class BloodDecal:
	extends Node2D
	var radius_tiles: float = 0.2
	var color: Color = Color(0.5, 0.03, 0.03, 0.85)
	var seed_value: int = 0
	var lifetime: float = 30.0
	var fade: float = 4.0
	var _t: float = 0.0
	var _grow: float = 0.0

	func _process(delta: float) -> void:
		_t += delta
		if _grow < 1.0:
			_grow = minf(_grow + delta * 6.0, 1.0)
			queue_redraw()
		if _t > lifetime:
			modulate.a = 1.0 - (_t - lifetime) / fade
			if _t > lifetime + fade:
				queue_free()

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var r := radius_tiles * (0.4 + 0.6 * _grow)
		var pts := PackedVector2Array()
		var n := 14
		for i: int in n:
			var a := TAU * i / n
			var k := rng.randf_range(0.65, 1.15)
			pts.append(Iso.to_screen(Vector2(cos(a), sin(a)) * Iso.tiles(r) * k))
		draw_colored_polygon(pts, color)
		draw_colored_polygon(_scaled(pts, 0.55), color.darkened(0.25))
		for i: int in rng.randi_range(2, 5):
			var dp := Iso.to_screen(Vector2.RIGHT.rotated(rng.randf() * TAU) * Iso.tiles(r) * rng.randf_range(1.15, 1.8))
			draw_circle(dp, rng.randf_range(1.2, 2.6), color)

	func _scaled(pts: PackedVector2Array, k: float) -> PackedVector2Array:
		var out := PackedVector2Array()
		for p: Vector2 in pts:
			out.append(p * k)
		return out


## Yerde genişleyen halka (alan kombo'ları).
func _on_area_pulse(pos: Vector2, radius_tiles: float, color: Color) -> void:
	var ring := PulseRing.new()
	ring.radius_tiles = radius_tiles
	ring.color = color
	add_child(ring)
	ring.global_position = pos
	ring.z_index = -1


class PulseRing:
	extends Node2D
	var radius_tiles: float = 1.0
	var color: Color = Color.WHITE
	var _t: float = 0.0

	func _process(delta: float) -> void:
		_t += delta
		if _t >= 0.4:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var k := clampf(_t / 0.4, 0.0, 1.0)
		var r := radius_tiles * (0.35 + 0.65 * sqrt(k))
		var poly := Shapes.iso_ellipse(r, 32)
		draw_colored_polygon(poly, Color(color, 0.28 * (1.0 - k)))
		poly.append(poly[0])
		draw_polyline(poly, Color(color.lightened(0.3), 1.0 - k), 3.0)


func _sparks(pos: Vector2, dir_cart: Vector2, color: Color, amount: int, speed_mult: float = 1.0) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = 0.35
	p.explosiveness = 1.0
	p.direction = Iso.to_screen(dir_cart).normalized() if dir_cart.length() > 0.01 else Vector2.UP
	p.spread = 55.0 if dir_cart.length() > 0.01 else 180.0
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
