## GameState — aktif run'ın durumu: ırk, level, XP, kat, envanter (altın, iksir, çanta, 4 slot), buff'lar.
## Run bitince tamamen sıfırlanır (kalıcı veriler SaveManager'dadır). Envanter mantığı Inventory sınıfındadır;
## gold, potions, bag, slots ve active_slot ona kısayoldur.
extends Node

const SLOT_NAMES := Inventory.SLOT_NAMES

var in_run: bool = false
var race_id: String = ""
var level: int = 1
var xp: float = 0.0
var floor_index: int = 1
var run_seed: int = 0               ## haritaları üreten seed (her kat: run_seed + kat)
var in_combat: bool = false         ## kilitli bir savaş odasında mı (GDD: slot değişimi yalnızca oda dışında)
var inventory: Inventory             ## çanta, 4 slot, altın, iksir (Aşama 5)
var gold: int:
	get: return inventory.gold if inventory else 0
	set(v): inventory.gold = v
var potions: int:
	get: return inventory.potions if inventory else 0
	set(v): inventory.potions = v
var bag: Array:
	get: return inventory.bag if inventory else []
var slots: Dictionary:
	get: return inventory.slots if inventory else {}
var active_slot: String:
	get: return inventory.active_slot if inventory else "active_1"
	set(v): inventory.active_slot = v
var buffs: Dictionary = {}          # stat adı -> toplam bonus (ödüllerden)
var special_effects: Array[String] = []   # alınmış boss özel etkileri
var damage_by_weapon_type: Dictionary = {} # ustalık XP dağılımı için


func _ready() -> void:
	reset_run()


## Yeni run için her şeyi başlangıç değerlerine döndürür.
func reset_run() -> void:
	in_run = false
	race_id = ""
	level = 1
	xp = 0.0
	floor_index = 1
	run_seed = 0
	in_combat = false
	inventory = Inventory.new()
	buffs = {}
	special_effects = []
	damage_by_weapon_type = {}


func start_run(new_race_id: String) -> void:
	reset_run()
	race_id = new_race_id
	in_run = true
	potions = int(DataDB.get_value("progression", "potions.start"))
	# Her run ırkın kendi ailesinden Yaygın, level 1 bir silahla başlar; çanta boş (economy.start_weapons).
	inventory.slots["active_1"] = LootGenerator.start_weapon(race_id)
	Events.run_started.emit(race_id)


## GDD Kontroller ve Slotlar: çanta ↔ slot değişimi yalnızca oda dışında (koridorda, temizlenmiş ya da savaş dışı
## odada). Tab ile iki aktif silah arasında geçiş bu kurala tabi değildir, savaşta da serbesttir.
func can_change_slots() -> bool:
	return not in_combat


func set_in_combat(value: bool) -> void:
	if in_combat == value:
		return
	in_combat = value
	Events.combat_state_changed.emit(value)


## Kat seed'i: aynı run seed'inden her kat için farklı ama tekrarlanabilir harita.
func floor_seed(floor_idx: int) -> int:
	return hash([run_seed, floor_idx])


## Silah tipine göre verilen hasarı biriktirir (run sonunda ustalık XP'si buna göre bölünür).
func record_damage(weapon_type: String, amount: float) -> void:
	damage_by_weapon_type[weapon_type] = float(damage_by_weapon_type.get(weapon_type, 0.0)) + amount
