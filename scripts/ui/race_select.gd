## RaceSelect — Aşama 10 ırk seçim ekranı (GDD: Menüler ve Oyun Sonu). 4 kart: ırkın animasyonlu sprite'ı (elinde
## başlangıç silahı), adı, can/zırh/hız, kaynağı, Q ve E yetenekleri, pasifi, silah ailesi ve başlangıç silahının kalıcı
## ustalık leveli. Tıklayınca ya da ←/→, 1-4 ile seçilir (seçilen kart kan kırmızısı çerçeveli, karakter saldırır);
## çift tık ya da Enter / "Zindana in" run'ı başlatır, Esc / "Geri" ana menüye döner. Seçim TestRoom.config'e yazılır
## (DungeonRun run'ı oradan kurar) ve bir sonraki açılışta aynı ırk seçili gelir.
class_name RaceSelect
extends Control

const GAME_SCENE := "res://scenes/game.tscn"
const MENU_SCENE := "res://scenes/main_menu.tscn"
const ORDER: Array[String] = ["warrior", "ghost", "archer", "magical"]

var selected: String = "warrior"
var cards: Dictionary = {}          ## ırk -> Button
var bodies: Dictionary = {}         ## ırk -> PlaceholderBody (SpriteBody)
var start_button: Button
var _fade: ColorRect
var _leaving := false


func _ready() -> void:
	get_tree().paused = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.theme()
	var base := ColorRect.new()
	base.color = UiTheme.INK
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base)
	MainMenu.add_ember_backdrop(self)
	add_child(UiTheme.vignette(0.9))
	if not TestRoom.config.is_empty() and ORDER.has(str(TestRoom.config.get("race", ""))):
		selected = str(TestRoom.config["race"])
	_build()
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	create_tween().tween_property(_fade, "color:a", 0.0, 0.5)
	Audio.play_music("menu", 1.5)
	select(selected, false)
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			var shots := TestRoom.ShotTaker.new()
			shots.dir = a.get_slice("=", 1)
			shots.times = [1.5]
			add_child(shots)


func _build() -> void:
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_top = 70
	col.offset_bottom = -60
	col.add_theme_constant_override("separation", 26)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(col)
	col.add_child(UiTheme.title("Irkını seç", 52, Color(0.82, 0.66, 0.52)))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 26)
	col.add_child(row)
	for id: String in ORDER:
		var c := _card(id)
		row.add_child(c)
		cards[id] = c
	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 24)
	col.add_child(bar)
	var back := UiTheme.menu_button("Geri  (Esc)", 260)
	back.alignment = HORIZONTAL_ALIGNMENT_CENTER
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(func() -> void: _leave(MENU_SCENE))
	bar.add_child(back)
	start_button = UiTheme.menu_button("Zindana in  (Enter)", 360)
	start_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	start_button.focus_mode = Control.FOCUS_NONE
	start_button.pressed.connect(start_run)
	bar.add_child(start_button)


func _card(id: String) -> Button:
	var r: Dictionary = DataDB.table("races")[id]
	var b := Button.new()
	b.custom_minimum_size = Vector2(390, 690)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", UiTheme.panel_box())
	b.add_theme_stylebox_override("hover", UiTheme.panel_box(UiTheme.BLOOD))
	b.add_theme_stylebox_override("pressed", UiTheme.panel_box(UiTheme.BLOOD))
	b.pressed.connect(func() -> void: select(id))
	b.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).double_click:
			start_run())
	# Karakter: sprite alanının ortasında, yere basar gibi; hafif kızıl zemin ışığı
	var stage := Control.new()
	stage.position = Vector2(0, 10)
	stage.size = Vector2(390, 330)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.draw.connect(func() -> void:
		var c := Color(0.45, 0.06, 0.04, 0.3)
		stage.draw_set_transform(Vector2(195, 300), 0.0, Vector2(1.0, 0.42))
		for i: int in 6:
			stage.draw_circle(Vector2.ZERO, 150.0 - i * 20.0, Color(c, c.a * (0.2 + i * 0.1)))
		stage.draw_circle(Vector2.ZERO, 62.0, Color(0, 0, 0, 0.6))
		stage.draw_set_transform_matrix(Transform2D.IDENTITY))
	b.add_child(stage)
	var body := SpriteBody.create(str(r.get("sprite", "")))
	body.body_color = Color(str(r["placeholder_color"]))
	var start_type := str(DataDB.table("economy")["start_weapons"][id])
	body.weapon_style = str(DataDB.table("weapon_types")[start_type]["visual"])
	body.position = Vector2(195, 300)
	body.scale = Vector2(3.3, 3.3)
	body.light_mask = 2
	stage.add_child(body)
	# Sprite'ın normal haritasını sol üst önden aydınlatan sıcak meşale ışığı (yalnızca karakteri aydınlatır)
	var light := PointLight2D.new()
	light.texture = _light_texture()
	light.texture_scale = 2.6
	light.color = Color(1.0, 0.68, 0.4)
	light.energy = 1.5
	light.range_item_cull_mask = 2
	light.position = Vector2(90, 150)
	stage.add_child(light)
	body.set_facing(Vector2(1, 1).normalized())
	bodies[id] = body
	var info := VBoxContainer.new()
	info.position = Vector2(26, 352)
	info.size = Vector2(338, 320)
	info.add_theme_constant_override("separation", 6)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(info)
	var name := UiTheme.title(str(r["name"]), 40, UiTheme.BONE)
	info.add_child(name)
	var accent := ColorRect.new()
	accent.color = Color(str(r["placeholder_color"]), 0.7)
	accent.custom_minimum_size = Vector2(0, 3)
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(accent)
	var t := RichTextLabel.new()
	t.bbcode_enabled = true
	t.fit_content = true
	t.scroll_active = false
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.custom_minimum_size = Vector2(338, 0)
	t.add_theme_font_size_override("normal_font_size", 18)
	t.add_theme_font_size_override("bold_font_size", 18)
	t.text = describe(id)
	info.add_child(t)
	return b


