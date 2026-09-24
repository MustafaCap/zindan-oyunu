## EnemyMelee — yakın dövüş düşmanı (İskelet Savaşçı, Mağara Faresi; test odasında Damar Kütlesi de bu yapay zekâyı kullanır).
## Durumlar: doğma → takip → hazırlık (yerde kırmızı uyarı) → vuruş → toparlanma. Ölünce söner ve toz saçar.
## Tüm statlar enemies.json > <id>.stats içinden okunur. material_id verilirse (stone, ghost…) o malzemenin
## bağışıklık/zayıflıkları eklenir ve adı "Taş İskelet Savaşçı" gibi olur.
## Aşama 2: element durumları (StatusEffects), bağışıklık ikonları, süreli hasar, donma/sersemleme, Buhar ıskalaması.
class_name EnemyMelee
extends CharacterBody2D

enum State { SPAWN, CHASE, WINDUP, RECOVER, DEAD }

const SPAWN_TIME := 0.6
const DOT_NUMBER_INTERVAL := 0.5

var enemy_id: String = "skeleton_warrior"
var material_id: String = ""
var is_boss: bool = false
var is_elite: bool = false

var display_name: String
var max_hp: float
var hp: float
var damage: float
var move_speed_tiles: float
var radius_tiles: float
var attack_range: float
var attack_arc: float
var windup: float
var attack_cd_max: float
var knockback_resist: float

var defense: DamageCalc.Defense
var status: StatusEffects
var fury_stacks: int = 0

var state: State = State.SPAWN
var dead: bool = false
var facing_cart: Vector2 = Vector2.LEFT
var visual: PlaceholderBody
var target: Node2D
var rng := RandomNumberGenerator.new()

var _t: float = 0.0
var _attack_cd: float = 0.0
var _knock_vel: Vector2 = Vector2.ZERO
var _knock_t: float = 0.0
var _feel: Dictionary
var _hp_bar_visible_t: float = 0.0
var _dot_acc: Dictionary = {"fire": 0.0, "poison": 0.0}
var _dot_timer: float = 0.0
var _base_modulate: Color = Color.WHITE
var _anim_t: float = 0.0
var _immune_text_cd: float = 0.0


