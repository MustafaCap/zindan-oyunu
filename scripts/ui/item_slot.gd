## ItemSlot — envanter arayüzünde tek bir göz: çanta gözü, 4 slottan biri, tüccar tezgâhı, satış/yere bırakma alanı
## ya da demirci örsü. Sürükle-bırak Godot'nun Control sistemiyle (_get_drag_data / _can_drop_data / _drop_data);
## kararları InventoryUI verir. Eşya çizimi placeholder'dır (Aşama 8'de gerçek ikonlar gelir).
class_name ItemSlot
extends Control

## kind: "inv" (çanta ya da slot; ref dolu), "stock" (tüccar tezgâhı; index), "sell", "drop", "smith"
var kind: String = "inv"
var ref: Dictionary = {}
var index: int = -1
var title: String = ""            ## gözün altında/üstünde görünen ad ("Aktif 1", "Yere bırak"…)
var ui: Node                      ## InventoryUI
var hovered: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func() -> void:
		hovered = true
		ui.call("on_slot_hover", self, true)
		queue_redraw())
	mouse_exited.connect(func() -> void:
		hovered = false
		ui.call("on_slot_hover", self, false)
		queue_redraw())


func item() -> Variant:
	return ui.call("slot_item", self)


func _get_drag_data(_at: Vector2) -> Variant:
	var data: Variant = ui.call("drag_data_for", self)
	if data == null:
		return null
	var prev := DragPreview.new()
	prev.item = item()
	prev.player_level = int(ui.call("player_level"))
	prev.size = Vector2(72, 72)
	prev.position = -prev.size * 0.5
	var holder := Control.new()
	holder.add_child(prev)
	set_drag_preview(holder)
	return data


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return bool(ui.call("can_drop", data, self))


func _drop_data(_at: Vector2, data: Variant) -> void:
	ui.call("do_drop", data, self)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			ui.call("quick_action", self)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_LEFT and mb.double_click:
			ui.call("quick_action", self)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			ui.call("select_slot", self)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var it: Variant = item()
	var selected := bool(ui.call("is_selected", self))
	match kind:
		"sell", "drop", "smith":
			draw_rect(r, Color(0.16, 0.13, 0.1, 0.9) if kind != "drop" else Color(0.12, 0.12, 0.14, 0.9))
			if it == null:
				var font := ThemeDB.fallback_font
				draw_string(font, Vector2(4, size.y * 0.5 + 6), title, HORIZONTAL_ALIGNMENT_CENTER, size.x - 8, 15, Color(0.75, 0.72, 0.65))
		_:
			draw_rect(r, Color(0.09, 0.09, 0.12, 0.95))
	if it != null:
		draw_item(self, it, r.grow(-3), int(ui.call("player_level")))
	var border := Color(0.35, 0.35, 0.42)
	var bw := 1.5
	if it is Weapon:
		border = (it as Weapon).rarity_color()
		bw = 2.5
	elif it is Talisman:
		border = (it as Talisman).color()
		bw = 2.5
	if bool(ui.call("drop_highlight", self)):
		border = Color(0.5, 1.0, 0.55)
		bw = 3.0
	if selected:
		border = Color(1.0, 0.92, 0.5)
		bw = 3.5
	elif hovered:
		border = border.lightened(0.35)
	draw_rect(r, border, false, bw)


## Eşyanın küçük çizimi (arayüzde ve sürükleme önizlemesinde).
static func draw_item(ci: CanvasItem, it: Variant, r: Rect2, player_level: int) -> void:
	var font := ThemeDB.fallback_font
	var c := r.get_center()
	var s := minf(r.size.x, r.size.y)
	if it is Weapon:
		var w := it as Weapon
		var rc := w.rarity_color()
		ci.draw_rect(r, Color(rc.darkened(0.75), 0.9))
		if w.is_legendary():
			ci.draw_circle(c, s * 0.34, Color(rc, 0.25))
		var ec := Weapon.kind_color(w.element)
		var a := c + Vector2(-s * 0.26, s * 0.2)
		var b := c + Vector2(s * 0.24, -s * 0.24)
		ci.draw_line(a, b, Color(0, 0, 0, 0.7), s * 0.12)
		ci.draw_line(a, b, ec, s * 0.07)
		ci.draw_line(a + Vector2(-s * 0.06, -s * 0.12), a + Vector2(s * 0.1, s * 0.05), rc.lightened(0.2), s * 0.06)
		ci.draw_string(font, r.position + Vector2(3, 15), w.type_name(), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 6, int(clampf(s * 0.16, 11, 15)), Color(0.92, 0.92, 0.95))
		ci.draw_string(font, r.position + Vector2(3, r.size.y - 5), "Lv %d" % w.level, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 6, int(clampf(s * 0.17, 11, 16)), Color(1, 0.95, 0.75))
		if w.is_elemental():
			ElementIcons.draw_badge(ci, w.element, r.position + Vector2(r.size.x - s * 0.15, r.size.y - s * 0.15), s * 0.11)
		if not w.traits.is_empty():
			# Özellik sayısı: sağ üstte mor noktalar
			for k: int in w.traits.size():
				ci.draw_circle(r.position + Vector2(r.size.x - 8 - k * 9, 9), 3.5, Color(0.85, 0.75, 1.0))
		if w.is_locked(player_level):
			ci.draw_rect(r, Color(0, 0, 0, 0.55))
			ci.draw_string(font, Vector2(r.position.x, c.y + 5), "KİLİTLİ", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, int(clampf(s * 0.17, 11, 15)), Color(1, 0.45, 0.4))
	elif it is Talisman:
		var t := it as Talisman
		var tc := t.color()
		ci.draw_rect(r, Color(tc.darkened(0.8), 0.9))
		var gem := PackedVector2Array([c + Vector2(0, -s * 0.3), c + Vector2(s * 0.22, -s * 0.05), c + Vector2(0, s * 0.25), c + Vector2(-s * 0.22, -s * 0.05)])
		ci.draw_colored_polygon(gem, tc)
		gem.append(gem[0])
		ci.draw_polyline(gem, Color(1, 1, 1, 0.8), 1.5)
		ci.draw_string(font, r.position + Vector2(3, r.size.y - 5), "Tılsım", HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 6, 12, tc.lightened(0.4))


## Sürüklenen eşyanın önizlemesi.
class DragPreview:
	extends Control
	var item: Variant
	var player_level: int = 1

	func _draw() -> void:
		modulate = Color(1, 1, 1, 0.85)
		ItemSlot.draw_item(self, item, Rect2(Vector2.ZERO, size), player_level)
