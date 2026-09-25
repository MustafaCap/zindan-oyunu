## Morvath, Ana Göz — 1. kat boss'u (GDD: Boss'lar > 1. Kat). Duvara gömülü, hareket etmez.
##   Bakış Işını: önce taranacak alan ve başlangıç çizgisi işaretlenir, sonra ışın yavaşça döner; sütunların
##                arkası güvenlidir (görüş hattı), Space'in dokunulmazlığıyla içinden geçilir. 2. fazda iki ışın ters döner.
##   Damar Kırbacı: oyuncuya doğru yelpaze şeklinde kırmızı çatlak şeritleri, sonra fışkırma.
##   Göz Yavruları: işaretli noktalarda 4-6 Sürünen Göz doğar.
## Kapanan Göz Kapağı: open_interval sn açık kalır, sonra kapanır (hasar almaz) ve duvarda 3 göz belirir; üçü kırılınca
## kapak açılır, 6 sn +%50 hasar alır. Morvath'a gelen yıldırımın %50'si duvar gözlerine sıçrar.
## 2. faz: zeminin bazı bölgeleri sürekli hasar verir (işaretli, 12 sn'de bir yer değiştirir).
class_name Morvath
extends Boss

var closed: bool = false
var bonus_t: float = 0.0
var _open_t: float = 0.0
var _closed_t: float = 0.0
var _beams: Array[Dictionary] = []    ## {angle, sign, left, warn, hit_cd}
var _zones: Array[EnemyHazard] = []
var _zone_t: float = 0.0


func _body_color() -> String:
	return "#b0405a"


func start_fight() -> void:
	status_text = "Göz kapağı açık"


func tick_mechanic(delta: float) -> void:
	var m := mech()
	bonus_t = maxf(bonus_t - delta, 0.0)
	if closed:
		_closed_t += delta
		var eyes := alive_minions("wall_eye")
		status_text = "Göz kapağı KAPALI — duvardaki %d gözü kır!" % eyes.size()
		if eyes.is_empty():
			_open(true)
		elif _closed_t >= float(m["closed_timeout"]):
			for e: Node2D in eyes:
				e.call("dissolve")
			_open(false)
	else:
		_open_t += delta
		status_text = "AÇIK! +%%%d hasar (%.0f sn)" % [roundi(float(m["open_damage_bonus"]) * 100.0), bonus_t] if bonus_t > 0.0 else "Göz kapağı açık"
		if _open_t >= float(m["open_interval"]) and bonus_t <= 0.0:
			_close()
	_tick_beams(delta)
	if phase == 2:
		_zone_t -= delta
		if _zone_t <= 0.0:
			_place_zones()


func _close() -> void:
	closed = true
	_closed_t = 0.0
	Events.floating_text.emit(global_position + Vector2(0, -150), "GÖZ KAPANDI", Color(0.9, 0.7, 0.7), 26)
	var back := -arena.door_dir
	var r := arena.radius - 1.3
	for deg: float in [-65.0, 65.0, 150.0]:
		var p := arena.clamp_inside(arena.point(back.rotated(deg_to_rad(deg)) * r), r)
		add_minion("wall_eye", p)


func _open(with_bonus: bool) -> void:
	closed = false
	_open_t = 0.0
	if with_bonus:
		bonus_t = float(mech()["open_duration"])
		Events.floating_text.emit(global_position + Vector2(0, -150), "GÖZ AÇIK! +%50 HASAR", Color(1.0, 0.85, 0.4), 28)
		Events.area_pulse.emit(global_position, 2.5, Color(1.0, 0.85, 0.4))


func modify_incoming(amount: float, info: Dictionary) -> float:
	var m := mech()
	# Islak damarlar yıldırımı iletir: yıldırım hasarının bir kısmı duvardaki gözlere sıçrar (kapak kapalıyken de)
	if str(info.get("kind", "")) == "lightning" and not bool(info.get("secondary", false)) and not bool(info.get("dot", false)):
		for e: Node2D in alive_minions("wall_eye"):
			Events.chain_zap.emit(global_position + Vector2(0, -60), e.global_position + Vector2(0, -20), Weapon.kind_color("lightning"), true)
			e.call("apply_damage", amount * float(m["lightning_jump_pct"]), {"kind": "lightning", "secondary": true, "dir": Vector2.RIGHT})
	if closed:
		return 0.0
	if bonus_t > 0.0:
		amount *= 1.0 + float(m["open_damage_bonus"])
	return amount


