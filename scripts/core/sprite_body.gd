## SpriteBody — Aşama 8: Blender'da üretilen 8 yönlü sprite'larla çizilen karakter (PlaceholderBody'nin yerine geçer).
## Sprite'lar `assets/sprites/characters/<id>/` içindedir (meta.json + her animasyon için renk ve normal haritası sayfası;
## tools/blender/render_sprites.py üretir). Renk ve normal CanvasTexture'da birleşir: Light2D'ler (meşale, büyü) karakteri
## normal haritasıyla aydınlatır. Karanlıkta parlayan parçalar (gözler) ışıktan etkilenmeyen ayrı bir katmandır.
## Silah ayrı katmandır (`assets/sprites/weapons/`, 16 dönüş × 4 eğim): karakterin elindeki konum ve açı meta'dan okunur,
## element varsa parıltı maskesi element rengiyle boyanır. Demir yumruk iki ele birden giydirilir.
## Animasyon kendiliğinden seçilir: hareket → walk, durunca idle; lean yükselince (saldırı) attack, cast ya da demir
## yumrukta sırayla punch_r / punch_l; flash → hit; play_action() yetenek animasyonu (Warrior Kalkan Hücumu: rush);
## play_death() ölüm animasyonunu oynatıp son karede kalır. API PlaceholderBody ile aynıdır (flash, set_facing, lean, …).
class_name SpriteBody
extends PlaceholderBody

const CHAR_DIR := "res://assets/sprites/characters/"
const WEAPON_DIR := "res://assets/sprites/weapons/"
## Bu görsellerle yapılan saldırılar "cast" (atış/büyü) animasyonunu, diğerleri "attack" (savuruş) animasyonunu oynatır.
const RANGED_STYLES := ["bow", "crossbow", "tome", "staff", "rune", "ranged"]
## İki ele birden giyilen silah görselleri.
const DUAL_STYLES := ["fist"]
const ATTACK_ANIMS := ["attack", "cast", "punch_r", "punch_l"]

## Önbellekler zayıf referans tutar: gövdeler silinince dokular da bırakılır (kapanışta sızıntı uyarısı olmaz).
static var _chars: Dictionary = {}     ## id → WeakRef(CharSprites)
static var _weapons: Dictionary = {}   ## görsel → WeakRef(WeaponSprites)
static var _weapon_meta: Dictionary = {}
static var _weapons_loaded := false

var char_id: String = ""
var sprites: CharSprites
## Saldırı animasyonunu seçer: boşsa weapon_style'a bakılır (düşmanlar "melee"/"ranged" verir).
var attack_kind: String = ""
var dir_index: int = 2
var anim: String = "idle"
var anim_t: float = 0.0
var frozen_frame: int = -1             ## ≥ 0: iz (afterimage) kopyası; bu kareyi çizer, oynatmaz
## Durum varyantı: varsa "<anim><variant>" sayfası çizilir (ör. Kordrak plakasız "_p2", Morvath kapak kapalı "_closed").
var variant: String = ""
var _oneshot: String = ""
var _speed: float = 1.0                ## tek seferlik animasyonun hız çarpanı (play_action süreye uydurur)
var _dying := false
var _prev_lean: float = 0.0
var _punch_left := false
var _ws: WeaponSprites                 ## elindeki silahın sayfası (güçlü referans; önbellek zayıf tutar)
var _ws_style: String = "<yok>"
var _emissive: EmissiveLayer


## Sprite'ı olan karakter için SpriteBody, yoksa PlaceholderBody döndürür.
static func create(id: String) -> PlaceholderBody:
	if id != "" and has_sprites(id):
		var b := SpriteBody.new()
		b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR   # 2× doku ~0,8× çizilir; yumuşak küçültme
		b.char_id = id
		b.sprites = _load_char(id)
		b.body_height = b.sprites.height
		b.body_width = b.sprites.width
		return b
	return PlaceholderBody.new()


static func has_sprites(id: String) -> bool:
	return FileAccess.file_exists(CHAR_DIR + id + "/meta.json")


