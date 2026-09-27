## UiTheme — Aşama 10: menülerin ortak görünümü (görsel yön: karanlık, kanlı, vahşi). Kömür karası
## zemin, pas-kan kırmızısı çerçeveler, kemik beyazı serif yazı; üzerine gelinen düğmenin çerçevesi kan kırmızısına döner
## ve solunda kan izi belirir. Yazı tipi Windows'un kendi serif fontlarından (SystemFont: Palatino Linotype → Book Antiqua →
## Georgia); .exe'ye font dosyası eklenmez, hiçbiri yoksa Godot'nun varsayılan fontu kullanılır.
## Kullanım: bir CanvasLayer'ın kök Control'üne `theme = UiTheme.theme()`; başlıklar için UiTheme.title().
class_name UiTheme
extends RefCounted

const INK := Color(0.045, 0.032, 0.035)              ## en koyu zemin
const PANEL_BG := Color(0.07, 0.042, 0.042, 0.96)
const FRAME := Color(0.33, 0.09, 0.07)                ## pas-kan çerçeve
const BLOOD := Color(0.5, 0.05, 0.04)                 ## kurumuş kan
const BLOOD_LIGHT := Color(0.8, 0.13, 0.09)           ## taze kan (vurgu)
const BONE := Color(0.87, 0.82, 0.74)                 ## kemik beyazı yazı
const ASH := Color(0.58, 0.52, 0.47)                  ## soluk, ikincil yazı
const GOLD := Color(0.86, 0.64, 0.3)                  ## zafer, ilk kesiş
const EMBER := Color(1.0, 0.56, 0.24)
const HOT := Color(1.0, 0.94, 0.86)                   ## üzerine gelinen düğmenin yazısı

static var _theme: Theme
static var _font: Font


static func font() -> Font:
	if _font == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Palatino Linotype", "Book Antiqua", "Georgia", "Times New Roman", "serif"])
		f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		_font = f
	return _font


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 22
	for type: String in ["Label", "Button", "CheckBox", "RichTextLabel"]:
		t.set_color("font_outline_color", type, Color.BLACK)
	t.set_color("font_color", "Label", BONE)
	t.set_constant("outline_size", "Label", 4)
	t.set_color("default_color", "RichTextLabel", BONE)
	t.set_font_size("normal_font_size", "RichTextLabel", 19)
	t.set_font_size("bold_font_size", "RichTextLabel", 19)
	t.set_stylebox("normal", "Button", button_box(false, false))
	t.set_stylebox("hover", "Button", button_box(true, false))
	t.set_stylebox("pressed", "Button", button_box(true, true))
	t.set_stylebox("disabled", "Button", button_box(false, false))
	t.set_stylebox("focus", "Button", focus_box())
	t.set_color("font_color", "Button", BONE.darkened(0.1))
	t.set_color("font_hover_color", "Button", HOT)
	t.set_color("font_focus_color", "Button", HOT)
	t.set_color("font_hover_pressed_color", "Button", HOT)
	t.set_color("font_pressed_color", "Button", BLOOD_LIGHT.lightened(0.35))
	t.set_color("font_disabled_color", "Button", ASH.darkened(0.35))
	t.set_constant("outline_size", "Button", 4)
	t.set_font_size("font_size", "Button", 26)
	t.set_stylebox("panel", "PanelContainer", panel_box())
	t.set_stylebox("panel", "Panel", panel_box())
	t.set_color("font_color", "CheckBox", BONE)
	t.set_color("font_hover_color", "CheckBox", HOT)
	t.set_font_size("font_size", "CheckBox", 20)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.12, 0.06, 0.06)
	track.border_color = FRAME
	track.set_border_width_all(1)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	t.set_stylebox("slider", "HSlider", track)
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = BLOOD
	t.set_stylebox("grabber_area", "HSlider", fill)
	var fill_hi := fill.duplicate() as StyleBoxFlat
	fill_hi.bg_color = BLOOD_LIGHT
	t.set_stylebox("grabber_area_highlight", "HSlider", fill_hi)
	_theme = t
	return t


## Düğme: dövme demir gibi koyu levha; üzerine gelince kan kırmızısı çerçeve ve solda kalın kan izi.
static func button_box(hot: bool, pressed: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.085, 0.05, 0.048, 0.93)
	sb.border_color = FRAME
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 8
	sb.content_margin_bottom = 10
	if hot:
		sb.bg_color = Color(0.2, 0.045, 0.04, 0.96) if not pressed else Color(0.3, 0.03, 0.03, 0.98)
		sb.border_color = BLOOD_LIGHT
		sb.set_border_width_all(2)
		sb.border_width_left = 7
		sb.shadow_color = Color(0.6, 0.02, 0.0, 0.35)
		sb.shadow_size = 10
	return sb


## Klavye odağı: üzerine gelinmiş gibi görünür (çerçeve yalnızca çizgi; düğmenin kendi zemini altta kalır).
static func focus_box() -> StyleBoxFlat:
	var sb := button_box(true, false)
	sb.draw_center = false
	sb.shadow_size = 0
	return sb


static func panel_box(border: Color = FRAME) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(28)
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 18
	return sb


## Büyük başlık (Kazandın, Öldün, Duraklatıldı…): serif, kalın siyah dış hat.
static func title(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.0, 0.0))
	l.add_theme_constant_override("outline_size", maxi(size / 7, 4))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func label(text: String, size: int, color: Color = BONE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Menü düğmesi: sabit genişlik, sola hizalı yazı.
static func menu_button(text: String, width: float = 360.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(width, 58)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_entered.connect(func() -> void:
		if b.focus_mode != Control.FOCUS_NONE:
			b.grab_focus())
	# Klavyeyle odak değişince de üzerine gelme sesi (fareyle gelince Audio zaten çalıyor)
	b.focus_entered.connect(func() -> void:
		if not b.is_hovered():
			Audio.play("ui_hover"))
	return b


## Ekranı kaplayan karartma (vinyet): ortası saydam, kenarları koyu.
static func vignette(strength: float = 0.85) -> TextureRect:
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0.0))
	g.set_color(1, Color(0.02, 0.0, 0.0, strength))
	g.add_point(0.55, Color(0, 0, 0, strength * 0.25))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.05, 1.05)
	tex.width = 256
	tex.height = 256
	var r := TextureRect.new()
	r.texture = tex
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r
