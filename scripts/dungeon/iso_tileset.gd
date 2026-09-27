## IsoTileset — izometrik karo seti. Aşama 8: katın Blender'da üretilmiş karoları (assets/sprites/tiles/floor<N>.png,
## blocks<N>.png; normal haritalı CanvasTexture — meşaleler zemini ve duvarları aydınlatır) varsa onlar, yoksa (test odası
## ya da eksik dosya) koddan üretilen placeholder karolar kullanılır. İki setin atlas koordinatları aynıdır.
## Kaynak 0: zemin (4 varyant). Kaynak 1: duvar (3 varyant), sütun/engel (2 varyant), kapı ve çatlak duvar (çarpışmalı).
## Parlayan parçalar (gözler, lav, mantar, kristal) ayrı bir "ışıma" setindedir (build_glow; ışıktan etkilenmez, eklenir).
## Çarpışma katmanları: duvarlar 1 (hiçbir şey geçemez), sütun/engeller 8 (Magical'ın Uçuş'u üstünden geçer).
class_name IsoTileset
extends RefCounted

const W := Iso.TILE_W
const H := Iso.TILE_H
const WALL_HEIGHT := 40
const TILE_DIR := "res://assets/sprites/tiles/"

const FLOOR_SOURCE := 0
const BLOCK_SOURCE := 1
const FLOOR_VARIANTS: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]
const FLOOR_A := Vector2i(0, 0)
const FLOOR_B := Vector2i(1, 0)
const WALL := Vector2i(0, 0)
const WALL_VARIANTS: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
const PILLAR := Vector2i(3, 0)
const PILLAR_VARIANTS: Array[Vector2i] = [Vector2i(3, 0), Vector2i(4, 0)]
const DOOR := Vector2i(5, 0)
const CRACKED := Vector2i(6, 0)
const BLOCK_COUNT := 7
const BLOCKS: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0),
	Vector2i(5, 0), Vector2i(6, 0)]
const WALL_LAYER := 1
const OBSTACLE_LAYER := 8


## Katın karo sanatı var mı (floor<N>.png ve blocks<N>.png).
static func has_art(floor_index: int) -> bool:
	return ResourceLoader.exists("%sfloor%d.png" % [TILE_DIR, floor_index]) and \
		ResourceLoader.exists("%sblocks%d.png" % [TILE_DIR, floor_index])


## Katın karo seti: sanat varsa onu, yoksa floors.json'daki placeholder renklerini kullanır.
static func for_floor(floor_index: int) -> TileSet:
	if has_art(floor_index):
		var fl := _canvas_tex("floor%d" % floor_index)
		var bl := _canvas_tex("blocks%d" % floor_index)
		return _assemble(fl, bl)
	var f: Dictionary = DataDB.table("floors")["floors"][str(floor_index)]
	return build(Color(str(f["placeholder_color"])), Color(str(f["wall_color"])), Color(str(f["obstacle_color"])))


## Işıma seti (aynı koordinatlar; yalnızca parlayan pikseller). Yoksa null.
static func build_glow(floor_index: int) -> TileSet:
	var fp := "%sfloor%d_e.png" % [TILE_DIR, floor_index]
	var bp := "%sblocks%d_e.png" % [TILE_DIR, floor_index]
	if not ResourceLoader.exists(fp) and not ResourceLoader.exists(bp):
		return null
	var fl: Texture2D = load(fp) if ResourceLoader.exists(fp) else ImageTexture.create_from_image(Image.create(W * 4, H, false, Image.FORMAT_RGBA8))
	var bl: Texture2D = load(bp) if ResourceLoader.exists(bp) else ImageTexture.create_from_image(Image.create(W * BLOCK_COUNT, H + WALL_HEIGHT, false, Image.FORMAT_RGBA8))
	return _assemble(fl, bl, false)


## Hücreye göre zemin varyantı (seed'siz, konumdan hash: aynı harita hep aynı görünür).
static func floor_tile(c: Vector2i) -> Vector2i:
	var h := absi(hash(c)) % 100
	if h < 52:
		return FLOOR_VARIANTS[0]
	if h < 78:
		return FLOOR_VARIANTS[1]
	if h < 90:
		return FLOOR_VARIANTS[2]
	return FLOOR_VARIANTS[3]


