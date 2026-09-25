## Traits — 5 silah özelliğinin saf hesapları: Öfke, İnfaz, Can Emme, Sekme, Sersemletme.
## Sahneye dokunan kısmı HitResolver yapar; burada yalnızca sayılar ve zar atışları var.
class_name Traits
extends RefCounted


static func data(trait_id: String) -> Dictionary:
	return DataDB.table("traits")[trait_id]


## scale: özelliğin gücü. Silahın kendi özelliği 1; Esnek slottaki silahın özelliği %9 (GDD: pasifinin %9'u),
## ikisi de varsa toplanır (1,09). Sayısal değerler bununla çarpılır (şanslar, eşikler, yüzdeler).

## Öfke: hedefe daha önce vurulan her vuruş için +%1, maks %6 (stacks = önceki vuruş sayısı).
static func fury_bonus(stacks: int, scale: float = 1.0) -> float:
	var d := data("fury")
	return minf(float(stacks) * float(d["per_hit"]), float(d["max"])) * scale


## İnfaz: vuruştan sonra canı eşiğin altındaysa hedef ölür (boss'ta eşik %3).
static func should_execute(hp: float, max_hp: float, is_boss: bool, scale: float = 1.0) -> bool:
	if hp <= 0.0 or max_hp <= 0.0:
		return false
	var d := data("execute")
	var threshold := float(d["boss_threshold"] if is_boss else d["threshold"]) * scale
	return hp / max_hp < threshold


## Can Emme: verilen hasarın %3'ü.
static func lifesteal_amount(damage_dealt: float, scale: float = 1.0) -> float:
	return damage_dealt * float(data("lifesteal")["pct"]) * scale


## Sekme şansı tuttu mu?
static func roll_ricochet(rng: RandomNumberGenerator, scale: float = 1.0) -> bool:
	return rng.randf() < float(data("ricochet")["chance"]) * scale


## Sersemletme şansı tuttu mu?
static func roll_stun(rng: RandomNumberGenerator, scale: float = 1.0) -> bool:
	return rng.randf() < float(data("stun")["chance"]) * scale


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
