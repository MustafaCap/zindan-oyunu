## data/ JSON dosyalarının GDD ile uyumunu ve DataDB doğrulamasını test eder.
extends "res://tests/test_case.gd"

const DataDBScript := preload("res://scripts/autoload/data_db.gd")


func test_all_files_load_without_errors() -> void:
	assert_true(DataDB.loaded, "DataDB hatasız yüklenmeli: %s" % ", ".join(DataDB.errors))
	assert_eq(DataDB.tables.size(), 15, "15 veri dosyası")


func test_content_counts() -> void:
	assert_eq(DataDB.records(DataDB.table("races")).size(), 4, "4 ırk")
	assert_eq(DataDB.records(DataDB.table("weapon_types")).size(), 12, "12 silah tipi")
	assert_eq(DataDB.table("rarities").size(), 4, "4 nadirlik")
	assert_eq(DataDB.table("elements")["elements"].size(), 6, "6 element")
	assert_eq(DataDB.table("elements")["combos"].size(), 7, "7 kombo")
	assert_eq(DataDB.records(DataDB.table("traits")).size(), 5, "5 özellik")
	assert_eq(DataDB.table("talismans").size(), 3, "3 tılsım")
	assert_eq(DataDB.table("enemies")["enemies"].size(), 17, "17 düşman")
	assert_eq(DataDB.table("bosses")["bosses"].size(), 4, "4 boss")
	assert_eq(DataDB.table("rewards")["level_pool"].size(), 15, "15 level ödülü")
	assert_eq(DataDB.table("rewards")["boss_major_pool"].size(), 12, "12 büyük boss ödülü")
	assert_eq(DataDB.table("rewards")["boss_special_pool"].size(), 11, "11 özel etki")
	assert_eq(DataDB.table("floors")["floors"].size(), 4, "4 kat")


func test_rarity_base_damage() -> void:
	var r := DataDB.table("rarities")
	assert_eq(r["common"]["base_damage"], 100)
	assert_eq(r["rare"]["base_damage"], 125)
	assert_eq(r["epic"]["base_damage"], 175)
	assert_eq(r["legendary"]["base_damage"], 260)


## XP eğrisi: katın tüm düşmanları + 2 elit + boss kesilirse oyuncu hedef levele tam ulaşır.
func test_floor_xp_matches_level_targets() -> void:
	var prog := DataDB.table("progression")
	var base: float = prog["player"]["xp_base"]
	var per: float = prog["player"]["xp_per_level"]
	var expected_totals := {"1": 3500, "2": 11800, "3": 19800, "4": 36000}
	for fid: String in ["1", "2", "3", "4"]:
		var fl: Dictionary = DataDB.table("floors")["floors"][fid]
		var lr: Array = fl["level_range"]
		var curve_total := 0.0
		for lvl: int in range(int(lr[0]), int(lr[1])):
			curve_total += base + per * lvl
		assert_eq(curve_total, expected_totals[fid], "kat %s eğri toplamı" % fid)
		var xp: Dictionary = prog["enemy_xp"][fid]
		var enemy_total: float = float(fl["expected_normal_enemies"]) * float(xp["normal"]) \
			+ float(fl["expected_elites"]) * float(xp["elite"]) + float(xp["boss"])
		assert_eq(enemy_total, curve_total, "kat %s düşman XP toplamı = eğri" % fid)


func test_mastery_curve_is_114_matches() -> void:
	var m: Dictionary = DataDB.table("progression")["mastery"]
	var total := 0.0
	for x: Variant in m["xp_to_next"]:
		total += float(x)
	assert_eq(total / float(m["reference_match_xp"]), 114, "ustalık 12 için 114 referans maç")


func test_room_counts_match_run_length_table() -> void:
	var fl: Dictionary = DataDB.table("floors")["floors"]
	assert_eq(fl["1"]["rooms"], 8)
	assert_eq(fl["2"]["rooms"], 9)
	assert_eq(fl["3"]["rooms"], 10)
	assert_eq(fl["4"]["rooms"], 11)


func test_missing_field_gives_clear_error() -> void:
	var dir := _copy_data_to_temp("missing_field")
	var races: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir + "/races.json"))
	(races["ghost"] as Dictionary).erase("base_hp")
	_write(dir + "/races.json", JSON.stringify(races))
	var db: Node = DataDBScript.new()
	db.report_errors = false
	var ok: bool = db.load_all(dir)
	assert_true(not ok, "eksik alan yüklemeyi başarısız yapmalı")
	assert_true(_errors_contain(db, "races.ghost: eksik alan 'base_hp'"), "hata mesajı alanı söylemeli: %s" % str(db.errors))
	db.free()


func test_wrong_type_gives_clear_error() -> void:
	var dir := _copy_data_to_temp("wrong_type")
	var wt: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir + "/weapon_types.json"))
	wt["sword"]["range"] = "uzun"
	_write(dir + "/weapon_types.json", JSON.stringify(wt))
	var db: Node = DataDBScript.new()
	db.report_errors = false
	db.load_all(dir)
	assert_true(_errors_contain(db, "weapon_types.sword.range: 'number' tipinde olmalı"), "tip hatası: %s" % str(db.errors))
	db.free()


func test_broken_json_and_missing_file() -> void:
	var dir := _copy_data_to_temp("broken_json")
	_write(dir + "/traits.json", "{ \"fury\": ")
	DirAccess.remove_absolute(dir + "/talismans.json")
	var db: Node = DataDBScript.new()
	db.report_errors = false
	db.load_all(dir)
	assert_true(_errors_contain(db, "traits.json: JSON hatası"), "bozuk JSON: %s" % str(db.errors))
	assert_true(_errors_contain(db, "talismans.json: dosya bulunamadı"), "eksik dosya: %s" % str(db.errors))
	db.free()


func test_bad_reference_is_caught() -> void:
	var dir := _copy_data_to_temp("bad_ref")
	var floors: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir + "/floors.json"))
	(floors["floors"]["1"]["enemy_pool"] as Array).append("dragon")
	_write(dir + "/floors.json", JSON.stringify(floors))
	var db: Node = DataDBScript.new()
	db.report_errors = false
	db.load_all(dir)
	assert_true(_errors_contain(db, "bilinmeyen düşman 'dragon'"), "referans hatası: %s" % str(db.errors))
	db.free()


func test_rarity_weights_must_sum_to_one() -> void:
	var dir := _copy_data_to_temp("bad_weights")
	var lt: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir + "/loot_tables.json"))
	lt["floors"]["2"]["rarity_weights"]["common"] = 0.9
	_write(dir + "/loot_tables.json", JSON.stringify(lt))
	var db: Node = DataDBScript.new()
	db.report_errors = false
	db.load_all(dir)
	assert_true(_errors_contain(db, "loot_tables.floors.2: nadirlik oranlarının toplamı 1 olmalı"), str(db.errors))
	db.free()


# --- yardımcılar ---

func _copy_data_to_temp(name: String) -> String:
	var dir := "user://test_tmp/" + name
	DirAccess.make_dir_recursive_absolute(dir)
	for f: String in DirAccess.get_files_at("res://data"):
		if f.ends_with(".json"):
			_write(dir + "/" + f, FileAccess.get_file_as_string("res://data/" + f))
	return dir


func _write(path: String, text: String) -> void:
	var fa := FileAccess.open(path, FileAccess.WRITE)
	fa.store_string(text)
	fa.close()


func _errors_contain(db: Node, needle: String) -> bool:
	for e: String in db.errors:
		if e.contains(needle):
			return true
	return false
