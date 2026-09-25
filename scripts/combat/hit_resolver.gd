## HitResolver — oyuncunun bir silah vuruşunu hedefe işler: hasar (DamageCalc), element durumu (StatusEffects),
## kombolar (Combos), Yıldırım zinciri ve 5 özellik (Traits). Efektleri Events sinyalleriyle duyurur.
##
## Hedef arayüzü (EnemyMelee ve testlerdeki sahte hedef bunu sağlar):
##   değişkenler: dead, hp, max_hp, is_boss, radius_tiles, facing_cart, defense, status, fury_stacks
##   fonksiyonlar: apply_damage(amount: float, info: Dictionary), execute(dir_cart: Vector2)
## Saldıran: global_position; varsa heal(amount) (Can Emme için).
##
## İkincil vuruşlar (zincir, sekme, kombo alanı) hasar ve element durumu uygular ama yeni kombo, zincir ya da
## özellik tetiklemez; böylece sonsuz döngü olmaz.
class_name HitResolver
extends RefCounted

const P := DamageCalc.PHYSICAL


## opts anahtarları (hepsi isteğe bağlı):
##   skill_mult (1.0), heavy (false), dir (Vector2, düz uzayda vuruş yönü), crit_bonus_chance (0),
##   crit_damage_bonus (0), damage_buffs (0), element_bonus (0), mastery_level (0), combo_damage_bonus (0),
##   flex_traits (Array: Esnek slottaki silahın özellikleri), flex_scale (0,09: onların gücü),
##   fury_max (Öfke tavanı; 0 = veri), execute_bonus / execute_boss_bonus (İnfaz eşiğine eklenen; Aşama 6 özel etkileri)
## candidates: yakındaki diğer hedefler (zincir, sekme ve alan kombo'ları için).
## Döndürür: {"damage", "crit", "combo", "executed", "immune", "chained": Array, "ricochet": Node}
static func resolve(attacker: Node2D, weapon: Weapon, target: Node2D, opts: Dictionary,
		candidates: Array, rng: RandomNumberGenerator) -> Dictionary:
	var res := {"damage": 0.0, "crit": false, "combo": "", "executed": false, "immune": false, "chained": [], "ricochet": null}
	if target == null or target.get("dead"):
		return res
	var kind := weapon.element
	var def: DamageCalc.Defense = target.get("defense")
	var st: StatusEffects = target.get("status")
	var immune := DamageCalc.is_immune(kind, def)
	res["immune"] = immune
	var dir: Vector2 = opts.get("dir", Vector2.RIGHT)

	# Kombo: hedefte ilk element varken ikinci elementle vuruş
	var combo := {}
	var consumed := ""
	if kind != P and not immune:
		var found := Combos.find(st, kind)
		if not found.is_empty():
			combo = found["combo"]
			consumed = found["consumed"]

	# Ana vuruş
	var hit := _base_hit(weapon, opts)
	var caps: Dictionary = DataDB.get_value("progression", "stat_caps")
	var crit_chance := minf(float(DataDB.get_value("progression", "combat.base_crit_chance")) + float(opts.get("crit_bonus_chance", 0.0)), float(caps["crit_chance"]))
	hit.is_crit = bool(combo.get("guaranteed_crit", false)) or rng.randf() < crit_chance
	var fury_s := trait_scale(weapon, "fury", opts)
	if fury_s > 0.0:
		hit.damage_buffs += Traits.fury_bonus(int(target.get("fury_stacks")), fury_s, float(opts.get("fury_max", 0.0)))
		target.set("fury_stacks", int(target.get("fury_stacks")) + 1)
	hit.backstab = DamageCalc.is_behind(target.global_position, target.get("facing_cart"), attacker.global_position)
	var dmg := DamageCalc.compute(hit, def)
	res["crit"] = hit.is_crit

	if not combo.is_empty():
		st.consume(consumed)
	target.call("apply_damage", dmg, {"crit": hit.is_crit, "dir": dir, "heavy": bool(opts.get("heavy", false)), "kind": kind, "immune": immune})
	res["damage"] = dmg
	var total_dealt := dmg

	# Element durumu
	if kind != P and not immune and not target.get("dead"):
		var applied := st.apply_element(kind, dmg)
		if applied["froze"]:
			_text(target, "DONDU", Weapon.kind_color("ice"))

	# Kombo etkisi
	if not combo.is_empty():
		res["combo"] = combo["id"]
		total_dealt += _trigger_combo(combo, attacker, weapon, target, hit, dmg, opts, candidates)

	# Yıldırım zinciri
	if kind == "lightning" and not immune:
		var el: Dictionary = DataDB.table("elements")["elements"]["lightning"]
		var others := _nearest(target, candidates, float(el["chain_range"]), int(el["chain_targets"]))
		for o: Node2D in others:
			Events.chain_zap.emit(_mid(target), _mid(o), Weapon.kind_color("lightning"), true)
			total_dealt += secondary_hit(weapon, o, float(el["chain_damage_pct"]), kind, opts, true, dir)
			(res["chained"] as Array).append(o)

	# Özellikler (silahın kendi özellikleri tam güçle, Esnek slottakiler %9 ile)
	var ls_s := trait_scale(weapon, "lifesteal", opts)
	if ls_s > 0.0 and attacker.has_method("heal"):
		attacker.call("heal", Traits.lifesteal_amount(total_dealt, ls_s))
	var ex_s := trait_scale(weapon, "execute", opts)
	var ex_bonus := float(opts.get("execute_boss_bonus" if bool(target.get("is_boss")) else "execute_bonus", 0.0))
	if ex_s > 0.0 and not target.get("dead") \
			and Traits.should_execute(float(target.get("hp")), float(target.get("max_hp")), bool(target.get("is_boss")), ex_s, ex_bonus):
		_text(target, "İNFAZ", Color(1.0, 0.3, 0.25))
		target.call("execute", dir)
		res["executed"] = true
	var stun_s := trait_scale(weapon, "stun", opts)
	if stun_s > 0.0 and not target.get("dead") and Traits.roll_stun(rng, stun_s):
		var sd := Traits.data("stun")
		st.stun(float(sd["duration"]), float(sd["boss_slow_duration"]), float(sd["boss_slow"]))
		_text(target, "YAVAŞ" if bool(target.get("is_boss")) else "SERSEM", Color(1.0, 0.95, 0.5))
	var ric_s := trait_scale(weapon, "ricochet", opts)
	if ric_s > 0.0 and Traits.roll_ricochet(rng, ric_s):
		var rd := Traits.data("ricochet")
		var near := _nearest(target, candidates, float(rd["range"]), 1)
		if not near.is_empty():
			var r: Node2D = near[0]
			Events.chain_zap.emit(_mid(target), _mid(r), weapon.rarity_color().lightened(0.3), false)
			secondary_hit(weapon, r, float(rd["damage_pct"]), kind, opts, true, dir)
			res["ricochet"] = r

	GameState.record_damage(weapon.type_id, total_dealt)
	return res


