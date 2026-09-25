## Nyx'thar, Yankısız — 4. kat final boss'u (GDD: Boss'lar > 4. Kat). Havada süzülür (sütunların üstünden geçer).
##   Gölge Kopyaları: işaretli yerlerde kopyalar belirir; gerçek olanın yere gölgesi düşer. Sahteye vurulursa o sahte
##                    oyuncunun yanına ışınlanır ve işaretli bir kesik atıp dağılır. Gerçeğe vurulunca kopyalar dağılır.
##   Boşluk Yırtığı: işaretli portallar açılır, yakındaki oyuncuyu içine çeker (karşı yürü ya da Space); merkezi yakar.
##   Çığlık: etrafında dolan işaret, sonra patlama.
## Karanlık Perdesi: arena kararır; yanan meşalelerin çevresi güvenli, karanlıkta 1 sn'den fazla kalan oyuncu can kaybeder.
## Nyx'thar 12 sn'de bir meşale söndürür (önce kırmızı titrer); en az 2 meşale hep yanar. Ateş vuruşu meşaleyi yakar.
## Fiziksele bağışık (yaygın silahlar %25). 2. faz: platform kenarları çöker (işaretli), kopyalar 5'e çıkar ve
## kopyalar da Boşluk Yırtığı açar.
class_name Nyxthar
extends Boss

var torches: Array[Dictionary] = []      ## {pos, lit, warn_t}
var collapse_r: float = -1.0             ## > 0: bu yarıçapın dışı uçurum
var _collapse_warn_t: float = 0.0
var _extinguish_t: float = 0.0
var _dark_t: float = 0.0
var _drain_t: float = 0.0
var _copies: Array[Node2D] = []
var _rifts: Array[EnemyHazard] = []
var _drift: Vector2 = Vector2.INF
var _drift_t: float = 0.0


func _body_color() -> String:
	return "#30284a"


func _setup_body() -> void:
	super._setup_body()
	collision_mask = 1 | 2 | 4   # süzülür: sütunlara takılmaz
	_base_modulate = Color(1, 1, 1, 0.85)


func start_fight() -> void:
	var m := mech()
	_place_torches(arena.radius - float(m["torch_inset"]))
	_extinguish_t = float(m["extinguish_sec"])
	log_telegraph("veil_of_darkness", float(m["grace_sec"]))


func _place_torches(r: float) -> void:
	var m := mech()
	var old := torches.duplicate()
	torches.clear()
	for i: int in int(m["torches"]):
		var off := Vector2.RIGHT.rotated(TAU * i / float(m["torches"]) + 0.3) * r
		var lit := true if old.is_empty() else bool(old[i]["lit"])
		torches.append({"pos": arena.clamp_inside(arena.point(off)), "lit": lit, "warn_t": 0.0})


func lit_count() -> int:
	return torches.filter(func(t: Dictionary) -> bool: return bool(t["lit"])).size()


func in_light(pos: Vector2) -> bool:
	var lr := float(mech()["light_radius"])
	for t: Dictionary in torches:
		if bool(t["lit"]) and Iso.tile_distance(pos, t["pos"]) <= lr:
			return true
	return false


func in_abyss(pos: Vector2) -> bool:
	return collapse_r > 0.0 and _collapse_warn_t <= 0.0 and arena.offset_of(pos).length() > collapse_r


