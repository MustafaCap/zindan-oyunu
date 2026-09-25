## BossArena — boss odasının geometrisi (saf yardımcı): merkez, yarıçap, kapı yönü, oda karoları.
## Konumlar dünya (ekran) uzayında; "cart" ofsetleri merkeze göre düz uzayda karo cinsindendir.
## Boss'lar saldırı noktalarını (bulut, kök, portal, meşale) buradan seçer.
class_name BossArena
extends RefCounted

var center: Vector2 = Vector2.ZERO        ## arenanın orta noktası (dünya)
var radius: float = 11.0                  ## yürünebilir yarıçap (karo)
var door_dir: Vector2 = Vector2.DOWN      ## merkezden kapıya (düz uzay, birim)
var cells: Dictionary = {}                ## oda zemini karoları (engeller hariç) -> true
var obstacles: Array[Vector2] = []        ## sütunların dünya konumları
var cell_to_world: Callable
var world_to_cell: Callable
var los: Callable                         ## (from, to) -> bool


## Dungeon odasından arena kurar.
static func from_room(r: DungeonLayout.Room, c2w: Callable, w2c: Callable, los_fn: Callable) -> BossArena:
	var a := BossArena.new()
	a.cell_to_world = c2w
	a.world_to_cell = w2c
	a.los = los_fn
	a.center = c2w.call(r.center())
	a.radius = minf(r.size.x, r.size.y) * 0.5 - 0.6
	for c: Vector2i in r.cells.keys():
		if r.obstacles.has(c):
			a.obstacles.append(c2w.call(c))
		else:
			a.cells[c] = true
	if not r.door_inner.is_empty():
		var inner: Vector2i = r.door_inner.values()[0]
		var v := Iso.to_cart(c2w.call(inner) - a.center)
		if v.length() > 0.01:
			a.door_dir = v.normalized()
	return a


## Merkeze göre düz uzay ofsetinden (karo) dünya noktası.
func point(offset_tiles: Vector2) -> Vector2:
	return center + Iso.to_screen(offset_tiles * Iso.KARO)


## Dünya noktasının merkeze göre düz uzay ofseti (karo).
func offset_of(pos: Vector2) -> Vector2:
	return Iso.to_cart(pos - center) / Iso.KARO


## Nokta arenada yürünebilir bir karoda mı?
func inside(pos: Vector2) -> bool:
	if cells.is_empty():
		return offset_of(pos).length() <= radius
	return cells.has(world_to_cell.call(pos))


## Merkezden min_r..max_r karo uzakta, arenada rastgele bir nokta (avoid'e en az avoid_dist uzak).
func random_point(rng: RandomNumberGenerator, min_r: float, max_r: float, avoid: Vector2 = Vector2.INF, avoid_dist: float = 0.0) -> Vector2:
	var fallback := center
	for i: int in 24:
		var a := rng.randf() * TAU
		var r := rng.randf_range(min_r, minf(max_r, radius))
		var p := point(Vector2(cos(a), sin(a)) * r)
		if not inside(p):
			continue
		fallback = p
		if avoid != Vector2.INF and Iso.tile_distance(p, avoid) < avoid_dist:
			continue
		return p
	return fallback


## Bir noktanın çevresinde (radius karo içinde) arenada rastgele nokta.
func point_near(rng: RandomNumberGenerator, pos: Vector2, spread: float) -> Vector2:
	for i: int in 16:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * spread
		var p := pos + Iso.to_screen(Vector2(cos(a), sin(a)) * Iso.tiles(r))
		if inside(p):
			return p
	return pos


## Verilen noktaya en yakın arena içi nokta (merkeze doğru çekerek).
func clamp_inside(pos: Vector2, max_r: float = -1.0) -> Vector2:
	var off := offset_of(pos)
	var lim := radius if max_r < 0.0 else max_r
	if off.length() > lim:
		off = off.normalized() * lim
	var p := point(off)
	var tries := 0
	while not inside(p) and tries < 20:
		off *= 0.9
		p = point(off)
		tries += 1
	return p
