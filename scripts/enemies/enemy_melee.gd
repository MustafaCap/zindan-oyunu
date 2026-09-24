## EnemyMelee — yakın dövüş düşmanı (Aşama 1: İskelet Savaşçı).
## Durumlar: doğma → takip → hazırlık (yerde kırmızı uyarı) → vuruş → toparlanma. Ölünce söner ve toz saçar.
## Tüm statlar enemies.json > <id>.stats içinden okunur.
class_name EnemyMelee
extends CharacterBody2D

enum State { SPAWN, CHASE, WINDUP, RECOVER, DEAD }

const SPAWN_TIME := 0.6

var enemy_id: String = "skeleton_warrior"
var max_hp: float
var hp: float
var armor: float
var damage: float
var move_speed_tiles: float
var radius_tiles: float
var attack_range: float
var attack_arc: float
var windup: float
var attack_cd_max: float
var knockback_resist: float

var state: State = State.SPAWN
var dead: bool = false
var facing_cart: Vector2 = Vector2.LEFT
var visual: PlaceholderBody
var target: Node2D

var _t: float = 0.0
var _attack_cd: float = 0.0
var _knock_vel: Vector2 = Vector2.ZERO
var _knock_t: float = 0.0
var _feel: Dictionary
var _caps: Dictionary
var _hp_bar_visible_t: float = 0.0


func _ready() -> void:
	add_to_group("enemies")
	var stats: Dictionary = DataDB.table("enemies")["enemies"][enemy_id]["stats"]
	_feel = DataDB.get_value("progression", "feel")
	_caps = DataDB.get_value("progression", "stat_caps")
	max_hp = float(stats["hp"])
	hp = max_hp
	armor = float(stats["armor"])
	damage = float(stats["damage"])
	move_speed_tiles = float(stats["move_speed"])
	radius_tiles = float(stats["radius"])
	attack_range = float(stats["attack_range"])
	attack_arc = float(stats["attack_arc_degrees"])
	windup = float(stats["attack_windup"])
	attack_cd_max = float(stats["attack_cooldown"])
	knockback_resist = float(stats["knockback_resist"])

	collision_layer = 4
	collision_mask = 1 | 2 | 4
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionPolygon2D.new()
	shape.polygon = Shapes.iso_ellipse(radius_tiles)
	add_child(shape)

	visual = PlaceholderBody.new()
	visual.body_color = Color(0.82, 0.8, 0.72)
	visual.head_color = Color(0.93, 0.92, 0.86)
	visual.body_height = 32.0
	add_child(visual)
	visual.scale = Vector2(1, 0.05)
	visual.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(visual, "scale", Vector2.ONE, SPAWN_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(visual, "modulate:a", 1.0, SPAWN_TIME * 0.5)
	_attack_cd = attack_cd_max * 0.5


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_t += delta
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	_hp_bar_visible_t = maxf(_hp_bar_visible_t - delta, 0.0)
	if target == null or not is_instance_valid(target):
		target = get_tree().get_first_node_in_group("player") as Node2D

	var move := Vector2.ZERO
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
			if _t >= windup:
				_strike()
				_set_state(State.RECOVER)
		State.RECOVER:
			if _t >= 0.35:
				_set_state(State.CHASE)

	visual.set_facing(facing_cart)
	visual.lean = 1.0 if (state == State.RECOVER and _t < 0.12) else 0.0
	var vel := Iso.to_screen(move * Iso.tiles(move_speed_tiles))
	if _knock_t > 0.0:
		_knock_t -= delta
		var k := clampf(_knock_t / float(_feel["knockback_duration"]), 0.0, 1.0)
		vel = _knock_vel * k
	velocity = vel
	move_and_slide()
	queue_redraw()


func _set_state(s: State) -> void:
	state = s
	_t = 0.0


func _strike() -> void:
	_attack_cd = attack_cd_max
	if target and target.has_method("take_damage") and not target.get("dead"):
		if CombatMath.in_arc(global_position, facing_cart, target.global_position, attack_range, attack_arc, float(target.get("radius_tiles"))):
			target.call("take_damage", damage, facing_cart)


## Oyuncudan gelen vuruş.
func take_hit(amount: float, is_crit: bool, dir_cart: Vector2, heavy: bool) -> void:
	if dead:
		return
	var dmg := CombatMath.apply_reduction(amount, armor, float(_caps["damage_reduction"]))
	hp = maxf(hp - dmg, 0.0)
	_hp_bar_visible_t = 3.0
	visual.flash(float(_feel["flash_duration"]))
	var kb_tiles := float(_feel["knockback_heavy_tiles"] if heavy else _feel["knockback_tiles"]) * (1.0 - knockback_resist)
	var dur := float(_feel["knockback_duration"])
	# Doğrusal yavaşlama ile toplam yol = hız × süre / 2
	_knock_vel = Iso.to_screen(dir_cart * Iso.tiles(kb_tiles) * 2.0 / dur)
	_knock_t = dur
	if heavy and state == State.WINDUP:
		_set_state(State.RECOVER)  # güçlü vuruş hazırlığı böler
	Events.hit_landed.emit(global_position + Vector2(0, -20), dmg, is_crit, heavy, dir_cart)
	Events.damage_number.emit(global_position + Vector2(0, -44), dmg, is_crit, false)
	if hp <= 0.0:
		_die(dir_cart)


func _die(dir_cart: Vector2) -> void:
	dead = true
	_set_state(State.DEAD)
	remove_from_group("enemies")
	collision_layer = 0
	collision_mask = 0
	Events.enemy_killed.emit(self, false, false)
	Events.enemy_died_fx.emit(global_position + Vector2(0, -16), dir_cart)
	var tw := create_tween()
	tw.tween_interval(0.05)
	tw.tween_property(visual, "position", Iso.to_screen(dir_cart * 14.0), 0.3).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(visual, "scale", Vector2(1.3, 0.1), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(visual, "modulate:a", 0.0, 0.3)
	tw.tween_callback(queue_free)
	queue_redraw()


func _draw() -> void:
	if state == State.DEAD:
		return
	# Saldırı uyarısı: hazırlık boyunca dolan kırmızı yay
	if state == State.WINDUP:
		var k := clampf(_t / windup, 0.0, 1.0)
		draw_colored_polygon(Shapes.iso_arc(facing_cart, attack_range, attack_arc, 0.0, 16), Color(1, 0.1, 0.1, 0.18))
		draw_colored_polygon(Shapes.iso_arc(facing_cart, attack_range * k, attack_arc, 0.0, 16), Color(1, 0.15, 0.1, 0.35))
	# Can barı: hasar alınca birkaç saniye görünür
	if _hp_bar_visible_t > 0.0 and hp < max_hp:
		var w := 36.0
		var pos := Vector2(-w * 0.5, -visual.body_height - 22)
		draw_rect(Rect2(pos - Vector2(1, 1), Vector2(w + 2, 6)), Color(0, 0, 0, 0.8))
		draw_rect(Rect2(pos, Vector2(w * hp / max_hp, 4)), Color(0.9, 0.2, 0.2))
