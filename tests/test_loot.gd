## Aşama 5 — LootGenerator: nadirlik oranları (kabul: 10.000 düşüşlük simülasyonda tabloya ±%1), elit/gizli oda
## üst nadirlik ×2, efsanevi 3. kattan, boss en az Destansı, silah alanları, düşmeler, sandık, tüccar tezgâhı.
extends "res://tests/test_case.gd"

const N := 10000
const TOL := 0.01


func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


func _freqs(floor_i: int, source: String, seed_v: int) -> Dictionary:
	var rng := _rng(seed_v)
	var counts := {}
	for r: String in LootGenerator.rarity_order():
		counts[r] = 0
	for i: int in N:
		var w := LootGenerator.make_weapon(floor_i, source, rng)
		counts[w.rarity_id] = int(counts[w.rarity_id]) + 1
	var out := {}
	for r2: String in counts.keys():
		out[r2] = float(counts[r2]) / N
	return out


## Aşama 5 kabulü: her katta 10.000 düşüşte oranlar tabloya ±%1 uyar.
func test_rarity_rates_match_table_10000_drops() -> void:
	for f: int in range(1, 5):
		var table: Dictionary = DataDB.table("loot_tables")["floors"][str(f)]["rarity_weights"]
		var got := _freqs(f, "normal", 1000 + f)
		for r: String in table.keys():
			assert_almost(float(got[r]), float(table[r]), TOL, "kat %d %s oranı" % [f, r])


## Elit düşman ve gizli oda: Destansı ve Efsanevi ×2, fark Yaygın'dan (örn. 3. kat: %8 / %38 / %44 / %10);
## Yaygın yetmezse kalan Ender'den (4. kat: %0 / %16 / %64 / %20).
func test_elite_and_secret_double_upper_rarities() -> void:
	for src: String in ["elite", "secret_room"]:
		for f: int in range(1, 5):
			var t: Dictionary = DataDB.table("loot_tables")["floors"][str(f)]["rarity_weights"]
			var want := {"rare": float(t["rare"]), "epic": float(t["epic"]) * 2.0, "legendary": float(t["legendary"]) * 2.0}
			want["common"] = 1.0 - float(want["rare"]) - float(want["epic"]) - float(want["legendary"])
			if float(want["common"]) < 0.0:
				# Yaygın yetmezse kalan Ender'den (4. kat: %0 / %16 / %64 / %20)
				want["rare"] = float(want["rare"]) + float(want["common"])
				want["common"] = 0.0
			var w := LootGenerator.rarity_weights(f, src)
			for r: String in want.keys():
				assert_almost(float(w[r]), float(want[r]), 0.0001, "%s kat %d %s ağırlığı" % [src, f, r])
			var got := _freqs(f, src, 2000 + f)
			for r2: String in want.keys():
				assert_almost(float(got[r2]), float(want[r2]), TOL, "%s kat %d %s oranı (10.000 düşüş)" % [src, f, r2])
	# Sandık ve tüccar normal tabloyu kullanır
	assert_eq(LootGenerator.rarity_weights(3, "chest"), LootGenerator.rarity_weights(3, "normal"))


func test_no_legendary_before_floor_3() -> void:
	for f: int in [1, 2]:
		for src: String in ["normal", "elite", "secret_room", "boss", "chest"]:
			assert_eq(float(LootGenerator.rarity_weights(f, src)["legendary"]), 0.0, "kat %d %s efsanevi yok" % [f, src])
	assert_true(float(LootGenerator.rarity_weights(3, "normal")["legendary"]) > 0.0, "3. katta efsanevi var")


## 3. ve 4. kat boss'ları en az Destansı düşürür; 1-2. kat boss'ları normal tabloyla.
func test_boss_min_rarity() -> void:
	var rng := _rng(3)
	for f: int in [3, 4]:
		var epic := 0
		var leg := 0
		for i: int in 3000:
			var w := LootGenerator.make_weapon(f, "boss", rng)
			assert_true(w.rarity_id in ["epic", "legendary"], "kat %d boss en az Destansı (bulunan %s)" % [f, w.rarity_id])
			if w.rarity_id == "epic":
				epic += 1
			else:
				leg += 1
		var t: Dictionary = DataDB.table("loot_tables")["floors"][str(f)]["rarity_weights"]
		var want_leg := float(t["legendary"]) / (float(t["epic"]) + float(t["legendary"]))
		assert_almost(float(leg) / 3000.0, want_leg, 0.02, "kat %d boss efsanevi payı" % f)
	assert_eq(LootGenerator.rarity_weights(1, "boss"), LootGenerator.rarity_weights(1, "normal"), "1. kat boss'u normal tablo")


