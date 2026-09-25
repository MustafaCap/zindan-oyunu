## InventoryUI — 4 slotluk envanter arayüzü (kullanıcı kararı: çanta yok; economy.bag_size > 0 olursa çanta ızgarası da
## görünür); tüccar ve demirci panelleri (GDD: Görsel Stil > Arayüz: envanter ızgarası,
## sürükle-bırak, stat karşılaştırmalı tooltip). I ile açılır (tüccar/demirci F ile), açıkken oyun duraklar.
##   Sürükle-bırak: eşyayı taşı ya da yer değiştir; "Yere bırak" alanına bırakınca yere düşer.
##   Sağ tık / çift tık: aktif slottaki silah Rezonans'la yer değiştirir; Rezonans/Esnek'teki açık silah boş aktif slota
##   (yoksa kullanılan aktif silahla yer değiştirir).   Sol tık: seç (tüccarda satmak, demircide işlemek için).
##   Tüccar: tezgâhtaki eşyayı satın al, iksir al; seçileni sat ya da "Sat" alanına sürükle.
##   Demirci: silahı örse sürükle ya da seç; level atlat, elementi ya da özellikleri yeniden çek.
## Savaş sürerken (GameState.in_combat) slotlara dokunulamaz.
## Ayrıntılı arayüz tasarımı sonraya bırakıldı (GDD Açık Kararlar); bu ilk sürümdür.
class_name InventoryUI
extends CanvasLayer

signal changed                         ## envanter değişti (oyuncunun silahları yeniden yüklenir)
signal drop_requested(item: Variant)   ## eşya yere bırakılacak
signal closed

var player: Player
var mode: String = "bag"               ## bag, merchant, blacksmith
var prop: RoomProp                     ## tüccar/demirci (tezgâh stoğu burada)
var rng := RandomNumberGenerator.new()
var selected: ItemSlot
var last_message: String = ""

var _slot_nodes: Dictionary = {}       ## slot adı -> ItemSlot
var _bag_nodes: Array[ItemSlot] = []
var _stock_rows: VBoxContainer
var _stock_slots: Array[ItemSlot] = []
var _root: HBoxContainer
var _inv_panel: PanelContainer
var _side_panel: PanelContainer
var _merchant_box: VBoxContainer
var _smith_box: VBoxContainer
var _gold_label: Label
var _status: Label
var _side_status: Label
var _sell_slot: ItemSlot
var _drop_slot: ItemSlot
var _smith_slot: ItemSlot
var _smith_target: Dictionary = {}     ## örsteki silahın ref'i
var _smith_buttons: Dictionary = {}
var _sell_button: Button
var _potion_button: Button
var _tooltip: PanelContainer
var _tooltip_text: RichTextLabel
var _hover: ItemSlot
var _dragging: Variant = null


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()


# --- açma / kapama ---

func open_ui(p_mode: String, p_player: Player, p_prop: RoomProp = null) -> void:
	player = p_player
	mode = p_mode
	prop = p_prop
	selected = null
	_smith_target = {}
	last_message = ""
	_side_panel.visible = mode != "bag"
	_merchant_box.visible = mode == "merchant"
	_smith_box.visible = mode == "blacksmith"
	visible = true
	get_tree().paused = true
	refresh()


func close() -> void:
	if not visible:
		return
	visible = false
	_tooltip.visible = false
	get_tree().paused = false
	closed.emit()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if k == KEY_ESCAPE or k == KEY_I or (k == KEY_F and mode != "bag"):
			close()
			get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not visible:
		return
	if _tooltip.visible:
		var mp := _tooltip.get_viewport().get_mouse_position()
		var vs := _tooltip.get_viewport().get_visible_rect().size
		var pos := mp + Vector2(24, 18)
		if pos.x + _tooltip.size.x > vs.x - 8:
			pos.x = mp.x - _tooltip.size.x - 24
		if pos.y + _tooltip.size.y > vs.y - 8:
			pos.y = vs.y - _tooltip.size.y - 8
		_tooltip.position = pos


