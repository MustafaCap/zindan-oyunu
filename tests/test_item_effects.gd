## Aşama 5 — eşya etkileri (ItemEffects): Rezonans ek hasarı, Esnek slot (%9 özellik, tam tılsım), 3 tılsım,
## efsanevi pasifler ve sağ tık ekleri; Player.load_loadout.
extends "res://tests/test_case.gd"

const FakeTarget := preload("res://tests/fake_target.gd")
const NO_CRIT := {"crit_bonus_chance": -1.0}

var _world: Node2D


func before_each() -> void:
	_world = Node2D.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(_world)


func after_each() -> void:
	_world.free()


func _player(race: String, w: Weapon, level: int = 10) -> Player:
	var p := Player.new()
	p.race_id = race
	p.level = level
	p.weapons = [w]
	_world.add_child(p)
	return p


func _target(pos_tiles: Vector2 = Vector2(1, 0), def: DamageCalc.Defense = null, in_group: bool = true) -> Node2D:
	var t: Node2D = FakeTarget.new()
	t.setup(100000.0, false, def)
	_world.add_child(t)
	if in_group:
		t.add_to_group("enemies")
	t.global_position = Iso.to_screen(pos_tiles * Iso.KARO)
	return t


func _secondary_total(t: Node2D) -> float:
	var s := 0.0
	for h: Dictionary in t.get("hits"):
		if bool(h.get("secondary", false)):
			s += float(h["amount"])
	return s


## GDD Rezonans: kilitliyken normal saldırının %10'u, açıkken %7'si; onun elementiyle; oyuncunun buff'larından etkilenmez.
func test_resonance_extra_damage() -> void:
	var p := _player("warrior", Weapon.make("sword", "common"), 10)
	var t := _target()
	var staff := Weapon.make("staff", "rare", "lightning", [], 20)   # kilitli (20 > 10)
	p.effects.resonance = staff
	p.deal_hit(t, p.weapon(), "light", 1.0, p.next_attack_id(), NO_CRIT)
	var want := staff.hit_damage() * 0.10
	assert_almost(_secondary_total(t), want, 0.01, "kilitli Rezonans %10")
	var hits: Array = t.get("hits")
	assert_eq(str(hits[hits.size() - 1]["kind"]), "lightning", "Rezonans hasarı kendi elementinde")
	assert_true(not (t.get("status") as StatusEffects).has_element("lightning"), "Rezonans element durumu bırakmaz")
	var t2 := _target(Vector2(1, 1))
	p.set_level(20)
	p.deal_hit(t2, p.weapon(), "light", 1.0, p.next_attack_id(), NO_CRIT)
	assert_almost(_secondary_total(t2), staff.hit_damage() * 0.07, 0.01, "açık Rezonans %7")
	# Bağışıklık geçerli: taş (yıldırıma bağışık) hedefe işlemez
	var t3 := _target(Vector2(1, -1), DamageCalc.Defense.new(["lightning"], [], [], 0.0))
	p.deal_hit(t3, p.weapon(), "light", 1.0, p.next_attack_id(), NO_CRIT)
	assert_eq(_secondary_total(t3), 0.0, "bağışık hedefe Rezonans işlemez")


## GDD Esnek slot: silah konursa özelliklerinin %9'u işler.
func test_flex_weapon_traits_at_nine_percent() -> void:
	var p := _player("warrior", Weapon.make("sword", "common"), 10)
	p.hp = 50.0
	p.effects.flex = Weapon.make("dagger", "epic", "fire", ["lifesteal"], 1)
	var o := p.effects.hit_opts()
	assert_eq(o["flex_traits"], ["lifesteal"])
	assert_almost(float(o["flex_scale"]), 0.09, 0.0001)
	var t := _target()
	var res := p.deal_hit(t, p.weapon(), "light", 1.0, p.next_attack_id(), NO_CRIT)
	var healed := p.hp - 50.0
	assert_almost(healed, float(res["damage"]) * 0.03 * 0.09, 0.01, "Can Emme %3 × %9")
	# Eşikler de ölçeklenir: İnfaz %7 × 0,09 = %0,63
	assert_true(Traits.should_execute(0.5, 100.0, false, 0.09), "%0,5 can < %0,63")
	assert_true(not Traits.should_execute(1.0, 100.0, false, 0.09), "%1 can > %0,63")
	# Silahta da özellik varsa toplanır (1,09)
	var own := Weapon.make("sword", "epic", "fire", ["lifesteal"])
	assert_almost(HitResolver.trait_scale(own, "lifesteal", o), 1.09, 0.0001)