func _ready() -> void:
	add_to_group("enemies")
	var data: Dictionary = DataDB.table("enemies")["enemies"][enemy_id]
	var stats: Dictionary = data["stats"]
	_feel = DataDB.get_value("progression", "feel")
	max_hp = float(stats["hp"])
	hp = max_hp
	damage = float(stats["damage"])
	move_speed_tiles = float(stats["move_speed"])
	radius_tiles = float(stats["radius"])
	attack_range = float(stats["attack_range"])
	attack_arc = float(stats["attack_arc_degrees"])
	windup = float(stats["attack_windup"])
	attack_cd_max = float(stats["attack_cooldown"])
	knockback_resist = float(stats["knockback_resist"])

	var immune: Array = (data["immune"] as Array).duplicate()
	var resistant: Array = (data["resistant"] as Array).duplicate()
	var weak: Array = (data["weak"] as Array).duplicate()
	display_name = str(data["name"])
	var body_col := Color(str(data.get("placeholder_color", "#d1ccb8")))
	if material_id != "":
		var mat: Dictionary = DataDB.table("enemies")["materials"][material_id]
		for k: Variant in mat["immune"]:
			if not k in immune: immune.append(k)
		for k: Variant in mat["resistant"]:
			if not k in resistant: resistant.append(k)
		for k: Variant in mat["weak"]:
			if not k in weak: weak.append(k)
		display_name = "%s %s" % [mat["prefix"], display_name]
		body_col = body_col.lerp(Color(str(mat["tint"])), 0.7)
		if material_id == "ghost":
			_base_modulate = Color(1, 1, 1, 0.72)
	defense = DamageCalc.Defense.new(immune, resistant, weak, float(stats["armor"]))
	status = StatusEffects.new(is_boss)

	collision_layer = 4
	collision_mask = 1 | 2 | 4
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionPolygon2D.new()
	shape.polygon = Shapes.iso_ellipse(radius_tiles)
	add_child(shape)

	visual = PlaceholderBody.new()
	visual.body_color = body_col
	visual.head_color = body_col.lightened(0.25)
	visual.body_height = 32.0 * clampf(radius_tiles / 0.35, 0.55, 1.6)
	visual.body_width = 18.0 * clampf(radius_tiles / 0.35, 0.6, 1.6)
	visual.weapon_length = 26.0 * clampf(attack_range / 1.1, 0.5, 1.2)
	add_child(visual)
	visual.scale = Vector2(1, 0.05)
	visual.modulate = Color(_base_modulate, 0.0)
	var tw := create_tween()
	tw.tween_property(visual, "scale", Vector2.ONE, SPAWN_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(visual, "modulate:a", _base_modulate.a, SPAWN_TIME * 0.5)
	_attack_cd = attack_cd_max * 0.5


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_t += delta
	_anim_t += delta
	_immune_text_cd = maxf(_immune_text_cd - delta, 0.0)
	_hp_bar_visible_t = maxf(_hp_bar_visible_t - delta, 0.0)
	_tick_status(delta)
	if dead:
		return
	var acting := status.can_act()
	if acting:
		_attack_cd = maxf(_attack_cd - delta, 0.0)
	if target == null or not is_instance_valid(target):
		target = get_tree().get_first_node_in_group("player") as Node2D

	var move := Vector2.ZERO
	if not acting:
		# Donmuş ya da sersem: hazırlık bozulur
		if state == State.WINDUP:
			_set_state(State.RECOVER)
	else:
		match state:
			State.SPAWN:
				if _t >= SPAWN_TIME:
					_set_state(State.CHASE)
			State.CHASE:
				if target and not target.get("dead"):
					var to_t := Iso.to_cart(target.global_position - global_position)
					facing_cart = to_t.normalized()
					var dist := to_t.length() / Iso.KARO
					if dist <= attack_range * 0.9 and _attack_cd <= 0.0:
						_set_state(State.WINDUP)
					elif dist > attack_range * 0.7:
						move = facing_cart
			State.WINDUP:
				if _t >= windup / maxf(status.speed_mult(), 0.25):
					_strike()
					_set_state(State.RECOVER)
			State.RECOVER:
				if _t >= 0.35:
					_set_state(State.CHASE)

	visual.set_facing(facing_cart)
	visual.lean = 1.0 if (state == State.RECOVER and _t < 0.12) else 0.0
	var vel := Iso.to_screen(move * Iso.tiles(move_speed_tiles * status.speed_mult()))
	if _knock_t > 0.0:
		_knock_t -= delta
		var k := clampf(_knock_t / float(_feel["knockback_duration"]), 0.0, 1.0)
		vel = _knock_vel * k
	velocity = vel
	move_and_slide()
	_update_tint()
	queue_redraw()


func _set_state(s: State) -> void:
	state = s
	_t = 0.0


func _strike() -> void:
	_attack_cd = attack_cd_max
	if target and target.has_method("take_damage") and not target.get("dead"):
		if CombatMath.in_arc(global_position, facing_cart, target.global_position, attack_range, attack_arc, float(target.get("radius_tiles"))):
			if rng.randf() < status.miss_chance():
				Events.floating_text.emit(target.global_position + Vector2(0, -60), "ISKA", Color(0.8, 0.8, 0.8), 20)
				return
			target.call("take_damage", damage, facing_cart)


## Süreli hasar (yanma, zehir) ve durum süreleri.
func _tick_status(delta: float) -> void:
	var dot := status.tick(delta)
	var total := float(dot["burn"]) + float(dot["poison"])
	if total > 0.0:
		hp = maxf(hp - total, 0.0)
		_hp_bar_visible_t = 3.0
		_dot_acc["fire"] = float(_dot_acc["fire"]) + float(dot["burn"])
		_dot_acc["poison"] = float(_dot_acc["poison"]) + float(dot["poison"])
	_dot_timer += delta
	if _dot_timer >= DOT_NUMBER_INTERVAL:
		_dot_timer = 0.0
		var off := 0.0
		for k: String in ["fire", "poison"]:
			if float(_dot_acc[k]) >= 0.5:
				Events.damage_number.emit(global_position + Vector2(18 + off, -30), float(_dot_acc[k]), false, false, k)
				off += 16.0
			_dot_acc[k] = 0.0
	if hp <= 0.0 and not dead:
		_die(Vector2.ZERO)


## Oyuncudan gelen hasar (HitResolver çağırır). info: crit, dir, heavy, kind, immune, secondary
func apply_damage(amount: float, info: Dictionary) -> void:
	if dead:
		return
	var dir: Vector2 = info.get("dir", Vector2.RIGHT)
	var heavy: bool = info.get("heavy", false)
	var crit: bool = info.get("crit", false)
	var kind: String = info.get("kind", DamageCalc.PHYSICAL)
	var secondary: bool = info.get("secondary", false)
	_hp_bar_visible_t = 3.0
	if amount <= 0.0:
		if _immune_text_cd <= 0.0:
			Events.floating_text.emit(global_position + Vector2(0, -56), "BAĞIŞIK", Color(0.75, 0.75, 0.78), 20)
			_immune_text_cd = 0.5
		Events.hit_landed.emit(global_position + Vector2(0, -20), 0.0, false, false, dir)
		return
	hp = maxf(hp - amount, 0.0)
	visual.flash(float(_feel["flash_duration"]), Color.WHITE if kind == DamageCalc.PHYSICAL else Weapon.kind_color(kind).lightened(0.5))
	if not secondary and not status.is_frozen():
		var kb_tiles := float(_feel["knockback_heavy_tiles"] if heavy else _feel["knockback_tiles"]) * (1.0 - knockback_resist)
		var dur := float(_feel["knockback_duration"])
		# Doğrusal yavaşlama ile toplam yol = hız × süre / 2
		_knock_vel = Iso.to_screen(dir * Iso.tiles(kb_tiles) * 2.0 / dur)
		_knock_t = dur
	if heavy and state == State.WINDUP:
		_set_state(State.RECOVER)  # güçlü vuruş hazırlığı böler
	if not secondary:
		Events.hit_landed.emit(global_position + Vector2(0, -20), amount, crit, heavy, dir)
	var off := Vector2(randf_range(-14, 14), -44 if not secondary else -58)
	Events.damage_number.emit(global_position + off, amount, crit, false, kind)
	if hp <= 0.0:
		_die(dir)


## İnfaz: anında ölüm.
func execute(dir: Vector2) -> void:
	if dead:
		return
	hp = 0.0
	_die(dir)


func _die(dir_cart: Vector2) -> void:
	dead = true
	_set_state(State.DEAD)
	remove_from_group("enemies")
	collision_layer = 0
	collision_mask = 0
	Events.enemy_killed.emit(self, is_elite, is_boss)
	Events.enemy_died_fx.emit(global_position + Vector2(0, -16), dir_cart)
	visual.modulate = _base_modulate
	var tw := create_tween()
	tw.tween_interval(0.05)
	tw.tween_property(visual, "position", Iso.to_screen(dir_cart * 14.0), 0.3).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(visual, "scale", Vector2(1.3, 0.1), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(visual, "modulate:a", 0.0, 0.3)
	tw.tween_callback(queue_free)
	queue_redraw()


## Durumlara göre gövde rengi: donmuş buz mavisi, yanan turuncu titreşim, ıslak mavi, zehirli yeşil, gölge mor.
func _update_tint() -> void:
	var c := Color(_base_modulate)
	var a := c.a
	if status.is_frozen():
		c = Color(0.6, 0.9, 1.35)
	else:
		if status.has_element("water"): c = c * Color(0.75, 0.88, 1.15)
		if status.has_element("poison"): c = c * Color(0.8, 1.1, 0.75)
		if status.has_element("dark"): c = c * Color(0.85, 0.7, 1.1)
		if status.has_element("fire"): c = c * Color(1.25, 0.85 + 0.1 * sin(_anim_t * 30.0), 0.6)
		if status.has_element("ice"): c = c.lerp(Color(0.75, 0.95, 1.2), 0.12 * status.chill_stacks)
	c.a = a
	visual.modulate = c


func _draw() -> void:
	if state == State.DEAD:
		return
	# Saldırı uyarısı: hazırlık boyunca dolan kırmızı yay
	if state == State.WINDUP:
		var k := clampf(_t / windup, 0.0, 1.0)
		draw_colored_polygon(Shapes.iso_arc(facing_cart, attack_range, attack_arc, 0.0, 16), Color(1, 0.1, 0.1, 0.18))
		draw_colored_polygon(Shapes.iso_arc(facing_cart, attack_range * k, attack_arc, 0.0, 16), Color(1, 0.15, 0.1, 0.35))
	# Donmuşken buz kabuğu
	if status.is_frozen():
		var ice := Shapes.iso_ellipse(radius_tiles * 1.35, 12)
		draw_colored_polygon(ice, Color(0.7, 0.95, 1.0, 0.35))
		var edge := ice.duplicate()
		edge.append(ice[0])
		draw_polyline(edge, Color(0.85, 1.0, 1.0, 0.9), 2.0)
	var top := -visual.body_height - 22.0
	# Sersemken başın üstünde dönen yıldızlar
	if status.stun_t > 0.0:
		for i: int in 3:
			var a := _anim_t * 6.0 + TAU * i / 3.0
			draw_circle(Vector2(cos(a) * 12.0, top + 10.0 + sin(a) * 4.0), 2.5, Color(1, 0.95, 0.5))
	# Can barı: hasar alınca birkaç saniye görünür
	if _hp_bar_visible_t > 0.0 and hp < max_hp:
		var w := 36.0
		var pos := Vector2(-w * 0.5, top)
		draw_rect(Rect2(pos - Vector2(1, 1), Vector2(w + 2, 6)), Color(0, 0, 0, 0.8))
		draw_rect(Rect2(pos, Vector2(w * hp / max_hp, 4)), Color(0.9, 0.2, 0.2))
	# Etkin durumlar (can barının altında küçük renkli kareler, yığın sayısıyla)
	var list := status.active_list()
	if not list.is_empty():
		var x := -list.size() * 5.0
		for s: Dictionary in list:
			var col := ElementIcons.status_color(str(s["id"]))
			draw_rect(Rect2(Vector2(x, top + 7), Vector2(8, 8)), Color(0, 0, 0, 0.85))
			draw_rect(Rect2(Vector2(x + 1, top + 8), Vector2(6, 6)), col)
			if int(s["stacks"]) > 1:
				draw_string(ThemeDB.fallback_font, Vector2(x + 1, top + 25), str(s["stacks"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)
			x += 10.0
	# Bağışıklık ve zayıflık ikonları (her zaman görünür, GDD: haksız run'ları önlemek için)
	var badges: Array = []
	for k2: Variant in defense.immune:
		badges.append([str(k2), "immune"])
	for k3: Variant in defense.weak:
		badges.append([str(k3), "weak"])
	if not badges.is_empty():
		var bx := -(badges.size() - 1) * 9.0
		for b: Array in badges:
			ElementIcons.draw_badge(self, b[0], Vector2(bx, top - 12.0), 7.5, b[1])
			bx += 18.0
