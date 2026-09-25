## Leveling — oyuncu XP'si ve leveli (GDD: Oyuncu Leveli, XP eğrisi). Saf hesaptır; GameState.add_xp bunu kullanır.
## Sonraki levele gereken XP = 100 + 20 × mevcut level (progression.player). Maks level 80; orada XP birikmez.
## Düşman XP'leri kat ve türe göre progression.enemy_xp içindedir: katın tüm düşmanları, 2 elit ve boss kesilirse
## oyuncu katın hedef üst levelinde çıkar (1→15, 15→35, 35→55, 55→80).
class_name Leveling
extends RefCounted


static func xp_to_next(level: int) -> float:
	var p: Dictionary = DataDB.get_value("progression", "player")
	return float(p["xp_base"]) + float(p["xp_per_level"]) * level


static func max_level() -> int:
	return int(DataDB.get_value("progression", "player.max_level"))


## Bir düşmanın verdiği XP. kind: "normal", "elite", "boss".
static func enemy_xp(floor_index: int, kind: String) -> float:
	var t: Dictionary = DataDB.table("progression")["enemy_xp"]
	var f := str(clampi(floor_index, 1, t.size()))
	return float(t[f].get(kind, 0.0))


## level→level_to arasındaki toplam XP.
static func xp_between(from_level: int, to_level: int) -> float:
	var total := 0.0
	for l: int in range(from_level, to_level):
		total += xp_to_next(l)
	return total


## XP ekler: {"level", "xp", "levels": [atlanan leveller]} döndürür. Maks levelde XP sıfırlanır.
static func apply(level: int, xp: float, amount: float) -> Dictionary:
	var lvl := level
	var x := xp + maxf(amount, 0.0)
	var gained: Array[int] = []
	var cap := max_level()
	while lvl < cap and x >= xp_to_next(lvl) - 0.0001:
		x -= xp_to_next(lvl)
		lvl += 1
		gained.append(lvl)
	if lvl >= cap:
		x = 0.0
	return {"level": lvl, "xp": maxf(x, 0.0), "levels": gained}


## Bu level ödül level'i mi? (her 5 levelde bir)
static func is_reward_level(level: int) -> bool:
	var every := int(DataDB.get_value("rewards", "level_reward_every"))
	return every > 0 and level % every == 0
