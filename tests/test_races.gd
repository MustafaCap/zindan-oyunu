## Aşama 3: ırk statları, ırk-silah matrisi, kaynaklar (Enerji, Mana, bekleme süreleri), büyü silahı ×1,5,
## Ghost'un iyileşme kuralı, iksir ve Tab ile stat yenileme.
extends "res://tests/test_case.gd"

const FakeTarget := preload("res://tests/fake_target.gd")
const NO_CRIT := {"crit_bonus_chance": -1.0}

var _world: Node2D


func before_each() -> void:
	_world = Node2D.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(_world)


func after_each() -> void:
	_world.free()


func _player(race: String, weapons: Array[Weapon], level: int = 1) -> Player:
	var p := Player.new()
	p.race_id = race
	p.level = level
	p.weapons = weapons
	_world.add_child(p)
	return p


func _target(pos_tiles: Vector2 = Vector2(1, 0)) -> Node2D:
	var t: Node2D = FakeTarget.new()
	t.setup(100000.0)
	_world.add_child(t)
	t.global_position = Iso.to_screen(pos_tiles * Iso.KARO)
	return t


# --- RaceStats ---

func test_base_stats_match_gdd() -> void:
	var expected := {"warrior": [150, 6, 1.0, 0.15], "ghost": [100, 4, 1.1, 0.0], "archer": [90, 3.5, 1.05, 0.0], "magical": [80, 3, 1.0, 0.0]}
	for rid: String in expected.keys():
		var own := str(DataDB.table("races")[rid]["family"])
		var s1 := RaceStats.compute(rid, 1, own)
		var s10 := RaceStats.compute(rid, 10, own)
		assert_eq(s1.max_hp, expected[rid][0], "%s level 1 can" % rid)
		assert_eq(s10.max_hp, float(expected[rid][0]) + 9.0 * float(expected[rid][1]), "%s level 10 can" % rid)
		assert_eq(s1.move_speed_mult, expected[rid][2], "%s hız" % rid)
		assert_eq(s1.armor, expected[rid][3], "%s zırh" % rid)


## GDD Irklar tablosu: satır ırk, sütun silah ailesi.
func test_race_weapon_matrix_matches_gdd() -> void:
	# [maks can oranı, saldırı hızı bonusu, hasar buff'ı, element bonusu (pasif hariç)]
	var table := {
		"warrior": {"warrior": [0, 0, 0, 0], "ghost": [0, -0.05, 0, 0], "archer": [-0.25, 0, 0, 0], "magical": [-0.20, 0, 0, -0.10]},
		"ghost": {"warrior": [0, -0.05, 0, 0], "ghost": [0, 0, 0, 0], "archer": [-0.20, 0, 0, 0], "magical": [-0.15, 0, 0, -0.10]},
		"archer": {"warrior": [0.10, 0, -0.15, 0], "ghost": [0.10, 0, -0.10, 0], "archer": [0, 0, 0, 0], "magical": [0, 0, -0.08, 0]},
		"magical": {"warrior": [0.15, -0.15, 0, 0], "ghost": [0.10, -0.15, 0, 0], "archer": [0, 0, -0.08, 0], "magical": [0, 0, 0, 0]},
	}
	for rid: String in table.keys():
		var base := float(DataDB.table("races")[rid]["base_hp"])
		var passive: Dictionary = DataDB.table("races")[rid]["passive"]["bonuses"]
		for fam: String in table[rid].keys():
			var e: Array = table[rid][fam]
			var s := RaceStats.compute(rid, 1, fam)
			assert_almost(s.max_hp, base * (1.0 + float(e[0])), 0.001, "%s × %s can" % [rid, fam])
			assert_almost(s.attack_speed_bonus, float(e[1]), 0.0001, "%s × %s saldırı hızı" % [rid, fam])
			assert_almost(s.damage_buffs, float(e[2]), 0.0001, "%s × %s hasar" % [rid, fam])
			assert_almost(s.element_bonus, float(e[3]) + float(passive.get("element_damage", 0.0)), 0.0001, "%s × %s element" % [rid, fam])