## Kartın metni (testler de kullanır): statlar, kaynak, yetenekler, pasif, silah ailesi, başlangıç silahı ve ustalığı.
static func describe(id: String) -> String:
	var r: Dictionary = DataDB.table("races")[id]
	var ab: Dictionary = r["abilities"]
	var fam: PackedStringArray = []
	var wt: Dictionary = DataDB.table("weapon_types")
	for t: String in DataDB.records(wt):
		if str(wt[t]["family"]) == str(r["family"]):
			fam.append(str(wt[t]["name"]))
	var start_type := str(DataDB.table("economy")["start_weapons"][id])
	var lines: PackedStringArray = []
	lines.append("Can [b]%d[/b] (+%s/level) · Zırh %%%d · Hız %s" % [int(r["base_hp"]), _num(float(r["hp_per_level"])),
		roundi(float(r["armor"]) * 100.0), _num(float(r["move_speed"]))])
	lines.append("[color=#948578]Kaynak:[/color] %s" % r["resource"]["name"])
	lines.append("[color=#d8a070]Q[/color] [b]%s[/b] — %s" % [ab["q"]["name"], ab["q"]["description"]])
	lines.append("[color=#d8a070]E[/color] [b]%s[/b] — %s" % [ab["e"]["name"], ab["e"]["description"]])
	lines.append("[color=#948578]Pasif:[/color] %s" % r["passive"]["description"])
	lines.append("[color=#948578]Silahları:[/color] %s" % ", ".join(fam).to_lower())
	lines.append("[color=#948578]Başlangıç:[/color] %s · ustalık Lv %d" % [wt[start_type]["name"], Mastery.level_of(start_type)])
	return "\n".join(lines)


static var _light_tex: Texture2D


static func _light_texture() -> Texture2D:
	if _light_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 128
		t.height = 128
		_light_tex = t
	return _light_tex


static func _num(f: float) -> String:
	return RunSummary._num(f)


func select(id: String, animate: bool = true) -> void:
	if not ORDER.has(id):
		return
	var changed := id != selected
	selected = id
	for rid: String in ORDER:
		var c: Button = cards[rid]
		var on := rid == id
		c.add_theme_stylebox_override("normal", UiTheme.panel_box(UiTheme.BLOOD_LIGHT if on else UiTheme.FRAME))
		c.add_theme_stylebox_override("hover", UiTheme.panel_box(UiTheme.BLOOD_LIGHT if on else UiTheme.BLOOD))
		c.modulate = Color.WHITE if on else Color(0.62, 0.58, 0.56)
	if animate:
		var body: PlaceholderBody = bodies[id]
		body.play_attack()
		if changed:
			Audio.play("ui_click")


func start_run() -> void:
	if _leaving:
		return
	var cfg := TestRoom.default_config()
	cfg["race"] = selected
	TestRoom.config = cfg
	print("[Menü] Irk seçildi: %s" % selected)
	_leave(GAME_SCENE)


func _leave(scene: String) -> void:
	if _leaving:
		return
	_leaving = true
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.4)
	tw.tween_callback(func() -> void: get_tree().change_scene_to_file(scene))


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var k := (event as InputEventKey).keycode
	var i := ORDER.find(selected)
	match k:
		KEY_LEFT, KEY_A:
			select(ORDER[(i + 3) % 4])
		KEY_RIGHT, KEY_D:
			select(ORDER[(i + 1) % 4])
		KEY_1, KEY_2, KEY_3, KEY_4:
			select(ORDER[k - KEY_1])
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			start_run()
		KEY_ESCAPE:
			_leave(MENU_SCENE)
		_:
			return
	get_viewport().set_input_as_handled()
