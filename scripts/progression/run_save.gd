## RunSave — v0.11.1 run kaydı (kaldığın yerden devam). Aktif run'ın GameState'i ve eşyaları sözlüğe çevrilir, geri
## kurulur ve doğrulanır. Dosyayı SaveManager yazar (user://run.json); katın durumunu (temizlenen odalar, sandıklar,
## tüccar, yerdeki eşyalar, oyuncunun yeri) DungeonRun toplar ve geri kurar (run_snapshot / load_run). Kat haritası
## kaydedilmez: run seed'inden aynısı yeniden üretilir.
## Ölüm run'ı bitirir: kayıt yalnızca oyunu kapatıp sonra sürdürmek içindir; ölüm, zafer ve run'ı bırakmak kaydı siler.
## Kayıtlı run varken yeni oyun başlatılırsa o run bırakılmış sayılır (discard_saved: ustalık XP'si o kattaki ölüm
## çarpanıyla işlenir).
class_name RunSave
extends RefCounted

const VERSION := 1


static func item_to_dict(item: Variant) -> Variant:
	if item is Weapon:
		var w := item as Weapon
		return {"kind": "weapon", "type": w.type_id, "rarity": w.rarity_id, "element": w.element, "traits": Array(w.traits),
			"level": w.level, "xp": w.xp, "legendary": w.legendary_id, "rerolls": w.rerolls}
	if item is Talisman:
		return {"kind": "talisman", "id": (item as Talisman).id}
	return null


## Sözlükten eşya. Tanınmayan (verisi silinmiş tip, element, özellik…) ya da bozuk kayıt null döner.
static func item_from_dict(v: Variant) -> Variant:
	if typeof(v) != TYPE_DICTIONARY:
		return null
	var d: Dictionary = v
	match str(d.get("kind", "")):
		"weapon":
			var type := str(d.get("type", ""))
			var rarity := str(d.get("rarity", ""))
			var element := str(d.get("element", DamageCalc.PHYSICAL))
			if not DataDB.table("weapon_types").has(type) or not DataDB.table("rarities").has(rarity):
				return null
			if element != DamageCalc.PHYSICAL and not (DataDB.table("elements")["elements"] as Dictionary).has(element):
				return null
			var traits: Array[String] = []
			for t: Variant in d.get("traits", []):
				if not DataDB.table("traits").has(str(t)):
					return null
				traits.append(str(t))
			var w := Weapon.make(type, rarity, element, traits, maxi(int(d.get("level", 1)), 1))
			w.xp = maxf(float(d.get("xp", 0.0)), 0.0)
			w.rerolls = maxi(int(d.get("rerolls", 0)), 0)
			var leg := str(d.get("legendary", ""))
			if leg != "":
				if Weapon.legendary_record(leg).is_empty():
					return null
				w.legendary_id = leg
			return w
		"talisman":
			var id := str(d.get("id", ""))
			return Talisman.make(id) if id in Talisman.all_ids() else null
	return null


static func items_to_array(items: Array) -> Array:
	var out: Array = []
	for it: Variant in items:
		out.append(item_to_dict(it))
	return out


## Kayıttaki eşya listesi; tanınmayanlar atlanır (tüccarın tezgâhı).
static func items_from_array(v: Variant) -> Array:
	var out: Array = []
	for d: Variant in (v if typeof(v) == TYPE_ARRAY else []):
		var it: Variant = item_from_dict(d)
		if it != null:
			out.append(it)
	return out


## Aktif run'ın GameState'i (envanter dahil).
static func capture_state() -> Dictionary:
	var inv := GameState.inventory
	var slots := {}
	for s: String in Inventory.SLOT_NAMES:
		slots[s] = item_to_dict(inv.slots[s])
	return {
		"race": GameState.race_id, "level": GameState.level, "xp": GameState.xp, "floor": GameState.floor_index,
		"seed": str(GameState.run_seed), "buffs": GameState.buffs.duplicate(), "special_effects": Array(GameState.special_effects),
		"damage_by_weapon_type": GameState.damage_by_weapon_type.duplicate(), "pending_rewards": Array(GameState.pending_rewards),
		"bosses_killed": Array(GameState.bosses_killed), "floor2_cleared": GameState.floor2_cleared,
		"second_chance_used": GameState.second_chance_used, "kills": GameState.kills, "xp_earned": GameState.xp_earned,
		"inventory": {"slots": slots, "bag": items_to_array(inv.bag), "gold": inv.gold, "potions": inv.potions,
			"potion_max": inv.potion_max, "active_slot": inv.active_slot},
	}


