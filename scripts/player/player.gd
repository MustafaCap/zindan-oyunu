## Player — oyuncu karakteri (Aşama 2: Warrior + iki aktif kılıç, Tab ile anında geçiş).
## WASD ile 8 yönde yürür, fareye bakar, Space ile atılır; sol tık yay vuruşu, sağ tık Dönen kesik.
## Vuruşlar HitResolver'dan geçer (hasar formülü, element durumları, kombolar, özellikler).
## Tüm sayılar DataDB'den okunur. autoplay açıkken bir bot oynar (smoke testi için; kombo da yapar).
class_name Player
extends CharacterBody2D

signal died
signal health_changed(hp: float, max_hp: float)

const SlashFx := preload("res://scripts/fx/slash_fx.gd")

var race_id: String = "warrior"
## İki aktif silah (GDD: Kontroller ve Slotlar). Test odası kurar; boşsa yaygın kılıç verilir.
var weapons: Array[Weapon] = []
var active_index: int = 0

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
var defense: DamageCalc.Defense
var combos_done: int = 0

var _race: Dictionary
var _combat: Dictionary
var _feel: Dictionary
var _caps: Dictionary
var _lean_t: float = 0.0
var _bot_dash_timer: float = 0.0
var _bot_swap_cd: float = 0.0


func _ready() -> void:
	add_to_group("player")
	_race = DataDB.table("races")[race_id]
	if weapons.is_empty():
		weapons.append(Weapon.make("sword", "common"))
	_combat = DataDB.get_value("progression", "combat")
	_feel = DataDB.get_value("progression", "feel")
	_caps = DataDB.get_value("progression", "stat_caps")

	max_hp = float(_race["base_hp"])
	hp = max_hp
	armor = float(_race["armor"])
	defense = _make_defense()
	Events.combo_triggered.connect(func(_id: String, _t: Node) -> void: combos_done += 1)
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
	refresh_weapon_visual()
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
	var want_swap := false
	if autoplay:
		var bot := _bot_think(delta)
		move_cart = bot["move"]
		aim_cart = bot["aim"]
		want_attack = bot["attack"]
		want_heavy = bot["heavy"]
		want_dash = bot["dash"]
		want_swap = bot["swap"]
	else:
		move_cart = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		aim_cart = Iso.to_cart(get_global_mouse_position() - global_position)
		want_attack = Input.is_action_pressed("attack_primary")
		want_heavy = Input.is_action_just_pressed("attack_secondary")
		want_dash = Input.is_action_just_pressed("dash")
		want_swap = Input.is_action_just_pressed("swap_weapon")

	if want_swap:
		swap_weapon()

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


func weapon() -> Weapon:
	return weapons[active_index]


## Tab: iki aktif silah arasında anında geçiş (kombolar için ana araç).
func swap_weapon() -> void:
	if weapons.size() < 2:
		return
	active_index = (active_index + 1) % weapons.size()
	visual.weapon_color = Weapon.kind_color(weapon().element)
	Events.weapon_swapped.emit(active_index)


## Silahlar değişince (test odası hata ayıklama tuşları) görseli tazeler.
func refresh_weapon_visual() -> void:
	visual.weapon_color = Weapon.kind_color(weapon().element)


## Sol tık: fare yönünde yay şeklinde vuruş.
func _swing() -> void:
	var wt := weapon().type_data()
	attack_cd = 1.0 / float(wt["attacks_per_sec"])
	_lean_t = 0.12
	var range_tiles := float(wt["range"])
	var arc := float(wt["arc_degrees"])
	var fx := SlashFx.new()
	fx.setup(facing_cart, range_tiles, arc, false, Weapon.kind_color(weapon().element))
	get_parent().add_child(fx)
	fx.global_position = global_position + Vector2(0, -6)
	_hit_enemies(range_tiles, arc, 1.0, false)


## Sağ tık: Dönen kesik — etraftaki herkese hasar.
func _spin_slash() -> void:
	heavy_cd = heavy_cd_max
	_lean_t = 0.12
	var heavy: Dictionary = weapon().type_data()["heavy"]
	var radius := float(heavy["radius"])
	var fx := SlashFx.new()
	fx.setup(facing_cart, radius, 360.0, true, Weapon.kind_color(weapon().element))
	get_parent().add_child(fx)
	fx.global_position = global_position + Vector2(0, -6)
	_hit_enemies(radius, 360.0, float(heavy["damage_mult"]), true)


