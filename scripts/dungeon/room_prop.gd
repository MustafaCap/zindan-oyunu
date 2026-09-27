## RoomProp — odalardaki etkileşimli nesneler (yer tutucu çizimler): sandık, tüccar, demirci, aşağı inen merdiven.
## F (etkileşim) ile kullanılır. Aşama 5: sandık açılınca loot saçar (DungeonRun; bazen tuzaklı, gizli oda sandığı
## tuzaksız ve üst nadirlik ×2), tüccar ve demirci envanter arayüzünü kendi panelleriyle açar. Tüccarın tezgâhı
## (stock) kat başına bir kez üretilir. Merdiven kat boss'u kesilince boss odasının ortasında belirir.
class_name RoomProp
extends Node2D

signal used(prop: RoomProp)


## Aşama 8: nesnenin Blender sprite'ı (ışıkla aydınlanır). Etiketler bu düğümde (ışıktan etkilenmez) çizilir.
const PROP_DIR := "res://assets/sprites/props/"
static var _meta: Dictionary = {}
var _ct: CanvasTexture
var _ct_key: String = ""
var _art: Node2D

func _init() -> void:
	material = Lighting.unshaded()   # Aşama 8: etkileşimli nesneler karanlıkta da okunur


func _ready() -> void:
	if _meta.is_empty() and FileAccess.file_exists(PROP_DIR + "props.json"):
		_meta = JSON.parse_string(FileAccess.get_file_as_string(PROP_DIR + "props.json"))
	if not _meta.has(_art_name()):
		return
	_art = Node2D.new()
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_art.show_behind_parent = true   # etiketler gövdenin önünde kalsın
	_art.draw.connect(_draw_art)
	add_child(_art)
	var light := ""
	match kind:
		"merchant": light = "#ffc870"
		"blacksmith": light = "#ff7a2a"
		"stairs": light = "#7a9aff"
	if light != "":
		var l := Lighting.make_light(Color(light), 3.5, 1.0)
		l.position = Vector2(0, -20)
		add_child(l)


func _art_name() -> String:
	if kind == "chest":
		return "chest_open" if opened else "chest_closed"
	return kind


func _draw_art() -> void:
	var m: Dictionary = _meta.get(_art_name(), {})
	if m.is_empty():
		return
	var key := _art_name()
	if _ct_key != key:
		_ct_key = key
		_ct = CanvasTexture.new()
		_ct.diffuse_texture = load(PROP_DIR + str(m["file"]))
		_ct.normal_texture = load(PROP_DIR + str(m["normal"]))
	var tex := _ct
	var s := 1.0 / float(m["scale"])
	var size := Vector2(m["size"][0], m["size"][1]) * s
	var anchor := Vector2(m["anchor"][0], m["anchor"][1]) * s
	_art.draw_colored_polygon(Shapes.iso_ellipse(0.5, 16), Color(0, 0, 0, 0.35))
	_art.draw_texture_rect(tex, Rect2(-anchor, size), false)

var kind: String = "chest"     ## chest, merchant, blacksmith, stairs
var room_id: int = -1
var opened: bool = false
var secret: bool = false        ## gizli odanın sandığı
var stock: Array = []           ## tüccarın tezgâhı (Weapon / Talisman)
var stock_ready: bool = false
var _t: float = 0.0


## Etkileşim ipucu (HUD'da "F: ..." olarak görünür). Boşsa etkileşim yok.
func prompt() -> String:
	match kind:
		"chest":
			return "" if opened else "F: Sandığı aç"
		"merchant":
			return "F: Tüccar (al / sat)"
		"blacksmith":
			return "F: Demirci (level atlat / yeniden çek)"
		"stairs":
			return "F: Aşağı in" if GameState.floor_index < 4 else "F: Zindandan çık"
	return ""


## Kullanınca ekranda gösterilecek kısa mesaj.
func use() -> String:
	var msg := ""
	match kind:
		"chest":
			if opened:
				return ""
			opened = true
		_:
			msg = ""
	queue_redraw()
	used.emit(self)
	return msg


