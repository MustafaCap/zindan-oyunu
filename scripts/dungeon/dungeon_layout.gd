## DungeonLayout — bir katın üretilmiş haritası (saf veri; sahneden bağımsız, testlerde doğrudan kullanılır).
## Karo koordinatları TileMapLayer'ın izometrik koordinatlarıdır (Vector2i). Odalar kaba bir ızgaraya dizilir
## (her ızgara hücresi grid_cell_tiles × grid_cell_tiles karo); komşu odalar 3 karo genişliğinde koridorla bağlanır.
## Gizli oda ve ona giden koridor, çatlak duvar kırılana kadar haritada yoktur (secret_* alanları).
class_name DungeonLayout
extends RefCounted


## Tek bir oda.
class Room:
	extends RefCounted
	var id: int = 0
	var type: String = "combat"          ## start, combat, elite, merchant, blacksmith, chest, secret, boss
	var grid: Vector2i = Vector2i.ZERO   ## ızgara hücresi
	var template_id: String = ""
	var symmetry: int = 0                ## 0-7: şablonun döndürülmüş/aynalanmış hali
	var origin: Vector2i = Vector2i.ZERO ## sınır kutusunun sol-üst karosu
	var size: Vector2i = Vector2i.ZERO
	var cells: Dictionary = {}           ## Vector2i -> true: odanın zemini (engeller dahil)
	var obstacles: Dictionary = {}       ## Vector2i -> true: sütun/engel karoları (oda zemininin alt kümesi)
	var doors: Dictionary = {}           ## komşu oda id -> Array[Vector2i]: kapı ağzı (oda dışındaki ilk koridor karoları)
	var door_inner: Dictionary = {}      ## komşu oda id -> Vector2i: kapının oda içindeki orta karosu
	var keep_clear: Dictionary = {}      ## kapı yolları ve orta alan: engel konmaz
	var depth: int = 0                   ## girişten kaç oda uzakta
	var on_main_path: bool = false
	var waves: Array = []                ## [[{"id", "material", "elite", "boss", "boss_id"}, ...], ...]

	## Odanın orta karosu (engel değilse); engelse en yakın boş zemin.
	func center() -> Vector2i:
		var c := origin + size / 2
		if cells.has(c) and not obstacles.has(c):
			return c
		var best := c
		var best_d := 1 << 30
		for k: Vector2i in cells.keys():
			if obstacles.has(k):
				continue
			var d := (k - c).length_squared()
			if d < best_d:
				best_d = d
				best = k
		return best

	## Üzerinde yürünebilen karolar (zemin - engeller).
	func free_cells() -> Array[Vector2i]:
		var out: Array[Vector2i] = []
		for k: Vector2i in cells.keys():
			if not obstacles.has(k):
				out.append(k)
		return out

	func has_enemies() -> bool:
		return not waves.is_empty()


var floor_index: int = 1
var seed_value: int = 0
var rooms: Array[Room] = []
var edges: Array = []                    ## [a, b, gizli_mi]
var start_id: int = 0
var boss_id: int = -1
var secret_id: int = -1
var floor_cells: Dictionary = {}         ## görünen zemin: odalar + koridorlar (gizli kısım hariç), engeller dahil
var corridor_cells: Dictionary = {}
var secret_floor: Dictionary = {}        ## gizli oda + gizli koridor (duvar kırılınca açılır)
var secret_wall_cells: Array[Vector2i] = []  ## çatlak duvar karoları (kırılınca zemin olur)
var secret_host_id: int = -1             ## çatlak duvarın bulunduğu oda
var cell_room: Dictionary = {}           ## oda zemini karosu -> oda id


func room(id: int) -> Room:
	return rooms[id]


func neighbors(id: int, include_secret: bool = true) -> Array[int]:
	var out: Array[int] = []
	for e: Array in edges:
		if bool(e[2]) and not include_secret:
			continue
		if int(e[0]) == id:
			out.append(int(e[1]))
		elif int(e[1]) == id:
			out.append(int(e[0]))
	return out


