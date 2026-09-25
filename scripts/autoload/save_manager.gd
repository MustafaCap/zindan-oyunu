## SaveManager — kalıcı veriler: silah tipi ustalıkları ve boss ilk kesişleri (GDD: run sonunda yalnızca bunlar kalır).
## user://save.json dosyasına yazar. Dosya bozuksa (okunamayan JSON ya da yanlış yapı) yedeğini alır (.bozuk) ve temiz
## kayıtla devam eder; tek tek bozuk kayıtlar (yanlış tipte ustalık, bilinmeyen alan) atlanır, level aralığa sıkıştırılır.
## Yazma önce geçici dosyaya yapılır, sonra yerine taşınır: yazarken çökerse eski kayıt bozulmaz.
## Aşama 6: ustalık run sonunda (Mastery.apply_run), boss ilk kesişi hemen kaydedilir.
extends Node

const SAVE_VERSION := 1

var save_path: String = "user://save.json"
var mastery: Dictionary = {}          # silah tipi -> {"level": int, "xp": float}
var boss_first_kills: Array[String] = []
var last_load_status: String = ""     # "new", "ok", "repaired" (bazı kayıtlar atlandı), "corrupt"
var report_errors: bool = true


func _ready() -> void:
	load_game()


func reset() -> void:
	mastery = {}
	boss_first_kills = []


func load_game() -> void:
	reset()
	if not FileAccess.file_exists(save_path):
		last_load_status = "new"
		return
	var text := FileAccess.get_file_as_string(save_path)
	var json := JSON.new()
	var data: Variant = json.data if json.parse(text) == OK else null
	if typeof(data) != TYPE_DICTIONARY or not _is_valid(data):
		if report_errors:
			push_warning("[SaveManager] Kayıt dosyası bozuk; yedeklenip sıfırdan başlanıyor.")
		DirAccess.copy_absolute(ProjectSettings.globalize_path(save_path),
			ProjectSettings.globalize_path(save_path + ".bozuk"))
		last_load_status = "corrupt"
		return
	var d: Dictionary = data
	var repaired := false
	var lo := _level_min()
	var hi := _level_max()
	for k: Variant in (d["mastery"] as Dictionary).keys():
		var m: Variant = d["mastery"][k]
		if typeof(m) != TYPE_DICTIONARY:
			repaired = true
			continue
		var md: Dictionary = m
		var lv: Variant = md.get("level", lo)
		var xp: Variant = md.get("xp", 0.0)
		if not _is_number(lv) or not _is_number(xp):
			repaired = true
			continue
		var level := clampi(int(lv), lo, hi)
		if level != int(lv) or float(xp) < 0.0:
			repaired = true
		mastery[str(k)] = {"level": level, "xp": 0.0 if level >= hi else maxf(float(xp), 0.0)}
	for b: Variant in d["boss_first_kills"]:
		if typeof(b) != TYPE_STRING or str(b) in boss_first_kills:
			repaired = true
			continue
		boss_first_kills.append(str(b))
	last_load_status = "repaired" if repaired else "ok"
	if repaired and report_errors:
		push_warning("[SaveManager] Kayıttaki bazı bozuk girdiler atlandı.")


func save_game() -> bool:
	var data := {
		"version": SAVE_VERSION,
		"mastery": mastery,
		"boss_first_kills": boss_first_kills,
	}
	# Önce geçici dosyaya yaz, sonra yerine taşı: yazarken çökerse eski kayıt bozulmaz.
	var tmp := save_path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("[SaveManager] Kayıt yazılamadı: %s" % error_string(FileAccess.get_open_error()))
		return false
	f.store_string(JSON.stringify(data, "  "))
	f.close()
	var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(save_path))
	return err == OK


## Boss ilk kesişi: yeni ise ekler, hemen kaydeder ve true döner.
func record_boss_kill(boss_id: String) -> bool:
	if boss_id == "" or boss_id in boss_first_kills:
		return false
	boss_first_kills.append(boss_id)
	save_game()
	return true


## Kayıt dosyasını ve kalıcı verileri siler (hata ayıklama menüsü).
func wipe() -> void:
	reset()
	save_game()


func _is_valid(d: Dictionary) -> bool:
	return d.has("mastery") and typeof(d["mastery"]) == TYPE_DICTIONARY \
		and d.has("boss_first_kills") and typeof(d["boss_first_kills"]) == TYPE_ARRAY


func _is_number(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT


func _level_min() -> int:
	return int((DataDB.tables.get("progression", {}) as Dictionary).get("mastery", {}).get("start_level", 1))


func _level_max() -> int:
	return int((DataDB.tables.get("progression", {}) as Dictionary).get("mastery", {}).get("max_level", 12))
