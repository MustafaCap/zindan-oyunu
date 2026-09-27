## Android: dokunmatik kontroller (TouchControls) ve Mobile arayüz ölçeği. Dokunmalar _input'a doğrudan verilir.
extends "res://tests/test_case.gd"

const FakeTarget := preload("res://tests/fake_target.gd")

var _world: Node2D
var _run: FakeRun
var _touch: TouchControls
var _p: Player


class FakeRun:
	extends Node
	var player: Player
	var hud: Hud
	var finished: bool = false


func before_each() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	_world = Node2D.new()
	root.add_child(_world)
	_p = Player.new()
	_p.race_id = "warrior"
	_p.weapons = [Weapon.make("sword", "common")] as Array[Weapon]
	_world.add_child(_p)
	_run = FakeRun.new()
	_run.player = _p
	_run.hud = Hud.new()
	_run.add_child(_run.hud)
	_run.hud.touch_mode = true
	_touch = TouchControls.new()
	_touch.run = _run
	_run.add_child(_touch)
	root.add_child(_run)
	_p.touch = _touch


func after_each() -> void:
	_run.free()
	_world.free()


func _down(i: int, pos: Vector2) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = i
	ev.position = pos
	ev.pressed = true
	_touch._input(ev)


func _drag(i: int, pos: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = i
	ev.position = pos
	_touch._input(ev)


func _up(i: int, pos: Vector2) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = i
	ev.position = pos
	ev.pressed = false
	_touch._input(ev)


func _enemy(pos_tiles: Vector2) -> Node2D:
	var t: Node2D = FakeTarget.new()
	t.setup(1000.0)
	t.add_to_group("enemies")
	_world.add_child(t)
	t.global_position = _p.global_position + Iso.to_screen(pos_tiles * Iso.KARO)
	return t


func test_joystick_moves_where_the_thumb_points() -> void:
	var c := _touch.joystick_rest()
	var r := _touch.joy_radius
	for dir: Vector2 in [Vector2.RIGHT, Vector2.UP, Vector2(1, 1).normalized(), Vector2(-1, -0.5).normalized()]:
		_down(0, c)
		_drag(0, c + dir * r)
		var move: Vector2 = _touch.read_intent(_p)["move"]
		assert_almost(move.length(), 1.0, 0.01, "tam itişte hız 1")
		assert_almost(Iso.to_screen(move).normalized().dot(dir), 1.0, 0.001, "ekranda parmağın yönüne yürür %s" % dir)
		_up(0, c + dir * r)
		assert_eq(_touch.read_intent(_p)["move"], Vector2.ZERO, "bırakınca durur")
	_down(0, c)
	_drag(0, c + Vector2(r * 0.1, 0))
	assert_eq(_touch.read_intent(_p)["move"], Vector2.ZERO, "ölü bölgede yürümez")
	_drag(0, c + Vector2(r * 3.0, 0))
	assert_almost((_touch.read_intent(_p)["move"] as Vector2).length(), 1.0, 0.01, "uzağa sürükleyince joystick peşinden gelir")
	_up(0, c)


func test_attack_hold_auto_aims_at_nearest_enemy() -> void:
	var far := _enemy(Vector2(6, 0))
	var near := _enemy(Vector2(0, 3))
	var b := _touch.button_center("light")
	_down(1, b)
	for i: int in 3:
		var d := _touch.read_intent(_p)
		assert_true(bool(d["light"]), "basılı tutunca saldırır")
		assert_eq(d["aim"], near.global_position, "en yakın düşmana nişan")
	_up(1, b)
	assert_true(not bool(_touch.read_intent(_p)["light"]), "bırakınca durur")
	assert_true(far != null)


func test_drag_aims_manually() -> void:
	_enemy(Vector2(3, 0))
	var b := _touch.button_center("light")
	_down(1, b)
	_drag(1, b + Vector2(-200, 0))
	var d := _touch.read_intent(_p)
	assert_true(_touch.aim_manual, "sürükleyince elle nişan")
	var v := Iso.to_cart((d["aim"] as Vector2) - _p.global_position)
	assert_true(v.normalized().dot(Vector2.LEFT) > 0.99, "sola sürükleyince sola nişan (düşman sağda olsa da)")
	assert_almost(v.length() / Iso.KARO, float(DataDB.get_value("touch", "aim.max_tiles")), 0.01, "tam sürüklemede en uzak nişan")
	_up(1, b)


func test_abilities_fire_on_release_once() -> void:
	var e := _enemy(Vector2(2, 2))
	var q := _touch.button_center("q")
	_down(2, q)
	assert_true(not bool(_touch.read_intent(_p)["q"]), "basarken tetiklenmez")
	_up(2, q)
	var d := _touch.read_intent(_p)
	assert_true(bool(d["q"]), "bırakınca tetiklenir")
	assert_eq(d["aim"], e.global_position, "dokunup bırakınca otomatik nişan")
	assert_true(not bool(_touch.read_intent(_p)["q"]), "bir kez")
	# Sürükleyip bırakınca o yöne
	_down(2, q)
	_drag(2, q + Vector2(0, 120))
	_up(2, q + Vector2(0, 120))
	d = _touch.read_intent(_p)
	assert_true(bool(d["q"]))
	assert_true(Iso.to_cart((d["aim"] as Vector2) - _p.global_position).normalized().dot(Vector2.DOWN) > 0.99, "aşağı sürüklendi")


func test_heavy_press_and_hold() -> void:
	var h := _touch.button_center("heavy")
	_down(3, h)
	var d := _touch.read_intent(_p)
	assert_true(bool(d["heavy"]) and bool(d["heavy_held"]), "basınca başlar")
	d = _touch.read_intent(_p)
	assert_true(not bool(d["heavy"]) and bool(d["heavy_held"]), "basılı tutulur (Yay doldurma)")
	_up(3, h)
	assert_true(not bool(_touch.read_intent(_p)["heavy_held"]), "bırakınca atar")


func test_one_shot_buttons_and_multitouch() -> void:
	var c := _touch.joystick_rest()
	_down(0, c)
	_drag(0, c + Vector2(_touch.joy_radius, 0))
	_down(1, _touch.button_center("dash"))
	var d := _touch.read_intent(_p)
	assert_true(bool(d["dash"]), "atılma")
	assert_true((d["move"] as Vector2).x > 0.9, "yürürken atılma: joystick yönü")
	assert_true(not bool(_touch.read_intent(_p)["dash"]), "bir kez")
	_up(1, _touch.button_center("dash"))
	_down(1, _touch.button_center("potion"))
	assert_true(bool(_touch.read_intent(_p)["potion"]), "iksir")
	_up(1, _touch.button_center("potion"))
	_up(0, c)


func test_swap_button_needs_two_weapons() -> void:
	assert_true(not _touch.button_visible("swap"), "tek silahla gizli")
	_p.weapons.append(Weapon.make("axe", "common"))
	assert_true(_touch.button_visible("swap"))
	_down(1, _touch.button_center("swap"))
	assert_true(bool(_touch.read_intent(_p)["swap"]))
	_up(1, _touch.button_center("swap"))
	# Silah paneline dokunmak da değiştirir
	_down(1, _run.hud.weapon_panel_rect().get_center())
	assert_true(bool(_touch.read_intent(_p)["swap"]), "silah paneline dokununca")
	_up(1, _run.hud.weapon_panel_rect().get_center())


func test_signals_and_interact_button() -> void:
	var got: Array[String] = []
	_touch.inventory_pressed.connect(func() -> void: got.append("bag"))
	_touch.pause_pressed.connect(func() -> void: got.append("pause"))
	_touch.interact_pressed.connect(func() -> void: got.append("interact"))
	_down(1, _touch.button_center("bag"))
	_up(1, _touch.button_center("bag"))
	_down(1, _touch.button_center("pause"))
	_up(1, _touch.button_center("pause"))
	assert_true(not _touch.button_visible("interact"), "yakında bir şey yokken gizli")
	_run.hud.prompt_text = "F: Al — Kılıç"
	_down(1, _touch.button_center("interact"))
	_up(1, _touch.button_center("interact"))
	assert_eq(got, ["bag", "pause", "interact"] as Array[String])
	assert_eq(TouchControls.interact_label("F: Al — Kılıç"), "Al")
	assert_eq(TouchControls.interact_label("F: Tüccar (al / sat)"), "Tüccar")
	assert_eq(TouchControls.interact_label("F: Aşağı in"), "Aşağı in")


func test_pause_releases_fingers() -> void:
	_down(1, _touch.button_center("light"))
	_touch._notification(Node.NOTIFICATION_PAUSED)
	assert_true(not _touch.visible, "oyun durunca gizlenir")
	_touch._notification(Node.NOTIFICATION_UNPAUSED)
	assert_true(not bool(_touch.read_intent(_p)["light"]), "basılı parmak bırakılmış sayılır")


func test_player_reads_touch_not_mouse() -> void:
	_down(1, _touch.button_center("light"))
	var d: Dictionary = _p._read_input(0.016)
	assert_true(bool(d["light"]), "oyuncu dokunmatik girdiyi okur")
	_up(1, _touch.button_center("light"))
	# Dokunma fareye de çevrilir (menüler için); dokunmatik modda fare tıklaması saldırı sayılmaz
	Input.action_press("attack_primary")
	assert_true(not bool(_p._read_input(0.016)["light"]), "fare tıklaması saldırı değil")
	Input.action_release("attack_primary")


func test_no_input_when_dead_or_run_over() -> void:
	_run.finished = true
	_down(1, _touch.button_center("light"))
	assert_true(not bool(_touch.read_intent(_p)["light"]), "run bitince dokunma işlenmez")


func test_mobile_ui_scale() -> void:
	assert_almost(Mobile.auto_scale(Vector2i(2400, 1080), 400), 1080.0 / 780.0, 0.001, "6,5 inç telefon")
	assert_almost(Mobile.auto_scale(Vector2i(1600, 720), 180), 1080.0 / (780.0 + 1.3 * 130.0), 0.001, "4 inç kısa kenar")
	assert_eq(Mobile.auto_scale(Vector2i(2560, 1600), 280), 1.0, "tablet: masaüstü ölçeği")
	assert_eq(Mobile.auto_scale(Vector2i(1920, 1080), 0), 1.0, "dpi bilinmiyorsa büyütmez")
	assert_eq(Mobile.keys("  (Esc)"), "  (Esc)" if not Mobile.enabled else "")
