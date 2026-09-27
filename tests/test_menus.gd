## Aşama 10: menüler — ana menü, ırk seçimi, duraklatma menüsü (run'ı bırakmak ölüm sayılır), run sonu ekranı,
## F5 geliştirici menüsü, ortak tema.
extends "res://tests/test_case.gd"


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	return e


func after_each() -> void:
	_tree().paused = false


func test_theme_has_dark_buttons_and_serif_font() -> void:
	var t := UiTheme.theme()
	assert_true(t.default_font is SystemFont, "yazı tipi sistemin serif fontu (dosya eklenmez)")
	var hover := t.get_stylebox("hover", "Button") as StyleBoxFlat
	assert_eq(hover.border_color, UiTheme.BLOOD_LIGHT, "üzerine gelince kan kırmızısı çerçeve")
	assert_true(hover.border_width_left > hover.border_width_top, "solda kalın kan izi")
	assert_true(UiTheme.theme() == t, "tema bir kez kurulur")


func test_main_menu_has_three_buttons_and_no_title() -> void:
	var m := MainMenu.new()
	_tree().root.add_child(m)
	if m.video != null:   # videodaki gömülü yazılar düğme; YÜKLE soluk ve düğmesiz (kullanıcı kararı)
		assert_eq(m.button_labels, ["YENİ OYUN", "AYARLAR", "ÇIKIŞ"])
		assert_true(m.video.loop, "sakin döngü sıçramasız döner")
	else:
		assert_eq(m.button_labels, ["Başla", "Ses ayarları", "Çık"])
	assert_eq(m.buttons.size(), 3)
	var labels := m.find_children("*", "Label", true, false)
	for l: Node in labels:
		assert_true(str((l as Label).text).begins_with("v"), "oyun adı yazılmaz (yalnızca sürüm): '%s'" % (l as Label).text)
	m.free()


func test_race_select_describes_each_race() -> void:
	SaveManager.mastery["dagger"] = {"level": 4, "xp": 0.0}
	for id: String in RaceSelect.ORDER:
		var r: Dictionary = DataDB.table("races")[id]
		var txt := RaceSelect.describe(id)
		assert_true(str(r["abilities"]["q"]["name"]) in txt and str(r["abilities"]["e"]["name"]) in txt, "%s: Q ve E" % id)
		assert_true("Can [b]%d[/b]" % int(r["base_hp"]) in txt, "%s: can" % id)
		assert_true(str(r["resource"]["name"]) in txt, "%s: kaynak" % id)
	assert_true("Hançer · ustalık Lv 4" in RaceSelect.describe("ghost"), "başlangıç silahının kalıcı ustalığı")


func test_race_select_writes_config() -> void:
	TestRoom.config = {}
	RaceSelect.prefs_path = "user://menu_unit_tests.json"
	DirAccess.remove_absolute(RaceSelect.prefs_path)
	var rs := RaceSelect.new()
	_tree().root.add_child(rs)
	assert_eq(rs.selected, "warrior", "varsayılan Warrior")
	assert_eq(rs.cards.size(), 4)
	rs._unhandled_input(_key(KEY_RIGHT))
	assert_eq(rs.selected, "ghost", "→ sonraki ırk")
	rs._unhandled_input(_key(KEY_4))
	assert_eq(rs.selected, "magical", "4 tuşu")
	# v0.10.1: kartın altında ailenin 3 silahı; varsayılan asa, ↓ ile sonraki (rün), düğmeyle kitap
	assert_eq((rs.weapon_buttons["magical"] as Dictionary).size(), 3, "3 silah düğmesi")
	assert_eq(str(rs.start_choice["magical"]), "staff", "varsayılan başlangıç silahı")
	rs._unhandled_input(_key(KEY_DOWN))
	assert_eq(str(rs.start_choice["magical"]), "rune", "↓ sonraki silah")
	(rs.weapon_buttons["magical"]["tome"] as Button).pressed.emit()
	assert_eq(str(rs.start_choice["magical"]), "tome", "düğmeyle seçilir")
	assert_true("Kitap · ustalık" in (rs.texts["magical"] as RichTextLabel).text, "kart metni seçilen silahı yazar")
	(rs.weapon_buttons["warrior"]["axe"] as Button).pressed.emit()
	assert_eq(rs.selected, "warrior", "başka ırkın silah düğmesi o ırkı seçer")
	rs.select("magical")
	rs.start_run()
	assert_eq(str(TestRoom.config["race"]), "magical", "seçim run'a gider")
	assert_eq(str(TestRoom.config["start_weapon"]), "tome", "başlangıç silahı run'a gider")
	assert_eq(int(TestRoom.config["level"]), 1)
	rs.free()
	GameState.start_run("magical", "tome")
	var w: Weapon = GameState.inventory.slots["active_1"]
	assert_true(w.type_id == "tome" and w.rarity_id == "common" and w.level == 1, "run Yaygın level 1 kitapla başlar")
	GameState.start_run("magical", "sword")
	assert_eq((GameState.inventory.slots["active_1"] as Weapon).type_id, "staff", "başka aileden seçim geçersiz → varsayılan")
	GameState.reset_run()
	# Bir sonraki açılışta aynı ırk ve silahlar seçili gelir (oyun yeniden açılsa da: dosyadan)
	TestRoom.config = {}
	var rs2 := RaceSelect.new()
	_tree().root.add_child(rs2)
	assert_eq(rs2.selected, "magical")
	assert_eq(str(rs2.start_choice["magical"]), "tome", "silah seçimi hatırlanır")
	assert_eq(str(rs2.start_choice["warrior"]), "axe", "diğer ırkların seçimi de")
	rs2.free()
	DirAccess.remove_absolute(RaceSelect.prefs_path)
	RaceSelect.prefs_path = "user://menu.json"


