## Aşama 6 — ilerleme: oyuncu XP'si ve leveli (kat XP toplamları hedef levellere birebir), level/boss ödülleri, stat
## tavanları, silah tipi ustalığı (114 referans maç, derinlik çarpanı, hasar payı), boss özel etkileri, run sonu kaydı.
extends "res://tests/test_case.gd"

const FakeTarget := preload("res://tests/fake_target.gd")
const SaveScript := preload("res://scripts/autoload/save_manager.gd")
const NO_CRIT := {"crit_bonus_chance": -1.0}
const TARGETS := [15, 35, 55, 80]

var _world: Node2D


func before_each() -> void:
	_world = Node2D.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(_world)


func after_each() -> void:
	_world.free()
	GameState.reset_run()
	(Engine.get_main_loop() as SceneTree).paused = false


func _player(race: String, w: Weapon, level: int = 1) -> Player:
	var p := Player.new()
	p.race_id = race
	p.level = level
	p.weapons = [w]
	_world.add_child(p)
	return p


func _target(pos_tiles: Vector2 = Vector2(1, 0), hp: float = 100000.0, boss: bool = false) -> Node2D:
	var t: Node2D = FakeTarget.new()
	t.setup(hp, boss)
	_world.add_child(t)
	t.add_to_group("enemies")
	t.global_position = Iso.to_screen(pos_tiles * Iso.KARO)
	return t


# --- oyuncu XP'si ve leveli ---

func test_xp_curve_formula() -> void:
	assert_eq(Leveling.xp_to_next(1), 120.0, "100 + 20 × 1")
	assert_eq(Leveling.xp_to_next(10), 300.0)
	var r := Leveling.apply(1, 0.0, 120.0 + 140.0 + 50.0)
	assert_eq(r["level"], 3, "iki level atlanır")
	assert_almost(float(r["xp"]), 50.0, 0.0001, "artan XP bir sonraki levele")
	assert_eq(r["levels"], [2, 3] as Array[int])
	var m := Leveling.apply(79, 0.0, 1000000.0)
	assert_eq(m["level"], 80, "maks level 80")
	assert_eq(m["xp"], 0.0, "maks levelde XP birikmez")
	assert_eq(Leveling.apply(80, 0.0, 500.0)["levels"], [] as Array[int])


func test_enemy_xp_table_matches_gdd() -> void:
	var want := {1: [40, 150, 800], 2: [120, 500, 2400], 3: [180, 900, 3600], 4: [280, 1800, 7200]}
	for f: int in want.keys():
		assert_eq(Leveling.enemy_xp(f, "normal"), float(want[f][0]), "kat %d normal" % f)
		assert_eq(Leveling.enemy_xp(f, "elite"), float(want[f][1]), "kat %d elit" % f)
		assert_eq(Leveling.enemy_xp(f, "boss"), float(want[f][2]), "kat %d boss" % f)


## Aşama 6 kabulü: üretilen haritalarda katın tüm düşmanları, elitleri ve boss'u kesilirse oyuncu tam olarak katın hedef
## üst levelinde çıkar (1→15, 15→35, 35→55, 55→80); birkaç farklı seed'le.
func test_generated_floors_xp_reaches_level_targets_exactly() -> void:
	for seed_value: int in [1, 42, 777, 2026]:
		var level := 1
		var xp := 0.0
		for f: int in [1, 2, 3, 4]:
			var layout := DungeonGenerator.generate(f, hash([seed_value, f]))
			var counts := {"normal": 0, "elite": 0, "boss": 0}
			for r: DungeonLayout.Room in layout.rooms:
				for wave: Variant in r.waves:
					for spec: Dictionary in wave:
						var kind := "boss" if bool(spec.get("boss", false)) else ("elite" if bool(spec.get("elite", false)) else "normal")
						counts[kind] = int(counts[kind]) + 1
			assert_eq(counts["boss"], 1, "seed %d kat %d: 1 boss" % [seed_value, f])
			var total := 0.0
			for k: String in counts.keys():
				total += int(counts[k]) * Leveling.enemy_xp(f, k)
			var res := Leveling.apply(level, xp, total)
			level = int(res["level"])
			xp = float(res["xp"])
			assert_eq(level, TARGETS[f - 1], "seed %d: %d. kat sonunda level" % [seed_value, f])
			assert_almost(xp, 0.0, 0.0001, "seed %d: %d. kat sonunda artan XP yok" % [seed_value, f])


