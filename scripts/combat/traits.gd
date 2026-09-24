## Traits — 5 silah özelliğinin saf hesapları: Öfke, İnfaz, Can Emme, Sekme, Sersemletme.
## Sahneye dokunan kısmı HitResolver yapar; burada yalnızca sayılar ve zar atışları var.
class_name Traits
extends RefCounted


static func data(trait_id: String) -> Dictionary:
	return DataDB.table("traits")[trait_id]


## Öfke: hedefe daha önce vurulan her vuruş için +%1, maks %6 (stacks = önceki vuruş sayısı).
static func fury_bonus(stacks: int) -> float:
	var d := data("fury")
	return minf(float(stacks) * float(d["per_hit"]), float(d["max"]))


## İnfaz: vuruştan sonra canı eşiğin altındaysa hedef ölür (boss'ta eşik %3).
static func should_execute(hp: float, max_hp: float, is_boss: bool) -> bool:
	if hp <= 0.0 or max_hp <= 0.0:
		return false
	var d := data("execute")
	var threshold := float(d["boss_threshold"] if is_boss else d["threshold"])
	return hp / max_hp < threshold


## Can Emme: verilen hasarın %3'ü.
static func lifesteal_amount(damage_dealt: float) -> float:
	return damage_dealt * float(data("lifesteal")["pct"])


## Sekme şansı tuttu mu?
static func roll_ricochet(rng: RandomNumberGenerator) -> bool:
	return rng.randf() < float(data("ricochet")["chance"])


## Sersemletme şansı tuttu mu?
static func roll_stun(rng: RandomNumberGenerator) -> bool:
	return rng.randf() < float(data("stun")["chance"])


## Silah adı: "Öfkeli Buz Kılıcı", "İnfazcı Zehir Hançeri", "Kılıç".
static func weapon_name(type_id: String, element: String, trait_ids: Array) -> String:
	var wt: Dictionary = DataDB.table("weapon_types")[type_id]
	var parts: PackedStringArray = []
	for t: Variant in trait_ids:
		parts.append(str(data(str(t))["adjective"]))
	if element != "" and element != DamageCalc.PHYSICAL:
		parts.append(str(DataDB.table("elements")["elements"][element]["name"]))
		parts.append(str(wt["name_compound"]))
	else:
		parts.append(str(wt["name"]))
	return " ".join(parts)
