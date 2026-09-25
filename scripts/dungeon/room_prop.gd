## RoomProp — odalardaki etkileşimli nesneler (yer tutucu çizimler): sandık, tüccar, demirci, aşağı inen merdiven.
## F (etkileşim) ile kullanılır. Aşama 5: sandık açılınca loot saçar (DungeonRun; bazen tuzaklı, gizli oda sandığı
## tuzaksız ve üst nadirlik ×2), tüccar ve demirci envanter arayüzünü kendi panelleriyle açar. Tüccarın tezgâhı
## (stock) kat başına bir kez üretilir. Merdiven kat boss'u kesilince boss odasının ortasında belirir.
class_name RoomProp
extends Node2D

signal used(prop: RoomProp)

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
	if kind == "stairs":
		queue_redraw()


func _draw() -> void:
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


func _draw_stairs() -> void:
	var pulse := 0.75 + 0.25 * sin(_t * 4.0)
	for i: int in 4:
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
