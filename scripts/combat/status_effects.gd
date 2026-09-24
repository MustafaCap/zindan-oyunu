## StatusEffects — bir düşmanın üzerindeki element durumları ve kontrol etkileri.
## Yanma, Islak, Zehir (yığın), Buz (yığın → donma), Gölge işareti; Sersem, Yavaş, Buhar, Çürüme.
## Saf mantıktır: sahne ağacına dokunmaz, tick() her karede çağrılır ve o karedeki süreli hasarı döndürür.
## Sayılar elements.json ve traits.json'dan okunur.
class_name StatusEffects
extends RefCounted

var is_boss: bool = false

var burn_t: float = 0.0
var burn_dps: float = 0.0
var wet_t: float = 0.0
var poison_stacks: Array[Vector2] = []   # x = kalan süre, y = saniyedeki hasar
var chill_stacks: int = 0
var chill_t: float = 0.0
var shadow_t: float = 0.0
var frozen_t: float = 0.0
var freeze_immune_t: float = 0.0         # boss'larda donmadan sonra bağışıklık
var stun_t: float = 0.0
var slow_t: float = 0.0
var slow_amount: float = 0.0
var steam_t: float = 0.0
var steam_miss: float = 0.0
var rot_t: float = 0.0
var rot_poison_mult: float = 1.0

var _el: Dictionary


func _init(boss: bool = false) -> void:
	is_boss = boss
	_el = DataDB.table("elements")["elements"]


## Bir element vuruşunun bıraktığı durumu uygular. hit_damage süreli hasarın temelidir.
## Döndürür: {"froze": bool} — buz yığını dolup hedef donduysa true.
func apply_element(element: String, hit_damage: float) -> Dictionary:
	var out := {"froze": false}
	match element:
		"fire":
			burn_t = float(_el["fire"]["duration"])
			burn_dps = maxf(burn_dps if burn_t > 0.0 else 0.0, hit_damage * float(_el["fire"]["dps_pct"]))
		"water":
			wet_t = float(_el["water"]["duration"])
		"poison":
			var p: Dictionary = _el["poison"]
			if poison_stacks.size() >= int(p["max_stacks"]):
				poison_stacks.remove_at(_weakest_poison_index())
			poison_stacks.append(Vector2(float(p["duration_per_stack"]), hit_damage * float(p["dps_pct_per_stack"])))
		"ice":
			if frozen_t > 0.0:
				return out
			var ice: Dictionary = _el["ice"]
			chill_stacks += 1
			chill_t = float(ice["stack_duration"])
			if chill_stacks >= int(ice["freeze_at_stacks"]):
				chill_stacks = 0
				chill_t = 0.0
				out["froze"] = freeze(float(ice["freeze_duration"]))
		"dark":
			shadow_t = float(_el["dark"]["duration"])
		# "lightning": kalıcı durum bırakmaz; etkisi anında zincirdir.
	return out


## Hedefin üzerinde bu element (ya da "frozen") var mı? Kombo kontrolü bunu kullanır.
func has_element(element: String) -> bool:
	match element:
		"fire": return burn_t > 0.0
		"water": return wet_t > 0.0
		"poison": return not poison_stacks.is_empty()
		"ice": return chill_stacks > 0
		"dark": return shadow_t > 0.0
		"frozen": return frozen_t > 0.0
	return false


## Kombonun ilk elementini tüketir.
func consume(element: String) -> void:
	match element:
		"fire":
			burn_t = 0.0
			burn_dps = 0.0
		"water": wet_t = 0.0
		"poison": poison_stacks.clear()
		"ice":
			chill_stacks = 0
			chill_t = 0.0
		"dark": shadow_t = 0.0
		"frozen": frozen_t = 0.0


## Dondurur. Boss donmadan sonra bir süre bağışıktır; bağışıksa false döner.
func freeze(duration: float) -> bool:
	if freeze_immune_t > 0.0:
		return false
	frozen_t = maxf(frozen_t, duration)
	chill_stacks = 0
	chill_t = 0.0
	if is_boss:
		freeze_immune_t = duration + float(DataDB.get_value("elements", "boss_freeze_immunity_sec"))
	return true