static func wall_tile(c: Vector2i) -> Vector2i:
	var h := absi(hash([c, "w"])) % 100
	if h < 72:
		return WALL_VARIANTS[0]
	if h < 92:
		return WALL_VARIANTS[1]
	return WALL_VARIANTS[2]


static func pillar_tile(c: Vector2i) -> Vector2i:
	return PILLAR_VARIANTS[absi(hash([c, "p"])) % 2]


static func _canvas_tex(name: String) -> Texture2D:
	var ct := CanvasTexture.new()
	ct.diffuse_texture = load(TILE_DIR + name + ".png")
	var n := TILE_DIR + name + "_n.png"
	if ResourceLoader.exists(n):
		ct.normal_texture = load(n)
	return ct


static func _new_tileset(with_physics: bool) -> TileSet:
	var ts := TileSet.new()
	ts.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	ts.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	ts.tile_size = Vector2i(W, H)
	if with_physics:
		ts.add_physics_layer()
		ts.set_physics_layer_collision_layer(0, WALL_LAYER)
		ts.set_physics_layer_collision_mask(0, 0)
		ts.add_physics_layer()
		ts.set_physics_layer_collision_layer(1, OBSTACLE_LAYER)
		ts.set_physics_layer_collision_mask(1, 0)
	return ts


## Zemin (4 × W×H) ve blok (7 × W×(H+duvar)) dokularından karo seti kurar.
static func _assemble(floor_tex: Texture2D, block_tex: Texture2D, with_physics: bool = true) -> TileSet:
	var ts := _new_tileset(with_physics)
	var floor_src := TileSetAtlasSource.new()
	floor_src.texture = floor_tex
	floor_src.texture_region_size = Vector2i(W, H)
	ts.add_source(floor_src, FLOOR_SOURCE)
	for c: Vector2i in FLOOR_VARIANTS:
		floor_src.create_tile(c)
	var bh := H + WALL_HEIGHT
	var block_src := TileSetAtlasSource.new()
	block_src.texture = block_tex
	block_src.texture_region_size = Vector2i(W, bh)
	ts.add_source(block_src, BLOCK_SOURCE)
	var footprint := PackedVector2Array([Vector2(0, -H * 0.5), Vector2(W * 0.5, 0), Vector2(0, H * 0.5), Vector2(-W * 0.5, 0)])
	for coord: Vector2i in BLOCKS:
		block_src.create_tile(coord)
		var td := block_src.get_tile_data(coord, 0)
		# Doku bloğun tabanı karoya otursun diye yukarı kaydırılır.
		td.texture_origin = Vector2i(0, WALL_HEIGHT / 2)
		if with_physics:
			# Sütun/engel katman 8'de (Uçuş üstünden geçer); duvar, kapı ve çatlak duvar katman 1'de.
			var phys := 1 if coord in PILLAR_VARIANTS else 0
			td.add_collision_polygon(phys)
			td.set_collision_polygon_points(phys, 0, footprint)
	return ts


