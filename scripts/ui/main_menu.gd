## MainMenu — Aşama 10 ana menüsü (oyunun açılış sahnesi). Oyunun adı yazılmaz (kullanıcı kararı: henüz ad yok).
## Arka plan kullanıcının videosu (Ogg Theora, make menu-video üretir): oyun açılışında kanlı giriş videosu bir kez oynar
## (menu_intro.ogv), sonunda çapraz geçişle kansız sakin döngüye (menu_loop.ogv, ileri-geri, sıçramasız) geçer; menüye sonraki
## dönüşlerde yalnızca döngü oynar. Müzik videonun sesidir (audio.json > music.tracks.menu → menu.ogg).
## Videoda menü yazıları gömülüdür (YENİ OYUN / YÜKLE / AYARLAR / ÇIKIŞ): düğmeler bu yazıların üstüne oturan görünmez tıklama
## alanlarıdır; üzerine gelince yazı kızıl parlar ve solunda kan izi belirir. YÜKLE soluk ve tıklanmaz (kayıtlı run yok;
## kullanıcı kararı). Klavyeyle yukarı/aşağı ve Enter. Video yoksa koyu, korlu yedek arka plan ve kendi düğmeleri
## (Başla, Ses ayarları, Çık).
## Komut satırında oyun bayrağı verilmişse (--autoplay, --seed=…, --race=… gibi test ve geliştirme bayrakları) menü atlanır ve
## zindan doğrudan açılır: make dungeon / make bosses / denge simülasyonu eskisi gibi çalışır. "--menu" menüde kalır.
class_name MainMenu
extends Control

const GAME_SCENE := "res://scenes/game.tscn"
const RACE_SCENE := "res://scenes/race_select.tscn"
const INTRO_PATH := "res://assets/video/menu_intro.ogv"
const LOOP_PATH := "res://assets/video/menu_loop.ogv"
const VIDEO_SIZE := Vector2(1280, 720)
const INTRO_XFADE := 1.4            ## giriş videosunun son saniyelerinde döngüye çapraz geçiş (sn)
## Videodaki gömülü yazılar (1280×720 video pikseli): [yazı, tıklama alanı, eylem]; eylemi boş olan soluk ve tıklanmaz.
const VIDEO_ITEMS := [
	["YENİ OYUN", Rect2(70, 243, 210, 48), "start"],
	["YÜKLE", Rect2(70, 305, 132, 48), ""],
	["AYARLAR", Rect2(70, 366, 180, 48), "settings"],
	["ÇIKIŞ", Rect2(70, 427, 114, 48), "quit"],
]

static var intro_seen := false      ## giriş videosu oyun başına bir kez

var video: VideoStreamPlayer        ## sakin döngü (her zaman altta)
var intro: VideoStreamPlayer        ## kanlı giriş (üstte; bitince silinir)
var buttons: Array[Button] = []
var button_labels: Array[String] = []
var _overlay: Control               ## video yazılarının üstündeki tıklama alanları (videoyla birlikte ölçeklenir)
var _fade: ColorRect
var _leaving := false
var _intro_fading := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty() and not "--menu" in args:
		get_tree().change_scene_to_file.call_deferred(GAME_SCENE)
		return
	get_tree().paused = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.theme()
	_build_backdrop()
	if video != null:
		_build_video_menu()
	else:
		_build_menu()
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	create_tween().tween_property(_fade, "color:a", 0.0, 0.9)
	Audio.play_music("menu", 1.5)   # videonun sesi (menu.ogg; audio.json); ırk seçiminde de sürer
	buttons[0].grab_focus.call_deferred()
	for a: String in args:
		if a.begins_with("--shots="):
			var shots := TestRoom.ShotTaker.new()
			shots.dir = a.get_slice("=", 1)
			shots.times = [1.5]
			add_child(shots)


## Arka plan: video (varsa: giriş + döngü) ya da yedek; yedekte üstüne soldan karartma (düğmeler okunsun) ve vinyet.
func _build_backdrop() -> void:
	var base := ColorRect.new()
	base.color = UiTheme.INK
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base)
	if not ResourceLoader.exists(LOOP_PATH):
		add_ember_backdrop(self)
		_add_shade()
		return
	video = _video_player(LOOP_PATH)
	video.loop = true
	add_child(video)
	if not intro_seen and ResourceLoader.exists(INTRO_PATH):
		intro_seen = true
		intro = _video_player(INTRO_PATH)
		intro.finished.connect(_end_intro)
		add_child(intro)
		intro.play()
	else:
		video.play()
	resized.connect(_fit_video)
	_fit_video.call_deferred()
	add_child(UiTheme.vignette(0.45))