func test_talisman_blood_stone() -> void:
	var p := _player("warrior", Weapon.make("sword", "common"))
	p.effects.flex = Talisman.make("blood_stone")
	for i: int in 7:
		p.effects.on_kill(null, false)
	assert_eq(p.effects.blood_stacks, 5, "maks 5 yığın")
	assert_almost(float(p.effects.hit_opts()["damage_buffs"]), 0.10, 0.0001, "5 × %2")
	p.effects.tick(10.5)
	assert_eq(p.effects.blood_stacks, 0, "10 sn sonra söner")


func test_talisman_wind_feather() -> void:
	var p := _player("warrior", Weapon.make("sword", "common"))
	p.effects.flex = Talisman.make("wind_feather")
	assert_almost(p.effects.dash_cooldown_mult(), 0.7, 0.0001, "Space beklemesi −%30")
	p._start_dash(Vector2.RIGHT)
	assert_almost(p.dash_cd, 0.7, 0.0001)
	assert_almost(p.effects.move_speed_mult(), 1.15, 0.0001, "atılmadan sonra +%15 hız")
	p.effects.tick(2.1)
	assert_almost(p.effects.move_speed_mult(), 1.0, 0.0001, "2 sn sonra biter")
	# Çantadaki tılsım etki etmez
	p.effects.flex = null
	assert_almost(p.effects.dash_cooldown_mult(), 1.0, 0.0001)


func test_talisman_element_heart() -> void:
	var p := _player("warrior", Weapon.make("sword", "common"))
	p.effects.flex = Talisman.make("element_heart")
	assert_eq(float(p.effects.hit_opts()["element_bonus"]), 0.0)
	Events.combo_triggered.emit("melt", null)
	assert_almost(float(p.effects.hit_opts()["element_bonus"]), 0.20, 0.0001, "kombo sonrası +%20 element")
	p.effects.tick(3.1)
	assert_eq(float(p.effects.hit_opts()["element_bonus"]), 0.0)


## Efsanevi "Gökyarığı": her 5. saldırı gökten yıldırım (vuruşun %80'i).
func test_legendary_sky_lightning_every_fifth_attack() -> void:
	var lw := Weapon.make_legendary("sky_rift", ["fury"], 10)
	var p := _player("warrior", lw)
	var t := _target()
	for i: int in 4:
		p.deal_hit(t, lw, "light", 1.0, p.next_attack_id(), NO_CRIT)
	assert_eq(_secondary_total(t), 0.0, "ilk 4 saldırıda yok")
	var id := p.next_attack_id()
	p.deal_hit(t, lw, "light", 1.0, id, NO_CRIT)
	p.deal_hit(t, lw, "light", 1.0, id, NO_CRIT)  # aynı saldırı iki kez sayılmaz
	assert_true(_secondary_total(t) > 0.0, "5. saldırıda gökten yıldırım")
	assert_eq(int(p.effects.hit_counter["active"]), 5)


func test_legendary_death_burst_and_frenzy() -> void:
	var lw := Weapon.make_legendary("ash_eater", ["stun"], 10)
	var p := _player("warrior", lw)
	var dead := _target(Vector2(2, 0))
	var near := _target(Vector2(3, 0))
	p.effects.on_kill(dead, false)
	assert_true(_secondary_total(near) > 0.0, "öldürülen düşman patlar")
	assert_true((near.get("status") as StatusEffects).has_element("fire"), "patlama element bırakır")
	var fw := Weapon.make_legendary("soul_reaper", ["fury"], 10)
	var p2 := _player("ghost", fw)
	var before := p2.attack_interval()
	p2.effects.on_kill(null, false)
	assert_almost(p2.attack_interval(), 1.0 / (0.9 * (1.25 + Mastery.bonus(1, "attack_speed"))), 0.0001, "öldürme sonrası +%25 saldırı hızı")
	assert_true(p2.attack_interval() < before)
	p2.effects.tick(4.1)
	assert_almost(p2.attack_interval(), before, 0.0001)


