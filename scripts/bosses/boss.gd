## Boss — kat boss'larının ortak temeli (Aşama 7). Enemy'nin savaş arayüzünü (hasar, element durumları, bağışıklık,
## İnfaz, can barı) kullanır; yapay zekâsı ayrıdır: saldırılar bosses.json'daki sıradan, art arda aynısı gelmeyecek
## şekilde seçilir, aralarında attack_gap sn beklenir. Her saldırının yerde renkli uyarı işareti vardır (EnemyHazard,
## EnemyProjectile ya da boss'un kendi çizdiği işaret). Canı %50'ye inince 2. faz başlar.
## Alt sınıflar: Morvath, Mycela, Kordrak, Nyxthar. Saldırı başlatma start_attack(id) -> süre, mekanik tick_mechanic(),
## hareket move_dir(); zamanlanmış adımlar schedule(gecikme, fonksiyon) ile.
class_name Boss
extends Enemy

var arena: BossArena
var bdata: Dictionary
var phase: int = 1
## HUD'da boss can barının altında görünen durum (ör. "Göz kapağı KAPALI — duvardaki gözleri kır!").
var status_text: String = ""
## Kullanılan saldırılar: id -> [1. fazda, 2. fazda] (testler için).
var attack_log: Dictionary = {}
var overlay: BossOverlay
## Gövdenin üstüne çizilen ayrıntılar (Morvath'ın gözü, Kordrak'ın çekirdeği): draw_top().
var top_layer: TopLayer

var _time: float = 0.0
var _gap_t: float = 2.0
var _busy_t: float = 0.0
var _last_attack: String = ""
var _sched: Array = []            ## [zaman, Callable]
var _phase_banner_t: float = 0.0
var _last_player_attacks: int = -1


## boss id -> sınıf
static func create(id: String) -> Boss:
	var b: Boss
	match id:
		"morvath": b = Morvath.new()
		"mycela": b = Mycela.new()
		"kordrak": b = Kordrak.new()
		"nyxthar": b = Nyxthar.new()
		_: b = Boss.new()
	b.boss_id = id
	b.is_boss = true
	return b


func _setup_stats() -> void:
	bdata = DataDB.table("bosses")["bosses"][boss_id]
	var st: Dictionary = bdata["stats"]
	data = {"name": bdata["name"], "placeholder_color": _body_color(), "ai": "boss"}
	ai = "boss"
	attack = {"type": "none"}
	attack_type = "none"
	max_hp = float(st["hp"]) * hp_mult
	if hp_override > 0.0:
		max_hp = hp_override
	hp = max_hp
	damage = float(st["damage"]) * damage_mult
	move_speed_tiles = float(st["move_speed"])
	radius_tiles = float(st["radius"])
	attack_range = 1.0
	attack_arc = 90.0
	windup = 1.0
	attack_cd_max = 1.0
	knockback_resist = 1.0
	body_scale = 2.2
	display_name = str(bdata["name"])
	defense = DamageCalc.Defense.new((bdata["immune"] as Array).duplicate(), [], (bdata["weak"] as Array).duplicate(), 0.0)
	status = StatusEffects.new(true)
	for a: Dictionary in bdata["attacks"]:
		attack_log[str(a["id"])] = [0, 0]
	_gap_t = 1.5


func _body_color() -> String:
	return "#c04050"


func _ready() -> void:
	super._ready()
	visual.body_height = 32.0 * clampf(radius_tiles / 0.35, 1.0, 2.6)
	visual.body_width = 18.0 * clampf(radius_tiles / 0.35, 1.0, 2.6)
	visual.show_weapon = false
	top_layer = TopLayer.new()
	top_layer.boss = self
	add_child(top_layer)
	overlay = BossOverlay.new()
	overlay.boss = self
	get_parent().add_child.call_deferred(overlay)
	start_fight()


## Dövüş başında (mekaniklerin kurulumu). Alt sınıflar geçersiz kılar.
func start_fight() -> void:
	pass


func attack_data(id: String) -> Dictionary:
	for a: Dictionary in bdata["attacks"]:
		if str(a["id"]) == id:
			return a
	return {}


func mech() -> Dictionary:
	return bdata["mechanic"]


