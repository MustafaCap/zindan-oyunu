## Player — oyuncu karakteri (Aşama 3: 4 ırk, 12 silah tipi, iki aktif silah).
## WASD ile 8 yönde yürür, fareye bakar, Space ile atılır. Sol/sağ tık aktif silahın saldırıları (WeaponAttacks),
## Q/E ırk yetenekleri (RaceAbilities), Tab iki aktif silah arasında geçiş, 1 iksir.
## Irk statları RaceStats'tan (ırk-silah matrisi dahil, aktif silahın ailesine göre), kaynak ve bekleme süreleri
## RaceKit'ten gelir. Bütün vuruşlar deal_hit → HitResolver'dan geçer. Tüm sayılar DataDB'den okunur.
## Girdi üç kaynaktan gelir: klavye/fare, autoplay botu (smoke testi) ya da external_intent (matris testi).
## Aşama 5: zindanda silahlar, Rezonans/Esnek slot ve iksirler Inventory'den gelir (load_loadout); eşya etkileri
## (Rezonans ek hasarı, Esnek slot, tılsımlar, efsanevi pasif ve sağ tık ekleri) ItemEffects'te işlenir.
## Aşama 6: statlara run ödülleri, silah tipi ustalığı ve boss ilk kesiş bonusu eklenir (RunBonuses → RaceStats); ustalığın
## hasar bonusu formülün U terimidir. Boss özel etkileri (GameState.special_effects): Çift vuruş, Kritik zinciri, Kombo
## ustası, Hiddet, Cellat, Element izi, İkinci şans burada; Ek mermi WeaponAttacks'ta, Delici Projectile'da, Rezonans
## güçlendirme ItemEffects'te, Yedek iksir seçildiği anda (DungeonRun) işler.
class_name Player
extends CharacterBody2D

signal died
signal health_changed(hp: float, max_hp: float)

const SlashFx := preload("res://scripts/fx/slash_fx.gd")
const MASK_WALLS := 1
const MASK_OBSTACLES := 8
## Skill hasarı ödülünün işlediği vuruş kaynakları (sağ tık, Q, E).
const SKILL_SOURCES := ["heavy", "q", "e"]

var race_id: String = "warrior"
var level: int = 1
## İki aktif silah (GDD: Kontroller ve Slotlar). Test odası kurar; boşsa yaygın kılıç verilir.
var weapons: Array[Weapon] = []
var active_index: int = 0

var stats: RaceStats
var kit: RaceKit
var max_hp: float
var hp: float
var move_speed_tiles: float
var radius_tiles: float
var defense: DamageCalc.Defense
## Zindanda silahlar, slotlar ve iksirler buradan (null ise test odası: weapons ve _potions yerel).
var inventory: Inventory
var effects: ItemEffects
var _potions: int = 0
var potions: int:
	get: return inventory.potions if inventory else _potions
	set(v):
		if inventory:
			inventory.potions = v
		else:
			_potions = v

var facing_cart: Vector2 = Vector2.RIGHT
var aim_point: Vector2 = Vector2.ZERO     ## farenin (ya da botun hedefinin) dünya konumu
var attack_cd: float = 0.0
var dash_cd: float = 0.0
var dash_cd_max: float = 1.0
var iframes: float = 0.0
var busy_t: float = 0.0                   ## seri yumruk, saplama gibi hareketler sürerken yeni saldırı yok
var dead: bool = false
var autoplay: bool = false
## Geliştirme: hasar almaz (zindan smoke testi --god ile haritanın yürünebilirliğini dener).
var invulnerable: bool = false
## Zindan botu (DungeonAutopilot): düşman yokken bu noktaya yürür / bu noktaya vurur (çatlak duvar). INF = yok.
var bot_waypoint: Vector2 = Vector2.INF
var bot_attack_point: Vector2 = Vector2.INF
## Zindan botu: (kendi konumu, hedef) -> engellerin etrafından dolaşan yön (DungeonNav). Boşsa doğrudan hedefe.
var bot_nav: Callable
## Zindan botu: (kendi konumu, hedef) -> arada engel yok mu. Uzak silahla görüş yoksa bot hedefe yaklaşır.
var bot_los: Callable
## Doluysa girdi buradan okunur (matris testi her karede doldurur). Anahtarlar _read_input ile aynı.
var external_intent: Dictionary = {}

# Yetenek durumları
var rush_t: float = 0.0                   ## Warrior Kalkan Hücumu sürüyor (kalan süre)
var _rush: Dictionary = {}                ## hücumun verisi, silahı, saldırı id'si ve vurulanlar
var phase_t: float = 0.0
var flight_t: float = 0.0
var charging: bool = false                ## Yay: Güçlü atış dolduruluyor
var charge_t: float = 0.0
var spear_out: Projectile                 ## Mızrak havada / saplı
var trap: GroundEffect                    ## Kurulu rün tuzağı

# Testler ve HUD için kayıtlar
var combos_done: int = 0
var damage_by_source: Dictionary = {"light": 0.0, "heavy": 0.0, "q": 0.0, "e": 0.0}
var uses: Dictionary = {"light": 0, "heavy": 0, "q": 0, "e": 0}

