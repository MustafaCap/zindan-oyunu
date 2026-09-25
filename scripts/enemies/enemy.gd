## Enemy — sıradan düşmanlar, elitler ve boss yardımcıları (Aşama 7; Aşama 1-6'daki Enemy'nin yerini aldı).
## Veri odaklı: enemies.json > enemies (ya da boss_adds) kaydının ai, attack, abilities, on_death ve front_shield alanları
## davranışı belirler (Uygulamada Verilen Kararlar > Düşmanlar ve boss'lar).
##   ai:      chase (oyuncuya yürür), kite (mesafe korur), wall (duvara yapışık), support (dostlarının yanında kalır,
##            oyuncudan uzak durur), inert (hareketsiz, saldırmaz).
##   attack:  arc (yakın yay), projectile (mermi), beam (ışın), slam (etrafına alan), lunge (atılıp ısırma), cone (çığlık).
##   abilities: heal (dostları iyileştirir), summon (düşman çağırır), pull (oyuncuyu çeker), stealth (görünmezleşip arkadan).
## Durumlar: doğma → takip → hazırlık (yerde işaret dolar) → eylem (atılma) → toparlanma; STEALTH: Gölge görünmezken.
## Kat ölçeklemesi (floor_scaling) can ve hasarı çarpar; elit ×3 can (sürüde elite_hp_mult), ×1,5 hasar, ×1,35 boy ve
## bir aura (Hız, Kalkan, Yenilenme, Öfke) taşır. Demir Muhafız'ın kalkanı önden gelen birincil vuruşları engeller.
## Aşama 2: element durumları, bağışıklık ikonları, süreli hasar, donma/sersemleme, Buhar ıskalaması.
class_name Enemy
extends CharacterBody2D

enum State { SPAWN, CHASE, WINDUP, ACTION, RECOVER, STEALTH, DEAD }

const SPAWN_TIME := 0.6
const DOT_NUMBER_INTERVAL := 0.5
const RECOVER_TIME := 0.35
const AURA_REFRESH := 0.25

var enemy_id: String = "skeleton_warrior"
var material_id: String = ""
var floor_index: int = 1
var is_boss: bool = false
var is_elite: bool = false
## Elitin aurası (elite_auras id'si); boşsa kendi rng'siyle seçilir.
var elite_aura: String = ""
## Çağrılan düşman ya da boss yardımcısı: XP, altın ve iksir vermez, öldürme sayılmaz.
var no_reward: bool = false
## Çağıran (Boşluk Çağırıcı ya da boss): o ölünce bu da dağılır.
var summoner: Node2D
## Hata ayıklama kuklası: yürümez, saldırmaz, geri savrulmaz (test odası). hp_override > 0 ise can o olur.
var dummy: bool = false
var hp_override: float = 0.0
## Ek can/hasar çarpanı ve gövde ölçeği (elit ve kat ölçeklemesine ek; testler ve hata ayıklama için).
var hp_mult: float = 1.0
var damage_mult: float = 1.0
var body_scale: float = 1.0
var name_override: String = ""
## Boss'un kaydı (bosses.json id'si; ilk kesiş bonusu için). Boss değilse boş.
var boss_id: String = ""
## Zindanda engellerin etrafından dolaşma: (kendi konumu, hedef konumu) -> düz uzayda birim yön (DungeonNav).
var navigator: Callable
## (from, to) -> bool: görüş hattı (zindanda duvar ve engeller). Yoksa her zaman açık.
var los: Callable
## (dünya noktası) -> bool: orada durulabilir mi (Gölge'nin ışınlanması). Yoksa her yer.
var can_stand: Callable
## (id, dünya noktası, çağıran) -> Node2D: çağrılan düşmanı sahneye koyar ve odanın canlılarına ekler.
var spawner: Callable

var data: Dictionary
var ai: String = "chase"
var attack: Dictionary = {}
var attack_type: String = "arc"
var attack_kind: String = DamageCalc.PHYSICAL
var priority: bool = false
var shield: Dictionary = {}
var untargetable: bool = false

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
var keep_distance: float = 0.0

var defense: DamageCalc.Defense
var status: StatusEffects
var fury_stacks: int = 0
## Yakındaki elitlerin auralarından gelen etkiler: move, attack_speed, damage_taken, damage, regen
var aura_mods: Dictionary = {"move": 0.0, "attack_speed": 0.0, "damage_taken": 0.0, "damage": 0.0, "regen": 0.0}

var state: State = State.SPAWN
var dead: bool = false
var facing_cart: Vector2 = Vector2.LEFT
var visual: PlaceholderBody
var target: Node2D
var rng := RandomNumberGenerator.new()
var summons: Array[Node2D] = []

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
var _abilities: Array[Dictionary] = []
var _action: Dictionary = {}          ## hazırlıktaki eylem: {"kind": attack/pull/summon, ...}
var _aim_cart: Vector2 = Vector2.LEFT
var _lunge_left: float = 0.0
var _lunge_hit: bool = false
var _aura_t: float = 0.0
var _beam_fx_t: float = 0.0
var _beam_fx_len: float = 0.0
var _heal_fx_t: float = 0.0
var _block_text_cd: float = 0.0


## enemies.json'daki kayıt: temel düşman, boss yardımcısı ya da varyant ([temel, malzeme]).
static func record(id: String) -> Dictionary:
	var t: Dictionary = DataDB.table("enemies")
	if (t["enemies"] as Dictionary).has(id):
		return t["enemies"][id]
	if (t["boss_adds"] as Dictionary).has(id):
		return t["boss_adds"][id]
	return {}


