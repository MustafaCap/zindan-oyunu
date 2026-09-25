## RaceKit — ırkın kaynağı (Enerji, Mana ya da yalnızca bekleme süreleri) ve sağ tık / Q / E bekleme süreleri.
## Saf mantıktır (sahneye dokunmaz); Player her karede tick() çağırır. Sayılar races.json'dan okunur.
##   Warrior: Enerji 100, saniyede 10 dolar, isabet eden her saldırıda +2. Q/E enerji harcar, sağ tık beklemeli.
##   Magical: Mana 120 + level × 4, saniyede maks mananın %3'ü. Sol tık, sağ tık, Q, E mana harcar.
##   Archer / Ghost: kaynak yok; sağ tık, Q ve E bekleme sürelidir.
## Magical dışındaki ırk büyü silahı (kitap, asa, rün) kullanırsa sağ tık bekleme süresi ×1,5 olur ve sol tık bedavadır.
## Aşama 6: cooldown_reduction (ödüller, tavan %40) başlayan beklemeleri kısaltır; reduce() Kritik zinciri için.
class_name RaceKit
extends RefCounted

const SLOTS := ["heavy", "q", "e"]

var race_id: String
var resource_type: String      ## "energy", "mana" ya da "cooldown"
var resource: float = 0.0
var resource_max: float = 0.0
var cooldowns: Dictionary = {"heavy": 0.0, "q": 0.0, "e": 0.0}      ## kalan süre
var cooldown_totals: Dictionary = {"heavy": 1.0, "q": 1.0, "e": 1.0} ## son başlatılan toplam süre (gösterge için)
var cooldown_reduction: float = 0.0   ## Player statlardan verir (tavan uygulanmış)

var _race: Dictionary
var _res: Dictionary
var _last_hit_attack_id: int = -1


func _init(p_race_id: String, level: int = 1) -> void:
	race_id = p_race_id
	_race = DataDB.table("races")[race_id]
	_res = _race["resource"]
	resource_type = str(_res["type"])
	set_level(level)
	resource = resource_max


## Level değişince maks mana güncellenir (enerjide sabit 100).
func set_level(level: int) -> void:
	match resource_type:
		"energy": resource_max = float(_res["max"])
		"mana": resource_max = RaceStats.max_mana(race_id, level)
		_: resource_max = 0.0
	resource = minf(resource, resource_max)


func resource_name() -> String:
	return str(_res["name"])


func resource_color() -> Color:
	return Color(str(_res["color"]))


func uses_resource() -> bool:
	return resource_type != "cooldown"


## Bu silah ailesi bu ırk için "yabancı büyü silahı" mı? (Magical dışı ırk + kitap/asa/rün)
func is_foreign_spell_weapon(weapon_family: String) -> bool:
	return weapon_family == "magical" and str(_race["family"]) != "magical"


## Slotu kullanmanın kaynak bedeli. slot: "light", "heavy", "q", "e".
func cost(slot: String, weapon_family: String) -> float:
	if not uses_resource():
		return 0.0
	if slot in ["light", "heavy"] and is_foreign_spell_weapon(weapon_family):
		return 0.0
	return float((_race["costs"] as Dictionary).get(slot, 0.0))


## Slot kullanılınca başlayan bekleme süresi (saniye). Sol tık için 0 (saldırı hızı ayrı işler).
func cooldown_for(slot: String, weapon_family: String) -> float:
	if slot == "light":
		return 0.0
	var cds: Dictionary = _race["cooldowns"]
	var base := 0.0
	if cds.has(slot):
		var v: Variant = cds[slot]
		# Warrior'da sağ tık 5-7 sn: aralık verilmişse ortası kullanılır.
		base = (float(v[0]) + float(v[1])) * 0.5 if v is Array else float(v)
	# Magical dışı ırkların hepsinin sağ tık beklemesi vardır (DataDB denetler).
	if slot == "heavy" and is_foreign_spell_weapon(weapon_family):
		base *= float(DataDB.get_value("progression", "combat.non_magical_spell_cooldown_mult"))
	return base * (1.0 - clampf(cooldown_reduction, 0.0, 1.0))


func is_ready(slot: String) -> bool:
	return float(cooldowns.get(slot, 0.0)) <= 0.0


func can_use(slot: String, weapon_family: String) -> bool:
	return is_ready(slot) and resource + 0.0001 >= cost(slot, weapon_family)


## Kullanılabiliyorsa bedeli öder, bekleme süresini başlatır ve true döner.
## start_cooldown false ise bekleme başlatılmaz (Mızrak fırlatma: bekleme mızrak dönünce başlar).
func use(slot: String, weapon_family: String, start_cooldown: bool = true) -> bool:
	if not can_use(slot, weapon_family):
		return false
	resource -= cost(slot, weapon_family)
	if start_cooldown:
		start(slot, weapon_family)
	return true


func start(slot: String, weapon_family: String) -> void:
	var cd := cooldown_for(slot, weapon_family)
	if cd > 0.0 and cooldowns.has(slot):
		cooldowns[slot] = cd
		cooldown_totals[slot] = cd


func tick(delta: float) -> void:
	for s: String in SLOTS:
		cooldowns[s] = maxf(float(cooldowns[s]) - delta, 0.0)
	match resource_type:
		"energy": resource = minf(resource + float(_res["regen_per_sec"]) * delta, resource_max)
		"mana": resource = minf(resource + resource_max * float(_res["regen_pct_per_sec"]) * delta, resource_max)


## Bir saldırı isabet etti: Warrior'a enerji verir. Aynı saldırı birden çok düşmana değse de bir kez sayılır.
func on_hit_landed(attack_id: int) -> void:
	if resource_type != "energy" or attack_id == _last_hit_attack_id:
		return
	_last_hit_attack_id = attack_id
	resource = minf(resource + float(_res["gain_on_hit"]), resource_max)


## Sağ tık, Q ve E beklemelerini sn kadar kısaltır (boss özel etkisi Kritik zinciri).
func reduce(seconds: float) -> void:
	for s: String in SLOTS:
		cooldowns[s] = maxf(float(cooldowns[s]) - seconds, 0.0)
