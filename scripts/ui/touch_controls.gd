## TouchControls — dokunmatik kontroller (Android). Mobile.enabled ise DungeonRun kurar; Player girdiyi read_intent'ten alır.
## Sol taraf: yüzen joystick (dokunulan yerde belirir, parmak uzaklaşınca peşinden gelir) → yürüme.
## Sağ alt: Saldırı (basılı tut), güçlü saldırı (basınca başlar; Yay'da basılı tutup bırakınca atar), Q ve E (bırakınca),
## atılma (joystick yönüne), silah değiştir, iksir. Saldırı ve yetenek düğmesinden sürükleyince nişan o yöne gider
## (sürükleme uzunluğu = uzaklık); sürüklenmezse menzildeki en yakın düşmana otomatik nişan (görüş hattındakiler önce),
## düşman yoksa yürünen yöne. Üst: Menü (Esc) ve Çanta (I). Yakında etkileşimli bir şey varsa "Al / Aç / İn" düğmesi (F).
## HUD'daki silah paneline dokunmak da silahı değiştirir. Çoklu dokunma: her parmak dokunduğu yere göre joystick'e ya da
## bir düğmeye bağlanır. Oyun durunca (envanter, ödül, duraklatma) gizlenir ve basılı parmaklar bırakılmış sayılır.
## Sayılar data/touch.json'da; düğme yerleşimi aşağıda (mantıksal piksel, ekran köşesine göre).
class_name TouchControls
extends CanvasLayer

signal inventory_pressed
signal pause_pressed
signal interact_pressed

## id: [köşe ("br" sağ alt, "tr" sağ üst), köşeye göre merkez, yarıçap]
const LAYOUT := {
	"light": ["br", Vector2(-190, -180), 92.0],
	"heavy": ["br", Vector2(-400, -110), 64.0],
	"q": ["br", Vector2(-370, -290), 60.0],
	"e": ["br", Vector2(-230, -380), 60.0],
	"dash": ["br", Vector2(-80, -350), 56.0],
	"swap": ["br", Vector2(-530, -90), 48.0],
	"potion": ["br", Vector2(-520, -240), 48.0],
	"interact": ["br", Vector2(-330, -510), 56.0],
	"bag": ["tr", Vector2(-350, 62), 40.0],
	"pause": ["tr", Vector2(-450, 62), 40.0],
}
## Basılı tutulan (sürükleyince nişan alınan) düğmeler; diğerleri basınca ya da bırakınca bir kez tetiklenir.
const HOLD := ["light", "heavy"]
## Bırakınca tetiklenenler (sürükleyerek nişan alınır; dokunup bırakmak otomatik nişan).
const ON_RELEASE := ["q", "e"]
## Joystick bölgesinin üstünde kalan şerit (can barı, bilgi satırları).
const TOP_BAND := 150.0

var run: Node                       ## DungeonRun (hud, player, finished)
var joy_radius: float
var joy_deadzone: float
var joy_zone: float
var _aim: Dictionary

var _fingers: Dictionary = {}       ## dokunma indeksi -> {"kind": "stick"|"button"|"weapons", "id", "start", "pos"}
var _stick_center: Vector2 = Vector2.INF
var _stick_vec: Vector2 = Vector2.ZERO   ## ekran yönü, uzunluk 0-1
var _held: Dictionary = {}          ## "light"/"heavy" -> true
var _shots: Dictionary = {}         ## bu karede tetiklenecekler: heavy, q, e, dash, swap, potion
var _shot_drag: Vector2 = Vector2.ZERO   ## bırakılan yeteneğin sürükleme vektörü (nişan)
var _overlay: Control
## Çizim için son nişan: elle mi, nokta (dünya) ve otomatik hedef.
var aim_manual: bool = false
var aim_world: Vector2 = Vector2.ZERO
var auto_target: Node2D


func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_PAUSABLE
	var joy: Dictionary = DataDB.get_value("touch", "joystick")
	joy_radius = float(joy["radius"])
	joy_deadzone = float(joy["deadzone"])
	joy_zone = float(joy["zone_width"])
	_aim = DataDB.get_value("touch", "aim")
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		release_all()
		visible = false
	elif what == NOTIFICATION_UNPAUSED:
		visible = true


func _process(_delta: float) -> void:
	_overlay.queue_redraw()


## Bütün parmakları bırakır (oyun durunca, sahne değişince).
func release_all() -> void:
	_fingers.clear()
	_held.clear()
	_shots.clear()
	_stick_vec = Vector2.ZERO
	_stick_center = Vector2.INF


