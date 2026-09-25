## MatrixRunner — Aşama 3 kabul testi: her ırk × silah tipi kombinasyonunu (4 × 12 = 48) hata ayıklama odasında
## sırayla dener. Her denemede oyuncu kuklaların önüne konur ve senaryo oynanır:
##   sol tık → sağ tık (Yay'da basılı tut, Mızrak'ta geri çağır) → E → Q → Tab.
## Başarı: sol ve sağ tık hasar verdi, Q ve E kullanıldı (hasar veren yetenekler hasar da verdi), Tab ile ikinci
## silaha geçildi ve statlar o silahın ailesine göre yeniden hesaplandı. Sonuç tablosu konsola yazılır.
## Çıkış kodu: hepsi geçerse 0, biri bile geçmezse 5.
class_name MatrixRunner
extends Node

const CASE_TIME := 5.4
const LEVEL := 80   ## Mana/enerji senaryonun tamamına yetsin diye (Magical'ın manası level ile artar)
const DAMAGE_ABILITIES := ["shield_charge", "ground_slam", "back_leap", "arrow_rain", "element_storm"]
const ELEMENTS := ["fire", "water", "lightning", "poison", "ice", "dark", "physical"]

var room: Node   ## TestRoom
var cases: Array = []
var index: int = -1
var failures: PackedStringArray = []

var _t: float = 0.0
var _dummy: Node2D
var _second_family: String = ""


func _ready() -> void:
	process_physics_priority = -20
	var type_ids: Array = DataDB.records(DataDB.table("weapon_types"))
	var race_ids: Array = DataDB.records(DataDB.table("races"))
	for ri: int in race_ids.size():
		for ti: int in type_ids.size():
			cases.append([race_ids[ri], type_ids[ti], ELEMENTS[(ri + ti) % ELEMENTS.size()]])
	print("[Matris] %d kombinasyon deneniyor (%d ırk × %d silah tipi)" % [cases.size(), race_ids.size(), type_ids.size()])
	_next()


func _next() -> void:
	index += 1
	if index >= cases.size():
		_finish()
		return
	var c: Array = cases[index]
	var type_id: String = c[1]
	var fam := str(DataDB.table("weapon_types")[type_id]["family"])
	var second := "staff" if fam != "magical" else "sword"
	_second_family = str(DataDB.table("weapon_types")[second]["family"])
	var cfg := {
		"race": c[0], "level": LEVEL, "enemies": "dummies",
		"weapons": [{"type": type_id, "element": c[2], "trait": ""}, {"type": second, "element": "fire", "trait": ""}],
	}
	var dummies: Array[EnemyMelee] = room.spawn_dummies([[Vector2(1.15, 0), ""], [Vector2(2.6, 1.3), ""], [Vector2(2.6, -1.3), ""]])
	_dummy = dummies[0]
	var p: Player = room.spawn_player(cfg)
	p.external_intent = {"aim": _dummy.global_position}
	_t = 0.0


func _physics_process(delta: float) -> void:
	if index < 0 or index >= cases.size():
		return
	var p: Player = room.player
	if p == null or not is_instance_valid(p) or not p.is_inside_tree():
		return
	_t += delta
	var type_id: String = cases[index][1]
	var style := str(DataDB.table("weapon_types")[type_id]["heavy"]["style"])
	var intent := {"aim": _dummy.global_position}
	if _t < 1.3:
		intent["light"] = true
	if _t >= 1.4 and _t - delta < 1.4:
		intent["heavy"] = true
	if _t >= 1.4 and _t < 2.5:
		intent["heavy_held"] = true
	if style == "spear_throw" and _t >= 2.6 and _t - delta < 2.6:
		intent["heavy"] = true   # mızrağı geri çağır
	if _t >= 2.9 and _t - delta < 2.9:
		intent["e"] = true
	if _t >= 4.0 and _t - delta < 4.0:
		intent["q"] = true
	if _t >= 4.8 and _t - delta < 4.8:
		intent["swap"] = true
	p.external_intent = intent
	if _t >= CASE_TIME:
		_evaluate(p)
		_next()


func _evaluate(p: Player) -> void:
	var c: Array = cases[index]
	var race: Dictionary = DataDB.table("races")[c[0]]
	var problems: PackedStringArray = []
	if float(p.damage_by_source["light"]) <= 0.0:
		problems.append("sol tık hasar vermedi")
	if float(p.damage_by_source["heavy"]) <= 0.0:
		problems.append("sağ tık hasar vermedi")
	for slot: String in ["q", "e"]:
		var aid := str(race["abilities"][slot]["id"])
		if int(p.uses[slot]) <= 0:
			problems.append("%s (%s) kullanılamadı" % [slot.to_upper(), aid])
		elif aid in DAMAGE_ABILITIES and float(p.damage_by_source[slot]) <= 0.0:
			problems.append("%s (%s) hasar vermedi" % [slot.to_upper(), aid])
	if p.active_index != 1:
		problems.append("Tab ile geçilemedi")
	elif p.stats.weapon_family != _second_family:
		problems.append("Tab sonrası statlar yenilenmedi")
	var expected := RaceStats.compute(str(c[0]), LEVEL, _second_family).max_hp
	if absf(p.max_hp - expected) > 0.01:
		problems.append("maks can %.1f, beklenen %.1f" % [p.max_hp, expected])
	var line := "%-8s × %-9s %-9s sol %6d · sağ %6d · Q %6d · E %6d" % [c[0], c[1], c[2],
		roundi(p.damage_by_source["light"]), roundi(p.damage_by_source["heavy"]),
		roundi(p.damage_by_source["q"]), roundi(p.damage_by_source["e"])]
	if problems.is_empty():
		print("[Matris] ✓ " + line)
	else:
		print("[Matris] ✗ " + line + "  → " + ", ".join(problems))
		failures.append("%s × %s: %s" % [c[0], c[1], ", ".join(problems)])


func _finish() -> void:
	set_physics_process(false)
	if failures.is_empty():
		print("[Matris] SONUÇ: %d kombinasyonun hepsi çalıştı" % cases.size())
		get_tree().quit(0)
	else:
		print("[Matris] SONUÇ: %d / %d kombinasyonda sorun var" % [failures.size(), cases.size()])
		get_tree().quit(5)