static func _load_char(id: String) -> CharSprites:
	var cs: CharSprites = (_chars[id] as WeakRef).get_ref() if _chars.has(id) else null
	if cs == null:
		cs = CharSprites.new(CHAR_DIR + id + "/")
		_chars[id] = weakref(cs)
	return cs


static func weapon_sprites(style: String) -> WeaponSprites:
	if not _weapons_loaded:
		_weapons_loaded = true
		var path := WEAPON_DIR + "weapons.json"
		if FileAccess.file_exists(path):
			var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if typeof(meta) == TYPE_DICTIONARY:
				_weapon_meta = meta
	if not _weapon_meta.has(style):
		return null
	var ws: WeaponSprites = (_weapons[style] as WeakRef).get_ref() if _weapons.has(style) else null
	if ws == null:
		ws = WeaponSprites.new(WEAPON_DIR, _weapon_meta[style])
		_weapons[style] = weakref(ws)
	return ws


func _ready() -> void:
	super._ready()
	if sprites and sprites.has_emissive and frozen_frame < 0:
		_emissive = EmissiveLayer.new()
		_emissive.body = self
		add_child(_emissive)


func _process(delta: float) -> void:
	if frozen_frame >= 0 or sprites == null:
		return
	anim_t += delta * _speed
	if lean > _prev_lean + 0.2 and not _dying and _oneshot != "rush":
		_start(_attack_anim())
	_prev_lean = lean
	if _oneshot != "":
		var a: CharSprites.Anim = sprites.anims[_oneshot]
		if anim_t >= a.frames / a.fps and not _dying:
			_oneshot = ""
			_speed = 1.0
	if _oneshot == "":
		var v := _parent_velocity()
		var next := "walk" if v.length() > 8.0 and sprites.anims.has("walk") else "idle"
		if next != anim:
			anim = next
			anim_t = 0.0
	queue_redraw()
	if _emissive:
		_emissive.queue_redraw()


func _attack_anim() -> String:
	var kind := attack_kind if attack_kind != "" else weapon_style
	if kind in DUAL_STYLES and sprites.anims.has("punch_r"):
		_punch_left = not _punch_left
		return "punch_l" if _punch_left else "punch_r"
	return "cast" if kind in RANGED_STYLES else "attack"


func _start(name: String, speed: float = 1.0) -> void:
	if not sprites.anims.has(name):
		return
	anim = name
	_oneshot = name
	anim_t = 0.0
	_speed = speed


## Saldırı animasyonu (boss'lar saldırı başlatınca).
func play_attack() -> void:
	if sprites and not _dying:
		_start(_attack_anim())


## Yetenek animasyonu (ör. "rush": Warrior Kalkan Hücumu). duration > 0 ise animasyon bu süreye sığdırılır.
func play_action(name: String, duration: float = -1.0) -> void:
	if sprites == null or _dying or not sprites.anims.has(name):
		return
	var a: CharSprites.Anim = sprites.anims[name]
	_start(name, (a.frames / a.fps) / duration if duration > 0.0 else 1.0)


func _parent_velocity() -> Vector2:
	var p := get_parent()
	if p is CharacterBody2D:
		return (p as CharacterBody2D).velocity
	return Vector2.ZERO


func flash(duration: float, color: Color = Color.WHITE) -> void:
	super.flash(duration, color)
	if sprites and not _dying and _oneshot not in ATTACK_ANIMS and _oneshot != "rush":
		_start("hit")


## Ölüm animasyonunu oynatır (son karede kalır). Sprite'lı gövde için true.
func play_death() -> bool:
	if sprites == null or not sprites.anims.has("death"):
		return false
	_dying = true
	_start("death")
	return true


## Atılma/ışınlanma izi: bu anki kareyi donmuş olarak çizen kopya.
func make_afterimage() -> Node2D:
	var c := SpriteBody.new()
	c.texture_filter = texture_filter
	c.char_id = char_id
	c.sprites = sprites
	c.dir_index = dir_index
	c.anim = anim
	c.frozen_frame = _frame(sprites.anims[anim])
	c.show_weapon = false
	c.show_shadow = false
	return c


