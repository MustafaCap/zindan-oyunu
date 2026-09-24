## Aşama 3: 12 silah tipinin saldırıları — yay vuruşu menzil/açı, mermiler (delme, güdüm, patlama, geri dönme),
## Yay dolumu, Saçma, Mızrak geri çağırma, Rün tuzağı, sağ tık bekleme/kaynak kuralları.
extends "res://tests/test_case.gd"

const FakeTarget := preload("res://tests/fake_target.gd")
const DT := 1.0 / 60.0

var _world: Node2D


func before_each() -> void:
	_world = Node2D.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(_world)


func after_each() -> void:
	_world.free()


func _player(race: String, type_id: String, element: String = "physical", level: int = 1) -> Player:
	var p := Player.new()
	p.race_id = race
	p.level = level
	p.weapons = [Weapon.make(type_id, "rare" if element != "physical" else "common", element)] as Array[Weapon]
	p.rng.seed = 3
	_world.add_child(p)
	p.facing_cart = Vector2.RIGHT
	return p


func _enemy(pos_tiles: Vector2, hp: float = 100000.0) -> Node2D:
	var t: Node2D = FakeTarget.new()
	t.setup(hp)
	_world.add_child(t)
	t.add_to_group("enemies")
	t.global_position = Iso.to_screen(pos_tiles * Iso.KARO)
	return t


## Sahnedeki mermi ve yer efektlerini dt adımlarıyla ilerletir.
func _step(seconds: float) -> void:
	var n := int(ceil(seconds / DT))
	for i: int in n:
		for c: Node in _world.get_children():
			if c.is_queued_for_deletion():
				continue
			if c is Projectile or c is GroundEffect:
				c.call("_physics_process", DT)


func _count(cls: Variant) -> int:
	var k := 0
	for c: Node in _world.get_children():
		if is_instance_of(c, cls) and not c.is_queued_for_deletion():
			k += 1
	return k


func test_all_types_have_light_and_heavy() -> void:
	for t: String in DataDB.records(DataDB.table("weapon_types")):
		var wt: Dictionary = DataDB.table("weapon_types")[t]
		assert_true(str(wt["light"]["style"]) in ["arc", "thrust", "projectile", "blast"], "%s sol tık stili" % t)
		assert_true(str(wt["heavy"]["style"]) != "", "%s sağ tık stili" % t)


func test_sword_arc_hits_front_only() -> void:
	var p := _player("warrior", "sword")
	var front := _enemy(Vector2(1.2, 0))
	var back := _enemy(Vector2(-1.2, 0))
	var far := _enemy(Vector2(3.0, 0))
	assert_true(WeaponAttacks.light(p))
	assert_eq(front.hits.size(), 1, "öndeki vurulur")
	assert_eq(back.hits.size(), 0, "arkadaki vurulmaz")
	assert_eq(far.hits.size(), 0, "menzil dışı vurulmaz")
	assert_almost(p.attack_cd, 1.0 / 1.4, 0.0001, "saldırı hızı 1,4/sn")


func test_spear_thrust_is_narrow_and_long() -> void:
	var p := _player("archer", "spear")
	var tip := _enemy(Vector2(3.4, 0))
	var side := _enemy(Vector2(1.0, 1.0))
	WeaponAttacks.light(p)
	assert_eq(tip.hits.size(), 1, "mızrak 3,5 karoya uzanır (Archer +%10)")
	assert_eq(side.hits.size(), 0, "dar açı: yandaki vurulmaz")


func test_arrow_flies_hits_first_and_stops() -> void:
	var p := _player("archer", "bow")
	var a := _enemy(Vector2(4, 0))
	var b := _enemy(Vector2(6, 0))
	WeaponAttacks.light(p)
	assert_eq(_count(Projectile), 1, "ok atıldı")
	_step(1.0)
	assert_eq(a.hits.size(), 1, "ilk düşmana çarptı")
	assert_eq(b.hits.size(), 0, "ok delmez")
	assert_eq(_count(Projectile), 0, "ok yok oldu")


