## PlaceholderBody — Aşama 8'deki sprite'lar gelene kadar karakterleri çizen basit şekil.
## Gölge + gövde + kafa + bakış yönünü gösteren silah çizgisi. Vuruş flaşı için hit_flash shader'ı taşır.
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
var show_weapon: bool = true
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
	var tip := hand + dir_screen * weapon_length
	draw_line(hand, tip, outline_color, 5.0)
	draw_line(hand, tip, Color(0.85, 0.87, 0.92), 3.0)


func _draw_ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i: int in 20:
		var a := TAU * i / 20.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)
