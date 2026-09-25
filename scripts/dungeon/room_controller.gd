## RoomController — bir odanın oyun içi akışı (GDD Uygulama Rehberi, Aşama 4.3).
## Düşmanlı oda (savaş, elit, boss): oyuncu kapı ağzından içeri girince kapılar kilitlenir, dalgalar sırayla gelir,
## son dalga ölünce kapılar açılır ve oda "temizlendi" olur. Kilitliyken GameState.in_combat = true (slot değişimi
## yasak); açılınca false. Düşmansız odalar (giriş, tüccar, demirci, sandık, gizli) girildiği anda temizlenmiş sayılır.
class_name RoomController
extends Node

signal cleared(room_id: int)
signal boss_killed(room_id: int, enemy: Node2D)

enum State { IDLE, ACTIVE, CLEARED }

var info: DungeonLayout.Room
var run: Node                     ## DungeonRun (kapıları kilitler, düşmanları sahneye koyar)
var state: State = State.IDLE
var wave_index: int = -1
var alive: Array[Node2D] = []
var rng := RandomNumberGenerator.new()
var _delay: float = -1.0
var _waves_cfg: Dictionary
var _boss: Node2D
var _last_valid: Dictionary = {}   ## düşman instance id -> odanın içindeki son konumu


func _ready() -> void:
	_waves_cfg = DataDB.table("dungeon")["waves"]
	Events.enemy_killed.connect(_on_enemy_killed)


func _exit_tree() -> void:
	if Events.enemy_killed.is_connected(_on_enemy_killed):
		Events.enemy_killed.disconnect(_on_enemy_killed)


func has_enemies() -> bool:
	return info.has_enemies()


func alive_count() -> int:
	var n := 0
	for e: Node2D in alive:
		if is_instance_valid(e) and not e.get("dead"):
			n += 1
	return n


## Savaş sırasında sonradan gelen düşman (çağrılan Gölge, boss yardımcıları): oda o ölmeden temizlenmez.
func register(e: Node2D) -> void:
	if state == State.ACTIVE and not e in alive:
		alive.append(e)


## Oyuncu odanın iç kısmına girdi.
func enter() -> void:
	if state != State.IDLE:
		return
	if not has_enemies():
		state = State.CLEARED
		cleared.emit(info.id)
		return
	state = State.ACTIVE
	run.call("set_room_locked", info.id, true)
	GameState.set_in_combat(true)
	_delay = float(_waves_cfg["first_wave_delay_sec"])


func _process(delta: float) -> void:
	if state != State.ACTIVE:
		return
	if _delay > 0.0:
		_delay -= delta
		if _delay <= 0.0:
			_spawn_wave(wave_index + 1)
		return
	_keep_inside()
	if alive_count() > 0:
		return
	if wave_index + 1 < info.waves.size():
		_delay = float(_waves_cfg["wave_delay_sec"])
	else:
		_finish()


func _spawn_wave(i: int) -> void:
	wave_index = i
	alive.clear()
	var specs: Array = info.waves[i]
	var cells := _spawn_cells()
	for spec: Dictionary in specs:
		var cell: Vector2i
		if bool(spec.get("boss", false)) or cells.is_empty():
			cell = info.center()
		else:
			var idx := rng.randi_range(0, cells.size() - 1)
			cell = cells[idx]
			cells.remove_at(idx)
		var e: Node2D = run.call("spawn_enemy", spec, cell)
		alive.append(e)
		if bool(spec.get("boss", false)):
			_boss = e
	run.call("on_wave_started", info.id, i, info.waves.size())


func _on_enemy_killed(enemy: Node, _elite: bool, is_boss: bool) -> void:
	if is_boss and _boss != null and enemy == _boss:
		_boss = null
		boss_killed.emit(info.id, enemy as Node2D)


## Güvenlik ağı: bir düşman itilerek duvarın ya da engelin içine/ötesine geçerse odanın içindeki son konumuna döner.
func _keep_inside() -> void:
	for e: Node2D in alive:
		if not is_instance_valid(e) or e.get("dead"):
			continue
		var c: Vector2i = run.call("world_to_cell", e.global_position)
		var id := e.get_instance_id()
		if info.cells.has(c) and not info.obstacles.has(c):
			_last_valid[id] = e.global_position
		elif _last_valid.has(id):
			e.global_position = _last_valid[id]
		else:
			e.global_position = run.call("cell_to_world", info.center())


## Doğma karoları: engel değil, kapı ağzına yakın değil, oyuncudan en az spawn_min_distance_tiles uzakta.
func _spawn_cells() -> Array[Vector2i]:
	var zone: Dictionary = run.call("entry_zone", info.id)
	var player_pos: Vector2 = run.call("player_position")
	var min_d := float(_waves_cfg["spawn_min_distance_tiles"])
	var out: Array[Vector2i] = []
	var near: Array[Vector2i] = []
	for c: Vector2i in info.free_cells():
		if zone.has(c) or _touches_obstacle(c):
			continue
		var d := Iso.tile_distance(run.call("cell_to_world", c), player_pos)
		if d >= min_d:
			out.append(c)
		elif d >= 2.0:
			near.append(c)
	out.sort()
	return out if out.size() >= 4 else out + near


func _touches_obstacle(c: Vector2i) -> bool:
	for dx: int in range(-1, 2):
		for dy: int in range(-1, 2):
			var n := c + Vector2i(dx, dy)
			if info.obstacles.has(n) or not info.cells.has(n):
				return true
	return false


func _finish() -> void:
	state = State.CLEARED
	run.call("set_room_locked", info.id, false)
	GameState.set_in_combat(false)
	Events.room_cleared.emit(info.id)
	cleared.emit(info.id)