# --- durum yardımcıları (ItemSlot çağırır) ---

func inv() -> Inventory:
	return GameState.inventory


func player_level() -> int:
	return player.level if player else GameState.level


func race_id() -> String:
	return player.race_id if player else GameState.race_id


func floor_i() -> int:
	return clampi(GameState.floor_index, 1, 4)


func slot_item(s: ItemSlot) -> Variant:
	match s.kind:
		"inv":
			return inv().get_item(s.ref)
		"stock":
			var st := stock()
			return st[s.index] if s.index >= 0 and s.index < st.size() else null
		"smith":
			return inv().get_item(_smith_target) if not _smith_target.is_empty() else null
	return null


func stock() -> Array:
	return prop.stock if prop else []


func is_selected(s: ItemSlot) -> bool:
	return s == selected


func drop_highlight(s: ItemSlot) -> bool:
	return _dragging != null and s.hovered and can_drop(_dragging, s)


func drag_data_for(s: ItemSlot) -> Variant:
	if s.kind != "inv" or slot_item(s) == null:
		return null
	_dragging = {"from": s.ref}
	_tooltip.visible = false
	return _dragging


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_dragging = null
		refresh()


func can_drop(data: Variant, s: ItemSlot) -> bool:
	if typeof(data) != TYPE_DICTIONARY or not (data as Dictionary).has("from"):
		return false
	var from: Dictionary = data["from"]
	match s.kind:
		"inv":
			return inv().check_move(from, s.ref, player_level(), GameState.in_combat) == ""
		"drop":
			return inv().can_remove(from, GameState.in_combat) == ""
		"sell":
			return mode == "merchant" and inv().can_remove(from, GameState.in_combat) == ""
		"smith":
			return mode == "blacksmith" and inv().get_item(from) is Weapon
	return false


func do_drop(data: Variant, s: ItemSlot) -> void:
	var from: Dictionary = data["from"]
	match s.kind:
		"inv":
			_result(inv().move(from, s.ref, player_level(), GameState.in_combat), "")
		"drop":
			var why := inv().can_remove(from, GameState.in_combat)
			if why == "":
				var it: Variant = inv().remove(from)
				drop_requested.emit(it)
			_result(why, "Yere bırakıldı")
		"sell":
			sell_ref(from)
		"smith":
			_smith_target = from
			refresh()
	_dragging = null


## Sağ tık / çift tık: hızlı tak / çıkar.
func quick_action(s: ItemSlot) -> void:
	if s.kind == "stock":
		buy_stock(s.index)
		return
	if s.kind != "inv":
		return
	var it: Variant = slot_item(s)
	if it == null:
		return
	var I := inv()
	var lvl := player_level()
	var combat := GameState.in_combat
	if str(s.ref["area"]) == "slot":
		var n0 := str(s.ref["name"])
		if I.bag.size() > 0:
			var free := I.first_free_bag()
			_result("Çanta dolu" if free < 0 else I.move(s.ref, Inventory.bag_ref(free), lvl, combat), "")
			return
		# Çanta yok: aktif silah ↔ Rezonans; Rezonans/Esnek'teki açık silah → aktif slot
		var dest := ""
		if Inventory.ACTIVE_SLOTS.has(n0):
			dest = "resonance"
		elif it is Weapon and not (it as Weapon).is_locked(lvl):
			for n: String in Inventory.ACTIVE_SLOTS:
				if I.slots[n] == null:
					dest = n
					break
			if dest == "":
				dest = I.active_slot
		if dest == "":
			_result("Bu eşyayı sürükleyerek taşı (kilitli silah aktif slota konamaz)", "")
			return
		_result(I.move(s.ref, Inventory.slot_ref(dest), lvl, combat), "")
		return
	var target := ""
	if it is Talisman:
		target = "flex"
	elif (it as Weapon).is_locked(lvl):
		target = "resonance"
	else:
		for n: String in Inventory.ACTIVE_SLOTS:
			if I.slots[n] == null:
				target = n
				break
		if target == "":
			target = I.active_slot
	_result(I.move(s.ref, Inventory.slot_ref(target), lvl, combat), "")


