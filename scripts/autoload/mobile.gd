## Mobile — Android (dokunmatik) desteği: dokunmatik mod açık mı, telefonda arayüz ölçeği, Android geri tuşu.
## Dokunmatik mod "mobile" özelliği olan platformda (Android) kendiliğinden açılır; masaüstünde denemek için komut
## satırında --touch (fare dokunma gibi davranır). --ui-scale=X arayüz ölçeğini elle verir (masaüstünde telefon
## görünümünü denemek için). Ölçek: ekranın kısa kenarı küçüldükçe mantıksal çözünürlük küçülür, yazılar ve düğmeler
## büyür (sayılar data/touch.json > ui). Geri tuşu Esc gibi davranır (duraklatma menüsü, pencere kapatma); oyundan
## çıkmak için menüdeki "Çık" kullanılır (application/config/quit_on_go_back kapalı).
extends Node

var enabled: bool = false
var ui_scale: float = 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	enabled = OS.has_feature("mobile")
	var forced_scale := -1.0
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--touch":
			enabled = true
		elif arg.begins_with("--ui-scale="):
			forced_scale = float(arg.get_slice("=", 1))
	if enabled and not OS.has_feature("mobile"):
		Input.emulate_touch_from_mouse = true
	if forced_scale > 0.0:
		ui_scale = forced_scale
	elif OS.has_feature("mobile") and DataDB.loaded:
		ui_scale = auto_scale(DisplayServer.screen_get_size(), DisplayServer.screen_get_dpi())
	if not is_equal_approx(ui_scale, 1.0):
		get_tree().root.content_scale_factor = ui_scale


## Ekran boyutu (piksel) ve dpi'dan arayüz ölçeği: kısa kenar min_inches'ta 1080 / min_height, büyük ekranlarda 1.
func auto_scale(screen_px: Vector2i, dpi: int) -> float:
	var ui: Dictionary = DataDB.get_value("touch", "ui")
	var short_in := minf(screen_px.x, screen_px.y) / maxf(float(dpi), 1.0)
	var h := float(ui["min_height"]) + (short_in - float(ui["min_inches"])) * float(ui["height_per_inch"])
	return 1080.0 / clampf(h, float(ui["min_height"]), 1080.0)


## Arayüz büyütülünce zindan kamerasının yakınlık çarpanı (dünya arayüzle birlikte fazla büyümesin).
func camera_zoom_mult() -> float:
	return pow(ui_scale, -float(DataDB.get_value("touch", "ui.camera_comp")))


## Tuş ipucu: dokunmatik modda boş (klavye yok), değilse aynen. Örn. "Kapat" + Mobile.keys("  (Esc)").
func keys(text: String) -> String:
	return "" if enabled else text


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_press_escape()


## Android geri tuşu: Esc basılıp bırakılmış gibi (oyunun Esc işleyicileri aynen çalışır).
func _press_escape() -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = KEY_ESCAPE
		ev.physical_keycode = KEY_ESCAPE
		ev.pressed = pressed
		Input.parse_input_event(ev)
