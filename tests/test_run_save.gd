## v0.11.1 run kaydı (kaldığın yerden devam): eşyaların ve GameState'in kayda çevrilmesi, kaydet → yükle döngüsü (katın
## durumu dahil), savaşta kaydedilmemesi, ölümde silinmesi, bozuk dosya, yeni oyunda kayıtlı run'ın bırakılması, menü.
## Dosya run_tests.gd'de ayrı (user://run_unit_tests.json): oyuncunun kaydına dokunulmaz.
extends "res://tests/test_case.gd"


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func after_each() -> void:
	_tree().paused = false
	DungeonRun.load_request = {}
	GameState.set_in_combat(false)


func _free_run(run: DungeonRun) -> void:
	run.free()
	for n: Node in _tree().get_nodes_in_group("enemies") + _tree().get_nodes_in_group("enemy_hazards"):
		n.free()
	GameState.reset_run()


func _run(seed_value: int) -> DungeonRun:
	var run := DungeonRun.new()
	run.fixed_seed = seed_value
	_tree().root.add_child(run)
	return run


func test_items_roundtrip() -> void:
	var traits: Array[String] = ["fury", "execute"]
	var w := Weapon.make("axe", "epic", "fire", traits, 17)
	w.xp = 42.5
	w.rerolls = 2
	var w2: Weapon = RunSave.item_from_dict(JSON.parse_string(JSON.stringify(RunSave.item_to_dict(w))))
	assert_eq([w2.type_id, w2.rarity_id, w2.element, Array(w2.traits), w2.level, w2.rerolls], ["axe", "epic", "fire", ["fury", "execute"], 17, 2])
	assert_almost(w2.xp, 42.5, 0.001, "silah XP'si")
	var leg: Dictionary = DataDB.table("legendaries")["weapons"][0]
	var no_traits: Array[String] = []
	var lw := Weapon.make_legendary(str(leg["id"]), no_traits, 30)
	var lw2: Weapon = RunSave.item_from_dict(RunSave.item_to_dict(lw))
	assert_eq(lw2.legendary_id, str(leg["id"]), "efsanevi kaydı")
	assert_true(lw2.is_legendary() and lw2.rarity_id == "legendary")
	var t: Talisman = RunSave.item_from_dict(RunSave.item_to_dict(Talisman.make("wind_feather")))
	assert_eq(t.id, "wind_feather", "tılsım")
	assert_eq(RunSave.item_from_dict({"kind": "weapon", "type": "yok_boyle_tip", "rarity": "common"}), null, "tanınmayan tip düşer")
	assert_eq(RunSave.item_from_dict({"kind": "talisman", "id": "yok"}), null, "tanınmayan tılsım düşer")
	assert_eq(RunSave.item_from_dict("bozuk"), null)


