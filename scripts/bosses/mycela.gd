## Mycela, Spor Kraliçesi — 2. kat boss'u (GDD: Boss'lar > 2. Kat). Arenada oyuncudan orta mesafede dolaşır.
##   Spor Bulutu: oyuncunun çevresinde işaretlenen yerlerde birkaç saniye kalan zehirli bulutlar.
##   Kök Patlaması: oyuncunun o anki yerinin altında sırayla işaretlenip fışkıran kökler (sürekli hareket et).
##   Spor Oku: yolları önce çizilen 5 sporluk yelpaze.
## İyileştiren Mantarlar: 3 totem (öncelikli hedef) yaşadıkça Mycela'yı iyileştirir. v0.10.1: totemler
## savaşta YALNIZCA BİR KEZ, Mycela'nın canı %20'ye (mechanic.plant_at_hp_pct) inince dikilir; kırılınca yeniden dikilmez.
## Ateş vuruşu (mermi, alan ya da ateşli yakın saldırı) bir spor bulutuna değerse bulut Zehir Patlaması'yla yok
## olur ve çevredeki düşmanlara (Mycela ve totemler dahil) hasar verir.
## 2. faz: Spor Sisi — arena aralıklarla kısa süre sporla dolar, yalnızca temiz hava alanları güvenli (v0.11.1: eskiden
## faz sonuna kadar doluydu). Sis sürerken Kök Patlaması yok, Spor Bulutu tek ve küçük. Mycela 6 sn'de bir işaretli yere ışınlanır.
class_name Mycela
extends Boss

enum Fog { NONE, WARN, ACTIVE }

const FOG_FADE_SEC := 0.4            ## sis kalkınca yeşilin sönme süresi (sn)

var _clouds: Array[EnemyHazard] = []
var totems_planted: bool = false      ## totemler bu savaşta dikildi mi (yalnızca bir kez)
var _wander: Vector2 = Vector2.INF
var _wander_t: float = 0.0
var _clean: Array[Vector2] = []       ## Spor Sisi'nin temiz hava merkezleri
var fog: Fog = Fog.NONE
var _fog_t: float = 0.0               ## sisin o anki adımının (işaret / sis / ara) kalan süresi
var _fog_fade: float = 0.0            ## sis kalktıktan sonra yeşilin sönmesi (yalnızca görüntü)
var _fog_clouds: int = 0              ## bu sis sırasında bırakılan spor bulutu
var _out_t: float = 0.0
var _relocate_t: float = 0.0


func _body_color() -> String:
	return "#8a5ab0"


func start_fight() -> void:
	pass


## 3 totemi işaretleyip diker (savaşta bir kez; tick_mechanic can eşiğinde çağırır).
func _plant_totems() -> void:
	var m := mech()
	totems_planted = true
	Events.floating_text.emit(global_position + Vector2(0, -150), "MANTAR TOTEMLERİ!", Color(0.7, 1.0, 0.5), 28)
	var base := rng.randf() * TAU
	for i: int in int(m["totems"]):
		var off := Vector2.RIGHT.rotated(base + TAU * i / float(m["totems"])) * float(m["totem_distance"])
		var pt := arena.clamp_inside(arena.point(off))
		hazard("totems", pt, "circle", float(m["plant_warn"]), 0.0, {"mode": "visual", "radius": 0.8, "color": Color(0.6, 0.35, 0.9)})
		schedule(float(m["plant_warn"]), func() -> void: add_minion(str(m["add_id"]), pt))


func tick_mechanic(delta: float) -> void:
	var m := mech()
	if not totems_planted and hp <= max_hp * float(m["plant_at_hp_pct"]):
		_plant_totems()
	var totems := alive_minions(str(m["add_id"]))
	if not totems.is_empty() and status.can_heal():
		var heal := max_hp * float(m["heal_pct_per_sec"]) * totems.size() * delta
		hp = minf(hp + heal, max_hp)
		if int(_time * 2.0) != int((_time - delta) * 2.0):
			for t: Node2D in totems:
				Events.chain_zap.emit(t.global_position + Vector2(0, -30), global_position + Vector2(0, -60), Color(0.5, 1.0, 0.5), false)
	status_text = "Totemler Mycela'yı iyileştiriyor (%d) — önce totemleri kır!" % totems.size() if not totems.is_empty() \
		else ("Canı %%%d'ye inince 3 mantar totemi dikecek" % roundi(float(m["plant_at_hp_pct"]) * 100.0) if not totems_planted else "")
	_check_fire_on_clouds()
	if phase == 2:
		_tick_phase2(delta)