func _zero_damage_text() -> String:
	return "KAPALI" if closed else "BAĞIŞIK"


func start_attack(id: String) -> float:
	var a := attack_data(id)
	match id:
		"gaze_beam":
			var base := Iso.to_cart(target.global_position - global_position).angle()
			var sweep := deg_to_rad(float(a["sweep_degrees"]))
			var sgn := 1.0 if rng.randf() < 0.5 else -1.0
			var count := int(p2()["beams"]) if phase == 2 else 1
			for i: int in count:
				var s := sgn if i == 0 else -sgn
				_beams.append({"angle": base - s * sweep * 0.5, "sign": s, "left": sweep, "warn": float(a["warn"]), "hit_cd": 0.0})
			log_telegraph(id, float(a["warn"]))
			var speed := deg_to_rad(float(a["speed_degrees"])) * (float(p2()["beam_speed_mult"]) if phase == 2 else 1.0)
			return float(a["warn"]) + sweep / speed
		"vein_lash":
			var to_p := Iso.to_cart(target.global_position - global_position).normalized()
			var n := int(a["lines"])
			var fan := deg_to_rad(float(a["fan_degrees"]))
			for i: int in n:
				var dir := to_p.rotated(-fan * 0.5 + fan * i / maxf(n - 1, 1))
				schedule(i * float(a["stagger"]), func() -> void:
					hazard(id, global_position, "rect", float(a["warn"]), float(a["damage_mult"]),
						{"dir_cart": dir, "length": float(a["length"]), "width": float(a["width"]), "start": radius_tiles * 0.8,
						"color": Color(0.85, 0.1, 0.2)}))
			return float(a["warn"]) + n * float(a["stagger"])
		"eye_spawns":
			var cnt: Array = a["count"]
			var n2 := mini(rng.randi_range(int(cnt[0]), int(cnt[1])), int(a["max_alive"]) - alive_minions(str(a["add_id"])).size())
			var dist: Array = a["distance"]
			for i2: int in maxi(n2, 0):
				var off := (-arena.door_dir).rotated(PI + rng.randf_range(-1.2, 1.2)) * rng.randf_range(float(dist[0]), float(dist[1]))
				var pt := arena.clamp_inside(global_position + Iso.to_screen(off * Iso.KARO))
				hazard(id, pt, "circle", float(a["warn"]), 0.0, {"mode": "visual", "radius": 0.6, "color": Color(0.9, 0.4, 0.6)})
				schedule(float(a["warn"]), func() -> void: add_minion(str(a["add_id"]), pt))
			return float(a["warn"])
	return 0.0


func can_use(id: String) -> bool:
	if id == "eye_spawns":
		var a := attack_data(id)
		return alive_minions(str(a["add_id"])).size() < int(a["max_alive"]) - 2
	return true


## Bakış Işını: uyarıdan sonra döner, oyuncuya değerse (sütun arkasında değilse) vurur.
func _tick_beams(delta: float) -> void:
	if _beams.is_empty():
		return
	var a := attack_data("gaze_beam")
	var speed := deg_to_rad(float(a["speed_degrees"])) * (float(p2()["beam_speed_mult"]) if phase == 2 else 1.0)
	var keep: Array[Dictionary] = []
	for b: Dictionary in _beams:
		if float(b["warn"]) > 0.0:
			b["warn"] = float(b["warn"]) - delta
			keep.append(b)
			continue
		var step := speed * delta
		b["angle"] = float(b["angle"]) + float(b["sign"]) * step
		b["left"] = float(b["left"]) - step
		b["hit_cd"] = maxf(float(b["hit_cd"]) - delta, 0.0)
		if _target_visible() and float(b["hit_cd"]) <= 0.0:
			var dir := Vector2.RIGHT.rotated(float(b["angle"]))
			var v := Iso.to_cart(target.global_position - global_position) / Iso.KARO
			if Shapes.segment_distance(v, Vector2.ZERO, dir * float(a["length"])) <= float(a["width"]) * 0.5 + float(target.get("radius_tiles")) \
					and (not arena.los.is_valid() or bool(arena.los.call(global_position, target.global_position))):
				target.call("take_damage", damage * float(a["damage_mult"]), dir, DamageCalc.PHYSICAL)
				b["hit_cd"] = float(a["hit_interval"])
		if float(b["left"]) > 0.0:
			keep.append(b)
	_beams = keep