func test_sixteen_level_rewards_per_run() -> void:
	var n := 0
	for l: int in range(2, Leveling.max_level() + 1):
		if Leveling.is_reward_level(l):
			n += 1
	assert_eq(n, 16, "GDD: run başına 16 level ödülü")


func test_game_state_add_xp_and_xp_gain() -> void:
	var ups: Array[int] = []
	var cb := func(l: int) -> void: ups.append(l)
	Events.level_up.connect(cb)
	var lv := GameState.add_xp(120.0)
	assert_eq(lv, [2] as Array[int])
	assert_eq(GameState.level, 2)
	GameState.buffs["xp_gain"] = 0.5
	GameState.add_xp(100.0)   # ×1,5 = 150 > 140
	assert_eq(GameState.level, 3, "Deneyim kazanımı XP'yi çarpar")
	assert_almost(GameState.xp, 10.0, 0.0001)
	assert_eq(ups, [2, 3] as Array[int], "her level için level_up sinyali")
	Events.level_up.disconnect(cb)


# --- ödüller ---

func test_level_offer_two_distinct_from_pool() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var pool: Dictionary = DataDB.table("rewards")["level_pool"]
	for i: int in 50:
		var o := Rewards.level_offer(rng, {})
		assert_eq(o.size(), 2, "2 seçenek")
		assert_true(str(o[0]["id"]) != str(o[1]["id"]), "farklı")
		for c: Dictionary in o:
			assert_true(pool.has(str(c["id"])) and str(c["kind"]) == "stat")
			assert_eq(float(c["value"]), float(pool[str(c["id"])]["value"]))


func test_capped_stat_leaves_pool() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var totals := {"attack_speed": 1.5, "crit_chance": 0.6, "cooldown_reduction": 0.41}
	for i: int in 200:
		for c: Dictionary in Rewards.level_offer(rng, totals):
			assert_true(not str(c["id"]) in ["attack_speed", "crit_chance", "cooldown_reduction"], "tavandaki stat çıkmaz")
	assert_true(Rewards.is_capped("attack_range", {"attack_range": 0.5}))
	assert_true(not Rewards.is_capped("attack_range", {"attack_range": 0.49}))
	assert_true(not Rewards.is_capped("damage", {"damage": 99.0}), "hasarın tavanı yok")


func test_boss_offer_one_major_one_special() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var majors: Dictionary = DataDB.table("rewards")["boss_major_pool"]
	var taken: Array[String] = ["double_hit", "wrath"]
	for i: int in 100:
		var o := Rewards.boss_offer(rng, {}, taken, "warrior")
		assert_eq(o.size(), 2)
		assert_true(str(o[0]["kind"]) == "stat" and majors.has(str(o[0]["id"])), "biri büyük stat")
		assert_eq(str(o[1]["kind"]), "special", "diğeri özel etki")
		assert_true(not str(o[1]["id"]) in taken, "alınmış özel etki tekrar çıkmaz")
		var g := Rewards.boss_offer(rng, {}, [], "ghost")
		assert_true(str(g[1]["id"]) != "spare_potion", "Ghost'a Yedek iksir sunulmaz")
	# Özel etki kalmadıysa iki büyük stat
	var all: Array[String] = []
	all.assign(DataDB.records(DataDB.table("rewards")["boss_special_pool"]))
	var o2 := Rewards.boss_offer(rng, {}, all, "warrior")
	assert_eq(o2.size(), 2)
	assert_true(str(o2[0]["kind"]) == "stat" and str(o2[1]["kind"]) == "stat")


