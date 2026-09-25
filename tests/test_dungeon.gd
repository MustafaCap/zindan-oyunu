## Aşama 4 — zindan üretimi testleri: aynı seed aynı harita, oda sayıları, her odaya ulaşılabilirlik, şablonlar,
## düşman sayıları, kapı kilitleme ve oda akışı (DungeonRun + RoomController).
extends "res://tests/test_case.gd"

const SEEDS := 25


func _gen(floor_i: int, seed_v: int) -> DungeonLayout:
	return DungeonGenerator.generate(floor_i, seed_v)


func test_same_seed_same_map() -> void:
	for f: int in range(1, 5):
		for s: int in [1, 77, 123456]:
			assert_eq(_gen(f, s).signature(), _gen(f, s).signature(), "kat %d seed %d aynı harita" % [f, s])
	assert_true(_gen(1, 1).signature() != _gen(1, 2).signature(), "farklı seed farklı harita")
	assert_true(_gen(1, 5).signature() != _gen(2, 5).signature(), "farklı kat farklı harita")


func test_floor_seeds_differ_per_floor() -> void:
	GameState.run_seed = 42
	assert_true(GameState.floor_seed(1) != GameState.floor_seed(2))
	assert_eq(GameState.floor_seed(3), GameState.floor_seed(3))


## GDD Run Süresi: oda sayısı (boss dahil) 8 / 9 / 10 / 11; Ekonomi ve Oda Tipleri: tip başına adetler.
func test_room_counts_match_gdd() -> void:
	var rt: Dictionary = DataDB.table("floors")["room_types"]
	var min_combat := int(DataDB.table("dungeon")["min_combat_rooms"])
	var secret_seen := false
	for f: int in range(1, 5):
		var want := int(DataDB.table("floors")["floors"][str(f)]["rooms"])
		for s: int in SEEDS:
			var L := _gen(f, s)
			var counted := 0
			for r: DungeonLayout.Room in L.rooms:
				if r.type != "start" and r.type != "secret":
					counted += 1
			var tag := "kat %d seed %d" % [f, s]
			assert_eq(counted, want, tag + ": oda sayısı (boss dahil)")
			assert_eq(L.count_type("start"), 1, tag + ": giriş")
			assert_eq(L.count_type("boss"), 1, tag + ": boss")
			assert_eq(L.count_type("merchant"), 1, tag + ": tüccar")
			assert_eq(L.count_type("blacksmith"), 1, tag + ": demirci")
			for t: String in ["elite", "chest", "secret"]:
				var r2: Array = rt[t]["per_floor"]
				var n := L.count_type(t)
				assert_true(n >= int(r2[0]) and n <= int(r2[1]), "%s: %s sayısı %d aralık dışında" % [tag, t, n])
			assert_true(L.count_type("combat") >= min_combat, tag + ": en az %d savaş odası" % min_combat)
			if L.count_type("secret") > 0:
				secret_seen = true
	assert_true(secret_seen, "en az bir haritada gizli oda çıkmalı")


## Her oda (ve her odanın tüm boş zemini) girişten yürünerek ulaşılabilir; gizli oda yalnızca duvar kırılınca.
func test_every_room_reachable() -> void:
	for f: int in range(1, 5):
		for s: int in SEEDS:
			var L := _gen(f, s)
			var start := L.rooms[L.start_id].center()
			var closed := L.reachable_from(start, false)
			var open := L.reachable_from(start, true)
			var tag := "kat %d seed %d" % [f, s]
			for r: DungeonLayout.Room in L.rooms:
				var reach := open if r.type == "secret" else closed
				var missing := 0
				for c: Vector2i in r.free_cells():
					if not reach.has(c):
						missing += 1
				assert_eq(missing, 0, "%s: oda %d (%s) %d karoya ulaşılamıyor" % [tag, r.id, r.type, missing])
				if r.type == "secret":
					assert_true(not closed.has(r.center()), tag + ": gizli oda duvar kırılmadan ulaşılabilir olmamalı")


