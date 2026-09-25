## ItemEffects — oyuncunun taşıdığı eşyaların savaş etkileri (Aşama 5). Player her karede tick() çağırır ve
## vuruş/öldürme/kombo/atılma/sağ tık anlarında kancaları çağırır.
##   Rezonans slotu: aktif silahın her vuruşunda, Rezonans silahının T × Ç × (1+L) değerinin %10'u (açıksa %7'si)
##     kadar ek hasar, onun elementiyle. Oyuncunun buff'larından etkilenmez; bağışıklık geçerlidir; element durumu
##     bırakmaz, kombo tetiklemez (ikincil vuruş).
##   Esnek slot: silahsa özellikleri ve efsanevi pasifi %9 ile işler; tılsımsa tılsımın tam etkisi.
##   Efsanevi silah (aktif): pasifi tam, sağ tık eki (skill) her sağ tıkta.
## Tılsımlar: Kan Taşı (öldürme başına +%2 hasar, 10 sn, maks 5 yığın), Rüzgâr Tüyü (Space beklemesi −%30, atılmadan
## sonra 2 sn +%15 hareket hızı), Element Kalbi (kombo sonrası 3 sn +%20 element hasarı).
class_name ItemEffects
extends RefCounted

var player: Player
var resonance: Weapon          ## Rezonans slotundaki silah (null = boş)
var flex: Variant              ## Esnek slottaki silah ya da tılsım (null = boş)

# Tılsım ve pasif durumları
var blood_stacks: int = 0
var blood_t: float = 0.0
var feather_t: float = 0.0
var heart_t: float = 0.0
var frenzy_t: float = 0.0
var frenzy_bonus: float = 0.0
var hit_counter: Dictionary = {}   ## pasif kaynağı ("active"/"flex") -> sayılan saldırı
var _last_counted_attack: Dictionary = {}
var _combat: Dictionary


func _init(p: Player) -> void:
	player = p
	_combat = DataDB.get_value("progression", "combat")


func tick(delta: float) -> void:
	blood_t = maxf(blood_t - delta, 0.0)
	if blood_t <= 0.0:
		blood_stacks = 0
	feather_t = maxf(feather_t - delta, 0.0)
	heart_t = maxf(heart_t - delta, 0.0)
	frenzy_t = maxf(frenzy_t - delta, 0.0)


# --- slotlar ---

func flex_weapon() -> Weapon:
	return flex as Weapon


func talisman() -> Talisman:
	return flex as Talisman


func has_talisman(id: String) -> bool:
	return talisman() != null and talisman().id == id


func flex_scale() -> float:
	return float(_combat["flex_weapon_passive_pct"])


## Rezonans oranı: kilitliyken %10, açıkken %7 (oyuncunun leveline göre). Boss özel etkisi Rezonans güçlendirme:
## %15 / %10.
func resonance_pct() -> float:
	if resonance == null:
		return 0.0
	var locked := resonance.is_locked(player.level)
	var boost := GameState.special("resonance_boost")
	if not boost.is_empty():
		return float(boost["locked"] if locked else boost["unlocked"])
	return float(_combat["resonance_locked_pct" if locked else "resonance_unlocked_pct"])


# --- vuruşa eklenen bonuslar ---

## deal_hit'in opts'una eklenenler: Esnek silahın özellikleri, Kan Taşı hasarı, Element Kalbi.
func hit_opts() -> Dictionary:
	var o := {"damage_buffs": 0.0, "element_bonus": 0.0}
	var fw := flex_weapon()
	if fw != null and not fw.traits.is_empty():
		o["flex_traits"] = fw.traits.duplicate()
		o["flex_scale"] = flex_scale()
	if has_talisman("blood_stone") and blood_stacks > 0:
		o["damage_buffs"] = float(o["damage_buffs"]) + blood_stacks * float(talisman().data()["damage_per_stack"])
	if has_talisman("element_heart") and heart_t > 0.0:
		o["element_bonus"] = float(o["element_bonus"]) + float(talisman().data()["element_damage_bonus"])
	return o