func test_passives() -> void:
	var a := RaceStats.compute("archer", 1, "archer")
	assert_eq(a.attack_range_bonus, 0.10, "Archer menzil bonusu")
	assert_eq(a.crit_bonus, 0.05, "Archer kritik bonusu")
	var m := RaceStats.compute("magical", 1, "magical")
	assert_eq(m.element_bonus, 0.15, "Magical element bonusu")
	var mw := RaceStats.compute("magical", 1, "warrior")
	assert_eq(mw.element_bonus, 0.15, "Magical pasifi yakın silahta da geçerli")
	assert_eq(RaceStats.compute("warrior", 1, "magical").element_bonus, -0.10, "Warrior + büyü silahı −%10 element")
	assert_eq(RaceStats.matrix_text("warrior", "archer"), "−%25 can")
	assert_eq(RaceStats.matrix_text("archer", "archer"), "kendi ailesi")


# --- RaceKit: kaynaklar ---

func test_energy() -> void:
	var k := RaceKit.new("warrior")
	assert_eq(k.resource_type, "energy")
	assert_eq(k.resource_max, 100.0, "Enerji sabit 100")
	assert_eq(k.resource, 100.0)
	assert_eq(k.cost("q", "warrior"), 40.0)
	assert_eq(k.cost("e", "warrior"), 70.0)
	assert_eq(k.cost("light", "warrior"), 0.0, "sol tık bedava")
	assert_true(k.use("e", "warrior"))
	assert_eq(k.resource, 30.0)
	assert_true(not k.can_use("e", "warrior"), "30 enerjiyle E (70) olmaz")
	assert_true(not k.can_use("q", "warrior"), "30 enerjiyle Q (40) olmaz")
	k.tick(0.5)
	assert_eq(k.resource, 35.0, "saniyede 10 dolar")
	k.on_hit_landed(1)
	k.on_hit_landed(1)
	assert_eq(k.resource, 37.0, "isabet başına +2, aynı saldırı bir kez sayılır")
	k.on_hit_landed(2)
	assert_eq(k.resource, 39.0)
	k.tick(100.0)
	assert_eq(k.resource, 100.0, "tavan 100")


func test_mana() -> void:
	var k1 := RaceKit.new("magical", 1)
	assert_eq(k1.resource_max, 124.0, "Mana = 120 + level × 4")
	var k80 := RaceKit.new("magical", 80)
	assert_eq(k80.resource_max, 440.0, "level 80'de 440")
	assert_eq(k80.cost("light", "magical"), 1.0)
	assert_eq(k80.cost("heavy", "magical"), 55.0)
	assert_eq(k80.cost("q", "magical"), 65.0)
	assert_eq(k80.cost("e", "magical"), 90.0)
	assert_eq(k80.cooldown_for("heavy", "magical"), 0.0, "Magical sağ tık mana ile, beklemesiz")
	# Maks levelde arka arkaya 5-6 skill (GDD); yalnızca sağ tık atılırsa 8
	var casts := 0
	while k80.use("heavy", "magical"):
		casts += 1
	assert_eq(casts, 8, "440 manayla arka arkaya 8 sağ tık (55)")
	var k_mix := RaceKit.new("magical", 80)
	var skills := 0
	for slot: String in ["e", "q", "heavy", "e", "q", "heavy", "e"]:
		if k_mix.use(slot, "magical"):
			skills += 1
	assert_true(skills >= 5 and skills <= 6, "karışık Q/E/sağ tıkla 5-6 skill (bulunan %d)" % skills)
	k80.resource = 0.0
	k80.tick(1.0)
	assert_almost(k80.resource, 13.2, 0.001, "saniyede maks mananın %3'ü")
	var k20 := RaceKit.new("magical", 1)
	k20.set_level(20)
	assert_eq(k20.resource_max, 200.0, "level atlayınca maks mana artar")


func test_cooldown_races() -> void:
	var a := RaceKit.new("archer")
	assert_true(not a.uses_resource())
	assert_eq(a.cooldown_for("heavy", "archer"), 6.0)
	assert_eq(a.cooldown_for("q", "archer"), 8.0)
	assert_eq(a.cooldown_for("e", "archer"), 18.0)
	var g := RaceKit.new("ghost")
	assert_eq(g.cooldown_for("heavy", "ghost"), 5.0)
	assert_eq(g.cooldown_for("q", "ghost"), 12.0)
	assert_eq(g.cooldown_for("e", "ghost"), 10.0)
	assert_true(g.use("q", "ghost"))
	assert_true(not g.can_use("q", "ghost"), "bekleme süresinde kullanılamaz")
	g.tick(11.9)
	assert_true(not g.can_use("q", "ghost"))
	g.tick(0.2)
	assert_true(g.can_use("q", "ghost"), "12 sn sonra hazır")
	var w := RaceKit.new("warrior")
	assert_eq(w.cooldown_for("heavy", "warrior"), 6.0, "Warrior sağ tık 5-7 sn → 6")