func select_slot(s: ItemSlot) -> void:
	if s.kind == "inv" and slot_item(s) != null:
		selected = s
		if mode == "blacksmith" and slot_item(s) is Weapon:
			_smith_target = s.ref
	refresh()


func on_slot_hover(s: ItemSlot, on: bool) -> void:
	if on:
		_hover = s
		_show_tooltip(s)
	elif _hover == s:
		_hover = null
		_tooltip.visible = false


# --- tüccar ---

func buy_stock(i: int) -> void:
	if prop == null:
		return
	var it: Variant = stock()[i] if i >= 0 and i < stock().size() else null
	var name := _item_name(it)
	_result(Shop.buy(inv(), stock(), i, floor_i(), player_level()), "Satın alındı: %s" % name, true)


func buy_potion() -> void:
	_result(Shop.buy_potion(inv(), floor_i(), race_id()), "İksir alındı", true)


func sell_ref(ref: Dictionary) -> void:
	var it: Variant = inv().get_item(ref)
	var price := Shop.sell_price(it, floor_i()) if it != null else 0
	_result(Shop.sell(inv(), ref, floor_i(), GameState.in_combat), "Satıldı: %s (+%d altın)" % [_item_name(it), price], true)
	if selected and selected.kind == "inv" and inv().get_item(selected.ref) == null:
		selected = null


func sell_selected() -> void:
	if selected and selected.kind == "inv":
		sell_ref(selected.ref)


# --- demirci ---

func smith_weapon() -> Weapon:
	return inv().get_item(_smith_target) as Weapon if not _smith_target.is_empty() else null


func smith_action(action: String) -> void:
	var w := smith_weapon()
	if w == null:
		_result("Önce bir silah seç", "", true)
		return
	var why := ""
	var ok := ""
	match action:
		"level":
			var old := w.level
			why = Shop.level_up(inv(), w, player_level(), floor_i())
			ok = "Level atladı: %d → %d" % [old, w.level]
		"element":
			why = Shop.reroll_element(inv(), w, floor_i(), rng)
			ok = "Yeni element: %s" % Weapon.kind_name(w.element)
		"traits":
			why = Shop.reroll_traits(inv(), w, floor_i(), rng)
			ok = "Yeni özellik: %s" % ", ".join(w.traits.map(func(t: String) -> String: return str(Traits.data(t)["name"])))
	_result(why, ok, true)


# --- sonuç ve yenileme ---

func _result(why: String, ok_text: String, side: bool = false) -> void:
	if why == "same":
		why = ""
	last_message = why if why != "" else ok_text
	if why == "":
		changed.emit()
	refresh()
	var lab := _side_status if side else _status
	lab.add_theme_color_override("font_color", Color(1, 0.55, 0.5) if why != "" else Color(0.6, 1.0, 0.65))
	lab.text = last_message


func refresh() -> void:
	if not is_inside_tree():
		return
	var I := inv()
	_gold_label.text = "Altın: %d    ·    İksir: %d / %d%s" % [I.gold, I.potions, I.potion_max,
		"" if race_id() == "" or bool(DataDB.table("races")[race_id()]["healing"]["potions"]) else " (kullanamazsın)"]
	if GameState.in_combat:
		_status.text = "SAVAŞ SÜRÜYOR: slotlar kilitli (oda temizlenince düzenle)"
		_status.add_theme_color_override("font_color", Color(1, 0.55, 0.5))
	for n: Node in _slot_nodes.values() + _bag_nodes:
		(n as Control).queue_redraw()
	for c: Control in [_sell_slot, _drop_slot, _smith_slot]:
		c.queue_redraw()
	if mode == "merchant":
		_refresh_merchant()
	elif mode == "blacksmith":
		_refresh_smith()
	if _hover and is_instance_valid(_hover) and _hover.is_inside_tree():
		_show_tooltip(_hover)
	else:
		_hover = null
		_tooltip.visible = false


