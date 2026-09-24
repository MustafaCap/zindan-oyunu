## DungeonGenerator — bir katın haritasını seed'den üretir (aynı seed + kat = aynı harita).
## Adımlar:
##   1. Oda sayıları: floors.json > rooms (boss dahil) ve room_types > per_floor aralıkları. Giriş odası ve gizli
##      oda bu sayıya ektir. Savaş odası min_combat_rooms'un altına düşerse fazladan sandık/elit azaltılır.
##   2. Izgara: girişten boss'a kendini kesmeyen rastgele yürüyüşle ana yol (oda sayısının main_path_ratio'su),
##      kalan odalar ana yoldan ya da dallardan çıkan yan dallar. Boss'a yalnızca ana yoldan girilir.
##   3. Oda tipleri: tüccar, demirci ve sandık önce çıkmaz odalara; elit en az 2 oda derine (önce ana yola).
##   4. Gizli oda: bir odanın boş ızgara komşusuna; aradaki geçit çatlak duvarla kapalıdır.
##   5. Karolar: her oda için şablon (+ rastgele döndürme/aynalama), kapı yolları, 3 karo genişliğinde koridorlar.
##   6. Rastgele engeller: kapı yollarına ve oda ortasına konmaz; her engelden sonra odanın tüm zemini kapıdan
##      ulaşılabilir kalmalı, kalmıyorsa engel geri alınır.
##   7. Düşman dalgaları: katın beklenen düşman sayısı savaş odalarına bölünür (floors.json > expected_*).
## Tüm sayılar data/dungeon.json ve data/floors.json'dan okunur.
class_name DungeonGenerator
extends RefCounted

const Room := DungeonLayout.Room
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
const MAX_ATTEMPTS := 60


## enemy_mult >= 0 ise dungeon.json > waves > enemy_count_mult yerine kullanılır (smoke testini kısaltmak için).
static func generate(floor_index: int, seed_value: int, enemy_mult: float = -1.0) -> DungeonLayout:
	var dg: Dictionary = DataDB.table("dungeon")
	var fl: Dictionary = DataDB.table("floors")["floors"][str(floor_index)]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var layout := DungeonLayout.new()
	layout.floor_index = floor_index
	layout.seed_value = seed_value
	var counts := room_counts(fl, dg, rng)
	for attempt: int in MAX_ATTEMPTS:
		if _place_grid(layout, counts, dg, rng):
			break
		assert(attempt < MAX_ATTEMPTS - 1, "DungeonGenerator: ızgara yerleşimi başarısız")
	_assign_types(layout, counts, rng)
	if int(counts["secret"]) > 0:
		_add_secret(layout, rng)
	_build_tiles(layout, dg, rng)
	for r: Room in layout.rooms:
		_place_obstacles(r, dg, rng)
	_make_waves(layout, fl, dg, floor_index, rng, enemy_mult)
	return layout