func enter_phase2() -> void:
	_zone_t = 0.0
	status_text = "Damarlar hızlandı — nabız atan bölgelerden uzak dur!"


func _place_zones() -> void:
	var p := p2()
	for z: Variant in _zones:
		if is_instance_valid(z):
			(z as EnemyHazard).dismiss()
	_zones.clear()
	_zone_t = float(p["zone_relocate_sec"])
	for i: int in int(p["zones"]):
		var pt := arena.random_point(rng, 2.5, arena.radius - 1.0, global_position, 3.0)
		_zones.append(hazard("phase2_zones", pt, "circle", float(p["zone_warn"]), float(p["zone_damage_mult"]),
			{"mode": "zone", "radius": float(p["zone_radius"]), "duration": float(p["zone_relocate_sec"]) - float(p["zone_warn"]),
			"tick": float(p["zone_tick"]), "color": Color(0.75, 0.05, 0.25)}))


func _draw() -> void:
	super._draw()
	if state == State.DEAD:
		return
	var a := attack_data("gaze_beam")
	for b: Dictionary in _beams:
		var dir := Vector2.RIGHT.rotated(float(b["angle"]))
		if float(b["warn"]) > 0.0:
			# Uyarı: taranacak dilim soluk, başlangıç çizgisi parlayarak
			var mid := dir.rotated(float(b["sign"]) * float(b["left"]) * 0.5)
			draw_colored_polygon(Shapes.iso_arc(mid, float(a["length"]), rad_to_deg(float(b["left"])), radius_tiles, 24), Color(1, 0.1, 0.1, 0.08))
			var k := 1.0 - float(b["warn"]) / float(a["warn"])
			draw_colored_polygon(Shapes.iso_rect(dir, float(a["length"]), float(a["width"]), radius_tiles * 0.5), Color(1, 0.15, 0.1, 0.15 + 0.3 * k))
			var arrow := Iso.to_screen(dir.rotated(float(b["sign"]) * 0.25) * Iso.tiles(float(a["length"]) * 0.6))
			draw_circle(arrow, 5.0, Color(1, 0.3, 0.2, 0.8))
		else:
			draw_colored_polygon(Shapes.iso_rect(dir, float(a["length"]), float(a["width"]), radius_tiles * 0.5), Color(1.0, 0.35, 0.45, 0.8))
			draw_colored_polygon(Shapes.iso_rect(dir, float(a["length"]), float(a["width"]) * 0.35, radius_tiles * 0.5), Color(1.0, 0.9, 0.9, 0.9))


## Göz: kapalıyken kapak, açıkken parlayan göz bebeği (gövdenin önünde).
func draw_top(n: Node2D) -> void:
	var eye_y := -visual.body_height * visual.scale.y * 0.6
	if closed:
		n.draw_circle(Vector2(0, eye_y), 16.0, Color(0.45, 0.15, 0.2))
		n.draw_line(Vector2(-18, eye_y), Vector2(18, eye_y), Color(0.2, 0.05, 0.08), 5.0)
	else:
		n.draw_circle(Vector2(0, eye_y), 16.0, Color(0.95, 0.9, 0.85))
		n.draw_circle(Iso.to_screen(facing_cart) * 6.0 + Vector2(0, eye_y), 7.0, Color(1.0, 0.8, 0.2) if bonus_t > 0.0 else Color(0.5, 0.05, 0.1))


func draw_overlay(o: Node2D) -> void:
	# Duvardaki gözlere uzanan damarlar
	for e: Node2D in alive_minions("wall_eye"):
		o.draw_line(o.to_local(global_position), o.to_local(e.global_position), Color(0.6, 0.1, 0.25, 0.6), 4.0)
