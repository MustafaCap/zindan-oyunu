## Player — oyuncu karakteri (Aşama 1 prototipi: Warrior + yaygın kılıç).
## WASD ile 8 yönde yürür, fareye bakar, Space ile atılır; sol tık yay vuruşu, sağ tık Dönen kesik.
## Tüm sayılar DataDB'den okunur. autoplay açıkken bir bot oynar (smoke testi için).
class_name Player
extends CharacterBody2D

signal died
signal health_changed(hp: float, max_hp: float)

const SlashFx := preload("res://scripts/fx/slash_fx.gd")

var race_id: String = "warrior"
var weapon_type_id: String = "sword"
var rarity_id: String = "common"

var max_hp: float
var hp: float
var armor: float
var move_speed_tiles: float
var radius_tiles: float

var facing_cart: Vector2 = Vector2.RIGHT
var attack_cd: float = 0.0
var heavy_cd: float = 0.0
var heavy_cd_max: float = 1.0
var dash_cd: float = 0.0
var dash_cd_max: float = 1.0
var dash_time: float = 0.0
var dash_dir_cart: Vector2 = Vector2.ZERO
var iframes: float = 0.0
var dead: bool = false
var autoplay: bool = false

var rng := RandomNumberGenerator.new()
var visual: PlaceholderBody

var _race: Dictionary
var _weapon: Dictionary
var _combat: Dictionary
var _feel: Dictionary
var _caps: Dictionary
var _lean_t: float = 0.0
var _bot_dash_timer: float = 0.0


func _ready() -> void:
	add_to_group("player")
	_race = DataDB.table("races")[race_id]
	_weapon = DataDB.table("weapon_types")[weapon_type_id]
	_combat = DataDB.get_value("progression", "combat")
	_feel = DataDB.get_value("progression", "feel")
	_caps = DataDB.get_value("progression", "stat_caps")

	max_hp = float(_race["base_hp"])
	hp = max_hp
	armor = float(_race["armor"])
	move_speed_tiles = float(_combat["base_move_speed"]) * float(_race["move_speed"])
	radius_tiles = float(_combat["player_radius"])
	dash_cd_max = float(_combat["dash_cooldown"])
	var heavy_cd_data: Variant = _race["cooldowns"].get("heavy", 5.0)
	# Warrior'da sağ tık 5-7 sn arası: aralık verilmişse ortası kullanılır.
	heavy_cd_max = (float(heavy_cd_data[0]) + float(heavy_cd_data[1])) * 0.5 if heavy_cd_data is Array else float(heavy_cd_data)

	collision_layer = 2
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionPolygon2D.new()
	shape.polygon = Shapes.iso_ellipse(radius_tiles)
	add_child(shape)

	visual = PlaceholderBody.new()
	visual.body_color = Color(0.25, 0.55, 0.95)
	visual.head_color = Color(0.93, 0.8, 0.66)
	add_child(visual)
	health_changed.emit(hp, max_hp)


func _physics_process(delta: float) -> void:
	attack_cd = maxf(attack_cd - delta, 0.0)
	heavy_cd = maxf(heavy_cd - delta, 0.0)
	dash_cd = maxf(dash_cd - delta, 0.0)
	iframes = maxf(iframes - delta, 0.0)
	_lean_t = maxf(_lean_t - delta, 0.0)
	visual.lean = _lean_t / 0.12
	if dead:
		return

	var move_cart := Vector2.ZERO
	var aim_cart := facing_cart
	var want_attack := false
	var want_heavy := false
	var want_dash := false
	if autoplay:
		var bot := _bot_think(delta)
		move_cart = bot["move"]
		aim_cart = bot["aim"]
		want_attack = bot["attack"]
		want_heavy = bot["heavy"]
		want_dash = bot["dash"]
	else:
		move_cart = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		aim_cart = Iso.to_cart(get_global_mouse_position() - global_position)
		want_attack = Input.is_action_pressed("attack_primary")
		want_heavy = Input.is_action_just_pressed("attack_secondary")
		want_dash = Input.is_action_just_pressed("dash")

	if aim_cart.length() > 0.01:
		facing_cart = aim_cart.normalized()
		visual.set_facing(facing_cart)

	if dash_time > 0.0:
		dash_time -= delta
		var dash_speed := Iso.tiles(float(_combat["dash_distance"])) / float(_combat["dash_duration"])
		velocity = Iso.to_screen(dash_dir_cart * dash_speed)
	else:
		if want_dash and dash_cd <= 0.0:
			_start_dash(move_cart)
		velocity = Iso.to_screen(move_cart.limit_length(1.0) * Iso.tiles(move_speed_tiles))
		if want_heavy and heavy_cd <= 0.0:
			_spin_slash()
		elif want_attack and attack_cd <= 0.0:
			_swing()
	move_and_slide()


