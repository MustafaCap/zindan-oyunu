## DebugMenu — geçici hata ayıklama menüsü (Aşama 3): ırk, level, iki aktif silahın tipi/elementi/özelliği ve
## düşman türü seçilip test odası o ayarla yeniden kurulur. M ile açılır/kapanır; açıkken oyun duraklar.
## Nihai arayüz değildir (ayrıntılı arayüz tasarımı GDD Açık Kararlar'da); Aşama 10'da kaldırılacak.
class_name DebugMenu
extends CanvasLayer

signal applied(config: Dictionary)

const LEVELS := [1, 10, 20, 40, 60, 80]
const ENEMY_MODES := [["waves", "1. kat dalgaları"], ["dummies", "Kuklalar (saldırmaz, ölmez)"]]

var config: Dictionary = {}

var _race_buttons: Dictionary = {}
var _level: OptionButton
var _slots: Array = []        ## her silah için [tip, element, özellik] OptionButton'ları
var _enemies: OptionButton
var _info: Label
var _type_ids: Array = []
var _element_ids: Array = []
var _trait_ids: Array = []


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_type_ids = DataDB.records(DataDB.table("weapon_types"))
	_element_ids = ["physical"] + (DataDB.table("elements")["elements"] as Dictionary).keys()
	_trait_ids = [""] + DataDB.records(DataDB.table("traits"))
	_build()


func open(current: Dictionary) -> void:
	config = current.duplicate(true)
	_load_config()
	visible = true
	get_tree().paused = true


func close() -> void:
	visible = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if k == KEY_M or k == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.13, 0.97)
	sb.border_color = Color(0.9, 0.8, 0.5)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.custom_minimum_size = Vector2(860, 0)
	panel.add_child(box)

	var title := _label("Hata Ayıklama Menüsü", 28, Color(1, 0.9, 0.6))
	box.add_child(title)
	box.add_child(_label("Irk, level ve iki aktif silahı seç; 'Uygula' test odasını bu ayarla yeniden kurar. (M / Esc: kapat)", 15, Color(0.7, 0.7, 0.75)))

	# Irk
	var race_row := _row(box, "Irk")
	var group := ButtonGroup.new()
	for rid: String in DataDB.records(DataDB.table("races")):
		var b := Button.new()
		b.text = str(DataDB.table("races")[rid]["name"])
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(130, 40)
		b.add_theme_font_size_override("font_size", 18)
		b.pressed.connect(func() -> void:
			config["race"] = rid
			_refresh_info())
		race_row.add_child(b)
		_race_buttons[rid] = b

	# Level
	var lvl_row := _row(box, "Level")
	_level = _option(lvl_row, LEVELS.map(func(l: int) -> String: return str(l)), 120)
	_level.item_selected.connect(func(i: int) -> void:
		config["level"] = LEVELS[i]
		_refresh_info())

	# İki silah
	for slot: int in 2:
		var row := _row(box, "%d. silah" % (slot + 1))
		var type_names: Array = []
		for t: String in _type_ids:
			var wt: Dictionary = DataDB.table("weapon_types")[t]
			type_names.append("%s (%s)" % [wt["name"], DataDB.table("races")[str(wt["family"])]["name"]])
		var t_opt := _option(row, type_names, 250)
		var el_names: Array = _element_ids.map(func(e: String) -> String: return Weapon.kind_name(e) if e != "physical" else "Elementsiz")
		var e_opt := _option(row, el_names, 170)
		var tr_names: Array = _trait_ids.map(func(t2: String) -> String: return "Özellik yok" if t2 == "" else str(Traits.data(t2)["name"]))
		var r_opt := _option(row, tr_names, 170)
		var s := slot
		t_opt.item_selected.connect(func(i: int) -> void:
			config["weapons"][s]["type"] = _type_ids[i]
			_refresh_info())
		e_opt.item_selected.connect(func(i: int) -> void:
			config["weapons"][s]["element"] = _element_ids[i]
			_refresh_info())
		r_opt.item_selected.connect(func(i: int) -> void:
			config["weapons"][s]["trait"] = _trait_ids[i]
			_refresh_info())
		_slots.append([t_opt, e_opt, r_opt])

	# Düşmanlar
	var en_row := _row(box, "Düşmanlar")
	_enemies = _option(en_row, ENEMY_MODES.map(func(m: Array) -> String: return str(m[1])), 300)
	_enemies.item_selected.connect(func(i: int) -> void: config["enemies"] = ENEMY_MODES[i][0])

	_info = _label("", 15, Color(0.82, 0.85, 0.9))
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(860, 150)
	box.add_child(_info)

	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 16)
	btns.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(btns)
	var cancel := Button.new()
	cancel.text = "Kapat"
	cancel.custom_minimum_size = Vector2(140, 44)
	cancel.pressed.connect(close)
	btns.add_child(cancel)
	var ok := Button.new()
	ok.text = "Uygula ve başla"
	ok.custom_minimum_size = Vector2(220, 44)
	ok.add_theme_font_size_override("font_size", 18)
	ok.pressed.connect(func() -> void:
		close()
		applied.emit(config.duplicate(true)))
	btns.add_child(ok)