func test_apply_reward_to_buffs() -> void:
	Rewards.apply({"kind": "stat", "id": "damage", "value": 0.05})
	Rewards.apply({"kind": "stat", "id": "damage", "value": 0.12})
	assert_almost(float(GameState.buffs["damage"]), 0.17, 0.0001, "stat ödülleri toplanır")
	Rewards.apply({"kind": "special", "id": "piercing", "value": 0.0})
	Rewards.apply({"kind": "special", "id": "piercing", "value": 0.0})
	assert_eq(GameState.special_effects, ["piercing"] as Array[String], "özel etki bir kez")
	assert_true(GameState.has_special("piercing"))


# --- stat tavanları ---

func test_stat_caps_apply_to_all_sources() -> void:
	var s := RaceStats.compute("archer", 1, "archer", {"attack_speed": 5.0, "attack_range": 5.0, "damage_reduction": 5.0,
		"cooldown_reduction": 5.0, "dash_cooldown_reduction": 5.0, "crit_chance": 5.0})
	assert_eq(s.attack_speed_bonus, 1.5, "saldırı hızı +%150")
	assert_eq(s.attack_range_bonus, 0.5, "menzil +%50")
	assert_eq(s.armor, 0.75, "hasar azaltma %75")
	assert_eq(s.cooldown_reduction, 0.4, "bekleme azaltma %40")
	assert_eq(s.dash_cooldown_reduction, 0.5, "Space bekleme azaltma %50")
	assert_almost(float(s.totals["attack_range"]), 5.0 + 0.1, 0.0001, "tavansız toplam (Archer pasifi dahil)")
	assert_almost(float(s.totals["crit_chance"]), 0.05 + 0.05 + 5.0, 0.0001, "kritik toplamı temel %5 dahil")
	# Kritik şansı tavanı %60 (HitResolver)
	var p := _player("warrior", Weapon.make("sword", "common"))
	p.rng.seed = 11
	var crits := 0
	for i: int in 2000:
		var t := _target(Vector2(1, 0))
		if bool(p.deal_hit(t, p.weapon(), "light", 1.0, i, {"crit_bonus_chance": 5.0})["crit"]):
			crits += 1
		t.free()
	assert_almost(crits / 2000.0, 0.6, 0.04, "kritik şansı %60'ta durur")


func test_rewards_feed_player_stats() -> void:
	GameState.buffs = {"damage": 0.10, "max_hp": 0.08, "skill_damage": 0.2, "crit_damage": 0.1, "cooldown_reduction": 0.2,
		"move_speed": 0.1, "damage_reduction": 0.05}
	var p := _player("warrior", Weapon.make("sword", "common"))
	var mu := 1.0 + Mastery.bonus(1, "damage")
	assert_almost(p.max_hp, 150.0 * 1.08, 0.001, "maks can ödülü")
	assert_almost(p.stats.armor, 0.20, 0.0001, "hasar azaltma ırk zırhına eklenir")
	assert_almost(p.stats.move_speed_mult, 1.1, 0.0001)
	assert_almost(p.kit.cooldown_for("heavy", "warrior"), 6.0 * 0.8, 0.0001, "bekleme azaltma")
	var r := p.deal_hit(_target(), p.weapon(), "light", 1.0, 1, NO_CRIT)
	assert_almost(float(r["damage"]), 100.0 * mu * 1.10, 0.001, "hasar ödülü B'ye")
	r = p.deal_hit(_target(Vector2(0, 2)), p.weapon(), "heavy", 1.0, 2, NO_CRIT)
	assert_almost(float(r["damage"]), 100.0 * mu * 1.30, 0.001, "skill hasarı yalnızca sağ tık/Q/E")
	# Kritik şansı tavanı %60: kritik gelene kadar dene
	for i: int in 50:
		r = p.deal_hit(_target(Vector2(0, -2)), p.weapon(), "light", 1.0, 3 + i, {"crit_bonus_chance": 5.0})
		if bool(r["crit"]):
			break
	assert_true(bool(r["crit"]))
	assert_almost(float(r["damage"]), 100.0 * mu * 1.10 * 1.6, 0.001, "kritik hasarı 1,5 + %10")


