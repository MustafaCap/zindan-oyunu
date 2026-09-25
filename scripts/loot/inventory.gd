## Inventory — run'ın 4 slotu, altını ve iksirleri (GDD: Kontroller ve Slotlar, Rezonans ve Esnek Slot).
## Saf mantıktır; arayüz (InventoryUI) ve DungeonRun bunu çağırır. GameState.inventory run boyunca tutar.
## Kullanıcı kararı (Aşama 5): envanterin tamamı 4 slottur, çanta yoktur (economy.bag_size = 0); yeni eşya için yer
## yoksa bir eşya geride bırakılır. Kod çanta gözlerini destekler (bag_size > 0 olursa çanta geri gelir).
##   Aktif 1 / Aktif 2: yalnızca açık (kilitsiz) silah.   Rezonans: kilitli ya da açık silah.
##   Esnek: silah (kilitli ya da açık) ya da tılsım.
## Kurallar: en az bir aktif silah kalır; savaş sürerken (GameState.in_combat) slotlara dokunulamaz ve eşya alınamaz.
## Dolu yere bırakılan eşya yer değiştirir (karşı taraf da kurala uymalı).
## Eşya adresi (ref): {"area": "bag", "index": i} ya da {"area": "slot", "name": "active_1"}.
class_name Inventory
extends RefCounted

const SLOT_NAMES := ["active_1", "active_2", "resonance", "flex"]
const ACTIVE_SLOTS := ["active_1", "active_2"]
const SLOT_TITLES := {"active_1": "Aktif 1", "active_2": "Aktif 2", "resonance": "Rezonans", "flex": "Esnek"}

var bag: Array = []            ## sabit uzunlukta; null = boş göz
var slots: Dictionary = {}     ## slot adı -> Weapon / Talisman / null
var gold: int = 0
var potions: int = 0
var potion_max: int = 3
var active_slot: String = "active_1"


func _init(bag_size: int = -1) -> void:
	reset(bag_size)


func reset(bag_size: int = -1) -> void:
	# Veri yüklenemediyse (hata ekranı) de çökmesin diye varsayılanlarla
	var ec: Dictionary = DataDB.tables.get("economy", {})
	var n := bag_size if bag_size > 0 else int(ec.get("bag_size", 12))
	bag = []
	bag.resize(n)
	slots = {}
	for s: String in SLOT_NAMES:
		slots[s] = null
	gold = 0
	potions = 0
	potion_max = int((DataDB.tables.get("progression", {}) as Dictionary).get("potions", {}).get("max", 3))
	active_slot = "active_1"


static func bag_ref(i: int) -> Dictionary:
	return {"area": "bag", "index": i}


static func slot_ref(n: String) -> Dictionary:
	return {"area": "slot", "name": n}


static func same_ref(a: Dictionary, b: Dictionary) -> bool:
	return str(a.get("area")) == str(b.get("area")) and a.get("index", -1) == b.get("index", -1) \
		and str(a.get("name", "")) == str(b.get("name", ""))


func get_item(ref: Dictionary) -> Variant:
	if str(ref.get("area")) == "bag":
		var i := int(ref.get("index", -1))
		return bag[i] if i >= 0 and i < bag.size() else null
	return slots.get(str(ref.get("name", "")))


func _set_item(ref: Dictionary, item: Variant) -> void:
	if str(ref.get("area")) == "bag":
		bag[int(ref["index"])] = item
	else:
		slots[str(ref["name"])] = item


## Bu yer bu eşyayı alabilir mi? "" = evet, değilse nedeni.
func can_hold(ref: Dictionary, item: Variant, player_level: int) -> String:
	if item == null or str(ref.get("area")) == "bag":
		return ""
	var s := str(ref.get("name", ""))
	match s:
		"active_1", "active_2":
			if not item is Weapon:
				return "Aktif slota yalnızca silah konur"
			if (item as Weapon).is_locked(player_level):
				return "Kilitli silah aktif slota konamaz (level %d gerekli)" % (item as Weapon).level
		"resonance":
			if not item is Weapon:
				return "Rezonans slotuna yalnızca silah konur"
		"flex":
			if not (item is Weapon or item is Talisman):
				return "Esnek slota silah ya da tılsım konur"
		_:
			return "Bilinmeyen slot"
	return ""