## Magical dışındaki ırk kitap/asa/rün kullanırsa sağ tık beklemesi ×1,5 ve mana yok.
func test_foreign_spell_weapon_cooldown_x1_5() -> void:
	assert_eq(RaceKit.new("warrior").cooldown_for("heavy", "magical"), 9.0)
	assert_eq(RaceKit.new("ghost").cooldown_for("heavy", "magical"), 7.5)
	assert_eq(RaceKit.new("archer").cooldown_for("heavy", "magical"), 9.0)
	assert_eq(RaceKit.new("warrior").cost("heavy", "magical"), 0.0)
	assert_true(RaceKit.new("warrior").is_foreign_spell_weapon("magical"))
	assert_true(not RaceKit.new("magical").is_foreign_spell_weapon("magical"))
	assert_eq(RaceKit.new("archer").cooldown_for("heavy", "warrior"), 6.0, "yakın silah ×1 kalır")
	assert_eq(RaceKit.new("magical", 1).cost("light", "warrior"), 1.0, "Magical her silahta mana harcar")


# --- Player: can, iksir, Ghost, Tab ---

func test_ghost_healing_rule() -> void:
	var p := _player("ghost", [Weapon.make("dagger", "rare", "dark")] as Array[Weapon])
	p.hp = 50.0
	assert_true(not p.use_potion(), "Ghost iksir kullanamaz")
	assert_eq(p.potions, 2, "iksir harcanmadı")
	p.heal(20.0)
	assert_eq(p.hp, 50.0, "Ghost can emmeyle iyileşmez")
	var dummy := Node2D.new()
	_world.add_child(dummy)
	Events.enemy_killed.emit(dummy, false, false)
	assert_eq(p.hp, 54.0, "öldürme başına maks canın %4'ü")
	Events.enemy_killed.emit(dummy, true, false)
	assert_eq(p.hp, 64.0, "elit öldürmede %10")
	p.weapon().traits.append("lifesteal")
	Events.enemy_killed.emit(dummy, false, false)
	assert_eq(p.hp, 71.0, "Can Emme öldürme başına ek %3'e dönüşür")


func test_other_races_potion_and_lifesteal() -> void:
	var p := _player("warrior", [Weapon.make("sword", "common")] as Array[Weapon])
	p.hp = 10.0
	assert_true(p.use_potion())
	assert_eq(p.hp, 70.0, "iksir maks canın %40'ı")
	assert_eq(p.potions, 1)
	p.heal(5.0)
	assert_eq(p.hp, 75.0, "Warrior can emmeyle iyileşir")
	var dummy := Node2D.new()
	_world.add_child(dummy)
	Events.enemy_killed.emit(dummy, false, false)
	assert_eq(p.hp, 75.0, "öldürme iyileşmesi yalnızca Ghost'ta")
	p.hp = p.max_hp
	assert_true(not p.use_potion(), "can doluyken iksir içilmez")


func test_swap_recomputes_stats_keeping_hp_ratio() -> void:
	var p := _player("archer", [Weapon.make("bow", "common"), Weapon.make("sword", "common")] as Array[Weapon])
	assert_eq(p.max_hp, 90.0)
	p.hp = 45.0
	p.swap_weapon()
	assert_eq(p.active_index, 1)
	assert_almost(p.max_hp, 99.0, 0.001, "Archer + Warrior silahı +%10 can")
	assert_almost(p.hp, 49.5, 0.001, "can oranı korunur")
	assert_eq(p.stats.damage_buffs, -0.15, "Archer + Warrior silahı −%15 hasar")
	p.swap_weapon()
	assert_eq(p.max_hp, 90.0)
	assert_almost(p.hp, 45.0, 0.001)