var rng := RandomNumberGenerator.new()
var visual: PlaceholderBody

var _race: Dictionary
var _combat: Dictionary
var _feel: Dictionary
var _stats_cache: Dictionary = {}
var _lean_t: float = 0.0
var _attack_counter: int = 0
var _move_override_t: float = 0.0         ## atılma, geri sıçrama, saplama: bu süre boyunca hız sabit
var _move_override_vel: Vector2 = Vector2.ZERO
var _move_override_done: Callable
var _note_cd: float = 0.0
var _bot := {"dash": 0.0, "swap": 0.0, "q": 0.0, "e": 0.0, "hold": 0.0}
var _shape: CollisionPolygon2D


func _ready() -> void:
	add_to_group("player")
	_race = DataDB.table("races")[race_id]
	effects = ItemEffects.new(self)
	if inventory:
		weapons = inventory.active_weapons()
		active_index = inventory.active_index()
		effects.resonance = inventory.resonance_weapon()
		effects.flex = inventory.flex_item()
	if weapons.is_empty():
		weapons.append(Weapon.make("sword", "common"))
	active_index = clampi(active_index, 0, weapons.size() - 1)
	_combat = DataDB.get_value("progression", "combat")
	_feel = DataDB.get_value("progression", "feel")
	kit = RaceKit.new(race_id, level)
	if inventory == null:
		potions = int(DataDB.get_value("progression", "potions.start"))
	radius_tiles = float(_combat["player_radius"])
	dash_cd_max = float(_combat["dash_cooldown"])
	_apply_stats(true)
	Events.combo_triggered.connect(_on_combo)
	Events.enemy_killed.connect(_on_enemy_killed)

	collision_layer = 2
	collision_mask = MASK_WALLS | MASK_OBSTACLES
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_shape = CollisionPolygon2D.new()
	_shape.polygon = Shapes.iso_ellipse(radius_tiles)
	add_child(_shape)

	visual = PlaceholderBody.new()
	visual.body_color = Color(str(_race["placeholder_color"]))
	visual.head_color = Color(0.93, 0.8, 0.66)
	add_child(visual)
	refresh_weapon_visual()
	aim_point = global_position + Vector2(40, 0)
	health_changed.emit(hp, max_hp)


func _exit_tree() -> void:
	if Events.combo_triggered.is_connected(_on_combo):
		Events.combo_triggered.disconnect(_on_combo)
	if Events.enemy_killed.is_connected(_on_enemy_killed):
		Events.enemy_killed.disconnect(_on_enemy_killed)


# --- statlar ---

func weapon() -> Weapon:
	return weapons[active_index]


## Silahın statları: ırk + ailesine göre ırk-silah matrisi + run ödülleri + tipinin ustalığı + ilk kesiş bonusu
## (önbellekli, silah tipine göre). Mermiler ateşlendiği silahın statını kullanır.
func stats_for(w: Weapon) -> RaceStats:
	var key := w.type_id
	if not _stats_cache.has(key):
		_stats_cache[key] = RaceStats.compute(race_id, level, w.family(), RunBonuses.for_weapon(w.type_id))
	return _stats_cache[key]


## Ödül seçilince, ilk kesiş bonusu gelince ya da ustalık değişince statlar yeniden hesaplanır (can oranı korunur).
func refresh_bonuses() -> void:
	_stats_cache.clear()
	_apply_stats()


## Aktif silahla statların tavansız toplamları (ödül havuzu tavana ulaşan statı çıkarır).
func stat_totals() -> Dictionary:
	var t: Dictionary = stats.totals.duplicate()
	t["dash_cooldown_reduction"] = float(t.get("dash_cooldown_reduction", 0.0)) + effects.dash_cooldown_reduction()
	return t


## Aktif silah değişince maks can, hız, zırh ve bonuslar yeniden hesaplanır; can oranı korunur.
func _apply_stats(fill: bool = false) -> void:
	var ratio := 1.0 if fill or max_hp <= 0.0 else hp / max_hp
	stats = stats_for(weapon())
	max_hp = stats.max_hp
	hp = max_hp if fill else clampf(max_hp * ratio, 0.0, max_hp)
	move_speed_tiles = float(_combat["base_move_speed"]) * stats.move_speed_mult
	defense = _make_defense()
	kit.cooldown_reduction = stats.cooldown_reduction
	health_changed.emit(hp, max_hp)


func _make_defense() -> DamageCalc.Defense:
	var d := DamageCalc.Defense.new([], [], [], current_armor())
	var res: Dictionary = _race["resistances"]
	for k: String in res.keys():
		match str(res[k]):
			"immune": d.immune.append(k)
			"resistant": d.resistant.append(k)
			"weak": d.weak.append(k)
	return d


## Zırh = ırk zırhı + hasar azaltma ödülleri. Tavanı DamageCalc uygular.
func current_armor() -> float:
	return stats.armor if stats else 0.0


## Silahın saldırı menzili (ırk menzil bonusu dahil).
func attack_range(w: Weapon = null) -> float:
	var ww := w if w else weapon()
	return float(ww.type_data()["range"]) * (1.0 + stats_for(ww).attack_range_bonus)