## Ateş spor bulutunu yakar: Zehir Patlaması (oyuncuya dokunmaz).
func _check_fire_on_clouds() -> void:
	var swung := player_swung()
	var m := mech()
	_clouds = _clouds.filter(func(x: Variant) -> bool: return is_instance_valid(x))
	for c: EnemyHazard in _clouds.duplicate():
		if not c.is_active():
			continue
		if fire_near(c.global_position, c.radius) or (swung and fire_swing_reaches(c.global_position, c.radius)):
			_clouds.erase(c)
			c.dismiss()
			Events.area_pulse.emit(c.global_position, float(m["burst_radius"]), Color(0.7, 1.0, 0.3))
			Events.floating_text.emit(c.global_position + Vector2(0, -50), "ZEHİR PATLAMASI", Color(0.8, 1.0, 0.4), 24)
			var dmg := max_hp * float(m["burst_boss_pct"])
			for n: Node in get_tree().get_nodes_in_group("enemies"):
				var e := n as Node2D
				if e and not e.get("dead") and Iso.tile_distance(e.global_position, c.global_position) <= float(m["burst_radius"]) + float(e.get("radius_tiles")):
					var d := Iso.to_cart(e.global_position - c.global_position)
					e.call("apply_damage", dmg, {"kind": "fire", "secondary": true, "dir": d.normalized() if d.length() > 0.01 else Vector2.RIGHT})
					GameState.record_damage(player().weapon().type_id, dmg)


## Spor Sisi sürüyor mu (işareti dahil)?
func fog_running() -> bool:
	return fog != Fog.NONE


## Sis sürerken oyuncunun altına kök fışkırmaz, spor bulutu da yalnızca fog_cloud_count kez bırakılır.
func can_use(id: String) -> bool:
	if not fog_running():
		return true
	match id:
		"root_burst":
			return false
		"spore_cloud":
			return _fog_clouds < int(p2()["fog_cloud_count"])
	return true


func start_attack(id: String) -> float:
	var a := attack_data(id)
	match id:
		"spore_cloud":
			var count := int(a["count"])
			var radius := float(a["radius"])
			if fog_running():
				count = 1
				radius = float(p2()["fog_cloud_radius"])
				_fog_clouds += 1
			for i: int in count:
				var pt := arena.point_near(rng, target.global_position, float(a["spread"])) if i > 0 else target.global_position
				_clouds.append(hazard(id, pt, "circle", float(a["warn"]), float(a["damage_mult"]),
					{"mode": "zone", "radius": radius, "duration": float(a["duration"]), "tick": float(a["tick"]),
					"kind": "poison", "color": Color(0.45, 0.85, 0.3), "look": "fog"}))
			return float(a["warn"])
		"root_burst":
			for i: int in int(a["count"]):
				schedule(i * float(a["interval"]), func() -> void:
					if _target_visible() and not fog_running():
						hazard(id, target.global_position, "circle", float(a["warn"]), float(a["damage_mult"]),
							{"radius": float(a["radius"]), "color": Color(0.8, 0.2, 0.1)}))
			return int(a["count"]) * float(a["interval"]) + float(a["warn"])
		"spore_shot":
			var to_p := Iso.to_cart(target.global_position - global_position).normalized()
			var n := int(a["count"])
			var fan := deg_to_rad(float(a["fan_degrees"]))
			for i2: int in n:
				var dir := to_p.rotated(-fan * 0.5 + fan * i2 / maxf(n - 1, 1))
				shoot(id, global_position, dir, float(a["warn"]), float(a["damage_mult"]), float(a["speed"]), float(a["range"]), "poison", "spore")
			return float(a["warn"])
	return 0.0


func move_dir(delta: float) -> Vector2:
	if _busy_t > 0.0 or not _target_visible():
		return Vector2.ZERO
	_wander_t -= delta
	if _wander == Vector2.INF or _wander_t <= 0.0 or Iso.tile_distance(global_position, _wander) < 0.6:
		_wander = arena.random_point(rng, 1.0, arena.radius - 2.0, target.global_position, 4.0)
		_wander_t = 4.0
	return navigator.call(global_position, _wander) if navigator.is_valid() else Iso.to_cart(_wander - global_position).normalized()


func enter_phase2() -> void:
	_relocate_t = float(p2()["relocate_sec"])
	_start_fog()