## Boss odası ana yolun sonunda, tek girişli, girişe bitişik değil; elit en az 2 oda derinde.
func test_boss_and_elite_placement() -> void:
	for f: int in range(1, 5):
		for s: int in SEEDS:
			var L := _gen(f, s)
			var tag := "kat %d seed %d" % [f, s]
			var boss := L.rooms[L.boss_id]
			assert_eq(L.neighbors(L.boss_id).size(), 1, tag + ": boss odasının tek kapısı olmalı")
			assert_true(boss.on_main_path and boss.depth >= 2, tag + ": boss ana yolun sonunda")
			for r: DungeonLayout.Room in L.rooms:
				if r.type == "elite":
					assert_true(r.depth >= 2, tag + ": elit en az 2 oda derinde")
				if r.type != "boss" and r.type != "secret":
					assert_true(r.depth <= boss.depth + 3, tag + ": oda derinliği makul")


## Kapı ağızları koridor zemini, engelsiz; kapı yolunda ve oda ortasında engel yok; duvarlar zeminle çakışmaz.
func test_doors_obstacles_and_walls() -> void:
	for f: int in range(1, 5):
		for s: int in 10:
			var L := _gen(f, s)
			var tag := "kat %d seed %d" % [f, s]
			for r: DungeonLayout.Room in L.rooms:
				for nid: Variant in r.doors.keys():
					var mouth: Array = r.doors[nid]
					assert_eq(mouth.size(), 3, tag + ": kapı 3 karo genişliğinde")
					for c: Vector2i in mouth:
						var ok := L.floor_cells.has(c) or L.secret_floor.has(c) or c in L.secret_wall_cells
						assert_true(ok, "%s: oda %d kapı ağzı %s zemin değil" % [tag, r.id, c])
						assert_true(not r.cells.has(c), tag + ": kapı ağzı odanın dışında")
				for c: Vector2i in r.obstacles.keys():
					assert_true(r.cells.has(c), tag + ": engel oda zemininde")
			var walls := {}
			for c: Vector2i in L.wall_cells(true):
				walls[c] = true
			var overlap := 0
			for c: Vector2i in L.visible_floor(true).keys():
				if walls.has(c):
					overlap += 1
			assert_eq(overlap, 0, tag + ": duvar ve zemin çakışmamalı")
			if L.secret_id >= 0:
				assert_eq(L.secret_wall_cells.size(), 3, tag + ": çatlak duvar 3 karo")


## GDD: 6-8 elle çizilmiş oda şablonu; her şablon 8 döndürme/aynalamada tek parça (engeller dahil).
func test_templates() -> void:
	var dg: Dictionary = DataDB.table("dungeon")
	var combat_pool: Array = dg["template_pools"]["combat"]
	assert_true(combat_pool.size() >= 6 and combat_pool.size() <= 8, "savaş odası şablonu 6-8 arası (bulunan %d)" % combat_pool.size())
	for tid: String in DataDB.records(dg["templates"]):
		for sym: int in 8:
			var shape := DungeonGenerator.template_cells(dg["templates"][tid]["rows"], sym)
			var free := {}
			for c: Vector2i in shape["floor"]:
				free[c] = true
			var first: Vector2i = (shape["floor"] as Array)[0]
			var seen := {first: true}
			var queue: Array[Vector2i] = [first]
			while not queue.is_empty():
				var c: Vector2i = queue.pop_back()
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if free.has(c + d) and not seen.has(c + d):
						seen[c + d] = true
						queue.append(c + d)
			assert_eq(seen.size(), free.size(), "şablon %s (simetri %d) tek parça olmalı" % [tid, sym])
			var size: Vector2i = shape["size"]
			for c: Vector2i in shape["floor"]:
				assert_true(c.x >= 0 and c.y >= 0 and c.x < size.x and c.y < size.y, "şablon %s karo sınır içinde" % tid)