func _player() -> Player:
	var p: Variant = run.get("player") if run else null
	return p as Player if p is Player and is_instance_valid(p) else null


func _active() -> bool:
	var p := _player()
	return visible and p != null and not p.dead and not bool(run.get("finished"))


# --- yerleşim ---

func _vp() -> Vector2:
	return _overlay.size


func button_center(id: String) -> Vector2:
	var spec: Array = LAYOUT[id]
	var vp := _vp()
	var corner := Vector2(vp.x, vp.y) if spec[0] == "br" else Vector2(vp.x, 0)
	return corner + (spec[1] as Vector2)


func button_radius(id: String) -> float:
	return float(LAYOUT[id][2])


## Düğme şu an görünür ve basılabilir mi.
func button_visible(id: String) -> bool:
	var p := _player()
	if p == null:
		return false
	match id:
		"swap":
			return p.weapons.size() > 1
		"potion":
			return bool(DataDB.table("races")[p.race_id]["healing"]["potions"])
		"interact":
			return _prompt() != ""
	return true


func _prompt() -> String:
	var hud: Variant = run.get("hud") if run else null
	return str(hud.get("prompt_text")) if hud else ""


func joystick_rest() -> Vector2:
	return Vector2(joy_radius + 90.0, _vp().y - joy_radius - 90.0)


func _button_at(pos: Vector2) -> String:
	var best := ""
	var best_d := INF
	for id: String in LAYOUT.keys():
		if not button_visible(id):
			continue
		var d := pos.distance_to(button_center(id))
		if d <= button_radius(id) * 1.2 and d < best_d:
			best_d = d
			best = id
	return best


func _weapons_rect() -> Rect2:
	var hud: Variant = run.get("hud") if run else null
	return hud.call("weapon_panel_rect") if hud and hud.has_method("weapon_panel_rect") else Rect2()


# --- dokunma ---

func _input(event: InputEvent) -> void:
	if not _active():
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_touch_down(t.index, t.position)
		else:
			_touch_up(t.index, t.position, t.canceled)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		_touch_move(d.index, d.position)


func _touch_down(index: int, pos: Vector2) -> void:
	var id := _button_at(pos)
	if id != "":
		_fingers[index] = {"kind": "button", "id": id, "start": pos, "pos": pos}
		_button_pressed(id)
	elif _weapons_rect().has_point(pos):
		_fingers[index] = {"kind": "weapons", "id": "", "start": pos, "pos": pos}
		_shots["swap"] = true
	elif pos.x < _vp().x * joy_zone and pos.y > TOP_BAND and not _has_stick():
		var c := pos
		c.x = maxf(c.x, joy_radius + 16.0)
		c.y = minf(c.y, _vp().y - joy_radius - 16.0)
		_stick_center = c
		_fingers[index] = {"kind": "stick", "id": "", "start": c, "pos": pos}
		_update_stick(pos)


func _touch_move(index: int, pos: Vector2) -> void:
	if not _fingers.has(index):
		return
	var f: Dictionary = _fingers[index]
	f["pos"] = pos
	if f["kind"] == "stick":
		_update_stick(pos)


func _touch_up(index: int, pos: Vector2, canceled: bool) -> void:
	if not _fingers.has(index):
		return
	var f: Dictionary = _fingers[index]
	_fingers.erase(index)
	match str(f["kind"]):
		"stick":
			_stick_vec = Vector2.ZERO
			_stick_center = Vector2.INF
		"button":
			var id := str(f["id"])
			_held.erase(id)
			if id in ON_RELEASE and not canceled:
				_shots[id] = true
				_shot_drag = pos - (f["start"] as Vector2)


func _has_stick() -> bool:
	for f: Dictionary in _fingers.values():
		if f["kind"] == "stick":
			return true
	return false


func _update_stick(pos: Vector2) -> void:
	var v := pos - _stick_center
	if v.length() > joy_radius:
		_stick_center = pos - v.normalized() * joy_radius
		v = v.normalized() * joy_radius
	var k := v.length() / joy_radius
	_stick_vec = Vector2.ZERO if k < joy_deadzone else v.normalized() * inverse_lerp(joy_deadzone, 1.0, k)


func _button_pressed(id: String) -> void:
	match id:
		"light":
			_held["light"] = true
		"heavy":
			_held["heavy"] = true
			_shots["heavy"] = true
		"dash", "swap", "potion":
			_shots[id] = true
		"interact":
			interact_pressed.emit()
		"bag":
			inventory_pressed.emit()
		"pause":
			pause_pressed.emit()


