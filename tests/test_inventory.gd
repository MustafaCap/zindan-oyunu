## Aşama 5 — Inventory: 4 slotun kuralları (kilitli silah, tılsım, en az bir aktif silah, savaşta kilit),
## yer değiştirme, yerden alma, silah leveli ve yetişme XP'si, Shop (tüccar ve demirci).
extends "res://tests/test_case.gd"


func _inv() -> Inventory:
	var inv := Inventory.new()
	inv.slots["active_1"] = Weapon.make("sword", "common")
	return inv


func _w(level: int = 1, type: String = "axe", rarity: String = "rare", el: String = "fire") -> Weapon:
	return Weapon.make(type, rarity, el, [], level)


func test_run_starts_with_race_weapon_and_empty_bag() -> void:
	GameState.start_run("archer")
	var inv := GameState.inventory
	assert_eq(inv.bag.size(), int(DataDB.table("economy")["bag_size"]), "çanta 12 göz")
	assert_eq(inv.bag_free(), inv.bag.size(), "çanta boş")
	var w := inv.slots["active_1"] as Weapon
	assert_true(w != null and w.type_id == "bow" and w.rarity_id == "common" and w.level == 1, "Archer yayla başlar")
	assert_eq(inv.slots["active_2"], null)
	assert_eq(GameState.potions, 2)
	assert_eq(GameState.gold, 0)
	GameState.reset_run()


func test_slot_rules() -> void:
	var inv := _inv()
	var locked := _w(20)
	var t := Talisman.make("blood_stone")
	assert_true(inv.can_hold(Inventory.slot_ref("active_2"), locked, 10) != "", "kilitli silah aktif slota konamaz")
	assert_eq(inv.can_hold(Inventory.slot_ref("active_2"), locked, 20), "", "level yetince konur")
	assert_eq(inv.can_hold(Inventory.slot_ref("resonance"), locked, 1), "", "kilitli silah Rezonans'a")
	assert_eq(inv.can_hold(Inventory.slot_ref("flex"), locked, 1), "", "kilitli silah Esnek'e")
	assert_true(inv.can_hold(Inventory.slot_ref("active_1"), t, 80) != "", "tılsım aktif slota konamaz")
	assert_true(inv.can_hold(Inventory.slot_ref("resonance"), t, 80) != "", "tılsım Rezonans'a konamaz")
	assert_eq(inv.can_hold(Inventory.slot_ref("flex"), t, 1), "", "tılsım Esnek'e")
	assert_eq(inv.can_hold(Inventory.bag_ref(3), t, 1), "", "çantaya her şey")


func test_move_swap_and_last_active_rule() -> void:
	var inv := _inv()
	var a1: Weapon = inv.slots["active_1"]
	var axe := _w(1)
	inv.bag[0] = axe
	assert_eq(inv.move(Inventory.bag_ref(0), Inventory.slot_ref("active_1"), 1, false), "", "çantadan aktif slota (yer değiştirir)")
	assert_eq(inv.slots["active_1"], axe)
	assert_eq(inv.bag[0], a1, "eski silah çantaya geçti")
	# Son aktif silah çantaya çıkarılamaz
	var free := inv.first_free_bag()
	assert_true(inv.move(Inventory.slot_ref("active_1"), Inventory.bag_ref(free), 1, false) != "", "en az bir aktif silah kalmalı")
	assert_true(inv.can_remove(Inventory.slot_ref("active_1"), false) != "", "son aktif silah satılamaz/bırakılamaz")
	# İkinci aktif silah varken çıkarılabilir; kullanılan slot boşalınca diğerine geçilir
	assert_eq(inv.move(Inventory.bag_ref(0), Inventory.slot_ref("active_2"), 1, false), "")
	inv.active_slot = "active_2"
	assert_eq(inv.active_index(), 1)
	assert_eq(inv.move(Inventory.slot_ref("active_2"), Inventory.bag_ref(5), 1, false), "")
	assert_eq(inv.active_slot, "active_1", "boşalan aktif slottan diğerine geçildi")
	assert_eq(inv.active_weapons().size(), 1)
	# Kilitli silah, aktif silahla yer değiştiremez (kilitli olan aktif slota gideceği için)
	inv.bag[6] = _w(30)
	assert_true(inv.move(Inventory.bag_ref(6), Inventory.slot_ref("active_1"), 10, false) != "")
	assert_eq(inv.move(Inventory.bag_ref(6), Inventory.slot_ref("resonance"), 10, false), "")
	# Rezonans'taki kilitli silah çantadaki açık silahla yer değiştirebilir mi? (açık silah Rezonans'a gider: evet)
	assert_eq(inv.move(Inventory.bag_ref(5), Inventory.slot_ref("resonance"), 10, false), "")
	assert_eq((inv.bag[5] as Weapon).level, 30, "kilitli silah çantaya döndü")


