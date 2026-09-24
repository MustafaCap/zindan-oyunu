## DamageCalc — oyundaki tüm hasarın geçtiği tek formül (GDD: Mimari ve Veri > Hasar formülü).
##   Hasar = T × Ç × (1+L) × (1+U) × (1+B) × E × K × A × (1−Z)
## Saf (yan etkisiz) hesaplardır; sayılar DataDB'den okunur. Her terim ayrı fonksiyondur ve
## tests/test_damage_calc.gd ile korunur.
class_name DamageCalc
extends RefCounted

const PHYSICAL := "physical"


## Bir vuruşun saldıran tarafı.
class Hit:
	extends RefCounted
	var base_damage: float = 100.0   ## T: nadirlik temel hasarı (düşmanlarda düşmanın hasarı)
	var type_mult: float = 1.0       ## Ç: silah tipi çarpanı (sağ tık / sekme / kombo payı da buna çarpılır)
	var weapon_level: int = 0        ## L bundan hesaplanır (0 = silah leveli yok)
	var mastery_level: int = 0       ## U bundan hesaplanır
	var damage_buffs: float = 0.0    ## B: toplam hasar buff'ları (Öfke, ödüller, ırk cezası… toplanarak)
	var kind: String = PHYSICAL      ## element id ya da "physical"
	var element_bonus: float = 0.0   ## element hasarı bonusları toplamı (E terimine girer)
	var is_crit: bool = false
	var crit_damage_bonus: float = 0.0
	var backstab: bool = false       ## hedefe arkasından mı vuruldu


## Bir vuruşun savunan tarafı.
class Defense:
	extends RefCounted
	var immune: Array = []
	var resistant: Array = []
	var weak: Array = []
	var armor: float = 0.0           ## Z: zırh / hasar azaltma (tavanı stat_caps.damage_reduction)

	func _init(p_immune: Array = [], p_resistant: Array = [], p_weak: Array = [], p_armor: float = 0.0) -> void:
		immune = p_immune
		resistant = p_resistant
		weak = p_weak
		armor = p_armor


## Formülün tamamı.
static func compute(hit: Hit, def: Defense) -> float:
	return hit.base_damage * hit.type_mult \
		* (1.0 + weapon_level_ratio(hit.weapon_level)) \
		* (1.0 + mastery_bonus(hit.mastery_level)) \
		* (1.0 + hit.damage_buffs) \
		* element_term(hit.kind, def, hit.element_bonus) \
		* crit_term(hit.is_crit, hit.crit_damage_bonus) \
		* backstab_term(hit.kind, hit.backstab) \
		* armor_term(def.armor)


## L: her 5 levelde yenilenen oran (level 5 → 0,05 … level 80 → 0,80). Katlanmaz.
static func weapon_level_ratio(level: int) -> float:
	var w: Dictionary = DataDB.get_value("progression", "weapon")
	var lvl := clampi(level, 0, int(w["max_level"]))
	return floorf(float(lvl) / float(w["bonus_step_levels"])) * float(w["bonus_per_step"])


## U: ustalık hasar bonusu (level × 0,05; level 12'de 0,60).
static func mastery_bonus(level: int) -> float:
	var m: Dictionary = DataDB.get_value("progression", "mastery")
	var max_level := int(m["max_level"])
	var per_level := float(m["bonus_at_max"]["damage"]) / float(max_level)
	return per_level * clampi(level, 0, max_level)


## Durum çarpanı: bağışık 0 (fiziksel hasar fiziksele bağışık hedefe, yani hayalete %25), dirençli 0,5, normal 1, zayıf 1,5.
static func status_multiplier(kind: String, def: Defense) -> float:
	var m: Dictionary = DataDB.get_value("elements", "status_multipliers")
	if kind in def.immune:
		return float(m["common_vs_ghost"]) if kind == PHYSICAL else float(m["immune"])
	if kind in def.resistant:
		return float(m["resistant"])
	if kind in def.weak:
		return float(m["weak"])
	return float(m["normal"])


## E: durum çarpanı × (1 + element hasarı bonusları) × elementin kendi çarpanı (Su'da 0,8).
## Fiziksel hasara element bonusları uygulanmaz.
static func element_term(kind: String, def: Defense, element_bonus: float) -> float:
	var sm := status_multiplier(kind, def)
	if kind == PHYSICAL:
		return sm
	var el: Dictionary = DataDB.table("elements")["elements"].get(kind, {})
	return sm * (1.0 + element_bonus) * float(el.get("damage_mult", 1.0))


## K: kritikse 1,5 + kritik hasarı bonusları, değilse 1.
static func crit_term(is_crit: bool, crit_damage_bonus: float) -> float:
	if not is_crit:
		return 1.0
	return float(DataDB.get_value("progression", "combat.base_crit_mult")) + crit_damage_bonus


## A: Karanlık silahla arkadan vuruşta 1,1; diğer durumlarda 1.
static func backstab_term(kind: String, backstab: bool) -> float:
	if kind == "dark" and backstab:
		return float(DataDB.get_value("elements", "elements.dark.backstab_mult"))
	return 1.0


## (1 − Z): zırh tavanı %75.
static func armor_term(armor: float) -> float:
	var cap := float(DataDB.get_value("progression", "stat_caps.damage_reduction"))
	return 1.0 - clampf(armor, 0.0, cap)


## Saldıran, hedefin arkasında mı? (hedefin baktığı yönle saldırana olan yön arasındaki açı eşikten büyükse)
## Konumlar ekran uzayında, facing düz (zemin) uzayında verilir.
static func is_behind(target_pos: Vector2, target_facing_cart: Vector2, attacker_pos: Vector2) -> bool:
	var to_attacker := Iso.to_cart(attacker_pos - target_pos)
	if to_attacker.length() < 0.001 or target_facing_cart.length() < 0.001:
		return false
	var limit := float(DataDB.get_value("elements", "elements.dark.backstab_angle_degrees"))
	return absf(rad_to_deg(target_facing_cart.angle_to(to_attacker))) > limit


## Hasar türü hedefe hiç işlemiyor mu? (element durumu ve kombo uygulanmaz)
static func is_immune(kind: String, def: Defense) -> bool:
	return kind != PHYSICAL and kind in def.immune
