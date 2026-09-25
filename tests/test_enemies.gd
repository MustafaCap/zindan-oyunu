## Aşama 7 — düşmanlar ve boss'lar: 55 düşman (17 temel + 17 elit + 21 varyant), kat ölçeklemesi, elitler ve auralar,
## malzeme varyantları, dalga üretimi (sürüler, destek sınırı, elitler, gerçek boss), uyarı işaretli tehlikeler,
## Demir Muhafız'ın kalkanı, çağrılanların ödülsüz olması ve 4 boss'un mekanikleri.
extends "res://tests/test_case.gd"

const FakeTarget := preload("res://tests/fake_target.gd")


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _enemy(id: String, floor_i: int = 1, elite: bool = false, material: String = "") -> Enemy:
	var e := Enemy.new()
	e.enemy_id = id
	e.floor_index = floor_i
	e.is_elite = elite
	e.material_id = material
	e.elite_aura = "fortify" if elite else ""
	_tree().root.add_child(e)
	return e


func _cleanup() -> void:
	for n: Node in _tree().get_nodes_in_group("enemies") + _tree().get_nodes_in_group("enemy_hazards"):
		n.free()


# --- veri ---

func test_fifty_five_enemies() -> void:
	var t: Dictionary = DataDB.table("enemies")
	var base: Array = DataDB.records(t["enemies"])
	var variants: Array = DataDB.records(t["variants"])
	assert_eq(base.size(), 17, "17 temel düşman")
	assert_eq(variants.size(), 21, "21 malzeme varyantı")
	assert_eq(base.size() * 2 + variants.size(), 55, "17 + 17 elit + 21 varyant = 55 (GDD)")
	var roles := {}
	for id: String in base:
		roles[str(t["enemies"][id]["role"])] = true
	assert_eq(roles.keys().size(), 5, "5 rol: yakın, uzak, sürü, tank, destek")
	# Her katın havuzu yalnızca bilinen düşman/varyant içerir ve katın 4-5 temel düşmanı hepsi havuzda
	for f: int in range(1, 5):
		var fl: Dictionary = DataDB.table("floors")["floors"][str(f)]
		var ids: Array = (fl["spawn_pool"] as Array).map(func(e: Array) -> String: return str(e[0]))
		for bid: Variant in fl["enemy_pool"]:
			assert_true(str(bid) in ids, "%d. kat havuzunda %s var" % [f, bid])
	# Tüm varyantlar bir katın havuzunda kullanılır
	var used := {}
	for f2: int in range(1, 5):
		for e2: Array in DataDB.table("floors")["floors"][str(f2)]["spawn_pool"]:
			used[str(e2[0])] = true
	for v: String in variants:
		assert_true(used.has(v), "varyant %s bir katta çıkar" % v)


func test_floor_scaling_and_elite() -> void:
	var sc: Dictionary = DataDB.table("enemies")["floor_scaling"]
	var st: Dictionary = Enemy.record("skeleton_warrior")["stats"]
	var e1 := _enemy("skeleton_warrior", 1)
	var e3 := _enemy("skeleton_warrior", 3)
	assert_almost(e1.max_hp, float(st["hp"]), 0.01, "1. kat temel can")
	assert_almost(e3.max_hp, float(st["hp"]) * float(sc["3"]["hp"]), 0.01, "3. kat can ölçeklenir")
	assert_almost(e3.damage, float(st["damage"]) * float(sc["3"]["damage"]), 0.01, "3. kat hasar ölçeklenir")
	var el := _enemy("skeleton_warrior", 1, true)
	var ed: Dictionary = DataDB.table("enemies")["elite"]
	assert_almost(el.max_hp, float(st["hp"]) * float(ed["hp_mult"]), 0.01, "elit ×3 can")
	assert_almost(el.damage, float(st["damage"]) * float(ed["damage_mult"]), 0.01, "elit ×1,5 hasar")
	assert_true(el.display_name.begins_with("Elit "), "elit adı")
	assert_true(el.is_in_group("elite_aura"), "elit aura taşır")
	var rat := _enemy("cave_rat", 1, true)
	assert_almost(rat.max_hp, float(Enemy.record("cave_rat")["stats"]["hp"]) * float(Enemy.record("cave_rat")["elite_hp_mult"]), 0.01, "sürü eliti daha dayanıklı")
	# Kalkan aurası: yakındaki dost %30 az hasar alır
	rat.elite_aura = "haste"
	e1.global_position = el.global_position + Vector2(20, 0)
	e1._tick_aura(1.0)
	assert_almost(e1.modify_incoming(100.0, {}), 70.0, 0.01, "Kalkan aurası %30 azaltır")
	_cleanup()


