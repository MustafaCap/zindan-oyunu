## Android uygulama simgeleri: Warrior'ın önden bekleme karesi (parlayan gözler) ve arkasında kanlı kılıç, koyu kızıl
## zemin üstünde. assets/icon/ içine yazar: icon_192.png (klasik simge), icon_fg_432.png ve icon_bg_432.png (uyarlanabilir
## simgenin ön ve arka katmanı; ön katman ortadaki %66'lık güvenli alanda). Sprite'lar değişirse yeniden çalıştırılır:
## godot --headless --path . -s tools/android/make_icons.gd
extends SceneTree

const OUT := "res://assets/icon"
const SHEET := "res://assets/sprites/characters/warrior/idle.png"
const BLADE := "res://assets/sprites/icons/weapon_blade.png"
const CELL := Vector2i(88, 128)
const FRONT_ROW := 2   ## sayfada önden bakan yön


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var bg := _background(432)
	var fg := _foreground(432, 0.66)
	bg.save_png(ProjectSettings.globalize_path(OUT + "/icon_bg_432.png"))
	fg.save_png(ProjectSettings.globalize_path(OUT + "/icon_fg_432.png"))
	# Klasik simge: arka plan + ön katman (güvenli alan biraz daha geniş), 192'ye küçültülmüş
	var full := _background(432)
	full.blend_rect(_foreground(432, 0.8), Rect2i(Vector2i.ZERO, Vector2i(432, 432)), Vector2i.ZERO)
	full.resize(192, 192, Image.INTERPOLATE_LANCZOS)
	full.save_png(ProjectSettings.globalize_path(OUT + "/icon_192.png"))
	print("Simgeler yazıldı: ", OUT)
	quit(0)


func _load(path: String) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	img.convert(Image.FORMAT_RGBA8)
	return img


## Koyu kızıl, ortası aydınlık radyal zemin.
func _background(size: int) -> Image:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size * 0.5, size * 0.56)
	for y: int in size:
		for x: int in size:
			var k := clampf(Vector2(x, y).distance_to(c) / (size * 0.62), 0.0, 1.0)
			img.set_pixel(x, y, Color(0.36, 0.04, 0.03).lerp(Color(0.05, 0.03, 0.04), k * k))
	return img


## Ön katman: kılıç (çapraz) ve önünde karakter; safe: güvenli alanın kenar oranı.
func _foreground(size: int, safe: float) -> Image:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var box := size * safe
	var blade := _load(BLADE)
	var bs := int(box * 0.95)
	blade.resize(bs, bs, Image.INTERPOLATE_LANCZOS)
	img.blend_rect(blade, Rect2i(Vector2i.ZERO, blade.get_size()), Vector2i(size / 2 - bs / 2, size / 2 - bs / 2))
	var sheet := _load(SHEET)
	var frame := sheet.get_region(Rect2i(Vector2i(0, FRONT_ROW * CELL.y), CELL))
	var used := frame.get_used_rect()
	frame = frame.get_region(used)
	var k := box * 0.92 / float(used.size.y)
	frame.resize(roundi(used.size.x * k), roundi(used.size.y * k), Image.INTERPOLATE_NEAREST)
	var pos := Vector2i(size / 2 - frame.get_width() / 2, roundi(size * 0.5 + box * 0.5 - frame.get_height()))
	img.blend_rect(frame, Rect2i(Vector2i.ZERO, frame.get_size()), pos)
	return img
