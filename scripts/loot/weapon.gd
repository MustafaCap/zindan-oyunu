## Weapon — bir silah örneği: tip, nadirlik, element, özellikler ve level.
## Aşama 5'te LootGenerator bunları üretecek; Aşama 2'de test odası elle kurar.
class_name Weapon
extends RefCounted

var type_id: String = "sword"
var rarity_id: String = "common"
var element: String = DamageCalc.PHYSICAL   ## element id ya da "physical" (yaygın silah)
var traits: Array[String] = []
var level: int = 1


static func make(p_type: String, p_rarity: String, p_element: String = DamageCalc.PHYSICAL, p_traits: Array[String] = [], p_level: int = 1) -> Weapon:
	var w := Weapon.new()
	w.type_id = p_type
	w.rarity_id = p_rarity
	w.element = p_element if p_element != "" else DamageCalc.PHYSICAL
	w.traits = p_traits
	w.level = p_level
	return w


func type_data() -> Dictionary:
	return DataDB.table("weapon_types")[type_id]


func base_damage() -> float:
	return float(DataDB.table("rarities")[rarity_id]["base_damage"])


func has_trait(trait_id: String) -> bool:
	return trait_id in traits


func is_elemental() -> bool:
	return element != DamageCalc.PHYSICAL


func display_name() -> String:
	return Traits.weapon_name(type_id, element if is_elemental() else "", traits)


func rarity_name() -> String:
	return str(DataDB.table("rarities")[rarity_id]["name"])


func rarity_color() -> Color:
	return Color(str(DataDB.table("rarities")[rarity_id]["color"]))


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