## Özelliğin bu vuruştaki gücü: silahta varsa 1, Esnek slottaki silahta varsa + flex_scale (yoksa 0).
static func trait_scale(weapon: Weapon, trait_id: String, opts: Dictionary) -> float:
	var s := 1.0 if weapon.has_trait(trait_id) else 0.0
	if trait_id in (opts.get("flex_traits", []) as Array):
		s += float(opts.get("flex_scale", 0.0))
	return s


## İkincil vuruş: ana vuruşun pct katı, kritik ve arkadan vuruş yok. Hedefin bağışıklığı geçerlidir.
## apply_status true ise element durumunu da bırakır (kombo tetiklemez).
static func secondary_hit(weapon: Weapon, target: Node2D, pct: float, kind: String, opts: Dictionary,
		apply_status: bool, dir: Vector2) -> float:
	if target.get("dead"):
		return 0.0
	var hit := _base_hit(weapon, opts)
	hit.type_mult *= pct
	hit.kind = kind
	var def: DamageCalc.Defense = target.get("defense")
	var immune := DamageCalc.is_immune(kind, def)
	var dmg := DamageCalc.compute(hit, def)
	target.call("apply_damage", dmg, {"crit": false, "dir": dir, "heavy": false, "kind": kind, "immune": immune, "secondary": true})
	if apply_status and kind != P and not immune and not target.get("dead"):
		(target.get("status") as StatusEffects).apply_element(kind, dmg)
	return dmg


static func _base_hit(weapon: Weapon, opts: Dictionary) -> DamageCalc.Hit:
	var hit := DamageCalc.Hit.new()
	hit.base_damage = weapon.base_damage()
	hit.type_mult = float(weapon.type_data()["damage_mult"]) * float(opts.get("skill_mult", 1.0))
	hit.weapon_level = weapon.level
	hit.mastery_level = int(opts.get("mastery_level", 0))
	hit.damage_buffs = float(opts.get("damage_buffs", 0.0))
	hit.kind = weapon.element
	hit.element_bonus = float(opts.get("element_bonus", 0.0))
	hit.crit_damage_bonus = float(opts.get("crit_damage_bonus", 0.0))
	return hit