# --- girdi (Player) ---

## Player'ın girdisi: {move, aim, light, heavy, heavy_held, q, e, dash, swap, potion} (Player._read_input ile aynı).
## Tek seferlik basışlar okununca silinir.
func read_intent(p: Player) -> Dictionary:
	var move := Vector2.ZERO
	if _stick_vec != Vector2.ZERO:
		move = Iso.to_cart(_stick_vec).normalized() * _stick_vec.length()
	else:
		move = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var d := {
		"move": move,
		"aim": aim_point(p, move),
		"light": bool(_held.get("light", false)),
		"heavy": bool(_shots.get("heavy", false)),
		"heavy_held": bool(_held.get("heavy", false)),
		"q": bool(_shots.get("q", false)),
		"e": bool(_shots.get("e", false)),
		"dash": bool(_shots.get("dash", false)),
		"swap": bool(_shots.get("swap", false)),
		"potion": bool(_shots.get("potion", false)),
	}
	_shots.clear()
	_shot_drag = Vector2.ZERO
	return d


## Nişan noktası (dünya): bırakılan yeteneğin sürüklemesi > basılı düğmenin sürüklemesi > en yakın düşman > yürünen yön.
func aim_point(p: Player, move_cart: Vector2) -> Vector2:
	var drag := _shot_drag
	if drag.length() < float(_aim["drag_deadzone"]):
		drag = _held_drag()
	aim_manual = drag.length() >= float(_aim["drag_deadzone"])
	auto_target = null
	if aim_manual:
		var k := clampf(inverse_lerp(float(_aim["drag_deadzone"]), float(_aim["drag_full"]), drag.length()), 0.0, 1.0)
		var tiles := lerpf(float(_aim["min_tiles"]), float(_aim["max_tiles"]), k)
		aim_world = p.global_position + Iso.to_screen(Iso.to_cart(drag).normalized() * Iso.tiles(tiles))
		return aim_world
	auto_target = nearest_enemy(p)
	if auto_target:
		aim_world = auto_target.global_position
	elif move_cart.length() > 0.1:
		aim_world = p.global_position + Iso.to_screen(move_cart.normalized() * Iso.tiles(float(_aim["idle_tiles"])))
	else:
		aim_world = p.global_position + Iso.to_screen(p.facing_cart * Iso.tiles(float(_aim["idle_tiles"])))
	return aim_world


## Basılı saldırı/yetenek düğmelerinden en çok sürüklenenin vektörü (ilk dokunulan yerden); yoksa sıfır.
func _held_drag() -> Vector2:
	var best := Vector2.ZERO
	for f: Dictionary in _fingers.values():
		if f["kind"] == "button" and str(f["id"]) in HOLD + ON_RELEASE:
			var v: Vector2 = (f["pos"] as Vector2) - (f["start"] as Vector2)
			if v.length() > best.length():
				best = v
	return best


## Otomatik nişan: auto_range karo içindeki en yakın düşman; görüş hattında olan varsa o.
func nearest_enemy(p: Player) -> Node2D:
	var best: Node2D = null
	var best_d := INF
	var los := p.bot_los
	for e: Node2D in p.enemies():
		var d := Iso.tile_distance(p.global_position, e.global_position)
		if d > float(_aim["auto_range"]):
			continue
		if los.is_valid() and not bool(los.call(p.global_position, e.global_position)):
			d += 1000.0
		if d < best_d:
			best_d = d
			best = e
	return best


# --- çizim ---

