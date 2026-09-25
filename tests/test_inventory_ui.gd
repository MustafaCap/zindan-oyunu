## Aşama 5 — envanter arayüzü (sürükle-bırak, sağ tık, yere bırakma, tüccar, demirci, tooltip) ve zindanda loot
## (düşman loot'u, altın/iksir toplama, F ile alma, sandık, tüccar tezgâhı, çanta kısayolu).
extends "res://tests/test_case.gd"

var _world: Node2D


func before_each() -> void:
	_world = Node2D.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(_world)
	GameState.start_run("warrior")
	GameState.level = 10


func after_each() -> void:
	(Engine.get_main_loop() as SceneTree).paused = false
	_world.free()
	GameState.set_in_combat(false)
	GameState.reset_run()


func _setup() -> Array:
	var p := Player.new()
	p.race_id = "warrior"
	p.level = 10
	p.inventory = GameState.inventory
	_world.add_child(p)
	var ui := InventoryUI.new()
	_world.add_child(ui)
	return [ui, p]


func test_drag_and_drop_moves_and_swaps() -> void:
	var s := _setup()
	var ui: InventoryUI = s[0]
	var p: Player = s[1]
	var inv := GameState.inventory
	var axe := Weapon.make("axe", "rare", "fire", [], 5)
	inv.bag[0] = axe
	ui.open_ui("bag", p)
	assert_true((Engine.get_main_loop() as SceneTree).paused, "çanta açıkken oyun durur")
	var changes := [0]
	ui.changed.connect(func() -> void: changes[0] += 1)
	var from: ItemSlot = ui._bag_nodes[0]
	var to: ItemSlot = ui._slot_nodes["active_2"]
	var data: Variant = ui.drag_data_for(from)
	assert_true(data != null, "dolu gözden sürüklenir")
	assert_true(ui.can_drop(data, to), "boş aktif slota bırakılabilir")
	ui.do_drop(data, to)
	assert_eq(inv.slots["active_2"], axe)
	assert_eq(changes[0], 1, "değişiklik bildirildi")
	# Kilitli silah aktif slota bırakılamaz, Rezonans'a bırakılabilir
	inv.bag[1] = Weapon.make("bow", "epic", "ice", ["fury"], 40)
	var d2: Variant = ui.drag_data_for(ui._bag_nodes[1])
	assert_true(not ui.can_drop(d2, ui._slot_nodes["active_1"]), "kilitli → aktif olmaz")
	assert_true(ui.can_drop(d2, ui._slot_nodes["resonance"]), "kilitli → Rezonans olur")
	# Boş göz sürüklenmez
	assert_eq(ui.drag_data_for(ui._bag_nodes[5]), null)
	# Savaşta slota bırakılamaz
	GameState.set_in_combat(true)
	assert_true(not ui.can_drop(d2, ui._slot_nodes["resonance"]), "savaşta slot kilitli")
	assert_true(ui.can_drop(d2, ui._bag_nodes[7]), "savaşta çanta içi serbest")
	GameState.set_in_combat(false)
	ui.close()
	assert_true(not (Engine.get_main_loop() as SceneTree).paused, "kapanınca oyun devam eder")


func test_quick_action_equips_and_unequips() -> void:
	var s := _setup()
	var ui: InventoryUI = s[0]
	var inv := GameState.inventory
	ui.open_ui("bag", s[1])
	inv.bag[2] = Weapon.make("mace", "rare", "water", [], 3)
	inv.bag[3] = Weapon.make("tome", "rare", "dark", [], 60)
	inv.bag[4] = Talisman.make("wind_feather")
	ui.quick_action(ui._bag_nodes[2])
	assert_true(inv.slots["active_2"] is Weapon and (inv.slots["active_2"] as Weapon).type_id == "mace", "boş aktif slota takıldı")
	ui.quick_action(ui._bag_nodes[3])
	assert_true((inv.slots["resonance"] as Weapon).type_id == "tome", "kilitli silah Rezonans'a")
	ui.quick_action(ui._bag_nodes[4])
	assert_true(inv.slots["flex"] is Talisman, "tılsım Esnek'e")
	ui.quick_action(ui._slot_nodes["flex"])
	assert_eq(inv.slots["flex"], null, "slottaki çantaya çıktı")
	# İki aktif dolu: çantadaki açık silah kullanılan aktif silahla yer değiştirir
	inv.bag[8] = Weapon.make("dagger", "common", "physical", [], 1)
	var old: Weapon = inv.slots[inv.active_slot]
	var idx := inv.bag.find(null)
	ui.quick_action(ui._bag_nodes[8])
	assert_eq((inv.slots[inv.active_slot] as Weapon).type_id, "dagger")
	assert_eq(inv.bag[8], old, "eski aktif silah çantaya")
	assert_true(idx >= 0)


