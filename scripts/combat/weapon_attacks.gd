## WeaponAttacks — 12 silah tipinin sol tık (normal) ve sağ tık (güçlü) saldırıları.
## Saldırının biçimi weapon_types.json > light.style / heavy.style ile seçilir; sayılar da oradan okunur.
## Kaynak (enerji/mana) ve bekleme süreleri Player.kit (RaceKit) üzerinden ödenir. Vuruşlar Player.deal_hit'ten geçer.
##   Sol tık:  arc (yay vuruşu) · thrust (mızrak dürtmesi) · projectile (ok, cıvata, sayfa, küre) · blast (rün patlaması)
##   Sağ tık:  spin · boomerang · flurry · arc · backstab · smash · charge_shot · fan · spear_throw · homing · orb · trap
class_name WeaponAttacks
extends RefCounted


## Sol tık. Saldırdıysa true.
static func light(p: Player) -> bool:
	var w := p.weapon()
	var wt := w.type_data()
	var ld: Dictionary = wt["light"]
	var fam := w.family()
	if w.type_id == "spear" and is_instance_valid(p.spear_out):
		return false  # mızrak havadayken dürtme yok
	if not p.kit.can_use("light", fam):
		p.note("%s yetersiz" % p.kit.resource_name(), Color(0.5, 0.7, 1.0))
		return false
	p.kit.use("light", fam)
	p.end_phase()
	p.attack_cd = p.attack_interval(w)
	p.uses["light"] = int(p.uses["light"]) + 1
	var id := p.next_attack_id()
	var rng_t := p.attack_range(w)
	var col := Weapon.kind_color(w.element)
	match str(ld["style"]):
		"arc", "thrust":
			var arc := float(wt["arc_degrees"])
			p.slash_fx(rng_t, arc, false)
			for e: Node2D in p.enemies_in_arc(rng_t, arc):
				p.deal_hit(e, w, "light", 1.0, id)
		"projectile":
			var pr := make_projectile(p, w, "light", 1.0, id, p.facing_cart)
			pr.speed_tiles = float(ld["speed"])
			pr.radius_tiles = float(ld["radius"])
			pr.max_range = rng_t
			pr.kind = str(ld.get("projectile", "arrow"))
			p.spawn(pr, p.global_position)
			p.visual.lean = 1.0
		"blast":
			var g := make_ground(p, w, "light", 1.0)
			g.mode = "blast"
			g.look = "rune"
			g.radius = float(ld["radius"])
			g.delay = float(ld["delay"])
			g.color = col
			p.spawn(g, p.target_point(rng_t))
	return true


## Sağ tık basıldı. Yay'da dolum başlar (bırakınca atar); Mızrak havadaysa geri çağırır.
static func heavy_pressed(p: Player) -> bool:
	var w := p.weapon()
	var hd: Dictionary = w.type_data()["heavy"]
	var fam := w.family()
	var style := str(hd["style"])
	if style == "spear_throw" and is_instance_valid(p.spear_out):
		p.spear_out.recall()
		return true
	if not p.kit.can_use("heavy", fam):
		if not p.kit.is_ready("heavy"):
			p.note("Sağ tık bekliyor %.1f sn" % float(p.kit.cooldowns["heavy"]))
		else:
			p.note("%s yetersiz" % p.kit.resource_name(), Color(0.5, 0.7, 1.0))
		return false
	if style == "charge_shot":
		p.charging = true
		p.charge_t = 0.0
		return true
	# Mızrak: bekleme süresi mızrak dönünce başlar
	p.kit.use("heavy", fam, style != "spear_throw")
	p.end_phase()
	p.uses["heavy"] = int(p.uses["heavy"]) + 1
	_do_heavy(p, w, hd, style)
	return true


## Sağ tık bırakıldı (yalnızca Yay'ın Güçlü atışı için anlamlı).
static func heavy_released(p: Player) -> void:
	if not p.charging:
		return
	p.charging = false
	var w := p.weapon()
	var hd: Dictionary = w.type_data()["heavy"]
	if not p.kit.use("heavy", w.family()):
		return
	p.end_phase()
	p.uses["heavy"] = int(p.uses["heavy"]) + 1
	var k := clampf(p.charge_t / float(hd["charge_time"]), 0.0, 1.0)
	var mult := lerpf(float(hd["min_mult"]), float(hd["max_mult"]), k)
	var pr := make_projectile(p, w, "heavy", mult, p.next_attack_id(), p.facing_cart)
	pr.speed_tiles = float(hd["speed"])
	pr.max_range = float(hd["range"]) * (1.0 + p.stats_for(w).attack_range_bonus)
	pr.radius_tiles = float(hd["radius"])
	pr.pierce = -1
	pr.kind = "pierce_arrow"
	pr.extra_opts = {"heavy": true}
	p.spawn(pr, p.global_position)
	p.charge_t = 0.0
	if k >= 1.0:
		Events.floating_text.emit(p.global_position + Vector2(0, -80), "TAM GÜÇ", Color(1.0, 0.9, 0.4), 18)


