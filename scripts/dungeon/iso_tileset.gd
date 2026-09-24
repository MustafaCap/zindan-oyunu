## IsoTileset — placeholder izometrik karo setini koddan üretir (Aşama 8'de gerçek karolar gelecek).
## Kaynak 0: zemin (iki ton, dama deseni). Kaynak 1: duvar ve sütun blokları (çarpışmalı).
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
const WALL_LAYER := 1
const OBSTACLE_LAYER := 8


static func build(floor_color: Color) -> TileSet:
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
	var block_img := Image.create(W * 2, bh, false, Image.FORMAT_RGBA8)
	var wall_c := floor_color.darkened(0.45)
	_draw_block(block_img, 0, wall_c)
	_draw_block(block_img, W, floor_color.lightened(0.05).darkened(0.2))
	var block_src := TileSetAtlasSource.new()
	block_src.texture = ImageTexture.create_from_image(block_img)
	block_src.texture_region_size = Vector2i(W, bh)
	ts.add_source(block_src, BLOCK_SOURCE)
	var footprint := PackedVector2Array([Vector2(0, -H * 0.5), Vector2(W * 0.5, 0), Vector2(0, H * 0.5), Vector2(-W * 0.5, 0)])
	for coord: Vector2i in [WALL, PILLAR]:
		block_src.create_tile(coord)
		var td := block_src.get_tile_data(coord, 0)
		# Doku bloğun tabanı karoya otursun diye yukarı kaydırılır.
		td.texture_origin = Vector2i(0, WALL_HEIGHT / 2)
		var phys := 0 if coord == WALL else 1
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
