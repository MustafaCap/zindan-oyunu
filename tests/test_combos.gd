## Aşama 2: Combos ve HitResolver — 7 kombo, ilk elementin tüketilmesi, bağışıklık, boss donma bağışıklığı.
extends "res://tests/test_case.gd"

const FakeTarget := preload("res://tests/fake_target.gd")
const NO_CRIT := {"crit_bonus_chance": -1.0}

var _world: Node2D
var _rng := RandomNumberGenerator.new()


func before_each() -> void:
	_world = Node2D.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(_world)
	_rng.seed = 1234


func after_each() -> void:
	_world.free()


func _target(pos_tiles: Vector2 = Vector2(1, 0), hp: float = 10000.0, boss: bool = false, def: DamageCalc.Defense = null) -> Node2D:
	var t: Node2D = FakeTarget.new()
	t.setup(hp, boss, def)
	_world.add_child(t)
	t.global_position = Iso.to_screen(pos_tiles * Iso.KARO)
	return t


func _attacker() -> Node2D:
	var a: Node2D = FakeTarget.new()
	a.setup()
	_world.add_child(a)
	return a


func _hit(attacker: Node2D, el: String, t: Node2D, others: Array = [], traits: Array[String] = []) -> Dictionary:
	var w := Weapon.make("sword", "rare", el, traits)
	return HitResolver.resolve(attacker, w, t, NO_CRIT, others, _rng)


# --- Combos.find ---

func test_all_seven_combos_found_in_order() -> void:
	var cases := [
		["water", "lightning", "electroshock"], ["fire", "ice", "melt"], ["water", "ice", "freeze"],
		["fire", "poison", "poison_burst"], ["fire", "water", "steam"], ["poison", "dark", "rot"],
	]
	for c: Array in cases:
		var st := StatusEffects.new()
		st.apply_element(c[0], 10.0)
		var f := Combos.find(st, c[1])
		assert_true(not f.is_empty(), "%s + %s kombo olmalı" % [c[0], c[1]])
		if not f.is_empty():
			assert_eq(f["combo"]["id"], c[2])
			assert_eq(f["consumed"], c[0], "ilk element tüketilir")
	var frozen := StatusEffects.new()
	frozen.freeze(2.0)
	var s := Combos.find(frozen, "lightning")
	assert_eq(s.get("combo", {}).get("id", ""), "shatter", "Donmuş + Yıldırım = Kırılma")


func test_order_matters_except_order_free() -> void:
	var st := StatusEffects.new()
	st.apply_element("lightning", 10.0)
	assert_true(Combos.find(st, "water").is_empty(), "yıldırım durum bırakmaz; ters sıra kombo değil")
	var st2 := StatusEffects.new()
	st2.apply_element("dark", 10.0)
	assert_true(Combos.find(st2, "poison").is_empty(), "Karanlık → Zehir kombo değil (sıra önemli)")
	var st3 := StatusEffects.new()
	st3.apply_element("poison", 10.0)
	assert_eq(Combos.find(st3, "fire")["combo"]["id"], "poison_burst", "Zehir → Ateş de patlar (sırasız)")
	assert_eq(Combos.find(st3, "fire")["consumed"], "poison")
	var st4 := StatusEffects.new()
	st4.apply_element("water", 10.0)
	assert_eq(Combos.find(st4, "fire")["combo"]["id"], "steam", "Su → Ateş de Buhar (sırasız)")


func test_same_element_is_not_combo() -> void:
	for el: String in ["fire", "water", "poison", "ice", "dark"]:
		var st := StatusEffects.new()
		st.apply_element(el, 10.0)
		assert_true(Combos.find(st, el).is_empty(), "%s + %s kombo değil" % [el, el])


# --- HitResolver ile sahnede kombolar ---

func test_electroshock_hits_all_wet_and_consumes_water() -> void:
	var a := _attacker()
	var t := _target(Vector2(1, 0))
	var wet2 := _target(Vector2(3, 0))
	var wet_far := _target(Vector2(20, 0))
	var dry := _target(Vector2(1, 2))
	var all := [t, wet2, wet_far, dry]
	for x: Node2D in [t, wet2, wet_far]:
		(x.get("status") as StatusEffects).apply_element("water", 10.0)
	var r := _hit(a, "lightning", t, all)
	assert_eq(r["combo"], "electroshock")
	assert_true(not (t.get("status") as StatusEffects).has_element("water"), "hedefin ıslaklığı tüketildi")
	assert_true(not (wet2.get("status") as StatusEffects).has_element("water"), "menzildeki ıslak düşman çarpıldı")
	assert_true(float(wet2.call("total_damage")) > 0.0, "ıslak komşu hasar aldı")
	assert_true((wet_far.get("status") as StatusEffects).has_element("water"), "menzil dışındaki ıslak etkilenmez")