func test_combat_locks_slots_but_not_bag() -> void:
	var inv := _inv()
	inv.bag[0] = _w(1)
	assert_true(inv.move(Inventory.bag_ref(0), Inventory.slot_ref("active_2"), 1, true) != "", "savaşta slota konamaz")
	assert_eq(inv.move(Inventory.bag_ref(0), Inventory.bag_ref(4), 1, true), "", "savaşta çanta içi düzenleme serbest")
	assert_true(inv.can_remove(Inventory.slot_ref("active_1"), true) != "")
	# Savaşta yerden alınan silah boş aktif slota değil çantaya gider
	assert_eq(inv.add_item(_w(1), 1, true, true), "bag")
	assert_eq(inv.add_item(_w(1), 1, true, false), "active_2", "savaş dışında boş aktif slota takılır")
	assert_eq(inv.add_item(_w(50), 1, true, false), "bag", "kilitli silah çantaya")


func test_bag_full() -> void:
	var inv := _inv()
	for i: int in inv.bag.size():
		inv.bag[i] = _w(1)
	inv.slots["active_2"] = _w(1)
	assert_eq(inv.add_item(_w(1), 1), "", "çanta dolu")
	assert_eq(inv.bag_free(), 0)


func test_owned_talismans() -> void:
	var inv := _inv()
	inv.bag[2] = Talisman.make("wind_feather")
	inv.slots["flex"] = Talisman.make("element_heart")
	var owned := inv.owned_talismans()
	owned.sort()
	assert_eq(owned, ["element_heart", "wind_feather"])


# --- silah leveli ve XP ---

func test_weapon_xp_curve_same_as_player() -> void:
	assert_eq(Weapon.xp_to_next(1), 120.0)
	assert_eq(Weapon.xp_to_next(10), 300.0)
	var w := _w(1)
	assert_eq(w.add_xp(120.0), 1)
	assert_eq(w.level, 2)
	assert_eq(w.add_xp(140.0 + 160.0 + 10.0), 2, "iki level birden")
	assert_eq(w.level, 4)
	assert_almost(w.xp, 10.0, 0.001)
	var m := _w(80)
	assert_eq(m.add_xp(1e6), 0, "maks levelde XP birikmez")
	assert_eq(m.level, 80)


## GDD Yetişme XP'si: oyuncunun levelinin altındaki silah 1,5 kat alır, yakalayınca normal hıza döner (geçemez).
func test_catch_up_xp() -> void:
	var inv := _inv()
	var w: Weapon = inv.slots["active_1"]
	inv.grant_weapon_xp(100.0, 10)
	assert_almost(w.xp, 30.0, 0.001, "100 XP → 150 (level 1'den 2'ye 120 harcandı, 30 arttı)")
	assert_eq(w.level, 2)
	# Oyuncunun levelinde: normal hız ve oyuncuyu geçemez
	var w2 := _w(5)
	inv.slots["active_2"] = w2
	inv.grant_weapon_xp(50.0, 5)
	assert_almost(w2.xp, 50.0, 0.001, "oyuncunun levelinde 1× XP")
	inv.grant_weapon_xp(10000.0, 5)
	assert_eq(w2.level, 5, "silah oyuncunun levelini geçmez")
	assert_almost(w2.xp, Weapon.xp_to_next(5), 0.001, "çubuk dolu bekler")
	inv.grant_weapon_xp(0.0, 6)
	assert_eq(w2.level, 6, "oyuncu level atlayınca bekleyen level gelir")
	# Geçiş: level 9, oyuncu 10: 9→10'u 1,5 kat hızla, kalan normal hızla
	var w3 := _w(9)
	inv.slots["active_2"] = w3
	var need := Weapon.xp_to_next(9) / 1.5
	inv.grant_weapon_xp(need + 40.0, 10)
	assert_eq(w3.level, 10)
	assert_almost(w3.xp, 40.0, 0.001, "yakalayınca normal hız")


func test_xp_only_for_slotted_unlocked_weapons() -> void:
	var inv := _inv()
	var bagged := _w(1)
	var locked := _w(20)
	var res := _w(1)
	inv.bag[0] = bagged
	inv.slots["flex"] = locked
	inv.slots["resonance"] = res
	var ups := inv.grant_weapon_xp(500.0, 10)
	assert_eq(bagged.xp + bagged.level, 1.0, "çantadaki silah XP almaz")
	assert_eq(locked.level, 20, "kilitli silah XP almaz")
	assert_almost(locked.xp, 0.0, 0.001)
	assert_true(res.level > 1, "Rezonans'taki açık silah XP alır")
	assert_true(ups.size() >= 2, "level atlayanlar raporlanır")


# --- tüccar ---