func _refresh_merchant() -> void:
	for c: Node in _stock_rows.get_children():
		_stock_rows.remove_child(c)
		c.queue_free()
	_stock_slots.clear()
	var st := stock()
	for i: int in st.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var sl := _make_slot("stock", {}, Vector2(76, 76))
		sl.index = i
		_stock_slots.append(sl)
		row.add_child(sl)
		var it: Variant = st[i]
		var info := Label.new()
		info.text = "%s\n%s" % [_item_name(it), _item_sub(it)]
		info.custom_minimum_size = Vector2(250, 0)
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_theme_font_size_override("font_size", 15)
		info.add_theme_color_override("font_color", _item_color(it).lightened(0.3))
		row.add_child(info)
		var b := Button.new()
		var price := Shop.item_price(it, floor_i())
		b.text = "Satın al\n%d altın" % price
		b.custom_minimum_size = Vector2(120, 60)
		b.disabled = inv().gold < price
		var idx := i
		b.pressed.connect(func() -> void: buy_stock(idx))
		row.add_child(b)
		_stock_rows.add_child(row)
	if st.is_empty():
		var l := Label.new()
		l.text = "Tezgâh boş."
		_stock_rows.add_child(l)
	var pp := Shop.potion_price(floor_i())
	_potion_button.text = "İksir al (%%%d can) — %d altın" % [roundi(float(DataDB.get_value("progression", "potions.heal_pct")) * 100.0), pp]
	_potion_button.disabled = inv().gold < pp or inv().potions >= inv().potion_max \
		or not bool(DataDB.table("races")[race_id()]["healing"]["potions"])
	var sel_item: Variant = inv().get_item(selected.ref) if selected and selected.kind == "inv" else null
	_sell_button.disabled = sel_item == null
	_sell_button.text = "Seçileni sat" if sel_item == null else "Sat: %s (+%d altın)" % [_item_name(sel_item), Shop.sell_price(sel_item, floor_i())]


func _refresh_smith() -> void:
	var w := smith_weapon()
	var lvl := player_level()
	var f := floor_i()
	var defs := {
		"level": ["Level atlat", "" if w == null else Shop.level_up_block(w, lvl)],
		"element": ["Elementi yeniden çek", "" if w == null else Shop.reroll_element_block(w)],
		"traits": ["Özellikleri yeniden çek", "" if w == null else Shop.reroll_trait_block(w)],
	}
	for k: String in defs.keys():
		var b: Button = _smith_buttons[k]
		var base: String = defs[k][0]
		var block: String = defs[k][1]
		if w == null:
			b.text = base
			b.disabled = true
			continue
		if block != "":
			b.text = "%s\n(%s)" % [base, block]
			b.disabled = true
			continue
		var cost := 0
		match k:
			"level":
				cost = Shop.level_up_cost(w, lvl, f)
				b.text = "%s: Lv %d → %d\n%d altın" % [base, w.level, Shop.level_up_target(w, lvl), cost]
			"element":
				cost = Shop.reroll_element_cost(w, f)
				b.text = "%s (%s)\n%d altın" % [base, Weapon.kind_name(w.element), cost]
			"traits":
				cost = Shop.reroll_trait_cost(w, f)
				b.text = "%s\n%d altın" % [base, cost]
		b.disabled = inv().gold < cost


func _show_tooltip(s: ItemSlot) -> void:
	var it: Variant = slot_item(s)
	if it == null or _dragging != null:
		_tooltip.visible = false
		return
	var compare: Weapon = null
	if player and it is Weapon and it != player.weapon():
		compare = player.weapon()
	var price := ""
	if mode == "merchant":
		if s.kind == "stock":
			price = "[color=#ffd966]Fiyat: %d altın[/color]" % Shop.item_price(it, floor_i())
		elif s.kind == "inv":
			price = "[color=#ffd966]Satış: %d altın[/color]" % Shop.sell_price(it, floor_i())
	_tooltip_text.text = WeaponInfo.tooltip(it, race_id(), player_level(), compare, floor_i(), price)
	_tooltip.reset_size()
	_tooltip.visible = true