## Katın düşman sayıları floors.json ile birebir (XP eğrisi bu sayılara göre ayarlı).
func test_enemy_counts_match_floor_data() -> void:
	for f: int in range(1, 5):
		var fl: Dictionary = DataDB.table("floors")["floors"][str(f)]
		for s: int in 10:
			var L := _gen(f, s)
			var normal := 0
			var elites := 0
			var bosses := 0
			for r: DungeonLayout.Room in L.rooms:
				for w: Array in r.waves:
					assert_true(not w.is_empty(), "boş dalga olmamalı")
					for spec: Dictionary in w:
						if bool(spec["boss"]):
							bosses += 1
							assert_true(str(spec["boss_id"]) in (fl["boss_pool"] as Array), "boss kat havuzundan")
						elif bool(spec["elite"]):
							elites += 1
						else:
							normal += 1
				if r.type in ["start", "merchant", "blacksmith", "chest", "secret"]:
					assert_true(r.waves.is_empty(), "%s odasında düşman olmamalı" % r.type)
			var tag := "kat %d seed %d" % [f, s]
			assert_eq(normal, int(fl["expected_normal_enemies"]), tag + ": normal düşman sayısı")
			assert_eq(elites, int(fl["expected_elites"]), tag + ": elit sayısı")
			assert_eq(bosses, 1, tag + ": bir boss")


func test_enemy_mult_override() -> void:
	var L := DungeonGenerator.generate(1, 3, 0.5)
	var normal := 0
	for r: DungeonLayout.Room in L.rooms:
		for w: Array in r.waves:
			for spec: Dictionary in w:
				if not bool(spec["elite"]) and not bool(spec["boss"]):
					normal += 1
	assert_eq(normal, 30, "çarpan 0,5 ile 60 → 30")


## GDD: slot değişimi yalnızca oda dışında.
func test_slot_change_rule() -> void:
	GameState.set_in_combat(false)
	assert_true(GameState.can_change_slots(), "savaş dışında serbest")
	GameState.set_in_combat(true)
	assert_true(not GameState.can_change_slots(), "savaşta kapalı")
	GameState.set_in_combat(false)


## Oda akışı: içeri girince kapılar kilitlenir, dalgalar gelir, son dalga ölünce kapılar açılır.
func test_room_flow_locks_and_unlocks() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var run := DungeonRun.new()
	run.fixed_seed = 99
	run.god = true
	tree.root.add_child(run)
	var L := run.layout
	assert_true(L != null, "zindan kuruldu")
	assert_eq(GameState.floor_index, 1)
	var rid := -1
	for r: DungeonLayout.Room in L.rooms:
		if r.type == "combat":
			rid = r.id
			break
	var info := L.rooms[rid]
	var rc := run.room_controller(rid)
	# Oyuncuyu odanın ortasına koy
	run.player.global_position = run.cell_to_world(info.center())
	run._track_room()
	assert_eq(rc.state, RoomController.State.ACTIVE, "oda devrede")
	assert_true(GameState.in_combat, "savaş başladı")
	var door: Vector2i = (info.doors.values()[0] as Array)[0]
	assert_eq(run.wall_layer.get_cell_atlas_coords(door), IsoTileset.DOOR, "kapı kilitli")
	var guard := 0
	while rc.state == RoomController.State.ACTIVE and guard < 50:
		guard += 1
		rc._process(3.0)
		for e: Node2D in rc.alive:
			if is_instance_valid(e) and not e.get("dead"):
				e.call("execute", Vector2.RIGHT)
		rc._process(0.1)
	assert_eq(rc.state, RoomController.State.CLEARED, "oda temizlendi")
	assert_eq(rc.wave_index + 1, info.waves.size(), "tüm dalgalar geldi")
	assert_true(not GameState.in_combat, "savaş bitti")
	assert_eq(run.wall_layer.get_cell_source_id(door), -1, "kapı açıldı")
	# Düşmansız oda girince temizlenir
	for r: DungeonLayout.Room in L.rooms:
		if r.type == "merchant":
			run.player.global_position = run.cell_to_world(r.center())
			run._track_room()
			assert_eq(run.room_controller(r.id).state, RoomController.State.CLEARED, "tüccar odası savaş dışı")
	run.free()
	for n: Node in tree.get_nodes_in_group("enemies"):
		n.free()
	GameState.reset_run()