## Aşama 6'dan beri her silah tipinin ustalığı level 1'dir ve level 1 de bonus verir (hız +%3,33, menzil +%1,67 …).
func test_attack_speed_and_range_from_matrix() -> void:
	var m_spd := Mastery.bonus(1, "attack_speed")
	var m_rng := Mastery.bonus(1, "attack_range")
	var p := _player("magical", [Weapon.make("sword", "common"), Weapon.make("staff", "common")] as Array[Weapon])
	assert_almost(p.attack_interval(), 1.0 / (1.4 * (0.85 + m_spd)), 0.0001, "Magical + Warrior silahı −%15 saldırı hızı")
	var a := _player("archer", [Weapon.make("bow", "common")] as Array[Weapon])
	assert_almost(a.attack_range(), 9.0 * (1.1 + m_rng), 0.0001, "Archer pasifi +%10 menzil")


func test_deal_hit_applies_matrix_and_passive() -> void:
	var t := _target()
	var archer := _player("archer", [Weapon.make("sword", "common")] as Array[Weapon])
	# Ustalık level 1: hasar ×1,05 (U), element +%2,5
	var mu := 1.0 + Mastery.bonus(1, "damage")
	var me := Mastery.bonus(1, "element_damage")
	var r := archer.deal_hit(t, archer.weapon(), "light", 1.0, 1, NO_CRIT)
	assert_almost(float(r["damage"]), 100.0 * mu * 0.85, 0.001, "Archer kılıçla −%15 hasar")
	var mage := _player("magical", [Weapon.make("staff", "rare", "fire")] as Array[Weapon])
	var t2 := _target(Vector2(0, 3))
	r = mage.deal_hit(t2, mage.weapon(), "light", 1.0, 1, NO_CRIT)
	assert_almost(float(r["damage"]), 125.0 * mu * (1.15 + me), 0.001, "Magical element +%15")
	var war := _player("warrior", [Weapon.make("staff", "rare", "fire")] as Array[Weapon])
	var t3 := _target(Vector2(0, -3))
	r = war.deal_hit(t3, war.weapon(), "light", 1.0, 1, NO_CRIT)
	assert_almost(float(r["damage"]), 125.0 * mu * (0.9 + me), 0.001, "Warrior + büyü silahı −%10 element")
	assert_almost(war.damage_by_source["light"], 125.0 * mu * (0.9 + me), 0.001, "hasar kaynağa göre kaydedilir")


## Kullanıcı kararı (Aşama 6): Warrior Q artık Kalkan Hücumu — ileri atılır, yoldaki düşmanlara ×1,5 vurur, iter ve sersemletir.
func test_warrior_shield_charge() -> void:
	var p := _player("warrior", [Weapon.make("sword", "common")] as Array[Weapon])
	p.rng.seed = 12345  # kritik zarı sabit: vuruş kritik olmasın (test rastgeleliğe bağlı kalmasın)
	p.aim_point = Iso.to_screen(Vector2(6, 0) * Iso.KARO)
	p.facing_cart = Vector2.RIGHT
	var on_path := _target(Vector2(2, 0))
	on_path.add_to_group("enemies")
	var far := _target(Vector2(2, 3))
	far.add_to_group("enemies")
	var boss: Node2D = FakeTarget.new()
	boss.setup(100000.0, true)
	_world.add_child(boss)
	boss.add_to_group("enemies")
	boss.global_position = Iso.to_screen(Vector2(3.5, 0) * Iso.KARO)
	assert_true(RaceAbilities.use(p, "q"))
	assert_eq(p.kit.resource, 60.0, "Kalkan Hücumu 40 enerji")
	assert_true(p.iframes > 0.2, "hücum sırasında dokunulmaz")
	# Hücum hızı × süre = 4 karo, farenin yönünde (testte fizik adımı elle sürüldüğü için konum yerine hız ölçülür)
	var travel := p._move_override_vel * 0.25
	assert_almost(Iso.tile_distance(Vector2.ZERO, travel), 4.0, 0.01, "4 karo ileri atılır")
	assert_true(Iso.to_cart(travel).x > 0.0, "farenin yönünde")
	for i: int in 30:
		p._physics_process(1.0 / 60.0)
	assert_eq(p.rush_t, 0.0, "hücum biter")
	var hits: Array = on_path.get("hits")
	assert_eq(hits.size(), 1, "yoldaki düşmana bir kez vurur")
	assert_almost(float(hits[0]["amount"]), 100.0 * 1.5 * (1.0 + Mastery.bonus(1, "damage")), 0.01, "aktif silahın ×1,5'i")
	assert_true(bool(hits[0]["heavy"]), "güçlü vuruş (savrulur)")
	assert_true((on_path.get("status") as StatusEffects).stun_t > 0.0, "sersemletir")
	assert_true((boss.get("status") as StatusEffects).stun_t <= 0.0, "boss sersemlemez")
	assert_eq((far.get("hits") as Array).size(), 0, "yol dışındaki vurulmaz")
	assert_true(p.damage_by_source["q"] > 0.0, "Q hasarı kaydedilir")
	assert_eq(p.current_armor(), 0.15, "artık zırh buff'ı yok")


