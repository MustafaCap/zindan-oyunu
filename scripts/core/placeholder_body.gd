## PlaceholderBody — Aşama 8'deki sprite'lar gelene kadar karakterleri çizen basit şekil.
## Gölge + gövde + kafa + bakış yönünü gösteren silah. Vuruş flaşı için hit_flash shader'ı taşır.
## weapon_style silahın placeholder şeklini seçer (weapon_types.json > visual): blade, axe, fist, scythe, dagger,
## mace, bow, crossbow, spear, tome, staff, rune. Boşsa düz çizgi (düşmanların silahı).
class_name PlaceholderBody
extends Node2D

const FLASH_SHADER := preload("res://assets/shaders/hit_flash.gdshader")

var body_color: Color = Color(0.3, 0.6, 0.9)
var head_color: Color = Color(0.85, 0.8, 0.7)
var outline_color: Color = Color(0.05, 0.05, 0.08)
var body_height: float = 34.0
var body_width: float = 18.0
var facing_cart: Vector2 = Vector2.RIGHT
var weapon_length: float = 26.0
var weapon_color: Color = Color(0.85, 0.87, 0.92):
	set(v):
		weapon_color = v
		queue_redraw()
var weapon_style: String = "":
	set(v):
		weapon_style = v
		queue_redraw()
var show_weapon: bool = true:
	set(v):
		show_weapon = v
		queue_redraw()
var lean: float = 0.0            # saldırıda öne eğilme (0..1)

var _flash_tween: Tween


func _ready() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = FLASH_SHADER
	material = mat


## Kısa bir renk flaşı (varsayılan beyaz).
func flash(duration: float, color: Color = Color.WHITE) -> void:
	var mat := material as ShaderMaterial
	mat.set_shader_parameter("flash_color", color)
	mat.set_shader_parameter("flash", 1.0)
	if _flash_tween:
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_method(func(v: float) -> void: mat.set_shader_parameter("flash", v), 1.0, 0.0, duration)


func set_facing(f: Vector2) -> void:
	if f.length() > 0.01:
		facing_cart = f.normalized()
		queue_redraw()


func _draw() -> void:
	# Gölge
	_draw_ellipse(Vector2.ZERO, body_width * 0.9, body_width * 0.45, Color(0, 0, 0, 0.35))
	var dir_screen := Iso.to_screen(facing_cart).normalized()
	var lean_off := dir_screen * lean * 6.0
	var w := body_width * 0.5
	var top := -body_height + lean_off.y
	# Silah arkadaysa (yukarı bakıyorsa) gövdeden önce çiz
	var weapon_behind := facing_cart.y < 0.0
	if show_weapon and weapon_behind:
		_draw_weapon(dir_screen, lean_off)
	# Gövde
	var body := PackedVector2Array([
		Vector2(-w, -4), Vector2(-w * 0.85 + lean_off.x, top + 8),
		Vector2(w * 0.85 + lean_off.x, top + 8), Vector2(w, -4), Vector2(0, 2)])
	draw_colored_polygon(body, body_color)
	draw_polyline(body + PackedVector2Array([body[0]]), outline_color, 2.0)
	# Bakış yönünü gösteren küçük göğüs işareti
	draw_circle(Vector2(lean_off.x, top + 18) + dir_screen * 4.0, 2.5, body_color.lightened(0.45))
	# Kafa
	var head_c := Vector2(lean_off.x, top + 2)
	draw_circle(head_c, 8.0, head_color)
	draw_arc(head_c, 8.0, 0, TAU, 20, outline_color, 2.0)
	draw_circle(head_c + dir_screen * 4.0 + Vector2(0, -1), 1.8, outline_color)
	if show_weapon and not weapon_behind:
		_draw_weapon(dir_screen, lean_off)