func _video_player(path: String) -> VideoStreamPlayer:
	var p := VideoStreamPlayer.new()
	p.stream = load(path)
	p.expand = true
	p.volume = 0.0               # videolar sessizdir; ses müzik kanalından (menu.ogg) gelir
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## Giriş videosunun son INTRO_XFADE saniyesinde döngü başlar ve giriş sönerek kaybolur (kanlı sahne → temiz koridor).
func _process(_delta: float) -> void:
	if intro == null or _intro_fading:
		return
	var length := intro.get_stream_length()
	if length > 0.0 and intro.stream_position >= length - INTRO_XFADE:
		_intro_fading = true
		video.play()
		var tw := create_tween()
		tw.tween_property(intro, "modulate:a", 0.0, INTRO_XFADE).set_trans(Tween.TRANS_SINE)
		tw.tween_callback(_end_intro)


func _end_intro() -> void:
	if intro == null:
		return
	if not video.is_playing():
		video.play()
	intro.queue_free()
	intro = null


func _add_shade() -> void:
	var g := Gradient.new()
	g.set_color(0, Color(0.01, 0.0, 0.0, 0.82))
	g.set_color(1, Color(0, 0, 0, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0.0, 0.5)
	tex.fill_to = Vector2(0.5, 0.5)
	var shade := TextureRect.new()
	shade.texture = tex
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	add_child(UiTheme.vignette(0.9))


## Videoları ekranı kaplayacak şekilde (en-boy korunarak, taşan kısım kırpılır) boyutlandırır; tıklama alanları da
## videoyla birlikte ölçeklenir ki gömülü yazıların üstünde kalsın.
func _fit_video() -> void:
	var vs := VIDEO_SIZE
	if video.get_video_texture() != null and video.get_video_texture().get_width() > 0:
		vs = video.get_video_texture().get_size()
	var k := maxf(size.x / vs.x, size.y / vs.y)
	for c: Control in [video, intro, _overlay]:
		if c == null:
			continue
		c.set_anchors_preset(Control.PRESET_TOP_LEFT)
		c.size = vs * k
		c.position = (size - c.size) * 0.5
	if _overlay:
		var s := _overlay.size / VIDEO_SIZE
		for n: Node in _overlay.get_children():
			var r: Rect2 = n.get_meta("video_rect")
			(n as Control).position = r.position * s
			(n as Control).size = r.size * s


## Video yoksa (ve ırk seçiminde): koyu kızıl zemin, yukarı savrulan korlar ve yavaşça nabız gibi atan uzak bir kızıllık.
static func add_ember_backdrop(parent: Control) -> void:
	var g := Gradient.new()
	g.set_color(0, Color(0.35, 0.05, 0.03, 0.55))
	g.set_color(1, Color(0, 0, 0, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.68, 0.78)
	tex.fill_to = Vector2(1.2, 0.2)
	var tr := TextureRect.new()
	tr.texture = tex
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(tr)
	var tw := tr.create_tween().set_loops()
	tw.tween_property(tr, "modulate:a", 0.55, 2.4).set_trans(Tween.TRANS_SINE)
	tw.tween_property(tr, "modulate:a", 1.0, 2.4).set_trans(Tween.TRANS_SINE)
	var embers := CPUParticles2D.new()
	embers.amount = 70
	embers.lifetime = 7.0
	embers.preprocess = 7.0
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = Vector2(1100, 20)
	embers.position = Vector2(1100, 1140)
	embers.direction = Vector2(0.15, -1)
	embers.spread = 18.0
	embers.gravity = Vector2(0, -8)
	embers.initial_velocity_min = 40.0
	embers.initial_velocity_max = 120.0
	embers.scale_amount_min = 1.5
	embers.scale_amount_max = 4.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.6, 0.25, 0.0))
	ramp.add_point(0.15, Color(1.0, 0.55, 0.2, 0.9))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.6, 0.08, 0.02, 0.0))
	embers.color_ramp = ramp
	parent.add_child(embers)


func _build_menu() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	box.anchor_top = 0.5
	box.anchor_bottom = 0.5
	box.offset_left = 150.0
	box.offset_top = -40.0
	box.offset_right = 560.0
	box.offset_bottom = 260.0
	add_child(box)
	for spec: Array in [["Başla", _on_start], ["Ses ayarları", func() -> void: Audio.toggle_settings()], ["Çık", _on_quit]]:
		var b := UiTheme.menu_button(str(spec[0]))
		b.pressed.connect(spec[1])
		box.add_child(b)
		buttons.append(b)
		button_labels.append(b.text)
		b.modulate.a = 0.0
		create_tween().tween_property(b, "modulate:a", 1.0, 0.6).set_delay(0.5 + 0.12 * buttons.size())
	_add_version_label()