## Taşımayı denetler: "" = yapılabilir, değilse nedeni.
func check_move(from: Dictionary, to: Dictionary, player_level: int, in_combat: bool) -> String:
	if same_ref(from, to):
		return "same"
	var a: Variant = get_item(from)
	if a == null:
		return "Boş göz"
	if in_combat and (str(from["area"]) == "slot" or str(to["area"]) == "slot"):
		return "Savaş sürerken slot değişimi yapılamaz"
	var b: Variant = get_item(to)
	var why := can_hold(to, a, player_level)
	if why != "":
		return why
	if b != null:
		why = can_hold(from, b, player_level)
		if why != "":
			return why
	# En az bir aktif silah kalmalı
	var after := {}
	for s: String in ACTIVE_SLOTS:
		after[s] = slots[s]
	if str(from["area"]) == "slot" and ACTIVE_SLOTS.has(str(from["name"])):
		after[str(from["name"])] = b
	if str(to["area"]) == "slot" and ACTIVE_SLOTS.has(str(to["name"])):
		after[str(to["name"])] = a
	if after["active_1"] == null and after["active_2"] == null:
		return "En az bir aktif silah kalmalı"
	return ""


## Taşır (hedef doluysa yer değiştirir). "" = oldu, değilse nedeni.
func move(from: Dictionary, to: Dictionary, player_level: int, in_combat: bool) -> String:
	var why := check_move(from, to, player_level, in_combat)
	if why != "":
		return why
	var a: Variant = get_item(from)
	var b: Variant = get_item(to)
	_set_item(to, a)
	_set_item(from, b)
	_fix_active_slot()
	return ""


## Eşyayı çıkarmak (satmak, yere bırakmak) mümkün mü?
func can_remove(ref: Dictionary, in_combat: bool) -> String:
	if get_item(ref) == null:
		return "Boş göz"
	if str(ref["area"]) == "slot":
		if in_combat:
			return "Savaş sürerken slot değişimi yapılamaz"
		var n := str(ref["name"])
		if ACTIVE_SLOTS.has(n):
			var other := "active_2" if n == "active_1" else "active_1"
			if slots[other] == null:
				return "En az bir aktif silah kalmalı"
	return ""


func remove(ref: Dictionary) -> Variant:
	var item: Variant = get_item(ref)
	_set_item(ref, null)
	_fix_active_slot()
	return item


func first_free_bag() -> int:
	for i: int in bag.size():
		if bag[i] == null:
			return i
	return -1


func bag_free() -> int:
	var n := 0
	for it: Variant in bag:
		if it == null:
			n += 1
	return n


## Eşyanın konabileceği ilk boş slot: açık silah Aktif 1 → Aktif 2 → Rezonans → Esnek; kilitli silah Rezonans → Esnek;
## tılsım Esnek. Yoksa "".
func free_slot_for(item: Variant, player_level: int) -> String:
	for s: String in SLOT_NAMES:
		if slots[s] == null and can_hold(slot_ref(s), item, player_level) == "":
			return s
	return ""


## Yerden alınan ya da satın alınan eşyayı koyar: uygun boş slota, yoksa (varsa) çantaya.
## Döndürür: konduğu slotun adı, "bag" ya da "" (yer yok). Savaşta eşya alınamaz ("").
func add_item(item: Variant, player_level: int, in_combat: bool = false) -> String:
	if in_combat:
		return ""
	var s := free_slot_for(item, player_level)
	if s != "":
		slots[s] = item
		_fix_active_slot()
		return s
	var i := first_free_bag()
	if i < 0:
		return ""
	bag[i] = item
	return "bag"


## Yer yokken yerdekiyle değiştirilecek slot: açık silah kullanılan aktif silahla, kilitli silah Rezonans'la,
## tılsım Esnek'le.
func swap_slot_for(item: Variant, player_level: int) -> String:
	if item is Talisman:
		return "flex"
	if (item as Weapon).is_locked(player_level):
		return "resonance"
	return active_slot if slots.get(active_slot) != null else "active_1"


## Eşyayı slota koyar, oradakini döndürür (yere bırakılır).
func swap_in(item: Variant, slot: String) -> Variant:
	var old: Variant = slots[slot]
	slots[slot] = item
	_fix_active_slot()
	return old


