## Weapon — bir silah örneği: tip, nadirlik, element, özellikler, level ve XP.
## LootGenerator üretir (Aşama 5); test odası ve hata ayıklama menüsü elle kurar.
## Level: silah statları her 5 levelde +%5 (DamageCalc.weapon_level_ratio). Oyuncunun levelinden yüksek silah kilitlidir
## (aktif slota konamaz). XP eğrisi oyuncununkiyle aynıdır: sonraki levele 100 + 20 × level (progression.player).
## Efsanevi silahın adı, elementi, pasifi ve sağ tık eki legendaries.json'daki kaydından gelir (legendary_id).
class_name Weapon
extends RefCounted

var type_id: String = "sword"
var rarity_id: String = "common"
var element: String = DamageCalc.PHYSICAL   ## element id ya da "physical" (yaygın silah)
var traits: Array[String] = []
var level: int = 1
var xp: float = 0.0                          ## bu leveldeki XP (sonraki levele xp_to_next)
var legendary_id: String = ""                ## efsanevi silahın kaydı (boşsa efsanevi değil)
var rerolls: int = 0                         ## demircide yeniden çekme sayısı (her biri fiyatı artırır)


static func make(p_type: String, p_rarity: String, p_element: String = DamageCalc.PHYSICAL, p_traits: Array[String] = [], p_level: int = 1) -> Weapon:
	var w := Weapon.new()
	w.type_id = p_type
	w.rarity_id = p_rarity
	w.element = p_element if p_element != "" else DamageCalc.PHYSICAL
	w.traits = p_traits
	w.level = p_level
	return w


## Efsanevi kayıttan silah (tip ve element kayıttan, özellikler dışarıdan).
static func make_legendary(legendary_id_: String, p_traits: Array[String], p_level: int) -> Weapon:
	var d := legendary_record(legendary_id_)
	var w := make(str(d["type"]), "legendary", str(d["element"]), p_traits, p_level)
	w.legendary_id = legendary_id_
	return w


static func legendary_record(id: String) -> Dictionary:
	for d: Dictionary in DataDB.table("legendaries")["weapons"]:
		if str(d["id"]) == id:
			return d
	return {}


func is_legendary() -> bool:
	return legendary_id != ""


func legendary_data() -> Dictionary:
	return legendary_record(legendary_id) if is_legendary() else {}


## Efsanevi pasifin şablon sayıları ({} = pasif yok).
func passive_data() -> Dictionary:
	var d := legendary_data()
	if d.is_empty():
		return {}
	var p: Dictionary = (DataDB.table("legendaries")["passive_templates"][str(d["passive"])] as Dictionary).duplicate()
	p["id"] = str(d["passive"])
	return p


## Efsanevi sağ tık ekinin şablon sayıları ({} = yok).
func skill_data() -> Dictionary:
	var d := legendary_data()
	if d.is_empty():
		return {}
	var s: Dictionary = (DataDB.table("legendaries")["skill_templates"][str(d["skill"])] as Dictionary).duplicate()
	s["id"] = str(d["skill"])
	return s


func type_data() -> Dictionary:
	return DataDB.table("weapon_types")[type_id]


## Silah ailesi: warrior, ghost, archer, magical (ırk-silah matrisi buna göre).
func family() -> String:
	return str(type_data()["family"])


func base_damage() -> float:
	return float(DataDB.table("rarities")[rarity_id]["base_damage"])


func has_trait(trait_id: String) -> bool:
	return trait_id in traits


func is_elemental() -> bool:
	return element != DamageCalc.PHYSICAL


## Oyuncunun levelinden yüksek silah kilitlidir: aktif slota konamaz (Rezonans ya da Esnek slota konabilir).
func is_locked(player_level: int) -> bool:
	return level > player_level


## Sonraki levele gereken XP (oyuncununkiyle aynı eğri).
static func xp_to_next(lvl: int) -> float:
	var p: Dictionary = DataDB.get_value("progression", "player")
	return float(p["xp_base"]) + float(p["xp_per_level"]) * lvl


static func max_level() -> int:
	return int(DataDB.get_value("progression", "weapon.max_level"))


## XP ekler; atlanan level sayısını döndürür (maks levelde XP birikmez).
func add_xp(amount: float) -> int:
	if level >= max_level():
		return 0
	xp += maxf(amount, 0.0)
	var gained := 0
	while level < max_level() and xp >= xp_to_next(level):
		xp -= xp_to_next(level)
		level += 1
		gained += 1
	if level >= max_level():
		xp = 0.0
	return gained


## Normal saldırının vuruş başına ham hasarı: T × Ç × (1 + L) (ırk, ustalık ve buff'lar hariç).
func hit_damage() -> float:
	return base_damage() * float(type_data()["damage_mult"]) * (1.0 + DamageCalc.weapon_level_ratio(level))


func display_name() -> String:
	if is_legendary():
		return str(legendary_data()["name"])
	return Traits.weapon_name(type_id, element if is_elemental() else "", traits)


func type_name() -> String:
	return str(type_data()["name"])


func rarity_name() -> String:
	return str(DataDB.table("rarities")[rarity_id]["name"])


func rarity_color() -> Color:
	return Color(str(DataDB.table("rarities")[rarity_id]["color"]))


func duplicate_weapon() -> Weapon:
	var w := Weapon.make(type_id, rarity_id, element, traits.duplicate(), level)
	w.xp = xp
	w.legendary_id = legendary_id
	w.rerolls = rerolls
	return w


## Hasar türünün rengi (element rengi ya da fiziksel).
static func kind_color(kind: String) -> Color:
	if kind == DamageCalc.PHYSICAL or kind == "":
		return Color(str(DataDB.get_value("elements", "physical.color")))
	var els: Dictionary = DataDB.table("elements")["elements"]
	if els.has(kind):
		return Color(str(els[kind]["color"]))
	return Color.WHITE


static func kind_name(kind: String) -> String:
	if kind == DamageCalc.PHYSICAL or kind == "":
		return str(DataDB.get_value("elements", "physical.name"))
	return str(DataDB.table("elements")["elements"][kind]["name"])