func tick_mechanic(delta: float) -> void:
	var m := mech()
	# Meşaleler: söndürme (önce titrer) ve ateşle yeniden yakma
	_extinguish_t -= delta
	if _extinguish_t <= 0.0:
		_extinguish_t = float(m["extinguish_sec"])
		var lit := []
		for t: Dictionary in torches:
			if bool(t["lit"]) and float(t["warn_t"]) <= 0.0:
				lit.append(t)
		if lit.size() > int(m["min_lit"]):
			var pick: Dictionary = lit[rng.randi_range(0, lit.size() - 1)]
			pick["warn_t"] = float(m["extinguish_warn"])
			log_telegraph("extinguish", float(m["extinguish_warn"]))
	var swung := player_swung()
	for t: Dictionary in torches:
		if float(t["warn_t"]) > 0.0:
			t["warn_t"] = float(t["warn_t"]) - delta
			if float(t["warn_t"]) <= 0.0:
				t["lit"] = false
				Events.floating_text.emit(t["pos"] + Vector2(0, -60), "Meşale söndü", Color(0.7, 0.6, 0.9), 18)
		if not bool(t["lit"]) and (fire_near(t["pos"], float(m["relight_reach"])) or (swung and fire_swing_reaches(t["pos"], float(m["relight_reach"])))):
			t["lit"] = true
			Events.area_pulse.emit(t["pos"], float(m["light_radius"]) * 0.5, Color(1.0, 0.7, 0.3))
			Events.floating_text.emit(t["pos"] + Vector2(0, -60), "Meşale yandı!", Color(1.0, 0.8, 0.4), 20)
	# Karanlıkta can erir
	if _target_visible() and not in_light(target.global_position):
		_dark_t += delta
		if _dark_t > float(m["grace_sec"]):
			_drain_t -= delta
			if _drain_t <= 0.0:
				_drain_t = float(m["drain_tick"])
				target.call("take_damage", damage * float(m["drain_damage_mult"]), Vector2.RIGHT, "dark")
	else:
		_dark_t = 0.0
		_drain_t = 0.0
	# Boşluk Yırtığı çekimi
	_rifts = _rifts.filter(func(x: Variant) -> bool: return is_instance_valid(x))
	for r: EnemyHazard in _rifts:
		if r.is_active() and _target_visible():
			var a := attack_data("void_rift")
			var v := Iso.to_cart(r.global_position - target.global_position)
			var d := v.length() / Iso.KARO
			if d <= float(a["pull_radius"]) and d > 0.2:
				target.call("add_pull_frame", Iso.to_screen(v.normalized() * Iso.tiles(float(a["pull_speed"]))))
	# 2. faz: çöken kenarlar
	if collapse_r > 0.0:
		if _collapse_warn_t > 0.0:
			_collapse_warn_t -= delta
			if _collapse_warn_t <= 0.0:
				_place_torches(collapse_r - 1.5)
				Events.floating_text.emit(global_position + Vector2(0, -160), "Platform çöktü!", Color(0.8, 0.5, 1.0), 26)
		elif _target_visible() and in_abyss(target.global_position):
			var p := player()
			p.take_damage(p.max_hp * float(p2()["fall_damage_pct"]), Vector2.RIGHT, DamageCalc.PHYSICAL)
			p.global_position = arena.clamp_inside(p.global_position, collapse_r - 1.0)
			Events.floating_text.emit(p.global_position + Vector2(0, -80), "UÇURUM!", Color(0.8, 0.5, 1.0), 24)
	_copies = _copies.filter(func(c: Variant) -> bool: return is_instance_valid(c) and not (c as Node2D).get("dead"))
	var dark := "Karanlıktasın — meşale ışığına gir!" if _dark_t > 0.0 else "Meşaleler: %d / %d yanıyor (ateş yakar)" % [lit_count(), torches.size()]
	status_text = ("Gerçek Nyx'thar'ın gölgesi var! · " if not _copies.is_empty() else "") + dark


func start_attack(id: String) -> float:
	var a := attack_data(id)
	match id:
		"shadow_copies":
			var n := int(p2()["copies"]) if phase == 2 else int(a["copies"])
			var spots: Array[Vector2] = [global_position]
			for i: int in n - 1:
				spots.append(arena.random_point(rng, 1.5, (collapse_r if collapse_r > 0.0 else arena.radius) - 1.5, target.global_position, 2.5))
			for s: Vector2 in spots:
				hazard(id, s, "circle", float(a["warn"]), 0.0, {"mode": "visual", "radius": 0.9, "color": Color(0.5, 0.35, 0.8)})
			schedule(float(a["warn"]), func() -> void: _split(spots, a))
			return float(a["warn"]) + 0.5
		"void_rift":
			var n2 := int(p2()["portals"]) if phase == 2 else int(a["portals"])
			var pts: Array[Vector2] = []
			for i2: int in n2:
				pts.append(arena.random_point(rng, 1.0, (collapse_r if collapse_r > 0.0 else arena.radius) - 1.5, target.global_position, 3.0))
			if phase == 2:
				for c1: Variant in _copies:
					if is_instance_valid(c1):
						pts.append((c1 as Node2D).global_position)
			for pt: Vector2 in pts:
				_rifts.append(hazard(id, pt, "circle", float(a["warn"]), float(a["damage_mult"]),
					{"mode": "zone", "radius": float(a["core_radius"]), "duration": float(a["duration"]), "tick": float(a["tick"]),
					"kind": "dark", "color": Color(0.55, 0.25, 0.95)}))
			return float(a["warn"]) + 1.0
		"scream":
			hazard(id, global_position, "circle", float(a["warn"]), float(a["damage_mult"]), {"radius": float(a["radius"]), "kind": "dark", "color": Color(0.8, 0.2, 0.5)})
			return float(a["warn"])
	return 0.0


