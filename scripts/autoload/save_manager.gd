## SaveManager — kalıcı veriler: silah tipi ustalıkları ve boss ilk kesişleri.
## user://save.json dosyasına yazar. Dosya bozuksa yedeğini alır ve temiz kayıtla devam eder.
extends Node

const SAVE_VERSION := 1

var save_path: String = "user://save.json"
var mastery: Dictionary = {}          # silah tipi -> {"level": int, "xp": float}
var boss_first_kills: Array[String] = []
var last_load_status: String = ""     # "new", "ok", "corrupt"
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
	for k: String in (d["mastery"] as Dictionary).keys():
		var m: Dictionary = d["mastery"][k]
		mastery[k] = {"level": int(m.get("level", 1)), "xp": float(m.get("xp", 0.0))}
	for b: Variant in d["boss_first_kills"]:
		boss_first_kills.append(str(b))
	last_load_status = "ok"


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


func _is_valid(d: Dictionary) -> bool:
	return d.has("mastery") and typeof(d["mastery"]) == TYPE_DICTIONARY \
		and d.has("boss_first_kills") and typeof(d["boss_first_kills"]) == TYPE_ARRAY
