## LootGenerator — loot üretimi (GDD: Nadirlik ve Efsanevi Silahlar, Zindan, Ekonomi). Saf hesaptır; zar atışları
## verilen RandomNumberGenerator'dan gelir (aynı seed aynı loot).
##   Nadirlik: katın oranları (loot_tables.json). Elit düşman ve gizli oda üst nadirliklerin (Destansı, Efsanevi) şansını
##   ×2 yapar, fark Yaygın'dan düşülür (Yaygın yetmezse — 4. kat — kalan Ender'den). Efsanevi 3. kattan itibaren. 3. ve 4. kat boss'ları en az Destansı düşürür.
##   Silah: tip 12 tipten eşit olasılıkla; element sayısı ve özellik sayısı nadirliğe göre; level katın aralığından.
##   Efsanevi: legendaries.json'daki kayıtlardan biri (tip ve element kayıttan), 1 veya 2 özellik.
##   Düşmeler (economy.json): altın, silah, iksir; sandıkta ayrıca tılsım.
## Kaynak (source): "normal", "elite", "boss", "chest", "secret_room", "merchant".
class_name LootGenerator
extends RefCounted


## Nadirlikler temel hasara göre sıralı (Yaygın → Efsanevi).
static func rarity_order() -> Array:
	var r: Dictionary = DataDB.table("rarities")
	var ids := DataDB.records(r)
	ids.sort_custom(func(a: String, b: String) -> bool: return float(r[a]["base_damage"]) < float(r[b]["base_damage"]))
	return ids


## Kaynağa göre düzeltilmiş nadirlik oranları (toplamı 1).
static func rarity_weights(floor_i: int, source: String) -> Dictionary:
	var lt: Dictionary = DataDB.table("loot_tables")
	var base: Dictionary = lt["floors"][str(floor_i)]["rarity_weights"]
	var order := rarity_order()
	var w := {}
	for r: String in order:
		w[r] = float(base.get(r, 0.0))
	var common: String = order[0]
	# Efsanevi yalnızca belirli kattan itibaren (fark Yaygın'a)
	if floor_i < int(lt["legendary_from_floor"]) and w.has("legendary"):
		w[common] = float(w[common]) + float(w["legendary"])
		w["legendary"] = 0.0
	# Elit ve gizli oda: üst nadirlikler ×2, fark Yaygın'dan; Yaygın yetmezse (4. kat) kalanı Ender'den
	var boost: Dictionary = lt["upper_rarity_boost"]
	if source in (boost["sources"] as Array):
		var extra := 0.0
		for r2: Variant in boost["rarities"]:
			var before := float(w[str(r2)])
			w[str(r2)] = before * float(boost["multiplier"])
			extra += float(w[str(r2)]) - before
		for r6: String in order:
			if extra <= 0.0 or r6 in (boost["rarities"] as Array):
				continue
			var take := minf(float(w[r6]), extra)
			w[r6] = float(w[r6]) - take
			extra -= take
	# Boss: en az belirli nadirlik (alttakiler sıfırlanır, kalanlar yeniden ölçeklenir)
	if source == "boss" and (lt["boss_min_rarity"] as Dictionary).has(str(floor_i)):
		var min_r := str(lt["boss_min_rarity"][str(floor_i)])
		for r3: String in order:
			if r3 == min_r:
				break
			w[r3] = 0.0
	var total := 0.0
	for r4: String in order:
		total += float(w[r4])
	if total > 0.0:
		for r5: String in order:
			w[r5] = float(w[r5]) / total
	return w


static func roll_rarity(floor_i: int, source: String, rng: RandomNumberGenerator) -> String:
	var w := rarity_weights(floor_i, source)
	var x := rng.randf()
	var acc := 0.0
	var last := ""
	for r: String in rarity_order():
		if float(w[r]) <= 0.0:
			continue
		acc += float(w[r])
		last = r
		if x < acc:
			return r
	return last


## Katın silah leveli aralığından eşit olasılıkla bir level (1. kat 1, 2. kat 10, 3. kat 25-40, 4. kat 50).
static func roll_level(floor_i: int, rng: RandomNumberGenerator) -> int:
	var wl: Array = DataDB.table("loot_tables")["floors"][str(floor_i)]["weapon_level"]
	return rng.randi_range(int(wl[0]), int(wl[1]))


## Kattan silah: nadirlik (verilmediyse kaynağa göre zar), tip, element, özellik, level.
static func make_weapon(floor_i: int, source: String, rng: RandomNumberGenerator, rarity: String = "") -> Weapon:
	var r := rarity if rarity != "" else roll_rarity(floor_i, source, rng)
	return weapon_of_rarity(r, roll_level(floor_i, rng), rng)


