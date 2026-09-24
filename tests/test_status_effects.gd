## Aşama 2: StatusEffects — 6 elementin durumları, donma, boss donma bağışıklığı, sersemletme, Çürüme.
extends "res://tests/test_case.gd"


func _run(st: StatusEffects, seconds: float, step: float = 0.05) -> Dictionary:
	var total := {"burn": 0.0, "poison": 0.0}
	var t := 0.0
	while t < seconds - 0.00001:
		var d := st.tick(step)
		total["burn"] += float(d["burn"])
		total["poison"] += float(d["poison"])
		t += step
	return total


func test_burn_three_seconds_twenty_percent() -> void:
	var st := StatusEffects.new()
	st.apply_element("fire", 100.0)
	assert_true(st.has_element("fire"))
	var dot := _run(st, 5.0)
	assert_almost(float(dot["burn"]), 100.0 * 0.20 * 3.0, 0.01, "3 sn × %20")
	assert_true(not st.has_element("fire"), "3 sn sonra söner")


func test_wet_lasts_four_seconds() -> void:
	var st := StatusEffects.new()
	st.apply_element("water", 50.0)
	_run(st, 3.9)
	assert_true(st.has_element("water"), "3,9 sn'de hâlâ ıslak")
	_run(st, 0.2)
	assert_true(not st.has_element("water"), "4 sn sonra kurur")


func test_poison_stacks_cap_and_damage() -> void:
	var st := StatusEffects.new()
	for i: int in 8:
		st.apply_element("poison", 100.0)
	assert_eq(st.poison_count(), 5, "en fazla 5 yığın")
	var dot := _run(st, 6.0)
	assert_almost(float(dot["poison"]), 5 * 100.0 * 0.08 * 4.0, 0.05, "5 yığın × %8 × 4 sn")
	assert_eq(st.poison_count(), 0, "4 sn sonra yığınlar biter")


func test_ice_slows_then_freezes_at_five() -> void:
	var st := StatusEffects.new()
	for i: int in 4:
		st.apply_element("ice", 10.0)
	assert_eq(st.chill_stacks, 4)
	assert_almost(st.speed_mult(), 0.6, 0.0001, "4 yığın %40 yavaş")
	assert_true(not st.is_frozen())
	var r := st.apply_element("ice", 10.0)
	assert_true(r["froze"], "5. yığında donar")
	assert_true(st.is_frozen())
	assert_true(not st.can_act(), "donmuşken hareket edemez")
	assert_eq(st.speed_mult(), 0.0)
	_run(st, 1.45)
	assert_true(st.is_frozen(), "1,5 sn donuk")
	_run(st, 0.1)
	assert_true(not st.is_frozen(), "sonra çözülür")
	assert_eq(st.chill_stacks, 0, "donunca yığınlar sıfırlanır")


func test_boss_freeze_immunity_eight_seconds() -> void:
	var boss := StatusEffects.new(true)
	assert_true(boss.freeze(2.0), "boss ilk kez donar")
	_run(boss, 2.1)
	assert_true(not boss.is_frozen())
	assert_true(not boss.freeze(2.0), "donmadan sonraki 8 sn bağışık")
	_run(boss, 7.7)
	assert_true(not boss.freeze(2.0), "donma bittikten 7,8 sn sonra hâlâ bağışık")
	_run(boss, 0.3)
	assert_true(boss.freeze(2.0), "donma bittikten 8 sn sonra tekrar donabilir")
	var normal := StatusEffects.new(false)
	normal.freeze(1.0)
	_run(normal, 1.1)
	assert_true(normal.freeze(1.0), "normal düşmanda bağışıklık yok")


func test_stun_normal_vs_boss_slow() -> void:
	var st := StatusEffects.new()
	st.stun(0.8, 1.0, 0.3)
	assert_true(not st.can_act(), "sersem")
	_run(st, 0.85)
	assert_true(st.can_act())
	var boss := StatusEffects.new(true)
	boss.stun(0.8, 1.0, 0.3)
	assert_true(boss.can_act(), "boss sersemlemez")
	assert_almost(boss.speed_mult(), 0.7, 0.0001, "boss yavaşlar")
	_run(boss, 1.05)
	assert_eq(boss.speed_mult(), 1.0)


func test_dark_mark_and_lightning_leaves_nothing() -> void:
	var st := StatusEffects.new()
	st.apply_element("lightning", 100.0)
	assert_true(st.active_list().is_empty(), "yıldırım kalıcı durum bırakmaz")
	st.apply_element("dark", 100.0)
	assert_true(st.has_element("dark"))
	_run(st, 4.05)
	assert_true(not st.has_element("dark"), "Gölge işareti 4 sn")


func test_rot_doubles_poison_and_blocks_healing() -> void:
	var st := StatusEffects.new()
	st.apply_rot(6.0, 2.0)
	assert_true(not st.can_heal(), "Çürüme iyileşmeyi engeller")
	st.apply_element("poison", 100.0)
	var dot := _run(st, 1.0)
	assert_almost(float(dot["poison"]), 100.0 * 0.08 * 2.0, 0.01, "zehir iki kat")


func test_consume_removes_element() -> void:
	var st := StatusEffects.new()
	for el: String in ["fire", "water", "poison", "ice", "dark"]:
		st.apply_element(el, 10.0)
		assert_true(st.has_element(el), el)
		st.consume(el)
		assert_true(not st.has_element(el), "%s tüketildi" % el)
	st.freeze(2.0)
	st.consume("frozen")
	assert_true(not st.is_frozen(), "donma tüketildi")


func test_steam_miss_chance_expires() -> void:
	var st := StatusEffects.new()
	st.apply_steam(4.0, 0.4)
	assert_almost(st.miss_chance(), 0.4, 0.0001)
	_run(st, 4.05)
	assert_eq(st.miss_chance(), 0.0)
