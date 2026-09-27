## AudioSettingsUI — ses ayarları paneli (Aşama 9): Ana ses, Müzik, Efektler ve Arayüz kaydırıcıları, "Sessiz" kutusu.
## O tuşuyla açılır/kapanır (Audio autoload'u açar); açıkken oyun durur. Değişiklik hemen duyulur, kapatınca
## user://settings.json'a kaydedilir. Aşama 10'daki duraklatma menüsü de bu paneli kullanacak.
class_name AudioSettingsUI
extends CanvasLayer

const ROWS := [["Master", "Ana ses"], ["Music", "Müzik"], ["SFX", "Efektler"], ["UI", "Arayüz"]]

var _sliders: Dictionary = {}
var _values: Dictionary = {}
var _mute: CheckBox
var _was_paused: bool = false


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.05, 0.06, 0.96)
	sb.border_color = Color(0.45, 0.12, 0.1)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(26)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	box.add_child(_label("Ses Ayarları", 30, Color(0.95, 0.75, 0.6)))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 12)
	box.add_child(grid)
	for row: Array in ROWS:
		var bus: String = row[0]
		grid.add_child(_label(str(row[1]), 20, Color(0.88, 0.85, 0.82)))
		var s := HSlider.new()
		s.min_value = 0.0
		s.max_value = 100.0
		s.step = 1.0
		s.custom_minimum_size = Vector2(320, 24)
		s.value_changed.connect(func(v: float) -> void: _on_slider(bus, v))
		grid.add_child(s)
		_sliders[bus] = s
		var val := _label("", 18, Color(0.75, 0.72, 0.7))
		val.custom_minimum_size = Vector2(60, 0)
		grid.add_child(val)
		_values[bus] = val
	_mute = CheckBox.new()
	_mute.text = "Sessiz"
	_mute.add_theme_font_size_override("font_size", 18)
	_mute.toggled.connect(func(on: bool) -> void: Audio.set_muted(on))
	box.add_child(_mute)
	var close_btn := Button.new()
	close_btn.text = "Kapat (O / Esc)"
	close_btn.add_theme_font_size_override("font_size", 18)
	close_btn.pressed.connect(close)
	box.add_child(close_btn)


func open() -> void:
	for bus: String in _sliders.keys():
		(_sliders[bus] as HSlider).set_value_no_signal(roundf(float(Audio.volumes.get(bus, 0.8)) * 100.0))
		_show_value(bus)
	_mute.set_pressed_no_signal(Audio.muted)
	_was_paused = get_tree().paused
	visible = true
	get_tree().paused = true
	Audio.play("ui_open")


func close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = _was_paused
	Audio.save_settings()
	Audio.play("ui_close")


func _on_slider(bus: String, v: float) -> void:
	Audio.set_volume(bus, v / 100.0)
	_show_value(bus)
	if bus != "Music":
		Audio.play("ui_click" if bus == "UI" else "hit_flesh")


func _show_value(bus: String) -> void:
	(_values[bus] as Label).text = "%%%d" % roundi(float(Audio.volumes.get(bus, 0.0)) * 100.0)


## Panel açıkken O ve Esc paneli kapatır (Esc oyundan çıkmaz).
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if k == KEY_O or k == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
