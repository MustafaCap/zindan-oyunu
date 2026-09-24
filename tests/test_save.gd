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