func p2() -> Dictionary:
	return bdata["phase2"]


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_t += delta
	_anim_t += delta
	_immune_text_cd = maxf(_immune_text_cd - delta, 0.0)
	_hp_bar_visible_t = maxf(_hp_bar_visible_t - delta, 0.0)
	_phase_banner_t = maxf(_phase_banner_t - delta, 0.0)
	_tick_status(delta)
	if dead:
		return
	_time += delta
	summons = summons.filter(func(x: Variant) -> bool: return is_instance_valid(x) and not (x as Node2D).get("dead"))
	_run_schedule()
	if dead:
		return
	if target == null or not is_instance_valid(target):
		target = get_tree().get_first_node_in_group("player") as Node2D
	if state == State.SPAWN and _t >= SPAWN_TIME:
		_set_state(State.CHASE)
	if phase == 1 and hp <= max_hp * float(DataDB.get_value("bosses", "phase2_threshold")):
		phase = 2
		_phase_banner_t = float(DataDB.get_value("bosses", "phase2_banner_sec"))
		Events.floating_text.emit(global_position + Vector2(0, -140), "2. FAZ!", Color(1.0, 0.35, 0.3), 34)
		Events.area_pulse.emit(global_position, 3.0, Color(1.0, 0.3, 0.3))
		enter_phase2()
	tick_mechanic(delta)
	var acting := status.can_act() and state != State.SPAWN
	var move := Vector2.ZERO
	if acting and _target_visible():
		if _busy_t > 0.0:
			_busy_t -= delta
		else:
			_gap_t -= delta
			if _gap_t <= 0.0:
				var id := choose_attack()
				if id != "":
					_last_attack = id
					(attack_log[id] as Array)[phase - 1] = int((attack_log[id] as Array)[phase - 1]) + 1
					_busy_t = start_attack(id)
				_gap_t = float(bdata["attack_gap"])
		move = move_dir(delta)
		var to_t := Iso.to_cart(target.global_position - global_position)
		if to_t.length() > 0.01 and _busy_t <= 0.0:
			facing_cart = to_t.normalized()
	visual.set_facing(facing_cart)
	velocity = Iso.to_screen(move * Iso.tiles(current_speed() * status.speed_mult()))
	move_and_slide()
	_update_tint()
	queue_redraw()
	if overlay and is_instance_valid(overlay):
		overlay.queue_redraw()
	top_layer.queue_redraw()


## Sıradaki saldırı: art arda aynısı gelmez; alt sınıf koşula göre eleyebilir (can_use).
func choose_attack() -> String:
	var opts: Array[String] = []
	for a: Dictionary in bdata["attacks"]:
		var id := str(a["id"])
		if id != _last_attack and can_use(id):
			opts.append(id)
	if opts.is_empty():
		for a2: Dictionary in bdata["attacks"]:
			if can_use(str(a2["id"])):
				opts.append(str(a2["id"]))
	if opts.is_empty():
		return ""
	return opts[rng.randi_range(0, opts.size() - 1)]


func can_use(_id: String) -> bool:
	return true


## Saldırıyı başlatır; saldırının sürdüğü süreyi (sn) döndürür (bu sürede yeni saldırı başlamaz).
func start_attack(_id: String) -> float:
	return 0.0


func tick_mechanic(_delta: float) -> void:
	pass


func enter_phase2() -> void:
	pass


## Yürüme yönü (düz uzay birim vektör ya da sıfır).
func move_dir(_delta: float) -> Vector2:
	return Vector2.ZERO


func current_speed() -> float:
	return move_speed_tiles


# --- zamanlayıcı ---

## delay sn sonra fn çağrılır (boss ölürse iptal).
func schedule(delay: float, fn: Callable) -> void:
	_sched.append([_time + delay, fn])


func _run_schedule() -> void:
	if _sched.is_empty():
		return
	var due: Array = []
	var keep: Array = []
	for s: Array in _sched:
		if float(s[0]) <= _time:
			due.append(s)
		else:
			keep.append(s)
	_sched = keep
	for s2: Array in due:
		if dead:
			return
		(s2[1] as Callable).call()


# --- saldırı yardımcıları ---

## Yerde işaretli tehlike koyar (hasar = boss hasarı × mult).
func hazard(label: String, pos: Vector2, shape: String, warn: float, mult: float, props: Dictionary = {}) -> EnemyHazard:
	var h := EnemyHazard.new()
	h.label = label
	h.shape = shape
	h.warn = warn
	h.damage = damage * mult
	h.source = self
	for k: String in props.keys():
		h.set(k, props[k])
	get_parent().add_child(h)
	h.global_position = pos
	return h