func test_dash_cooldown_reduction_capped_with_feather() -> void:
	GameState.buffs = {"dash_cooldown_reduction": 0.3}
	var p := _player("warrior", Weapon.make("sword", "common"))
	assert_almost(p.dash_cooldown_reduction(), 0.3, 0.0001)
	p.effects.flex = Talisman.make("wind_feather")
	assert_almost(p.dash_cooldown_reduction(), 0.5, 0.0001, "ödül + Rüzgâr Tüyü toplamı %50'de durur")
	assert_almost(float(p.stat_totals()["dash_cooldown_reduction"]), 0.6, 0.0001, "tavansız toplam")


func test_lifesteal_reward_and_ghost_conversion() -> void:
	GameState.buffs = {"lifesteal": 0.1}
	var p := _player("warrior", Weapon.make("sword", "common"))
	p.hp = 20.0
	var r := p.deal_hit(_target(), p.weapon(), "light", 1.0, 1, NO_CRIT)
	assert_almost(p.hp, 20.0 + float(r["damage"]) * 0.1, 0.01, "can emme ödülü")
	var g := _player("ghost", Weapon.make("dagger", "common"))
	g.hp = 10.0
	g.deal_hit(_target(Vector2(0, 2)), g.weapon(), "light", 1.0, 1, NO_CRIT)
	assert_eq(g.hp, 10.0, "Ghost can emmeyle iyileşmez")
	var dummy := _target(Vector2(0, 3))
	Events.enemy_killed.emit(dummy, false, false)
	assert_almost(g.hp, 10.0 + g.max_hp * (0.04 + 0.1), 0.01, "Ghost: öldürme başına %4 + can emme ödülü %10")


# --- ustalık ---

func test_mastery_curve_and_bonuses() -> void:
	assert_eq(Mastery.level_of("sword"), 1, "kayıt yoksa level 1")
	assert_almost(Mastery.bonus(6, "damage"), 0.30, 0.0001)
	assert_almost(Mastery.bonus(6, "attack_speed"), 0.20, 0.0001)
	assert_almost(Mastery.bonus(6, "attack_range"), 0.10, 0.0001)
	assert_almost(Mastery.bonus(6, "element_damage"), 0.15, 0.0001)
	assert_almost(Mastery.bonus(12, "damage"), 0.60, 0.0001)
	# Aşama 6 kabulü: 12. levele 114 referans maç (her biri 100 XP)
	var e := {"level": 1, "xp": 0.0}
	var matches := 0
	while int(e["level"]) < 12 and matches < 1000:
		Mastery.add_xp(e, 100.0)
		matches += 1
	assert_eq(matches, 114, "ustalık 12 için 114 referans maç")
	assert_eq(Mastery.add_xp(e, 5000.0), 0, "maks levelde level atlanmaz")
	assert_eq(e["xp"], 0.0, "maks levelde XP birikmez")
	var steps := {"level": 1, "xp": 0.0}
	var want := [3, 7, 13, 21, 33, 45, 58, 71, 84, 98, 114]
	var m := 0
	for i: int in want.size():
		while int(steps["level"]) < i + 2:
			Mastery.add_xp(steps, 100.0)
			m += 1
		assert_eq(m, want[i], "level %d toplam maç" % (i + 2))


func test_depth_multipliers() -> void:
	assert_eq(Mastery.depth_key(1, false, false), "death_floor_1")
	assert_eq(Mastery.depth_key(2, false, false), "death_floor_2")
	assert_eq(Mastery.depth_key(2, false, true), "clear_floor_2")
	assert_eq(Mastery.depth_key(3, false, true), "death_floor_3")
	assert_eq(Mastery.depth_key(4, false, true), "death_floor_4")
	assert_eq(Mastery.depth_key(4, true, true), "victory")
	var want := {"death_floor_1": 10.0, "death_floor_2": 30.0, "clear_floor_2": 100.0, "death_floor_3": 150.0, "death_floor_4": 200.0, "victory": 300.0}
	for k: String in want.keys():
		assert_almost(Mastery.run_xp(k), float(want[k]), 0.0001, k)