## Geçici saldırı hızı bonusu (efsanevi "kill_frenzy").
func attack_speed_bonus() -> float:
	return frenzy_bonus if frenzy_t > 0.0 else 0.0


## Hareket hızı çarpanı (Rüzgâr Tüyü atılmadan sonra).
func move_speed_mult() -> float:
	if has_talisman("wind_feather") and feather_t > 0.0:
		return 1.0 + float(talisman().data()["move_speed_bonus"])
	return 1.0


## Space bekleme süresi çarpanı (Rüzgâr Tüyü).
func dash_cooldown_mult() -> float:
	return 1.0 - dash_cooldown_reduction()


## Rüzgâr Tüyü'nün Space bekleme süresi azaltması (Player ödüllerle toplayıp tavana uydurur).
func dash_cooldown_reduction() -> float:
	if has_talisman("wind_feather"):
		return float(talisman().data()["dash_cooldown_reduction"])
	return 0.0


# --- efsanevi pasif kaynakları ---

## [ [silah, güç], ... ]: aktif efsanevi silah tam, Esnek slottaki efsanevi %9.
func passive_sources() -> Array:
	var out: Array = []
	var aw := player.weapon()
	if aw != null and aw.is_legendary():
		out.append([aw, 1.0, "active"])
	var fw := flex_weapon()
	if fw != null and fw.is_legendary():
		out.append([fw, flex_scale(), "flex"])
	return out


static func _scaled(pd: Dictionary, field: String, scale: float) -> float:
	var v := float(pd[field])
	return v * scale if str(pd.get("flex_field", "")) == field else v


# --- kancalar ---

## Player.deal_hit ana vuruştan sonra çağırır.
func after_hit(target: Node2D, w: Weapon, res: Dictionary, attack_id: int, opts: Dictionary) -> void:
	if res.is_empty():
		return
	# Rezonans ek hasarı
	if resonance != null and not target.get("dead"):
		var dir: Vector2 = opts.get("dir", player.facing_cart)
		var dmg := HitResolver.secondary_hit(resonance, target, resonance_pct(), resonance.element, {}, false, dir)
		GameState.record_damage(resonance.type_id, dmg)
	# Efsanevi pasifler
	for src: Array in passive_sources():
		var lw: Weapon = src[0]
		var scale: float = src[1]
		var pd := lw.passive_data()
		match str(pd["id"]):
			"sky_lightning":
				var key: String = src[2]
				if int(_last_counted_attack.get(key, -1)) == attack_id:
					continue
				_last_counted_attack[key] = attack_id
				hit_counter[key] = int(hit_counter.get(key, 0)) + 1
				if int(hit_counter[key]) % int(pd["every_n_hits"]) == 0:
					_burst(lw, target.global_position, float(pd["radius"]), _scaled(pd, "damage_pct", scale), true, opts)
			"crit_nova":
				if bool(res.get("crit", false)):
					_burst(lw, target.global_position, float(pd["radius"]), _scaled(pd, "damage_pct", scale), false, opts)


func on_kill(enemy: Node2D, _is_elite: bool) -> void:
	if has_talisman("blood_stone"):
		var td := talisman().data()
		blood_stacks = mini(blood_stacks + 1, int(td["max_stacks"]))
		blood_t = float(td["duration"])
	for src: Array in passive_sources():
		var lw: Weapon = src[0]
		var scale: float = src[1]
		var pd := lw.passive_data()
		match str(pd["id"]):
			"death_burst":
				if enemy != null and is_instance_valid(enemy):
					_burst(lw, enemy.global_position, float(pd["radius"]), _scaled(pd, "damage_pct", scale), false, {}, enemy)
			"kill_frenzy":
				var prev := frenzy_bonus if frenzy_t > 0.0 else 0.0
				frenzy_bonus = maxf(prev, _scaled(pd, "attack_speed", scale))
				frenzy_t = float(pd["duration"])


