## Mastery — silah tipi ustalığı (GDD: Silah Tipi Ustalığı). Oyunda kalıcı olan tek ilerleme; SaveManager.mastery'de
## {"silah tipi": {"level", "xp"}} olarak saklanır. Maks level 12; her silah tipi level 1'den başlar.
## Bonuslar level başına: hasar +%5, saldırı hızı +%3,33, menzil +%1,67, element +%2,5 (level 12'de 60/40/20/30).
## Hasar bonusu hasar formülündeki U terimidir (DamageCalc.mastery_bonus); diğerleri RaceStats'a eklenir.
## Run sonu: XP = referans maç XP'si (100) × derinlik çarpanı; run boyunca verilen hasarın silah tiplerine göre yüzdesiyle
## bölünür (GameState.damage_by_weapon_type).
class_name Mastery
extends RefCounted

const BONUS_STATS := ["damage", "attack_speed", "attack_range", "element_damage"]


static func _cfg() -> Dictionary:
	return DataDB.get_value("progression", "mastery")


static func max_level() -> int:
	return int(_cfg()["max_level"])


static func start_level() -> int:
	return int(_cfg()["start_level"])


## Silah tipinin kayıttaki ustalık leveli (kayıt yoksa başlangıç leveli). save: SaveManager (testte başka örnek).
static func level_of(type_id: String, save: Node = null) -> int:
	var sm: Node = save if save else SaveManager
	var m: Dictionary = sm.get("mastery")
	if not m.has(type_id):
		return start_level()
	return clampi(int((m[type_id] as Dictionary).get("level", start_level())), start_level(), max_level())


## Leveldeki bir bonus (stat: damage, attack_speed, attack_range, element_damage).
static func bonus(level: int, stat: String) -> float:
	var c := _cfg()
	return float(c["bonus_at_max"][stat]) / float(c["max_level"]) * clampi(level, 0, int(c["max_level"]))


## RaceStats'a eklenen ustalık bonusları (hasar hariç: o U terimi olarak ayrı çarpılır).
static func stat_bonuses(level: int) -> Dictionary:
	return {"attack_speed": bonus(level, "attack_speed"), "attack_range": bonus(level, "attack_range"),
		"element_damage": bonus(level, "element_damage")}


## Sonraki levele gereken XP (maks levelde 0).
static func xp_to_next(level: int) -> float:
	var table: Array = _cfg()["xp_to_next"]
	var i := level - start_level()
	if level >= max_level() or i < 0 or i >= table.size():
		return 0.0
	return float(table[i])


## Kayda XP ekler ({"level", "xp"} yerinde değişir); atlanan level sayısını döndürür. Maks levelde XP birikmez.
static func add_xp(entry: Dictionary, amount: float) -> int:
	var lvl := clampi(int(entry.get("level", start_level())), start_level(), max_level())
	var x := float(entry.get("xp", 0.0)) + maxf(amount, 0.0)
	var gained := 0
	while lvl < max_level() and x >= xp_to_next(lvl) - 0.0001:
		x -= xp_to_next(lvl)
		lvl += 1
		gained += 1
	if lvl >= max_level():
		x = 0.0
	entry["level"] = lvl
	entry["xp"] = maxf(x, 0.0)
	return gained


## Derinlik çarpanının anahtarı: zafer, "2. katı bitirme" (2. kat boss'u kesilip 3. kata inilmeden ölüm) ya da ölünen kat.
static func depth_key(floor_reached: int, victory: bool, floor2_cleared: bool) -> String:
	if victory:
		return "victory"
	if floor_reached == 2 and floor2_cleared:
		return "clear_floor_2"
	return "death_floor_%d" % clampi(floor_reached, 1, 4)


static func depth_multiplier(key: String) -> float:
	return float((_cfg()["depth_multipliers"] as Dictionary).get(key, 0.0))


## Run'ın toplam ustalık XP'si.
static func run_xp(key: String) -> float:
	return float(_cfg()["reference_match_xp"]) * depth_multiplier(key)


## Toplam XP'yi hasar payına göre böler: {silah tipi: xp}. Hasar yoksa boş.
static func split(damage_by_type: Dictionary, total_xp: float) -> Dictionary:
	var total := 0.0
	for k: Variant in damage_by_type.keys():
		total += maxf(float(damage_by_type[k]), 0.0)
	var out := {}
	if total <= 0.0:
		return out
	for k: Variant in damage_by_type.keys():
		var d := maxf(float(damage_by_type[k]), 0.0)
		if d > 0.0:
			out[str(k)] = total_xp * d / total
	return out


## Run sonunu işler: XP'yi silah tiplerine dağıtır ve save.mastery'yi günceller (kaydetmez; çağıran save_game yapar).
## Döndürür: hasar payına göre sıralı [{"type", "share", "xp", "from_level", "to_level", "xp_now", "xp_next"}].
static func apply_run(damage_by_type: Dictionary, key: String, save: Node = null) -> Array:
	var sm: Node = save if save else SaveManager
	var m: Dictionary = sm.get("mastery")
	var total_xp := run_xp(key)
	var parts := split(damage_by_type, total_xp)
	var dmg_total := 0.0
	for k: Variant in damage_by_type.keys():
		dmg_total += maxf(float(damage_by_type[k]), 0.0)
	var out: Array = []
	for t: String in parts.keys():
		if not m.has(t):
			m[t] = {"level": start_level(), "xp": 0.0}
		var entry: Dictionary = m[t]
		var before := level_of(t, sm)
		add_xp(entry, float(parts[t]))
		out.append({"type": t, "share": float(damage_by_type[t]) / dmg_total, "xp": float(parts[t]),
			"from_level": before, "to_level": int(entry["level"]), "xp_now": float(entry["xp"]), "xp_next": xp_to_next(int(entry["level"]))})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["share"]) > float(b["share"]))
	return out