func test_legendary_combo_reset_and_crit_nova() -> void:
	var lw := Weapon.make_legendary("wave_breaker", ["fury"], 10)
	var p := _player("ghost", lw)
	p.kit.cooldowns["heavy"] = 3.0
	p.kit.cooldowns["q"] = 5.0
	p.kit.cooldowns["e"] = 5.0
	Events.combo_triggered.emit("electroshock", null)
	assert_eq(float(p.kit.cooldowns["heavy"]) + float(p.kit.cooldowns["q"]) + float(p.kit.cooldowns["e"]), 0.0, "kombo beklemeleri sıfırlar")
	var cw := Weapon.make_legendary("storm_string", ["fury"], 10)
	var p2 := _player("archer", cw)
	var t := _target()
	var t2 := _target(Vector2(1.5, 0))
	p2.deal_hit(t, cw, "light", 1.0, p2.next_attack_id(), {"crit_bonus_chance": 5.0})
	assert_true(_secondary_total(t2) > 0.0, "kritik vuruş etrafında patlar")


## Esnek slottaki efsanevinin pasifi %9 ile: death_burst hasarı %50 × 0,09.
func test_flex_legendary_passive_scaled() -> void:
	var p := _player("warrior", Weapon.make("sword", "common"))
	var fw := Weapon.make_legendary("ash_eater", ["stun"], 1)
	p.effects.flex = fw
	var src := p.effects.passive_sources()
	assert_eq(src.size(), 1)
	assert_almost(float(src[0][1]), 0.09, 0.0001)
	var near := _target(Vector2(3, 0))
	p.effects.on_kill(_target(Vector2(2.5, 0)), false)
	var full := HitResolver.secondary_hit(fw, _target(Vector2(8, 8), null, false), 0.5, "fire", {}, false, Vector2.RIGHT)
	assert_almost(_secondary_total(near), full * 0.09, full * 0.02, "Esnek'te pasif %9")


func test_legendary_heavy_skills_spawn() -> void:
	for id: String in ["sky_rift", "ash_eater", "soul_reaper"]:
		var lw := Weapon.make_legendary(id, ["fury"], 10)
		var p := _player(str(lw.family()), lw)
		var before := _world.get_child_count()
		p.effects.on_heavy(lw)
		var n := int(lw.skill_data().get("count", 1))
		assert_eq(_world.get_child_count() - before, n, "%s sağ tık eki %d düğüm" % [id, n])
	# Efsanevi olmayan silahta ek yok
	var p2 := _player("warrior", Weapon.make("sword", "common"))
	var b2 := _world.get_child_count()
	p2.effects.on_heavy(p2.weapon())
	assert_eq(_world.get_child_count(), b2)


## Zindanda silahlar envanterden: load_loadout aktif silahları, Rezonans ve Esnek'i okur; Tab envanteri günceller.
func test_player_loads_loadout_from_inventory() -> void:
	var inv := Inventory.new()
	var a := Weapon.make("sword", "rare", "water")
	var b := Weapon.make("staff", "rare", "lightning")
	inv.slots["active_1"] = a
	inv.slots["active_2"] = b
	inv.slots["resonance"] = Weapon.make("axe", "common", "physical", [], 30)
	inv.slots["flex"] = Talisman.make("wind_feather")
	inv.active_slot = "active_2"
	inv.potions = 3
	var p := Player.new()
	p.race_id = "warrior"
	p.inventory = inv
	_world.add_child(p)
	assert_eq(p.weapons.size(), 2)
	assert_eq(p.weapon(), b, "kullanılan aktif slot korunur")
	assert_eq(p.effects.resonance, inv.slots["resonance"])
	assert_true(p.effects.talisman() != null)
	assert_eq(p.potions, 3, "iksirler envanterden")
	p.swap_weapon()
	assert_eq(inv.active_slot, "active_1", "Tab envanteri günceller")
	p.hp = p.max_hp * 0.5
	inv.slots["active_2"] = null
	p.load_loadout(inv)
	assert_eq(p.weapons.size(), 1)
	assert_almost(p.hp / p.max_hp, 0.5, 0.001, "can oranı korunur")
	p.use_potion()
	assert_eq(inv.potions, 2, "iksir envanterden düşer")