static func weapon_of_rarity(rarity: String, lvl: int, rng: RandomNumberGenerator) -> Weapon:
	var rd: Dictionary = DataDB.table("rarities")[rarity]
	var trait_range: Array = rd["traits"]
	var n_traits := rng.randi_range(int(trait_range[0]), int(trait_range[1]))
	var traits := random_traits(n_traits, [], rng)
	var legendaries: Array = DataDB.table("legendaries")["weapons"]
	if bool(rd["unique_passive"]) and not legendaries.is_empty():
		var rec: Dictionary = legendaries[rng.randi_range(0, legendaries.size() - 1)]
		return Weapon.make_legendary(str(rec["id"]), traits, lvl)
	var types := DataDB.records(DataDB.table("weapon_types"))
	var type_id: String = types[rng.randi_range(0, types.size() - 1)]
	var element := DamageCalc.PHYSICAL
	if int(rd["elements"]) > 0:
		element = random_element(rng, "")
	return Weapon.make(type_id, rarity, element, traits, lvl)


static func random_element(rng: RandomNumberGenerator, exclude: String) -> String:
	var els: Array = (DataDB.table("elements")["elements"] as Dictionary).keys()
	els.erase(exclude)
	return els[rng.randi_range(0, els.size() - 1)]


## count farklı özellik (exclude'dakiler hariç).
static func random_traits(count: int, exclude: Array, rng: RandomNumberGenerator) -> Array[String]:
	var pool := DataDB.records(DataDB.table("traits"))
	for e: Variant in exclude:
		pool.erase(str(e))
	var out: Array[String] = []
	for i: int in mini(count, pool.size()):
		var idx := rng.randi_range(0, pool.size() - 1)
		out.append(str(pool[idx]))
		pool.remove_at(idx)
	return out


## Sahip olunmayan (exclude dışındaki) rastgele tılsım; hepsi varsa null.
static func roll_talisman(rng: RandomNumberGenerator, exclude: Array = []) -> Talisman:
	var pool := Talisman.all_ids()
	for e: Variant in exclude:
		pool.erase(str(e))
	if pool.is_empty():
		return null
	return Talisman.make(str(pool[rng.randi_range(0, pool.size() - 1)]))


## Altın miktarı: economy.gold[key] aralığı × katın altın çarpanı.
static func gold_amount(floor_i: int, key: String, rng: RandomNumberGenerator) -> int:
	var ec: Dictionary = DataDB.table("economy")
	var g: Array = ec["gold"][key]
	return roundi(rng.randi_range(int(g[0]), int(g[1])) * gold_mult(floor_i))


static func gold_mult(floor_i: int) -> float:
	return float(DataDB.table("economy")["floor_gold_mult"][str(clampi(floor_i, 1, 4))])


## Düşmanın düşürdükleri. kind: "normal", "elite", "boss".
## Döndürür: [{"kind": "gold", "amount": int} | {"kind": "weapon", "item": Weapon} | {"kind": "potion"}]
static func enemy_drops(floor_i: int, kind: String, rng: RandomNumberGenerator) -> Array:
	var d: Dictionary = DataDB.table("economy")["drops"]
	var out: Array = [{"kind": "gold", "amount": gold_amount(floor_i, kind, rng)}]
	var weapons := 0
	var potion_chance := 0.0
	match kind:
		"normal":
			weapons = 1 if rng.randf() < float(d["normal_weapon_chance"]) else 0
			potion_chance = float(d["normal_potion_chance"])
		"elite":
			weapons = int(d["elite_weapons"])
			potion_chance = float(d["elite_potion_chance"])
		"boss":
			weapons = int(d["boss_weapons"])
			potion_chance = float(d["boss_potion_chance"])
	for i: int in weapons:
		out.append({"kind": "weapon", "item": make_weapon(floor_i, kind, rng)})
	if rng.randf() < potion_chance:
		out.append({"kind": "potion"})
	return out


## Sandık: altın + 1 silah (ya da %20 ihtimalle sahip olunmayan bir tılsım). Gizli oda sandığı üst nadirlik ×2.
static func chest_drops(floor_i: int, secret: bool, rng: RandomNumberGenerator, owned_talismans: Array = []) -> Array:
	var d: Dictionary = DataDB.table("economy")["drops"]
	var out: Array = [{"kind": "gold", "amount": gold_amount(floor_i, "secret_chest" if secret else "chest", rng)}]
	for i: int in int(d["chest_weapons"]):
		if rng.randf() < float(d["chest_talisman_chance"]):
			var t := roll_talisman(rng, owned_talismans)
			if t != null:
				out.append({"kind": "talisman", "item": t})
				owned_talismans = owned_talismans + [t.id]
				continue
		out.append({"kind": "weapon", "item": make_weapon(floor_i, "secret_room" if secret else "chest", rng)})
	return out


## Tüccarın tezgâhı: katın tablosundan silahlar ve sahip olunmayan tılsım(lar).
static func merchant_stock(floor_i: int, rng: RandomNumberGenerator, owned_talismans: Array = []) -> Array:
	var m: Dictionary = DataDB.table("economy")["merchant"]
	var out: Array = []
	for i: int in int(m["weapons"]):
		out.append(make_weapon(floor_i, "merchant", rng))
	var owned := owned_talismans.duplicate()
	for j: int in int(m["talismans"]):
		var t := roll_talisman(rng, owned)
		if t != null:
			out.append(t)
			owned.append(t.id)
	return out


## Irkın başlangıç silahı: kendi ailesinden Yaygın, level 1 (economy.start_weapons).
static func start_weapon(race_id: String) -> Weapon:
	return Weapon.make(str(DataDB.table("economy")["start_weapons"][race_id]), "common")
