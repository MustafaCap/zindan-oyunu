## Talisman — tılsım eşyası (GDD: Rezonans ve Esnek Slot > Tılsımlar). Yalnızca Esnek slotta etki eder (tam etki);
## çantada durur. Etkileri Player'da işlenir (Kan Taşı, Rüzgâr Tüyü, Element Kalbi). Sayılar talismans.json'dan.
class_name Talisman
extends RefCounted

var id: String = "blood_stone"


static func make(p_id: String) -> Talisman:
	var t := Talisman.new()
	t.id = p_id
	return t


func data() -> Dictionary:
	return DataDB.table("talismans")[id]


func display_name() -> String:
	return str(data()["name"])


func description() -> String:
	return str(data()["description"])


func color() -> Color:
	return Color(str(data().get("color", "#cccce6")))


static func all_ids() -> Array:
	return DataDB.records(DataDB.table("talismans"))
