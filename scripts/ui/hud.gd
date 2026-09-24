## Hud — prototip arayüzü: can barı, sağ tık ve Space bekleme göstergeleri, dalga bilgisi, ortadaki mesajlar.
## Ayrıntılı arayüz tasarımı sonraya bırakıldı (GDD Açık Kararlar); bu yalnızca test için.
class_name Hud
extends CanvasLayer

var player: Player
var wave_text: String = ""
var _panel: Control
var _center: Label
var _info: Label
var _hint: Label


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

	_hint = _make_label(18, Color(0.6, 0.6, 0.66))
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_hint.position = Vector2(32, -64)
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint.text = "WASD yürü · Fare nişan · Sol tık vuruş · Sağ tık Dönen kesik · Space atılma · R yeniden başla · Esc çık"

	var ver := _make_label(16, Color(0.5, 0.5, 0.55))
	ver.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	ver.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ver.position = Vector2(-32, 24)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ver.text = "v%s · Aşama 1 prototipi" % ProjectSettings.get_setting("application/config/version", "?")


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


func _process(_delta: float) -> void:
	_info.text = wave_text
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
	_cooldown_box(Vector2(vp.x * 0.5 - 80, vp.y - 110), "Sağ tık", player.heavy_cd, player.heavy_cd_max)
	_cooldown_box(Vector2(vp.x * 0.5 + 10, vp.y - 110), "Space", player.dash_cd, player.dash_cd_max)


func _cooldown_box(p: Vector2, label: String, cd: float, cd_max: float) -> void:
	var s := Vector2(70, 70)
	_panel.draw_rect(Rect2(p, s), Color(0.12, 0.12, 0.16, 0.9))
	if cd > 0.0 and cd_max > 0.0:
		var k := cd / cd_max
		_panel.draw_rect(Rect2(p + Vector2(0, s.y * (1.0 - k)), Vector2(s.x, s.y * k)), Color(0, 0, 0, 0.65))
		_panel.draw_string(ThemeDB.fallback_font, p + Vector2(0, 44), "%.1f" % cd, HORIZONTAL_ALIGNMENT_CENTER, s.x, 20, Color.WHITE)
	_panel.draw_rect(Rect2(p, s), Color(0.9, 0.8, 0.5) if cd <= 0.0 else Color(0.4, 0.4, 0.45), false, 2.0)
	_panel.draw_string(ThemeDB.fallback_font, p + Vector2(0, s.y + 20), label, HORIZONTAL_ALIGNMENT_CENTER, s.x, 16, Color(0.8, 0.8, 0.85))