func _draw_weapon(dir_screen: Vector2, lean_off: Vector2) -> void:
	var hand := Vector2(lean_off.x, -body_height * 0.45) + dir_screen * 8.0
	var d := dir_screen
	var n := d.orthogonal()
	var wood := Color(0.55, 0.4, 0.26)
	var steel := weapon_color.lerp(Color(0.85, 0.87, 0.92), 0.35)
	var o := outline_color
	match weapon_style:
		"blade":
			_stick(hand, hand + d * 30.0, steel, 4.0)
			_stick(hand - n * 6.0, hand + n * 6.0, wood, 3.0)
		"dagger":
			_stick(hand, hand + d * 17.0, steel, 3.5)
			_stick(hand - n * 4.0, hand + n * 4.0, wood, 2.5)
		"axe":
			var tip := hand + d * 26.0
			_stick(hand - d * 4.0, tip, wood, 3.5)
			var head := PackedVector2Array([tip - d * 3.0, tip + n * 9.0 - d * 8.0, tip + n * 11.0 + d * 2.0, tip + d * 4.0])
			draw_colored_polygon(head, steel)
			draw_polyline(head + PackedVector2Array([head[0]]), o, 1.5)
		"fist":
			for side: float in [-1.0, 1.0]:
				var c := Vector2(lean_off.x, -body_height * 0.45) + d * 10.0 + n * side * 8.0
				draw_circle(c, 5.5, o)
				draw_circle(c, 4.2, steel)
		"scythe":
			var top := hand + d * 32.0 - n * 4.0
			_stick(hand - d * 8.0, top, wood, 3.5)
			var blade := PackedVector2Array([top, top + n * 16.0 + d * 2.0, top + n * 18.0 - d * 6.0, top + n * 6.0 - d * 1.0])
			draw_colored_polygon(blade, steel)
			draw_polyline(blade + PackedVector2Array([blade[0]]), o, 1.5)
		"mace":
			var tip2 := hand + d * 24.0
			_stick(hand - d * 3.0, tip2, wood, 3.5)
			draw_circle(tip2, 7.5, o)
			draw_circle(tip2, 6.0, steel)
			for i: int in 4:
				var sp := Vector2.RIGHT.rotated(TAU * i / 4.0 + 0.4) * 9.0
				draw_line(tip2, tip2 + sp, o, 2.0)
		"bow":
			var pts := PackedVector2Array()
			for i: int in 9:
				var a := -1.1 + 2.2 * i / 8.0
				pts.append(hand + d * (6.0 + cos(a) * 10.0) + n * sin(a) * 18.0)
			draw_polyline(pts, o, 4.5)
			draw_polyline(pts, wood, 2.5)
			draw_line(pts[0], pts[8], Color(0.9, 0.9, 0.85), 1.0)
			draw_circle(hand + d * 16.0, 2.5, weapon_color)
		"crossbow":
			_stick(hand - d * 4.0, hand + d * 20.0, wood, 4.0)
			_stick(hand + d * 14.0 - n * 12.0, hand + d * 14.0 + n * 12.0, steel, 3.0)
		"spear":
			var tip3 := hand + d * 38.0
			_stick(hand - d * 12.0, tip3, wood, 3.0)
			draw_colored_polygon(PackedVector2Array([tip3 + d * 9.0, tip3 + n * 4.0, tip3 - n * 4.0]), steel)
		"tome":
			var c2 := hand + d * 6.0
			var bk := PackedVector2Array([c2 - n * 8.0 - d * 5.0, c2 + n * 8.0 - d * 5.0, c2 + n * 8.0 + d * 5.0, c2 - n * 8.0 + d * 5.0])
			draw_colored_polygon(bk, Color(0.45, 0.2, 0.2))
			draw_polyline(bk + PackedVector2Array([bk[0]]), o, 1.5)
			draw_line(c2 - d * 5.0, c2 + d * 5.0, Color(0.95, 0.9, 0.8), 1.5)
			draw_circle(c2 + Vector2(0, -12), 3.0, Color(weapon_color, 0.8))
		"staff":
			var top2 := hand + d * 10.0 + Vector2(0, -22)
			_stick(hand + d * 10.0 + Vector2(0, 12), top2, wood, 3.5)
			draw_circle(top2, 6.5, Color(weapon_color, 0.35))
			draw_circle(top2, 4.5, weapon_color.lightened(0.2))
		"rune":
			var c3 := hand + d * 8.0 + Vector2(0, -6)
			var st := PackedVector2Array([c3 + Vector2(0, -9), c3 + Vector2(7, 0), c3 + Vector2(0, 9), c3 + Vector2(-7, 0)])
			draw_colored_polygon(st, Color(0.35, 0.35, 0.42))
			draw_polyline(st + PackedVector2Array([st[0]]), weapon_color.lightened(0.3), 2.0)
			draw_line(c3 + Vector2(-2, -4), c3 + Vector2(2, 4), weapon_color.lightened(0.5), 1.5)
		_:
			var tip4 := hand + d * weapon_length
			draw_line(hand, tip4, o, 5.0)
			draw_line(hand, tip4, weapon_color, 3.0)


func _stick(a: Vector2, b: Vector2, col: Color, w: float) -> void:
	draw_line(a, b, outline_color, w + 2.0)
	draw_line(a, b, col, w)


func _draw_ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i: int in 20:
		var a := TAU * i / 20.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)