func test_pause_menu_pauses_and_confirms_abandon() -> void:
	var pm := PauseMenu.new()
	_tree().root.add_child(pm)
	var got: Array = []
	pm.abandon_requested.connect(func(q: bool) -> void: got.append(q))
	pm.open()
	assert_true(pm.visible and _tree().paused, "açıkken oyun durur")
	assert_eq(pm.buttons.map(func(b: Button) -> String: return b.text), ["Devam  (Esc)", "Ses ayarları", "Ana menüye dön", "Oyundan çık"])
	pm._ask(false)
	assert_true(pm.is_confirming(), "ana menüye dönmeden önce onay sorulur")
	pm._unhandled_input(_key(KEY_ESCAPE))
	assert_true(not pm.is_confirming() and pm.visible, "Esc onaydan vazgeçer")
	pm._unhandled_input(_key(KEY_ESCAPE))
	assert_true(not pm.visible and not _tree().paused, "Esc menüyü kapatır, oyun sürer")
	pm.open()
	pm._ask(true)
	pm._confirmed()
	assert_eq(got, [true], "oyundan çık onaylandı")
	# Test odasında run yok: onaysız
	var got2: Array = []
	pm.in_run = false
	pm.leave_requested.connect(func(q: bool) -> void: got2.append(q))
	pm.open()
	pm._ask(false)
	assert_eq(got2, [false])
	pm.free()


func test_abandon_run_counts_as_death() -> void:
	var run := DungeonRun.new()
	run.fixed_seed = 5
	_tree().root.add_child(run)
	run.enter_floor(3)
	GameState.damage_by_weapon_type = {"sword": 300.0}
	run.abandon_run(false)
	assert_true(run.finished)
	assert_eq(str(run.last_summary["depth_key"]), "death_floor_3", "3. katta ölüm sayılır")
	assert_true(bool(run.last_summary["abandoned"]))
	assert_true(bool(run.last_summary["saved"]), "ustalık kaydedildi")
	assert_almost(float(SaveManager.mastery["sword"]["xp"]), 150.0, 0.001, "×1,5 → 150 XP")
	assert_true(run.summary.visible, "özet ekranı açılır")
	assert_true(_tree().paused, "dünya durur")
	assert_true("RUN BIRAKILDI" in run.summary._title.text)
	_tree().paused = false
	run.free()
	for n: Node in _tree().get_nodes_in_group("enemies"):
		n.free()


func test_esc_opens_pause_and_f5_opens_debug_menu() -> void:
	var run := DungeonRun.new()
	run.fixed_seed = 6
	_tree().root.add_child(run)
	run._unhandled_input(_key(KEY_M))
	assert_true(not run.menu.visible, "M artık hata ayıklama menüsünü açmaz")
	run._unhandled_input(_key(KEY_F5))
	assert_true(run.menu.visible, "F5 geliştirici menüsünü açar")
	run.menu._unhandled_input(_key(KEY_F5))
	assert_true(not run.menu.visible, "F5 kapatır")
	run._unhandled_input(_key(KEY_ESCAPE))
	assert_true(run.pause.visible and _tree().paused, "Esc duraklatma menüsünü açar (oyundan çıkmaz)")
	run.pause.close()
	run.free()
	for n: Node in _tree().get_nodes_in_group("enemies"):
		n.free()


func test_run_summary_title_then_details_and_keys() -> void:
	var s := RunSummary.new()
	_tree().root.add_child(s)
	var asked: Array = []
	s.new_run_requested.connect(func() -> void: asked.append("new"))
	s.main_menu_requested.connect(func() -> void: asked.append("menu"))
	var info := {"victory": true, "floor": 4, "level": 80, "time": 2290.0, "kills": 400, "gold": 900, "xp": 71000.0,
		"depth_key": "victory", "mastery": [], "first_kills": ["Nyx'thar, Yankısız"], "rewards": [], "saved": true,
		"subtitle": "Nyx'thar, Yankısız düştü. Zindan temizlendi."}
	s.show_summary(info)
	assert_eq(s._title.text, "KAZANDIN")
	assert_true(not s.details_visible(), "önce yalnızca başlık")
	s._unhandled_input(_key(KEY_R))
	assert_eq(asked, [], "özet açılmadan R yeni run başlatmaz")
	s.show_details()
	assert_true(s.details_visible())
	s._unhandled_input(_key(KEY_R))
	s._unhandled_input(_key(KEY_ESCAPE))
	assert_eq(asked, ["new", "menu"], "R yeni run, Esc ana menü")
	var txt := RunSummary.summary_text(info)
	assert_true("38:10" in txt and "×3" in txt and "Nyx'thar" in txt, "süre, zafer çarpanı, ilk kesiş")
	info["victory"] = false
	s.show_summary(info)
	assert_eq(s._title.text, "ÖLDÜN")
	s.free()