## Saldırı hızı bonusu: ırk/matris, ödüller, ustalık + eşyaların geçici bonusu (efsanevi pasif); toplam tavana uyar.
func attack_speed_bonus(w: Weapon = null) -> float:
	var ww := w if w else weapon()
	var extra := effects.attack_speed_bonus() if effects else 0.0
	return minf(float(stats_for(ww).totals["attack_speed"]) + extra, float(DataDB.get_value("progression", "stat_caps.attack_speed")))


func attack_interval(w: Weapon = null) -> float:
	var ww := w if w else weapon()
	return 1.0 / (float(ww.type_data()["attacks_per_sec"]) * maxf(1.0 + attack_speed_bonus(ww), 0.1))


## Şimdiye kadarki saldırı sayısı (zindan çatlak duvarı bir saldırının duvara gelip gelmediğini buradan anlar).
func attack_count() -> int:
	return _attack_counter


func next_attack_id() -> int:
	_attack_counter += 1
	return _attack_counter


func is_flying() -> bool:
	return flight_t > 0.0


func is_phasing() -> bool:
	return phase_t > 0.0


## Düşmanlar Faz sırasında oyuncuyu göremez.
func is_untargetable() -> bool:
	return dead or phase_t > 0.0


# --- ana döngü ---

func _physics_process(delta: float) -> void:
	attack_cd = maxf(attack_cd - delta, 0.0)
	dash_cd = maxf(dash_cd - delta, 0.0)
	iframes = maxf(iframes - delta, 0.0)
	busy_t = maxf(busy_t - delta, 0.0)
	_note_cd = maxf(_note_cd - delta, 0.0)
	_lean_t = maxf(_lean_t - delta, 0.0)
	visual.lean = _lean_t / 0.12
	kit.tick(delta)
	effects.tick(delta)
	_tick_buffs(delta)
	if dead:
		return

	var intent := _read_input(delta)
	aim_point = intent["aim"]
	var aim_cart := Iso.to_cart(aim_point - global_position)
	if aim_cart.length() > 0.01 and _move_override_t <= 0.0:
		facing_cart = aim_cart.normalized()
		visual.set_facing(facing_cart)

	if intent["swap"]:
		swap_weapon()
	if intent["potion"]:
		use_potion()

	if _move_override_t > 0.0:
		_move_override_t -= delta
		velocity = _move_override_vel
		if _move_override_t <= 0.0:
			_move_override_t = 0.0
			if _move_override_done.is_valid():
				var cb := _move_override_done
				_move_override_done = Callable()
				cb.call()
	else:
		var move_cart: Vector2 = intent["move"]
		if intent["dash"] and dash_cd <= 0.0:
			_start_dash(move_cart)
		else:
			var spd := move_speed_tiles * effects.move_speed_mult() * (1.0 + (float(_race["abilities"]["q"].get("speed_bonus", 0.0)) if is_flying() else 0.0))
			velocity = Iso.to_screen(move_cart.limit_length(1.0) * Iso.tiles(spd))
		if intent["q"]:
			RaceAbilities.use(self, "q")
		if intent["e"]:
			RaceAbilities.use(self, "e")
		# Sağ tık: basınca başlar; Yay'da basılı tutup bırakınca atar
		if charging:
			charge_t += delta
			if not intent["heavy_held"]:
				WeaponAttacks.heavy_released(self)
		elif intent["heavy"] and busy_t <= 0.0:
			WeaponAttacks.heavy_pressed(self)
		elif intent["light"] and attack_cd <= 0.0 and busy_t <= 0.0 and not charging:
			WeaponAttacks.light(self)
	move_and_slide()
	_rush_step(delta)


func _tick_buffs(delta: float) -> void:
	if phase_t > 0.0:
		phase_t = maxf(phase_t - delta, 0.0)
		if phase_t <= 0.0:
			end_phase()
	if flight_t > 0.0:
		flight_t -= delta
		# Uçuş bir engelin üstünde biterse oyuncu engelden çıkana kadar uçmaya devam eder.
		if flight_t <= 0.0 and _overlaps_obstacle():
			flight_t = 0.05
		if flight_t <= 0.0:
			end_flight()
	queue_redraw()


## Girdi: {move, aim, light, heavy, heavy_held, q, e, dash, swap, potion}
func _read_input(delta: float) -> Dictionary:
	if not external_intent.is_empty():
		var d := _empty_intent()
		d.merge(external_intent, true)
		return d
	if autoplay:
		return _bot_think(delta)
	return {
		"move": Input.get_vector("move_left", "move_right", "move_up", "move_down"),
		"aim": get_global_mouse_position(),
		"light": Input.is_action_pressed("attack_primary"),
		"heavy": Input.is_action_just_pressed("attack_secondary"),
		"heavy_held": Input.is_action_pressed("attack_secondary"),
		"q": Input.is_action_just_pressed("ability_q"),
		"e": Input.is_action_just_pressed("ability_e"),
		"dash": Input.is_action_just_pressed("dash"),
		"swap": Input.is_action_just_pressed("swap_weapon"),
		"potion": Input.is_action_just_pressed("use_potion"),
	}


