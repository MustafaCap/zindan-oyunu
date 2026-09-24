## Minimap — sağ üst köşede katın oda haritası (yer tutucu arayüz). İzometrik dünyayla aynı yöne döndürülmüştür.
## Girilen odalar tipinin rengi ve harfiyle, girilen odaların komşuları sönük "?" olarak görünür; gizli oda bulunana
## kadar hiç görünmez. Bulunulan oda beyaz çerçevelidir; temizlenmemiş savaş odası kırmızı noktalıdır.
class_name Minimap
extends Control

const LETTERS := {"start": "G", "combat": "", "elite": "E", "merchant": "T", "blacksmith": "D", "chest": "S", "secret": "?", "boss": "B"}
const MAX_CELL := 64.0

var layout: DungeonLayout
var visited: Dictionary = {}          ## oda id -> true
var cleared: Dictionary = {}          ## oda id -> true
var current_room: int = -1
var secrets_open: bool = false
var reveal_all: bool = false          ## hata ayıklama: tüm haritayı göster
var _colors: Dictionary = {}
var _cell: float = MAX_CELL


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	for k: String in (DataDB.table("dungeon")["room_type_colors"] as Dictionary).keys():
		_colors[k] = Color(str(DataDB.table("dungeon")["room_type_colors"][k]))


func _process(_delta: float) -> void:
	queue_redraw()


func _known(id: int) -> int:
	## 2 = girildi, 1 = komşusu girildi (türü bilinmiyor), 0 = bilinmiyor
	if visited.has(id) or reveal_all:
		return 2
	if id == layout.secret_id and not secrets_open:
		return 0
	for nb: int in layout.neighbors(id, secrets_open):
		if visited.has(nb):
			return 1
	return 0


func _grid_to_px(g: Vector2i, origin: Vector2) -> Vector2:
	return origin + Vector2((g.x - g.y) * _cell * 0.5, (g.x + g.y) * _cell * 0.25)


func _draw() -> void:
	if layout == null:
		return
	# Katın tamamı kutuya sığacak ölçek
	_cell = 1.0
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for r: DungeonLayout.Room in layout.rooms:
		var p := _grid_to_px(r.grid, Vector2.ZERO)
		mn = mn.min(p)
		mx = mx.max(p)
	var ext := (mx - mn) + Vector2(1.0, 0.5)
	_cell = minf(MAX_CELL, minf((size.x - 24.0) / ext.x, (size.y - 24.0) / ext.y))
	mn *= _cell
	mx *= _cell
	var box := Rect2(Vector2.ZERO, size)
	draw_rect(box, Color(0.05, 0.05, 0.07, 0.86))
	draw_rect(box, Color(0.45, 0.42, 0.35, 0.8), false, 2.0)
	var origin := size * 0.5 - (mn + mx) * 0.5
	# Bağlantılar
	for e: Array in layout.edges:
		var a := int(e[0])
		var b := int(e[1])
		if bool(e[2]) and not secrets_open:
			continue
		if _known(a) == 0 or _known(b) == 0 or (_known(a) < 2 and _known(b) < 2):
			continue
		draw_line(_grid_to_px(layout.rooms[a].grid, origin), _grid_to_px(layout.rooms[b].grid, origin), Color(0.6, 0.58, 0.5, 0.8), maxf(_cell * 0.08, 2.0))
	# Odalar (izometrik elmas)
	var font := ThemeDB.fallback_font
	for r: DungeonLayout.Room in layout.rooms:
		var k := _known(r.id)
		if k == 0:
			continue
		var c := _grid_to_px(r.grid, origin)
		var hw := _cell * 0.46
		var hh := _cell * 0.23
		var pts := PackedVector2Array([c + Vector2(0, -hh), c + Vector2(hw, 0), c + Vector2(0, hh), c + Vector2(-hw, 0)])
		var col: Color = _colors.get(r.type, Color.GRAY) if k == 2 else Color(0.3, 0.3, 0.33)
		if k == 2 and not cleared.has(r.id) and r.has_enemies():
			col = col.darkened(0.25)
		draw_colored_polygon(pts, col)
		var edge := pts.duplicate()
		edge.append(pts[0])
		if r.id == current_room:
			draw_polyline(edge, Color.WHITE, 2.5)
		else:
			draw_polyline(edge, Color(0, 0, 0, 0.7), 1.0)
		var letter: String = LETTERS.get(r.type, "") if k == 2 else "?"
		if letter != "":
			draw_string(font, c + Vector2(-10, 5), letter, HORIZONTAL_ALIGNMENT_CENTER, 20, 14, Color(0.05, 0.05, 0.05) if k == 2 else Color(0.75, 0.75, 0.8))
		if k == 2 and r.has_enemies() and not cleared.has(r.id):
			draw_circle(c + Vector2(hw * 0.55, -hh * 0.6), 3.0, Color(1, 0.25, 0.2))