func count_type(t: String) -> int:
	var n := 0
	for r: Room in rooms:
		if r.type == t:
			n += 1
	return n


## Karonun ait olduğu oda (koridor ya da boşluksa -1).
func room_at(c: Vector2i) -> int:
	return int(cell_room.get(c, -1))


func is_obstacle(c: Vector2i) -> bool:
	var rid := room_at(c)
	return rid >= 0 and rooms[rid].obstacles.has(c)


## Yürünebilir karolar. secrets_open: çatlak duvar kırıldıysa gizli kısım da dahil.
func walkable(secrets_open: bool) -> Dictionary:
	var out := {}
	for c: Vector2i in floor_cells.keys():
		if not is_obstacle(c):
			out[c] = true
	if secrets_open:
		for c: Vector2i in secret_floor.keys():
			if not is_obstacle(c):
				out[c] = true
		for c: Vector2i in secret_wall_cells:
			out[c] = true
	return out


## Görünen zemin karoları (engeller dahil) — çizim için.
func visible_floor(secrets_open: bool) -> Dictionary:
	var out := floor_cells.duplicate()
	if secrets_open:
		out.merge(secret_floor)
		for c: Vector2i in secret_wall_cells:
			out[c] = true
	return out


## Görünen zeminin çevresindeki duvar karoları (8 komşu). Çatlak duvar kapalıyken ayrıca çizilir, buraya girmez.
func wall_cells(secrets_open: bool) -> Array[Vector2i]:
	var fl := visible_floor(secrets_open)
	var skip := {}
	if not secrets_open:
		for c: Vector2i in secret_wall_cells:
			skip[c] = true
	var seen := {}
	var out: Array[Vector2i] = []
	for c: Vector2i in fl.keys():
		for dx: int in range(-1, 2):
			for dy: int in range(-1, 2):
				var n := c + Vector2i(dx, dy)
				if fl.has(n) or skip.has(n) or seen.has(n):
					continue
				seen[n] = true
				out.append(n)
	return out


## Başlangıç karosundan 4 yönde ulaşılabilen karolar.
func reachable_from(start: Vector2i, secrets_open: bool) -> Dictionary:
	var walk := walkable(secrets_open)
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for d: Vector2i in dirs:
			var n := c + d
			if walk.has(n) and not seen.has(n):
				seen[n] = true
				queue.append(n)
	return seen


## Kapıya yakın karolar: oyuncu bu bölgedeyken oda kilitlenmez (kapı arkasında kapanmasın diye).
func entry_zone(id: int, radius: int) -> Dictionary:
	var out := {}
	var r := rooms[id]
	for nid: Variant in r.doors.keys():
		for m: Vector2i in r.doors[nid]:
			for dx: int in range(-radius, radius + 1):
				for dy: int in range(-radius, radius + 1):
					out[m + Vector2i(dx, dy)] = true
	return out


## Tüm karoları kapsayan dikdörtgen.
func bounds() -> Rect2i:
	var all := floor_cells.duplicate()
	all.merge(secret_floor)
	var mn := Vector2i(1 << 30, 1 << 30)
	var mx := Vector2i(-(1 << 30), -(1 << 30))
	for c: Vector2i in all.keys():
		mn = Vector2i(mini(mn.x, c.x), mini(mn.y, c.y))
		mx = Vector2i(maxi(mx.x, c.x), maxi(mx.y, c.y))
	return Rect2i(mn - Vector2i(2, 2), mx - mn + Vector2i(5, 5))


## Haritanın özeti (aynı seed aynı haritayı üretir mi testi için).
func signature() -> String:
	var parts: PackedStringArray = []
	for r: Room in rooms:
		var obs: Array = r.obstacles.keys()
		obs.sort()
		parts.append("%d:%s:%s:%s:%d:%s:%s:%s" % [r.id, r.type, r.grid, r.template_id, r.symmetry, r.origin, obs, JSON.stringify(r.waves)])
	parts.append(str(edges))
	parts.append(str(corridor_cells.size()))
	return "|".join(parts)