func set_facing(f: Vector2) -> void:
	if f.length() > 0.01:
		facing_cart = f.normalized()
		dir_index = wrapi(roundi(atan2(facing_cart.y, facing_cart.x) / (PI / 4.0)), 0, 8)


func _frame(a: CharSprites.Anim) -> int:
	if frozen_frame >= 0:
		return mini(frozen_frame, a.frames - 1)
	var fps := a.fps
	if anim == "walk":
		# Adım hızı yürüme hızına uyar (karo/sn ÷ bir döngüde alınan yol × kare sayısı)
		var tiles := Iso.to_cart(_parent_velocity()).length() / Iso.KARO
		fps = maxf(tiles / sprites.walk_stride * a.frames, 4.0)
	var f := int(anim_t * fps)
	return f % a.frames if a.loop else mini(f, a.frames - 1)


## Çizilen animasyon: durum varyantı varsa onun sayfası.
func _cur() -> CharSprites.Anim:
	if variant != "" and sprites.anims.has(anim + variant):
		return sprites.anims[anim + variant]
	return sprites.anims[anim]


func _src(a: CharSprites.Anim, f: int) -> Rect2:
	return Rect2(f * a.cell.x, dir_index * a.cell.y, a.cell.x, a.cell.y)


func _dest(a: CharSprites.Anim) -> Rect2:
	var s := 1.0 / sprites.scale
	return Rect2(-a.anchor * s, a.cell * s)


func _draw() -> void:
	if sprites == null:
		return
	var a: CharSprites.Anim = _cur()
	var f := _frame(a)
	if show_shadow:
		var k := 0.55 if anim == "death" else 1.0
		_draw_ellipse(Vector2.ZERO, body_width * 0.5 * k + 4.0, body_width * 0.25 * k + 2.0, Color(0, 0, 0, 0.35))
	if weapon_style != _ws_style:
		_ws_style = weapon_style
		_ws = weapon_sprites(weapon_style)
	# Silahı tutan eller: [el verisi, arkada mı]; demir yumrukta iki el
	var hands: Array = []
	# Ölürken silah elden düşer (yere yığılırken havada dikili kalmasın)
	var holding := not (anim == "death" and f >= 3)
	if show_weapon and holding and not a.hand.is_empty():
		hands.append(a.hand[dir_index][f])
		if weapon_style in DUAL_STYLES and not a.hand_l.is_empty():
			hands.append(a.hand_l[dir_index][f])
	var behind: Array[bool] = []
	for h: Array in hands:
		var b := _ws != null and float(h[4]) + float(h[5]) * _ws.length / Iso.KARO * 0.5 > 0.0
		behind.append(b)
		if b:
			_draw_weapon_sprite(_ws, h)
	draw_texture_rect_region(a.texture, _dest(a), _src(a, f))
	for i: int in hands.size():
		if _ws and not behind[i]:
			_draw_weapon_sprite(_ws, hands[i])
		elif _ws == null and weapon_style != "":
			# Sprite'ı henüz olmayan silah: placeholder çizimi eldeki konuma
			var h: Array = hands[i]
			var d := Iso.to_screen(facing_cart).normalized()
			draw_set_transform(Vector2(float(h[0]), float(h[1])) - Vector2(0, -body_height * 0.45) - d * 8.0)
			_draw_weapon(d, Vector2.ZERO)
			draw_set_transform(Vector2.ZERO)


## Duvar arkası silüeti (XRayMarker çağırır): o anki kare, verilen düğümün malzemesiyle.
func draw_silhouette(ci: CanvasItem) -> void:
	if sprites == null:
		return
	var a: CharSprites.Anim = _cur()
	ci.draw_texture_rect_region(a.texture.diffuse_texture, _dest(a), _src(a, _frame(a)))