## Placeholder karo seti (koddan). wall_color / obstacle_color verilmezse zemin renginden türetilir (test odası).
static func build(floor_color: Color, wall_color: Color = Color(-1, 0, 0), obstacle_color: Color = Color(-1, 0, 0)) -> TileSet:
	var floor_img := Image.create(W * FLOOR_VARIANTS.size(), H, false, Image.FORMAT_RGBA8)
	for i: int in FLOOR_VARIANTS.size():
		var shade := 0.0 if i % 2 == 0 else 0.08
		_fill_diamond(floor_img, Vector2(W * (i + 0.5), H * 0.5), floor_color.darkened(shade), floor_color.darkened(0.25 + shade))
	var bh := H + WALL_HEIGHT
	var block_img := Image.create(W * BLOCK_COUNT, bh, false, Image.FORMAT_RGBA8)
	var wall_c := wall_color if wall_color.r >= 0.0 else floor_color.darkened(0.45)
	var obst_c := obstacle_color if obstacle_color.r >= 0.0 else floor_color.lightened(0.05).darkened(0.2)
	for c: Vector2i in WALL_VARIANTS:
		_draw_block(block_img, W * c.x, wall_c)
	for c: Vector2i in PILLAR_VARIANTS:
		_draw_block(block_img, W * c.x, obst_c)
	_draw_block(block_img, W * DOOR.x, Color(0.55, 0.36, 0.2))
	_draw_bars(block_img, W * DOOR.x)
	_draw_block(block_img, W * CRACKED.x, wall_c.lightened(0.12))
	_draw_cracks(block_img, W * CRACKED.x, wall_c.lightened(0.45))
	return _assemble(ImageTexture.create_from_image(floor_img), ImageTexture.create_from_image(block_img))


static func _fill_diamond(img: Image, center: Vector2, fill: Color, edge: Color) -> void:
	for y: int in H:
		for x: int in range(int(center.x - W * 0.5), int(center.x + W * 0.5)):
			var dx := absf(x + 0.5 - center.x) / (W * 0.5)
			var dy := absf(y + 0.5 - center.y) / (H * 0.5)
			var d := dx + dy
			if d <= 1.0:
				img.set_pixel(x, y, edge if d > 0.9 else fill)


static func _draw_block(img: Image, x0: int, c: Color) -> void:
	var bh := H + WALL_HEIGHT
	var top_c := c.lightened(0.18)
	var left_c := c
	var right_c := c.darkened(0.3)
	for y: int in bh:
		for xi: int in W:
			var x := float(xi) + 0.5
			var yy := float(y) + 0.5
			# Üst yüz: (W/2, H/2) merkezli elmas
			var dtop := absf(x - W * 0.5) / (W * 0.5) + absf(yy - H * 0.5) / (H * 0.5)
			var col := Color(0, 0, 0, 0)
			if dtop <= 1.0:
				col = top_c.lightened(0.08) if dtop > 0.92 else top_c
			else:
				# Yan yüzler: üst elmasın alt kenarından WALL_HEIGHT kadar aşağı
				var edge_y := H * 0.5 + (H * 0.5) * (1.0 - absf(x - W * 0.5) / (W * 0.5))
				if yy >= edge_y and yy <= edge_y + WALL_HEIGHT:
					col = left_c if x < W * 0.5 else right_c
					if absf(x - W * 0.5) < 1.0:
						col = col.darkened(0.3)
			if col.a > 0.0:
				img.set_pixel(x0 + xi, y, col)


## Kapı: yan yüzlere koyu demir parmaklıklar.
static func _draw_bars(img: Image, x0: int) -> void:
	var bh := H + WALL_HEIGHT
	for xi: int in range(6, W - 6, 8):
		for y: int in bh:
			var c := img.get_pixel(x0 + xi, y)
			if c.a > 0.0:
				img.set_pixel(x0 + xi, y, Color(0.18, 0.16, 0.15))
				img.set_pixel(x0 + xi + 1, y, Color(0.3, 0.27, 0.25))


## Çatlak duvar: yan yüzlerde açık renkli kırık çizgiler (gizli oda ipucu).
static func _draw_cracks(img: Image, x0: int, c: Color) -> void:
	var pts: Array[Vector2i] = [Vector2i(14, 30), Vector2i(18, 38), Vector2i(15, 46), Vector2i(20, 54), Vector2i(44, 32),
		Vector2i(40, 40), Vector2i(46, 48), Vector2i(42, 58)]
	for i: int in range(0, pts.size() - 1):
		if i == 3:
			continue
		var a := pts[i]
		var b := pts[i + 1]
		for t: int in 12:
			var p := Vector2(a).lerp(Vector2(b), t / 11.0)
			var px := x0 + int(p.x)
			var py := int(p.y)
			if py < img.get_height() and img.get_pixel(px, py).a > 0.0:
				img.set_pixel(px, py, c)
