## Proje ayarları, input map ve autoload'ların GDD'ye uygunluğunu test eder.
extends "res://tests/test_case.gd"

const EXPECTED_KEYS := {
	"move_up": KEY_W, "move_down": KEY_S, "move_left": KEY_A, "move_right": KEY_D,
	"ability_q": KEY_Q, "ability_e": KEY_E, "dash": KEY_SPACE, "swap_weapon": KEY_TAB,
	"use_potion": KEY_1, "interact": KEY_F,
}
const EXPECTED_MOUSE := {"attack_primary": MOUSE_BUTTON_LEFT, "attack_secondary": MOUSE_BUTTON_RIGHT}


func test_window_settings() -> void:
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_width"), 1920)
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_height"), 1080)
	assert_eq(ProjectSettings.get_setting("display/window/stretch/mode"), "canvas_items")


func test_key_actions() -> void:
	for action: String in EXPECTED_KEYS.keys():
		assert_true(InputMap.has_action(action), "eylem yok: " + action)
		if not InputMap.has_action(action):
			continue
		var found := false
		for ev: InputEvent in InputMap.action_get_events(action):
			if ev is InputEventKey and (ev as InputEventKey).physical_keycode == EXPECTED_KEYS[action]:
				found = true
		assert_true(found, "%s tuşu yanlış" % action)


func test_mouse_actions() -> void:
	for action: String in EXPECTED_MOUSE.keys():
		assert_true(InputMap.has_action(action), "eylem yok: " + action)
		var found := false
		for ev: InputEvent in InputMap.action_get_events(action):
			if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == EXPECTED_MOUSE[action]:
				found = true
		assert_true(found, "%s fare tuşu yanlış" % action)


func test_autoloads_exist() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	for n: String in ["Events", "DataDB", "GameState", "SaveManager", "Audio", "Mobile"]:
		assert_true(root.has_node(n), "autoload yok: " + n)


func test_game_state_start_run() -> void:
	GameState.start_run("warrior")
	assert_eq(GameState.race_id, "warrior")
	assert_eq(GameState.level, 1)
	assert_eq(GameState.potions, 2, "run 2 iksirle başlar")
	assert_eq(GameState.slots.size(), 4, "4 slot")
	GameState.reset_run()
	assert_true(not GameState.in_run)


## Android: sürüm kodu oyun sürümünden türetilir (0.11.0 → 1100); her sürümde artmazsa telefon güncellemeyi kurmaz.
## Ekran yatay, geri tuşu oyundan çıkarmaz (Mobile Esc gibi işler).
func test_android_export_preset() -> void:
	var cfg := ConfigFile.new()
	assert_eq(cfg.load("res://export_presets.cfg"), OK, "export_presets.cfg okunur")
	var android := ""
	for sec: String in cfg.get_sections():
		if not sec.ends_with(".options") and str(cfg.get_value(sec, "platform", "")) == "Android":
			android = sec
	assert_true(android != "", "Android ön ayarı var")
	if android == "":
		return
	var v := str(ProjectSettings.get_setting("application/config/version")).split(".")
	var code := int(v[0]) * 10000 + int(v[1]) * 100 + int(v[2])
	assert_eq(int(cfg.get_value(android + ".options", "version/code")), code, "version/code = sürümden türetilmiş")
	for key: String in ["launcher_icons/main_192x192", "launcher_icons/adaptive_foreground_432x432", "launcher_icons/adaptive_background_432x432"]:
		assert_true(ResourceLoader.exists(str(cfg.get_value(android + ".options", key))), "simge var: " + key)
	assert_eq(int(ProjectSettings.get_setting("display/window/handheld/orientation")), DisplayServer.SCREEN_SENSOR_LANDSCAPE, "yatay ekran")
	assert_true(not bool(ProjectSettings.get_setting("application/config/quit_on_go_back")), "geri tuşu oyundan çıkmaz")