## Kombonun etkisini uygular; verdiği ek hasarı döndürür.
static func _trigger_combo(combo: Dictionary, _attacker: Node2D, weapon: Weapon, target: Node2D,
		hit: DamageCalc.Hit, dmg: float, opts: Dictionary, candidates: Array) -> float:
	var id: String = combo["id"]
	var color := Color(str(combo["color"]))
	var bonus_mult := 1.0 + float(opts.get("combo_damage_bonus", 0.0))
	var dir: Vector2 = opts.get("dir", Vector2.RIGHT)
	var st: StatusEffects = target.get("status")
	var extra := 0.0
	Events.combo_triggered.emit(id, target)
	match id:
		"electroshock":
			# Hedef ve menzildeki tüm ıslak düşmanlar zincirleme çarpılır; ıslaklık tüketilir.
			var pct := float(combo["damage_pct"]) * bonus_mult
			var victims: Array[Node2D] = [target]
			for c: Variant in candidates:
				var o := c as Node2D
				if o == null or o == target or o.get("dead"):
					continue
				if not (o.get("status") as StatusEffects).has_element("water"):
					continue
				if Iso.tile_distance(target.global_position, o.global_position) > float(combo["range"]):
					continue
				victims.append(o)
			var prev := target
			for v: Node2D in victims:
				if v != target:
					Events.chain_zap.emit(_mid(prev), _mid(v), color, true)
					prev = v
				(v.get("status") as StatusEffects).consume("water")
				extra += secondary_hit(weapon, v, pct, "lightning", opts, false, dir)
		"melt":
			var bonus := DamageCalc.Hit.new()
			bonus.base_damage = dmg
			bonus.type_mult = float(combo["bonus_damage_pct"]) * bonus_mult
			# dmg zaten zırh, element ve kritik içeriyor; tekrar uygulanmaması için savunmasız hesaplanır.
			var raw := DamageCalc.compute(bonus, DamageCalc.Defense.new())
			target.call("apply_damage", raw, {"crit": true, "dir": dir, "heavy": true, "kind": hit.kind, "immune": false, "secondary": true})
			Events.area_pulse.emit(target.global_position, 1.2, color)
			extra += raw
		"freeze":
			if not st.freeze(float(combo["freeze_duration"])):
				_text(target, "DONMAYA BAĞIŞIK", color)
		"shatter":
			Events.area_pulse.emit(target.global_position, 0.9, color)
		"poison_burst":
			var r := float(combo["radius"])
			Events.area_pulse.emit(target.global_position, r, color)
			for c2: Variant in [target] + candidates:
				var o2 := c2 as Node2D
				if o2 == null or o2.get("dead"):
					continue
				if o2 != target and Iso.tile_distance(target.global_position, o2.global_position) > r:
					continue
				extra += secondary_hit(weapon, o2, float(combo["damage_pct"]) * bonus_mult, "poison", opts, false, dir)
		"steam":
			var r2 := float(combo["radius"])
			Events.area_pulse.emit(target.global_position, r2, color)
			for c3: Variant in [target] + candidates:
				var o3 := c3 as Node2D
				if o3 == null or o3.get("dead"):
					continue
				if o3 == target or Iso.tile_distance(target.global_position, o3.global_position) <= r2:
					(o3.get("status") as StatusEffects).apply_steam(float(combo["duration"]), float(combo["miss_chance"]))
		"rot":
			st.apply_rot(float(combo["duration"]), float(combo["poison_mult"]))
	return extra


## Hedefe en yakın, ölü olmayan ve menzildeki en fazla count aday.
static func _nearest(target: Node2D, candidates: Array, range_tiles: float, count: int) -> Array[Node2D]:
	var pairs: Array = []
	for c: Variant in candidates:
		var o := c as Node2D
		if o == null or o == target or o.get("dead"):
			continue
		var d := Iso.tile_distance(target.global_position, o.global_position)
		if d <= range_tiles:
			pairs.append([d, o])
	pairs.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var out: Array[Node2D] = []
	for i: int in mini(count, pairs.size()):
		out.append(pairs[i][1])
	return out


static func _mid(n: Node2D) -> Vector2:
	return n.global_position + Vector2(0, -18)


static func _text(target: Node2D, text: String, color: Color) -> void:
	Events.floating_text.emit(target.global_position + Vector2(0, -70), text, color, 22)