## Oda tiplerinin sayıları. "combat" = kalan odalar. Giriş ve gizli oda "rooms" sayısına dahil değildir.
static func room_counts(fl: Dictionary, dg: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var rt: Dictionary = DataDB.table("floors")["room_types"]
	var c := {}
	for t: String in ["boss", "elite", "merchant", "blacksmith", "chest", "secret"]:
		var r: Array = rt[t]["per_floor"]
		c[t] = rng.randi_range(int(r[0]), int(r[1]))
	var total := int(fl["rooms"])
	var min_combat := int(dg["min_combat_rooms"])
	while total - _special_sum(c) < min_combat:
		if int(c["chest"]) > int(rt["chest"]["per_floor"][0]):
			c["chest"] = int(c["chest"]) - 1
		elif int(c["elite"]) > int(rt["elite"]["per_floor"][0]):
			c["elite"] = int(c["elite"]) - 1
		else:
			break
	c["combat"] = maxi(total - _special_sum(c), 0)
	c["total"] = total
	return c


static func _special_sum(c: Dictionary) -> int:
	return int(c["boss"]) + int(c["elite"]) + int(c["merchant"]) + int(c["blacksmith"]) + int(c["chest"])


# --- 2. ızgara ---

static func _place_grid(layout: DungeonLayout, counts: Dictionary, dg: Dictionary, rng: RandomNumberGenerator) -> bool:
	layout.rooms.clear()
	layout.edges.clear()
	var used := {}
	var start := _new_room(layout, Vector2i.ZERO, used)
	start.type = "start"
	start.on_main_path = true
	var n := int(counts["total"])
	var main_len := clampi(roundi(n * float(dg["main_path_ratio"])), 2, n)
	var cur := Vector2i.ZERO
	var last_dir := Vector2i.ZERO
	var prev := start
	for i: int in main_len:
		var opts: Array[Vector2i] = []
		for d: Vector2i in DIRS:
			if not used.has(cur + d):
				opts.append(d)
		if opts.is_empty():
			return false
		# Aynı yönde devam etmeyi biraz tercih et: harita yumak gibi kıvrılmasın
		var dir := opts[rng.randi_range(0, opts.size() - 1)]
		if last_dir in opts and rng.randf() < 0.35:
			dir = last_dir
		last_dir = dir
		cur += dir
		var r := _new_room(layout, cur, used)
		r.on_main_path = true
		layout.edges.append([prev.id, r.id, false])
		prev = r
	layout.boss_id = prev.id
	layout.start_id = start.id
	var boss_grid := prev.grid
	for i: int in n - main_len:
		var cands: Array = []
		for r: Room in layout.rooms:
			if r.id == layout.boss_id:
				continue
			for d: Vector2i in DIRS:
				var g := r.grid + d
				if used.has(g) or _adjacent(g, boss_grid):
					continue
				cands.append([r, g])
		if cands.is_empty():
			return false
		var pick: Array = cands[rng.randi_range(0, cands.size() - 1)]
		var nr := _new_room(layout, pick[1], used)
		layout.edges.append([(pick[0] as Room).id, nr.id, false])
	_compute_depths(layout)
	return true


static func _adjacent(a: Vector2i, b: Vector2i) -> bool:
	return absi(a.x - b.x) + absi(a.y - b.y) == 1


static func _new_room(layout: DungeonLayout, g: Vector2i, used: Dictionary) -> Room:
	var r := Room.new()
	r.id = layout.rooms.size()
	r.grid = g
	used[g] = r.id
	layout.rooms.append(r)
	return r


static func _compute_depths(layout: DungeonLayout) -> void:
	for r: Room in layout.rooms:
		r.depth = -1
	layout.rooms[layout.start_id].depth = 0
	var queue: Array[int] = [layout.start_id]
	while not queue.is_empty():
		var id: int = queue.pop_front()
		for nb: int in layout.neighbors(id):
			if layout.rooms[nb].depth < 0:
				layout.rooms[nb].depth = layout.rooms[id].depth + 1
				queue.append(nb)


# --- 3. oda tipleri ---

static func _assign_types(layout: DungeonLayout, counts: Dictionary, rng: RandomNumberGenerator) -> void:
	layout.rooms[layout.boss_id].type = "boss"
	var free: Array[int] = []
	for r: Room in layout.rooms:
		if r.id != layout.start_id and r.id != layout.boss_id:
			r.type = ""
			free.append(r.id)
	_shuffle(free, rng)
	# Çıkmaz odalar önce: tüccar, demirci, sandık keşfedilince ödül gibi hissettirsin
	var leaves: Array[int] = []
	var others: Array[int] = []
	for id: int in free:
		if layout.neighbors(id).size() == 1:
			leaves.append(id)
		else:
			others.append(id)
	var order: Array[int] = leaves + others
	var wanted: Array[String] = ["merchant", "blacksmith"]
	for i: int in int(counts["chest"]):
		wanted.append("chest")
	for t: String in wanted:
		for id: int in order:
			if layout.rooms[id].type == "":
				layout.rooms[id].type = t
				break
	# Elit: en az 2 oda derinde, önce ana yolda
	for i: int in int(counts["elite"]):
		var best := -1
		for pass_i: int in 3:
			for id: int in free:
				var r := layout.rooms[id]
				if r.type != "":
					continue
				if pass_i == 0 and (r.depth < 2 or not r.on_main_path):
					continue
				if pass_i == 1 and r.depth < 2:
					continue
				best = id
				break
			if best >= 0:
				break
		if best >= 0:
			layout.rooms[best].type = "elite"
	for id: int in free:
		if layout.rooms[id].type == "":
			layout.rooms[id].type = "combat"


static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i: int in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


# --- 4. gizli oda ---

static func _add_secret(layout: DungeonLayout, rng: RandomNumberGenerator) -> void:
	var used := {}
	for r: Room in layout.rooms:
		used[r.grid] = true
	var boss_grid := layout.rooms[layout.boss_id].grid
	var cands: Array = []
	for r: Room in layout.rooms:
		if r.type in ["start", "boss"]:
			continue
		for d: Vector2i in DIRS:
			var g := r.grid + d
			if not used.has(g) and not _adjacent(g, boss_grid):
				cands.append([r.id, g])
	if cands.is_empty():
		return
	var pick: Array = cands[rng.randi_range(0, cands.size() - 1)]
	var s := _new_room(layout, pick[1], used)
	s.type = "secret"
	s.depth = layout.rooms[int(pick[0])].depth + 1
	layout.edges.append([int(pick[0]), s.id, true])
	layout.secret_id = s.id
	layout.secret_host_id = int(pick[0])


# --- 5. karolar ---

static func _build_tiles(layout: DungeonLayout, dg: Dictionary, rng: RandomNumberGenerator) -> void:
	var cell := int(dg["grid_cell_tiles"])
	var jit := int(dg["room_jitter_tiles"])
	var templates: Dictionary = dg["templates"]
	for r: Room in layout.rooms:
		var pool: Array = dg["template_pools"][r.type]
		r.template_id = str(pool[rng.randi_range(0, pool.size() - 1)])
		r.symmetry = rng.randi_range(0, 7) if bool(dg["template_symmetry"]) else 0
		var shape := template_cells(templates[r.template_id]["rows"], r.symmetry)
		r.size = shape["size"]
		var room_margin := Vector2i((cell - r.size.x) / 2 - 2, (cell - r.size.y) / 2 - 2)
		var j := Vector2i(rng.randi_range(-mini(jit, room_margin.x), mini(jit, room_margin.x)),
			rng.randi_range(-mini(jit, room_margin.y), mini(jit, room_margin.y)))
		r.origin = r.grid * cell + (Vector2i(cell, cell) - r.size) / 2 + j
		for c: Vector2i in shape["floor"]:
			r.cells[r.origin + c] = true
		for c: Vector2i in shape["obstacles"]:
			r.cells[r.origin + c] = true
			r.obstacles[r.origin + c] = true
	for e: Array in layout.edges:
		var a := layout.rooms[int(e[0])]
		var b := layout.rooms[int(e[1])]
		var d := b.grid - a.grid
		var ma := _carve_door(a, d, b.id)
		var mb := _carve_door(b, -d, a.id)
		var secret := bool(e[2])
		var target: Dictionary = layout.secret_floor if secret else layout.corridor_cells
		_carve_corridor(ma, mb, d, a, b, target)
		if secret:
			for c: Vector2i in a.doors[b.id]:
				layout.secret_wall_cells.append(c)
				layout.secret_floor.erase(c)
	for r: Room in layout.rooms:
		for c: Vector2i in r.cells.keys():
			layout.cell_room[c] = r.id
			if r.type == "secret":
				layout.secret_floor[c] = true
			else:
				layout.floor_cells[c] = true
		# oda ortası da açık kalsın (sandık, tüccar, merdiven, boss burada durur)
		var ctr := r.origin + r.size / 2
		for dx: int in range(-2, 3):
			for dy: int in range(-2, 3):
				r.keep_clear[ctr + Vector2i(dx, dy)] = true
	for c: Vector2i in layout.corridor_cells.keys():
		layout.floor_cells[c] = true


## Şablon satırlarını karolara çevirir; symmetry: bit 4 = eksenleri değiştir, bit 1 = x aynala, bit 2 = y aynala.
static func template_cells(rows: Array, symmetry: int) -> Dictionary:
	var h := rows.size()
	var w := str(rows[0]).length()
	var size := Vector2i(h, w) if symmetry & 4 else Vector2i(w, h)
	var floor_out: Array[Vector2i] = []
	var obs_out: Array[Vector2i] = []
	for y: int in h:
		var row := str(rows[y])
		for x: int in w:
			var ch := row[x]
			if ch == " ":
				continue
			var p := Vector2i(y, x) if symmetry & 4 else Vector2i(x, y)
			if symmetry & 1:
				p.x = size.x - 1 - p.x
			if symmetry & 2:
				p.y = size.y - 1 - p.y
			if ch == "o":
				obs_out.append(p)
			else:
				floor_out.append(p)
	return {"size": size, "floor": floor_out, "obstacles": obs_out}


## d yönündeki kenarın ortasından odanın içine, şablon zeminine ulaşana kadar 3 karo genişliğinde yol açar.
## Kapı ağzını (oda dışındaki 3 karo) kaydeder ve ağzın ortasını döndürür.
static func _carve_door(r: Room, d: Vector2i, other_id: int) -> Vector2i:
	var mid: Vector2i
	if d == Vector2i(1, 0):
		mid = Vector2i(r.origin.x + r.size.x - 1, r.origin.y + r.size.y / 2)
	elif d == Vector2i(-1, 0):
		mid = Vector2i(r.origin.x, r.origin.y + r.size.y / 2)
	elif d == Vector2i(0, 1):
		mid = Vector2i(r.origin.x + r.size.x / 2, r.origin.y + r.size.y - 1)
	else:
		mid = Vector2i(r.origin.x + r.size.x / 2, r.origin.y)
	var p := Vector2i(absi(d.y), absi(d.x))
	var c := mid
	for step: int in maxi(r.size.x, r.size.y):
		var all_floor := true
		for k: int in range(-1, 2):
			var cc := c + p * k
			if not r.cells.has(cc) or r.obstacles.has(cc):
				all_floor = false
			r.cells[cc] = true
			r.obstacles.erase(cc)
			r.keep_clear[cc] = true
		if all_floor:
			break
		c -= d
	var mouth: Array[Vector2i] = []
	for k: int in range(-1, 2):
		mouth.append(mid + d + p * k)
	r.doors[other_id] = mouth
	r.door_inner[other_id] = mid
	return mid + d


## İki kapı ağzı arasında 3 karo genişliğinde koridor: ilerle → yana kay → ilerle.
static func _carve_corridor(ma: Vector2i, mb: Vector2i, d: Vector2i, a: Room, b: Room, target: Dictionary) -> void:
	var pts: Array[Vector2i] = []
	var horizontal := d.x != 0
	var mid := (ma.x + mb.x) / 2 if horizontal else (ma.y + mb.y) / 2
	var c := ma
	pts.append(c)
	var lim := 200
	while (c.x if horizontal else c.y) != mid and lim > 0:
		c += d
		pts.append(c)
		lim -= 1
	var lat_target := mb.y if horizontal else mb.x
	var lat := Vector2i(0, signi(lat_target - c.y)) if horizontal else Vector2i(signi(lat_target - c.x), 0)
	while (c.y if horizontal else c.x) != lat_target and lim > 0:
		c += lat
		pts.append(c)
		lim -= 1
	while c != mb and lim > 0:
		c += d
		pts.append(c)
		lim -= 1
	var ra := Rect2i(a.origin, a.size)
	var rb := Rect2i(b.origin, b.size)
	for pt: Vector2i in pts:
		for dx: int in range(-1, 2):
			for dy: int in range(-1, 2):
				var q := pt + Vector2i(dx, dy)
				if ra.has_point(q) or rb.has_point(q):
					continue
				target[q] = true


# --- 6. engeller ---

static func _place_obstacles(r: Room, dg: Dictionary, rng: RandomNumberGenerator) -> void:
	var range_arr: Array = dg["obstacles"][r.type]
	var want := rng.randi_range(int(range_arr[0]), int(range_arr[1]))
	if want <= 0:
		return
	var clear_r := int(dg["door_clear_radius"])
	var blocked := r.keep_clear.duplicate()
	for nid: Variant in r.doors.keys():
		for m: Vector2i in r.doors[nid]:
			for dx: int in range(-clear_r - 1, clear_r + 2):
				for dy: int in range(-clear_r - 1, clear_r + 2):
					blocked[m + Vector2i(dx, dy)] = true
	var cands: Array[Vector2i] = []
	for c: Vector2i in r.cells.keys():
		if blocked.has(c) or r.obstacles.has(c):
			continue
		# odanın kenarına yapışık olmasın (duvarla arasında geçit kalsın)
		var edge := false
		for dx: int in range(-1, 2):
			for dy: int in range(-1, 2):
				if not r.cells.has(c + Vector2i(dx, dy)):
					edge = true
		if not edge:
			cands.append(c)
	cands.sort()
	_shuffle(cands, rng)
	var placed := 0
	for c: Vector2i in cands:
		if placed >= want:
			break
		if _near_obstacle(r, c):
			continue
		var group: Array[Vector2i] = [c]
		if rng.randf() < 0.35:
			var d: Vector2i = DIRS[rng.randi_range(0, 3)]
			var c2 := c + d
			if r.cells.has(c2) and not blocked.has(c2) and not r.obstacles.has(c2):
				group.append(c2)
		for g: Vector2i in group:
			r.obstacles[g] = true
		if _room_connected(r):
			placed += 1
		else:
			for g: Vector2i in group:
				r.obstacles.erase(g)


static func _near_obstacle(r: Room, c: Vector2i) -> bool:
	for dx: int in range(-2, 3):
		for dy: int in range(-2, 3):
			if r.obstacles.has(c + Vector2i(dx, dy)):
				return true
	return false


## Odanın tüm boş zemini ilk kapının içinden ulaşılabilir mi?
static func _room_connected(r: Room) -> bool:
	var free := {}
	for c: Vector2i in r.cells.keys():
		if not r.obstacles.has(c):
			free[c] = true
	if free.is_empty():
		return false
	var start: Vector2i = r.door_inner.values()[0] if not r.door_inner.is_empty() else free.keys()[0]
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for d: Vector2i in DIRS:
			var n := c + d
			if free.has(n) and not seen.has(n):
				seen[n] = true
				queue.append(n)
	return seen.size() == free.size()


# --- 7. düşman dalgaları ---

static func _make_waves(layout: DungeonLayout, fl: Dictionary, dg: Dictionary, floor_index: int, rng: RandomNumberGenerator, enemy_mult: float) -> void:
	var wv: Dictionary = dg["waves"]
	var pool: Array = dg["prototype_enemies"][str(floor_index)]["pool"]
	var combat: Array[Room] = []
	var elites: Array[Room] = []
	for r: Room in layout.rooms:
		if r.type == "combat":
			combat.append(r)
		elif r.type == "elite":
			elites.append(r)
	var mult := enemy_mult if enemy_mult >= 0.0 else float(wv["enemy_count_mult"])
	var total := roundi(float(fl["expected_normal_enemies"]) * mult)
	if combat.is_empty():
		push_error("DungeonGenerator: savaş odası yok")
		return
	var per_room: Array[int] = []
	for i: int in combat.size():
		per_room.append(total / combat.size() + (1 if i < total % combat.size() else 0))
	# Elitler: her elit odasında bir tane; eksik kalanlar rastgele savaş odalarının son dalgasına
	var extra_elites := maxi(int(fl["expected_elites"]) - elites.size(), 0)
	var elite_rooms: Array[int] = []
	for i: int in extra_elites:
		elite_rooms.append(rng.randi_range(0, combat.size() - 1))
	for i: int in combat.size():
		var n := per_room[i]
		var k := clampi(ceili(float(n) / float(wv["max_per_wave"])), int(wv["min_waves"]), int(wv["max_waves"]))
		var waves: Array = []
		for w: int in k:
			var size := n / k + (1 if w < n % k else 0)
			waves.append(_wave(size, pool, dg, rng))
		for ei: int in elite_rooms:
			if ei == i:
				(waves[waves.size() - 1] as Array).append(_elite_spec(pool, dg, rng))
		combat[i].waves = waves
	for r: Room in elites:
		r.waves = [[_elite_spec(pool, dg, rng)]]
	var boss := layout.rooms[layout.boss_id]
	var bp: Array = fl["boss_pool"]
	boss.waves = [[{"id": str(dg["placeholder_boss"]["base"]), "material": "", "elite": false, "boss": true,
		"boss_id": str(bp[rng.randi_range(0, bp.size() - 1)])}]]


## size kadar düşman: havuzdan ağırlıklı seçim; fare seçilirse sürü halinde (rat_group) gelir.
static func _wave(size: int, pool: Array, dg: Dictionary, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var total_w := 0.0
	for e: Array in pool:
		total_w += float(e[2])
	var group: Array = dg["prototype_enemies"]["rat_group"]
	while out.size() < size:
		var roll := rng.randf() * total_w
		var pick: Array = pool[pool.size() - 1]
		for e: Array in pool:
			roll -= float(e[2])
			if roll <= 0.0:
				pick = e
				break
		var count := 1
		if str(pick[0]) == "cave_rat":
			count = mini(rng.randi_range(int(group[0]), int(group[1])), size - out.size())
		for i: int in count:
			out.append({"id": str(pick[0]), "material": str(pick[1]), "elite": false, "boss": false})
	return out


static func _elite_spec(pool: Array, dg: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var base_pool: Array = dg["placeholder_elite"]["base_pool"]
	var opts: Array = []
	for e: Array in pool:
		if str(e[0]) in base_pool:
			opts.append(e)
	var pick: Array = opts[rng.randi_range(0, opts.size() - 1)] if not opts.is_empty() else [base_pool[0], ""]
	return {"id": str(pick[0]), "material": str(pick[1]), "elite": true, "boss": false}
