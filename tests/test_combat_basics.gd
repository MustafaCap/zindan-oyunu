## Aşama 1: izometrik dönüşümler, yay isabet testi, zırh ve prototip verileri.
extends "res://tests/test_case.gd"


func test_iso_roundtrip() -> void:
	var v := Vector2(37.0, -12.5)
	var back := Iso.to_screen(Iso.to_cart(v))
	assert_almost(back.x, v.x, 0.0001)
	assert_almost(back.y, v.y, 0.0001)


func test_one_tile_step_is_one_karo() -> void:
	# Bir karo sağ-aşağı komşu: ekranda (32, 16) ötede; zemin mesafesi 1 karo olmalı.
	assert_almost(Iso.tile_distance(Vector2.ZERO, Vector2(32, 16)), 1.0, 0.001, "komşu karo = 1 karo")
	assert_almost(Iso.tile_distance(Vector2.ZERO, Vector2(-32, 16)), 1.0, 0.001, "diğer eksen de 1 karo")


func test_in_arc_front_and_back() -> void:
	var o := Vector2.ZERO
	var facing := Vector2.RIGHT
	var front := Iso.to_screen(Vector2(Iso.tiles(1.0), 0))
	var back := Iso.to_screen(Vector2(-Iso.tiles(1.0), 0))
	assert_true(CombatMath.in_arc(o, facing, front, 1.5, 110.0), "önündeki hedef vurulur")
	assert_true(not CombatMath.in_arc(o, facing, back, 1.5, 110.0), "arkadaki hedef vurulmaz")
	assert_true(CombatMath.in_arc(o, facing, back, 1.5, 360.0), "tam dairede arkası da vurulur")


func test_in_arc_range_includes_target_radius() -> void:
	var o := Vector2.ZERO
	var t := Iso.to_screen(Vector2(Iso.tiles(1.8), 0))
	assert_true(not CombatMath.in_arc(o, Vector2.RIGHT, t, 1.5, 110.0, 0.0), "1,8 karo menzil dışında")
	assert_true(CombatMath.in_arc(o, Vector2.RIGHT, t, 1.5, 110.0, 0.35), "yarıçapla birlikte menzilde")


func test_in_arc_edge_angle() -> void:
	var o := Vector2.ZERO
	var at_50 := Iso.to_screen(Vector2.RIGHT.rotated(deg_to_rad(50)) * Iso.tiles(1.0))
	var at_60 := Iso.to_screen(Vector2.RIGHT.rotated(deg_to_rad(60)) * Iso.tiles(1.0))
	assert_true(CombatMath.in_arc(o, Vector2.RIGHT, at_50, 1.5, 110.0), "55° yarım açının içinde")
	assert_true(not CombatMath.in_arc(o, Vector2.RIGHT, at_60, 1.5, 110.0), "55° yarım açının dışında")


func test_reduction_and_cap() -> void:
	assert_almost(CombatMath.apply_reduction(100.0, 0.15, 0.75), 85.0, 0.0001, "Warrior %15 zırh")
	assert_almost(CombatMath.apply_reduction(100.0, 0.95, 0.75), 25.0, 0.0001, "tavan %75")


func test_crit_rate_near_base() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var chance := float(DataDB.get_value("progression", "combat.base_crit_chance"))
	var crits := 0
	for i: int in 20000:
		if CombatMath.roll_crit(chance, rng):
			crits += 1
	assert_almost(crits / 20000.0, chance, 0.01, "kritik oranı ≈ %5")


func test_prototype_data_present() -> void:
	var s: Dictionary = DataDB.table("enemies")["enemies"]["skeleton_warrior"]["stats"]
	for k: String in ["hp", "damage", "move_speed", "radius", "attack_range", "attack_windup", "attack_cooldown"]:
		assert_true(s.has(k), "iskelet statı eksik: " + k)
	assert_eq(DataDB.get_value("progression", "feel.hitstop_sec"), 0.06, "GDD: 60 ms hitstop")
	assert_eq(DataDB.get_value("progression", "combat.dash_cooldown"), 1.0, "GDD: Space 1 sn")
	assert_eq(DataDB.get_value("progression", "combat.dash_iframes"), 0.2, "GDD: 0,2 sn dokunulmazlık")


func test_sword_numbers_match_gdd() -> void:
	var sword: Dictionary = DataDB.table("weapon_types")["sword"]
	assert_eq(sword["attacks_per_sec"], 1.4)
	assert_eq(sword["range"], 1.5)
	assert_eq(sword["damage_mult"], 1.0)
