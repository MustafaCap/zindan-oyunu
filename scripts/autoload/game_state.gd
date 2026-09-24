## GameState — aktif run'ın durumu: ırk, level, XP, kat, altın, çanta, slotlar, buff'lar.
## Run bitince tamamen sıfırlanır (kalıcı veriler SaveManager'dadır).
extends Node

const SLOT_NAMES := ["active_1", "active_2", "resonance", "flex"]

var in_run: bool = false
var race_id: String = ""
var level: int = 1
var xp: float = 0.0
var floor_index: int = 1
var run_seed: int = 0               ## haritaları üreten seed (her kat: run_seed + kat)
var in_combat: bool = false         ## kilitli bir savaş odasında mı (GDD: slot değişimi yalnızca oda dışında)
var gold: int = 0
var potions: int = 0
var bag: Array = []                 # çantadaki eşyalar (Aşama 5)
var slots: Dictionary = {}          # SLOT_NAMES -> eşya ya da null
var active_slot: String = "active_1"
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
	gold = 0
	potions = 0
	bag = []
	slots = {}
	for s: String in SLOT_NAMES:
		slots[s] = null
	active_slot = "active_1"
	buffs = {}
	special_effects = []
	damage_by_weapon_type = {}


func start_run(new_race_id: String) -> void:
	reset_run()
	race_id = new_race_id
	in_run = true
	potions = int(DataDB.get_value("progression", "potions.start"))
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