## GameState'i kayıttan kurar (önce sıfırlar). Tanınmayan eşyalar düşer; aktif silah kalmazsa ırkın başlangıç silahı verilir.
static func apply_state(s: Dictionary) -> void:
	GameState.reset_run()
	GameState.in_run = true
	GameState.race_id = str(s["race"])
	GameState.level = clampi(int(s.get("level", 1)), 1, Leveling.max_level())
	GameState.xp = maxf(float(s.get("xp", 0.0)), 0.0)
	GameState.floor_index = clampi(int(s.get("floor", 1)), 1, 4)
	GameState.run_seed = str(s.get("seed", "0")).to_int()
	for k: Variant in (s.get("buffs", {}) as Dictionary).keys():
		GameState.buffs[str(k)] = float(s["buffs"][k])
	for e: Variant in s.get("special_effects", []):
		GameState.special_effects.append(str(e))
	for k2: Variant in (s.get("damage_by_weapon_type", {}) as Dictionary).keys():
		GameState.damage_by_weapon_type[str(k2)] = float(s["damage_by_weapon_type"][k2])
	for r: Variant in s.get("pending_rewards", []):
		GameState.pending_rewards.append(str(r))
	for b: Variant in s.get("bosses_killed", []):
		GameState.bosses_killed.append(str(b))
	GameState.floor2_cleared = bool(s.get("floor2_cleared", false))
	GameState.second_chance_used = bool(s.get("second_chance_used", false))
	GameState.kills = maxi(int(s.get("kills", 0)), 0)
	GameState.xp_earned = maxf(float(s.get("xp_earned", 0.0)), 0.0)
	var inv := GameState.inventory
	var si: Dictionary = s.get("inventory", {})
	var slots: Dictionary = si.get("slots", {})
	for sl: String in Inventory.SLOT_NAMES:
		var item: Variant = item_from_dict(slots.get(sl))
		inv.slots[sl] = item if inv.can_hold(Inventory.slot_ref(sl), item, GameState.level) == "" else null
	var bag: Array = si.get("bag", [])
	for i: int in mini(inv.bag.size(), bag.size()):
		inv.bag[i] = item_from_dict(bag[i])
	inv.gold = maxi(int(si.get("gold", 0)), 0)
	inv.potion_max = maxi(int(si.get("potion_max", inv.potion_max)), 0)
	inv.potions = clampi(int(si.get("potions", 0)), 0, inv.potion_max)
	inv.active_slot = str(si.get("active_slot", "active_1")) if str(si.get("active_slot", "")) in Inventory.ACTIVE_SLOTS else "active_1"
	if inv.active_weapons().is_empty():
		inv.slots["active_1"] = LootGenerator.start_weapon(GameState.race_id)
	inv._fix_active_slot()


## Kayıt kurulabilir mi? "" = evet, değilse nedeni (SaveManager bozuk sayar).
static func check(d: Dictionary) -> String:
	if int(d.get("version", -1)) != VERSION:
		return "bilinmeyen kayıt sürümü"
	for k: String in ["state", "run", "player", "floor"]:
		if typeof(d.get(k)) != TYPE_DICTIONARY:
			return "'%s' eksik" % k
	var s: Dictionary = d["state"]
	if not DataDB.table("races").has(str(s.get("race", ""))) or str(s.get("race", "")).begins_with("_"):
		return "bilinmeyen ırk"
	if not int(s.get("floor", 0)) in [1, 2, 3, 4]:
		return "kat 1-4 olmalı"
	if typeof(s.get("inventory")) != TYPE_DICTIONARY or typeof((s["inventory"] as Dictionary).get("slots")) != TYPE_DICTIONARY:
		return "envanter eksik"
	return ""


## Ana menüde YÜKLE'nin yanında görünen kısa bilgi: "Warrior · 2. kat · Level 18".
static func describe(d: Dictionary) -> String:
	var s: Dictionary = d.get("state", {})
	var race := str(s.get("race", ""))
	var rname := str((DataDB.table("races").get(race, {}) as Dictionary).get("name", race))
	return "%s · %d. kat · Level %d" % [rname, int(s.get("floor", 1)), int(s.get("level", 1))]


## Kayıtlı run'ı bırakır (yeni oyun başlarken): ustalık XP'si o kattaki ölüm çarpanıyla işlenir ve kaydedilir, run kaydı silinir.
static func discard_saved() -> void:
	var d := SaveManager.read_run()
	SaveManager.clear_run()
	if d.is_empty():
		return
	var s: Dictionary = d["state"]
	var dmg := {}
	for k: Variant in (s.get("damage_by_weapon_type", {}) as Dictionary).keys():
		dmg[str(k)] = float(s["damage_by_weapon_type"][k])
	var key := Mastery.depth_key(int(s["floor"]), false, bool(s.get("floor2_cleared", false)))
	Mastery.apply_run(dmg, key)
	SaveManager.save_game()
	print("[Kayıt] Kayıtlı run bırakıldı (%s, %s)" % [describe(d), key])