func _load_config() -> void:
	var rid: String = config.get("race", "warrior")
	if _race_buttons.has(rid):
		(_race_buttons[rid] as Button).button_pressed = true
	_level.select(maxi(LEVELS.find(int(config.get("level", 1))), 0))
	for slot: int in 2:
		var wc: Dictionary = config["weapons"][slot]
		(_slots[slot][0] as OptionButton).select(maxi(_type_ids.find(wc["type"]), 0))
		(_slots[slot][1] as OptionButton).select(maxi(_element_ids.find(wc["element"]), 0))
		(_slots[slot][2] as OptionButton).select(maxi(_trait_ids.find(wc["trait"]), 0))
	for i: int in ENEMY_MODES.size():
		if ENEMY_MODES[i][0] == config.get("enemies", "waves"):
			_enemies.select(i)
	_refresh_info()


## Seçilen ırkın yetenekleri, kaynağı ve her silahla ırk-silah matrisi etkisi.
func _refresh_info() -> void:
	var rid: String = config.get("race", "warrior")
	var race: Dictionary = DataDB.table("races")[rid]
	var lvl := int(config.get("level", 1))
	var lines: PackedStringArray = []
	var res: Dictionary = race["resource"]
	var res_txt := str(res["name"])
	if str(res["type"]) == "mana":
		res_txt += " %d" % roundi(RaceStats.max_mana(rid, lvl))
	elif str(res["type"]) == "energy":
		res_txt += " %d" % int(res["max"])
	lines.append("%s — Q: %s · E: %s · Kaynak: %s · Pasif: %s" % [race["name"], race["abilities"]["q"]["name"],
		race["abilities"]["e"]["name"], res_txt, race["passive"]["description"]])
	var kit := RaceKit.new(rid, lvl)
	for slot: int in 2:
		var wc: Dictionary = config["weapons"][slot]
		var wt: Dictionary = DataDB.table("weapon_types")[wc["type"]]
		var fam := str(wt["family"])
		var st := RaceStats.compute(rid, lvl, fam)
		var eff := RaceStats.matrix_text(rid, fam)
		var cd := kit.cooldown_for("heavy", fam)
		var heavy_txt := str(wt["heavy"]["name"])
		if kit.cost("heavy", fam) > 0.0:
			heavy_txt += " (%d %s)" % [roundi(kit.cost("heavy", fam)), kit.resource_name()]
		if cd > 0.0:
			heavy_txt += " (%.1f sn bekleme%s)" % [cd, ", büyü silahı ×1,5" if kit.is_foreign_spell_weapon(fam) else ""]
		lines.append("%d. silah %s: maks can %d · matris: %s · sağ tık: %s" % [slot + 1, wt["name"], roundi(st.max_hp), eff, heavy_txt])
	_info.text = "\n".join(lines)


func _row(parent: Control, title: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var l := _label(title, 18, Color(0.9, 0.9, 0.95))
	l.custom_minimum_size = Vector2(110, 0)
	row.add_child(l)
	parent.add_child(row)
	return row


func _option(parent: Control, items: Array, width: float) -> OptionButton:
	var o := OptionButton.new()
	for it: Variant in items:
		o.add_item(str(it))
	o.custom_minimum_size = Vector2(width, 38)
	o.add_theme_font_size_override("font_size", 16)
	parent.add_child(o)
	return o


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