## Varyant id'sini [temel düşman, malzeme]'ye çevirir; varyant değilse [id, ""].
static func resolve_variant(id: String) -> Array:
	var v: Dictionary = DataDB.table("enemies")["variants"]
	if v.has(id) and typeof(v[id]) == TYPE_ARRAY:
		return [str(v[id][0]), str(v[id][1])]
	return [id, ""]


func _ready() -> void:
	add_to_group("enemies")
	_feel = DataDB.get_value("progression", "feel")
	_setup_stats()
	_setup_body()
	_attack_cd = attack_cd_max * 0.5


## Statlar, bağışıklıklar, ad, elit ve kat ölçeklemesi.
func _setup_stats() -> void:
	data = record(enemy_id)
	var stats: Dictionary = data["stats"]
	ai = str(data.get("ai", "chase"))
	attack = data.get("attack", {"type": "arc"})
	attack_type = str(attack.get("type", "arc"))
	attack_kind = str(attack.get("kind", DamageCalc.PHYSICAL))
	priority = bool(data.get("priority", false))
	shield = data.get("front_shield", {})
	max_hp = float(stats["hp"])
	damage = float(stats["damage"])
	move_speed_tiles = float(stats["move_speed"])
	radius_tiles = float(stats["radius"])
	attack_range = float(stats["attack_range"])
	attack_arc = float(stats["attack_arc_degrees"])
	windup = float(stats["attack_windup"])
	attack_cd_max = float(stats["attack_cooldown"])
	knockback_resist = float(stats["knockback_resist"])
	keep_distance = float(stats.get("keep_distance", 0.0))
	for ab: Dictionary in data.get("abilities", []):
		var a := ab.duplicate()
		a["cd"] = float(ab["cooldown"]) * 0.5
		_abilities.append(a)
	# Kat ölçeklemesi (boss'lar kendi değerlerini kullanır)
	var sc: Dictionary = DataDB.table("enemies")["floor_scaling"].get(str(clampi(floor_index, 1, 4)), {"hp": 1.0, "damage": 1.0})
	max_hp *= float(sc["hp"]) * hp_mult
	damage *= float(sc["damage"]) * damage_mult
	if is_elite:
		var el: Dictionary = DataDB.table("enemies")["elite"]
		max_hp *= float(data.get("elite_hp_mult", el["hp_mult"]))
		damage *= float(el["damage_mult"])
		body_scale *= float(el["scale"])
		if elite_aura == "":
			var ids: Array = DataDB.records(DataDB.table("enemies")["elite_auras"])
			elite_aura = str(ids[rng.randi_range(0, ids.size() - 1)])
		add_to_group("elite_aura")
	# Çarpışma gövdesi en fazla ×1,5 büyür: 1 karo kalınlığındaki duvarlardan taşmasın
	radius_tiles *= minf(body_scale, 1.5)
	if attack_type in ["arc", "slam", "cone"]:
		attack_range *= body_scale
	if hp_override > 0.0:
		max_hp = hp_override
	hp = max_hp
	if dummy:
		knockback_resist = 1.0

	var immune: Array = (data["immune"] as Array).duplicate()
	var resistant: Array = (data["resistant"] as Array).duplicate()
	var weak: Array = (data["weak"] as Array).duplicate()
	display_name = str(data["name"])
	if material_id != "":
		var mat: Dictionary = DataDB.table("enemies")["materials"][material_id]
		for k: Variant in mat["immune"]:
			if not k in immune: immune.append(k)
		for k: Variant in mat["resistant"]:
			if not k in resistant: resistant.append(k)
		for k: Variant in mat["weak"]:
			if not k in weak: weak.append(k)
		display_name = "%s %s" % [mat["prefix"], display_name]
		if material_id == "ghost":
			_base_modulate = Color(1, 1, 1, 0.72)
	# Bağışık olunan element zayıflık/direnç listesinde kalmaz (ör. Alevli Sporlu Böcek ateşe bağışık)
	weak = weak.filter(func(k: Variant) -> bool: return not k in immune)
	resistant = resistant.filter(func(k: Variant) -> bool: return not k in immune)
	if is_elite and name_override == "":
		display_name = "Elit " + display_name
	if name_override != "":
		display_name = name_override
	defense = DamageCalc.Defense.new(immune, resistant, weak, float(stats["armor"]))
	status = StatusEffects.new(is_boss)


