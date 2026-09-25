## Kordrak, Erimiş Demirci — 3. kat boss'u (GDD: Boss'lar > 3. Kat). Oyuncuya yavaşça yürür.
##   Örs Darbesi: işaretli çarpma alanı + genişleyecek şok halkasının sınırı; halka Space'le atlanır.
##   Lav Dolumu: zemindeki 4 lav kanalı (hep görünür) önce parlayıp sonra birkaç saniye lavla dolar.
##   Kor Yumruğu: atılma yolu işaretlenir, sonra oyuncunun olduğu yere hızla atılıp vurur.
## Soğutma: plakalar hasarı %70 azaltır (zırh). Her buz vuruşu 1 soğuma yığını; 5 yığında plakalar 10 sn kırılır.
## Yıldırıma bağışık (taş gövde). 2. faz: plakalar kalıcı düşer, hızlanır, Örs Darbesi'nden sonra ateş topları yağar.
class_name Kordrak
extends Boss

var cool_stacks: int = 0
var plates_off_t: float = 0.0
var plates_gone: bool = false
var _cool_decay_t: float = 0.0
var _dash_left: float = 0.0
var _dash_dir: Vector2 = Vector2.ZERO
var _dash_hit: bool = false
var _dash_mult: float = 1.0
var _lava_glow_t: float = 0.0


func _body_color() -> String:
	return "#4a4038"


func start_fight() -> void:
	_update_armor()


func _update_armor() -> void:
	var plated := not plates_gone and plates_off_t <= 0.0
	defense.armor = float(mech()["plate_damage_reduction"]) if plated else 0.0
	if plates_gone:
		status_text = "Plakalar düştü — çekirdek açıkta!"
	elif plates_off_t > 0.0:
		status_text = "Plakalar KIRIK! (%.0f sn)" % plates_off_t
	else:
		status_text = "Zırh plakaları: hasar %%%d azalır · Soğuma %d / %d (buzla vur)" % [roundi(float(mech()["plate_damage_reduction"]) * 100.0),
			cool_stacks, int(mech()["ice_stacks_to_break"])]


func modify_incoming(amount: float, info: Dictionary) -> float:
	# Buz vuruşu plakaları soğutur
	if str(info.get("kind", "")) == "ice" and not bool(info.get("dot", false)) and not plates_gone and plates_off_t <= 0.0:
		cool_stacks += 1
		_cool_decay_t = float(mech()["stack_decay_sec"])
		if cool_stacks >= int(mech()["ice_stacks_to_break"]):
			cool_stacks = 0
			plates_off_t = float(mech()["armor_off_duration"])
			Events.floating_text.emit(global_position + Vector2(0, -150), "PLAKALAR KIRILDI!", Color(0.6, 0.9, 1.0), 28)
			Events.area_pulse.emit(global_position, 2.0, Color(0.6, 0.9, 1.0))
		_update_armor()
	return amount


func tick_mechanic(delta: float) -> void:
	if plates_off_t > 0.0:
		plates_off_t -= delta
	if cool_stacks > 0:
		_cool_decay_t -= delta
		if _cool_decay_t <= 0.0:
			cool_stacks = 0
	_lava_glow_t = maxf(_lava_glow_t - delta, 0.0)
	_update_armor()
	# Kor Yumruğu atılması
	if _dash_left > 0.0:
		var a := attack_data("ember_fist")
		var step := float(a["speed"]) * delta
		_dash_left -= step
		var col := move_and_collide(Iso.to_screen(_dash_dir * Iso.tiles(step)))
		if not _dash_hit and _target_visible() and Iso.tile_distance(global_position, target.global_position) <= float(a["hit_radius"]) + float(target.get("radius_tiles")):
			_dash_hit = true
			target.call("take_damage", damage * float(a["damage_mult"]), _dash_dir, "fire")
		if col != null or _dash_left <= 0.0:
			_dash_left = 0.0
			Events.area_pulse.emit(global_position, float(a["hit_radius"]), Color(1.0, 0.5, 0.2))


func enter_phase2() -> void:
	plates_gone = true
	cool_stacks = 0
	_update_armor()
	Events.floating_text.emit(global_position + Vector2(0, -170), "ÇEKİRDEK AÇIKTA", Color(1.0, 0.6, 0.2), 26)


func current_speed() -> float:
	return move_speed_tiles * (float(p2()["speed_mult"]) if phase == 2 else 1.0)


func move_dir(_delta: float) -> Vector2:
	if _busy_t > 0.0 or _dash_left > 0.0 or not _target_visible():
		return Vector2.ZERO
	if Iso.tile_distance(global_position, target.global_position) < 1.6:
		return Vector2.ZERO
	return navigator.call(global_position, target.global_position) if navigator.is_valid() else Iso.to_cart(target.global_position - global_position).normalized()


