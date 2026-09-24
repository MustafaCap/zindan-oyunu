## IsoTileset — placeholder izometrik karo setini koddan üretir (Aşama 8'de gerçek karolar gelecek).
## Kaynak 0: zemin (iki ton, dama deseni). Kaynak 1: duvar, sütun/engel, kapı ve çatlak duvar blokları (çarpışmalı).
## Aşama 4: kat paleti (zemin, duvar, engel rengi), kilitli kapı ve gizli odanın çatlak duvarı.
## Çarpışma katmanları: duvarlar 1 (hiçbir şey geçemez), sütun/engeller 8 (Magical'ın Uçuş'u üstünden geçer).
class_name IsoTileset
extends RefCounted

const W := Iso.TILE_W
const H := Iso.TILE_H
const WALL_HEIGHT := 40

const FLOOR_SOURCE := 0
const BLOCK_SOURCE := 1
const FLOOR_A := Vector2i(0, 0)
const FLOOR_B := Vector2i(1, 0)
const WALL := Vector2i(0, 0)
const PILLAR := Vector2i(1, 0)
const DOOR := Vector2i(2, 0)
const CRACKED := Vector2i(3, 0)
const BLOCKS: Array[Vector2i] = [WALL, PILLAR, DOOR, CRACKED]
const WALL_LAYER := 1
const OBSTACLE_LAYER := 8


## wall_color / obstacle_color verilmezse zemin renginden türetilir (test odası).
static func build(floor_color: Color, wall_color: Color = Color(-1, 0, 0), obstacle_color: Color = Color(-1, 0, 0)) -> TileSet:
	var ts := TileSet.new()
	ts.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	ts.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	ts.tile_size = Vector2i(W, H)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, WALL_LAYER)
	ts.set_physics_layer_collision_mask(0, 0)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(1, OBSTACLE_LAYER)
	ts.set_physics_layer_collision_mask(1, 0)

	# Zemin
	var floor_img := Image.create(W * 2, H, false, Image.FORMAT_RGBA8)
	_fill_diamond(floor_img, Vector2(W * 0.5, H * 0.5), floor_color, floor_color.darkened(0.25))
	_fill_diamond(floor_img, Vector2(W * 1.5, H * 0.5), floor_color.darkened(0.08), floor_color.darkened(0.3))
	var floor_src := TileSetAtlasSource.new()
	floor_src.texture = ImageTexture.create_from_image(floor_img)
	floor_src.texture_region_size = Vector2i(W, H)
	ts.add_source(floor_src, FLOOR_SOURCE)
	floor_src.create_tile(FLOOR_A)
	floor_src.create_tile(FLOOR_B)

	# Duvar ve sütun blokları (üst yüz + iki yan yüz)
	var bh := H + WALL_HEIGHT
	var block_img := Image.create(W * BLOCKS.size(), bh, false, Image.FORMAT_RGBA8)
	var wall_c := wall_color if wall_color.r >= 0.0 else floor_color.darkened(0.45)
	var obst_c := obstacle_color if obstacle_color.r >= 0.0 else floor_color.lightened(0.05).darkened(0.2)
	_draw_block(block_img, 0, wall_c)
	_draw_block(block_img, W, obst_c)
	_draw_block(block_img, W * 2, Color(0.55, 0.36, 0.2))
	_draw_bars(block_img, W * 2)
	_draw_block(block_img, W * 3, wall_c.lightened(0.12))
	_draw_cracks(block_img, W * 3, wall_c.lightened(0.45))
	var block_src := TileSetAtlasSource.new()
	block_src.texture = ImageTexture.create_from_image(block_img)
	block_src.texture_region_size = Vector2i(W, bh)
	ts.add_source(block_src, BLOCK_SOURCE)
	var footprint := PackedVector2Array([Vector2(0, -H * 0.5), Vector2(W * 0.5, 0), Vector2(0, H * 0.5), Vector2(-W * 0.5, 0)])
	for coord: Vector2i in BLOCKS:
		block_src.create_tile(coord)
		var td := block_src.get_tile_data(coord, 0)
		# Doku bloğun tabanı karoya otursun diye yukarı kaydırılır.
		td.texture_origin = Vector2i(0, WALL_HEIGHT / 2)
		# Sütun/engel katman 8'de (Uçuş üstünden geçer); duvar, kapı ve çatlak duvar katman 1'de.
		var phys := 1 if coord == PILLAR else 0
		td.add_collision_polygon(phys)
		td.set_collision_polygon_points(phys, 0, footprint)
	return ts


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
