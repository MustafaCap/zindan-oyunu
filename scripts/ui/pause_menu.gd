## PauseMenu — Aşama 10 duraklatma menüsü (Esc): Devam, Ses ayarları, Ana menüye dön, Oyundan çık. Açıkken oyun durur;
## Esc ya da "Devam" kapatır. Zindanda "Ana menüye dön" run'ı bırakır ve ölüm sayılır: önce onay sorulur,
## sonra DungeonRun ustalık XP'sini o kattaki ölüm çarpanıyla işler ve özet ekranını açar. "Oyundan çık" da run'ı aynı
## şekilde işleyip kaydeder, sonra oyunu kapatır. Test odasında (run yok) ikisi de onaysız, doğrudan çalışır.
class_name PauseMenu
extends CanvasLayer

## Zindan: run'ı bırak (ölüm sayılır). quit: sonra oyunu kapat.
signal abandon_requested(quit: bool)
## Test odası: ana menüye dön / çık.
signal leave_requested(quit: bool)

## Zindanda true (run var): çıkışlar onay ister ve run'ı işler.
var in_run: bool = true
var buttons: Array[Button] = []
var _main: VBoxContainer
var _confirm: VBoxContainer
var _confirm_text: Label
var _confirm_yes: Button
var _confirm_quit: bool = false


func _ready() -> void:
	layer = 35
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UiTheme.theme()
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.0, 0.0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	root.add_child(UiTheme.vignette(0.8))
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(520, 0)
	root.add_child(panel)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 14)
	panel.add_child(inner)
	inner.add_child(UiTheme.title("Duraklatıldı", 46, Color(0.82, 0.66, 0.52)))
	var drips := BloodDrips.new()
	drips.custom_minimum_size = Vector2(0, 46)
	drips.max_len = 40.0
	drips.count = 7
	drips.seed_value = 3
	inner.add_child(drips)
	_main = VBoxContainer.new()
	_main.add_theme_constant_override("separation", 12)
	_main.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_child(_main)
	for spec: Array in [["Devam" + Mobile.keys("  (Esc)"), close], ["Ses ayarları", func() -> void: Audio.toggle_settings()],
			["Ana menüye dön", func() -> void: _ask(false)], ["Oyundan çık", func() -> void: _ask(true)]]:
		var b := UiTheme.menu_button(str(spec[0]), 440)
		b.pressed.connect(spec[1])
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_main.add_child(b)
		buttons.append(b)
	_confirm = VBoxContainer.new()
	_confirm.add_theme_constant_override("separation", 12)
	_confirm.visible = false
	inner.add_child(_confirm)
	_confirm_text = UiTheme.label("", 20, UiTheme.BONE)
	_confirm_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_text.custom_minimum_size = Vector2(440, 0)
	_confirm.add_child(_confirm_text)
	_confirm_yes = UiTheme.menu_button("", 440)
	_confirm_yes.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_confirm_yes.pressed.connect(_confirmed)
	_confirm.add_child(_confirm_yes)
	var no := UiTheme.menu_button("Vazgeç" + Mobile.keys("  (Esc)"), 440)
	no.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	no.pressed.connect(_cancel_confirm)
	_confirm.add_child(no)


func open() -> void:
	if visible:
		return
	_cancel_confirm()
	visible = true
	get_tree().paused = true
	Audio.play("ui_open")
	buttons[0].grab_focus.call_deferred()


func close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = false
	Audio.play("ui_close")


func is_confirming() -> bool:
	return _confirm.visible


func _ask(quit: bool) -> void:
	if not in_run:
		visible = false
		leave_requested.emit(quit)
		return
	_confirm_quit = quit
	_confirm_text.text = ("Run bırakılır ve ölüm sayılır: ustalık XP'si bu kattaki ölüm çarpanıyla işlenip kaydedilir, sonra oyun kapanır." if quit
		else "Run bırakılır ve ölüm sayılır: ustalık XP'si bu kattaki ölüm çarpanıyla işlenir, özet ekranından ana menüye dönülür.")
	_confirm_yes.text = "Evet, oyundan çık" if quit else "Evet, run'ı bırak"
	_main.visible = false
	_confirm.visible = true
	_confirm_yes.grab_focus.call_deferred()


func _cancel_confirm() -> void:
	_confirm.visible = false
	_main.visible = true
	if visible:
		buttons[0].grab_focus.call_deferred()


func _confirmed() -> void:
	visible = false
	_confirm.visible = false
	_main.visible = true
	abandon_requested.emit(_confirm_quit)


## Esc: onay açıksa vazgeçer, değilse menüyü kapatır. (Ses paneli açıksa Esc'i o alır: _input'ta işler.)
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_ESCAPE:
		if _confirm.visible:
			_cancel_confirm()
		else:
			close()
		get_viewport().set_input_as_handled()