func _empty_intent() -> Dictionary:
	return {"move": Vector2.ZERO, "aim": aim_point, "light": false, "heavy": false, "heavy_held": false,
		"q": false, "e": false, "dash": false, "swap": false, "potion": false}


# --- hareket ---

func _start_dash(move_cart: Vector2) -> void:
	var dir := move_cart.normalized() if move_cart.length() > 0.1 else facing_cart
	dash_cd_max = float(_combat["dash_cooldown"]) * (1.0 - dash_cooldown_reduction())
	dash_cd = dash_cd_max
	effects.on_dash()
	iframes = maxf(iframes, float(_combat["dash_iframes"]))
	var dur := float(_combat["dash_duration"])
	var from := global_position
	var done := Callable()
	if GameState.has_special("element_trail"):
		done = func() -> void: _element_trail(from, global_position)
	move_override(Iso.to_screen(dir * Iso.tiles(float(_combat["dash_distance"])) / dur), dur, done)
	Events.player_dashed.emit(global_position)
	afterimage(Color(0.5, 0.8, 1.0, 0.5))


## Space bekleme süresi azaltma: ödüller + Rüzgâr Tüyü, toplam tavana uyar (progression.stat_caps).
func dash_cooldown_reduction() -> float:
	return minf(float(stats.totals.get("dash_cooldown_reduction", 0.0)) + effects.dash_cooldown_reduction(),
		float(DataDB.get_value("progression", "stat_caps.dash_cooldown_reduction")))


## Boss özel etkisi Element izi: atılma yolunun başında, ortasında ve sonunda aktif silahın elementinde yerde iz.
func _element_trail(from: Vector2, to: Vector2) -> void:
	var td := GameState.special("element_trail")
	if td.is_empty() or dead or not is_inside_tree():
		return
	var w := weapon()
	var n := maxi(int(td["segments"]), 1)
	for i: int in n:
		var g := WeaponAttacks.make_ground(self, w, "trail", float(td["damage_pct"]))
		g.mode = "pulses"
		g.look = "trail"
		g.radius = float(td["radius"])
		g.delay = 0.05
		g.pulses = int(td["pulses"])
		g.interval = float(td["interval"])
		g.color = Weapon.kind_color(w.element)
		spawn(g, from.lerp(to, float(i) / maxf(n - 1, 1)))


## Bir süre boyunca sabit hızla hareket (atılma, geri sıçrama, saplama). done: bitince çağrılır.
func move_override(vel_screen: Vector2, duration: float, done: Callable = Callable()) -> void:
	_move_override_vel = vel_screen
	_move_override_t = duration
	_move_override_done = done


func afterimage(color: Color) -> void:
	var ghost := visual.duplicate() as Node2D
	ghost.modulate = color
	get_parent().add_child(ghost)
	ghost.global_position = global_position
	var tw := ghost.create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, 0.25)
	tw.tween_callback(ghost.queue_free)


## Işınlanma (Gölge adımı): hedef nokta duvar/sütun içindeyse çevresinde boş yer arar.
func teleport_to(pos: Vector2) -> bool:
	var free := find_free_spot(pos)
	if free == Vector2.INF:
		return false
	afterimage(Color(0.6, 0.4, 1.0, 0.6))
	global_position = free
	return true


func find_free_spot(pos: Vector2) -> Vector2:
	var offsets: Array[Vector2] = [Vector2.ZERO]
	for r: float in [0.4, 0.8, 1.2]:
		for i: int in 8:
			offsets.append(Vector2.RIGHT.rotated(TAU * i / 8.0) * r)
	for o: Vector2 in offsets:
		var p := pos + Iso.to_screen(o * Iso.KARO)
		if not _overlaps_at(p, MASK_WALLS | MASK_OBSTACLES):
			return p
	return Vector2.INF


func _overlaps_obstacle() -> bool:
	return _overlaps_at(global_position, MASK_OBSTACLES)


func _overlaps_at(pos: Vector2, mask: int) -> bool:
	var shape := ConvexPolygonShape2D.new()
	shape.points = Shapes.iso_ellipse(radius_tiles * 0.9)
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = shape
	q.transform = Transform2D(0.0, pos)
	q.collision_mask = mask
	return not get_world_2d().direct_space_state.intersect_shape(q, 1).is_empty()


# --- yetenek durumları ---

func start_phase(duration: float) -> void:
	phase_t = duration
	iframes = maxf(iframes, duration)
	collision_layer = 0
	visual.modulate = Color(0.75, 0.6, 1.0, 0.35)


## Faz süresi dolunca ya da saldırınca biter.
func end_phase() -> void:
	if phase_t > 0.0:
		iframes = minf(iframes, 0.1)
	phase_t = 0.0
	collision_layer = 2
	visual.modulate = Color.WHITE


func start_flight(duration: float) -> void:
	flight_t = duration
	collision_mask = MASK_WALLS
	var hover := float(_race["abilities"]["q"].get("hover_px", 16.0))
	var tw := create_tween()
	tw.tween_property(visual, "position:y", -hover, 0.15).set_ease(Tween.EASE_OUT)