## Lav kanallarının merkez çizgileri: arenanın ortasından ±offset uzakta, iki eksende (# şekli).
func channels() -> Array[Dictionary]:
	var a := attack_data("lava_fill")
	var off := float(a["channel_offset"])
	var out: Array[Dictionary] = []
	for axis: Vector2 in [Vector2.RIGHT, Vector2.DOWN]:
		for s: float in [-1.0, 1.0]:
			var n := axis.orthogonal() * off * s
			out.append({"start": arena.point(n - axis * arena.radius), "dir": axis, "length": arena.radius * 2.0})
	return out


func start_attack(id: String) -> float:
	var a := attack_data(id)
	var gap := float(p2()["speed_mult"]) if phase == 2 else 1.0
	match id:
		"anvil_slam":
			var at := global_position
			hazard(id, at, "circle", float(a["warn"]), float(a["impact_damage_mult"]), {"radius": float(a["impact_radius"])})
			hazard(id, at, "ring_wave", float(a["warn"]), float(a["damage_mult"]),
				{"radius": float(a["ring_radius"]), "wave_speed": float(a["ring_speed"]), "wave_thickness": float(a["ring_thickness"]), "color": Color(1.0, 0.45, 0.15)})
			if phase == 2:
				schedule(float(a["warn"]), func() -> void: _fireballs(at))
			return float(a["warn"]) + (0.9 if phase == 2 else 0.3)
		"lava_fill":
			_lava_glow_t = float(a["warn"])
			for ch: Dictionary in channels():
				hazard(id, ch["start"], "rect", float(a["warn"]), float(a["damage_mult"]),
					{"mode": "zone", "dir_cart": ch["dir"], "length": float(ch["length"]), "width": float(a["channel_width"]),
					"duration": float(a["duration"]), "tick": float(a["tick"]), "kind": "fire", "color": Color(1.0, 0.45, 0.1)})
			return float(a["warn"]) * 0.8
		"ember_fist":
			var to_p := Iso.to_cart(target.global_position - global_position)
			var dist := minf(to_p.length() / Iso.KARO, float(a["max_distance"]))
			var dir := to_p.normalized()
			hazard(id, global_position, "rect", float(a["warn"]) / gap, 0.0,
				{"mode": "visual", "dir_cart": dir, "length": dist + float(a["hit_radius"]), "width": float(a["hit_radius"]) * 2.0})
			schedule(float(a["warn"]) / gap, func() -> void:
				_dash_dir = dir
				_dash_left = dist
				_dash_hit = false)
			return float(a["warn"]) / gap + dist / float(a["speed"]) + 0.3
	return 0.0


func _fireballs(center: Vector2) -> void:
	var p := p2()
	var d: Array = p["fireball_distance"]
	for i: int in int(p["fireballs"]):
		var ang := TAU * i / float(p["fireballs"]) + rng.randf_range(-0.3, 0.3)
		var pt := arena.clamp_inside(center + Iso.to_screen(Vector2.RIGHT.rotated(ang) * Iso.tiles(rng.randf_range(float(d[0]), float(d[1])))))
		hazard("phase2_fireballs", pt, "circle", float(p["fireball_warn"]), float(p["fireball_damage_mult"]),
			{"radius": float(p["fireball_radius"]), "kind": "fire", "color": Color(1.0, 0.4, 0.1)})


## Göğüsteki erimiş çekirdek ve zırh plakaları (soğudukça buz mavisine döner).
func draw_top(n: Node2D) -> void:
	var top := -visual.body_height * visual.scale.y
	n.draw_circle(Vector2(0, top * 0.55), 9.0 if not plates_gone else 14.0, Color(1.0, 0.55, 0.15, 0.95 if plates_gone or plates_off_t > 0.0 else 0.55))
	if not plates_gone and plates_off_t <= 0.0:
		var pc := Color(0.55, 0.58, 0.62).lerp(Color(0.6, 0.9, 1.0), cool_stacks / float(mech()["ice_stacks_to_break"]))
		n.draw_rect(Rect2(Vector2(-22, top * 0.78), Vector2(44, top * -0.45)), pc, false, 5.0)


func draw_overlay(o: Node2D) -> void:
	# Lav kanalları hep görünür (koyu), dolmadan önce parlar
	var a := attack_data("lava_fill")
	var glow := 0.25 + 0.5 * (1.0 - _lava_glow_t / float(a["warn"])) if _lava_glow_t > 0.0 else 0.0
	for ch: Dictionary in channels():
		var poly := Shapes.iso_rect(ch["dir"], float(ch["length"]), float(a["channel_width"]))
		var local := o.to_local(ch["start"])
		var moved := PackedVector2Array()
		for q: Vector2 in poly:
			moved.append(q + local)
		o.draw_colored_polygon(moved, Color(0.18, 0.1, 0.07, 0.75))
		if glow > 0.0:
			o.draw_colored_polygon(moved, Color(1.0, 0.45, 0.1, glow))