func _item_name(it: Variant) -> String:
	if it is Weapon:
		return (it as Weapon).display_name()
	if it is Talisman:
		return (it as Talisman).display_name()
	return ""


func _item_sub(it: Variant) -> String:
	if it is Weapon:
		var w := it as Weapon
		return "%s %s · Lv %d%s" % [w.rarity_name(), w.type_name(), w.level, " · KİLİTLİ" if w.is_locked(player_level()) else ""]
	if it is Talisman:
		return "Tılsım"
	return ""


func _item_color(it: Variant) -> Color:
	if it is Weapon:
		return (it as Weapon).rarity_color()
	if it is Talisman:
		return (it as Talisman).color()
	return Color.WHITE


# --- kurulum ---

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	_root = HBoxContainer.new()
	_root.add_theme_constant_override("separation", 24)
	_root.set_anchors_preset(Control.PRESET_CENTER)
	_root.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_root.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_root)

	# Yan panel: tüccar / demirci
	_side_panel = _panel()
	_root.add_child(_side_panel)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 12)
	side.custom_minimum_size = Vector2(500, 0)
	_side_panel.add_child(side)

	_merchant_box = VBoxContainer.new()
	_merchant_box.add_theme_constant_override("separation", 10)
	side.add_child(_merchant_box)
	_merchant_box.add_child(_label("Tüccar", 28, Color(1, 0.85, 0.4)))
	_merchant_box.add_child(_label("Tezgâhtaki eşyaya sağ tık ya da 'Satın al'. Satmak için eşyanı seç ya da 'Sat' alanına sürükle.", 14, Color(0.7, 0.7, 0.75), true))
	_stock_rows = VBoxContainer.new()
	_stock_rows.add_theme_constant_override("separation", 8)
	_merchant_box.add_child(_stock_rows)
	_potion_button = Button.new()
	_potion_button.custom_minimum_size = Vector2(0, 44)
	_potion_button.pressed.connect(buy_potion)
	_merchant_box.add_child(_potion_button)
	var sell_row := HBoxContainer.new()
	sell_row.add_theme_constant_override("separation", 12)
	_sell_slot = _make_slot("sell", {}, Vector2(120, 76))
	_sell_slot.title = "Sat (sürükle)"
	sell_row.add_child(_sell_slot)
	_sell_button = Button.new()
	_sell_button.custom_minimum_size = Vector2(340, 76)
	_sell_button.pressed.connect(sell_selected)
	sell_row.add_child(_sell_button)
	_merchant_box.add_child(sell_row)

	_smith_box = VBoxContainer.new()
	_smith_box.add_theme_constant_override("separation", 10)
	side.add_child(_smith_box)
	_smith_box.add_child(_label("Demirci", 28, Color(0.7, 0.8, 1.0)))
	_smith_box.add_child(_label("Silahı örse sürükle ya da slotta seç. Level atlatma bir sonraki 5'in katına çıkarır (en fazla senin levelin).", 14, Color(0.7, 0.7, 0.75), true))
	var smith_row := HBoxContainer.new()
	smith_row.add_theme_constant_override("separation", 14)
	_smith_slot = _make_slot("smith", {}, Vector2(110, 110))
	_smith_slot.title = "Örs"
	smith_row.add_child(_smith_slot)
	var smith_btns := VBoxContainer.new()
	smith_btns.add_theme_constant_override("separation", 8)
	for k: String in ["level", "element", "traits"]:
		var b := Button.new()
		b.custom_minimum_size = Vector2(340, 56)
		var key := k
		b.pressed.connect(func() -> void: smith_action(key))
		smith_btns.add_child(b)
		_smith_buttons[k] = b
	smith_row.add_child(smith_btns)
	_smith_box.add_child(smith_row)

	_side_status = _label("", 16, Color(0.6, 1.0, 0.65), true)
	side.add_child(_side_status)

	# Envanter paneli
	_inv_panel = _panel()
	_root.add_child(_inv_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(600, 0)
	_inv_panel.add_child(box)
	box.add_child(_label("Envanter (4 slot)", 28, Color(1, 0.9, 0.6)))
	_gold_label = _label("", 18, Color(1, 0.85, 0.35))
	box.add_child(_gold_label)

	var slot_row := HBoxContainer.new()
	slot_row.add_theme_constant_override("separation", 14)
	for n: String in Inventory.SLOT_NAMES:
		var col := VBoxContainer.new()
		col.add_child(_label(Inventory.SLOT_TITLES[n], 15, Color(0.85, 0.85, 0.9)))
		var sl := _make_slot("inv", Inventory.slot_ref(n), Vector2(104, 104))
		_slot_nodes[n] = sl
		col.add_child(sl)
		slot_row.add_child(col)
	box.add_child(slot_row)
	box.add_child(_label("Aktif: tam güç · Rezonans: kilitliyken normal saldırının %10'u, açıkken %7'si ek hasar · Esnek: silahın özellik/pasifinin %9'u ya da tılsım", 13, Color(0.65, 0.65, 0.7), true))

	box.add_child(_label("Çanta yok: taşıyabileceğin her şey bu 4 slot. Yeni eşya için yer açmak, birini geride bırakmak demek.", 14, Color(0.9, 0.8, 0.55), true))
	if GameState.inventory.bag.size() > 0:
		box.add_child(_label("Çanta", 18, Color(0.85, 0.85, 0.9)))
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for i: int in GameState.inventory.bag.size():
		var sl2 := _make_slot("inv", Inventory.bag_ref(i), Vector2(84, 84))
		_bag_nodes.append(sl2)
		grid.add_child(sl2)
	box.add_child(grid)

	var drop_row := HBoxContainer.new()
	drop_row.add_theme_constant_override("separation", 12)
	_drop_slot = _make_slot("drop", {}, Vector2(140, 56))
	_drop_slot.title = "Yere bırak"
	drop_row.add_child(_drop_slot)
	drop_row.add_child(_label("Sürükle-bırak: slotlar arası taşı / yer değiştir\nSağ tık ya da çift tık: aktif ↔ Rezonans · Sol tık: seç\nI ya da Esc: kapat", 13, Color(0.65, 0.65, 0.7)))
	box.add_child(drop_row)
	_status = _label("", 16, Color(0.6, 1.0, 0.65), true)
	box.add_child(_status)

	_tooltip = PanelContainer.new()
	var tsb := StyleBoxFlat.new()
	tsb.bg_color = Color(0.06, 0.06, 0.08, 0.97)
	tsb.border_color = Color(0.6, 0.55, 0.4)
	tsb.set_border_width_all(1)
	tsb.set_corner_radius_all(4)
	tsb.set_content_margin_all(12)
	_tooltip.add_theme_stylebox_override("panel", tsb)
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.visible = false
	_tooltip.top_level = true
	_tooltip_text = RichTextLabel.new()
	_tooltip_text.bbcode_enabled = true
	_tooltip_text.fit_content = true
	_tooltip_text.scroll_active = false
	_tooltip_text.custom_minimum_size = Vector2(460, 0)
	_tooltip_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_text.add_theme_font_size_override("normal_font_size", 15)
	_tooltip_text.add_theme_font_size_override("bold_font_size", 15)
	_tooltip.add_child(_tooltip_text)
	add_child(_tooltip)


func _make_slot(kind: String, ref: Dictionary, sz: Vector2) -> ItemSlot:
	var s := ItemSlot.new()
	s.kind = kind
	s.ref = ref
	s.ui = self
	s.custom_minimum_size = sz
	return s


func _panel() -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.13, 0.97)
	sb.border_color = Color(0.9, 0.8, 0.5)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(20)
	p.add_theme_stylebox_override("panel", sb)
	return p


func _label(text: String, size: int, color: Color, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(440, 0)
	return l