func test_material_variants_merge_immunities() -> void:
	var vm := Enemy.resolve_variant("fire_spore_beetle")
	assert_eq(vm, ["spore_beetle", "fire_elemental"])
	var e := _enemy(str(vm[0]), 3, false, str(vm[1]))
	assert_true("poison" in e.defense.immune and "fire" in e.defense.immune, "zehir + ateş bağışık")
	assert_true(not "fire" in e.defense.weak, "bağışık olunan element zayıflıktan düşer")
	assert_true("ice" in e.defense.weak, "Alevli: buza zayıf")
	assert_true(e.display_name.begins_with("Alevli "), "ad önekli")
	var g := _enemy("iron_guard", 4, false, "ghost")
	assert_true("physical" in g.defense.immune and "lightning" in g.defense.immune)
	_cleanup()


func test_waves_packs_support_cap_elites_and_real_boss() -> void:
	var rng := RandomNumberGenerator.new()
	for f: int in range(1, 5):
		var fl: Dictionary = DataDB.table("floors")["floors"][str(f)]
		for s: int in 20:
			rng.seed = s * 31 + f
			var w := DungeonGenerator.wave(8, fl["spawn_pool"], rng)
			assert_eq(w.size(), 8, "dalga boyu korunur")
			var support := 0
			for spec: Dictionary in w:
				assert_true(not Enemy.record(str(spec["id"])).is_empty(), "bilinen düşman")
				if str(Enemy.record(str(spec["id"]))["role"]) == "support":
					support += 1
			assert_true(support <= 1, "dalgada en fazla 1 destek düşmanı")
		var el := DungeonGenerator.elite_spec(fl, rng)
		assert_true(str(el["id"]) in (fl["enemy_pool"] as Array), "elit katın temel düşmanı")
		assert_true(DataDB.table("enemies")["elite_auras"].has(str(el["aura"])), "elitin aurası var")
		var L := DungeonGenerator.generate(f, 1000 + f)
		var boss: Dictionary = L.rooms[L.boss_id].waves[0][0]
		assert_true(bool(boss["boss"]) and str(boss["id"]) == str(boss["boss_id"]), "gerçek boss")
		assert_true(str(boss["boss_id"]) in (fl["boss_pool"] as Array))


# --- tehlikeler ve saldırılar ---

func test_hazard_shapes_and_warn() -> void:
	var h := EnemyHazard.new()
	h.shape = "rect"
	h.dir_cart = Vector2.RIGHT
	h.length = 5.0
	h.width = 1.0
	_tree().root.add_child(h)
	h.global_position = Vector2.ZERO
	assert_true(h.contains(Iso.to_screen(Vector2(3, 0) * Iso.KARO)), "şeridin içinde")
	assert_true(not h.contains(Iso.to_screen(Vector2(3, 1.2) * Iso.KARO)), "şeridin dışında")
	h.shape = "arc"
	h.radius = 3.0
	h.arc_degrees = 90.0
	assert_true(h.contains(Iso.to_screen(Vector2(2, 0.5) * Iso.KARO)), "dilimin içinde")
	assert_true(not h.contains(Iso.to_screen(Vector2(-2, 0) * Iso.KARO)), "dilimin arkası dışarıda")
	h.free()
	# Oyuncu uyarı bitmeden hasar almaz, bitince alır
	var p := Player.new()
	_tree().root.add_child(p)
	var c := EnemyHazard.new()
	c.radius = 1.5
	c.warn = 0.8
	c.damage = 30.0
	_tree().root.add_child(c)
	c.global_position = p.global_position
	var hp0 := p.hp
	c._physics_process(0.5)
	assert_eq(p.hp, hp0, "uyarı sürerken hasar yok")
	c._physics_process(0.4)
	assert_true(p.hp < hp0, "uyarı bitince vurur")
	p.free()
	_cleanup()


func test_enemy_attacks_hit_and_slow_player() -> void:
	var p := Player.new()
	p.race_id = "warrior"
	_tree().root.add_child(p)
	var e := _enemy("skeleton_warrior")
	e.global_position = p.global_position + Iso.to_screen(Vector2(0.8, 0) * Iso.KARO)
	e.target = p
	e.facing_cart = Vector2.LEFT
	e._begin_attack()
	var hp0 := p.hp
	e._execute_action()
	assert_true(p.hp < hp0, "yakın yay vurur")
	# Feryatçı: çığlık yavaşlatır
	p.iframes = 0.0
	var w := _enemy("wailer", 4)
	w.global_position = p.global_position + Iso.to_screen(Vector2(3, 0) * Iso.KARO)
	w.target = p
	w.facing_cart = Vector2.LEFT
	w._begin_attack()
	w._execute_action()
	assert_true(p.slow_t > 0.0 and p.slow_amount > 0.3, "çığlık yavaşlatır")
	p.free()
	_cleanup()


