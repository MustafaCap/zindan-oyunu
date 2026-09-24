## Testlerde HitResolver için sahte hedef/saldıran (EnemyMelee'nin savaş arayüzünün küçük bir kopyası).
extends Node2D

var dead: bool = false
var hp: float = 1000.0
var max_hp: float = 1000.0
var is_boss: bool = false
var radius_tiles: float = 0.35
var facing_cart: Vector2 = Vector2.LEFT
var defense := DamageCalc.Defense.new()
var status: StatusEffects
var fury_stacks: int = 0
var hits: Array[Dictionary] = []
var healed: float = 0.0
var executed: bool = false


func setup(p_hp: float = 1000.0, boss: bool = false, def: DamageCalc.Defense = null) -> Node2D:
	hp = p_hp
	max_hp = p_hp
	is_boss = boss
	status = StatusEffects.new(boss)
	if def != null:
		defense = def
	return self


func apply_damage(amount: float, info: Dictionary) -> void:
	if dead:
		return
	var rec := info.duplicate()
	rec["amount"] = amount
	hits.append(rec)
	hp = maxf(hp - amount, 0.0)
	if hp <= 0.0:
		dead = true


func execute(_dir: Vector2) -> void:
	executed = true
	hp = 0.0
	dead = true


func heal(amount: float) -> void:
	healed += amount


func total_damage() -> float:
	var t := 0.0
	for h: Dictionary in hits:
		t += float(h["amount"])
	return t
