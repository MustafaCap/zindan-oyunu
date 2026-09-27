## Lighting — Aşama 8 dinamik ışık: katın karanlık ortamı (CanvasModulate), oyuncunun çevresindeki ışık, duvar
## meşaleleri, mermi/büyü ışıkları. Karakter, zemin ve duvar sprite'ları normal haritalarıyla aydınlanır.
## Uyarı işaretleri, mermiler, hasar sayıları, loot ve arayüz "unshaded" malzemeyle çizilir: karanlıkta da okunur.
## Sayılar dungeon.json > lighting ve floors.json > light (_default notlarıyla).
class_name Lighting
extends RefCounted

## Önbellek zayıf referans tutar (düğümler silinince kaynaklar da bırakılır; kapanışta "kullanımda" uyarısı olmaz).
static var _refs: Dictionary = {}


static func _cached(key: String) -> Resource:
	var r: Resource = (_refs[key] as WeakRef).get_ref() if _refs.has(key) else null
	return r


static func _store(key: String, r: Resource) -> Resource:
	_refs[key] = weakref(r)
	return r


## Işıktan ve ortam karanlığından etkilenmeyen malzeme (paylaşılır).
static func unshaded() -> CanvasItemMaterial:
	var m := _cached("unshaded") as CanvasItemMaterial
	if m == null:
		m = CanvasItemMaterial.new()
		m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		_store("unshaded", m)
	return m


## Parlayan karo katmanı: ışıktan etkilenmez, üstüne eklenir.
static func glow_material() -> CanvasItemMaterial:
	var m := _cached("glow") as CanvasItemMaterial
	if m == null:
		m = CanvasItemMaterial.new()
		m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_store("glow", m)
	return m


static func light_texture() -> GradientTexture2D:
	var t := _cached("light") as GradientTexture2D
	if t == null:
		t = GradientTexture2D.new()
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 256
		t.height = 256
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.add_point(0.45, Color(0.55, 0.55, 0.55, 1))
		g.set_color(g.get_point_count() - 1, Color(0, 0, 0, 1))
		t.gradient = g
		_store("light", t)
	return t


static func cfg() -> Dictionary:
	return DataDB.get_value("dungeon", "lighting")


## İzometrik yarıçaplı nokta ışık (zeminde elips).
static func make_light(color: Color, radius_tiles: float, energy: float) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = light_texture()
	l.color = color
	l.energy = energy
	l.height = float(cfg()["light_height"])
	# Doku 256 px: yarıçap 128 px → radius_tiles karo (x); izometride y yarıya basılır
	l.texture_scale = Iso.tiles(radius_tiles) / 128.0
	l.scale = Vector2(1.0, 0.5)
	return l


## Katın karanlığını kurar (parent'ta tek CanvasModulate; varsa yeniden kullanır).
static func set_ambient(parent: Node, floor_index: int) -> CanvasModulate:
	var cm: CanvasModulate = parent.get_node_or_null("Ambient")
	if cm == null:
		cm = CanvasModulate.new()
		cm.name = "Ambient"
		parent.add_child(cm)
	var fl: Dictionary = DataDB.table("floors")["floors"][str(floor_index)]
	cm.color = Color(str(fl.get("light", {}).get("ambient", "#ffffff")))
	return cm


static func add_player_light(p: Node2D) -> PointLight2D:
	var c := cfg()
	var l := make_light(Color(str(c["player_light_color"])), float(c["player_light_radius_tiles"]), float(c["player_light_energy"]))
	l.name = "PlayerLight"
	l.position = Vector2(0, -20)
	p.add_child(l)
	return l


## Mermi/büyü ışığı (element renginde, küçük).
static func add_projectile_light(n: Node2D, color: Color) -> void:
	var c := cfg()
	n.add_child(make_light(color, float(c["projectile_light_radius_tiles"]), float(c["projectile_light_energy"])))


## Titreyen duvar meşalesi: demir kol, alev (ışıktan etkilenmez) ve nokta ışık.
class Torch:
	extends Node2D
	var color: Color = Color(1.0, 0.55, 0.25)
	var face_dir: Vector2 = Vector2(1, 0.5)    ## ekranda duvar yüzünün baktığı yön (alev bu yana eğilir)
	var _light: PointLight2D
	var _t: float = 0.0
	var _base_energy: float = 1.0
	var _flicker: float = 0.15
	var _flame: Node2D

	func _ready() -> void:
		var c := Lighting.cfg()
		_base_energy = float(c["torch_energy"])
		_flicker = float(c["torch_flicker"])
		_t = randf() * 10.0
		_light = Lighting.make_light(color, float(c["torch_radius_tiles"]), _base_energy)
		_light.position = Vector2(0, -34) + face_dir * 10.0
		add_child(_light)
		_flame = Node2D.new()
		_flame.material = Lighting.unshaded()
		_flame.draw.connect(_draw_flame)
		add_child(_flame)

	func _process(delta: float) -> void:
		_t += delta
		var f := sin(_t * 11.0) * 0.5 + sin(_t * 23.0 + 1.3) * 0.3 + sin(_t * 5.0) * 0.2
		_light.energy = _base_energy * (1.0 + f * _flicker)
		_flame.queue_redraw()

	func _draw() -> void:
		# demir kol ve kase (ışıkla aydınlanır)
		var base := Vector2(0, -24)
		draw_line(base, base + face_dir * 8.0 + Vector2(0, -6), Color(0.12, 0.11, 0.1), 3.0)
		draw_circle(base + face_dir * 8.0 + Vector2(0, -8), 3.5, Color(0.18, 0.16, 0.15))

	func _draw_flame() -> void:
		var c := Vector2(0, -34) + face_dir * 8.0
		var h := 9.0 + sin(_t * 17.0) * 1.5
		var w := 3.5 + sin(_t * 13.0 + 0.7) * 0.6
		var outer := PackedVector2Array([c + Vector2(-w, 2), c + Vector2(0, -h), c + Vector2(w, 2), c + Vector2(0, 4)])
		_flame.draw_colored_polygon(outer, Color(color, 0.9))
		var inner := PackedVector2Array([c + Vector2(-w * 0.5, 2), c + Vector2(0, -h * 0.6), c + Vector2(w * 0.5, 2), c + Vector2(0, 3)])
		_flame.draw_colored_polygon(inner, color.lightened(0.6))
