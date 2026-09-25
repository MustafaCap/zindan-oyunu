## DungeonAutopilot — zindan smoke testinin botu (Aşama 4 kabulü: "4 kat baştan sona yürünebilir").
## Her katta odaları girişten derinlik öncelikli sırayla gezer (boss en sona), çatlak duvarı kırıp gizli odaya girer,
## sandık/tüccar/demirciyle etkileşir, savaş odalarında Player'ın savaş botu dövüşür. Boss kesilince merdivene yürür,
## bir alt kata iner. Yol bulma AStarGrid2D ile karo ızgarasında (engeller ve kapalı çatlak duvar geçilmez).
## Aşama 5: savaş dışında yerdeki silah ve tılsımları toplar (çantada yer varsa), tüccarda satar/alır, demircide
## aktif silahı geliştirir (DungeonRun.bot_merchant / bot_blacksmith). Kat özetinde loot sayıları yazılır.
## Takılırsa (uzun süre ilerleyemezse) çıkış kodu 6, kat süresi dolarsa 3.
class_name DungeonAutopilot
extends Node

const FLOOR_TIMEOUT_SEC := 900.0
const STUCK_SEC := 12.0
const REPATH_SEC := 1.0

var run: DungeonRun
var plan: Array[int] = []
var target_room: int = -1
var astar := AStarGrid2D.new()
var path: Array[Vector2] = []
var _repath_t: float = 0.0
var _progress_t: float = 0.0
var _best_dist: float = INF
var _interacted: Dictionary = {}
var _log: PackedStringArray = []
var _combat_t: float = 0.0
var _status_t: float = 0.0
var _break_t: float = 0.0
var _combat_reported: bool = false
var _ignored_drops: Dictionary = {}


func _ready() -> void:
	process_priority = -5
	on_floor_entered()


func on_floor_entered() -> void:
	if run.layout == null:
		return
	_interacted.clear()
	_build_astar()
	_make_plan()
	target_room = -1
	path.clear()
	_progress_t = 0.0
	print("[Otopilot] %d. kat: %d oda, plan %s" % [GameState.floor_index, run.layout.rooms.size(), plan])


func on_secret_opened() -> void:
	_build_astar()
	path.clear()


## Girişten derinlik öncelikli dolaşma sırası; boss en sonda. Gizli oda, bulunduğu odadan hemen sonra.
func _make_plan() -> void:
	plan.clear()
	var L := run.layout
	var seen := {}
	var stack: Array[int] = [L.start_id]
	while not stack.is_empty():
		var id: int = stack.pop_back()
		if seen.has(id):
			continue
		seen[id] = true
		if id != L.boss_id and id != L.start_id:
			plan.append(id)
		var nbs := L.neighbors(id)
		nbs.sort()
		nbs.reverse()
		for nb: int in nbs:
			if not seen.has(nb):
				stack.append(nb)
	plan.append(L.boss_id)


func _build_astar() -> void:
	var L := run.layout
	astar = AStarGrid2D.new()
	astar.region = L.bounds()
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	astar.fill_solid_region(astar.region, true)
	for c: Vector2i in L.walkable(run.secrets_open).keys():
		astar.set_point_solid(c, false)


