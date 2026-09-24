## Combos — element kombolarını bulur (GDD: Kombolar).
## Hedefin üzerinde bir element varken ikinci bir elementle vurulursa kombo tetiklenir ve ilk element tüketilir.
## "order_free" kombolar iki sırayla da tetiklenir. Bir vuruşta en fazla bir kombo tetiklenir (listedeki ilk eşleşen).
class_name Combos
extends RefCounted


## incoming elementiyle vurulan hedefte tetiklenecek kombo.
## Döndürür: {} (kombo yok) ya da {"combo": <elements.json kaydı>, "consumed": <tüketilecek element>}
static func find(status: StatusEffects, incoming: String) -> Dictionary:
	for c: Variant in DataDB.table("elements")["combos"]:
		var combo: Dictionary = c
		var first: String = combo["first"]
		var second: String = combo["second"]
		if incoming == second and first != second and status.has_element(first):
			return {"combo": combo, "consumed": first}
		if bool(combo.get("order_free", false)) and incoming == first and status.has_element(second):
			return {"combo": combo, "consumed": second}
	return {}


static func by_id(combo_id: String) -> Dictionary:
	for c: Variant in DataDB.table("elements")["combos"]:
		if (c as Dictionary)["id"] == combo_id:
			return c
	return {}
