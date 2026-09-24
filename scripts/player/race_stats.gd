## RaceStats — bir ırkın verilen level ve aktif silah ailesiyle hesaplanan statları (saf hesap, sahneye dokunmaz).
## Kaynaklar: races.json (başlangıç statları, pasif), race_weapon_matrix.json (ırk-silah ailesi ceza/bonusu),
## progression.json > stat_caps (tavanlar). Aşama 6'da ödül ve ustalık bonusları da buraya eklenecek.
class_name RaceStats
extends RefCounted

var race_id: String
var level: int
var weapon_family: String

var max_hp: float = 1.0
var move_speed_mult: float = 1.0
var armor: float = 0.0
var attack_speed_bonus: float = 0.0   ## saldırı hızı = tipin saldırı/sn × (1 + bu)
var attack_range_bonus: float = 0.0   ## menzil = tipin menzili × (1 + bu)
var damage_buffs: float = 0.0         ## hasar formülündeki B'ye eklenir (ırk-silah cezası dahil)
var element_bonus: float = 0.0        ## E terimindeki element hasarı bonusu
var crit_bonus: float = 0.0           ## temel kritik şansına eklenir


static func compute(p_race_id: String, p_level: int, p_weapon_family: String) -> RaceStats:
	var s := RaceStats.new()
	s.race_id = p_race_id
	s.level = maxi(p_level, 1)
	s.weapon_family = p_weapon_family
	var race: Dictionary = DataDB.table("races")[p_race_id]
	var mods := matrix(p_race_id, p_weapon_family)
	var passive: Dictionary = race["passive"]["bonuses"]
	var caps: Dictionary = DataDB.get_value("progression", "stat_caps")

	var base_hp := float(race["base_hp"]) + float(race["hp_per_level"]) * (s.level - 1)
	s.max_hp = base_hp * (1.0 + _sum(mods, passive, "max_hp"))
	s.move_speed_mult = float(race["move_speed"])
	s.armor = minf(float(race["armor"]), float(caps["damage_reduction"]))
	s.attack_speed_bonus = minf(_sum(mods, passive, "attack_speed"), float(caps["attack_speed"]))
	s.attack_range_bonus = minf(_sum(mods, passive, "attack_range"), float(caps["attack_range"]))
	s.damage_buffs = _sum(mods, passive, "damage")
	s.element_bonus = _sum(mods, passive, "element_damage")
	s.crit_bonus = _sum(mods, passive, "crit_chance")
	return s


## Irk-silah ailesi matris hücresi (örn. Warrior + Archer ailesi → {"max_hp": -0.25}).
static func matrix(p_race_id: String, family: String) -> Dictionary:
	return DataDB.table("race_weapon_matrix")[p_race_id].get(family, {})


## Matris hücresinin kısa metni: "−%25 can", "+%10 can, −%15 hasar"; boşsa "kendi ailesi".
static func matrix_text(p_race_id: String, family: String) -> String:
	var m := matrix(p_race_id, family)
	if m.is_empty():
		return "kendi ailesi"
	var names := {"max_hp": "can", "attack_speed": "saldırı hızı", "damage": "hasar", "element_damage": "element"}
	var parts: PackedStringArray = []
	for k: String in m.keys():
		var v := float(m[k])
		parts.append("%s%%%d %s" % ["+" if v > 0.0 else "−", roundi(absf(v) * 100.0), names.get(k, k)])
	return ", ".join(parts)


## Magical'ın maks manası: 120 + level × 4 (GDD: Kaynaklar).
static func max_mana(p_race_id: String, p_level: int) -> float:
	var res: Dictionary = DataDB.table("races")[p_race_id]["resource"]
	if str(res["type"]) != "mana":
		return 0.0
	return float(res["base_max"]) + float(res["max_per_level"]) * maxi(p_level, 1)


static func _sum(a: Dictionary, b: Dictionary, key: String) -> float:
	return float(a.get(key, 0.0)) + float(b.get(key, 0.0))