func test_mastery_split_by_damage_share() -> void:
	var parts := Mastery.split({"sword": 700.0, "bow": 300.0}, 100.0)
	assert_almost(float(parts["sword"]), 70.0, 0.0001, "GDD örneği: %70 kılıç")
	assert_almost(float(parts["bow"]), 30.0, 0.0001, "%30 yay")
	assert_eq(Mastery.split({}, 100.0).size(), 0, "hasar yoksa XP yok")
	var sm: Node = SaveScript.new()
	sm.mastery["sword"] = {"level": 1, "xp": 250.0}
	var res := Mastery.apply_run({"sword": 700.0, "bow": 300.0}, "clear_floor_2", sm)
	assert_eq(res.size(), 2)
	assert_eq(str(res[0]["type"]), "sword", "hasar payına göre sıralı")
	assert_eq(int(res[0]["to_level"]), 2, "250 + 70 ≥ 300 → level 2")
	assert_almost(float(sm.mastery["sword"]["xp"]), 20.0, 0.0001)
	assert_almost(float(sm.mastery["bow"]["xp"]), 30.0, 0.0001)
	assert_eq(int(sm.mastery["bow"]["level"]), 1)
	sm.free()


func test_mastery_feeds_damage_and_speed() -> void:
	var sm: Node = SaveManager
	sm.mastery["sword"] = {"level": 6, "xp": 0.0}
	var p := _player("warrior", Weapon.make("sword", "common"))
	var r := p.deal_hit(_target(), p.weapon(), "light", 1.0, 1, NO_CRIT)
	assert_almost(float(r["damage"]), 130.0, 0.001, "ustalık 6: +%30 hasar (U)")
	assert_almost(p.attack_interval(), 1.0 / (1.4 * 1.2), 0.0001, "ustalık 6: +%20 saldırı hızı")
	assert_almost(p.attack_range(), 1.5 * 1.1, 0.0001, "ustalık 6: +%10 menzil")
	var bow := _player("warrior", Weapon.make("bow", "common"))
	assert_almost(bow.attack_range(), 9.0 * (1.0 + Mastery.bonus(1, "attack_range")), 0.0001, "ustalık silah tipine bağlı")


# --- boss özel etkileri ---

func test_wrath_and_executioner() -> void:
	assert_almost(Traits.fury_bonus(20, 1.0), 0.06, 0.0001)
	assert_almost(Traits.fury_bonus(20, 1.0, 0.10), 0.10, 0.0001, "Hiddet: Öfke tavanı %10")
	assert_true(not Traits.should_execute(8.0, 100.0, false, 1.0), "%8 canda infaz yok (%7)")
	assert_true(Traits.should_execute(8.0, 100.0, false, 1.0, 0.02), "Cellat: eşik %9")
	assert_true(Traits.should_execute(3.5, 100.0, true, 1.0, 0.01), "Cellat: boss'ta %4")
	assert_true(not Traits.should_execute(1.0, 100.0, false, 0.0, 0.02), "İnfaz yoksa Cellat işlemez")
	# Oyuncu üzerinden: Öfkeli silahla aynı hedefe 15 vuruş → son vuruş +%10
	GameState.special_effects.append("wrath")
	var p := _player("warrior", Weapon.make("sword", "epic", "fire", ["fury"] as Array[String]))
	var t := _target()
	var first := 0.0
	var last := 0.0
	for i: int in 15:
		var r := p.deal_hit(t, p.weapon(), "light", 1.0, i + 1, NO_CRIT)
		if i == 0:
			first = float(r["damage"])
		last = float(r["damage"])
	var mu := 1.0 + Mastery.bonus(1, "damage")
	var el := 1.0 + Mastery.bonus(1, "element_damage")
	assert_almost(first, 175.0 * mu * el, 0.01, "ilk vuruş öfkesiz")
	assert_almost(last, 175.0 * mu * 1.10 * el, 0.01, "Hiddet: öfke %10'a çıkar")


