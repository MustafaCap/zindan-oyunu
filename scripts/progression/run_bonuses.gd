## RunBonuses — bir silahla savaşırken RaceStats'a eklenen bonusların toplamı (Aşama 6):
##   run ödülleri (GameState.buffs; run yoksa boş) + silah tipinin ustalık stat bonusları (saldırı hızı, menzil, element)
##   + boss ilk kesiş bonusu (+%0,3 hasar × kesilen farklı boss, kalıcı).
## Ustalığın hasar bonusu formülde ayrı çarpan (U) olduğu için buraya girmez; Mastery.level_of ile deal_hit'e verilir.
## Player ve WeaponInfo (tooltip) aynı toplamı kullanır.
class_name RunBonuses
extends RefCounted


static func for_weapon(type_id: String) -> Dictionary:
	var out := {}
	for k: Variant in GameState.buffs.keys():
		out[str(k)] = float(GameState.buffs[k])
	var mb := Mastery.stat_bonuses(Mastery.level_of(type_id))
	for k2: String in mb.keys():
		out[k2] = float(out.get(k2, 0.0)) + float(mb[k2])
	out["damage"] = float(out.get("damage", 0.0)) + first_kill_bonus()
	return out


## Kalıcı boss ilk kesiş bonusu: kesilen her farklı boss için +%0,3 hasar (20 boss ile en fazla +%6).
static func first_kill_bonus() -> float:
	return float(DataDB.get_value("bosses", "first_kill_damage_bonus")) * SaveManager.boss_first_kills.size()
