## RaceAbilities — 4 ırkın Q/E yetenekleri (GDD: Irklar). Sayılar races.json > abilities içinden okunur.
##   Warrior  Q Zırh (hasar azaltma + %3 hasar) · E Yer sarsıntısı (önde geniş yay, büyük hasar)
##   Ghost    Q Faz (maks 1 sn dokunulmaz ve görünmez) · E Gölge adımı (farenin yakınındaki düşmanın arkasına ışınlanma)
##   Archer   Q Geri sıçrama (geriye atılıp öne 3 ok) · E Ok yağmuru (seçilen alana dalga dalga ok)
##   Magical  Q Uçuş (engellerin üstünden) · E Element fırtınası (aktif silahın elementinde alan hasarı)
## Hasar veren yetenekler aktif silahın vuruşunun skill_mult katıdır ve onun elementini taşır (kombolar çalışır).
class_name RaceAbilities
extends RefCounted


## Yeteneği kullanır; kaynak/bekleme yetmiyorsa ya da hedef yoksa false.
static func use(p: Player, slot: String) -> bool:
	var ab: Dictionary = DataDB.table("races")[p.race_id]["abilities"][slot]
	var w := p.weapon()
	var fam := w.family()
	if not p.kit.can_use(slot, fam):
		if not p.kit.is_ready(slot):
			p.note("%s bekliyor %.1f sn" % [ab["name"], float(p.kit.cooldowns[slot])])
		else:
			p.note("%s yetersiz" % p.kit.resource_name(), Color(0.5, 0.7, 1.0))
		return false
	# Hedef gerektiren yetenek: hedef yoksa bedel ödenmez
	var target: Node2D = null
	if str(ab["id"]) == "shadow_step":
		target = p.enemy_near_point(p.aim_point, float(ab["range"]))
		if target == null:
			p.note("Menzilde hedef yok")
			return false
	p.kit.use(slot, fam)
	p.uses[slot] = int(p.uses[slot]) + 1
	Events.floating_text.emit(p.global_position + Vector2(0, -86), str(ab["name"]), Color(0.95, 0.9, 0.7), 18)
	var id := p.next_attack_id()
	var col := Weapon.kind_color(w.element)
	match str(ab["id"]):
		"armor_up":
			p.start_armor_buff(float(ab["duration"]))
			Events.area_pulse.emit(p.global_position, 1.0, Color(1.0, 0.8, 0.3))
		"ground_slam":
			p.end_phase()
			var r := float(ab["range"])
			var arc := float(ab["arc_degrees"])
			p.slash_fx(r, arc, false, p.facing_cart, col.lerp(Color(0.9, 0.75, 0.5), 0.5))
			Events.area_pulse.emit(p.global_position + Iso.to_screen(p.facing_cart * Iso.tiles(r * 0.5)), r * 0.6, Color(0.9, 0.75, 0.5))
			for e: Node2D in p.enemies_in_arc(r, arc):
				p.deal_hit(e, w, slot, float(ab["skill_mult"]), id, {"heavy": true})
		"phase":
			p.start_phase(float(ab["max_duration"]))
		"shadow_step":
			var dest := WeaponAttacks.behind_point(target, float(ab["behind_distance"]) - float(target.get("radius_tiles")))
			if p.teleport_to(dest):
				p.iframes = maxf(p.iframes, float(ab["iframes"]))
				var to_t := Iso.to_cart(target.global_position - p.global_position)
				if to_t.length() > 0.01:
					p.facing_cart = to_t.normalized()
					p.visual.set_facing(p.facing_cart)
				Events.area_pulse.emit(p.global_position, 0.8, Color(0.6, 0.4, 1.0))
		"back_leap":
			var dur := float(ab["duration"])
			var back := -p.facing_cart
			p.iframes = maxf(p.iframes, dur)
			p.move_override(Iso.to_screen(back * Iso.tiles(float(ab["distance"]))) / dur, dur)
			p.afterimage(Color(0.5, 1.0, 0.6, 0.5))
			var n := int(ab["arrows"])
			var spread := float(ab["spread_degrees"])
			for i: int in n:
				var a := -spread * 0.5 + spread * i / maxf(n - 1, 1)
				var pr := WeaponAttacks.make_projectile(p, w, slot, float(ab["skill_mult"]), id, p.facing_cart.rotated(deg_to_rad(a)))
				pr.kind = "arrow"
				pr.speed_tiles = float(ab["arrow_speed"])
				pr.max_range = float(ab["arrow_range"])
				pr.radius_tiles = 0.25
				p.spawn(pr, p.global_position)
		"arrow_rain":
			var g := WeaponAttacks.make_ground(p, w, slot, float(ab["skill_mult"]))
			g.mode = "pulses"
			g.look = "rain"
			g.radius = float(ab["radius"])
			g.delay = float(ab["delay"])
			g.pulses = int(ab["waves"])
			g.interval = float(ab["interval"])
			g.color = col.lerp(Color(0.95, 0.9, 0.75), 0.5)
			p.spawn(g, p.target_point(float(ab["max_range"])))
		"flight":
			p.start_flight(float(ab["duration"]))
		"element_storm":
			var g2 := WeaponAttacks.make_ground(p, w, slot, float(ab["skill_mult"]))
			g2.mode = "pulses"
			g2.look = "storm"
			g2.radius = float(ab["radius"])
			g2.delay = 0.2
			g2.pulses = int(ab["pulses"])
			g2.interval = float(ab["interval"])
			g2.color = col
			p.spawn(g2, p.target_point(float(ab["max_range"])))
	return true
