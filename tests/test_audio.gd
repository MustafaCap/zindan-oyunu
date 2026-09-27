## Aşama 9 (ses): ses dosyaları, veri eşlemeleri, kanallar, çalma sınırları, müzik geçişleri, olay sesleri ve ayar kaydı.
extends "res://tests/test_case.gd"

const DataDBScript := preload("res://scripts/autoload/data_db.gd")
const SETTINGS_TEST_PATH := "user://settings_unit_tests.json"

var _saved_volumes: Dictionary
var _saved_muted: bool
var _saved_path: String


func before_each() -> void:
	super.before_each()
	_saved_volumes = Audio.volumes.duplicate()
	_saved_muted = Audio.muted
	_saved_path = Audio.settings_path
	Audio.enabled = true
	_reset_limits()


func after_each() -> void:
	Audio.settings_path = _saved_path
	Audio.volumes = _saved_volumes
	Audio.muted = _saved_muted
	Audio.apply_volumes()
	Audio.stop_music(0.0)
	super.after_each()


func _reset_limits() -> void:
	Audio.set("_last_ms", {})
	for p: Node in Audio.get_children():
		if p is AudioStreamPlayer or p is AudioStreamPlayer2D:
			if p.get_meta("sid", "") != "":
				p.call("stop")


func _sounds() -> Dictionary:
	return DataDB.table("audio")["sounds"]


func test_every_sound_has_its_files() -> void:
	var n := 0
	for id: String in DataDB.records(_sounds()):
		var count := int(_sounds()[id]["variants"])
		for i: int in range(1, count + 1):
			assert_true(ResourceLoader.exists("res://assets/audio/sfx/%s_%d.wav" % [id, i]), "dosya yok: %s_%d" % [id, i])
		assert_true(not ResourceLoader.exists("res://assets/audio/sfx/%s_%d.wav" % [id, count + 1]), "fazla varyant: %s_%d" % [id, count + 1])
		assert_true(Audio.has_sound(id), "yüklenmedi: " + id)
		n += 1
	assert_true(n >= 130, "en az 130 ses (%d)" % n)


func test_music_tracks_exist_and_loop() -> void:
	var tracks: Dictionary = DataDB.table("audio")["music"]["tracks"]
	for id: String in DataDB.records(tracks):
		var path := "res://assets/audio/music/" + str(tracks[id]["file"])
		assert_true(ResourceLoader.exists(path), "müzik yok: " + path)
		var s: AudioStream = load(path)
		assert_true(s is AudioStreamOggVorbis, "OGG olmalı: " + id)
		assert_true(s.get_length() >= 25.0, "%s en az 25 sn (%.1f)" % [id, s.get_length()])
		assert_true((s as AudioStreamOggVorbis).loop, "döngü açık olmalı: " + id)
	for f: String in ["1", "2", "3", "4"]:
		assert_true(tracks.has(str(DataDB.table("audio")["music"]["floors"][f])), "%s. kat müziği" % f)


## Koddaki her Audio.play("…") çağrısı var olan bir sese gider (yazım hatası sessiz kalmasın).
func test_code_references_existing_sounds() -> void:
	var re := RegEx.new()
	re.compile("Audio\\.play(?:_ui)?\\(\"([a-z0-9_]+)\"\\s*[,)]")
	var found := 0
	for path: String in _gd_files("res://scripts"):
		var text := FileAccess.get_file_as_string(path)
		for m: RegExMatch in re.search_all(text):
			found += 1
			assert_true(_sounds().has(m.get_string(1)), "%s: bilinmeyen ses '%s'" % [path, m.get_string(1)])
	assert_true(found >= 30, "kodda en az 30 doğrudan ses çağrısı (%d)" % found)
	for r: String in DataDB.table("rarities").keys():
		assert_true(_sounds().has("loot_" + r), "nadirlik sesi yok: loot_" + r)


func _gd_files(dir: String) -> Array[String]:
	var out: Array[String] = []
	for f: String in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir + "/" + f)
	for d: String in DirAccess.get_directories_at(dir):
		out.append_array(_gd_files(dir + "/" + d))
	return out


func test_every_weapon_ability_and_combo_has_a_sound() -> void:
	for wt: String in DataDB.records(DataDB.table("weapon_types")):
		for k: String in ["light", "heavy"]:
			assert_true(Audio.has_sound(Audio.sound_for("weapons.%s.%s" % [wt, k])), "%s %s sesi" % [wt, k])
	for race: String in DataDB.records(DataDB.table("races")):
		for slot: String in ["q", "e"]:
			var aid := str(DataDB.table("races")[race]["abilities"][slot]["id"])
			assert_true(Audio.has_sound(Audio.sound_for("abilities." + aid)), "yetenek sesi: " + aid)
	for c: Dictionary in DataDB.table("elements")["combos"]:
		assert_true(Audio.has_sound(Audio.sound_for("combos." + str(c["id"]))), "kombo sesi: " + str(c["id"]))
	for el: String in DataDB.table("elements")["elements"].keys():
		assert_true(Audio.has_sound(Audio.sound_for("elements." + el)), "element sesi: " + el)