func _process(delta: float) -> void:
	var p := run.player
	if p == null or p.dead or run.finished:
		return
	if run._floor_elapsed > FLOOR_TIMEOUT_SEC:
		print("[Otopilot] SÜRE DOLDU (%d. kat)" % GameState.floor_index)
		get_tree().quit(3)
		return
	p.bot_attack_point = Vector2.INF
	_status_t += delta
	if _status_t >= 60.0:
		_status_t = 0.0
		print("[Otopilot] durum: %.0f sn, oda %d, savaş %s, plan %s, oyuncu karo %s, hedef %s" % [run._floor_elapsed,
			run.current_room, GameState.in_combat, plan, run.world_to_cell(p.global_position), _current_goal()])
	# Savaş sürüyor: Player'ın savaş botu dövüşür; dalga arasında odanın ortasına yürü
	if GameState.in_combat:
		_combat_t += delta
		if _combat_t > 90.0 and not _combat_reported:
			_combat_reported = true
			_report_combat()
		var rc := run.room_controller(run.current_room) if run.current_room >= 0 else null
		p.bot_waypoint = run.cell_to_world(rc.info.center()) if rc else Vector2.INF
		_progress_t = 0.0
		return
	_combat_t = 0.0
	_combat_reported = false
	var goal := _current_goal()
	if goal.is_empty():
		return
	var goal_cell: Vector2i = goal["cell"]
	var here := run.world_to_cell(p.global_position)
	var dist := Iso.tile_distance(p.global_position, run.cell_to_world(goal_cell))
	if dist < float(goal.get("arrive", 0.8)):
		p.bot_waypoint = Vector2.INF
		_on_arrived(goal)
		_progress_t = 0.0
		_best_dist = INF
		return
	_repath_t -= delta
	if path.is_empty() or _repath_t <= 0.0:
		_repath_t = REPATH_SEC
		_find_path(here, goal_cell)
	while not path.is_empty() and Iso.tile_distance(p.global_position, path[0]) < 0.45:
		path.remove_at(0)
	p.bot_waypoint = path[0] if not path.is_empty() else run.cell_to_world(goal_cell)
	# Takılma denetimi: kalan yol (karo sayısı) kısalmıyorsa
	var remaining := float(path.size()) + dist * 0.01
	if remaining < _best_dist - 0.5:
		_best_dist = remaining
		_progress_t = 0.0
	else:
		_progress_t += delta
		if _progress_t > STUCK_SEC:
			print("[Otopilot] TAKILDI: %d. kat, hedef %s, oyuncu karo %s" % [GameState.floor_index, goal, here])
			get_tree().quit(6)


## Sıradaki hedef: {"cell", "kind": room/break/interact/stairs, "arrive"}
func _current_goal() -> Dictionary:
	var L := run.layout
	# Yerde silah/tılsım varsa (gezilen odalarda, çantada yer varken) önce onları topla
	var drop := _nearest_item_drop()
	if drop != null:
		return {"cell": run.world_to_cell(drop.global_position), "kind": "pickup", "drop": drop, "arrive": 0.8}
	# Boss kesildiyse merdiven
	for pr: RoomProp in run.props:
		if is_instance_valid(pr) and pr.kind == "stairs":
			return {"cell": run.world_to_cell(pr.global_position), "kind": "stairs", "arrive": 0.9}
	while not plan.is_empty():
		var id: int = plan[0]
		var rc := run.room_controller(id)
		var done := run.visited.has(id) and rc.state == RoomController.State.CLEARED
		var needs_interact := L.rooms[id].type in ["chest", "secret", "merchant", "blacksmith"] and not _interacted.has(id)
		if done and not needs_interact and id != L.boss_id:
			plan.remove_at(0)
			target_room = -1
			continue
		if target_room != id:
			target_room = id
			path.clear()
			_best_dist = INF
			_progress_t = 0.0
		if id == L.secret_id and not run.secrets_open:
			# Çatlak duvarın hemen önündeki karo (kısa menzilli silahlar da yetişsin)
			var inner: Vector2i = L.rooms[L.secret_host_id].door_inner[id]
			return {"cell": inner, "kind": "break", "arrive": 0.5}
		if needs_interact and run.visited.has(id):
			return {"cell": L.rooms[id].center(), "kind": "interact", "room": id, "arrive": 1.0}
		return {"cell": L.rooms[id].center(), "kind": "room", "room": id, "arrive": 1.2}
	return {}


func _on_arrived(goal: Dictionary) -> void:
	var p := run.player
	match str(goal["kind"]):
		"break":
			p.bot_attack_point = run.cell_to_world(run.layout.secret_wall_cells[1])
			_break_t += get_process_delta_time()
			if _break_t > 20.0:
				print("[Otopilot] TAKILDI: çatlak duvar kırılamıyor (%d. kat)" % GameState.floor_index)
				get_tree().quit(6)
		"interact":
			run.try_interact()
			_interacted[int(goal["room"])] = true
			_log.append("%s" % run.layout.rooms[int(goal["room"])].type)
		"stairs":
			_report()
			run.try_interact()
		"pickup":
			var d: LootDrop = goal["drop"]
			if is_instance_valid(d) and not d.picked and not run.pick_up(d):
				_ignored_drops[d.get_instance_id()] = true
		_:
			pass