## Spor Sisi'ni başlatır: temiz hava alanları seçilip fog_warn sn işaretlenir. Yerdeki spor bulutları ve kök işaretleri
## dağılır (sis sürerken yerde en fazla sisin kendi küçük bulutu olsun).
func _start_fog() -> void:
	var p := p2()
	_clean.clear()
	var base := rng.randf() * TAU
	for i: int in int(p["clean_zones"]):
		_clean.append(arena.clamp_inside(arena.point(Vector2.RIGHT.rotated(base + TAU * i / float(p["clean_zones"])) * arena.radius * 0.5)))
	for n: Node in get_tree().get_nodes_in_group("enemy_hazards"):
		if n.get("source") == self and str(n.get("label")) in ["spore_cloud", "root_burst"] and n.has_method("dismiss"):
			n.call("dismiss")
	_clouds.clear()
	fog = Fog.WARN
	_fog_t = float(p["fog_warn"])
	_fog_clouds = 0
	_out_t = 0.0
	log_telegraph("phase2_spores", float(p["fog_warn"]))
	Events.floating_text.emit(global_position + Vector2(0, -190), "SPOR SİSİ!", Color(0.7, 1.0, 0.5), 28)


func clean_radius() -> float:
	return float(p2()["clean_radius"])


func in_clean_air(pos: Vector2) -> bool:
	for c: Vector2 in _clean:
		if Iso.tile_distance(pos, c) <= clean_radius():
			return true
	return false


func _tick_phase2(delta: float) -> void:
	var p := p2()
	_fog_t -= delta
	_fog_fade = maxf(_fog_fade - delta, 0.0)
	match fog:
		Fog.WARN:
			status_text = "Spor sisi geliyor — temiz hava alanına geç! (%.1f)" % maxf(_fog_t, 0.0)
			if _fog_t <= 0.0:
				fog = Fog.ACTIVE
				_fog_t = float(p["fog_sec"])
		Fog.ACTIVE:
			status_text = "Spor sisi — temiz havada kal! (%.1f)" % maxf(_fog_t, 0.0)
			if _target_visible() and not in_clean_air(target.global_position):
				_out_t -= delta
				if _out_t <= 0.0:
					_out_t = float(p["outside_tick"])
					target.call("take_damage", damage * float(p["outside_damage_mult"]), Vector2.RIGHT, "poison")
			else:
				_out_t = 0.0
			if _fog_t <= 0.0:
				fog = Fog.NONE
				_fog_t = float(p["fog_every_sec"])
				_fog_fade = FOG_FADE_SEC
		Fog.NONE:
			if _fog_t <= 0.0:
				_start_fog()
	_relocate_t -= delta
	if _relocate_t <= 0.0 and _busy_t <= 0.0:
		_relocate_t = float(p["relocate_sec"])
		var dest := arena.random_point(rng, 1.0, arena.radius - 1.5, target.global_position if _target_visible() else Vector2.INF, 3.5)
		hazard("relocate", dest, "circle", float(p["relocate_warn"]), 0.0, {"mode": "visual", "radius": radius_tiles * 1.4, "color": Color(0.6, 0.35, 0.9)})
		schedule(float(p["relocate_warn"]), func() -> void:
			Events.area_pulse.emit(global_position, 1.2, Color(0.6, 0.35, 0.9))
			global_position = dest
			Events.area_pulse.emit(dest, 1.2, Color(0.6, 0.35, 0.9)))


## Spor Sisi: işarette arena hafifçe yeşillenir ve temiz hava alanlarının çemberleri çizilir; sis sürerken koyu yeşil.
## Sis kalkınca yeşil FOG_FADE_SEC'te söner.
func draw_overlay(o: Node2D) -> void:
	if phase != 2 or (fog == Fog.NONE and _fog_fade <= 0.0):
		return
	var p := p2()
	var a := 0.3
	match fog:
		Fog.WARN:
			a = lerpf(0.06, 0.2, 1.0 - clampf(_fog_t / float(p["fog_warn"]), 0.0, 1.0))
		Fog.NONE:
			a = 0.3 * _fog_fade / FOG_FADE_SEC
	for c: Vector2i in arena.cells.keys():
		var wp: Vector2 = arena.cell_to_world.call(c)
		if not in_clean_air(wp):
			paint_cell(o, c, Color(0.45, 0.75, 0.25, a))
	if fog == Fog.NONE:
		return
	for cc: Vector2 in _clean:
		var ring := Shapes.iso_ellipse(clean_radius(), 32)
		var local := o.to_local(cc)
		var moved := PackedVector2Array()
		for q: Vector2 in ring:
			moved.append(q + local)
		moved.append(moved[0])
		o.draw_polyline(moved, Color(0.85, 1.0, 0.9, 0.9), 2.5)
