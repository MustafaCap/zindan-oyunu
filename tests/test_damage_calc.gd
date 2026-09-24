## Aşama 2: DamageCalc — hasar formülünün her terimi (GDD: Mimari ve Veri > Hasar formülü).
extends "res://tests/test_case.gd"


func _hit(base: float = 100.0, kind: String = "physical") -> DamageCalc.Hit:
	var h := DamageCalc.Hit.new()
	h.base_damage = base
	h.kind = kind
	return h


func test_full_formula_example() -> void:
	# Destansı (175) Ateş baltası (Ç 1,25), silah level 12 (L 0,10), ustalık 6 (U 0,30), buff +%12,
	# +%20 element hasarı, kritik (+%25 kritik hasarı), %20 zırhlı normal hedef.
	var h := _hit(175.0, "fire")
	h.type_mult = 1.25
	h.weapon_level = 12
	h.mastery_level = 6
	h.damage_buffs = 0.12
	h.element_bonus = 0.2
	h.is_crit = true
	h.crit_damage_bonus = 0.25
	var def := DamageCalc.Defense.new([], [], [], 0.2)
	var expected := 175.0 * 1.25 * 1.10 * 1.30 * 1.12 * 1.2 * 1.75 * 0.8
	assert_almost(DamageCalc.compute(h, def), expected, 0.001, "tüm terimler")


func test_plain_hit_is_base_damage() -> void:
	assert_almost(DamageCalc.compute(_hit(125.0), DamageCalc.Defense.new()), 125.0, 0.0001, "terimsiz vuruş = T")


func test_immune_is_zero() -> void:
	var stone := DamageCalc.Defense.new(["lightning"], [], ["ice"])
	assert_eq(DamageCalc.compute(_hit(125.0, "lightning"), stone), 0.0, "taşa yıldırım 0")
	assert_true(DamageCalc.is_immune("lightning", stone), "bağışık sayılır")


func test_common_weapon_vs_ghost_is_quarter() -> void:
	var ghost := DamageCalc.Defense.new(["physical"], [], ["fire"])
	assert_almost(DamageCalc.compute(_hit(100.0), ghost), 25.0, 0.0001, "yaygın silah hayalete %25")
	assert_true(not DamageCalc.is_immune("physical", ghost), "fiziksel tamamen bağışık sayılmaz (%25 işler)")
	assert_almost(DamageCalc.compute(_hit(125.0, "fire"), ghost), 125.0 * 1.5, 0.0001, "hayalet ateşe zayıf")


func test_resistant_and_weak() -> void:
	var def := DamageCalc.Defense.new([], ["poison"], ["ice"])
	assert_almost(DamageCalc.status_multiplier("poison", def), 0.5, 0.0001, "dirençli 0,5")
	assert_almost(DamageCalc.status_multiplier("ice", def), 1.5, 0.0001, "zayıf 1,5")
	assert_almost(DamageCalc.status_multiplier("fire", def), 1.0, 0.0001, "normal 1")


func test_element_bonus_only_for_elements() -> void:
	var h := _hit(100.0)
	h.element_bonus = 0.5
	assert_almost(DamageCalc.compute(h, DamageCalc.Defense.new()), 100.0, 0.0001, "fiziksele element bonusu işlemez")
	var h2 := _hit(100.0, "fire")
	h2.element_bonus = 0.5
	assert_almost(DamageCalc.compute(h2, DamageCalc.Defense.new()), 150.0, 0.0001, "ateşe +%50 element")


func test_water_deals_lower_damage() -> void:
	var mult := float(DataDB.get_value("elements", "elements.water.damage_mult"))
	assert_true(mult < 1.0, "Su'nun kendi hasarı düşük")
	assert_almost(DamageCalc.compute(_hit(100.0, "water"), DamageCalc.Defense.new()), 100.0 * mult, 0.0001)


func test_crit_term() -> void:
	assert_eq(DamageCalc.crit_term(false, 0.5), 1.0, "kritik değilse 1")
	assert_eq(DamageCalc.crit_term(true, 0.0), 1.5, "kritik 1,5")
	assert_almost(DamageCalc.crit_term(true, 0.25), 1.75, 0.0001, "kritik hasarı bonusu eklenir")


func test_backstab_only_with_dark() -> void:
	assert_almost(DamageCalc.backstab_term("dark", true), 1.1, 0.0001, "karanlık + arkadan 1,1")
	assert_eq(DamageCalc.backstab_term("dark", false), 1.0, "önden 1")
	assert_eq(DamageCalc.backstab_term("fire", true), 1.0, "başka element arkadan 1")
	assert_eq(DamageCalc.backstab_term("physical", true), 1.0, "fiziksel arkadan 1")
	var h := _hit(100.0, "dark")
	h.backstab = true
	assert_almost(DamageCalc.compute(h, DamageCalc.Defense.new()), 110.0, 0.0001)


func test_is_behind_geometry() -> void:
	var target := Vector2.ZERO
	var facing := Vector2.RIGHT  # hedef sağa bakıyor
	var front := Iso.to_screen(Vector2(Iso.tiles(1.0), 0))
	var back := Iso.to_screen(Vector2(-Iso.tiles(1.0), 0))
	var side := Iso.to_screen(Vector2.RIGHT.rotated(deg_to_rad(85)) * Iso.tiles(1.0))
	assert_true(not DamageCalc.is_behind(target, facing, front), "önden vuruş arkadan değil")
	assert_true(DamageCalc.is_behind(target, facing, back), "arkadan vuruş")
	assert_true(not DamageCalc.is_behind(target, facing, side), "yandan (85°) arkadan sayılmaz")


func test_armor_cap() -> void:
	assert_almost(DamageCalc.armor_term(0.2), 0.8, 0.0001)
	assert_almost(DamageCalc.armor_term(0.9), 0.25, 0.0001, "tavan %75")
	assert_almost(DamageCalc.compute(_hit(100.0), DamageCalc.Defense.new([], [], [], 5.0)), 25.0, 0.0001, "aşırı zırhta bile %25 geçer")
	assert_eq(DamageCalc.armor_term(-1.0), 1.0, "negatif zırh yok sayılır")


func test_weapon_level_ratio_steps() -> void:
	var cases := {0: 0.0, 1: 0.0, 4: 0.0, 5: 0.05, 9: 0.05, 10: 0.10, 42: 0.40, 80: 0.80, 99: 0.80}
	for lvl: int in cases.keys():
		assert_almost(DamageCalc.weapon_level_ratio(lvl), cases[lvl], 0.0001, "silah level %d" % lvl)


func test_mastery_bonus() -> void:
	assert_eq(DamageCalc.mastery_bonus(0), 0.0)
	assert_almost(DamageCalc.mastery_bonus(1), 0.05, 0.0001)
	assert_almost(DamageCalc.mastery_bonus(6), 0.30, 0.0001, "GDD tablosu: level 6 +%30")
	assert_almost(DamageCalc.mastery_bonus(12), 0.60, 0.0001, "GDD tablosu: level 12 +%60")
	assert_almost(DamageCalc.mastery_bonus(20), 0.60, 0.0001, "12'de durur")


func test_player_ghost_race_resistances_through_formula() -> void:
	# Ghost ırkı fiziksele dirençli, ateşe zayıf (races.json > resistances)
	var def := DamageCalc.Defense.new([], ["physical"], ["fire"])
	assert_almost(DamageCalc.compute(_hit(20.0), def), 10.0, 0.0001)
	assert_almost(DamageCalc.compute(_hit(20.0, "fire"), def), 30.0, 0.0001)