func _setup_body() -> void:
	collision_layer = 4
	collision_mask = 1 | 2 | 4 | 8
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionPolygon2D.new()
	shape.polygon = Shapes.iso_ellipse(radius_tiles)
	add_child(shape)
	var body_col := Color(str(data.get("placeholder_color", "#d1ccb8")))
	if material_id != "":
		body_col = body_col.lerp(Color(str(DataDB.table("enemies")["materials"][material_id]["tint"])), 0.7)
	visual = PlaceholderBody.new()
	visual.body_color = body_col
	visual.head_color = body_col.lightened(0.25)
	visual.body_height = 32.0 * clampf(radius_tiles / 0.35, 0.55, 1.6)
	visual.body_width = 18.0 * clampf(radius_tiles / 0.35, 0.6, 1.6)
	visual.weapon_length = 26.0 * clampf(attack_range / 1.1, 0.5, 1.2)
	visual.show_weapon = attack_type in ["arc", "lunge", "slam"]
	add_child(visual)
	visual.scale = Vector2(1, 0.05)
	visual.modulate = Color(_base_modulate, 0.0)
	var tw := create_tween()
	var vis := 1.0 + (body_scale - 1.0) * 0.6
	tw.tween_property(visual, "scale", Vector2.ONE * vis, SPAWN_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(visual, "modulate:a", _base_modulate.a, SPAWN_TIME * 0.5)


# --- ana döngü ---

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_t += delta
	_anim_t += delta
	_immune_text_cd = maxf(_immune_text_cd - delta, 0.0)
	_block_text_cd = maxf(_block_text_cd - delta, 0.0)
	_hp_bar_visible_t = maxf(_hp_bar_visible_t - delta, 0.0)
	_beam_fx_t = maxf(_beam_fx_t - delta, 0.0)
	_heal_fx_t = maxf(_heal_fx_t - delta, 0.0)
	_tick_status(delta)
	if dead:
		return
	_tick_aura(delta)
	var acting := status.can_act()
	if acting:
		_attack_cd = maxf(_attack_cd - delta * (1.0 + float(aura_mods["attack_speed"])), 0.0)
		for ab: Dictionary in _abilities:
			ab["cd"] = maxf(float(ab["cd"]) - delta, 0.0)
	if target == null or not is_instance_valid(target):
		target = get_tree().get_first_node_in_group("player") as Node2D

	var move := Vector2.ZERO
	var speed := move_speed_tiles
	if dummy:
		acting = false
		if state != State.SPAWN or _t >= SPAWN_TIME:
			state = State.RECOVER
	if not acting:
		# Donmuş ya da sersem: hazırlık ve atılma bozulur
		if state == State.WINDUP or state == State.ACTION:
			_set_state(State.RECOVER)
	else:
		match state:
			State.SPAWN:
				if _t >= SPAWN_TIME:
					_set_state(State.CHASE)
			State.CHASE:
				move = _think_chase(delta)
			State.WINDUP:
				if _t >= _windup_time():
					_execute_action()
			State.ACTION:
				var step := float(attack.get("lunge_speed", 14.0)) * delta
				move = _aim_cart
				speed = float(attack.get("lunge_speed", 14.0))
				_lunge_left -= step
				if not _lunge_hit and _target_visible() and Iso.tile_distance(global_position, target.global_position) \
						<= float(attack.get("hit_range", 1.0)) + float(target.get("radius_tiles")):
					_lunge_hit = true
					_hit_player(1.0, _aim_cart)
				if _lunge_left <= 0.0 or (is_on_wall() and _t > 0.05):
					_set_state(State.RECOVER)
			State.RECOVER:
				if _t >= RECOVER_TIME:
					_set_state(State.CHASE)
			State.STEALTH:
				if _t >= float(_action.get("duration", 1.4)):
					_reappear()

	visual.set_facing(facing_cart)
	visual.lean = 1.0 if (state == State.RECOVER and _t < 0.12) or state == State.ACTION else 0.0
	var mult := status.speed_mult() * (1.0 + float(aura_mods["move"])) if state != State.ACTION else 1.0
	var vel := Iso.to_screen(move * Iso.tiles(speed * mult))
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


func _windup_time() -> float:
	var base := float(_action.get("warn", windup))
	return base / maxf(status.speed_mult() * (1.0 + float(aura_mods["attack_speed"])), 0.25)


## Takip durumu: yeteneği ya da saldırıyı başlatır, yoksa ai'ye göre yürür. Düz uzayda yürüme yönü döner.
func _think_chase(delta: float) -> Vector2:
	if not _target_visible() or ai == "inert":
		return Vector2.ZERO
	var to_t := Iso.to_cart(target.global_position - global_position)
	var dist := to_t.length() / Iso.KARO
	_face_toward(to_t, delta)
	if _try_ability(dist):
		return Vector2.ZERO
	var need_los := attack_type in ["projectile", "beam", "cone", "lunge"]
	var clear := not need_los or has_los_to(target.global_position)
	if attack_type != "none" and _attack_cd <= 0.0 and dist <= attack_range * 0.9 and clear:
		_begin_attack()
		return Vector2.ZERO
	return _ai_move(to_t, dist, clear)


func _ai_move(to_t: Vector2, dist: float, clear: bool) -> Vector2:
	match ai:
		"wall", "inert":
			return Vector2.ZERO
		"kite":
			if dist < keep_distance * 0.75:
				return -to_t.normalized()
			if dist > attack_range * 0.85 or not clear:
				return _nav_to(target.global_position, to_t)
			return Vector2.ZERO
		"support":
			var ally := _nearest_ally()
			if ally and Iso.tile_distance(global_position, ally.global_position) > 3.5 and dist > keep_distance * 0.6:
				return _nav_to(ally.global_position, Iso.to_cart(ally.global_position - global_position))
			if dist < keep_distance * 0.75:
				return -to_t.normalized()
			if dist > attack_range * 0.85 or not clear:
				return _nav_to(target.global_position, to_t)
			return Vector2.ZERO
		_:
			var stop := attack_range * (0.8 if attack_type == "lunge" else 0.7)
			if dist > stop or not clear:
				return _nav_to(target.global_position, to_t)
			return Vector2.ZERO


func _nav_to(pos: Vector2, fallback_cart: Vector2) -> Vector2:
	return navigator.call(global_position, pos) if navigator.is_valid() else fallback_cart.normalized()


## Yüzünü hedefe çevirir; kalkanlı düşman yavaş döner (arkasına geçilebilsin).
func _face_toward(to_t: Vector2, delta: float) -> void:
	if to_t.length() < 0.01:
		return
	var want := to_t.normalized()
	if shield.is_empty():
		facing_cart = want
		return
	var max_turn := deg_to_rad(float(shield["turn_rate_degrees"])) * delta
	facing_cart = facing_cart.rotated(clampf(facing_cart.angle_to(want), -max_turn, max_turn)).normalized()


func has_los_to(pos: Vector2) -> bool:
	return not los.is_valid() or bool(los.call(global_position, pos))


func _nearest_ally() -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for n: Node in get_tree().get_nodes_in_group("enemies"):
		if n == self or n.get("dead") or n.get("ai") == "support":
			continue
		var d := Iso.tile_distance(global_position, (n as Node2D).global_position)
		if d < best_d:
			best_d = d
			best = n as Node2D
	return best


# --- saldırı ---

func _begin_attack() -> void:
	_action = {"kind": "attack"}
	_aim_cart = facing_cart
	_set_state(State.WINDUP)


func _execute_action() -> void:
	var kind := str(_action.get("kind", "attack"))
	match kind:
		"pull":
			_do_pull()
		"summon":
			_do_summon()
		_:
			_attack_cd = attack_cd_max
			match attack_type:
				"arc":
					_strike_arc(attack_range, attack_arc, 1.0)
				"cone":
					if _strike_arc(attack_range, attack_arc, 1.0) and target.has_method("apply_slow"):
						target.call("apply_slow", float(attack.get("slow_duration", 2.0)), float(attack.get("slow", 0.4)))
					Events.area_pulse.emit(global_position + Iso.to_screen(_aim_cart * Iso.tiles(attack_range * 0.5)), attack_range * 0.5, Weapon.kind_color(attack_kind))
				"slam":
					Events.area_pulse.emit(global_position, attack_range, Color(0.8, 0.6, 0.4))
					if _target_visible() and Iso.tile_distance(global_position, target.global_position) <= attack_range + float(target.get("radius_tiles")):
						_hit_player(1.0, Iso.to_cart(target.global_position - global_position).normalized())
				"projectile":
					_shoot()
				"beam":
					_fire_beam()
				"lunge":
					_lunge_left = float(attack.get("lunge_distance", 3.0))
					_lunge_hit = false
					_set_state(State.ACTION)
					return
	_set_state(State.RECOVER)


func _strike_arc(range_tiles: float, arc: float, mult: float) -> bool:
	if not _target_visible():
		return false
	if CombatMath.in_arc(global_position, _aim_cart, target.global_position, range_tiles, arc, float(target.get("radius_tiles"))):
		return _hit_player(mult, _aim_cart)
	return false


## Oyuncuya vurur (Buhar ıskalaması, Öfke aurası). Vurduysa true.
func _hit_player(mult: float, dir: Vector2) -> bool:
	if not _target_visible() or not target.has_method("take_damage"):
		return false
	if rng.randf() < status.miss_chance():
		Events.floating_text.emit(target.global_position + Vector2(0, -60), "ISKA", Color(0.8, 0.8, 0.8), 20)
		return false
	target.call("take_damage", hit_damage(mult), dir, attack_kind)
	return true


## Bir vuruşun hasarı (Öfke aurası dahil).
func hit_damage(mult: float = 1.0) -> float:
	return damage * mult * (1.0 + float(aura_mods["damage"]))


func _shoot() -> void:
	var p := EnemyProjectile.new()
	p.dir_cart = _aim_cart
	p.speed_tiles = float(attack.get("projectile_speed", 9.0))
	p.max_range = attack_range * 1.3
	p.damage = hit_damage()
	p.kind = attack_kind
	p.look = str(attack.get("look", "arrow"))
	p.label = enemy_id
	p.source = self
	if attack.has("puddle"):
		var pd: Dictionary = (attack["puddle"] as Dictionary).duplicate()
		pd["damage"] = hit_damage(float(pd["damage_mult"]))
		p.puddle = pd
	get_parent().add_child(p)
	p.global_position = global_position + Iso.to_screen(_aim_cart * Iso.tiles(radius_tiles + 0.2))


func _fire_beam() -> void:
	var length := attack_range
	_beam_fx_t = float(attack.get("beam_duration", 0.4))
	_beam_fx_len = length
	if not _target_visible() or not has_los_to(target.global_position):
		return
	var v := Iso.to_cart(target.global_position - global_position) / Iso.KARO
	if Shapes.segment_distance(v, Vector2.ZERO, _aim_cart * length) <= float(attack.get("width", 0.5)) * 0.5 + float(target.get("radius_tiles")):
		_hit_player(1.0, _aim_cart)


# --- yetenekler ---

## Hazır bir yetenek varsa kullanır. Hazırlık gerektiren (çekme, çağırma) ya da görünmezlik başladıysa true.
func _try_ability(dist: float) -> bool:
	for ab: Dictionary in _abilities:
		if float(ab["cd"]) > 0.0:
			continue
		match str(ab["type"]):
			"heal":
				if _do_heal(ab):
					ab["cd"] = float(ab["cooldown"])
			"summon":
				summons = summons.filter(func(s: Variant) -> bool: return is_instance_valid(s) and not (s as Node2D).get("dead"))
				if summons.size() < int(ab["max_alive"]):
					ab["cd"] = float(ab["cooldown"])
					var pts: Array[Vector2] = []
					for i: int in int(ab["max_alive"]) - summons.size():
						pts.append(_free_point_near(global_position, 1.5, 2.5))
					_action = {"kind": "summon", "id": str(ab["id"]), "points": pts, "warn": float(ab["warn"])}
					_set_state(State.WINDUP)
					return true
			"pull":
				if dist <= float(ab["radius"]) and dist >= float(ab["min_dist"]) and has_los_to(target.global_position):
					ab["cd"] = float(ab["cooldown"])
					_action = {"kind": "pull", "radius": float(ab["radius"]), "tiles": float(ab["pull_tiles"]), "warn": float(ab["warn"])}
					_set_state(State.WINDUP)
					return true
			"stealth":
				if dist <= 7.0 and dist >= float(ab["min_dist"]):
					ab["cd"] = float(ab["cooldown"])
					_action = {"kind": "stealth", "duration": float(ab["duration"]), "behind": float(ab["behind_tiles"])}
					_enter_stealth()
					return true
	return false


## Mantar Şifacı: yarıçaptaki yaralı dostları maks canlarının heal_pct'i kadar iyileştirir (Çürüme engeller).
func _do_heal(ab: Dictionary) -> bool:
	var healed := false
	for n: Node in get_tree().get_nodes_in_group("enemies"):
		var e := n as Enemy
		if e == null or e == self or e.dead or e.hp >= e.max_hp * 0.95 or not e.status.can_heal():
			continue
		if Iso.tile_distance(global_position, e.global_position) > float(ab["radius"]):
			continue
		var amount := e.max_hp * float(ab["heal_pct"])
		e.hp = minf(e.hp + amount, e.max_hp)
		e._hp_bar_visible_t = 2.0
		Events.chain_zap.emit(global_position + Vector2(0, -30), e.global_position + Vector2(0, -30), Color(0.5, 1.0, 0.5), false)
		Events.damage_number.emit(e.global_position + Vector2(14, -52), amount, false, true, "heal")
		healed = true
	if healed:
		_heal_fx_t = 0.5
	return healed


func _do_pull() -> void:
	var r := float(_action["radius"])
	Events.area_pulse.emit(global_position, r, Color(0.55, 0.3, 0.9))
	if not _target_visible() or not target.has_method("add_push"):
		return
	var to_me := Iso.to_cart(global_position - target.global_position)
	var d := to_me.length() / Iso.KARO
	if d > r + float(target.get("radius_tiles")) or float(target.get("iframes")) > 0.0:
		return
	var tiles := minf(float(_action["tiles"]), maxf(d - 1.0, 0.0))
	var dur := 0.3
	target.call("add_push", Iso.to_screen(to_me.normalized() * Iso.tiles(tiles / dur)), dur)
	Events.floating_text.emit(target.global_position + Vector2(0, -70), "ÇEKİLDİN", Color(0.7, 0.5, 1.0), 18)


func _do_summon() -> void:
	for pt: Vector2 in _action.get("points", []):
		var s := spawn_add(str(_action["id"]), pt)
		if s:
			summons.append(s)


## Bir yardımcı/çağrılan düşman koyar (ödül vermez; çağıran ölünce dağılır).
func spawn_add(id: String, pos: Vector2) -> Node2D:
	var s: Node2D
	if spawner.is_valid():
		s = spawner.call(id, pos, self)
	else:
		var e := Enemy.new()
		e.enemy_id = id
		e.floor_index = floor_index
		e.no_reward = true
		e.summoner = self
		e.navigator = navigator
		e.los = los
		e.can_stand = can_stand
		get_parent().add_child(e)
		e.global_position = pos
		s = e
	if s:
		Events.area_pulse.emit(pos, 0.8, Color(0.55, 0.3, 0.9))
	return s


## Yakında durulabilir bir nokta (çağırma, ışınlanma).
func _free_point_near(center: Vector2, min_r: float, max_r: float) -> Vector2:
	for i: int in 12:
		var a := rng.randf() * TAU
		var r := rng.randf_range(min_r, max_r)
		var p := center + Iso.to_screen(Vector2(cos(a), sin(a)) * Iso.tiles(r))
		if not can_stand.is_valid() or bool(can_stand.call(p)):
			return p
	return center


func _enter_stealth() -> void:
	_set_state(State.STEALTH)
	untargetable = true
	remove_from_group("enemies")
	collision_layer = 0
	Events.area_pulse.emit(global_position, 0.8, Color(0.4, 0.3, 0.6))


## Görünmezlik biter: oyuncunun arkasına geçer ve hemen (işaretli) saldırır.
func _reappear() -> void:
	untargetable = false
	add_to_group("enemies")
	collision_layer = 4
	if _target_visible():
		var tf: Vector2 = target.get("facing_cart") if target.get("facing_cart") != null else Vector2.RIGHT
		var behind := float(_action.get("behind", 1.2))
		for off: Vector2 in [-tf, -tf.rotated(0.8), -tf.rotated(-0.8), tf.orthogonal(), -tf.orthogonal()]:
			var p: Vector2 = target.global_position + Iso.to_screen(off * Iso.tiles(behind))
			if not can_stand.is_valid() or bool(can_stand.call(p)):
				global_position = p
				break
		facing_cart = Iso.to_cart(target.global_position - global_position).normalized()
		Events.area_pulse.emit(global_position, 0.7, Color(0.4, 0.3, 0.6))
		_begin_attack()
	else:
		_set_state(State.CHASE)


# --- aura ---

func _tick_aura(delta: float) -> void:
	_aura_t -= delta
	if _aura_t <= 0.0:
		_aura_t = AURA_REFRESH
		for k: String in aura_mods.keys():
			aura_mods[k] = 0.0
		var radius: float = float(DataDB.table("enemies")["elite"]["aura_radius"])
		for n: Node in get_tree().get_nodes_in_group("elite_aura"):
			var e := n as Enemy
			if e == null or e.dead or Iso.tile_distance(global_position, e.global_position) > radius:
				continue
			var a: Dictionary = DataDB.table("enemies")["elite_auras"][e.elite_aura]
			aura_mods["move"] = float(aura_mods["move"]) + float(a.get("move_speed", 0.0))
			aura_mods["attack_speed"] = float(aura_mods["attack_speed"]) + float(a.get("attack_speed", 0.0))
			aura_mods["damage_taken"] = float(aura_mods["damage_taken"]) + float(a.get("damage_taken", 0.0))
			aura_mods["damage"] = float(aura_mods["damage"]) + float(a.get("damage", 0.0))
			aura_mods["regen"] = float(aura_mods["regen"]) + float(a.get("regen_pct", 0.0))
	if float(aura_mods["regen"]) > 0.0 and hp < max_hp and status.can_heal():
		hp = minf(hp + max_hp * float(aura_mods["regen"]) * delta, max_hp)


# --- hedef ve hasar ---

## Hedef görülebilir mi? (ölü değil ve Ghost'un Faz'ında değil)
func _target_visible() -> bool:
	if target == null or not is_instance_valid(target) or target.get("dead"):
		return false
	return not (target.has_method("is_untargetable") and bool(target.call("is_untargetable")))


## Demir Muhafız: önden (kalkan yayının içinden) gelen vuruşu engeller mi? Sersem ya da donmuşken kalkan iner.
func blocks_hit_from(pos: Vector2) -> bool:
	if shield.is_empty() or dead or not status.can_act():
		return false
	var to := Iso.to_cart(pos - global_position)
	if to.length() < 0.01:
		return false
	return facing_cart.dot(to.normalized()) > cos(deg_to_rad(float(shield["arc_degrees"]) * 0.5))


## Engellenen vuruşun geri bildirimi (HitResolver çağırır).
func on_blocked(dir: Vector2) -> void:
	_hp_bar_visible_t = 2.0
	if _block_text_cd <= 0.0:
		_block_text_cd = 0.5
		Events.floating_text.emit(global_position + Vector2(0, -60), "ENGELLENDİ", Color(0.7, 0.8, 0.95), 20)
	Events.hit_landed.emit(global_position + Vector2(0, -20), 0.0, false, false, dir)


## Gelen hasarın son düzeltmesi (aura, boss mekanikleri). Boss'lar geçersiz kılar.
func modify_incoming(amount: float, _info: Dictionary) -> float:
	return amount * maxf(1.0 - float(aura_mods["damage_taken"]), 0.0)


## Süreli hasar (yanma, zehir) ve durum süreleri.
func _tick_status(delta: float) -> void:
	var dot := status.tick(delta)
	var total := float(dot["burn"]) + float(dot["poison"])
	if total > 0.0:
		hp = maxf(hp - modify_incoming(total, {"dot": true}), 0.0)
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
	if dead or untargetable:
		return
	var dir: Vector2 = info.get("dir", Vector2.RIGHT)
	var heavy: bool = info.get("heavy", false)
	var crit: bool = info.get("crit", false)
	var kind: String = info.get("kind", DamageCalc.PHYSICAL)
	var secondary: bool = info.get("secondary", false)
	_hp_bar_visible_t = 3.0
	if amount > 0.0:
		amount = modify_incoming(amount, info)
	if amount <= 0.0:
		if _immune_text_cd <= 0.0:
			Events.floating_text.emit(global_position + Vector2(0, -56), _zero_damage_text(), Color(0.75, 0.75, 0.78), 20)
			_immune_text_cd = 0.5
		Events.hit_landed.emit(global_position + Vector2(0, -20), 0.0, false, false, dir)
		return
	hp = maxf(hp - amount, 0.0)
	visual.flash(float(_feel["flash_duration"]), Color.WHITE if kind == DamageCalc.PHYSICAL else Weapon.kind_color(kind).lightened(0.5))
	if not secondary and not status.is_frozen() and state != State.ACTION:
		var kb_tiles := float(_feel["knockback_heavy_tiles"] if heavy else _feel["knockback_tiles"]) * (1.0 - knockback_resist)
		var dur := float(_feel["knockback_duration"])
		if kb_tiles > 0.0:
			# Doğrusal yavaşlama ile toplam yol = hız × süre / 2
			_knock_vel = Iso.to_screen(dir * Iso.tiles(kb_tiles) * 2.0 / dur)
			_knock_t = dur
	if heavy and state == State.WINDUP and not is_boss:
		_set_state(State.RECOVER)  # güçlü vuruş hazırlığı böler
	if not secondary:
		Events.hit_landed.emit(global_position + Vector2(0, -20), amount, crit, heavy, dir)
	var off := Vector2(randf_range(-14, 14), -44 if not secondary else -58)
	Events.damage_number.emit(global_position + off, amount, crit, false, kind)
	after_damage(amount, info)
	if hp <= 0.0:
		_die(dir)


## Hasar sıfır olduğunda görünen yazı (boss'lar değiştirir: "KAPALI").
func _zero_damage_text() -> String:
	return "BAĞIŞIK"


## Hasar alındıktan sonra (boss mekanikleri: Kordrak'ın soğuma yığını, Morvath'ın yıldırım sıçraması).
func after_damage(_amount: float, _info: Dictionary) -> void:
	pass


## İnfaz: anında ölüm.
func execute(dir: Vector2) -> void:
	if dead or untargetable:
		return
	hp = 0.0
	_die(dir)


func _die(dir_cart: Vector2) -> void:
	dead = true
	_set_state(State.DEAD)
	remove_from_group("enemies")
	remove_from_group("elite_aura")
	collision_layer = 0
	collision_mask = 0
	_on_death_effect()
	for s: Variant in summons:
		if is_instance_valid(s) and not (s as Node2D).get("dead"):
			(s as Node2D).call("dissolve")
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


## Çağıranı ölen düşman dağılır (ödülsüz, patlamasız).
func dissolve() -> void:
	if dead:
		return
	no_reward = true
	data = data.duplicate()
	data.erase("on_death")
	hp = 0.0
	_die(Vector2.ZERO)


## Ölüm etkisi: Damar Kütlesi patlar (işaretli), Sporlu Böcek zehir bulutu bırakır.
func _on_death_effect() -> void:
	var od: Dictionary = data.get("on_death", {})
	if od.is_empty() or not is_inside_tree() or dummy:
		return
	var h := EnemyHazard.new()
	h.shape = "circle"
	h.radius = float(od["radius"]) * minf(body_scale, 1.5)
	h.warn = float(od.get("warn", 0.5))
	h.damage = hit_damage(float(od["damage_mult"]))
	h.label = enemy_id + "_death"
	match str(od["type"]):
		"cloud":
			h.mode = "zone"
			h.duration = float(od["duration"])
			h.kind = str(od.get("kind", "poison"))
			h.color = Weapon.kind_color(h.kind)
		_:
			h.mode = "burst"
			h.kind = attack_kind
	get_parent().add_child(h)
	h.global_position = global_position


# --- çizim ---

## Durumlara göre gövde rengi: donmuş buz mavisi, yanan turuncu titreşim, ıslak mavi, zehirli yeşil, gölge mor.
func _update_tint() -> void:
	var c := Color(_base_modulate)
	var a := c.a
	if state == State.STEALTH:
		a = 0.12
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
	if state == State.STEALTH:
		# Görünmezken yerde belli belirsiz bir titreşim
		var sh := Shapes.iso_ellipse(radius_tiles * (1.0 + 0.15 * sin(_anim_t * 12.0)), 14)
		sh.append(sh[0])
		draw_polyline(sh, Color(0.6, 0.5, 0.9, 0.25), 1.5)
		return
	_draw_rings()
	_draw_telegraph()
	if _beam_fx_t > 0.0:
		var k := _beam_fx_t / maxf(float(attack.get("beam_duration", 0.4)), 0.01)
		draw_colored_polygon(Shapes.iso_rect(_aim_cart, _beam_fx_len, float(attack.get("width", 0.5)) * 0.8), Color(1.0, 0.5, 0.6, 0.75 * k))
	if not shield.is_empty():
		var col := Color(0.65, 0.75, 0.9, 0.9) if status.can_act() else Color(0.5, 0.5, 0.55, 0.4)
		var arc := Shapes.iso_arc(facing_cart, radius_tiles * 1.5, float(shield["arc_degrees"]), radius_tiles * 1.2, 12)
		draw_colored_polygon(arc, col)
	# Donmuşken buz kabuğu
	if status.is_frozen():
		var ice := Shapes.iso_ellipse(radius_tiles * 1.35, 12)
		draw_colored_polygon(ice, Color(0.7, 0.95, 1.0, 0.35))
		var edge := ice.duplicate()
		edge.append(ice[0])
		draw_polyline(edge, Color(0.85, 1.0, 1.0, 0.9), 2.0)
	var top := -visual.body_height * maxf(visual.scale.y, 1.0) - 22.0
	if priority:
		# Öncelikli hedef işareti (sarı ünlem)
		var py := top - 30.0
		draw_colored_polygon(PackedVector2Array([Vector2(0, py - 9), Vector2(7, py), Vector2(0, py + 9), Vector2(-7, py)]), Color(1.0, 0.85, 0.2))
		draw_string(ThemeDB.fallback_font, Vector2(-3, py + 5), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.BLACK)
	if _heal_fx_t > 0.0:
		var hr := Shapes.iso_ellipse(0.6 + (0.5 - _heal_fx_t) * 3.0, 20)
		hr.append(hr[0])
		draw_polyline(hr, Color(0.5, 1.0, 0.5, _heal_fx_t * 1.6), 2.0)
	# Sersemken başın üstünde dönen yıldızlar
	if status.stun_t > 0.0:
		for i: int in 3:
			var a := _anim_t * 6.0 + TAU * i / 3.0
			draw_circle(Vector2(cos(a) * 12.0, top + 10.0 + sin(a) * 4.0), 2.5, Color(1, 0.95, 0.5))
	# Can barı: hasar alınca birkaç saniye görünür (öncelikli hedeflerde her zaman)
	if (_hp_bar_visible_t > 0.0 and hp < max_hp) or priority:
		var w := 36.0 * clampf(body_scale, 1.0, 1.6)
		var pos := Vector2(-w * 0.5, top)
		draw_rect(Rect2(pos - Vector2(1, 1), Vector2(w + 2, 6)), Color(0, 0, 0, 0.8))
		draw_rect(Rect2(pos, Vector2(w * hp / max_hp, 4)), Color(0.9, 0.2, 0.2))
	# Etkin durumlar (can barının altında küçük renkli kareler, yığın sayısıyla)
	var list := status.active_list()
	if not list.is_empty():
		var x := -list.size() * 5.0
		for s: Dictionary in list:
			var col2 := ElementIcons.status_color(str(s["id"]))
			draw_rect(Rect2(Vector2(x, top + 7), Vector2(8, 8)), Color(0, 0, 0, 0.85))
			draw_rect(Rect2(Vector2(x + 1, top + 8), Vector2(6, 6)), col2)
			if int(s["stacks"]) > 1:
				draw_string(ThemeDB.fallback_font, Vector2(x + 1, top + 25), str(s["stacks"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col2)
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


## Elit (altın halka + aura rengi), boss (kırmızı halka).
func _draw_rings() -> void:
	if is_elite:
		var a: Dictionary = DataDB.table("enemies")["elite_auras"].get(elite_aura, {})
		var ac := Color(str(a.get("color", "#ffd24a")))
		var aura := Shapes.iso_ellipse(float(DataDB.table("enemies")["elite"]["aura_radius"]), 40)
		aura.append(aura[0])
		draw_polyline(aura, Color(ac, 0.18 + 0.08 * sin(_anim_t * 3.0)), 2.0)
		var ring := Shapes.iso_ellipse(radius_tiles * 1.25, 24)
		ring.append(ring[0])
		draw_polyline(ring, Color(1.0, 0.75, 0.25, 0.85), 3.0)
		var ring2 := Shapes.iso_ellipse(radius_tiles * 1.45, 24)
		ring2.append(ring2[0])
		draw_polyline(ring2, Color(ac, 0.8), 2.0)
	elif is_boss:
		var ring3 := Shapes.iso_ellipse(radius_tiles * 1.25, 24)
		ring3.append(ring3[0])
		draw_polyline(ring3, Color(1.0, 0.25, 0.25, 0.9), 3.0)


## Hazırlık boyunca yerde dolan uyarı işareti (saldırı tipine göre şekil).
func _draw_telegraph() -> void:
	if state != State.WINDUP:
		return
	var k := clampf(_t / maxf(_windup_time(), 0.01), 0.0, 1.0)
	var red := Color(1, 0.1, 0.1)
	match str(_action.get("kind", "attack")):
		"pull":
			var r := float(_action["radius"])
			var purple := Color(0.55, 0.3, 0.9)
			draw_colored_polygon(Shapes.iso_ellipse(r, 32), Color(purple, 0.12))
			var ring := Shapes.iso_ellipse(r * (1.0 - k), 32)
			ring.append(ring[0])
			draw_polyline(ring, Color(purple, 0.9), 2.5)
			return
		"summon":
			for pt: Vector2 in _action.get("points", []):
				var c := Shapes.iso_ellipse(0.7 * k, 16)
				var off := to_local(pt)
				var moved := PackedVector2Array()
				for q: Vector2 in c:
					moved.append(q + off)
				draw_colored_polygon(moved, Color(0.55, 0.3, 0.9, 0.35))
			return
	match attack_type:
		"arc", "cone":
			draw_colored_polygon(Shapes.iso_arc(_aim_cart, attack_range, attack_arc, 0.0, 16), Color(red, 0.18))
			draw_colored_polygon(Shapes.iso_arc(_aim_cart, attack_range * k, attack_arc, 0.0, 16), Color(1, 0.15, 0.1, 0.35))
		"slam":
			draw_colored_polygon(Shapes.iso_ellipse(attack_range, 28), Color(red, 0.16))
			draw_colored_polygon(Shapes.iso_ellipse(attack_range * k, 28), Color(1, 0.15, 0.1, 0.32))
		"projectile":
			draw_colored_polygon(Shapes.iso_rect(_aim_cart, attack_range * 1.3, 0.3), Color(red, 0.12 + 0.1 * k))
			draw_colored_polygon(Shapes.iso_rect(_aim_cart, attack_range * 1.3 * k, 0.3), Color(1, 0.15, 0.1, 0.25))
		"beam":
			var w := float(attack.get("width", 0.5))
			draw_colored_polygon(Shapes.iso_rect(_aim_cart, attack_range, w), Color(red, 0.15))
			draw_colored_polygon(Shapes.iso_rect(_aim_cart, attack_range * k, w), Color(1, 0.15, 0.1, 0.32))
		"lunge":
			var ln := float(attack.get("lunge_distance", 3.0)) + float(attack.get("hit_range", 1.0))
			draw_colored_polygon(Shapes.iso_rect(_aim_cart, ln, radius_tiles * 2.2), Color(red, 0.15))
			draw_colored_polygon(Shapes.iso_rect(_aim_cart, ln * k, radius_tiles * 2.2), Color(1, 0.15, 0.1, 0.3))
