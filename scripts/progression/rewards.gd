## Rewards — run içi ödüller (GDD: Run İçi Ödüller). Saf mantıktır; seçim ekranı RewardUI, akış DungeonRun'dadır.
##   Level ödülü: her 5 levelde level havuzundan rastgele 2 küçük stat (tekrar seçilebilir).
##   Boss ödülü: 1 büyük stat + 1 özel etki (özel etkiler run başına bir kez).
## Tavana ulaşan stat (tüm kaynakların toplamı; Player.stat_totals) havuzdan çıkar. İksir kullanamayan ırka
## "Yedek iksir" sunulmaz. Seçilen stat GameState.buffs'a eklenir, özel etki GameState.special_effects'e.
## Seçenek: {"source": "level"/"boss", "kind": "stat"/"special", "id", "name", "value", "text"}.
class_name Rewards
extends RefCounted


static func _t() -> Dictionary:
	return DataDB.table("rewards")


## Tavanı olan statlar (progression.stat_caps); diğerlerinin tavanı yok.
static func cap_of(stat: String) -> float:
	var caps: Dictionary = DataDB.get_value("progression", "stat_caps")
	return float(caps[stat]) if caps.has(stat) and not stat.begins_with("_") else INF


## Stat tavana ulaştı mı? totals: statın şu anki toplamı (tavansız).
static func is_capped(stat: String, totals: Dictionary) -> bool:
	return float(totals.get(stat, 0.0)) >= cap_of(stat) - 0.0001


static func special_data(id: String) -> Dictionary:
	return _t()["boss_special_pool"][id]


## "+%5 Saldırı hızı" gibi kısa metin.
static func stat_text(stat: String, value: float) -> String:
	return "+%%%s" % _pct(value)


static func _pct(v: float) -> String:
	var p := v * 100.0
	if absf(p - roundf(p)) < 0.01:
		return str(roundi(p))
	return ("%.1f" % p).replace(".", ",")


## Havuzdaki uygun statlar (tavana ulaşanlar hariç).
static func eligible_stats(pool: String, totals: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for id: String in DataDB.records(_t()[pool]):
		if not is_capped(id, totals):
			out.append(id)
	return out


## Alınabilecek özel etkiler: alınmamış ve ırka uygun.
static func eligible_specials(taken: Array, race_id: String) -> Array[String]:
	var can_potion := bool(DataDB.table("races")[race_id]["healing"]["potions"])
	var out: Array[String] = []
	for id: String in DataDB.records(_t()["boss_special_pool"]):
		if id in taken:
			continue
		if bool(special_data(id).get("requires_potions", false)) and not can_potion:
			continue
		out.append(id)
	return out


static func _stat_choice(source: String, pool: String, id: String) -> Dictionary:
	var d: Dictionary = _t()[pool][id]
	return {"source": source, "kind": "stat", "id": id, "name": str(d["name"]), "value": float(d["value"]),
		"text": "%s %s" % [stat_text(id, float(d["value"])), d["name"]]}


static func _special_choice(id: String) -> Dictionary:
	var d := special_data(id)
	return {"source": "boss", "kind": "special", "id": id, "name": str(d["name"]), "value": 0.0, "text": str(d["description"])}


static func _pick(rng: RandomNumberGenerator, ids: Array[String], n: int) -> Array[String]:
	var pool := ids.duplicate()
	var out: Array[String] = []
	while out.size() < n and not pool.is_empty():
		var i := rng.randi_range(0, pool.size() - 1)
		out.append(pool[i])
		pool.remove_at(i)
	return out


## Level ödülü: level havuzundan rastgele 2 farklı stat (uygun olanlar arasından).
static func level_offer(rng: RandomNumberGenerator, totals: Dictionary) -> Array:
	var out: Array = []
	for id: String in _pick(rng, eligible_stats("level_pool", totals), int(_t()["choices_per_offer"])):
		out.append(_stat_choice("level", "level_pool", id))
	return out


## Boss ödülü: 1 büyük stat + 1 özel etki. Özel etki kalmadıysa iki büyük stat.
static func boss_offer(rng: RandomNumberGenerator, totals: Dictionary, taken: Array, race_id: String) -> Array:
	var n := int(_t()["choices_per_offer"])
	var specials := _pick(rng, eligible_specials(taken, race_id), 1)
	var majors := _pick(rng, eligible_stats("boss_major_pool", totals), n - specials.size())
	var out: Array = []
	for id: String in majors:
		out.append(_stat_choice("boss", "boss_major_pool", id))
	for id2: String in specials:
		out.append(_special_choice(id2))
	return out


## Seçimi run'a işler: stat → buffs, özel etki → special_effects. gs: GameState (testte başka örnek).
static func apply(choice: Dictionary, gs: Node = null) -> void:
	var g: Node = gs if gs else GameState
	if str(choice["kind"]) == "stat":
		var b: Dictionary = g.get("buffs")
		var id := str(choice["id"])
		b[id] = float(b.get(id, 0.0)) + float(choice["value"])
	else:
		var sp: Array[String] = g.get("special_effects")
		if not str(choice["id"]) in sp:
			sp.append(str(choice["id"]))