func _start_dash(move_cart: Vector2) -> void:
	dash_dir_cart = move_cart.normalized() if move_cart.length() > 0.1 else facing_cart
	dash_time = float(_combat["dash_duration"])
	dash_cd = dash_cd_max
	iframes = maxf(iframes, float(_combat["dash_iframes"]))
	Events.player_dashed.emit(global_position)
	var ghost := visual.duplicate() as Node2D
	ghost.modulate = Color(0.5, 0.8, 1.0, 0.5)
	get_parent().add_child(ghost)
	ghost.global_position = global_position
	var tw := ghost.create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, 0.25)
	tw.tween_callback(ghost.queue_free)


## Sol tık: fare yönünde yay şeklinde vuruş.
func _swing() -> void:
	attack_cd = 1.0 / float(_weapon["attacks_per_sec"])
	_lean_t = 0.12
	var range_tiles := float(_weapon["range"])
	var arc := float(_weapon["arc_degrees"])
	var fx := SlashFx.new()
	fx.setup(facing_cart, range_tiles, arc, false)
	get_parent().add_child(fx)
	fx.global_position = global_position + Vector2(0, -6)
	_hit_enemies(range_tiles, arc, 1.0, false)


## Sağ tık: Dönen kesik — etraftaki herkese hasar.
func _spin_slash() -> void:
	heavy_cd = heavy_cd_max
	_lean_t = 0.12
	var heavy: Dictionary = _weapon["heavy"]
	var radius := float(heavy["radius"])
	var fx := SlashFx.new()
	fx.setup(facing_cart, radius, 360.0, true)
	get_parent().add_child(fx)
	fx.global_position = global_position + Vector2(0, -6)
	_hit_enemies(radius, 360.0, float(heavy["damage_mult"]), true)


func _hit_enemies(range_tiles: float, arc: float, mult: float, heavy: bool) -> void:
	var base := float(DataDB.table("rarities")[rarity_id]["base_damage"]) * float(_weapon["damage_mult"]) * mult
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Node2D
		if e == null or not e.has_method("take_hit") or e.get("dead"):
			continue
		if not CombatMath.in_arc(global_position, facing_cart, e.global_position, range_tiles, arc, float(e.get("radius_tiles"))):
			continue
		var crit := CombatMath.roll_crit(float(_combat["base_crit_chance"]), rng)
		var dmg := base * (float(_combat["base_crit_mult"]) if crit else 1.0)
		var dir := Iso.to_cart(e.global_position - global_position)
		if dir.length() < 0.01:
			dir = facing_cart
		e.call("take_hit", dmg, crit, dir.normalized(), heavy)


## Düşmandan gelen hasar.
func take_damage(amount: float, _from_dir_cart: Vector2) -> void:
	if dead or iframes > 0.0:
		return
	var dmg := CombatMath.apply_reduction(amount, armor, float(_caps["damage_reduction"]))
	hp = maxf(hp - dmg, 0.0)
	iframes = float(_combat["player_hurt_iframes"])
	visual.flash(float(_feel["flash_duration"]) * 1.5, Color(1.0, 0.25, 0.25))
	Events.player_damaged.emit(dmg)
	Events.damage_number.emit(global_position + Vector2(0, -40), dmg, false, true)
	health_changed.emit(hp, max_hp)
	if hp <= 0.0:
		_die()


func _die() -> void:
	dead = true
	collision_layer = 0
	var tw := create_tween()
	tw.tween_property(visual, "rotation", deg_to_rad(80), 0.35).set_trans(Tween.TRANS_BACK)
	tw.parallel().tween_property(visual, "modulate", Color(0.6, 0.6, 0.6, 0.8), 0.35)
	Events.player_died.emit()
	died.emit()


## Smoke testi botu: en yakın düşmana yürür, menzildeyse vurur, kalabalıkta Dönen kesik atar.
func _bot_think(delta: float) -> Dictionary:
	var out := {"move": Vector2.ZERO, "aim": facing_cart, "attack": false, "heavy": false, "dash": false}
	var nearest: Node2D = null
	var best := INF
	var close_count := 0
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Node2D
		if e.get("dead"):
			continue
		var d := Iso.tile_distance(global_position, e.global_position)
		if d < best:
			best = d
			nearest = e
		if d < 1.8:
			close_count += 1
	if nearest == null:
		return out
	var to_e := Iso.to_cart(nearest.global_position - global_position)
	out["aim"] = to_e
	if best > float(_weapon["range"]) * 0.8:
		out["move"] = to_e.normalized()
	out["attack"] = best <= float(_weapon["range"]) + 0.3
	out["heavy"] = close_count >= 2
	_bot_dash_timer -= delta
	if _bot_dash_timer <= 0.0 and hp < max_hp * 0.5:
		out["dash"] = true
		out["move"] = -to_e.normalized()
		_bot_dash_timer = 3.0
	return out