## Aktif silahlar sırayla (Aktif 1, Aktif 2; boş olanlar atlanır).
func active_weapons() -> Array[Weapon]:
	var out: Array[Weapon] = []
	for s: String in ACTIVE_SLOTS:
		if slots[s] != null:
			out.append(slots[s])
	return out


## active_weapons() içinde şu an kullanılan silahın sırası.
func active_index() -> int:
	if active_slot == "active_2" and slots["active_1"] != null and slots["active_2"] != null:
		return 1
	return 0


## Player Tab'a basınca: sıradaki aktif silah.
func set_active_index(i: int) -> void:
	var list: Array[String] = []
	for s: String in ACTIVE_SLOTS:
		if slots[s] != null:
			list.append(s)
	if not list.is_empty():
		active_slot = list[clampi(i, 0, list.size() - 1)]


func _fix_active_slot() -> void:
	if slots.get(active_slot) == null:
		active_slot = "active_2" if active_slot == "active_1" else "active_1"
		if slots[active_slot] == null:
			active_slot = "active_1"


func resonance_weapon() -> Weapon:
	return slots["resonance"] as Weapon


func flex_item() -> Variant:
	return slots["flex"]


## Çantada ve slotlarda olan tılsımların id'leri (loot aynı tılsımı iki kez vermesin).
func owned_talismans() -> Array:
	var out: Array = []
	for it: Variant in bag + slots.values():
		if it is Talisman:
			out.append((it as Talisman).id)
	return out


func all_items() -> Array:
	var out: Array = []
	for it: Variant in slots.values() + bag:
		if it != null:
			out.append(it)
	return out


## Oyuncunun kazandığı XP silahlara (GDD: Yetişme XP'si). Yalnızca economy.weapon_xp.xp_slots'taki silahlar alır.
## Oyuncunun levelinin altındaki silah 1,5 katını alır; yakalayınca normal hıza döner. Silah oyuncunun levelini
## geçemez (XP birikir, oyuncu level atlayınca devam eder). Kilitli silah XP almaz.
## Döndürür: [{"weapon": Weapon, "levels": int, "slot": String}] (level atlayanlar).
func grant_weapon_xp(amount: float, player_level: int) -> Array:
	var cfg: Dictionary = DataDB.table("economy")["weapon_xp"]
	var mult := float(DataDB.get_value("progression", "weapon.catch_up_xp_mult"))
	var out: Array = []
	for s: Variant in cfg["xp_slots"]:
		var w := slots.get(str(s)) as Weapon
		if w == null:
			continue
		if w.is_locked(player_level) and not bool(cfg["locked_gains_xp"]):
			continue
		var gained := give_xp(w, amount, player_level, mult)
		if gained > 0:
			out.append({"weapon": w, "levels": gained, "slot": str(s)})
	return out


## Tek silaha yetişme kuralıyla XP verir; atlanan level sayısını döndürür.
static func give_xp(w: Weapon, amount: float, player_level: int, catch_up_mult: float) -> int:
	var left := amount
	var gained := 0
	# Oyuncunun levelinde dolu bekleyen çubuk: oyuncu level atladıysa o level şimdi gelir
	if w.level < player_level and w.level < Weapon.max_level() and w.xp >= Weapon.xp_to_next(w.level):
		gained += w.add_xp(0.0)
	var guard := 0
	while left > 0.0001 and guard < 400:
		guard += 1
		if w.level >= Weapon.max_level():
			break
		var need := Weapon.xp_to_next(w.level) - w.xp
		if w.level < player_level:
			var raw_need := need / catch_up_mult
			if left >= raw_need:
				gained += w.add_xp(need)
				left -= raw_need
			else:
				w.add_xp(left * catch_up_mult)
				left = 0.0
		else:
			# Oyuncunun levelinde: normal hız, ama levelini geçemez (çubuk dolu bekler)
			w.xp = minf(w.xp + left, Weapon.xp_to_next(w.level))
			left = 0.0
	return gained


func add_gold(n: int) -> void:
	gold = maxi(gold + n, 0)


func spend_gold(n: int) -> bool:
	if n > gold:
		return false
	gold -= n
	return true


func add_potion() -> bool:
	if potions >= potion_max:
		return false
	potions += 1
	return true