func end_flight() -> void:
	flight_t = 0.0
	collision_mask = MASK_WALLS | MASK_OBSTACLES
	var tw := create_tween()
	tw.tween_property(visual, "position:y", 0.0, 0.12).set_ease(Tween.EASE_IN)


## Warrior Q Kalkan Hücumu: farenin yönünde atılır (dokunulmaz); yoldaki düşmanlara _rush_step vurur.
func start_rush(ab: Dictionary, w: Weapon, attack_id: int) -> void:
	end_phase()
	var dur := float(ab["duration"])
	var dir := facing_cart
	rush_t = dur
	_rush = {"ab": ab, "weapon": w, "id": attack_id, "dir": dir, "hit": {}}
	iframes = maxf(iframes, dur + 0.05)
	busy_t = maxf(busy_t, dur)
	move_override(Iso.to_screen(dir * Iso.tiles(float(ab["distance"]))) / dur, dur, func() -> void:
		rush_t = 0.0
		Events.area_pulse.emit(global_position, float(ab["hit_radius"]) * 1.4, Color(0.95, 0.8, 0.45)))
	afterimage(Color(1.0, 0.85, 0.4, 0.55))
	slash_fx(float(ab["hit_radius"]) + 0.4, 120.0, true, dir, Color(0.95, 0.8, 0.45))


## Hücum sürerken yakına gelen her düşmana bir kez: ×1,5 güçlü vuruş (savrulur) + sersemletme (boss'ta yavaşlatma).
func _rush_step(delta: float) -> void:
	if rush_t <= 0.0 or _rush.is_empty():
		return
	rush_t = maxf(rush_t - delta, 0.0)
	var ab: Dictionary = _rush["ab"]
	var hit: Dictionary = _rush["hit"]
	for e: Node2D in enemies_in_circle(global_position, float(ab["hit_radius"])):
		var key := e.get_instance_id()
		if hit.has(key):
			continue
		hit[key] = true
		deal_hit(e, _rush["weapon"], "q", float(ab["skill_mult"]), int(_rush["id"]), {"heavy": true, "dir": _rush["dir"]})
		if is_instance_valid(e) and not e.get("dead"):
			(e.get("status") as StatusEffects).stun(float(ab["stun_duration"]), float(ab["boss_slow_duration"]), float(ab["boss_slow"]))
			Events.floating_text.emit(e.global_position + Vector2(0, -70), "YAVAŞ" if bool(e.get("is_boss")) else "SERSEM", Color(1.0, 0.95, 0.5), 20)
	if rush_t <= 0.0:
		_rush = {}


# --- silahlar ---

## Tab: iki aktif silah arasında anında geçiş (kombolar için ana araç).
func swap_weapon() -> void:
	if weapons.size() < 2 or busy_t > 0.0:
		return
	if charging:
		charging = false
		charge_t = 0.0
	active_index = (active_index + 1) % weapons.size()
	if inventory:
		inventory.set_active_index(active_index)
	_apply_stats()
	refresh_weapon_visual()
	Events.weapon_swapped.emit(active_index)


## Silahlar değişince (hata ayıklama menüsü) görseli ve statları tazeler.
func refresh_weapon_visual() -> void:
	var w := weapon()
	visual.weapon_color = Weapon.kind_color(w.element)
	visual.weapon_style = str(w.type_data()["visual"])
	visual.show_weapon = not (w.type_id == "spear" and is_instance_valid(spear_out))


## Zindan: aktif silahları, Rezonans ve Esnek slotu envanterden yeniden okur (envanter değişince). Can oranı korunur.
func load_loadout(inv: Inventory) -> void:
	inventory = inv
	if charging:
		charging = false
		charge_t = 0.0
	effects.resonance = inv.resonance_weapon()
	effects.flex = inv.flex_item()
	var list := inv.active_weapons()
	if list.is_empty():
		list.append(Weapon.make("sword", "common"))
	set_weapons(list, inv.active_index())


## Level değişince (hata ayıklama menüsü; Aşama 6'da XP) statlar ve maks mana yenilenir.
func set_level(new_level: int) -> void:
	level = maxi(new_level, 1)
	kit.set_level(level)
	_stats_cache.clear()
	_apply_stats()


func set_weapons(list: Array[Weapon], index: int = 0) -> void:
	weapons = list
	active_index = clampi(index, 0, weapons.size() - 1)
	_stats_cache.clear()
	if is_inside_tree():
		_apply_stats()
		refresh_weapon_visual()


## Kılıç izi / vuruş yayı efekti.
func slash_fx(radius: float, arc: float, heavy: bool, facing: Vector2 = Vector2.ZERO, color: Color = Color(-1, 0, 0), origin: Vector2 = Vector2.INF) -> void:
	var fx := SlashFx.new()
	var col := color if color.r >= 0.0 else Weapon.kind_color(weapon().element)
	fx.setup(facing if facing != Vector2.ZERO else facing_cart, radius, arc, heavy, col)
	get_parent().add_child(fx)
	fx.global_position = (origin if origin != Vector2.INF else global_position) + Vector2(0, -6)
	_lean_t = 0.12