func test_prices_scale_with_floor() -> void:
	var m: Dictionary = DataDB.table("economy")["merchant"]
	var w := _w(1, "sword", "epic")
	assert_eq(Shop.item_price(w, 1), int(m["weapon_prices"]["epic"]))
	assert_eq(Shop.item_price(w, 3), int(m["weapon_prices"]["epic"]) * 3)
	assert_eq(Shop.item_price(Talisman.make("wind_feather"), 2), int(m["talisman_price"]) * 2)
	assert_eq(Shop.potion_price(4), int(m["potion_price"]) * 4)
	assert_eq(Shop.sell_price(w, 1), roundi(int(m["weapon_prices"]["epic"]) * float(m["sell_pct"])))


func test_buy_sell_and_potions() -> void:
	var inv := _inv()
	var stock: Array = [_w(1, "sword", "rare"), Talisman.make("blood_stone")]
	assert_true(Shop.buy(inv, stock, 0, 1) != "", "altın yok")
	inv.gold = 1000
	assert_eq(Shop.buy(inv, stock, 0, 1), "")
	assert_eq(inv.gold, 1000 - Shop.item_price(_w(1, "sword", "rare"), 1))
	assert_eq(stock.size(), 1, "satılan eşya tezgâhtan kalktı")
	assert_true(inv.bag[0] is Weapon, "alınan çantaya gider")
	var g := inv.gold
	assert_eq(Shop.sell(inv, Inventory.bag_ref(0), 1, false), "")
	assert_eq(inv.gold, g + Shop.sell_price(_w(1, "sword", "rare"), 1))
	assert_true(Shop.sell(inv, Inventory.slot_ref("active_1"), 1, false) != "", "son aktif silah satılamaz")
	inv.potions = 2
	assert_eq(Shop.buy_potion(inv, 1, "warrior"), "")
	assert_eq(inv.potions, 3)
	assert_true(Shop.buy_potion(inv, 1, "warrior") != "", "taşıma sınırı 3")
	inv.potions = 0
	assert_true(Shop.buy_potion(inv, 1, "ghost") != "", "Ghost iksir alamaz")
	for i: int in inv.bag.size():
		inv.bag[i] = _w(1)
	assert_true(Shop.buy(inv, stock, 0, 1).contains("dolu"), "çanta doluyken alınamaz")


# --- demirci ---

func test_blacksmith_level_up() -> void:
	var inv := _inv()
	inv.gold = 10000
	var w := _w(10)
	assert_eq(Shop.level_up_target(w, 23), 15, "bir sonraki 5'in katı")
	assert_eq(Shop.level_up_target(_w(12), 13), 13, "oyuncunun levelini geçmez")
	var per := float(DataDB.table("economy")["blacksmith"]["level_up_cost_per_level"])
	assert_eq(Shop.level_up_cost(w, 23, 2), roundi(5 * per * 2))
	assert_eq(Shop.level_up(inv, w, 23, 2), "")
	assert_eq(w.level, 15)
	assert_eq(Shop.level_up(inv, w, 23, 2), "")
	assert_eq(w.level, 20)
	assert_eq(Shop.level_up(inv, w, 23, 2), "")
	assert_eq(w.level, 23)
	assert_true(Shop.level_up(inv, w, 23, 2) != "", "oyuncunun levelinde atlatılamaz")
	inv.gold = 0
	assert_true(Shop.level_up(inv, _w(1), 10, 1) != "", "altın yok")


func test_blacksmith_rerolls() -> void:
	var inv := _inv()
	inv.gold = 10000000
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var w := Weapon.make("sword", "epic", "fire", ["fury"], 10)
	var c1 := Shop.reroll_element_cost(w, 1)
	for i: int in 8:
		var old := w.element
		assert_eq(Shop.reroll_element(inv, w, 1, rng), "")
		assert_true(w.element != old and w.element != DamageCalc.PHYSICAL, "element değişti")
	assert_true(Shop.reroll_element_cost(w, 1) > c1, "her yeniden çekme pahalılaşır")
	for j: int in 6:
		var old_t := w.traits.duplicate()
		assert_eq(Shop.reroll_traits(inv, w, 1, rng), "")
		assert_eq(w.traits.size(), 1)
		assert_true(w.traits != old_t, "özellik değişti")
	assert_true(Shop.reroll_element_block(Weapon.make("sword", "common")) != "", "yaygında element yok")
	assert_true(Shop.reroll_trait_block(Weapon.make("sword", "rare", "fire")) != "", "enderde özellik yok")
	var lw := Weapon.make_legendary("sky_rift", ["fury", "stun"], 30)
	assert_true(Shop.reroll_element_block(lw) != "", "efsanevinin elementi sabit")
	assert_eq(Shop.reroll_traits(inv, lw, 3, rng), "")
	assert_eq(lw.traits.size(), 2, "efsanevide özellik sayısı korunur")