func test_drop_zone_puts_item_on_ground() -> void:
	var s := _setup()
	var ui: InventoryUI = s[0]
	var inv := GameState.inventory
	ui.open_ui("bag", s[1])
	inv.bag[0] = Weapon.make("axe", "rare", "fire")
	var dropped := []
	ui.drop_requested.connect(func(it: Variant) -> void: dropped.append(it))
	var data: Variant = ui.drag_data_for(ui._bag_nodes[0])
	assert_true(ui.can_drop(data, ui._drop_slot))
	ui.do_drop(data, ui._drop_slot)
	assert_eq(dropped.size(), 1)
	assert_eq(inv.bag[0], null)
	var d2: Variant = ui.drag_data_for(ui._slot_nodes["active_1"])
	assert_true(not ui.can_drop(d2, ui._drop_slot), "son aktif silah bırakılamaz")


func test_merchant_panel_buy_and_sell() -> void:
	var s := _setup()
	var ui: InventoryUI = s[0]
	var inv := GameState.inventory
	inv.gold = 1000
	var prop := RoomProp.new()
	prop.kind = "merchant"
	prop.stock = [Weapon.make("sword", "epic", "ice", ["stun"], 1), Talisman.make("element_heart")]
	prop.stock_ready = true
	_world.add_child(prop)
	ui.open_ui("merchant", s[1], prop)
	assert_true(ui._side_panel.visible and ui._merchant_box.visible, "tüccar paneli açık")
	assert_eq(ui._stock_slots.size(), 2)
	var price := Shop.item_price(prop.stock[0], 1)
	ui.buy_stock(0)
	assert_eq(inv.gold, 1000 - price)
	assert_eq(prop.stock.size(), 1)
	var bi := -1
	for i: int in inv.bag.size():
		if inv.bag[i] != null:
			bi = i
	assert_true(bi >= 0, "alınan çantada")
	ui.select_slot(ui._bag_nodes[bi])
	assert_true(not ui._sell_button.disabled, "seçili eşya satılabilir")
	var g := inv.gold
	ui.sell_selected()
	assert_eq(inv.bag[bi], null)
	assert_eq(inv.gold, g + roundi(price * 0.3))
	inv.potions = 0
	ui.buy_potion()
	assert_eq(inv.potions, 1, "iksir alındı")
	# Sürükleyerek sat
	inv.bag[3] = Weapon.make("bow", "rare", "fire")
	var data: Variant = ui.drag_data_for(ui._bag_nodes[3])
	assert_true(ui.can_drop(data, ui._sell_slot))
	ui.do_drop(data, ui._sell_slot)
	assert_eq(inv.bag[3], null, "sürüklenen satıldı")


func test_blacksmith_panel() -> void:
	var s := _setup()
	var ui: InventoryUI = s[0]
	var inv := GameState.inventory
	inv.gold = 5000
	var w := Weapon.make("axe", "epic", "fire", ["fury"], 1)
	inv.bag[0] = w
	ui.open_ui("blacksmith", s[1], null)
	assert_true(ui._smith_box.visible)
	var data: Variant = ui.drag_data_for(ui._bag_nodes[0])
	assert_true(ui.can_drop(data, ui._smith_slot))
	ui.do_drop(data, ui._smith_slot)
	assert_eq(ui.smith_weapon(), w, "örste")
	assert_true(not (ui._smith_buttons["level"] as Button).disabled)
	ui.smith_action("level")
	assert_eq(w.level, 5)
	var el := w.element
	ui.smith_action("element")
	assert_true(w.element != el)
	ui.smith_action("traits")
	assert_true(w.traits != ["fury"])
	ui.select_slot(ui._slot_nodes["active_1"])
	assert_eq(ui.smith_weapon(), inv.slots["active_1"], "seçmek de örse koyar")
	assert_true((ui._smith_buttons["element"] as Button).disabled, "yaygında element yok")


func test_tooltip_compares_with_active_weapon() -> void:
	var s := _setup()
	var ui: InventoryUI = s[0]
	var inv := GameState.inventory
	inv.bag[0] = Weapon.make("axe", "epic", "fire", ["fury"], 10)
	ui.open_ui("bag", s[1])
	ui.on_slot_hover(ui._bag_nodes[0], true)
	var txt := ui._tooltip_text.text
	assert_true(ui._tooltip.visible)
	assert_true(txt.contains("Aktif silahla kıyas (Kılıç)") and txt.contains("DPS"), "aktif silahla karşılaştırma: %s" % txt)
	assert_true(txt.contains("Öfke"), "özellik")
	assert_true(txt.contains("Rezonans'ta"), "Rezonans değeri")
	ui.on_slot_hover(ui._bag_nodes[0], false)
	assert_true(not ui._tooltip.visible)
	var lt := WeaponInfo.tooltip(Weapon.make_legendary("sky_rift", ["fury"], 60), "warrior", 10)
	assert_true(lt.contains("KİLİTLİ") and lt.contains("Efsanevi pasif") and lt.contains("Sağ tık eki"))