## Boss kesilince merdiven çıkar ve bir alt kata inilir; yeni katın haritası farklıdır.
func test_boss_kill_opens_stairs_and_next_floor() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var run := DungeonRun.new()
	run.fixed_seed = 5
	tree.root.add_child(run)
	var L := run.layout
	var boss_info := L.rooms[L.boss_id]
	var rc := run.room_controller(L.boss_id)
	run.player.global_position = run.cell_to_world(boss_info.center() + Vector2i(0, 4))
	run.player.hp = 10.0
	run._track_room()
	rc._process(3.0)
	assert_eq(rc.alive.size(), 1, "tek boss")
	var boss := rc.alive[0]
	assert_true(bool(boss.get("is_boss")), "boss işaretli")
	boss.call("execute", Vector2.RIGHT)
	rc._process(0.1)
	assert_eq(run.player.hp, run.player.max_hp, "boss sonrası can tamamen dolar")
	var bw := run.drops.filter(func(d: LootDrop) -> bool: return d.kind == "weapon")
	assert_eq(bw.size(), 1, "boss kesilince 1 silah düşer (Aşama 5 kullanıcı kararı)")
	var stairs: RoomProp = null
	for p: RoomProp in run.props:
		if is_instance_valid(p) and p.kind == "stairs":
			stairs = p
	assert_true(stairs != null, "merdiven çıktı")
	run.player.global_position = stairs.global_position
	var sig := L.signature()
	assert_true(run.try_interact(), "merdivenle etkileşim")
	assert_eq(GameState.floor_index, 2, "2. kata inildi")
	assert_true(run.layout.signature() != sig, "yeni kat yeni harita")
	run.free()
	for n: Node in tree.get_nodes_in_group("enemies"):
		n.free()
	GameState.reset_run()


## Çatlak duvara 3 vuruş: gizli oda açılır, çatlak duvar karoları zemin olur.
func test_secret_wall_breaks() -> void:
	var seed_v := -1
	for s: int in 200:
		GameState.run_seed = s
		if DungeonGenerator.generate(1, GameState.floor_seed(1)).secret_id >= 0:
			seed_v = s
			break
	assert_true(seed_v >= 0, "gizli odalı seed bulundu")
	var tree := Engine.get_main_loop() as SceneTree
	var run := DungeonRun.new()
	run.fixed_seed = seed_v
	tree.root.add_child(run)
	var L := run.layout
	assert_true(L.secret_id >= 0, "gizli oda var")
	var wall: Vector2i = L.secret_wall_cells[1]
	assert_eq(run.wall_layer.get_cell_atlas_coords(wall), IsoTileset.CRACKED, "çatlak duvar çizili")
	var inner: Vector2i = L.rooms[L.secret_host_id].door_inner[L.secret_id]
	var d := wall - inner
	run.player.global_position = run.cell_to_world(inner - d)
	run.player.facing_cart = Iso.to_cart(run.cell_to_world(wall) - run.player.global_position).normalized()
	for i: int in 3:
		run.player.next_attack_id()
		run._secret_hit_cd = 0.0
		run._check_secret_wall()
	assert_true(run.secrets_open, "3 vuruşta kırıldı")
	assert_eq(run.wall_layer.get_cell_source_id(wall), -1, "duvar kalktı")
	assert_true(L.walkable(true).has(wall), "geçit yürünebilir")
	run.free()
	GameState.reset_run()
