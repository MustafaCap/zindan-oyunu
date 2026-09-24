## Hud — prototip arayüzü: can barı, sağ tık ve Space bekleme göstergeleri, dalga bilgisi, ortadaki mesajlar.
## Aşama 2: iki aktif silah paneli (element ikonu, ad, nadirlik rengi; aktif olan vurgulu) ve hata ayıklama notları.
## Ayrıntılı arayüz tasarımı sonraya bırakıldı (GDD Açık Kararlar); bu yalnızca test için.
class_name Hud
extends CanvasLayer

var player: Player
var wave_text: String = ""
var _panel: Control
var _center: Label
var _info: Label
var _hint_lines: PackedStringArray = []
var _note_text: String = ""
var _note_t: float = 0.0


func _ready() -> void:
	layer = 10
	_panel = Control.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.draw.connect(_draw_panel)
	add_child(_panel)

	_center = _make_label(48, Color(1, 0.9, 0.6))
	_center.set_anchors_preset(Control.PRESET_CENTER)
	_center.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_center.grow_vertical = Control.GROW_DIRECTION_BOTH
	_center.position.y -= 160

	_info = _make_label(22, Color(0.85, 0.85, 0.9))
	_info.position = Vector2(32, 96)

	_hint_lines = PackedStringArray([
		"WASD yürü · Fare nişan · Sol tık vuruş · Sağ tık Dönen kesik · Space atılma · Tab silah değiştir · R yeniden başla · Esc çık",
		"Deneme tuşları: 2 Ateş · 3 Su · 4 Yıldırım · 5 Zehir · 6 Buz · 7 Karanlık · 0 Elementsiz · 8 Özellik değiştir · N Yeni dalga",
	])

	var ver := _make_label(16, Color(0.5, 0.5, 0.55))
	ver.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	ver.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ver.position = Vector2(-32, 24)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ver.text = "v%s · Aşama 2 · savaş çekirdeği" % ProjectSettings.get_setting("application/config/version", "?")


func _make_label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func show_message(text: String) -> void:
	_center.text = text


## Ekranın altında kısa süre görünen not (örn. silah değişti).
func flash_note(text: String) -> void:
	_note_text = text
	_note_t = 2.0


func _process(delta: float) -> void:
	_info.text = wave_text
	_note_t = maxf(_note_t - delta, 0.0)
	_panel.queue_redraw()


func _draw_panel() -> void:
	if player == null:
		return
	# Can barı
	var pos := Vector2(32, 32)
	var size := Vector2(360, 26)
	_panel.draw_rect(Rect2(pos - Vector2(3, 3), size + Vector2(6, 6)), Color(0, 0, 0, 0.75))
	_panel.draw_rect(Rect2(pos, size), Color(0.25, 0.08, 0.08))
	_panel.draw_rect(Rect2(pos, Vector2(size.x * player.hp / player.max_hp, size.y)), Color(0.85, 0.18, 0.2))
	var font := ThemeDB.fallback_font
	_panel.draw_string_outline(font, pos + Vector2(10, 20), "%d / %d" % [ceili(player.hp), roundi(player.max_hp)], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 5, Color.BLACK)
	_panel.draw_string(font, pos + Vector2(10, 20), "%d / %d" % [ceili(player.hp), roundi(player.max_hp)], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	# Bekleme göstergeleri (alt orta)
	var vp := _panel.size
	_cooldown_box(Vector2(vp.x * 0.5 - 80, vp.y - 180), "Sağ tık", player.heavy_cd, player.heavy_cd_max)
	_cooldown_box(Vector2(vp.x * 0.5 + 10, vp.y - 180), "Space", player.dash_cd, player.dash_cd_max)
	# Silah paneli (sol alt): iki aktif silah
	var wy := vp.y - 250.0
	for i: int in player.weapons.size():
		_weapon_box(Vector2(32, wy + i * 52.0), player.weapons[i], i == player.active_index, i + 1)
	_panel.draw_string_outline(ThemeDB.fallback_font, Vector2(32, wy - 12), "Tab: silah değiştir", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color.BLACK)
	_panel.draw_string(ThemeDB.fallback_font, Vector2(32, wy - 12), "Tab: silah değiştir", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.8, 0.8, 0.85))
	# Alt satırlar: tuş ipuçları
	for i: int in _hint_lines.size():
		var hp := Vector2(32, vp.y - 44 + i * 24)
		_panel.draw_string_outline(ThemeDB.fallback_font, hp, _hint_lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, 4, Color.BLACK)
		_panel.draw_string(ThemeDB.fallback_font, hp, _hint_lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.62, 0.62, 0.68))
	# Kısa not (silah değişti vb.)
	if _note_t > 0.0:
		var a := clampf(_note_t / 0.5, 0.0, 1.0)
		var np := Vector2(0, vp.y - 250)
		_panel.draw_string_outline(ThemeDB.fallback_font, np, _note_text, HORIZONTAL_ALIGNMENT_CENTER, vp.x, 28, 7, Color(0, 0, 0, a))
		_panel.draw_string(ThemeDB.fallback_font, np, _note_text, HORIZONTAL_ALIGNMENT_CENTER, vp.x, 28, Color(1, 0.95, 0.8, a))


func _weapon_box(p: Vector2, w: Weapon, active: bool, slot: int) -> void:
	var s := Vector2(420, 44)
	_panel.draw_rect(Rect2(p, s), Color(0.12, 0.12, 0.16, 0.92 if active else 0.6))
	_panel.draw_rect(Rect2(p, s), w.rarity_color() if active else Color(0.35, 0.35, 0.4), false, 3.0 if active else 1.0)
	ElementIcons.draw_badge(_panel, w.element, p + Vector2(24, 22), 14.0)
	var font := ThemeDB.fallback_font
	var name_col := w.rarity_color().lightened(0.25) if active else Color(0.6, 0.6, 0.65)
	_panel.draw_string(font, p + Vector2(48, 20), "%d. %s" % [slot, w.display_name()], HORIZONTAL_ALIGNMENT_LEFT, s.x - 56, 19, name_col)
	var sub := "%s · %s" % [w.rarity_name(), Weapon.kind_name(w.element)]
	if not w.traits.is_empty():
		sub += " · " + str(Traits.data(w.traits[0])["name"])
	_panel.draw_string(font, p + Vector2(48, 38), sub, HORIZONTAL_ALIGNMENT_LEFT, s.x - 56, 14, Color(0.7, 0.7, 0.75))


func _cooldown_box(p: Vector2, label: String, cd: float, cd_max: float) -> void:
	var s := Vector2(70, 70)
	_panel.draw_rect(Rect2(p, s), Color(0.12, 0.12, 0.16, 0.9))
	if cd > 0.0 and cd_max > 0.0:
		var k := cd / cd_max
		_panel.draw_rect(Rect2(p + Vector2(0, s.y * (1.0 - k)), Vector2(s.x, s.y * k)), Color(0, 0, 0, 0.65))
		_panel.draw_string(ThemeDB.fallback_font, p + Vector2(0, 44), "%.1f" % cd, HORIZONTAL_ALIGNMENT_CENTER, s.x, 20, Color.WHITE)
	_panel.draw_rect(Rect2(p, s), Color(0.9, 0.8, 0.5) if cd <= 0.0 else Color(0.4, 0.4, 0.45), false, 2.0)
	_panel.draw_string(ThemeDB.fallback_font, p + Vector2(0, s.y + 20), label, HORIZONTAL_ALIGNMENT_CENTER, s.x, 16, Color(0.8, 0.8, 0.85))