func test_ghost_phase_and_magical_flight() -> void:
	var g := _player("ghost", [Weapon.make("dagger", "common")] as Array[Weapon])
	assert_true(RaceAbilities.use(g, "q"))
	assert_true(g.is_untargetable(), "Faz: düşmanlara görünmez")
	g.take_damage(50.0, Vector2.LEFT)
	assert_eq(g.hp, g.max_hp, "Faz: dokunulmaz")
	g.end_phase()
	assert_true(not g.is_untargetable())
	var m := _player("magical", [Weapon.make("staff", "common")] as Array[Weapon], 10)
	assert_true(RaceAbilities.use(m, "q"))
	assert_true(m.is_flying())
	assert_eq(m.collision_mask, Player.MASK_WALLS, "uçarken yalnızca duvarlar engeller")
	m.end_flight()
	assert_eq(m.collision_mask, Player.MASK_WALLS | Player.MASK_OBSTACLES)


func test_shadow_step_needs_target_and_lands_behind() -> void:
	var g := _player("ghost", [Weapon.make("dagger", "common")] as Array[Weapon])
	assert_true(not RaceAbilities.use(g, "e"), "hedef yoksa kullanılmaz")
	assert_true(g.kit.is_ready("e"), "hedef yoksa bekleme başlamaz")
	var t := _target(Vector2(3, 0))
	t.add_to_group("enemies")
	t.facing_cart = Vector2.LEFT   # oyuncuya bakıyor
	g.aim_point = t.global_position
	assert_true(RaceAbilities.use(g, "e"))
	assert_true(DamageCalc.is_behind(t.global_position, t.facing_cart, g.global_position), "hedefin arkasına ışınlandı")
	assert_eq(g.kit.cooldowns["e"], 10.0)


func test_data_rejects_unknown_ability_and_style() -> void:
	var DataDBScript := load("res://scripts/autoload/data_db.gd")
	var dir := "user://test_tmp/bad_ability"
	DirAccess.make_dir_recursive_absolute(dir)
	for f: String in DirAccess.get_files_at("res://data"):
		if f.ends_with(".json"):
			var txt := FileAccess.get_file_as_string("res://data/" + f)
			if f == "races.json":
				var races: Dictionary = JSON.parse_string(txt)
				races["archer"]["abilities"]["e"]["id"] = "meteor"
				(races["magical"]["costs"] as Dictionary).erase("heavy")
				txt = JSON.stringify(races)
			elif f == "weapon_types.json":
				var wt: Dictionary = JSON.parse_string(txt)
				wt["axe"]["heavy"]["style"] = "laser"
				(wt["bow"]["light"] as Dictionary).erase("speed")
				txt = JSON.stringify(wt)
			var fa := FileAccess.open(dir + "/" + f, FileAccess.WRITE)
			fa.store_string(txt)
			fa.close()
	var db: Node = DataDBScript.new()
	db.report_errors = false
	db.load_all(dir)
	var all := "\n".join(db.errors)
	assert_true(all.contains("races.archer.abilities.e: bilinmeyen yetenek 'meteor'"), all)
	assert_true(all.contains("races.magical.costs: eksik alan 'heavy'"), all)
	assert_true(all.contains("weapon_types.axe.heavy.style: bilinmeyen stil 'laser'"), all)
	assert_true(all.contains("weapon_types.bow.light: eksik alan 'speed'"), all)
	db.free()