## Kaydet → yükle: GameState, envanter, katın durumu (temizlenen oda, açılan sandık, tüccarın tezgâhı, yerdeki eşyalar,
## merdiven), oyuncunun yeri ve canı geri gelir.
func test_save_and_load_run() -> void:
	var run := _run(31)
	assert_true(run.saves_enabled, "menüden açılan oyunda (bayraksız) kayıt açık")
	var L := run.layout
	run.set_player_level(12, 1)
	GameState.xp = 55.0
	GameState.inventory.gold = 345
	GameState.inventory.potions = 1
	GameState.buffs = {"damage": 0.12}
	GameState.special_effects.append("piercing")
	GameState.pending_rewards.append("level:10")
	GameState.damage_by_weapon_type = {"sword": 120.0, "axe": 30.0}
	GameState.kills = 17
	GameState.second_chance_used = true
	var traits: Array[String] = ["fury"]
	var axe := Weapon.make("axe", "epic", "fire", traits, 9)
	GameState.inventory.slots["active_2"] = axe
	GameState.inventory.slots["flex"] = Talisman.make("wind_feather")
	run._on_inventory_changed()
	var fight := -1
	for r: DungeonLayout.Room in L.rooms:
		if r.has_enemies() and r.type != "boss":
			fight = r.id
			break
	run.rooms[fight].state = RoomController.State.CLEARED
	run.visited[fight] = true
	var chest: RoomProp = null
	var merchant: RoomProp = null
	for p: RoomProp in run.props:
		if p.kind == "chest" and chest == null:
			chest = p
		elif p.kind == "merchant":
			merchant = p
	if chest:
		chest.opened = true
	var stock_n := -1
	if merchant:
		run._ensure_stock(merchant)
		merchant.stock.remove_at(0)
		stock_n = merchant.stock.size()
	run._add_prop("stairs", L.boss_id, L.rooms[L.boss_id].center())
	run._spawn_drop({"kind": "weapon", "item": Weapon.make("bow", "rare", "ice")}, run.player.global_position, 1.0)
	run._spawn_drop({"kind": "gold", "amount": 25}, run.player.global_position, 1.0)
	run.player.hp = run.player.max_hp * 0.5
	var hp := run.player.hp
	var pos := run.player.global_position
	var seed_value := GameState.run_seed
	assert_true(run.save_run(), "savaş dışında kaydedilir")
	var d := SaveManager.read_run()
	assert_true(not d.is_empty(), "kayıt okunur")
	assert_eq(RunSave.describe(d), "Warrior · 1. kat · Level 12", "menüdeki kısa bilgi")
	_free_run(run)

	DungeonRun.load_request = d
	var run2 := _run(-1)
	assert_true(DungeonRun.load_request.is_empty(), "istek kullanıldı")
	assert_eq(GameState.run_seed, seed_value, "aynı seed: aynı harita")
	assert_eq(run2.layout.rooms.size(), L.rooms.size())
	assert_eq([GameState.level, GameState.floor_index, GameState.kills], [12, 1, 17])
	assert_almost(GameState.xp, 55.0, 0.001)
	assert_eq([GameState.inventory.gold, GameState.inventory.potions], [345, 1])
	assert_almost(float(GameState.buffs["damage"]), 0.12, 0.0001, "ödüller")
	assert_eq(Array(GameState.special_effects), ["piercing"])
	assert_eq(Array(GameState.pending_rewards), ["level:10"], "bekleyen ödül")
	assert_almost(float(GameState.damage_by_weapon_type["axe"]), 30.0, 0.001, "ustalık için hasar payı")
	assert_true(GameState.second_chance_used)
	var a2: Weapon = GameState.inventory.slots["active_2"]
	assert_eq([a2.type_id, a2.rarity_id, a2.element, a2.level], ["axe", "epic", "fire", 9], "aktif silah")
	assert_eq((GameState.inventory.slots["flex"] as Talisman).id, "wind_feather", "Esnek slottaki tılsım")
	assert_eq(run2.rooms[fight].state, RoomController.State.CLEARED, "temizlenen oda temiz kalır")
	assert_true(run2.minimap.cleared.has(fight) and run2.visited.has(fight), "haritada da")
	for p2: RoomProp in run2.props:
		if chest and p2.kind == "chest" and p2.room_id == chest.room_id:
			assert_true(p2.opened, "açılan sandık açık kalır")
		if merchant and p2.kind == "merchant":
			assert_true(p2.stock_ready and p2.stock.size() == stock_n, "tüccardan alınan eşya geri gelmez")
	assert_eq(run2.props.filter(func(p3: RoomProp) -> bool: return p3.kind == "stairs").size(), 1, "merdiven")
	var kinds := run2.drops.map(func(dr: LootDrop) -> String: return dr.kind)
	kinds.sort()
	assert_eq(kinds, ["gold", "weapon"], "yerdeki eşyalar")
	assert_almost(run2.player.hp, hp, 0.01, "can")
	assert_true(run2.player.global_position.distance_to(pos) < 1.0, "oyuncu kaydedildiği yerde")
	_free_run(run2)


func test_no_save_in_combat_and_death_clears_it() -> void:
	var run := _run(32)
	assert_true(run.save_run())
	assert_true(SaveManager.has_run())
	GameState.set_in_combat(true)
	assert_true(not run.save_run(), "savaş sürerken kaydedilmez")
	GameState.set_in_combat(false)
	run._on_player_died()
	assert_true(not SaveManager.has_run(), "ölüm run'ı bitirir: kayıt silinir")
	assert_true(not run.save_run(), "run bittikten sonra kaydedilmez")
	_free_run(run)


func test_abandon_and_victory_clear_it() -> void:
	var run := _run(33)
	assert_true(run.save_run())
	run.abandon_run(false)
	assert_true(not SaveManager.has_run(), "run'ı bırakmak kaydı siler")
	_free_run(run)


## Ödül ekranı açıkken kaydedilirse yüklenince aynı ödül aynı rastgelelikle yeniden gelir.
func test_open_reward_screen_is_kept() -> void:
	var run := _run(34)
	var before := str(run.reward_rng.state)
	GameState.pending_rewards.append("level:5")
	run._try_open_reward()
	assert_true(run.reward_ui.visible and GameState.pending_rewards.is_empty(), "ödül ekranı açıldı")
	var d := run.run_snapshot()
	assert_eq(d["state"]["pending_rewards"], ["level:5"], "açık ödül kayda geri konur")
	assert_eq(str(d["run"]["reward_rng"]), before, "seçenekler çekilmeden önceki durum")
	run.reward_ui.close()
	_free_run(run)


