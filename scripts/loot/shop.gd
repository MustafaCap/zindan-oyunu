## Shop — tüccar ve demirci işlemleri (GDD: Ekonomi ve Oda Tipleri). Saf mantıktır; InventoryUI ve zindan botu çağırır.
## Fiyatlar economy.json'dan, katın altın çarpanıyla (1. kat ×1 … 4. kat ×4) çarpılır.
##   Tüccar: silah (nadirliğe göre), tılsım ve iksir satar; slottaki eşyaları (son aktif silah hariç) alış fiyatının
##   %30'una alır.
##   Demirci: silahı bir sonraki 5'in katına level atlatır (en fazla oyuncunun leveli); elementi (Ender+, efsanevi hariç)
##   ya da özellikleri (Destansı+) yeniden çeker. Her yeniden çekme o silahta bir sonrakini ×1,5 pahalılaştırır.
## İşlem fonksiyonları "" (oldu) ya da hatanın nedenini döndürür.
class_name Shop
extends RefCounted


static func _ec() -> Dictionary:
	return DataDB.table("economy")


static func item_price(item: Variant, floor_i: int) -> int:
	var m: Dictionary = _ec()["merchant"]
	var base := 0.0
	if item is Weapon:
		base = float(m["weapon_prices"][(item as Weapon).rarity_id])
	elif item is Talisman:
		base = float(m["talisman_price"])
	return roundi(base * LootGenerator.gold_mult(floor_i))


static func potion_price(floor_i: int) -> int:
	return roundi(float(_ec()["merchant"]["potion_price"]) * LootGenerator.gold_mult(floor_i))


static func sell_price(item: Variant, floor_i: int) -> int:
	return roundi(item_price(item, floor_i) * float(_ec()["merchant"]["sell_pct"]))


## Tezgâhtaki eşyayı satın alır; uygun boş slota konur (yer yoksa alınamaz; önce bir eşya sat ya da bırak).
static func buy(inv: Inventory, stock: Array, index: int, floor_i: int, player_level: int = 1) -> String:
	if index < 0 or index >= stock.size() or stock[index] == null:
		return "Bu eşya artık yok"
	var item: Variant = stock[index]
	var price := item_price(item, floor_i)
	if inv.gold < price:
		return "Altın yetmiyor (%d gerekli)" % price
	if inv.free_slot_for(item, player_level) == "" and inv.first_free_bag() < 0:
		return "Boş slot yok (önce bir eşya sat ya da yere bırak)"
	inv.spend_gold(price)
	inv.add_item(item, player_level)
	stock.remove_at(index)
	return ""


## İksir satın alır (taşıma sınırına kadar; iksir kullanamayan ırka satılmaz).
static func buy_potion(inv: Inventory, floor_i: int, race_id: String) -> String:
	if not bool(DataDB.table("races")[race_id]["healing"]["potions"]):
		return "%s iksir kullanamaz" % DataDB.table("races")[race_id]["name"]
	if inv.potions >= inv.potion_max:
		return "İksir taşıma sınırı dolu (%d)" % inv.potion_max
	var price := potion_price(floor_i)
	if inv.gold < price:
		return "Altın yetmiyor (%d gerekli)" % price
	inv.spend_gold(price)
	inv.add_potion()
	return ""


static func sell(inv: Inventory, ref: Dictionary, floor_i: int, in_combat: bool) -> String:
	var why := inv.can_remove(ref, in_combat)
	if why != "":
		return why
	var item: Variant = inv.remove(ref)
	inv.add_gold(sell_price(item, floor_i))
	return ""


# --- demirci ---

## Level atlatmanın hedefi: bir sonraki 5'in katı, en fazla oyuncunun leveli ve silahın maks leveli.
## Atlatılamıyorsa silahın kendi leveli döner.
static func level_up_target(w: Weapon, player_level: int) -> int:
	var step := int(DataDB.get_value("progression", "weapon.bonus_step_levels"))
	var target := (w.level / step + 1) * step
	target = mini(target, mini(player_level, Weapon.max_level()))
	return maxi(target, w.level)


static func level_up_cost(w: Weapon, player_level: int, floor_i: int) -> int:
	var gained := level_up_target(w, player_level) - w.level
	return roundi(gained * float(_ec()["blacksmith"]["level_up_cost_per_level"]) * LootGenerator.gold_mult(floor_i))


static func level_up_block(w: Weapon, player_level: int) -> String:
	if w.level >= Weapon.max_level():
		return "Silah en yüksek levelde"
	if level_up_target(w, player_level) <= w.level:
		return "Silah oyuncunun leveline (%d) ulaştı" % player_level
	return ""


static func level_up(inv: Inventory, w: Weapon, player_level: int, floor_i: int) -> String:
	var why := level_up_block(w, player_level)
	if why != "":
		return why
	var cost := level_up_cost(w, player_level, floor_i)
	if not inv.spend_gold(cost):
		return "Altın yetmiyor (%d gerekli)" % cost
	w.level = level_up_target(w, player_level)
	w.xp = 0.0
	return ""


static func _reroll_cost(base_key: String, w: Weapon, floor_i: int) -> int:
	var b: Dictionary = _ec()["blacksmith"]
	return roundi(float(b[base_key]) * pow(float(b["reroll_cost_growth"]), w.rerolls) * LootGenerator.gold_mult(floor_i))


static func reroll_element_cost(w: Weapon, floor_i: int) -> int:
	return _reroll_cost("reroll_element_cost", w, floor_i)


static func reroll_trait_cost(w: Weapon, floor_i: int) -> int:
	return _reroll_cost("reroll_trait_cost", w, floor_i)


static func reroll_element_block(w: Weapon) -> String:
	if w.is_legendary():
		return "Efsanevi silahın elementi sabittir"
	if int(DataDB.table("rarities")[w.rarity_id]["elements"]) <= 0:
		return "Yaygın silahın elementi yok"
	return ""


static func reroll_trait_block(w: Weapon) -> String:
	if w.traits.is_empty():
		return "Bu silahın özelliği yok (Destansı ve üstü)"
	return ""


static func reroll_element(inv: Inventory, w: Weapon, floor_i: int, rng: RandomNumberGenerator) -> String:
	var why := reroll_element_block(w)
	if why != "":
		return why
	var cost := reroll_element_cost(w, floor_i)
	if not inv.spend_gold(cost):
		return "Altın yetmiyor (%d gerekli)" % cost
	w.element = LootGenerator.random_element(rng, w.element)
	w.rerolls += 1
	return ""


## Özellikleri yeniden çeker: aynı sayıda, öncekinden farklı bir set (tek özellikte başka bir özellik).
static func reroll_traits(inv: Inventory, w: Weapon, floor_i: int, rng: RandomNumberGenerator) -> String:
	var why := reroll_trait_block(w)
	if why != "":
		return why
	var cost := reroll_trait_cost(w, floor_i)
	if not inv.spend_gold(cost):
		return "Altın yetmiyor (%d gerekli)" % cost
	var n := w.traits.size()
	var old := w.traits.duplicate()
	var fresh := LootGenerator.random_traits(n, [], rng)
	var guard := 0
	while _same_set(fresh, old) and guard < 50:
		fresh = LootGenerator.random_traits(n, [], rng)
		guard += 1
	w.traits = fresh
	w.rerolls += 1
	return ""


static func _same_set(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for x: Variant in a:
		if not x in b:
			return false
	return true