## Nadirliğe göre element ve özellik sayısı, katın silah leveli aralığı, 12 tipin hepsi çıkar.
func test_weapon_fields_by_rarity_and_floor() -> void:
	var rng := _rng(4)
	var types_seen := {}
	var elements_seen := {}
	for f: int in range(1, 5):
		var lv: Array = DataDB.table("loot_tables")["floors"][str(f)]["weapon_level"]
		for r: String in LootGenerator.rarity_order():
			var rd: Dictionary = DataDB.table("rarities")[r]
			for i: int in 200:
				var w := LootGenerator.make_weapon(f, "normal", rng, r)
				var tag := "kat %d %s" % [f, r]
				assert_eq(w.rarity_id, r, tag)
				assert_true(w.level >= int(lv[0]) and w.level <= int(lv[1]), "%s level %d aralıkta" % [tag, w.level])
				assert_eq(1 if w.is_elemental() else 0, int(rd["elements"]), tag + ": element sayısı")
				var tr: Array = rd["traits"]
				assert_true(w.traits.size() >= int(tr[0]) and w.traits.size() <= int(tr[1]), tag + ": özellik sayısı")
				var uniq := {}
				for t: String in w.traits:
					uniq[t] = true
				assert_eq(uniq.size(), w.traits.size(), tag + ": özellikler farklı")
				assert_eq(w.is_legendary(), r == "legendary", tag + ": efsanevi kaydı")
				types_seen[w.type_id] = true
				elements_seen[w.element] = true
	assert_eq(types_seen.size(), 12, "12 silah tipinin hepsi düşer")
	assert_eq(elements_seen.size(), 7, "6 element + fiziksel")


func test_floor_3_levels_spread_25_to_40() -> void:
	var rng := _rng(5)
	var lo := 99
	var hi := 0
	for i: int in 2000:
		var l := LootGenerator.roll_level(3, rng)
		lo = mini(lo, l)
		hi = maxi(hi, l)
	assert_eq(lo, 25)
	assert_eq(hi, 40)
	assert_eq(LootGenerator.roll_level(1, rng), 1)
	assert_eq(LootGenerator.roll_level(2, rng), 10)
	assert_eq(LootGenerator.roll_level(4, rng), 50)


func test_same_seed_same_loot() -> void:
	var a := _rng(77)
	var b := _rng(77)
	for i: int in 50:
		var wa := LootGenerator.make_weapon(3, "elite", a)
		var wb := LootGenerator.make_weapon(3, "elite", b)
		assert_eq([wa.type_id, wa.rarity_id, wa.element, wa.traits, wa.level, wa.legendary_id],
			[wb.type_id, wb.rarity_id, wb.element, wb.traits, wb.level, wb.legendary_id], "aynı seed aynı silah")


## Efsanevi silahlar: her tipten bir tane, adı/elementi/pasifi/skill'i kayıttan, 1-2 özellik.
func test_legendaries() -> void:
	var recs: Array = DataDB.table("legendaries")["weapons"]
	assert_eq(recs.size(), 12, "ilk sürümde 12 efsanevi")
	var types := {}
	for d: Dictionary in recs:
		types[d["type"]] = true
		var w := Weapon.make_legendary(str(d["id"]), [], 30)
		assert_eq(w.display_name(), str(d["name"]))
		assert_eq(w.element, str(d["element"]))
		assert_eq(w.rarity_id, "legendary")
		assert_true(not w.passive_data().is_empty() and not w.skill_data().is_empty(), "%s pasif ve skill" % d["name"])
		var desc := WeaponInfo.fill(str(w.passive_data()["description"]), w.passive_data(), w.element)
		assert_true(not "{" in desc, "%s pasif açıklaması dolu: %s" % [d["name"], desc])
		var sdesc := WeaponInfo.fill(str(w.skill_data()["description"]), w.skill_data(), w.element)
		assert_true(not "{" in sdesc, "%s skill açıklaması dolu: %s" % [d["name"], sdesc])
	assert_eq(types.size(), 12, "her silah tipinden bir efsanevi")
	var rng := _rng(6)
	var seen := {}
	for i: int in 400:
		var lw := LootGenerator.make_weapon(4, "normal", rng, "legendary")
		assert_true(lw.traits.size() >= 1 and lw.traits.size() <= 2, "efsanevi 1-2 özellik")
		seen[lw.legendary_id] = true
	assert_eq(seen.size(), 12, "12 efsanevinin hepsi düşebilir")