func test_iron_guard_shield_blocks_front() -> void:
	var p := Player.new()
	p.race_id = "warrior"
	_tree().root.add_child(p)
	var g := _enemy("iron_guard", 3)
	g.global_position = p.global_position + Iso.to_screen(Vector2(1.0, 0) * Iso.KARO)
	g.facing_cart = Vector2.LEFT   # oyuncuya dönük
	var w := Weapon.make("sword", "common")
	var hp0 := g.hp
	var res := p.deal_hit(g, w, "light", 1.0, p.next_attack_id())
	assert_true(bool(res.get("blocked", false)), "önden vuruş engellenir")
	assert_eq(g.hp, hp0, "hasar yok")
	g.facing_cart = Vector2.RIGHT  # arkası dönük
	p.deal_hit(g, w, "light", 1.0, p.next_attack_id())
	assert_true(g.hp < hp0, "arkadan vuruş işler")
	g.facing_cart = Vector2.LEFT
	g.status.stun(1.0, 1.0, 0.3)
	var hp1 := g.hp
	p.deal_hit(g, w, "light", 1.0, p.next_attack_id())
	assert_true(g.hp < hp1, "sersemken kalkan iner")
	p.free()
	_cleanup()


func test_summons_give_no_reward() -> void:
	var run := DungeonRun.new()
	run.fixed_seed = 3
	_tree().root.add_child(run)
	GameState.xp = 0.0
	var owner := _enemy("void_summoner", 1)
	owner.floor_index = GameState.floor_index
	var s := run.spawn_add("shade", run.player.global_position + Vector2(200, 0), owner) as Enemy
	assert_true(s.no_reward, "çağrılan ödülsüz")
	var xp0 := GameState.xp
	var kills0 := GameState.kills
	s.execute(Vector2.RIGHT)
	assert_eq(GameState.xp, xp0, "çağrılan XP vermez")
	assert_eq(GameState.kills, kills0, "öldürme sayılmaz")
	assert_eq(run.drops.size(), 0, "altın düşmez")
	var s2 := run.spawn_add("shade", run.player.global_position + Vector2(-200, 0), owner) as Enemy
	owner.summons.append(s2)
	owner.execute(Vector2.RIGHT)
	assert_true(s2.dead, "çağıran ölünce dağılır")
	run.free()
	_cleanup()
	GameState.reset_run()


# --- boss'lar ---

func _boss_run(floor_i: int) -> Array:
	var run := DungeonRun.new()
	run.fixed_seed = 21
	_tree().root.add_child(run)
	run.enter_floor(floor_i)
	var L := run.layout
	var spec: Dictionary = L.rooms[L.boss_id].waves[0][0]
	var boss := run.spawn_enemy(spec, L.rooms[L.boss_id].center()) as Boss
	boss.target = run.player
	return [run, boss]


func test_boss_classes_and_phase2() -> void:
	for f: int in range(1, 5):
		var rb := _boss_run(f)
		var run: DungeonRun = rb[0]
		var boss: Boss = rb[1]
		var bid := str(DataDB.table("floors")["floors"][str(f)]["boss_pool"][0])
		assert_eq(boss.boss_id, bid, "%d. kat boss'u" % f)
		assert_almost(boss.max_hp, float(DataDB.table("bosses")["bosses"][bid]["stats"]["hp"]), 0.01, "boss canı veriden")
		assert_eq(run.hud.boss, boss, "boss can barı")
		assert_eq(boss.attack_log.size(), 3, "3 saldırı")
		for id: String in boss.attack_log.keys():
			assert_true(boss.start_attack(id) > 0.0, "%s saldırısı başlar" % id)
		boss.hp = boss.max_hp * 0.49
		boss._physics_process(0.016)
		assert_eq(boss.phase, 2, "%50 altında 2. faz" )
		run.free()
		_cleanup()
		GameState.reset_run()