func _process(delta: float) -> void:
	_t += delta
	if _art:
		_art.queue_redraw()
	if kind == "stairs":
		queue_redraw()


func _draw() -> void:
	if _art:
		# Sprite'lı nesne: yalnızca etiket ve merdivenin parlayan halkası
		match kind:
			"merchant": _draw_label(Color(0.9, 0.75, 0.25), "Tüccar")
			"blacksmith": _draw_label(Color(0.55, 0.62, 0.75), "Demirci")
			"stairs": _draw_stairs(true)
		return
	match kind:
		"chest":
			_draw_chest()
		"merchant":
			_draw_npc(Color(0.9, 0.75, 0.25), "Tüccar")
		"blacksmith":
			_draw_npc(Color(0.55, 0.62, 0.75), "Demirci")
		"stairs":
			_draw_stairs()


func _draw_chest() -> void:
	var shadow := Shapes.iso_ellipse(0.55, 16)
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.35))
	var body := Rect2(Vector2(-18, -22), Vector2(36, 20))
	draw_rect(body, Color(0.5, 0.32, 0.16))
	draw_rect(body, Color(0.25, 0.15, 0.08), false, 2.0)
	if opened:
		draw_rect(Rect2(Vector2(-18, -34), Vector2(36, 8)), Color(0.38, 0.24, 0.12))
		draw_rect(Rect2(Vector2(-14, -22), Vector2(28, 4)), Color(0.1, 0.08, 0.06))
	else:
		draw_rect(Rect2(Vector2(-18, -30), Vector2(36, 9)), Color(0.6, 0.4, 0.2))
		draw_rect(Rect2(Vector2(-3, -24), Vector2(6, 7)), Color(0.95, 0.8, 0.3))


func _draw_npc(color: Color, label: String) -> void:
	draw_colored_polygon(Shapes.iso_ellipse(0.4, 16), Color(0, 0, 0, 0.35))
	draw_rect(Rect2(Vector2(-10, -40), Vector2(20, 38)), color.darkened(0.3))
	draw_circle(Vector2(0, -48), 9.0, Color(0.93, 0.8, 0.66))
	draw_rect(Rect2(Vector2(-12, -58), Vector2(24, 6)), color)
	var font := ThemeDB.fallback_font
	draw_string_outline(font, Vector2(-60, -68), label, HORIZONTAL_ALIGNMENT_CENTER, 120, 16, 4, Color.BLACK)
	draw_string(font, Vector2(-60, -68), label, HORIZONTAL_ALIGNMENT_CENTER, 120, 16, color.lightened(0.3))


func _draw_stairs(art: bool = false) -> void:
	var pulse := 0.75 + 0.25 * sin(_t * 4.0)
	for i: int in (0 if art else 4):
		var r := 1.2 - i * 0.25
		var col := Color(0.25 - i * 0.05, 0.2 - i * 0.04, 0.3, 1.0)
		draw_colored_polygon(Shapes.iso_ellipse(r, 24), col)
	var ring := Shapes.iso_ellipse(1.3, 32)
	ring.append(ring[0])
	draw_polyline(ring, Color(0.6, 0.85, 1.0, pulse), 3.0)
	var font := ThemeDB.fallback_font
	var text := "Aşağı in" if GameState.floor_index < 4 else "Çıkış"
	draw_string_outline(font, Vector2(-60, -30), text, HORIZONTAL_ALIGNMENT_CENTER, 120, 18, 4, Color.BLACK)
	draw_string(font, Vector2(-60, -30), text, HORIZONTAL_ALIGNMENT_CENTER, 120, 18, Color(0.7, 0.9, 1.0, pulse))


func _draw_label(color: Color, label: String) -> void:
	var font := ThemeDB.fallback_font
	draw_string_outline(font, Vector2(-60, -84), label, HORIZONTAL_ALIGNMENT_CENTER, 120, 16, 4, Color.BLACK)
	draw_string(font, Vector2(-60, -84), label, HORIZONTAL_ALIGNMENT_CENTER, 120, 16, color.lightened(0.3))