func _draw_overlay() -> void:
	var p := _player()
	if p == null or not _active():
		return
	var font := ThemeDB.fallback_font
	# Nişan: elle nişanda oyuncudan hedefe çizgi, otomatik nişanda hedefin çevresinde halka (saldırırken)
	var ct := _overlay.get_viewport().get_canvas_transform()
	var attacking := not _held.is_empty() or _fingers.values().any(func(f: Dictionary) -> bool: return str(f["id"]) in ON_RELEASE)
	if attacking and aim_manual:
		var a := ct * p.global_position
		var b := ct * aim_world
		_overlay.draw_line(a, b, Color(1.0, 0.85, 0.5, 0.55), 4.0)
		_overlay.draw_arc(b, 16.0, 0.0, TAU, 24, Color(1.0, 0.85, 0.5, 0.8), 3.0)
	elif attacking and auto_target and is_instance_valid(auto_target):
		_overlay.draw_arc(ct * auto_target.global_position, 34.0, 0.0, TAU, 32, Color(1.0, 0.3, 0.25, 0.75), 4.0)
	# Joystick
	var c := _stick_center if _stick_center != Vector2.INF else joystick_rest()
	var on := _stick_center != Vector2.INF
	_overlay.draw_circle(c, joy_radius, Color(0, 0, 0, 0.28 if on else 0.16))
	_overlay.draw_arc(c, joy_radius, 0.0, TAU, 48, Color(0.9, 0.8, 0.6, 0.5 if on else 0.25), 3.0)
	_overlay.draw_circle(c + _stick_vec * joy_radius, joy_radius * 0.42, Color(0.9, 0.8, 0.6, 0.55 if on else 0.25))
	# Düğmeler
	var kit := p.kit
	var fam := p.weapon().family()
	var race: Dictionary = DataDB.table("races")[p.race_id]
	for id: String in LAYOUT.keys():
		if not button_visible(id):
			continue
		var pos := button_center(id)
		var r := button_radius(id)
		var pressed := _fingers.values().any(func(f: Dictionary) -> bool: return str(f["id"]) == id)
		var label := ""
		var cd := 0.0
		var cd_max := 0.0
		var ok := true
		match id:
			"light":
				label = "Saldırı"
			"heavy", "q", "e":
				label = str(p.weapon().type_data()["heavy"]["name"]) if id == "heavy" else str(race["abilities"][id]["name"])
				cd = float(kit.cooldowns[id])
				cd_max = float(kit.cooldown_totals[id])
				ok = kit.resource + 0.001 >= kit.cost(id, fam)
			"dash":
				label = "Atıl"
				cd = p.dash_cd
				cd_max = p.dash_cd_max
			"swap":
				label = "Silah\ndeğiştir"
			"potion":
				label = "İksir\n%d" % p.potions
				ok = p.potions > 0
			"interact":
				label = interact_label(_prompt())
			"bag":
				label = "Çanta"
			"pause":
				label = "Menü"
		var fill := Color(0.08, 0.06, 0.07, 0.55)
		if pressed:
			fill = Color(0.45, 0.12, 0.1, 0.7)
		elif not ok:
			fill = Color(0.1, 0.15, 0.35, 0.55)
		_overlay.draw_circle(pos, r, fill)
		if cd > 0.0 and cd_max > 0.0:
			_pie(pos, r, clampf(cd / cd_max, 0.0, 1.0), Color(0, 0, 0, 0.6))
		var ready := cd <= 0.0 and ok
		var ring := Color(0.95, 0.8, 0.5, 0.9) if ready else Color(0.5, 0.5, 0.55, 0.7)
		if id == "interact":
			ring = Color(1.0, 0.95, 0.7, 0.95)
		_overlay.draw_arc(pos, r, 0.0, TAU, 40, ring, 3.0)
		var fs := 22 if id == "light" else (15 if r < 50.0 else 17)
		if font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > r * 2.0 - 14.0:
			label = label.replace(" ", "\n")
		var lines := label.split("\n")
		var y0 := pos.y - (lines.size() - 1) * fs * 0.55 + fs * 0.35
		for i: int in lines.size():
			var lp := Vector2(pos.x - r, y0 + i * fs * 1.1)
			_overlay.draw_string_outline(font, lp, lines[i], HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, 4, Color.BLACK)
			_overlay.draw_string(font, lp, lines[i], HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, Color(1, 0.95, 0.85))
		if cd > 0.0:
			var tp := Vector2(pos.x - r, pos.y + r * 0.62)
			_overlay.draw_string_outline(font, tp, "%.1f" % cd, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 16, 4, Color.BLACK)
			_overlay.draw_string(font, tp, "%.1f" % cd, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 16, Color.WHITE)


## Etkileşim düğmesinin kısa yazısı: "F: Al — Kılıç" → "Al", "F: Tüccar (al / sat)" → "Tüccar".
static func interact_label(prompt: String) -> String:
	return prompt.trim_prefix("F: ").get_slice(" — ", 0).get_slice(" (", 0)


## Bekleme süresi dilimi: k (0-1) oranında, saat yönünde tepeden başlayan pasta.
func _pie(c: Vector2, r: float, k: float, col: Color) -> void:
	if k <= 0.0:
		return
	var pts := PackedVector2Array([c])
	var n := maxi(int(40.0 * k), 2)
	for i: int in n + 1:
		var a := -PI * 0.5 + TAU * k * float(i) / float(n)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	_overlay.draw_colored_polygon(pts, col)
