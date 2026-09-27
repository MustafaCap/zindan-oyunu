## ItemIcons — Aşama 8: Blender'da üretilen silah ve tılsım ikonları ve nadirlik çerçevesi (assets/sprites/icons/).
## Çerçeve açık gri demirdir; nadirlik (ya da tılsım) rengine boyanarak çizilir. Dosya yoksa null döner (eski çizim).
## Dokular önbellekte tutulur (arayüz her karede çizer); oyun kapanırken önbellek boşaltılır.
class_name ItemIcons
extends RefCounted

const DIR := "res://assets/sprites/icons/"

static var _cache: Dictionary = {}
static var _hooked := false


static func _tex(name: String) -> Texture2D:
	if not _cache.has(name):
		var p := DIR + name + ".png"
		_cache[name] = load(p) if ResourceLoader.exists(p) else null
		if not _hooked:
			_hooked = true
			var tree := Engine.get_main_loop() as SceneTree
			if tree:
				tree.root.tree_exiting.connect(func() -> void: _cache.clear())
	return _cache[name]


static func weapon(style: String) -> Texture2D:
	return _tex("weapon_" + style)


static func talisman(id: String) -> Texture2D:
	return _tex("talisman_" + id)


static func frame() -> Texture2D:
	return _tex("frame")


## Nadirlik çerçevesi (boyanmış) + ikon.
static func draw(ci: CanvasItem, icon: Texture2D, r: Rect2, frame_color: Color) -> void:
	var s := minf(r.size.x, r.size.y)
	var sq := Rect2(r.get_center() - Vector2(s, s) * 0.5, Vector2(s, s))
	if icon:
		ci.draw_texture_rect(icon, sq.grow(-s * 0.1), false)
	var f := frame()
	if f:
		ci.draw_texture_rect(f, sq, false, frame_color.lightened(0.15))