func test_bad_audio_reference_gives_clear_error() -> void:
	var dir := "user://test_tmp/audio_bad"
	DirAccess.make_dir_recursive_absolute(dir)
	for f: String in DirAccess.get_files_at("res://data"):
		if f.ends_with(".json"):
			var t := FileAccess.get_file_as_string("res://data/" + f)
			if f == "audio.json":
				var a: Dictionary = JSON.parse_string(t)
				a["weapons"]["sword"]["light"] = "olmayan_ses"
				(a["weapons"] as Dictionary).erase("bow")
				t = JSON.stringify(a)
			var fa := FileAccess.open(dir + "/" + f, FileAccess.WRITE)
			fa.store_string(t)
			fa.close()
	var db: Node = DataDBScript.new()
	db.report_errors = false
	assert_true(not db.load_all(dir), "hatalı ses eşlemesi yüklemeyi durdurmalı")
	var text := "\n".join(db.errors)
	assert_true(text.contains("audio.weapons.sword.light: bilinmeyen ses 'olmayan_ses'"), "bilinmeyen ses hatası: " + text)
	assert_true(text.contains("audio.weapons: 'bow' silah tipi için ses yok"), "eksik silah sesi hatası: " + text)
	db.free()


func test_buses_and_limiter() -> void:
	for b: String in ["Music", "SFX", "UI"]:
		var i := AudioServer.get_bus_index(b)
		assert_true(i > 0, "kanal yok: " + b)
		assert_eq(AudioServer.get_bus_send(i), &"Master", b + " Master'a gitmeli")
	var m := AudioServer.get_bus_index("Master")
	var lim := false
	for k: int in AudioServer.get_bus_effect_count(m):
		if AudioServer.get_bus_effect(m, k) is AudioEffectHardLimiter:
			lim = true
	assert_true(lim, "Master'da tepe sınırlayıcı")


func test_play_respects_gap_poly_and_unknown() -> void:
	assert_true(Audio.play("door_slam") != null, "ilk çalma")
	assert_true(Audio.play("door_slam") == null, "gap (0,3 sn) dolmadan ikinci çalma yok")
	assert_true(Audio.play("olmayan_ses") == null, "bilinmeyen ses sessizce atlanır")
	_reset_limits()
	var poly := int(_sounds()["hit_flesh"]["poly"])
	var played := 0
	for i: int in poly + 3:
		Audio.set("_last_ms", {})
		if Audio.play("hit_flesh", Vector2(100, 100)) != null:
			played += 1
	assert_eq(played, poly, "aynı anda en fazla poly kadar")
	Audio.enabled = false
	_reset_limits()
	assert_true(Audio.play("dash") == null, "kapalıyken çalmaz")
	Audio.enabled = true


func test_pool_steals_oldest_when_full() -> void:
	var ids: Array = DataDB.records(_sounds())
	var world := int(DataDB.table("audio")["pool"]["world"])
	var ok := 0
	for i: int in world + 10:
		Audio.set("_last_ms", {})
		if Audio.play(str(ids[i % ids.size()]), Vector2(i * 10, 0)) != null:
			ok += 1
	assert_true(ok >= world, "havuz dolunca en eski ses kesilip yenisi çalar (%d)" % ok)


func test_enemy_body_and_hit_sounds() -> void:
	var sk := Enemy.new()
	sk.enemy_id = "skeleton_warrior"
	assert_eq(Audio.body_of(sk), "bone")
	sk.material_id = "ghost"
	assert_eq(Audio.body_of(sk), "ghost", "Hayalet malzemesi gövdeyi değiştirir")
	var rat := Enemy.new()
	rat.enemy_id = "cave_rat"
	assert_eq(Audio.body_of(rat), "flesh")
	var guard := Enemy.new()
	guard.enemy_id = "iron_guard"
	assert_eq(Audio.body_of(guard), "metal")
	var kd := Boss.create("kordrak")
	assert_eq(Audio.body_of(kd), "stone", "Kordrak taş")
	_reset_limits()
	Audio.enemy_hit(rat, false, false)
	assert_eq(Audio.last_played, "hit_flesh")
	_reset_limits()
	Audio.enemy_hit(rat, false, true)
	assert_eq(Audio.last_played, "hit_heavy")
	_reset_limits()
	Audio.enemy_hit(sk, false, false)
	assert_eq(Audio.last_played, "hit_ghost")
	_reset_limits()
	Audio.enemy_hit(guard, true, false)
	assert_eq(Audio.last_played, "hit_metal", "kritikte parlama + gövde sesi")
	for n: Node in [sk, rat, guard, kd]:
		n.free()


