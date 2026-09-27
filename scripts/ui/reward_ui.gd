## RewardUI — run içi ödül seçim ekranı (Aşama 6): level ödülü (her 5 levelde) ve boss ödülü. 2 kart; tıklanarak ya da
## 1 / 2 tuşuyla seçilir. Açıkken oyun durur. Seçenekleri Rewards üretir; seçimi DungeonRun işler (chosen sinyali).
## Kartta ödülün adı, değeri, şu anki toplamı ve (varsa) tavanı yazar. Nihai arayüz tasarımı sonraya (GDD Açık Kararlar).
## v0.10.1 (kullanıcı kararı): ekran açıldıktan sonra rewards.input_delay_sec (1,2 sn) boyunca tıklama ve 1/2 çalışmaz;
## kartlar soluk ve kilitli görünür, kartların altındaki çubuk dolunca seçilebilir (yanlışlıkla seçimi önler).
class_name RewardUI
extends CanvasLayer

signal chosen(choice: Dictionary)

var choices: Array = []
var _title: Label
var _sub: Label
var _row: HBoxContainer
var _cards: Array[Button] = []
var _lock_bar: ProgressBar
var _open_ms: int = 0
var _unlock_ms: int = 0


func _ready() -> void:
	layer = 26
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", 18)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(box)
	_title = _label(40, Color(1, 0.88, 0.5))
	box.add_child(_title)
	_sub = _label(18, Color(0.78, 0.78, 0.84))
	box.add_child(_sub)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 28)
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(_row)
	_lock_bar = ProgressBar.new()
	_lock_bar.show_percentage = false
	_lock_bar.custom_minimum_size = Vector2(420, 6)
	_lock_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.15, 0.08, 0.08, 0.9)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.7, 0.12, 0.1)
	_lock_bar.add_theme_stylebox_override("background", bg)
	_lock_bar.add_theme_stylebox_override("fill", fill)
	box.add_child(_lock_bar)


## Ekranı açar. totals: statların şu anki toplamları (kartta gösterilir).
func open(title: String, subtitle: String, p_choices: Array, totals: Dictionary = {}) -> void:
	choices = p_choices
	_title.text = title
	_sub.text = subtitle
	for c: Node in _row.get_children():
		c.queue_free()
	_cards.clear()
	for i: int in choices.size():
		var card := _card(i, choices[i], totals)
		_cards.append(card)
		_row.add_child(card)
	_open_ms = Time.get_ticks_msec()
	_unlock_ms = _open_ms + roundi(float(DataDB.get_value("rewards", "input_delay_sec")) * 1000.0)
	_apply_lock(true)
	visible = true
	get_tree().paused = true
	Audio.play("reward_open")


func close() -> void:
	visible = false
	get_tree().paused = false


## Seçim kilitli mi (açıldıktan sonraki bekleme süresi)? Gerçek zamanla sayılır (oyun durmuşken ve hitstop'ta da).
func is_locked() -> bool:
	return visible and Time.get_ticks_msec() < _unlock_ms


## Beklemeyi hemen bitirir (testler).
func unlock() -> void:
	_unlock_ms = 0
	_apply_lock(false)


func _process(_delta: float) -> void:
	if not visible or _lock_bar == null:
		return
	var total := maxi(_unlock_ms - _open_ms, 1)
	_lock_bar.value = 100.0 * clampf(float(Time.get_ticks_msec() - _open_ms) / float(total), 0.0, 1.0)
	if not is_locked() and not _cards.is_empty() and _cards[0].disabled:
		_apply_lock(false)


func _apply_lock(on: bool) -> void:
	for b: Button in _cards:
		if is_instance_valid(b):
			b.disabled = on
			b.modulate = Color(1, 1, 1, 0.4) if on else Color.WHITE
	if _lock_bar:
		_lock_bar.modulate.a = 1.0 if on else 0.0


func pick(i: int) -> void:
	if not visible or i < 0 or i >= choices.size() or is_locked():
		return
	var c: Dictionary = choices[i]
	close()
	Audio.play("reward_pick")
	chosen.emit(c)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if k == KEY_1 or k == KEY_KP_1:
			pick(0)
		elif k == KEY_2 or k == KEY_KP_2:
			pick(1)
		get_viewport().set_input_as_handled()


func _card(i: int, c: Dictionary, totals: Dictionary) -> Button:
	var special := str(c["kind"]) == "special"
	var b := Button.new()
	b.custom_minimum_size = Vector2(420, 250)
	b.focus_mode = Control.FOCUS_NONE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.1, 0.16, 0.97) if special else Color(0.1, 0.12, 0.15, 0.97)
	sb.border_color = Color(1.0, 0.7, 0.3) if special else Color(0.55, 0.75, 1.0)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(8)
	var hover := sb.duplicate() as StyleBoxFlat
	hover.bg_color = sb.bg_color.lightened(0.12)
	hover.set_border_width_all(5)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("disabled", sb)
	b.pressed.connect(func() -> void: pick(i))
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 22
	v.offset_right = -22
	v.offset_top = 18
	v.offset_bottom = -18
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 10)
	b.add_child(v)
	var key := _label(16, Color(0.7, 0.7, 0.76))
	key.text = "[%d]  %s" % [i + 1, "Özel etki (run başına bir kez)" if special else ("Büyük stat" if str(c["source"]) == "boss" else "Stat")]
	v.add_child(key)
	var name := _label(30, Color(1.0, 0.8, 0.45) if special else Color(0.8, 0.9, 1.0))
	name.text = str(c["name"])
	v.add_child(name)
	var desc := _label(22, Color(0.92, 0.92, 0.95))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(370, 0)
	desc.text = str(c["text"])
	v.add_child(desc)
	if not special:
		var id := str(c["id"])
		var now := float(totals.get(id, GameState.buffs.get(id, 0.0)))
		var cap := Rewards.cap_of(id)
		var line := "Şu an: +%%%s" % Rewards._pct(now)
		if cap < INF:
			line += " · tavan %%%s" % Rewards._pct(cap)
		var cur := _label(16, Color(0.65, 0.68, 0.75))
		cur.text = line
		v.add_child(cur)
	return b


func _label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