func test_resonance_boost() -> void:
	var p := _player("warrior", Weapon.make("sword", "common"), 10)
	p.effects.resonance = Weapon.make("staff", "rare", "lightning", [], 20)
	assert_almost(p.effects.resonance_pct(), 0.10, 0.0001)
	GameState.special_effects.append("resonance_boost")
	assert_almost(p.effects.resonance_pct(), 0.15, 0.0001, "kilitliyken %15")
	p.set_level(20)
	assert_almost(p.effects.resonance_pct(), 0.10, 0.0001, "açıkken %10")


func test_double_hit_and_crit_chain() -> void:
	GameState.special_effects.append("double_hit")
	var p := _player("warrior", Weapon.make("sword", "common"))
	p.rng.seed = 21
	var doubles := 0
	for i: int in 800:
		var t := _target()
		p.deal_hit(t, p.weapon(), "light", 1.0, i, NO_CRIT)
		if (t.get("hits") as Array).size() == 2:
			doubles += 1
		t.free()
	assert_almost(doubles / 800.0, 0.25, 0.05, "Çift vuruş %25")
	var t2 := _target(Vector2(1, 0), 1.0e9)
	GameState.special_effects.clear()
	GameState.special_effects.append("crit_chain")
	p.kit.cooldowns = {"heavy": 1000.0, "q": 1000.0, "e": 1000.0}
	var crits := 0
	for i: int in 800:
		if bool(p.deal_hit(t2, p.weapon(), "light", 1.0, i, {"crit_bonus_chance": 5.0})["crit"]):
			crits += 1
	var reduced := 1000.0 - float(p.kit.cooldowns["q"])
	assert_almost(reduced / crits, 0.20, 0.05, "Kritik zinciri: kritiklerin %20'si 1 sn azaltır")
	assert_eq(float(p.kit.cooldowns["heavy"]), float(p.kit.cooldowns["e"]), "sağ tık, Q ve E birlikte")


func test_combo_master_boosts_combo_damage() -> void:
	var dmg := {}
	for on: bool in [false, true]:
		GameState.special_effects.clear()
		if on:
			GameState.special_effects.append("combo_master")
		var p := _player("warrior", Weapon.make("sword", "rare", "ice"))
		var t := _target(Vector2(1, 0))
		(t.get("status") as StatusEffects).apply_element("fire", 10.0)
		var r := p.deal_hit(t, p.weapon(), "light", 1.0, 1, NO_CRIT)
		assert_eq(str(r["combo"]), "melt", "Ateş + Buz = Erime")
		var extra := 0.0
		for h: Dictionary in t.get("hits"):
			if bool(h.get("secondary", false)):
				extra += float(h["amount"])
		dmg[on] = extra
		p.free()
		t.free()
	assert_almost(float(dmg[true]) / float(dmg[false]), 1.3, 0.0001, "Kombo ustası: kombo hasarı +%30")


func test_piercing_extra_projectile_and_trail() -> void:
	GameState.special_effects.append("piercing")
	var p := _player("archer", Weapon.make("bow", "common"))
	var pr := WeaponAttacks.make_projectile(p, p.weapon(), "light", 1.0, 1, Vector2.RIGHT)
	p.spawn(pr, p.global_position)
	assert_eq(pr.pierce, 1, "Delici: 1 düşman deler")
	var orb := WeaponAttacks.make_projectile(p, p.weapon(), "heavy", 1.0, 2, Vector2.RIGHT)
	orb.explode_radius = 2.0
	p.spawn(orb, p.global_position)
	assert_eq(orb.pierce, 0, "patlayan küre değişmez")
	GameState.special_effects.append("extra_projectile")
	var s := _player("warrior", Weapon.make("sword", "common"))
	var before := _count(Projectile)
	WeaponAttacks.light(s)
	var waves := _world.get_children().filter(func(n: Node) -> bool: return n is Projectile and (n as Projectile).kind == "wave")
	assert_eq(_count(Projectile) - before, 1, "Ek mermi: 1 mermi")
	assert_eq(waves.size(), 1, "yakın silahta kılıç dalgası")
	assert_almost((waves[0] as Projectile).skill_mult, 0.3, 0.0001, "%30 hasar")
	GameState.special_effects.append("element_trail")
	var g0 := _count(GroundEffect)
	s._element_trail(Vector2.ZERO, Vector2(200, 0))
	assert_eq(_count(GroundEffect) - g0, 3, "Element izi: 3 parça")