static func _do_heavy(p: Player, w: Weapon, hd: Dictionary, style: String) -> void:
	var mult := float(hd.get("damage_mult", 1.0))
	var col := Weapon.kind_color(w.element)
	var id := p.next_attack_id()
	match style:
		"spin":
			var r := float(hd["radius"])
			p.slash_fx(r, 360.0, true)
			for e: Node2D in p.enemies_in_circle(p.global_position, r):
				p.deal_hit(e, w, "heavy", mult, id, {"heavy": true})
		"arc":
			# Hasat: geniş yay, arkadan vurulanlara ek hasar
			var r2 := float(hd["range"]) * (1.0 + p.stats_for(w).attack_range_bonus)
			var arc := float(hd["arc_degrees"])
			p.slash_fx(r2, arc, false)
			Events.area_pulse.emit(p.global_position, r2 * 0.6, col)
			for e: Node2D in p.enemies_in_arc(r2, arc):
				var opts := {"heavy": true}
				if DamageCalc.is_behind(e.global_position, e.get("facing_cart"), p.global_position):
					opts["damage_buffs"] = float(hd["backstab_bonus"])
					Events.floating_text.emit(e.global_position + Vector2(0, -64), "ARKADAN", Color(0.8, 0.6, 1.0), 16)
				p.deal_hit(e, w, "heavy", mult, id, opts)
		"boomerang":
			var pr := make_projectile(p, w, "heavy", mult, id, p.facing_cart)
			pr.kind = "axe"
			pr.speed_tiles = float(hd["speed"])
			pr.return_speed = float(hd["speed"]) * 1.15
			pr.max_range = float(hd["distance"])
			pr.radius_tiles = float(hd["radius"])
			pr.pierce = -1
			pr.boomerang = true
			pr.extra_opts = {"heavy": true}
			p.spawn(pr, p.global_position)
			p.visual.show_weapon = false
			pr.finished.connect(func() -> void:
				if is_instance_valid(p):
					p.refresh_weapon_visual())
		"flurry":
			var hits := int(hd["hits"])
			var interval := float(hd["interval"])
			p.busy_t = hits * interval
			for i: int in hits:
				var last := i == hits - 1
				var hit_fn := func() -> void:
					if not is_instance_valid(p) or p.dead:
						return
					var r3 := float(hd["range"])
					var a3 := float(hd["arc_degrees"])
					p.slash_fx(r3, a3 * 0.5, false, p.facing_cart.rotated(deg_to_rad(-20.0 if i % 2 == 0 else 20.0)))
					var sub_id := p.next_attack_id()
					for e: Node2D in p.enemies_in_arc(r3, a3):
						p.deal_hit(e, w, "heavy", mult, sub_id, {"heavy": last})
						if last and not e.get("dead"):
							var st: StatusEffects = e.get("status")
							st.stun(float(hd["stun_duration"]), float(hd["boss_slow_duration"]), float(hd["boss_slow"]))
							Events.floating_text.emit(e.global_position + Vector2(0, -70), "YAVAŞ" if bool(e.get("is_boss")) else "SERSEM", Color(1.0, 0.95, 0.5), 20)
				if i == 0:
					hit_fn.call()
				else:
					p.get_tree().create_timer(i * interval, false, true).timeout.connect(hit_fn)
		"backstab":
			var target := p.enemy_near_point(p.aim_point, float(hd["search_range"]))
			var dur := float(hd["dash_duration"])
			p.busy_t = dur + 0.05
			p.iframes = maxf(p.iframes, dur + 0.1)
			if target:
				var behind := behind_point(target, 0.55)
				var free := p.find_free_spot(behind)
				if free == Vector2.INF:
					free = behind
				p.afterimage(Color(0.6, 0.4, 1.0, 0.5))
				p.move_override((free - p.global_position) / dur, dur, func() -> void:
					if not is_instance_valid(target) or target.get("dead") or p.dead:
						return
					var to_t := Iso.to_cart(target.global_position - p.global_position)
					if to_t.length() > 0.01:
						p.facing_cart = to_t.normalized()
						p.visual.set_facing(p.facing_cart)
					p.slash_fx(1.2, 70.0, true)
					Events.floating_text.emit(target.global_position + Vector2(0, -64), "SAPLAMA", Color(0.8, 0.6, 1.0), 18)
					p.deal_hit(target, w, "heavy", mult, id, {"heavy": true}))
			else:
				var dist := float(hd["fallback_distance"])
				p.move_override(Iso.to_screen(p.facing_cart * Iso.tiles(dist)) / dur, dur, func() -> void:
					if p.dead:
						return
					p.slash_fx(1.3, 90.0, true)
					for e: Node2D in p.enemies_in_arc(1.3, 90.0):
						p.deal_hit(e, w, "heavy", mult, id, {"heavy": true}))
		"smash":
			var center := p.global_position + Iso.to_screen(p.facing_cart * Iso.tiles(float(hd["offset"])))
			var r4 := float(hd["radius"])
			p.slash_fx(r4, 360.0, true, p.facing_cart, col, center)
			Events.area_pulse.emit(center, r4, col.lerp(Color(0.8, 0.7, 0.5), 0.4))
			for e: Node2D in p.enemies_in_circle(center, r4):
				p.deal_hit(e, w, "heavy", mult, id, {"heavy": true})
				if not e.get("dead"):
					(e.get("status") as StatusEffects).slow(float(hd["slow_duration"]), float(hd["slow"]))
		"fan":
			var n := int(hd["bolts"])
			var spread := float(hd["spread_degrees"])
			for i: int in n:
				var a := -spread * 0.5 + spread * i / maxf(n - 1, 1)
				var pr2 := make_projectile(p, w, "heavy", mult, id, p.facing_cart.rotated(deg_to_rad(a)))
				pr2.kind = "bolt"
				pr2.speed_tiles = float(hd["speed"])
				pr2.max_range = float(hd["range"])
				pr2.radius_tiles = float(hd["radius"])
				p.spawn(pr2, p.global_position)
		"spear_throw":
			var pr3 := make_projectile(p, w, "heavy", mult, id, p.facing_cart)
			pr3.kind = "spear"
			pr3.speed_tiles = float(hd["speed"])
			pr3.return_speed = float(hd["return_speed"])
			pr3.max_range = float(hd["range"])
			pr3.radius_tiles = float(hd["radius"])
			pr3.pierce = -1
			pr3.stick = true
			pr3.auto_return_sec = float(hd["auto_return_sec"])
			pr3.extra_opts = {"heavy": true}
			p.spear_out = pr3
			p.spawn(pr3, p.global_position)
			p.refresh_weapon_visual()
			pr3.finished.connect(func() -> void:
				if not is_instance_valid(p):
					return
				p.spear_out = null
				p.kit.start("heavy", w.family())
				p.refresh_weapon_visual())
		"homing":
			var n2 := int(hd["projectiles"])
			for i: int in n2:
				var a2 := -50.0 + 100.0 * i / maxf(n2 - 1, 1)
				var pr4 := make_projectile(p, w, "heavy", mult, id, p.facing_cart.rotated(deg_to_rad(a2)))
				pr4.kind = "page"
				pr4.speed_tiles = float(hd["speed"])
				pr4.max_range = float(hd["range"])
				pr4.radius_tiles = float(hd["radius"])
				pr4.homing_range = float(hd["seek_range"])
				pr4.turn_rate = float(hd["turn_rate"])
				p.spawn(pr4, p.global_position)
		"orb":
			var pr5 := make_projectile(p, w, "heavy", mult, id, p.facing_cart)
			pr5.kind = "big_orb"
			pr5.speed_tiles = float(hd["speed"])
			pr5.max_range = float(hd["range"])
			pr5.radius_tiles = float(hd["radius"])
			pr5.explode_radius = float(hd["explosion_radius"])
			p.spawn(pr5, p.global_position)
		"trap":
			if is_instance_valid(p.trap):
				p.trap.dismiss()
			var g := make_ground(p, w, "heavy", mult)
			g.mode = "trap"
			g.look = "rune"
			g.radius = float(hd["radius"])
			g.arm_time = float(hd["arm_time"])
			g.trigger_radius = float(hd["trigger_radius"])
			g.lifetime = float(hd["lifetime"])
			g.color = col
			p.trap = g
			p.spawn(g, p.target_point(float(hd["max_range"])))


static func make_projectile(p: Player, w: Weapon, source: String, mult: float, attack_id: int, dir: Vector2) -> Projectile:
	var pr := Projectile.new()
	pr.player = p
	pr.weapon = w
	pr.source = source
	pr.skill_mult = mult
	pr.attack_id = attack_id
	pr.dir_cart = dir
	pr.color = Weapon.kind_color(w.element)
	return pr


static func make_ground(p: Player, w: Weapon, source: String, mult: float) -> GroundEffect:
	var g := GroundEffect.new()
	g.player = p
	g.weapon = w
	g.source = source
	g.skill_mult = mult
	return g


## Hedefin arkasındaki nokta (hedefin baktığı yönün tersinde, gövdesinin dışında).
static func behind_point(target: Node2D, gap_tiles: float) -> Vector2:
	var f: Vector2 = target.get("facing_cart")
	if f.length() < 0.01:
		f = Vector2.RIGHT
	var dist := float(target.get("radius_tiles")) + gap_tiles
	return target.global_position - Iso.to_screen(f.normalized() * Iso.tiles(dist))