func test_morvath_eyelid() -> void:
	var rb := _boss_run(1)
	var run: DungeonRun = rb[0]
	var m: Morvath = rb[1]
	assert_almost(m.modify_incoming(100.0, {}), 100.0, 0.01, "açıkken normal hasar")
	m._close()
	assert_eq(m.modify_incoming(100.0, {}), 0.0, "kapalıyken hasar almaz")
	var eyes := m.alive_minions("wall_eye")
	assert_eq(eyes.size(), 3, "duvarda 3 göz")
	var hp0 := float(eyes[0].get("hp"))
	m.modify_incoming(100.0, {"kind": "lightning"})
	assert_almost(float(eyes[0].get("hp")), hp0 - 50.0, 0.01, "yıldırımın %50'si gözlere sıçrar")
	for e: Node2D in eyes:
		e.call("execute", Vector2.RIGHT)
	m.tick_mechanic(0.016)
	assert_true(not m.closed, "gözler kırılınca kapak açılır")
	assert_almost(m.modify_incoming(100.0, {}), 150.0, 0.01, "6 sn +%50 hasar")
	run.free()
	_cleanup()
	GameState.reset_run()


func test_kordrak_cooling() -> void:
	var rb := _boss_run(3)
	var run: DungeonRun = rb[0]
	var k: Kordrak = rb[1]
	assert_almost(k.defense.armor, 0.7, 0.001, "plakalar %70 azaltır")
	for i: int in 5:
		k.modify_incoming(10.0, {"kind": "ice"})
	assert_eq(k.defense.armor, 0.0, "5 buz yığınında plakalar kırılır")
	k.tick_mechanic(10.5)
	assert_almost(k.defense.armor, 0.7, 0.001, "10 sn sonra plakalar döner")
	k.enter_phase2()
	assert_eq(k.defense.armor, 0.0, "2. fazda plakalar kalıcı düşer")
	run.free()
	_cleanup()
	GameState.reset_run()


func test_mycela_totems_and_fire_burst() -> void:
	var rb := _boss_run(2)
	var run: DungeonRun = rb[0]
	var my: Mycela = rb[1]
	my._plant_totems()
	my._time += 2.0
	my._run_schedule()
	assert_eq(my.alive_minions("spore_totem").size(), 3, "3 totem dikildi")
	my.hp = my.max_hp * 0.6
	var hp0 := my.hp
	my.tick_mechanic(1.0)
	assert_true(my.hp > hp0, "totemler iyileştirir")
	# Ateş mermisi bulutu patlatır
	var cloud := my.hazard("spore_cloud", my.global_position, "circle", 0.0, 0.1, {"mode": "zone", "radius": 1.6, "duration": 5.0})
	cloud._t = 0.1
	my._clouds.append(cloud)
	var pr := Projectile.new()
	pr.weapon = Weapon.make("staff", "rare", "fire")
	pr.player = run.player
	run.world.add_child(pr)
	pr.global_position = my.global_position
	var hp1 := my.hp
	my._check_fire_on_clouds()
	assert_true(my._clouds.is_empty(), "bulut yok oldu")
	assert_true(my.hp < hp1, "Zehir Patlaması Mycela'ya vurur")
	pr.free()
	run.free()
	_cleanup()
	GameState.reset_run()


func test_nyxthar_torches_and_abyss() -> void:
	var rb := _boss_run(4)
	var run: DungeonRun = rb[0]
	var n: Nyxthar = rb[1]
	assert_eq(n.torches.size(), 6, "6 meşale")
	assert_true(n.in_light(n.torches[0]["pos"]), "meşale yanında ışık")
	assert_true(not n.in_light(n.arena.center), "merkez karanlık")
	n.torches[0]["lit"] = false
	var pr := Projectile.new()
	pr.weapon = Weapon.make("staff", "rare", "fire")
	pr.player = run.player
	run.world.add_child(pr)
	pr.global_position = n.torches[0]["pos"]
	n.tick_mechanic(0.016)
	assert_true(bool(n.torches[0]["lit"]), "ateş meşaleyi yakar")
	# Söndürme en az 2 meşaleyi yanık bırakır
	for t: Dictionary in n.torches:
		t["lit"] = false
	n.torches[0]["lit"] = true
	n.torches[1]["lit"] = true
	n._extinguish_t = 0.0
	pr.free()
	n.tick_mechanic(0.016)
	var warned := n.torches.filter(func(t: Dictionary) -> bool: return float(t["warn_t"]) > 0.0).size()
	assert_eq(warned, 0, "2 meşale kalınca söndürmez")
	n.enter_phase2()
	n._collapse_warn_t = 0.0
	assert_true(n.in_abyss(n.arena.point(Vector2(n.arena.radius - 0.5, 0))), "kenar uçurum oldu")
	assert_true(not n.in_abyss(n.arena.center), "merkez güvenli")
	run.free()
	_cleanup()
	GameState.reset_run()