## Sahneye efekt/mermi ekler (oyuncunun ebeveyni: Y-sıralı dünya).
func spawn(node: Node2D, pos: Vector2) -> void:
	get_parent().add_child(node)
	node.global_position = pos


func enemies() -> Array[Node2D]:
	var out: Array[Node2D] = []
	for n: Node in get_tree().get_nodes_in_group("enemies"):
		var e := n as Node2D
		if e and not e.get("dead") and e.has_method("apply_damage"):
			out.append(e)
	return out


func enemies_in_arc(range_tiles: float, arc: float, facing: Vector2 = Vector2.ZERO, origin: Vector2 = Vector2.INF) -> Array[Node2D]:
	var f := facing if facing != Vector2.ZERO else facing_cart
	var o := origin if origin != Vector2.INF else global_position
	var out: Array[Node2D] = []
	for e: Node2D in enemies():
		if CombatMath.in_arc(o, f, e.global_position, range_tiles, arc, float(e.get("radius_tiles"))):
			out.append(e)
	return out


func enemies_in_circle(center: Vector2, radius: float) -> Array[Node2D]:
	var out: Array[Node2D] = []
	for e: Node2D in enemies():
		if Iso.tile_distance(center, e.global_position) <= radius + float(e.get("radius_tiles")):
			out.append(e)
	return out


