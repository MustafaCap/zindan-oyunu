## NyxCopy — Nyx'thar'ın sahte kopyası (Gölge Kopyaları). Gerçeğiyle aynı görünür ama yere gölge düşürmez.
## Vurulunca (hasar almaz) oyuncunun yanına ışınlanır, yerde işaretli bir kesik atar ve dağılır. Süresi dolunca da dağılır.
## Ödül vermez; gerçek Nyx'thar vurulunca ya da ölünce bütün kopyalar dağılır.
class_name NyxCopy
extends Enemy

var boss: Boss
var lifetime: float = 10.0
var hit_warn: float = 0.6
var hit_mult: float = 0.8
var fake_hp: float = 1000.0
var _life: float = 0.0
var _triggered: bool = false


func _setup_stats() -> void:
	data = {"name": boss.display_name, "placeholder_color": "#30284a", "ai": "inert"}
	ai = "inert"
	attack = {"type": "none"}
	attack_type = "none"
	max_hp = fake_hp
	hp = max_hp
	damage = boss.damage
	move_speed_tiles = 0.0
	radius_tiles = boss.radius_tiles
	attack_range = 1.0
	attack_arc = 90.0
	windup = 1.0
	attack_cd_max = 1.0
	knockback_resist = 1.0
	body_scale = boss.body_scale
	display_name = boss.display_name
	defense = DamageCalc.Defense.new(boss.defense.immune.duplicate(), [], boss.defense.weak.duplicate(), 0.0)
	status = StatusEffects.new(true)


func _ready() -> void:
	super._ready()
	visual.body_height = boss.visual.body_height
	visual.body_width = boss.visual.body_width
	visual.show_weapon = false
	visual.show_shadow = false
	_base_modulate = Color(1, 1, 1, 0.85)


func _physics_process(delta: float) -> void:
	if dead:
		return
	_life += delta
	_anim_t += delta
	if _life >= lifetime and not _triggered:
		dissolve()
		return
	if boss == null or not is_instance_valid(boss) or boss.dead:
		dissolve()
		return
	facing_cart = boss.facing_cart
	visual.set_facing(facing_cart)
	_update_tint()
	queue_redraw()


## Sahteye vurulunca: oyuncunun yanına ışınlanıp işaretli kesik atar, sonra dağılır.
func apply_damage(_amount: float, info: Dictionary) -> void:
	if dead or _triggered or bool(info.get("secondary", false)):
		return
	_triggered = true
	Events.floating_text.emit(global_position + Vector2(0, -80), "SAHTE!", Color(0.8, 0.6, 1.0), 22)
	var p := get_tree().get_first_node_in_group("player") as Player
	if p == null or boss == null or not is_instance_valid(boss):
		dissolve()
		return
	var side := p.facing_cart.orthogonal() * (1.0 if randf() < 0.5 else -1.0)
	var spot := p.global_position + Iso.to_screen(side * Iso.tiles(1.3))
	if boss.arena and not boss.arena.inside(spot):
		spot = p.global_position + Iso.to_screen(-side * Iso.tiles(1.3))
	Events.area_pulse.emit(global_position, 0.8, Color(0.5, 0.35, 0.8))
	global_position = spot
	var dir := Iso.to_cart(p.global_position - spot).normalized()
	facing_cart = dir
	boss.hazard("shadow_copies_fake", spot, "arc", hit_warn, hit_mult, {"radius": 2.2, "arc_degrees": 140.0, "dir_cart": dir, "kind": "dark", "color": Color(0.7, 0.2, 0.6)})
	get_tree().create_timer(hit_warn + 0.15, false).timeout.connect(func() -> void:
		if is_instance_valid(self):
			dissolve())


func execute(_dir: Vector2) -> void:
	apply_damage(1.0, {})


func dissolve() -> void:
	if dead:
		return
	no_reward = true
	hp = 0.0
	dead = true
	_set_state(State.DEAD)
	remove_from_group("enemies")
	collision_layer = 0
	collision_mask = 0
	Events.area_pulse.emit(global_position, 0.8, Color(0.4, 0.3, 0.6))
	var tw := create_tween()
	tw.tween_property(visual, "modulate:a", 0.0, 0.3)
	tw.tween_callback(queue_free)