## Düşmeler: altın her zaman (kat çarpanıyla), normal düşmanda %8 silah, elitte 1, boss'ta 2.
func test_enemy_drops() -> void:
	var rng := _rng(8)
	var ec: Dictionary = DataDB.table("economy")
	var weapons := 0
	var potions := 0
	for i: int in N:
		var got := LootGenerator.enemy_drops(2, "normal", rng)
		assert_eq(str(got[0]["kind"]), "gold")
		var g: Array = ec["gold"]["normal"]
		var amt := int(got[0]["amount"])
		assert_true(amt >= int(g[0]) * 2 and amt <= int(g[1]) * 2, "2. kat normal altın ×2 aralıkta (%d)" % amt)
		for d: Dictionary in got:
			if d["kind"] == "weapon":
				weapons += 1
			elif d["kind"] == "potion":
				potions += 1
	assert_almost(float(weapons) / N, float(ec["drops"]["normal_weapon_chance"]), TOL, "normal düşman silah oranı")
	assert_almost(float(potions) / N, float(ec["drops"]["normal_potion_chance"]), 0.005, "normal düşman iksir oranı")
	for i2: int in 50:
		var e := LootGenerator.enemy_drops(1, "elite", rng).filter(func(d: Dictionary) -> bool: return d["kind"] == "weapon")
		assert_eq(e.size(), int(ec["drops"]["elite_weapons"]), "elit silah sayısı")
		var b := LootGenerator.enemy_drops(4, "boss", rng).filter(func(d: Dictionary) -> bool: return d["kind"] == "weapon")
		assert_eq(b.size(), int(ec["drops"]["boss_weapons"]), "boss silah sayısı")
		for d2: Dictionary in b:
			assert_true((d2["item"] as Weapon).rarity_id in ["epic", "legendary"], "4. kat boss en az Destansı")


## Sandık: altın + silah ya da (%20) sahip olunmayan tılsım; gizli oda sandığı daha çok altın.
func test_chest_drops() -> void:
	var rng := _rng(9)
	var talismans := 0
	for i: int in 2000:
		var got := LootGenerator.chest_drops(1, false, rng, ["blood_stone"])
		assert_eq(got.size(), 2, "altın + 1 eşya")
		assert_eq(str(got[0]["kind"]), "gold")
		if got[1]["kind"] == "talisman":
			talismans += 1
			assert_true((got[1]["item"] as Talisman).id != "blood_stone", "sahip olunan tılsım tekrar düşmez")
	assert_almost(float(talismans) / 2000.0, float(DataDB.table("economy")["drops"]["chest_talisman_chance"]), 0.03)
	var all_owned := LootGenerator.chest_drops(1, false, rng, Talisman.all_ids())
	assert_eq(str(all_owned[1]["kind"]), "weapon", "tüm tılsımlar varsa silah")
	var sg: Array = DataDB.table("economy")["gold"]["secret_chest"]
	var s := LootGenerator.chest_drops(3, true, rng)
	assert_true(int(s[0]["amount"]) >= int(sg[0]) * 3, "gizli oda sandığı altını")


func test_merchant_stock_and_start_weapons() -> void:
	var rng := _rng(10)
	var st := LootGenerator.merchant_stock(2, rng, [])
	var m: Dictionary = DataDB.table("economy")["merchant"]
	assert_eq(st.size(), int(m["weapons"]) + int(m["talismans"]))
	assert_true(st[0] is Weapon and st[st.size() - 1] is Talisman)
	assert_eq((st[0] as Weapon).level, 10, "2. kat tüccarı level 10 silah")
	assert_eq(LootGenerator.merchant_stock(1, rng, Talisman.all_ids()).size(), int(m["weapons"]), "tılsımların hepsi varsa tılsım yok")
	for race: String in ["warrior", "ghost", "archer", "magical"]:
		var w := LootGenerator.start_weapon(race)
		assert_eq(w.family(), race, "%s kendi ailesinden başlar" % race)
		assert_eq(w.rarity_id, "common")
		assert_eq(w.level, 1)
