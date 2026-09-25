## GameState — aktif run'ın durumu: ırk, level, XP, kat, envanter (altın, iksir, çanta, 4 slot), buff'lar.
## Run bitince tamamen sıfırlanır (kalıcı veriler SaveManager'dadır). Envanter mantığı Inventory sınıfındadır;
## gold, potions, bag, slots ve active_slot ona kısayoldur.
## Aşama 6: add_xp (oyuncu XP'si ve leveli, Leveling), run ödülleri (buffs: stat → toplam, special_effects),
## bekleyen ödül ekranları (pending_rewards), kesilen boss'lar ve ustalık için silah tipine göre hasar.
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
var pending_rewards: Array[String] = []   # açılmayı bekleyen ödül ekranları: "level" / "boss" (sırayla)
var bosses_killed: Array[String] = []     # bu run'da kesilen boss'lar (id)
var floor2_cleared: bool = false          # 2. kat boss'u kesildi mi (ustalık derinlik çarpanı "2. katı bitirme")
var second_chance_used: bool = false
var kills: int = 0
var xp_earned: float = 0.0                # run boyunca kazanılan toplam XP (özet ekranı)


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
	pending_rewards = []
	bosses_killed = []
	floor2_cleared = false
	second_chance_used = false
	kills = 0
	xp_earned = 0.0


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


## Oyuncuya XP verir (Deneyim kazanımı ödülüyle çarpılır). Atlanan levelleri döndürür ([] = level atlanmadı).
## Events.xp_gained (verilen XP) ve her level için Events.level_up yayınlanır. Maks levelde XP birikmez.
func add_xp(amount: float) -> Array[int]:
	var gained_xp := maxf(amount, 0.0) * (1.0 + float(buffs.get("xp_gain", 0.0)))
	var r := Leveling.apply(level, xp, gained_xp)
	level = int(r["level"])
	xp = float(r["xp"])
	xp_earned += gained_xp
	Events.xp_gained.emit(gained_xp)
	var lv: Array[int] = []
	for l: Variant in r["levels"]:
		lv.append(int(l))
		Events.level_up.emit(int(l))
	return lv


func has_special(id: String) -> bool:
	return id in special_effects


## Bir özel etkinin sayıları (rewards.json > boss_special_pool); alınmadıysa {}.
func special(id: String) -> Dictionary:
	if not has_special(id):
		return {}
	return DataDB.table("rewards")["boss_special_pool"][id]