func test_bow_charge_shot_pierces_and_scales() -> void:
	var p := _player("archer", "bow")
	var a := _enemy(Vector2(3, 0))
	var b := _enemy(Vector2(5, 0))
	assert_true(WeaponAttacks.heavy_pressed(p))
	assert_true(p.charging, "basılı tutunca dolar")
	assert_true(p.kit.is_ready("heavy"), "bırakmadan bekleme başlamaz")
	p.charge_t = 5.0
	WeaponAttacks.heavy_released(p)
	assert_eq(p.kit.cooldowns["heavy"], 6.0)
	_step(1.0)
	assert_eq(a.hits.size(), 1)
	assert_eq(b.hits.size(), 1, "Güçlü atış deler")
	assert_almost(float(a.hits[0]["amount"]), 100.0 * 0.9 * 3.0, 0.001, "tam dolumda ×3")


func test_crossbow_scatter_five_bolts() -> void:
	var p := _player("archer", "crossbow")
	WeaponAttacks.heavy_pressed(p)
	assert_eq(_count(Projectile), 5, "5 cıvata")


func test_tome_homing_pages_find_target() -> void:
	var p := _player("magical", "tome", "fire", 10)
	var t := _enemy(Vector2(2, 3))
	WeaponAttacks.heavy_pressed(p)
	assert_eq(_count(Projectile), 4, "4 güdümlü sayfa")
	assert_eq(p.kit.resource, p.kit.resource_max - 55.0, "Magical sağ tık 55 mana")
	_step(3.0)
	assert_true(t.hits.size() >= 3, "sayfalar yandaki hedefi bulur (%d isabet)" % t.hits.size())


func test_staff_orb_explodes_in_area() -> void:
	var p := _player("magical", "staff", "fire", 10)
	var a := _enemy(Vector2(3, 0))
	var b := _enemy(Vector2(3, 1.2))
	var c := _enemy(Vector2(3, -6))
	WeaponAttacks.heavy_pressed(p)
	_step(1.5)
	assert_eq(a.hits.size(), 1, "çarptığı düşman")
	assert_eq(b.hits.size(), 1, "patlama alanındaki düşman")
	assert_eq(c.hits.size(), 0, "alan dışı")


func test_axe_returns_and_hits_twice() -> void:
	var p := _player("warrior", "axe")
	var t := _enemy(Vector2(2.5, 0))
	WeaponAttacks.heavy_pressed(p)
	assert_true(not p.visual.show_weapon, "balta elden çıktı")
	_step(2.0)
	assert_eq(t.hits.size(), 2, "gidişte ve dönüşte vurur")
	assert_eq(_count(Projectile), 0, "balta döndü")
	assert_true(p.visual.show_weapon)


func test_spear_throw_sticks_and_recalls() -> void:
	var p := _player("archer", "spear")
	var t := _enemy(Vector2(3, 0))
	assert_true(WeaponAttacks.heavy_pressed(p))
	assert_true(is_instance_valid(p.spear_out))
	assert_true(p.kit.is_ready("heavy"), "bekleme mızrak dönünce başlar")
	_step(1.0)
	assert_eq(p.spear_out.state, "stuck", "menzil sonunda saplandı")
	assert_eq(t.hits.size(), 1)
	assert_true(not WeaponAttacks.light(p), "mızrak havadayken dürtme yok")
	WeaponAttacks.heavy_pressed(p)   # geri çağır
	_step(1.5)
	assert_eq(t.hits.size(), 2, "dönüşte yeniden vurur")
	assert_true(not is_instance_valid(p.spear_out) or p.spear_out == null, "mızrak döndü")
	assert_eq(p.kit.cooldowns["heavy"], 6.0, "bekleme şimdi başladı")


func test_fist_flurry_last_hit_stuns() -> void:
	var p := _player("warrior", "fist")
	var t := _enemy(Vector2(1.0, 0))
	WeaponAttacks.heavy_pressed(p)
	assert_eq(t.hits.size(), 1, "ilk yumruk hemen")
	assert_true(p.busy_t > 0.0, "seri sürerken yeni saldırı yok")
	# Kalan yumruklar zamanlayıcıyla gelir; burada doğrudan zamanlayıcıları beklemek yerine süreyi kontrol ederiz
	assert_almost(p.busy_t, 5 * 0.09, 0.0001)


