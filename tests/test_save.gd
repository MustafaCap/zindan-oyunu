## SaveManager: kaydet-yükle döngüsü ve bozuk dosyaya dayanıklılık.
extends "res://tests/test_case.gd"

const SaveScript := preload("res://scripts/autoload/save_manager.gd")
const PATH := "user://test_save.json"

var sm: Node


func before_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	sm = SaveScript.new()
	sm.save_path = PATH
	sm.report_errors = false


func after_each() -> void:
	sm.free()


func test_new_game_when_no_file() -> void:
	sm.load_game()
	assert_eq(sm.last_load_status, "new")
	assert_eq(sm.mastery.size(), 0)


func test_roundtrip() -> void:
	sm.mastery["sword"] = {"level": 3, "xp": 150.0}
	sm.boss_first_kills.append("morvath")
	assert_true(sm.save_game(), "kayıt yazılmalı")
	var sm2: Node = SaveScript.new()
	sm2.save_path = PATH
	sm2.load_game()
	assert_eq(sm2.last_load_status, "ok")
	assert_eq(sm2.mastery["sword"]["level"], 3)
	assert_eq(sm2.mastery["sword"]["xp"], 150.0)
	assert_true("morvath" in sm2.boss_first_kills)
	sm2.free()


func test_corrupt_file_does_not_crash() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("{bu bir kayıt dosyası değil")
	f.close()
	sm.load_game()
	assert_eq(sm.last_load_status, "corrupt")
	assert_eq(sm.mastery.size(), 0, "bozuk kayıtta temiz başlanır")
	assert_true(FileAccess.file_exists(PATH + ".bozuk"), "bozuk dosyanın yedeği alınır")


## Aşama 6: tek tek bozuk girdiler atlanır, level aralığa sıkıştırılır; oyun çökmez.
func test_partially_broken_entries_are_repaired() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1,
		"mastery": {"sword": "bozuk", "bow": {"level": 99, "xp": 5}, "axe": {"level": 3, "xp": -4}, "staff": {"level": "x"}},
		"boss_first_kills": ["morvath", 5, "morvath"]}))
	f.close()
	sm.load_game()
	assert_eq(sm.last_load_status, "repaired")
	assert_true(not sm.mastery.has("sword"), "yanlış tipteki kayıt atlanır")
	assert_true(not sm.mastery.has("staff"), "sayı olmayan level atlanır")
	assert_eq(sm.mastery["bow"]["level"], 12, "level 12'ye sıkıştırılır")
	assert_eq(sm.mastery["bow"]["xp"], 0.0, "maks levelde XP yok")
	assert_eq(sm.mastery["axe"]["level"], 3)
	assert_eq(sm.mastery["axe"]["xp"], 0.0, "negatif XP sıfırlanır")
	assert_eq(sm.boss_first_kills, ["morvath"] as Array[String], "tekrar ve yanlış tip atlanır")


func test_wrong_structure_is_corrupt() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"mastery": [1, 2], "boss_first_kills": {}}))
	f.close()
	sm.load_game()
	assert_eq(sm.last_load_status, "corrupt")
	assert_eq(sm.mastery.size(), 0)


func test_boss_first_kill_saved_immediately() -> void:
	assert_true(sm.record_boss_kill("kordrak"), "ilk kesiş")
	assert_true(not sm.record_boss_kill("kordrak"), "ikinci kesiş ilk değil")
	var sm2: Node = SaveScript.new()
	sm2.save_path = PATH
	sm2.load_game()
	assert_eq(sm2.boss_first_kills, ["kordrak"] as Array[String], "hemen diske yazıldı")
	sm2.free()
