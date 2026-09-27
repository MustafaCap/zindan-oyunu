## Android uygulama simgeleri (v0.11.1): assets/icon/source/emblem.jpg'deki amblemden (kanlı zemin üstünde balta, kılıç,
## mızrak ve yaylar). assets/icon/ içine yazar: icon_192.png (klasik simge: görselin tamamı), icon_fg_432.png ve icon_bg_432.png
## (uyarlanabilir simgenin ön ve arka katmanı). Ön katmanda görsel küçültülüp ortaya konur ve kenarı yumuşakça saydamlaşır:
## telefon simgeyi daire ya da yuvarlak kare keser, amblem görünür alanın içinde kalır. Arka katman, görselin kenar
## renklerinden koyu kızıl radyal bir zemin (kesimde ön katmanın kenarı belli olmasın). Kaynak görsel .gdignore'lu klasörde
## durur, oyuna gömülmez. Görsel değişirse yeniden çalıştırılır: make android-icons
## (godot --headless --path . -s tools/android/make_icons.gd)
extends SceneTree

const OUT := "res://assets/icon"
const SOURCE := "res://assets/icon/source/emblem.jpg"
const SIZE := 432           ## uyarlanabilir katmanların boyu (Android: 108 dp; görünür alan ortadaki 72 dp ≈ 288 px)
const FG_SIZE := 320        ## ön katmanda görselin kenarı: amblemin uçları (kenarın ~%43'ü) 288'lik dairenin içinde kalır
const FADE_FROM := 0.45     ## görselin merkezinden bu uzaklıktan (kenar oranı) sonra saydamlaşır, 0,5'te tamamen


func _initialize() -> void:
	var src := Image.load_from_file(ProjectSettings.globalize_path(SOURCE))
	if src == null or src.is_empty():
		push_error("Simge görseli okunamadı: " + SOURCE)
		quit(1)
		return
	src.convert(Image.FORMAT_RGBA8)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var inner := _average(src, FADE_FROM, 0.5)
	var outer := _average(src, 0.62, 1.0)
	_background(inner, outer).save_png(ProjectSettings.globalize_path(OUT + "/icon_bg_432.png"))
	_foreground(src).save_png(ProjectSettings.globalize_path(OUT + "/icon_fg_432.png"))
	# Klasik simge (Android 7): görselin tamamı
	var legacy := src.duplicate() as Image
	legacy.resize(192, 192, Image.INTERPOLATE_LANCZOS)
	legacy.save_png(ProjectSettings.globalize_path(OUT + "/icon_192.png"))
	print("Simgeler yazıldı: ", OUT)
	quit(0)


## Görselin merkezinden [from, to) uzaklıktaki (kenar oranı) piksellerin ortalama rengi.
func _average(img: Image, from: float, to: float) -> Color:
	var n := img.get_width()
	var sum := Vector3.ZERO
	var count := 0
	for y: int in range(0, n, 4):
		for x: int in range(0, n, 4):
			var d := Vector2(x, y).distance_to(Vector2(n, n) * 0.5) / n
			if d >= from and d < to:
				var c := img.get_pixel(x, y)
				sum += Vector3(c.r, c.g, c.b)
				count += 1
	sum /= maxf(count, 1)
	return Color(sum.x, sum.y, sum.z)


## Arka katman: ön katmanın saydamlaştığı halkada görselin kenar rengi, köşelere doğru koyulaşır.
func _background(inner: Color, outer: Color) -> Image:
	var img := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var c := Vector2(SIZE, SIZE) * 0.5
	var r0 := FG_SIZE * FADE_FROM
	var r1 := SIZE * 0.71
	for y: int in SIZE:
		for x: int in SIZE:
			var k := smoothstep(r0, r1, Vector2(x, y).distance_to(c))
			img.set_pixel(x, y, inner.lerp(outer, k))
	return img


## Ön katman: görsel FG_SIZE'a küçültülüp ortada; kenarı dairesel olarak saydamlaşır.
func _foreground(src: Image) -> Image:
	var s := src.duplicate() as Image
	s.resize(FG_SIZE, FG_SIZE, Image.INTERPOLATE_LANCZOS)
	var c := Vector2(FG_SIZE, FG_SIZE) * 0.5
	for y: int in FG_SIZE:
		for x: int in FG_SIZE:
			var col := s.get_pixel(x, y)
			col.a = 1.0 - smoothstep(FADE_FROM, 0.5, Vector2(x, y).distance_to(c) / FG_SIZE)
			s.set_pixel(x, y, col)
	var img := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var off := (SIZE - FG_SIZE) / 2
	img.blit_rect(s, Rect2i(Vector2i.ZERO, s.get_size()), Vector2i(off, off))
	return img