func _count(cls: Variant) -> int:
	var n := 0
	for c: Node in _world.get_children():
		if is_instance_of(c, cls):
			n += 1
	return n


func test_second_chance_revives_once() -> void:
	GameState.special_effects.append("second_chance")
	var p := _player("warrior", Weapon.make("sword", "common"))
	p.take_damage(100000.0, Vector2.LEFT)
	assert_true(not p.dead, "İkinci şans: ölmez")
	assert_almost(p.hp, p.max_hp * 0.3, 0.01, "%30 canla dirilir")
	assert_true(p.iframes > 1.0, "kısa dokunulmazlık")
	p.iframes = 0.0
	p.take_damage(100000.0, Vector2.LEFT)
	assert_true(p.dead, "ikinci kez ölür")


# --- zindan akışı: boss ödülü, ilk kesiş, run sonu kaydı ---

func test_boss_kill_first_kill_reward_and_run_end_save() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var run := DungeonRun.new()
	run.fixed_seed = 99
	tree.root.add_child(run)
	run.enter_floor(2)
	var boss := EnemyMelee.new()
	boss.boss_id = "mycela"
	run._on_boss_killed(run.layout.boss_id, boss)
	assert_true("mycela" in SaveManager.boss_first_kills, "ilk kesiş kaydedildi")
	assert_true(GameState.floor2_cleared)
	assert_eq(GameState.pending_rewards, ["boss:2"] as Array[String], "boss ödülü sırada")
	assert_almost(run.player.stats.damage_buffs, 0.003, 0.00001, "kalıcı +%0,3 hasar")
	# Ödül ekranı: 1 büyük stat + 1 özel etki; seçince işlenir
	GameState.set_in_combat(false)
	run._try_open_reward()
	assert_true(run.reward_ui.visible, "savaş dışında ödül ekranı açılır")
	assert_eq(run.reward_ui.choices.size(), 2)
	var special: Dictionary = run.reward_ui.choices[1]
	run.reward_ui.pick(1)
	assert_true(not run.reward_ui.visible)
	assert_true(GameState.has_special(str(special["id"])), "özel etki alındı")
	assert_true(not tree.paused, "seçimden sonra oyun devam eder")
	# Level ödülü savaşı bölmez
	GameState.set_in_combat(true)
	run.grant_xp(Leveling.xp_between(GameState.level, 5))
	run._try_open_reward()
	assert_true(not run.reward_ui.visible, "savaşta ödül ekranı açılmaz")
	GameState.set_in_combat(false)
	run._try_open_reward()
	assert_true(run.reward_ui.visible, "savaş bitince açılır")
	run.reward_ui.pick(0)
	# Run sonu: 2. katı bitirip ölüm → ×1,0 → 100 XP, hasar payına göre
	GameState.damage_by_weapon_type = {"sword": 600.0, "staff": 400.0}
	run.finished = true
	run._end_run(false)
	assert_eq(str(run.last_summary["depth_key"]), "clear_floor_2")
	assert_true(bool(run.last_summary["saved"]), "kayıt yazıldı ve geri okundu")
	assert_true(run.summary.visible, "özet ekranı açıldı")
	# Oyun yeniden açılınca korunur: yeni bir SaveManager aynı dosyayı okur
	var sm2: Node = SaveScript.new()
	sm2.save_path = SaveManager.save_path
	sm2.load_game()
	assert_almost(float(sm2.mastery["sword"]["xp"]), 60.0, 0.0001, "kılıç %60 → 60 XP")
	assert_almost(float(sm2.mastery["staff"]["xp"]), 40.0, 0.0001, "asa %40 → 40 XP")
	assert_true("mycela" in sm2.boss_first_kills)
	sm2.free()
	run.free()
	for n: Node in tree.get_nodes_in_group("enemies"):
		n.free()
	boss.free()