## Video menüsü: gömülü yazıların üstüne görünmez düğmeler. Odaklanan (fare ya da klavye) yazı kızıl parlar (toplamalı
## karışımlı ışıma) ve solunda kan izi belirir; YÜKLE karartılır ve düğmesi yoktur.
func _build_video_menu() -> void:
	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	var actions := {"start": _on_start, "settings": func() -> void: Audio.toggle_settings(), "quit": _on_quit}
	for item: Array in VIDEO_ITEMS:
		var action := str(item[2])
		if action.is_empty():
			var g := Gradient.new()   # kenarlara doğru sönen karartma: yazı soluk görünür, duvarda kutu belli olmaz
			g.set_color(0, Color(0, 0, 0, 0.72))
			g.add_point(0.6, Color(0, 0, 0, 0.66))
			g.set_color(g.get_point_count() - 1, Color(0, 0, 0, 0))
			var tex := GradientTexture2D.new()
			tex.gradient = g
			tex.fill = GradientTexture2D.FILL_SQUARE
			tex.fill_from = Vector2(0.5, 0.5)
			tex.fill_to = Vector2(1.0, 0.5)
			var dim := TextureRect.new()
			dim.texture = tex
			dim.stretch_mode = TextureRect.STRETCH_SCALE
			dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
			dim.set_meta("video_rect", (item[1] as Rect2).grow_individual(4, 0, 14, 0))
			_overlay.add_child(dim)
			continue
		var b := _hotspot()
		b.set_meta("video_rect", item[1])
		b.pressed.connect(actions[action])
		_overlay.add_child(b)
		buttons.append(b)
		button_labels.append(str(item[0]))
	for i: int in buttons.size():   # yukarı/aşağı ok tuşları sarar
		buttons[i].focus_neighbor_top = buttons[i].get_path_to(buttons[(i - 1 + buttons.size()) % buttons.size()])
		buttons[i].focus_neighbor_bottom = buttons[i].get_path_to(buttons[(i + 1) % buttons.size()])
	_add_version_label()


func _hotspot() -> Button:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for st: String in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	var g := Gradient.new()
	g.set_color(0, Color(0.95, 0.12, 0.06, 0.55))
	g.add_point(0.45, Color(0.6, 0.04, 0.02, 0.28))
	g.set_color(g.get_point_count() - 1, Color(0, 0, 0, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var glow := TextureRect.new()
	glow.texture = tex
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.offset_left = -30
	glow.offset_right = 30
	glow.offset_top = -10
	glow.offset_bottom = 10
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = mat
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.modulate.a = 0.0
	b.add_child(glow)
	var mark := ColorRect.new()   # kan izi: yazının solunda kalın, aşağı sızan kızıl çizgi
	mark.color = UiTheme.BLOOD_LIGHT
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.anchor_top = 0.18
	mark.anchor_bottom = 0.18
	mark.offset_left = -4
	mark.offset_right = 3
	mark.modulate.a = 0.0
	b.add_child(mark)
	var tw_ref: Array[Tween] = [null]
	var set_lit := func(on: bool) -> void:
		if tw_ref[0] and tw_ref[0].is_valid():
			tw_ref[0].kill()
		var tw := b.create_tween().set_parallel()
		tw.tween_property(glow, "modulate:a", 1.0 if on else 0.0, 0.18 if on else 0.3)
		tw.tween_property(mark, "modulate:a", 1.0 if on else 0.0, 0.12 if on else 0.3)
		tw.tween_property(mark, "offset_bottom", b.size.y * 0.66 if on else 0.0, 0.35 if on else 0.3).set_trans(Tween.TRANS_QUAD)
		tw_ref[0] = tw
	b.focus_entered.connect(func() -> void:
		set_lit.call(true)
		if not b.is_hovered():
			Audio.play("ui_hover"))
	b.focus_exited.connect(func() -> void: set_lit.call(false))
	b.mouse_entered.connect(b.grab_focus)
	return b


func _add_version_label() -> void:
	var ver := UiTheme.label("v%s" % ProjectSettings.get_setting("application/config/version", "?"), 16, UiTheme.ASH.darkened(0.25))
	ver.anchor_top = 1.0
	ver.anchor_bottom = 1.0
	ver.offset_left = 28.0
	ver.offset_top = -44.0
	add_child(ver)


func _on_start() -> void:
	_leave(RACE_SCENE)


func _on_quit() -> void:
	if _leaving:
		return
	_leaving = true
	Audio.stop_music(0.4)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.4)
	tw.tween_callback(func() -> void: get_tree().quit())


func _leave(scene: String) -> void:
	if _leaving:
		return
	_leaving = true
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.35)
	tw.tween_callback(func() -> void: get_tree().change_scene_to_file(scene))