## Sersemletme özelliği: normal düşman sersemler, boss bunun yerine yavaşlar.
func stun(duration: float, boss_slow_duration: float, boss_slow: float) -> void:
	if is_boss:
		slow(boss_slow_duration, boss_slow)
	else:
		stun_t = maxf(stun_t, duration)


func slow(duration: float, amount: float) -> void:
	slow_t = maxf(slow_t, duration)
	slow_amount = maxf(slow_amount, amount)


func apply_steam(duration: float, miss_chance: float) -> void:
	steam_t = maxf(steam_t, duration)
	steam_miss = maxf(steam_miss, miss_chance)


func apply_rot(duration: float, poison_mult: float) -> void:
	rot_t = maxf(rot_t, duration)
	rot_poison_mult = poison_mult


## Süreleri ilerletir; bu karede verilen süreli hasarı {"burn": x, "poison": y} olarak döndürür.
func tick(delta: float) -> Dictionary:
	var out := {"burn": 0.0, "poison": 0.0}
	if burn_t > 0.0:
		var dt := minf(delta, burn_t)
		out["burn"] = burn_dps * dt
		burn_t -= delta
		if burn_t <= 0.0:
			burn_t = 0.0
			burn_dps = 0.0
	var pm := rot_poison_mult if rot_t > 0.0 else 1.0
	for i: int in range(poison_stacks.size() - 1, -1, -1):
		var s := poison_stacks[i]
		out["poison"] += s.y * minf(delta, s.x) * pm
		s.x -= delta
		if s.x <= 0.0:
			poison_stacks.remove_at(i)
		else:
			poison_stacks[i] = s
	wet_t = maxf(wet_t - delta, 0.0)
	shadow_t = maxf(shadow_t - delta, 0.0)
	if chill_t > 0.0:
		chill_t -= delta
		if chill_t <= 0.0:
			chill_t = 0.0
			chill_stacks = 0
	frozen_t = maxf(frozen_t - delta, 0.0)
	freeze_immune_t = maxf(freeze_immune_t - delta, 0.0)
	stun_t = maxf(stun_t - delta, 0.0)
	slow_t = maxf(slow_t - delta, 0.0)
	if slow_t <= 0.0:
		slow_amount = 0.0
	steam_t = maxf(steam_t - delta, 0.0)
	if steam_t <= 0.0:
		steam_miss = 0.0
	rot_t = maxf(rot_t - delta, 0.0)
	return out


## Hareket hızı çarpanı (buz yığınları ve yavaşlatma; donmuş/sersemse 0).
func speed_mult() -> float:
	if not can_act():
		return 0.0
	var chill := float(_el["ice"]["slow_per_stack"]) * chill_stacks
	return maxf(0.0, (1.0 - chill) * (1.0 - slow_amount))


## Donmuş ya da sersem değilse hareket edip saldırabilir.
func can_act() -> bool:
	return frozen_t <= 0.0 and stun_t <= 0.0


func is_frozen() -> bool:
	return frozen_t > 0.0


func miss_chance() -> float:
	return steam_miss if steam_t > 0.0 else 0.0


## Çürüme iyileşmeyi engeller.
func can_heal() -> bool:
	return rot_t <= 0.0


func poison_count() -> int:
	return poison_stacks.size()


## Arayüz için etkin durumların listesi: [{"id": ..., "stacks": n}]
func active_list() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if burn_t > 0.0: out.append({"id": "fire", "stacks": 0})
	if wet_t > 0.0: out.append({"id": "water", "stacks": 0})
	if not poison_stacks.is_empty(): out.append({"id": "poison", "stacks": poison_stacks.size()})
	if chill_stacks > 0: out.append({"id": "ice", "stacks": chill_stacks})
	if shadow_t > 0.0: out.append({"id": "dark", "stacks": 0})
	if rot_t > 0.0: out.append({"id": "rot", "stacks": 0})
	if steam_t > 0.0: out.append({"id": "steam", "stacks": 0})
	return out


func _weakest_poison_index() -> int:
	var idx := 0
	for i: int in poison_stacks.size():
		if poison_stacks[i].x < poison_stacks[idx].x:
			idx = i
	return idx