## Yolu önce işaretlenen mermi.
func shoot(label: String, from: Vector2, dir: Vector2, warn: float, mult: float, speed: float, range_tiles: float, kind: String, look: String) -> EnemyProjectile:
	var p := EnemyProjectile.new()
	p.label = label
	p.dir_cart = dir
	p.warn = warn
	p.damage = damage * mult
	p.speed_tiles = speed
	p.max_range = range_tiles
	p.kind = kind
	p.look = look
	p.source = self
	get_parent().add_child(p)
	p.global_position = from
	return p


## Boss'un kendi çizdiği işaretler (Bakış Işını) test kaydına eklenir.
func log_telegraph(label: String, warn: float) -> void:
	if EnemyHazard.log_enabled:
		EnemyHazard.telegraph_log.append({"label": label, "warn": warn, "shape": "custom", "mode": "custom"})


func add_minion(id: String, pos: Vector2) -> Node2D:
	var s := spawn_add(id, pos)
	if s:
		summons.append(s)
	return s


func alive_minions(id: String) -> Array[Node2D]:
	var out: Array[Node2D] = []
	for s: Variant in summons:
		if is_instance_valid(s) and not (s as Node2D).get("dead") and str((s as Node2D).get("enemy_id")) == id:
			out.append(s)
	return out


func player() -> Player:
	return target as Player


## Oyuncunun bu kare yaptığı ateş vuruşları pos'un radius karo yakınına değdi mi? (Mycela'nın bulutları,
## Nyx'thar'ın meşaleleri). Ateş mermisi, ateş alanı ya da menzildeki ateşli yakın saldırı sayılır.
func fire_near(pos: Vector2, radius: float) -> bool:
	var p := player()
	if p == null or p.dead:
		return false
	for n: Node in get_parent().get_children():
		if n is Projectile:
			var pr := n as Projectile
			if pr.weapon and pr.weapon.element == "fire" and Iso.tile_distance(pr.global_position, pos) <= radius + pr.radius_tiles:
				return true
		elif n is GroundEffect:
			var ge := n as GroundEffect
			if ge.weapon and ge.weapon.element == "fire" and Iso.tile_distance(ge.global_position, pos) <= radius + ge.radius:
				return true
	return false


## Oyuncu bu karede yeni bir yakın saldırı yaptıysa ve ateş silahıyla pos'a uzanıyorsa true (fire_near'a ek).
func fire_swing_reaches(pos: Vector2, radius: float) -> bool:
	var p := player()
	if p == null or p.dead or p.weapon().element != "fire":
		return false
	var to := Iso.to_cart(pos - p.global_position)
	var d := to.length() / Iso.KARO
	return d <= p.attack_range() + radius and (d < 0.5 or to.normalized().dot(p.facing_cart) > 0.3)


## Bu karede oyuncunun saldırı sayacı değişti mi (yeni saldırı)?
func player_swung() -> bool:
	var p := player()
	if p == null:
		return false
	var c := p.attack_count()
	var changed := _last_player_attacks >= 0 and c != _last_player_attacks
	_last_player_attacks = c
	return changed


func _zero_damage_text() -> String:
	return "BAĞIŞIK"


func _die(dir_cart: Vector2) -> void:
	for n: Node in get_tree().get_nodes_in_group("enemy_hazards"):
		if n.get("source") == self and n.has_method("dismiss"):
			n.call("dismiss")
	for s: Variant in summons:
		if is_instance_valid(s) and not (s as Node2D).get("dead"):
			(s as Node2D).call("dissolve")
	summons.clear()
	_sched.clear()
	if overlay and is_instance_valid(overlay):
		overlay.queue_free()
	super._die(dir_cart)


## Gövdenin üstündeki ayrıntılar (TopLayer çağırır). Alt sınıflar çizer.
func draw_top(_n: Node2D) -> void:
	pass


## Gövdenin üstünde çizen küçük düğüm (gövdeden sonra eklenir, onun önünde görünür).
class TopLayer:
	extends Node2D
	var boss: Boss

	func _draw() -> void:
		if boss and not boss.dead:
			boss.draw_top(self)


## Arena üstü katman (bulut sisi, karanlık, lav kanalları); BossOverlay çağırır. Alt sınıflar çizer.
func draw_overlay(_o: Node2D) -> void:
	pass


## Arena karosunu (dünya konumu) üst katmanda boyar.
func paint_cell(o: Node2D, cell: Vector2i, col: Color) -> void:
	var c: Vector2 = o.to_local(arena.cell_to_world.call(cell))
	o.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -16), c + Vector2(32, 0), c + Vector2(0, 16), c + Vector2(-32, 0)]), col)