## Kopyalara bölünür: gerçek Nyx'thar noktalardan birine geçer, diğerlerinde sahteler belirir.
func _split(spots: Array[Vector2], a: Dictionary) -> void:
	for c0: Variant in _copies:
		if is_instance_valid(c0):
			(c0 as Node2D).call("dissolve")
	_copies.clear()
	var real_i := rng.randi_range(0, spots.size() - 1)
	global_position = spots[real_i]
	for i: int in spots.size():
		if i == real_i:
			continue
		var c := NyxCopy.new()
		c.boss = self
		c.lifetime = float(a["duration"])
		c.hit_warn = float(a["fake_hit_warn"])
		c.hit_mult = float(a["fake_damage_mult"])
		c.fake_hp = max_hp * float(a["fake_hp_pct"])
		c.floor_index = floor_index
		c.no_reward = true
		c.summoner = self
		c.can_stand = can_stand
		get_parent().add_child(c)
		c.global_position = spots[i]
		_copies.append(c)
		summons.append(c)


func modify_incoming(amount: float, info: Dictionary) -> float:
	if not _copies.is_empty() and not bool(info.get("dot", false)):
		for c: Variant in _copies:
			if is_instance_valid(c):
				(c as Node2D).call("dissolve")
		_copies.clear()
		Events.floating_text.emit(global_position + Vector2(0, -150), "BULDUN!", Color(1.0, 0.85, 0.4), 24)
	return amount


func enter_phase2() -> void:
	collapse_r = arena.radius * float(p2()["collapse_radius_ratio"])
	_collapse_warn_t = float(p2()["collapse_warn"])
	log_telegraph("phase2_collapse", _collapse_warn_t)
	global_position = arena.clamp_inside(global_position, collapse_r - 1.5)


func move_dir(delta: float) -> Vector2:
	if _busy_t > 0.0 or not _target_visible():
		return Vector2.ZERO
	_drift_t -= delta
	var lim := (collapse_r if collapse_r > 0.0 else arena.radius) - 1.5
	if _drift == Vector2.INF or _drift_t <= 0.0 or Iso.tile_distance(global_position, _drift) < 0.5:
		_drift = arena.random_point(rng, 1.0, lim, target.global_position, 3.5)
		_drift_t = 3.0
	return Iso.to_cart(_drift - global_position).normalized()


func _draw() -> void:
	if state != State.DEAD:
		# Gerçek Nyx'thar yere gölge düşürür (kopyalar düşürmez)
		draw_colored_polygon(Shapes.iso_ellipse(radius_tiles * 1.6, 20), Color(0, 0, 0, 0.55))
	super._draw()


func draw_overlay(o: Node2D) -> void:
	var m := mech()
	var lr := float(m["light_radius"])
	for c: Vector2i in arena.cells.keys():
		var wp: Vector2 = arena.cell_to_world.call(c)
		var off := arena.offset_of(wp).length()
		if collapse_r > 0.0 and off > collapse_r:
			if _collapse_warn_t > 0.0:
				paint_cell(o, c, Color(1.0, 0.2, 0.2, 0.25 + 0.2 * sin(_time * 12.0)))
			else:
				paint_cell(o, c, Color(0.02, 0.0, 0.05, 0.95))
			continue
		var best := INF
		for t: Dictionary in torches:
			if bool(t["lit"]):
				best = minf(best, Iso.tile_distance(wp, t["pos"]))
		var dark := clampf((best - lr * 0.6) / (lr * 0.4), 0.0, 1.0) if best < INF else 1.0
		if dark > 0.0:
			paint_cell(o, c, Color(0.03, 0.02, 0.08, 0.7 * dark))
	for t2: Dictionary in torches:
		var p: Vector2 = o.to_local(t2["pos"])
		o.draw_rect(Rect2(p + Vector2(-3, -30), Vector2(6, 30)), Color(0.35, 0.25, 0.2))
		if bool(t2["lit"]):
			var flick := 0.8 + 0.2 * sin(_time * 17.0 + p.x)
			var col := Color(1.0, 0.25, 0.2) if float(t2["warn_t"]) > 0.0 and int(_time * 8.0) % 2 == 0 else Color(1.0, 0.7, 0.25)
			o.draw_circle(p + Vector2(0, -36), 8.0 * flick, col)
			var ring := Shapes.iso_ellipse(lr, 32)
			var moved := PackedVector2Array()
			for q: Vector2 in ring:
				moved.append(q + p)
			moved.append(moved[0])
			o.draw_polyline(moved, Color(1.0, 0.75, 0.35, 0.35), 1.5)
		else:
			o.draw_circle(p + Vector2(0, -34), 4.0, Color(0.3, 0.3, 0.35))
