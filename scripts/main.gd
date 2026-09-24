## Ana sahne (Aşama 0): boş pencere + durum bilgisi.
## Veri dosyaları yüklendi mi, kayıt dosyası nerede, hangi sürüm — tek bakışta gösterir.
## Esc ile oyundan çıkılır. Sonraki aşamalarda ana menü bunun yerini alacak.
extends Control

@onready var title_label: Label = $Center/VBox/Title
@onready var status_label: Label = $Center/VBox/Status
@onready var info_label: Label = $Center/VBox/Info


func _ready() -> void:
	title_label.text = "Zindan Oyunu"
	var version: String = ProjectSettings.get_setting("application/config/version", "?")
	if DataDB.loaded:
		status_label.text = "Veri dosyaları: %d / %d yüklendi ✓" % [DataDB.tables.size(), DataDB.SCHEMA.size()]
		status_label.modulate = Color(0.55, 0.9, 0.55)
	else:
		status_label.text = "VERİ HATASI:\n" + "\n".join(DataDB.errors)
		status_label.modulate = Color(1.0, 0.45, 0.45)
	info_label.text = "Sürüm %s · Aşama 0 · Godot %s\nKayıt: %s (%s)\nÇıkmak için Esc" % [
		version,
		Engine.get_version_info()["string"],
		ProjectSettings.globalize_path(SaveManager.save_path),
		SaveManager.last_load_status,
	]
	print("[Main] Aşama 0 başlatıldı. Veri geçerli: %s" % DataDB.loaded)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		get_tree().quit()