func test_hazard_sound_lookup() -> void:
	Audio.hazard_fired("anvil_slam", "burst", "physical", Vector2.ZERO)
	assert_eq(Audio.last_played, "anvil_slam", "etikete göre")
	_reset_limits()
	Audio.hazard_fired("vein_mass_death", "burst", "physical", Vector2.ZERO)
	assert_eq(Audio.last_played, "flesh_burst", "ölüm patlaması")
	_reset_limits()
	Audio.hazard_fired("spore_cloud", "zone", "poison", Vector2.ZERO)
	assert_eq(Audio.last_played, "gas", "biçim ve türe göre")
	_reset_limits()
	Audio.last_played = ""
	Audio.hazard_fired("bilinmeyen", "visual", "physical", Vector2.ZERO)
	assert_eq(Audio.last_played, "", "görsel işaretin kendi sesi yok")


func test_events_play_sounds() -> void:
	Events.player_dashed.emit(Vector2(10, 10))
	assert_eq(Audio.last_played, "dash")
	Events.combo_triggered.emit("melt", null)
	assert_eq(Audio.last_played, "combo_melt")
	var e := Enemy.new()
	e.enemy_id = "skeleton_archer"
	Events.enemy_killed.emit(e, true, false)
	assert_eq(Audio.last_played, "death_elite", "elitte gövde ölüm sesinden sonra elit vurgusu")
	e.free()
	_reset_limits()
	Events.level_up.emit(5)
	assert_eq(Audio.last_played, "level_up")


func test_music_follows_floor_boss_and_run_end() -> void:
	Events.floor_entered.emit(2)
	assert_eq(Audio.music_id, "floor_2", "kat ambiyansı")
	Events.boss_fight_started.emit("mycela")
	assert_eq(Audio.music_id, "boss_mycela", "boss müziği")
	assert_eq(Audio.last_played, "roar_mycela", "boss kükremesi")
	Audio.play_music("boss_mycela")
	assert_eq(Audio.music_id, "boss_mycela", "aynı parça yeniden başlamaz")
	_reset_limits()
	Events.run_ended.emit(true, 4)
	assert_eq(Audio.music_id, "", "run bitince müzik söner")
	assert_eq(Audio.last_played, "victory")
	_reset_limits()
	Events.run_ended.emit(false, 2)
	assert_eq(Audio.last_played, "defeat")


func test_settings_save_load_and_repair() -> void:
	Audio.settings_path = SETTINGS_TEST_PATH
	Audio.set_volume("Music", 0.3)
	Audio.set_volume("SFX", 1.7)
	Audio.set_muted(true)
	assert_almost(float(Audio.volumes["SFX"]), 1.0, 0.0001, "0-1'e sıkıştırılır")
	assert_true(Audio.save_settings(), "ayar dosyası yazılır")
	Audio.set_volume("Music", 0.9)
	Audio.set_muted(false)
	Audio.load_settings()
	assert_almost(float(Audio.volumes["Music"]), 0.3, 0.0001, "geri okunur")
	assert_true(Audio.muted, "sessiz geri okunur")
	assert_almost(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")), linear_to_db(0.3), 0.01, "kanal düzeyi uygulanır")
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")), "sessizde Master kapalı")
	var fa := FileAccess.open(SETTINGS_TEST_PATH, FileAccess.WRITE)
	fa.store_string("{bozuk json")
	fa.close()
	Audio.load_settings()
	assert_eq(Audio.volumes, Audio.default_volumes(), "bozuk dosyada varsayılanlar")
	assert_true(not Audio.muted)
	fa = FileAccess.open(SETTINGS_TEST_PATH, FileAccess.WRITE)
	fa.store_string(JSON.stringify({"volumes": {"Music": "yüksek", "UI": -3, "SFX": 0.5}, "muted": "evet"}))
	fa.close()
	Audio.load_settings()
	assert_almost(float(Audio.volumes["Music"]), float(Audio.default_volumes()["Music"]), 0.0001, "yanlış tip atlanır")
	assert_almost(float(Audio.volumes["UI"]), 0.0, 0.0001, "aralık dışı sıkıştırılır")
	assert_almost(float(Audio.volumes["SFX"]), 0.5, 0.0001)
	assert_true(not Audio.muted, "yanlış tipte sessiz atlanır")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_TEST_PATH))


func test_settings_panel_opens_and_pauses() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	Audio.settings_path = SETTINGS_TEST_PATH
	Audio.toggle_settings()
	var ui: CanvasLayer = Audio.get("_settings_ui")
	assert_true(ui != null and ui.visible, "panel açılır")
	assert_true(tree.paused, "açıkken oyun durur")
	Audio.toggle_settings()
	assert_true(not ui.visible, "panel kapanır")
	assert_true(not tree.paused, "kapanınca oyun devam eder")
	assert_true(FileAccess.file_exists(SETTINGS_TEST_PATH), "kapatınca ayarlar kaydedilir")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_TEST_PATH))