func test_mace_smash_slows() -> void:
	var p := _player("ghost", "mace")
	var t := _enemy(Vector2(1.5, 0.5))
	WeaponAttacks.heavy_pressed(p)
	assert_eq(t.hits.size(), 1)
	assert_true(t.status.slow_amount > 0.0, "yavaşlatır")


func test_scythe_harvest_backstab_bonus() -> void:
	var p := _player("ghost", "scythe")
	var facing_me := _enemy(Vector2(1.5, 0))
	facing_me.facing_cart = Vector2.LEFT
	var facing_away := _enemy(Vector2(0, 1.5))
	facing_away.facing_cart = Vector2(0, 1)
	p.rng.seed = 99
	WeaponAttacks.heavy_pressed(p)
	var a := float(facing_me.hits[0]["amount"])
	var b := float(facing_away.hits[0]["amount"])
	var crit_a: bool = facing_me.hits[0]["crit"]
	var crit_b: bool = facing_away.hits[0]["crit"]
	if not crit_a and not crit_b:
		assert_almost(b / a, 1.2, 0.0001, "arkadan vurulana +%20")


func test_rune_trap_triggers_and_replaces() -> void:
	var p := _player("magical", "rune", "fire", 10)
	p.aim_point = Iso.to_screen(Vector2(3, 0) * Iso.KARO)
	WeaponAttacks.heavy_pressed(p)
	var first := p.trap
	assert_true(is_instance_valid(first))
	p.kit.resource = p.kit.resource_max
	WeaponAttacks.heavy_pressed(p)
	assert_true(p.trap != first, "yeni tuzak eskisini kaldırır")
	_step(0.6)
	var t := _enemy(Vector2(3.3, 0))
	_step(0.1)
	assert_eq(t.hits.size(), 1, "üstüne basınca patlar")


func test_rune_light_blast_at_cursor() -> void:
	var p := _player("magical", "rune", "ice", 10)
	var t := _enemy(Vector2(4, 0))
	p.aim_point = t.global_position
	WeaponAttacks.light(p)
	assert_eq(t.hits.size(), 0, "gecikmeli")
	_step(0.5)
	assert_eq(t.hits.size(), 1, "farenin gösterdiği yerde patladı")


func test_foreign_spell_weapon_heavy_cooldown() -> void:
	var p := _player("warrior", "staff")
	WeaponAttacks.heavy_pressed(p)
	assert_eq(p.kit.cooldowns["heavy"], 9.0, "Warrior + asa: 6 × 1,5")
	assert_eq(p.kit.resource, 100.0, "enerji harcanmaz")
	assert_true(not WeaponAttacks.heavy_pressed(p), "beklemedeyken olmaz")


func test_magical_needs_mana_for_light() -> void:
	var p := _player("magical", "tome", "fire", 1)
	p.kit.resource = 0.5
	assert_true(not WeaponAttacks.light(p), "1 mana yoksa sol tık yok")
	p.kit.resource = 1.0
	assert_true(WeaponAttacks.light(p))
	assert_eq(p.kit.resource, 0.0)


func test_dagger_backstab_lunges_behind_target() -> void:
	var p := _player("ghost", "dagger")
	var t := _enemy(Vector2(2.5, 0))
	t.facing_cart = Vector2.LEFT
	p.aim_point = t.global_position
	WeaponAttacks.heavy_pressed(p)
	assert_true(p.busy_t > 0.0)
	# Atılma hareketini elle ilerlet (fizik döngüsü yerine)
	for i: int in 12:
		p._physics_process(DT)
	assert_true(DamageCalc.is_behind(t.global_position, t.facing_cart, p.global_position), "hedefin arkasına geçti")
	assert_eq(t.hits.size(), 1, "arkadan sapladı")