## Zindanda: düşman ölünce loot düşer, altın yaklaşınca toplanır, silah F ile alınır; sandık ve tüccar.
func test_dungeon_loot_flow() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var run := DungeonRun.new()
	run.fixed_seed = 11
	run.god = true
	tree.root.add_child(run)
	GameState.level = 1
	var inv := GameState.inventory
	assert_eq((inv.slots["active_1"] as Weapon).type_id, "sword", "Warrior kılıçla başlar")
	assert_eq(run.player.weapons.size(), 1)
	# Düşman ölünce altın düşer ve yaklaşınca toplanır
	var e := EnemyMelee.new()
	e.enemy_id = "skeleton_warrior"
	run.world.add_child(e)
	e.global_position = run.player.global_position + Iso.to_screen(Vector2(1.5, 0) * Iso.KARO)
	e.execute(Vector2.RIGHT)
	var golds := run.drops.filter(func(d: LootDrop) -> bool: return d.kind == "gold")
	assert_eq(golds.size(), 1, "altın düştü")
	for d: LootDrop in golds:
		d.global_position = run.player.global_position
	run._update_drops()
	assert_true(inv.gold > 0, "altın toplandı")
	# Silah F ile alınır: boş aktif slota takılır
	var w := Weapon.make("staff", "rare", "lightning")
	var drop := run._spawn_drop({"kind": "weapon", "item": w}, run.player.global_position, 0.0)
	drop.global_position = run.player.global_position
	assert_eq(run.nearest_prop(), drop, "en yakın etkileşim yerdeki silah")
	assert_true(run.try_interact())
	assert_eq(inv.slots["active_2"], w, "boş aktif slota takıldı")
	assert_eq(run.player.weapons.size(), 2, "oyuncunun silahları yenilendi")
	# İksir üstünden geçince (sınır doluysa kalır)
	inv.potions = 3
	var pd := run._spawn_drop({"kind": "potion"}, run.player.global_position, 0.0)
	pd.global_position = run.player.global_position
	run._update_drops()
	assert_true(is_instance_valid(pd) and not pd.picked, "taşıma sınırı doluyken iksir yerde kalır")
	inv.potions = 1
	run._update_drops()
	assert_eq(inv.potions, 2, "iksir alındı")
	# Sandık: altın + eşya saçar
	var chest: RoomProp = null
	var merchant: RoomProp = null
	for p: RoomProp in run.props:
		if p.kind == "chest" and chest == null:
			chest = p
		elif p.kind == "merchant":
			merchant = p
	var before := run.drops.size()
	run.player.global_position = chest.global_position
	assert_true(run.try_interact())
	assert_true(chest.opened)
	assert_true(run.drops.size() >= before + 2, "sandık loot saçtı")
	# Tüccar: tezgâh kat başına bir kez üretilir, arayüz açılır
	run.player.global_position = merchant.global_position
	run.try_interact()
	assert_true(run.bag_ui.visible and run.bag_ui.mode == "merchant", "tüccar arayüzü açıldı")
	var stock_sig := str(merchant.stock.map(func(it: Variant) -> String: return _item_id(it)))
	run.bag_ui.close()
	run.try_interact()
	assert_eq(str(merchant.stock.map(func(it: Variant) -> String: return _item_id(it))), stock_sig, "tezgâh aynı kaldı")
	run.bag_ui.close()
	# I: çanta
	var ev := InputEventKey.new()
	ev.keycode = KEY_I
	ev.pressed = true
	run._unhandled_input(ev)
	assert_true(run.bag_ui.visible and run.bag_ui.mode == "bag")
	run.bag_ui.close()
	run.free()
	for n: Node in tree.get_nodes_in_group("enemies"):
		n.free()


func _item_id(it: Variant) -> String:
	if it is Weapon:
		var w := it as Weapon
		return "%s/%s/%s/%d" % [w.type_id, w.rarity_id, w.element, w.level]
	return (it as Talisman).id


## Geçici kural: 2. kata inince level en az 15 olur (Aşama 6'ya kadar); kilidi açılan silahlar bildirilir.
func test_interim_floor_min_level_and_unlock() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var run := DungeonRun.new()
	run.fixed_seed = 12
	tree.root.add_child(run)
	GameState.inventory.bag[0] = Weapon.make("axe", "rare", "fire", [], 12)
	run.set_player_level(1)
	assert_eq(run.player.level, 1)
	run.enter_floor(2)
	assert_eq(GameState.level, 15, "2. katta en az level 15")
	assert_eq(run.player.level, 15)
	assert_true(not (GameState.inventory.bag[0] as Weapon).is_locked(GameState.level), "kilidi açıldı")
	run.free()
	for n: Node in tree.get_nodes_in_group("enemies"):
		n.free()