## Savaş çok uzun sürerse (bot bir düşmana ulaşamıyor olabilir) durumu yazar.
func _report_combat() -> void:
	var p := run.player
	print("[Otopilot] UZUN SAVAŞ: oda %d, oyuncu karo %s" % [run.current_room, run.world_to_cell(p.global_position)])
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		var n := e as Node2D
		var ec := run.world_to_cell(n.global_position)
		var pc := run.world_to_cell(p.global_position)
		print("    %s karo %s oda %d can %.0f durum %s · görüş %s · yön %s · hız %s" % [n.get("display_name"), ec,
			run.layout.room_at(ec), float(n.get("hp")), n.get("state"), run.nav.line_clear(ec, pc),
			run.nav_dir(n.global_position, p.global_position), (n as CharacterBody2D).velocity])


## Kat özeti: gezilen oda sayısı, gizli oda durumu, etkileşimler. Gezilmeyen oda varsa smoke testi düşer.
func report_floor() -> void:
	_report()


func _report() -> void:
	var L := run.layout
	var total := L.rooms.size()
	var missed: Array[int] = []
	for r: DungeonLayout.Room in L.rooms:
		if not run.visited.has(r.id):
			missed.append(r.id)
	var secret := "yok" if L.secret_id < 0 else ("bulundu" if run.secrets_open else "BULUNAMADI")
	print("[Otopilot] %d. kat bitti (%.1f sn): %d/%d oda gezildi, gizli oda %s, etkileşim %s" % [GameState.floor_index,
		run._floor_elapsed, total - missed.size(), total, secret, _log])
	var inv := GameState.inventory
	print("[Otopilot] loot (run toplamı): %s · altın %d · iksir %d · çanta %d/%d dolu · aktif %s" % [run.loot_stats, inv.gold,
		inv.potions, inv.bag.size() - inv.bag_free(), inv.bag.size(), inv.active_weapons().map(func(w: Weapon) -> String: return "%s Lv %d" % [w.display_name(), w.level])])
	_log.clear()
	if not missed.is_empty():
		print("[Otopilot] GEZİLEMEYEN ODALAR: %s" % [missed])
		get_tree().quit(7)


## En yakın toplanacak eşya (gezilmiş odada ya da koridorda, çanta doluysa yok). Ulaşılamayan eşya atlanır.
func _nearest_item_drop() -> LootDrop:
	if GameState.inventory.first_free_bag() < 0:
		return null
	var p := run.player
	var best: LootDrop = null
	var best_d := INF
	for d: LootDrop in run.drops:
		if not is_instance_valid(d) or d.picked or not d.is_item() or _ignored_drops.has(d.get_instance_id()):
			continue
		var rid := run.layout.room_at(run.world_to_cell(d.global_position))
		if rid >= 0 and not run.visited.has(rid):
			continue
		var dist := Iso.tile_distance(p.global_position, d.global_position)
		if dist < best_d:
			best_d = dist
			best = d
	return best


func _find_path(from: Vector2i, to: Vector2i) -> void:
	path.clear()
	var a := _nearest_open(from)
	var b := _nearest_open(to)
	if a == Vector2i(-99999, -99999) or b == Vector2i(-99999, -99999):
		return
	var ids := astar.get_id_path(a, b)
	for c: Vector2i in ids:
		path.append(run.cell_to_world(c))
	if not path.is_empty():
		path.remove_at(0)


func _nearest_open(c: Vector2i) -> Vector2i:
	if astar.is_in_boundsv(c) and not astar.is_point_solid(c):
		return c
	for r: int in range(1, 4):
		for dx: int in range(-r, r + 1):
			for dy: int in range(-r, r + 1):
				var n := c + Vector2i(dx, dy)
				if astar.is_in_boundsv(n) and not astar.is_point_solid(n):
					return n
	return Vector2i(-99999, -99999)