## Noktaya en yakın düşman (oyuncuya en fazla max_from_player karo uzakta olanlar arasından).
func enemy_near_point(point: Vector2, max_from_player: float) -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for e: Node2D in enemies():
		if Iso.tile_distance(global_position, e.global_position) > max_from_player:
			continue
		var d := Iso.tile_distance(point, e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


## Farenin gösterdiği nokta, oyuncudan en fazla max_range karo uzakta olacak şekilde.
func target_point(max_range: float) -> Vector2:
	var v := Iso.to_cart(aim_point - global_position)
	var d := v.length() / Iso.KARO
	if d > max_range:
		v = v.normalized() * Iso.tiles(max_range)
	return global_position + Iso.to_screen(v)


## Bütün oyuncu vuruşları buradan geçer: ırk statları + buff'lar → HitResolver.
## source: "light", "heavy", "q", "e" (hasar kaydı). attack_id: Warrior enerjisi saldırı başına bir kez.
## Aşama 6: ustalık (U), kritik hasarı, skill hasarı (sağ tık, Q, E), ödüllerden can emme ve boss özel etkileri eklenir.
func deal_hit(target: Node2D, w: Weapon, source: String, skill_mult: float, attack_id: int, opts: Dictionary = {}) -> Dictionary:
	if target == null or target.get("dead"):
		return {}
	var s := stats_for(w)
	var o := opts.duplicate()
	var eo := effects.hit_opts()
	var skill := s.skill_damage if source in SKILL_SOURCES else 0.0
	o["skill_mult"] = skill_mult
	o["mastery_level"] = Mastery.level_of(w.type_id)
	o["damage_buffs"] = s.damage_buffs + skill + float(o.get("damage_buffs", 0.0)) + float(eo["damage_buffs"])
	o["element_bonus"] = s.element_bonus + float(o.get("element_bonus", 0.0)) + float(eo["element_bonus"])
	o["crit_damage_bonus"] = s.crit_damage_bonus + float(o.get("crit_damage_bonus", 0.0))
	if eo.has("flex_traits"):
		o["flex_traits"] = eo["flex_traits"]
		o["flex_scale"] = eo["flex_scale"]
	o["crit_bonus_chance"] = s.crit_bonus + float(o.get("crit_bonus_chance", 0.0))
	var cm := GameState.special("combo_master")
	if not cm.is_empty():
		o["combo_damage_bonus"] = float(o.get("combo_damage_bonus", 0.0)) + float(cm["combo_damage"])
	var wr := GameState.special("wrath")
	if not wr.is_empty():
		o["fury_max"] = float(wr["fury_max"])
	var ex := GameState.special("executioner")
	if not ex.is_empty():
		o["execute_bonus"] = float(ex["threshold_bonus"])
		o["execute_boss_bonus"] = float(ex["boss_threshold_bonus"])
	if not o.has("dir"):
		var d := Iso.to_cart(target.global_position - global_position)
		o["dir"] = d.normalized() if d.length() > 0.01 else facing_cart
	var res := HitResolver.resolve(self, w, target, o, get_tree().get_nodes_in_group("enemies"), rng)
	var dealt := float(res.get("damage", 0.0))
	var src_key := "light" if source == "light_extra" else source
	damage_by_source[src_key] = float(damage_by_source.get(src_key, 0.0)) + dealt
	if dealt > 0.0:
		kit.on_hit_landed(attack_id)
		# Ödüllerden can emme (Ghost'ta öldürme başına iyileşmeye dönüşür: heal() Ghost'ta çalışmaz)
		if s.lifesteal > 0.0:
			heal(dealt * s.lifesteal)
	effects.after_hit(target, w, res, attack_id, o)
	# Kritik zinciri: kritik vuruş %20 ihtimalle sağ tık, Q ve E beklemelerini 1 sn azaltır
	var cc := GameState.special("crit_chain")
	if bool(res.get("crit", false)) and not cc.is_empty() and rng.randf() < float(cc["chance"]):
		kit.reduce(float(cc["seconds"]))
	# Çift vuruş: normal saldırı %25 ihtimalle aynı hedefe bir kez daha vurur
	var dh := GameState.special("double_hit")
	if source == "light" and not bool(opts.get("repeat", false)) and not dh.is_empty() \
			and is_instance_valid(target) and not target.get("dead") and rng.randf() < float(dh["chance"]):
		Events.floating_text.emit(target.global_position + Vector2(0, -80), "ÇİFT", Color(1.0, 0.85, 0.5), 16)
		var o2 := opts.duplicate()
		o2["repeat"] = true
		deal_hit(target, w, source, skill_mult, attack_id, o2)
	return res


## Kısa not (mana yetersiz, hedef yok…) — sık tekrarlanmasın diye yavaşlatılır.
func note(text: String, color: Color = Color(0.85, 0.85, 0.9)) -> void:
	if _note_cd > 0.0:
		return
	_note_cd = 0.6
	Events.floating_text.emit(global_position + Vector2(0, -78), text, color, 18)


# --- can ---

## Can Emme (ırk izin veriyorsa). Ghost'ta Can Emme öldürme başına iyileşmeye dönüşür (_on_enemy_killed).
func heal(amount: float) -> void:
	if not bool(_race["healing"]["lifesteal"]):
		return
	restore(amount)


func restore(amount: float) -> void:
	if dead or amount <= 0.0:
		return
	var before := hp
	hp = minf(hp + amount, max_hp)
	if hp - before >= 1.0:
		Events.damage_number.emit(global_position + Vector2(14, -52), hp - before, false, true, "heal")
	health_changed.emit(hp, max_hp)


## 1: iksir — maks canın %40'ı. Ghost iksir kullanamaz (GDD: Can ve İyileşme).
func use_potion() -> bool:
	if dead:
		return false
	if not bool(_race["healing"]["potions"]):
		note("%s iksir kullanamaz" % _race["name"], Color(1, 0.6, 0.6))
		return false
	if potions <= 0:
		note("İksir yok", Color(1, 0.6, 0.6))
		return false
	if hp >= max_hp:
		note("Can dolu")
		return false
	potions -= 1
	restore(max_hp * float(DataDB.get_value("progression", "potions.heal_pct")))
	return true


func _on_enemy_killed(enemy: Node, is_elite: bool, _is_boss: bool) -> void:
	if dead:
		return
	effects.on_kill(enemy as Node2D, is_elite)
	var h: Dictionary = _race["healing"]
	if not h.has("heal_on_kill"):
		return
	var pct := float(h["heal_on_elite_kill"] if is_elite else h["heal_on_kill"])
	if bool(h.get("lifesteal_becomes_kill_heal", false)):
		# Can Emme: aktif silahta tam, Esnek slottaki silahta %9 (GDD: Ghost'ta öldürme başına iyileşmeye dönüşür)
		var ls := HitResolver.trait_scale(weapon(), "lifesteal", effects.hit_opts())
		pct += float(Traits.data("lifesteal")["pct"]) * ls
		# Ödüllerden can emme de öldürme başına aynı yüzde kadar maks can iyileşmesine dönüşür
		pct += stats.lifesteal
	if enemy == null:
		return
	restore(max_hp * pct)


func _on_combo(_id: String, _t: Node) -> void:
	combos_done += 1
	if not dead:
		effects.on_combo()


## Düşmandan gelen hasar (hasar formülünden geçer: ırk direnci ve zırh).
func take_damage(amount: float, _from_dir_cart: Vector2, kind: String = DamageCalc.PHYSICAL) -> void:
	if dead or iframes > 0.0 or invulnerable:
		return
	var hit := DamageCalc.Hit.new()
	hit.base_damage = amount
	hit.kind = kind
	defense.armor = current_armor()
	var dmg := DamageCalc.compute(hit, defense)
	hp = maxf(hp - dmg, 0.0)
	iframes = float(_combat["player_hurt_iframes"])
	visual.flash(float(_feel["flash_duration"]) * 1.5, Color(1.0, 0.25, 0.25))
	Events.player_damaged.emit(dmg)
	Events.damage_number.emit(global_position + Vector2(0, -40), dmg, false, true, kind)
	health_changed.emit(hp, max_hp)
	if hp <= 0.0 and not _try_second_chance():
		_die()


## Boss özel etkisi İkinci şans: ölünce bir kez %30 canla dirilir (kısa dokunulmazlıkla).
func _try_second_chance() -> bool:
	var sc := GameState.special("second_chance")
	if sc.is_empty() or GameState.second_chance_used:
		return false
	GameState.second_chance_used = true
	hp = max_hp * float(sc["revive_hp"])
	iframes = float(sc["iframes"])
	visual.flash(0.3, Color(1.0, 0.9, 0.5))
	Events.floating_text.emit(global_position + Vector2(0, -90), "İKİNCİ ŞANS!", Color(1.0, 0.85, 0.4), 28)
	Events.area_pulse.emit(global_position, 2.0, Color(1.0, 0.85, 0.4))
	health_changed.emit(hp, max_hp)
	return true


func _die() -> void:
	dead = true
	collision_layer = 0
	charging = false
	var tw := create_tween()
	tw.tween_property(visual, "rotation", deg_to_rad(80), 0.35).set_trans(Tween.TRANS_BACK)
	tw.parallel().tween_property(visual, "modulate", Color(0.6, 0.6, 0.6, 0.8), 0.35)
	Events.player_died.emit()
	died.emit()


func _draw() -> void:
	# Warrior Kalkan Hücumu: önde altın kalkan yayı
	if rush_t > 0.0:
		var ring := Shapes.iso_ellipse(radius_tiles * 1.7, 20)
		ring.append(ring[0])
		draw_polyline(ring, Color(1.0, 0.8, 0.3, 0.8), 3.0)
	# Yay dolarken güç göstergesi
	if charging:
		var hd: Dictionary = weapon().type_data()["heavy"]
		var k := clampf(charge_t / float(hd.get("charge_time", 1.0)), 0.0, 1.0)
		draw_rect(Rect2(Vector2(-20, -70), Vector2(40, 5)), Color(0, 0, 0, 0.8))
		draw_rect(Rect2(Vector2(-20, -70), Vector2(40 * k, 5)), Color(1.0, 0.9, 0.4) if k >= 1.0 else Color(0.9, 0.9, 0.9))


# --- smoke testi botu ---

## En yakın düşmana yaklaşır (uzak silahta mesafe korur), menzildeyse vurur, kalabalıkta ya da uzaktan sağ tık,
## hazır olunca Q/E kullanır. Hedef aktif silahın elementine bağışıksa ya da diğer silahla kombo yapılabilecekse Tab.
func _bot_think(delta: float) -> Dictionary:
	var out := _empty_intent()
	for k: String in _bot.keys():
		_bot[k] = float(_bot[k]) - delta
	var nearest: Node2D = null
	var best := INF
	var close_count := 0
	for e: Node2D in enemies():
		var d := Iso.tile_distance(global_position, e.global_position)
		if d < best:
			best = d
			nearest = e
		if d < 2.0:
			close_count += 1
	if nearest == null:
		# Zindanda düşman yok: çatlak duvara vur ya da sıradaki yol noktasına yürü
		if bot_attack_point != Vector2.INF:
			out["aim"] = bot_attack_point
			out["light"] = attack_cd <= 0.0
		elif bot_waypoint != Vector2.INF:
			var to_w := Iso.to_cart(bot_waypoint - global_position)
			out["aim"] = bot_waypoint
			if to_w.length() > 2.0:
				out["move"] = to_w.normalized()
		return out
	var w := weapon()
	var rng_t := attack_range(w)
	var to_e := Iso.to_cart(nearest.global_position - global_position)
	out["aim"] = nearest.global_position
	var ranged := rng_t > 3.0
	var blocked := bot_los.is_valid() and not bool(bot_los.call(global_position, nearest.global_position))
	if best > rng_t * 0.8 or (blocked and best > 1.2):
		out["move"] = bot_nav.call(global_position, nearest.global_position) if bot_nav.is_valid() else to_e.normalized()
	elif ranged and best < minf(2.5, rng_t * 0.4):
		out["move"] = -to_e.normalized()
	var in_range := best <= rng_t + 0.3
	out["light"] = in_range
	var hd: Dictionary = w.type_data()["heavy"]
	if charging:
		out["heavy_held"] = float(_bot["hold"]) > 0.0
	elif in_range and (close_count >= 2 or ranged) and kit.can_use("heavy", w.family()):
		out["heavy"] = true
		out["heavy_held"] = true
		_bot["hold"] = float(hd.get("charge_time", 0.0))
	if is_instance_valid(spear_out) and spear_out.state == "stuck":
		out["heavy"] = true
	if best < 4.0 and float(_bot["q"]) <= 0.0 and kit.can_use("q", w.family()):
		out["q"] = true
		_bot["q"] = 2.0
	if best < 5.0 and float(_bot["e"]) <= 0.0 and kit.can_use("e", w.family()):
		out["e"] = true
		_bot["e"] = 2.0
	if weapons.size() >= 2 and float(_bot["swap"]) <= 0.0 and in_range and not charging:
		var other: Weapon = weapons[(active_index + 1) % weapons.size()]
		var def: DamageCalc.Defense = nearest.get("defense")
		var st: StatusEffects = nearest.get("status")
		var cur_useless := DamageCalc.status_multiplier(w.element, def) <= 0.0
		var other_combo := not DamageCalc.is_immune(other.element, def) and not Combos.find(st, other.element).is_empty()
		if cur_useless or other_combo:
			out["swap"] = true
			_bot["swap"] = 0.4
	if float(_bot["dash"]) <= 0.0 and hp < max_hp * 0.5:
		out["dash"] = true
		out["move"] = -to_e.normalized()
		_bot["dash"] = 3.0
	if hp < max_hp * 0.35:
		out["potion"] = true
	return out