func test_melt_adds_big_damage() -> void:
	var a := _attacker()
	var plain := _target(Vector2(1, 0))
	_hit(a, "ice", plain)
	var t := _target(Vector2(1, 0))
	(t.get("status") as StatusEffects).apply_element("fire", 10.0)
	var r := _hit(a, "ice", t)
	assert_eq(r["combo"], "melt")
	var bonus := float(DataDB.get_value("elements", "combos")[1]["bonus_damage_pct"])
	assert_almost(float(t.call("total_damage")), float(plain.call("total_damage")) * (1.0 + bonus), 0.01, "Erime ek hasarı")
	assert_true(not (t.get("status") as StatusEffects).has_element("fire"), "ateş tüketildi")


func test_freeze_combo_and_boss_immunity() -> void:
	var a := _attacker()
	var t := _target()
	(t.get("status") as StatusEffects).apply_element("water", 10.0)
	assert_eq(_hit(a, "ice", t)["combo"], "freeze")
	assert_true((t.get("status") as StatusEffects).is_frozen(), "2 sn donar")
	var boss := _target(Vector2(1, 0), 100000.0, true)
	var bst: StatusEffects = boss.get("status")
	bst.apply_element("water", 10.0)
	_hit(a, "ice", boss)
	assert_true(bst.is_frozen(), "boss da ilk seferde donar")
	bst.tick(2.1)
	bst.apply_element("water", 10.0)
	_hit(a, "ice", boss)
	assert_true(not bst.is_frozen(), "boss 8 sn donmaya bağışık")


func test_shatter_is_guaranteed_crit_and_unfreezes() -> void:
	var a := _attacker()
	var t := _target()
	var st: StatusEffects = t.get("status")
	st.freeze(2.0)
	var r := _hit(a, "lightning", t)
	assert_eq(r["combo"], "shatter")
	assert_true(r["crit"], "kritik şansı sıfırken bile kritik")
	assert_true(not st.is_frozen(), "donma tüketildi")


func test_poison_burst_hits_area() -> void:
	var a := _attacker()
	var t := _target(Vector2(1, 0))
	var near := _target(Vector2(2, 0))
	var far := _target(Vector2(8, 0))
	(t.get("status") as StatusEffects).apply_element("poison", 10.0)
	assert_eq(_hit(a, "fire", t, [t, near, far])["combo"], "poison_burst")
	assert_true(float(near.call("total_damage")) > 0.0, "yakındaki düşman patlamadan hasar aldı")
	assert_eq(float(far.call("total_damage")), 0.0, "uzaktaki almadı")


func test_steam_lowers_accuracy_in_area() -> void:
	var a := _attacker()
	var t := _target(Vector2(1, 0))
	var near := _target(Vector2(2, 0))
	(t.get("status") as StatusEffects).apply_element("water", 10.0)
	assert_eq(_hit(a, "fire", t, [t, near])["combo"], "steam")
	assert_true((t.get("status") as StatusEffects).miss_chance() > 0.0, "hedef ıskalar")
	assert_true((near.get("status") as StatusEffects).miss_chance() > 0.0, "yakındaki de ıskalar")


func test_rot_combo() -> void:
	var a := _attacker()
	var t := _target()
	(t.get("status") as StatusEffects).apply_element("poison", 10.0)
	assert_eq(_hit(a, "dark", t)["combo"], "rot")
	assert_true(not (t.get("status") as StatusEffects).can_heal(), "iyileşme engellendi")


func test_immune_target_gets_no_status_or_combo() -> void:
	var a := _attacker()
	var stone := _target(Vector2(1, 0), 1000.0, false, DamageCalc.Defense.new(["lightning"], [], ["ice"]))
	(stone.get("status") as StatusEffects).apply_element("water", 10.0)
	var r := _hit(a, "lightning", stone, [stone])
	assert_eq(r["damage"], 0.0, "taşa yıldırım işlemez")
	assert_eq(r["combo"], "", "bağışık hedefte kombo yok")
	assert_true((stone.get("status") as StatusEffects).has_element("water"), "ıslaklık tüketilmedi")


func test_common_sword_vs_ghost_in_game() -> void:
	var a := _attacker()
	var ghost := _target(Vector2(1, 0), 1000.0, false, DamageCalc.Defense.new(["physical"], [], ["fire"]))
	var w := Weapon.make("sword", "common")
	var r := HitResolver.resolve(a, w, ghost, NO_CRIT, [], _rng)
	assert_almost(float(r["damage"]), 25.0, 0.001, "yaygın kılıç hayalete %25")


func test_lightning_chains_to_two() -> void:
	var a := _attacker()
	var t := _target(Vector2(1, 0))
	var n1 := _target(Vector2(2, 0))
	var n2 := _target(Vector2(1, 1.5))
	var n3 := _target(Vector2(3.5, 0))
	var r := _hit(a, "lightning", t, [t, n1, n2, n3])
	assert_eq((r["chained"] as Array).size(), 2, "2 hedefe sıçrar")
	assert_almost(float(n1.call("total_damage")), float(r["damage"]) * 0.5, 0.01, "%50 hasar")
	assert_eq(float(n3.call("total_damage")), 0.0, "en yakın ikisi seçilir")