## Işıktan etkilenmeyen katman (EmissiveLayer'dan çağrılır).
func draw_emissive(layer: CanvasItem) -> void:
	var a: CharSprites.Anim = _cur()
	if a.emissive == null:
		return
	layer.draw_texture_rect_region(a.emissive, _dest(a), _src(a, _frame(a)), Color(1, 1, 1, modulate.a))


func _draw_weapon_sprite(ws: WeaponSprites, hand: Array) -> void:
	var yaw := float(hand[2])
	var pitch := float(hand[3])
	var j := wrapi(roundi(yaw / (360.0 / ws.yaws)), 0, ws.yaws)
	var pi := 0
	for i: int in ws.pitches.size():
		if absf(ws.pitches[i] - pitch) < absf(ws.pitches[pi] - pitch):
			pi = i
	var s := 1.0 / sprites.scale
	var src := Rect2(j * ws.cell, pi * ws.cell, ws.cell, ws.cell)
	var size := Vector2(ws.cell, ws.cell) * s
	var dest := Rect2(Vector2(float(hand[0]), float(hand[1])) - size * 0.5, size)
	draw_texture_rect_region(ws.texture, dest, src)
	if weapon_glow and ws.glow:
		draw_texture_rect_region(ws.glow, dest, src, Color(weapon_color.lightened(0.1), 0.6))


## Gözler gibi karanlıkta parlayan parçalar: ışıktan etkilenmez, üstüne eklenerek (additive) çizilir.
class EmissiveLayer:
	extends Node2D
	var body: SpriteBody

	func _ready() -> void:
		var m := CanvasItemMaterial.new()
		m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = m
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	func _draw() -> void:
		if body:
			body.draw_emissive(self)


## Bir karakterin sprite sayfaları ve meta'sı.
class CharSprites:
	var scale: float = 2.0
	var height: float = 50.0
	var width: float = 24.0
	var walk_stride: float = 1.4
	var has_emissive := false
	var anims: Dictionary = {}

	class Anim:
		var texture: CanvasTexture
		var emissive: Texture2D
		var frames: int
		var fps: float
		var loop: bool
		var cell: Vector2
		var anchor: Vector2
		var hand: Array = []
		var hand_l: Array = []

	func _init(dir: String) -> void:
		var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir + "meta.json"))
		scale = float(meta.get("scale", 2.0))
		height = float(meta.get("height", 50.0))
		width = float(meta.get("width", 24.0))
		walk_stride = float(meta.get("walk_stride", 1.4))
		for name: String in (meta["anims"] as Dictionary).keys():
			var m: Dictionary = meta["anims"][name]
			var a := Anim.new()
			a.texture = CanvasTexture.new()
			a.texture.diffuse_texture = load(dir + str(m["file"]))
			a.texture.normal_texture = load(dir + str(m["normal"]))
			if m.has("emissive"):
				a.emissive = load(dir + str(m["emissive"]))
				has_emissive = true
			a.frames = int(m["frames"])
			a.fps = float(m["fps"])
			a.loop = bool(m["loop"])
			a.cell = Vector2(m["cell"][0], m["cell"][1])
			a.anchor = Vector2(m["anchor"][0], m["anchor"][1])
			a.hand = m.get("hand", [])
			a.hand_l = m.get("hand_l", [])
			anims[name] = a


## Bir silah görselinin sayfası (16 dönüş × eğimler), normal haritası ve parıltı maskesi.
class WeaponSprites:
	var texture: CanvasTexture
	var glow: Texture2D
	var cell: float
	var yaws: int
	var pitches: Array[float] = []
	var length: float

	func _init(dir: String, m: Dictionary) -> void:
		texture = CanvasTexture.new()
		texture.diffuse_texture = load(dir + str(m["file"]))
		texture.normal_texture = load(dir + str(m["normal"]))
		glow = load(dir + str(m["glow"])) if m.has("glow") else null
		cell = float(m["cell"])
		yaws = int(m["yaws"])
		for p: Variant in m["pitches"]:
			pitches.append(float(p))
		length = float(m["length"])