func _hit_enemies(range_tiles: float, arc: float, mult: float, heavy: bool) -> void:
	var all := get_tree().get_nodes_in_group("enemies")
	var hits: Array[Node2D] = []
	for node: Node in all:
		var e := node as Node2D
		if e == null or not e.has_method("apply_damage") or e.get("dead"):
			continue
		if CombatMath.in_arc(global_position, facing_cart, e.global_position, range_tiles, arc, float(e.get("radius_tiles"))):
			hits.append(e)
	for e: Node2D in hits:
		if e.get("dead"):
			continue
		var dir := Iso.to_cart(e.global_position - global_position)
		if dir.length() < 0.01:
			dir = facing_cart
		var opts := {"skill_mult": mult, "heavy": heavy, "dir": dir.normalized()}
		HitResolver.resolve(self, weapon(), e, opts, all, rng)


## Can Emme (ırk izin veriyorsa). Ghost'un özel iyileşme kuralı Aşama 3'te.
func heal(amount: float) -> void:
	if dead or amount <= 0.0 or not bool(_race["healing"]["lifesteal"]):
		return
	var before := hp
	hp = minf(hp + amount, max_hp)
	if hp - before >= 1.0:
		Events.damage_number.emit(global_position + Vector2(14, -52), hp - before, false, true, "heal")
	health_changed.emit(hp, max_hp)


## Düşmandan gelen hasar (hasar formülünden geçer: ırk direnci ve zırh).
func take_damage(amount: float, _from_dir_cart: Vector2, kind: String = DamageCalc.PHYSICAL) -> void:
	if dead or iframes > 0.0:
		return
	var hit := DamageCalc.Hit.new()
	hit.base_damage = amount
	hit.kind = kind
	var dmg := DamageCalc.compute(hit, defense)
	hp = maxf(hp - dmg, 0.0)
	iframes = float(_combat["player_hurt_iframes"])
	visual.flash(float(_feel["flash_duration"]) * 1.5, Color(1.0, 0.25, 0.25))
	Events.player_damaged.emit(dmg)
	Events.damage_number.emit(global_position + Vector2(0, -40), dmg, false, true, kind)
	health_changed.emit(hp, max_hp)
	if hp <= 0.0:
		_die()


func _make_defense() -> DamageCalc.Defense:
	var d := DamageCalc.Defense.new([], [], [], armor)
	var res: Dictionary = _race["resistances"]
	for k: String in res.keys():
		match str(res[k]):
			"immune": d.immune.append(k)
			"resistant": d.resistant.append(k)
			"weak": d.weak.append(k)
	return d


func _die() -> void:
	dead = true
	collision_layer = 0
	var tw := create_tween()
	tw.tween_property(visual, "rotation", deg_to_rad(80), 0.35).set_trans(Tween.TRANS_BACK)
	tw.parallel().tween_property(visual, "modulate", Color(0.6, 0.6, 0.6, 0.8), 0.35)
	Events.player_died.emit()
	died.emit()


## Smoke testi botu: en yakın düşmana yürür, menzildeyse vurur, kalabalıkta Dönen kesik atar.
## Aşama 2: hedef aktif silahın elementine bağışıksa ya da hedefte diğer silahla kombo yapılabilecekse Tab'a basar.
func _bot_think(delta: float) -> Dictionary:
	var out := {"move": Vector2.ZERO, "aim": facing_cart, "attack": false, "heavy": false, "dash": false, "swap": false}
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
	var wt := weapon().type_data()
	var to_e := Iso.to_cart(nearest.global_position - global_position)
	out["aim"] = to_e
	if best > float(wt["range"]) * 0.8:
		out["move"] = to_e.normalized()
	out["attack"] = best <= float(wt["range"]) + 0.3
	out["heavy"] = close_count >= 2
	_bot_swap_cd -= delta
	if weapons.size() >= 2 and _bot_swap_cd <= 0.0 and out["attack"]:
		var other: Weapon = weapons[(active_index + 1) % weapons.size()]
		var def: DamageCalc.Defense = nearest.get("defense")
		var st: StatusEffects = nearest.get("status")
		var cur_useless := DamageCalc.status_multiplier(weapon().element, def) <= 0.0
		var other_combo := not DamageCalc.is_immune(other.element, def) and not Combos.find(st, other.element).is_empty()
		if cur_useless or other_combo:
			out["swap"] = true
			_bot_swap_cd = 0.4
	_bot_dash_timer -= delta
	if _bot_dash_timer <= 0.0 and hp < max_hp * 0.5:
		out["dash"] = true
		out["move"] = -to_e.normalized()
		_bot_dash_timer = 3.0
	return out
