## Aşama 2: 5 özellik — Öfke, İnfaz (boss'ta %3), Can Emme, Sekme, Sersemletme; silah adları.
extends "res://tests/test_case.gd"

const FakeTarget := preload("res://tests/fake_target.gd")
const NO_CRIT := {"crit_bonus_chance": -1.0}

var _world: Node2D
var _rng := RandomNumberGenerator.new()


func before_each() -> void:
	_world = Node2D.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(_world)
	_rng.seed = 99


func after_each() -> void:
	_world.free()


func _target(pos_tiles: Vector2 = Vector2(1, 0), hp: float = 100000.0, boss: bool = false) -> Node2D:
	var t: Node2D = FakeTarget.new()
	t.setup(hp, boss)
	_world.add_child(t)
	t.global_position = Iso.to_screen(pos_tiles * Iso.KARO)
	return t


func test_fury_bonus_curve() -> void:
	assert_eq(Traits.fury_bonus(0), 0.0, "ilk vuruş bonussuz")
	assert_almost(Traits.fury_bonus(3), 0.03, 0.0001)
	assert_almost(Traits.fury_bonus(6), 0.06, 0.0001)
	assert_almost(Traits.fury_bonus(50), 0.06, 0.0001, "maks %6")


func test_fury_stacks_per_target() -> void:
	var a := _target(Vector2.ZERO)
	var t1 := _target()
	var t2 := _target()
	var w := Weapon.make("sword", "epic", "fire", ["fury"])
	var dmgs: Array[float] = []
	for i: int in 8:
		dmgs.append(float(HitResolver.resolve(a, w, t1, NO_CRIT, [], _rng)["damage"]))
	assert_almost(dmgs[1] / dmgs[0], 1.01, 0.0001, "2. vuruş +%1")
	assert_almost(dmgs[7] / dmgs[0], 1.06, 0.0001, "7. vuruştan sonra +%6'da durur")
	var other := float(HitResolver.resolve(a, w, t2, NO_CRIT, [], _rng)["damage"])
	assert_almost(other, dmgs[0], 0.0001, "başka hedefte öfke sıfırdan başlar")


func test_execute_thresholds() -> void:
	assert_true(Traits.should_execute(6.9, 100.0, false), "%6,9 → infaz")
	assert_true(not Traits.should_execute(7.1, 100.0, false), "%7,1 → yok")
	assert_true(not Traits.should_execute(5.0, 100.0, true), "boss'ta %5 yetmez")
	assert_true(Traits.should_execute(2.9, 100.0, true), "boss'ta %2,9 → infaz")
	assert_true(not Traits.should_execute(0.0, 100.0, false), "ölüye infaz yok")


func test_execute_in_game() -> void:
	var a := _target(Vector2.ZERO)
	var t := _target(Vector2(1, 0), 1000.0)
	t.set("hp", 150.0)  # 125'lik vuruştan sonra %2,5 kalır
	var r := HitResolver.resolve(a, Weapon.make("sword", "rare", "fire", ["execute"]), t, NO_CRIT, [], _rng)
	assert_true(r["executed"], "eşiğin altına düşen hedef infaz edildi")
	assert_true(t.get("dead"))


func test_lifesteal_three_percent() -> void:
	assert_almost(Traits.lifesteal_amount(200.0), 6.0, 0.0001)
	var a := _target(Vector2.ZERO)
	var t := _target()
	var r := HitResolver.resolve(a, Weapon.make("sword", "rare", "fire", ["lifesteal"]), t, NO_CRIT, [], _rng)
	assert_almost(float(a.get("healed")), float(r["damage"]) * 0.03, 0.0001, "saldıran %3 iyileşir")


func test_ricochet_and_stun_rates() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var n := 20000
	var ric := 0
	var stun := 0
	for i: int in n:
		if Traits.roll_ricochet(rng): ric += 1
		if Traits.roll_stun(rng): stun += 1
	assert_almost(ric / float(n), 0.35, 0.01, "sekme ≈ %35")
	assert_almost(stun / float(n), 0.08, 0.01, "sersemletme ≈ %8")


func test_ricochet_in_game_hits_neighbor_at_half() -> void:
	var a := _target(Vector2.ZERO)
	var w := Weapon.make("sword", "epic", "fire", ["ricochet"])
	var bounced := 0
	for i: int in 60:
		var t := _target(Vector2(1, 0))
		var nb := _target(Vector2(2, 0))
		var r := HitResolver.resolve(a, w, t, NO_CRIT, [t, nb], _rng)
		if r["ricochet"] != null:
			bounced += 1
			assert_almost(float(nb.call("total_damage")), float(r["damage"]) * 0.5, 0.01, "sekme %50 hasar")
		t.queue_free()
		nb.queue_free()
	assert_true(bounced > 5 and bounced < 40, "60 vuruşta makul sayıda sekme (%d)" % bounced)


func test_stun_in_game_boss_gets_slow() -> void:
	var a := _target(Vector2.ZERO)
	var w := Weapon.make("sword", "epic", "fire", ["stun"])
	var boss := _target(Vector2(1, 0), 1.0e9, true)
	var st: StatusEffects = boss.get("status")
	var slowed := false
	for i: int in 200:
		HitResolver.resolve(a, w, boss, NO_CRIT, [], _rng)
		assert_true(st.can_act(), "boss hiç sersemlemez")
		if st.slow_amount > 0.0:
			slowed = true
	assert_true(slowed, "200 vuruşta boss en az bir kez yavaşladı")


func test_weapon_names() -> void:
	assert_eq(Traits.weapon_name("sword", "ice", ["fury"]), "Öfkeli Buz Kılıcı")
	assert_eq(Traits.weapon_name("dagger", "poison", ["execute"]), "İnfazcı Zehir Hançeri")
	assert_eq(Traits.weapon_name("sword", "", []), "Kılıç")
	assert_eq(Weapon.make("staff", "rare", "lightning").display_name(), "Yıldırım Asası")