func on_combo() -> void:
	if has_talisman("element_heart"):
		heart_t = float(talisman().data()["duration"])
	for src: Array in passive_sources():
		var lw: Weapon = src[0]
		var pd := lw.passive_data()
		if str(pd["id"]) == "combo_reset" and player.rng.randf() < _scaled(pd, "chance", float(src[1])):
			for s: String in ["heavy", "q", "e"]:
				player.kit.cooldowns[s] = 0.0
			Events.floating_text.emit(player.global_position + Vector2(0, -86), "YENİLENDİ", lw.rarity_color(), 18)


func on_dash() -> void:
	if has_talisman("wind_feather"):
		feather_t = float(talisman().data()["duration"])


## Efsanevi silahın sağ tık eki (skill): sağ tık kullanılınca.
func on_heavy(w: Weapon) -> void:
	if w == null or not w.is_legendary():
		return
	var sd := w.skill_data()
	var col := Weapon.kind_color(w.element)
	match str(sd["id"]):
		"heavy_nova":
			var g := WeaponAttacks.make_ground(player, w, "heavy", float(sd["skill_mult"]))
			g.mode = "blast"
			g.look = "storm"
			g.radius = float(sd["radius"])
			g.delay = float(sd["delay"])
			g.color = col
			player.spawn(g, player.global_position)
		"heavy_strikes":
			var center := player.target_point(float(sd["max_range"]))
			for i: int in int(sd["count"]):
				var off := Vector2.ZERO
				if i > 0:
					var a := player.rng.randf() * TAU
					off = Iso.to_screen(Vector2(cos(a), sin(a)) * Iso.tiles(player.rng.randf_range(0.4, 1.0) * float(sd["spread"])))
				var g2 := WeaponAttacks.make_ground(player, w, "heavy", float(sd["skill_mult"]))
				g2.mode = "blast"
				g2.look = "storm"
				g2.radius = float(sd["radius"])
				g2.delay = float(sd["delay"]) + i * float(sd["interval"])
				g2.color = col
				player.spawn(g2, center + off)
		"heavy_shards":
			var n := int(sd["count"])
			var id := player.next_attack_id()
			for i: int in n:
				var a2 := -35.0 + 70.0 * i / maxf(n - 1, 1)
				var pr := WeaponAttacks.make_projectile(player, w, "heavy", float(sd["skill_mult"]), id, player.facing_cart.rotated(deg_to_rad(a2)))
				pr.kind = "orb"
				pr.speed_tiles = float(sd["speed"])
				pr.max_range = float(sd["range"])
				pr.radius_tiles = float(sd["radius"])
				pr.homing_range = float(sd["seek_range"])
				pr.turn_rate = float(sd["turn_rate"])
				player.spawn(pr, player.global_position)


## Alan patlaması: merkezdeki düşmanlara silahın vuruşunun pct katı (ikincil vuruş: kritik yok, yeni kombo yok).
func _burst(w: Weapon, center: Vector2, radius: float, pct: float, from_sky: bool, opts: Dictionary, skip: Node2D = null) -> void:
	var col := Weapon.kind_color(w.element)
	Events.area_pulse.emit(center, radius, col)
	if from_sky:
		Events.chain_zap.emit(center + Vector2(0, -220), center + Vector2(0, -12), col, true)
	var s := player.stats_for(w)
	var o := {"damage_buffs": s.damage_buffs + float(opts.get("damage_buffs", 0.0)),
		"element_bonus": s.element_bonus + float(opts.get("element_bonus", 0.0)),
		"mastery_level": Mastery.level_of(w.type_id)}
	for e: Node2D in player.enemies_in_circle(center, radius):
		if e == skip:
			continue
		var d := Iso.to_cart(e.global_position - center)
		var dmg := HitResolver.secondary_hit(w, e, pct, w.element, o, true, d.normalized() if d.length() > 0.01 else Vector2.RIGHT)
		GameState.record_damage(w.type_id, dmg)