func test_corrupt_run_file() -> void:
	var f := FileAccess.open(SaveManager.run_path, FileAccess.WRITE)
	f.store_string("{bozuk")
	f.close()
	SaveManager.report_errors = false
	assert_true(SaveManager.read_run().is_empty(), "bozuk kayıt yüklenmez")
	SaveManager.report_errors = true
	assert_true(not FileAccess.file_exists(SaveManager.run_path), "bozuk dosya silinir")
	assert_true(FileAccess.file_exists(SaveManager.run_path + ".bozuk"), "yedeği alınır")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.run_path + ".bozuk"))
	assert_eq(RunSave.check({"version": 99}), "bilinmeyen kayıt sürümü")
	assert_true(RunSave.check({"version": RunSave.VERSION, "state": {"race": "yok"}, "run": {}, "player": {}, "floor": {}}) != "", "bilinmeyen ırk")


func _minimal_save(floor_i: int) -> Dictionary:
	return {"version": RunSave.VERSION, "start_weapon": "", "run": {}, "player": {}, "floor": {},
		"state": {"race": "warrior", "floor": floor_i, "level": 40, "inventory": {"slots": {}},
			"damage_by_weapon_type": {"sword": 300.0}}}


## Kayıtlı run varken yeni oyun: o run bırakılır, ölüm sayılır (3. kat ×1,5 → 150 XP), kayıt silinir.
func test_new_game_discards_saved_run_as_death() -> void:
	SaveManager.write_run(_minimal_save(3))
	assert_true(SaveManager.has_run())
	RunSave.discard_saved()
	assert_true(not SaveManager.has_run(), "kayıt silindi")
	assert_almost(float(SaveManager.mastery["sword"]["xp"]), 150.0, 0.001, "ustalık 3. kattaki ölüm çarpanıyla işlendi")


## Eksik eşyalı kayıt: aktif silah kalmazsa ırkın başlangıç silahı verilir.
func test_load_without_weapons_gets_start_weapon() -> void:
	RunSave.apply_state(_minimal_save(2)["state"])
	assert_true(not GameState.inventory.active_weapons().is_empty(), "aktif silah var")
	assert_eq(GameState.floor_index, 2)
	assert_true(GameState.in_run)
	GameState.reset_run()


## Harita bu sürümde başka üretildiyse (oda tipleri uyuşmuyor) katın girişinden devam edilir.
func test_mismatched_floor_starts_at_entrance() -> void:
	var run := _run(35)
	run.player.global_position += Vector2(64, 0)
	run._safe_pos = run.player.global_position
	var d := run.run_snapshot()
	d["floor"]["types"] = "baska,harita"
	_free_run(run)
	DungeonRun.load_request = d
	var run2 := _run(-1)
	var start := run2.cell_to_world(run2.layout.rooms[run2.layout.start_id].center())
	assert_true(run2.player.global_position.distance_to(start) < 1.0, "kat girişinde")
	_free_run(run2)


func test_main_menu_load_button() -> void:
	var m0 := MainMenu.new()
	_tree().root.add_child(m0)
	assert_true(not ("YÜKLE" in m0.button_labels), "kayıt yokken YÜKLE tıklanmaz")
	m0.free()
	SaveManager.write_run(_minimal_save(2))
	var m := MainMenu.new()
	_tree().root.add_child(m)
	assert_eq(m.buttons.size(), 4, "kayıt varken 4 düğme")
	if m.video != null:
		assert_eq(m.button_labels, ["YENİ OYUN", "YÜKLE", "AYARLAR", "ÇIKIŞ"])
	var infos := m.find_children("*", "Label", true, false).filter(func(l: Node) -> bool: return "2. kat" in str((l as Label).text))
	assert_eq(infos.size(), 1, "kaydın kısa bilgisi yazar")
	m._on_start()
	assert_true(m.is_confirming(), "kayıt varken yeni oyun önce sorulur")
	m._close_confirm()
	assert_true(not m.is_confirming())
	m._on_load()
	assert_eq(str(DungeonRun.load_request["state"]["race"]), "warrior", "kayıt zindana verilir")
	assert_eq(str(TestRoom.config["race"]), "warrior")
	m.free()
	SaveManager.clear_run()
