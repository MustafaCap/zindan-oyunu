## DungeonRun — Aşama 4 ana sahnesi: 4 katlık zindan run'ı.
## Her run yeni bir seed alır; her kat DungeonGenerator ile o seed'den üretilir (GameState.floor_seed). Oyuncu
## giriş odasında başlar, odaları gezer (RoomController kapıları kilitler ve dalgaları yönetir), kat boss'unu keser
## (canı tamamen dolar), boss odasında beliren merdivenle bir alt kata iner. 4. kat boss'u kesilince "Kazandın".
## Gizli oda: bir odanın duvarındaki çatlak bölüme vurarak (yakın saldırı ya da mermi) kırılır.
## Irk, level ve silahlar hata ayıklama menüsünden (M) seçilir; savaş sırasında silah/ırk değiştirilemez
## (GDD: slot değişimi yalnızca oda dışında). Tab ile iki aktif silah arasında geçiş her zaman serbest.
## Komut satırı ("--" sonrasına):
##   --autoplay        Bot oynar: her odayı gezer, gizli duvarı kırar, boss'ları keser, 4 katı bitirir (çıkış 0).
##                     Ölürse 2, süre dolarsa 3, takılırsa 6, gezilemeyen oda kalırsa 7.
##   --god             Oyuncu hasar almaz (smoke testinde haritanın yürünebilirliği denenir).
##   --seed=N          Run seed'i (aynı seed aynı haritaları üretir).   --floor=N   N. kattan başla.
##   --enemy-mult=X    Düşman sayısı çarpanı (smoke testini kısaltmak için).   --reveal   Minimapin tamamını göster.
##   --open-menu       Hata ayıklama menüsü açık başlar.
##   --race=… --level=… --weapons=…   Test odasıyla aynı.   --shots=KLASÖR --shot-times=…  Ekran görüntüsü.
class_name DungeonRun
extends Node2D

const TEST_ROOM_SCENE := "res://scenes/test_room.tscn"

var layout: DungeonLayout
var nav: DungeonNav
var player: Player
var world: Node2D
var floor_layer: TileMapLayer
var wall_layer: TileMapLayer
var camera: Camera2D
var juice: Juice
var hud: Hud
var menu: DebugMenu
var minimap: Minimap

var rooms: Array[RoomController] = []
var props: Array[RoomProp] = []
var visited: Dictionary = {}
var secrets_open: bool = false
var current_room: int = -1
var finished: bool = false
var victory: bool = false

var autoplay: bool = false
var god: bool = false
var enemy_mult: float = -1.0
var start_floor: int = 1
var fixed_seed: int = -1
var _dg: Dictionary
var _entry_zones: Dictionary = {}
var _locked: Dictionary = {}          ## oda id -> true
var _secret_hits: int = 0
var _secret_hit_cd: float = 0.0
var _last_attack_count: int = 0
var _hit_projectiles: Dictionary = {}
var _autopilot: DungeonAutopilot
var _elapsed: float = 0.0
var _floor_elapsed: float = 0.0
var _shots_dir: String = ""
var _shot_times: Array[float] = [1.0, 3.0]
var _prompt_prop: RoomProp
var _boss_node: Node2D
var _active_room: int = -1
var _last_inside: Vector2 = Vector2.INF


func _ready() -> void:
	if TestRoom.config.is_empty():
		TestRoom.config = TestRoom.default_config()
	var config: Dictionary = TestRoom.config
	start_floor = clampi(int(config.get("floor", 1)), 1, 4)
	var reveal := false
	var open_menu := false
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--autoplay":
			autoplay = true
		elif arg == "--god":
			god = true
		elif arg == "--reveal":
			reveal = true
		elif arg == "--open-menu":
			open_menu = true
		elif arg.begins_with("--seed="):
			fixed_seed = int(arg.get_slice("=", 1))
		elif arg.begins_with("--floor="):
			start_floor = clampi(int(arg.get_slice("=", 1)), 1, 4)
		elif arg.begins_with("--enemy-mult="):
			enemy_mult = float(arg.get_slice("=", 1))
		elif arg.begins_with("--race="):
			config["race"] = arg.get_slice("=", 1)
		elif arg.begins_with("--level="):
			config["level"] = int(arg.get_slice("=", 1))
		elif arg.begins_with("--weapons="):
			var specs := arg.get_slice("=", 1).split(",")
			for i: int in mini(specs.size(), 2):
				var parts := specs[i].split(":")
				config["weapons"][i] = {"type": parts[0], "element": parts[1] if parts.size() > 1 else "physical",
					"trait": parts[2] if parts.size() > 2 else ""}
		elif arg.begins_with("--shots="):
			_shots_dir = arg.get_slice("=", 1)
		elif arg.begins_with("--shot-times="):
			_shot_times.clear()
			for t: String in arg.get_slice("=", 1).split(","):
				_shot_times.append(float(t))
	if not DataDB.loaded:
		_show_data_error()
		return
	_dg = DataDB.table("dungeon")
	var cfg_error := TestRoom.validate_config(config)
	if cfg_error != "":
		push_error("[Zindan] " + cfg_error)
		TestRoom.config = TestRoom.default_config()

	world = Node2D.new()
	world.y_sort_enabled = true
	add_child(world)

	camera = Camera2D.new()
	camera.zoom = Vector2(1.6, 1.6)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	add_child(camera)

	juice = Juice.new()
	juice.camera = camera
	juice.hitstop_enabled = not autoplay
	add_child(juice)

	hud = Hud.new()
	hud.stage_text = "Aşama 4 · zindan üretimi"
	add_child(hud)
	hud.set_hints(PackedStringArray([
		"WASD yürü · Fare nişan · Sol/Sağ tık saldırı · Q/E yetenek · Space atılma · Tab silah değiştir · 1 iksir · F etkileşim · Esc çık",
		"M: HATA AYIKLAMA MENÜSÜ (ırk, silah, kat, yeni harita, ölümsüz, test odası) · Çatlak duvarlara vur: gizli oda! · R: yeni run (ölünce)",
	]))

	minimap = Minimap.new()
	minimap.reveal_all = reveal
	minimap.anchor_left = 1.0
	minimap.anchor_right = 1.0
	minimap.offset_left = -372.0
	minimap.offset_right = -32.0
	minimap.offset_top = 60.0
	minimap.offset_bottom = 310.0
	hud.add_child(minimap)

	menu = DebugMenu.new()
	menu.context = "dungeon"
	add_child(menu)
	menu.applied.connect(_on_menu_applied)
	menu.action.connect(_on_menu_action)

	new_run(start_floor)

	if autoplay:
		_autopilot = DungeonAutopilot.new()
		_autopilot.run = self
		add_child(_autopilot)
	if open_menu:
		menu.open.call_deferred(TestRoom.config)
	if _shots_dir != "":
		var shots := TestRoom.ShotTaker.new()
		shots.dir = _shots_dir
		shots.times = _shot_times
		add_child(shots)


func _exit_tree() -> void:
	get_tree().paused = false
	GameState.set_in_combat(false)


# --- run ve katlar ---

## Yeni run: yeni seed, from_floor. katından başlar. Oyuncu aynı ırk/silahlarla ve tam canla başlar.
func new_run(from_floor: int = 1) -> void:
	var seed_value := fixed_seed if fixed_seed >= 0 else randi()
	fixed_seed = -1 if not autoplay else fixed_seed
	GameState.start_run(str(TestRoom.config["race"]))
	GameState.run_seed = seed_value
	finished = false
	victory = false
	_spawn_player(TestRoom.config, false)
	enter_floor(from_floor)
	print("[Zindan] Yeni run: seed %d, %d. kattan" % [seed_value, from_floor])


func enter_floor(index: int) -> void:
	_clear_floor()
	GameState.floor_index = index
	GameState.set_in_combat(false)
	var fl: Dictionary = DataDB.table("floors")["floors"][str(index)]
	layout = DungeonGenerator.generate(index, GameState.floor_seed(index), enemy_mult)
	var ts := IsoTileset.build(Color(str(fl["placeholder_color"])), Color(str(fl["wall_color"])), Color(str(fl["obstacle_color"])))
	floor_layer = TileMapLayer.new()
	floor_layer.tile_set = ts
	floor_layer.z_index = -10
	add_child(floor_layer)
	move_child(floor_layer, 0)
	wall_layer = TileMapLayer.new()
	wall_layer.tile_set = ts
	wall_layer.y_sort_enabled = true
	world.add_child(wall_layer)
	var radius := int(_dg["door_clear_radius"])
	for r: DungeonLayout.Room in layout.rooms:
		_entry_zones[r.id] = layout.entry_zone(r.id, radius)
		var rc := RoomController.new()
		rc.info = r
		rc.run = self
		rc.rng.seed = hash([layout.seed_value, r.id])
		rc.cleared.connect(_on_room_cleared)
		rc.boss_killed.connect(_on_boss_killed)
		add_child(rc)
		rooms.append(rc)
		if r.type in ["chest", "secret", "merchant", "blacksmith"]:
			_add_prop("chest" if r.type == "secret" else r.type, r.id, r.center())
	paint_tiles()
	nav = DungeonNav.new(layout, false)
	player.global_position = cell_to_world(layout.rooms[layout.start_id].center())
	camera.global_position = player.global_position
	camera.reset_smoothing()
	minimap.layout = layout
	minimap.visited = visited
	minimap.cleared = {}
	minimap.secrets_open = false
	_floor_elapsed = 0.0
	Events.floor_entered.emit(index)
	hud.show_message("%d. Kat\n%s" % [index, fl["name"]])
	get_tree().create_timer(2.2).timeout.connect(func() -> void:
		if is_instance_valid(hud) and not finished and GameState.floor_index == index:
			hud.show_message(""))
	if _autopilot:
		_autopilot.on_floor_entered()


func _clear_floor() -> void:
	for rc: RoomController in rooms:
		rc.queue_free()
	rooms.clear()
	for p: RoomProp in props:
		if is_instance_valid(p):
			p.queue_free()
	props.clear()
	for n: Node in get_tree().get_nodes_in_group("enemies"):
		n.remove_from_group("enemies")
		n.queue_free()
	if world:
		for n: Node in world.get_children():
			if n is Projectile or n is GroundEffect or n is EnemyMelee:
				n.queue_free()
	# Eski karolar hemen kalksın: yeni katın ilk fizik adımında eski duvarlar oyuncuyu itmesin
	for layer: TileMapLayer in [floor_layer, wall_layer]:
		if layer and is_instance_valid(layer):
			layer.get_parent().remove_child(layer)
			layer.free()
	visited.clear()
	_entry_zones.clear()
	_locked.clear()
	secrets_open = false
	_secret_hits = 0
	current_room = -1
	_active_room = -1
	_last_inside = Vector2.INF
	_boss_node = null
	hud.boss = null


## Karoları çizer: zemin, duvarlar, engeller, kilitli kapılar ve (kırılmadıysa) çatlak duvar.
func paint_tiles() -> void:
	floor_layer.clear()
	wall_layer.clear()
	var fl := layout.visible_floor(secrets_open)
	for c: Vector2i in fl.keys():
		var alt := IsoTileset.FLOOR_A if (c.x + c.y) % 2 == 0 else IsoTileset.FLOOR_B
		floor_layer.set_cell(c, IsoTileset.FLOOR_SOURCE, alt)
		if layout.is_obstacle(c):
			wall_layer.set_cell(c, IsoTileset.BLOCK_SOURCE, IsoTileset.PILLAR)
	for c: Vector2i in layout.wall_cells(secrets_open):
		wall_layer.set_cell(c, IsoTileset.BLOCK_SOURCE, IsoTileset.WALL)
	if not secrets_open:
		for c: Vector2i in layout.secret_wall_cells:
			wall_layer.set_cell(c, IsoTileset.BLOCK_SOURCE, IsoTileset.CRACKED)
	for rid: int in _locked.keys():
		set_room_locked(rid, true)


# --- RoomController'ın çağırdıkları ---

func set_room_locked(room_id: int, locked: bool) -> void:
	if locked:
		_locked[room_id] = true
	else:
		_locked.erase(room_id)
	var r := layout.rooms[room_id]
	for nid: Variant in r.doors.keys():
		var secret_edge := int(nid) == layout.secret_id and room_id == layout.secret_host_id
		if secret_edge and not secrets_open:
			continue  # çatlak duvar zaten kapalı
		for c: Vector2i in r.doors[nid]:
			if locked:
				wall_layer.set_cell(c, IsoTileset.BLOCK_SOURCE, IsoTileset.DOOR)
			else:
				wall_layer.erase_cell(c)


func spawn_enemy(spec: Dictionary, cell: Vector2i) -> Node2D:
	var e := EnemyMelee.new()
	e.enemy_id = str(spec["id"])
	e.material_id = str(spec.get("material", ""))
	e.rng.seed = hash([layout.seed_value, cell, Time.get_ticks_usec()]) if not autoplay else hash([layout.seed_value, cell])
	if bool(spec.get("elite", false)):
		var pe: Dictionary = _dg["placeholder_elite"]
		e.is_elite = true
		e.hp_mult = float(pe["hp_mult"])
		e.damage_mult = float(pe["damage_mult"])
		e.body_scale = float(pe["scale"])
	if bool(spec.get("boss", false)):
		var pb: Dictionary = _dg["placeholder_boss"]
		e.is_boss = true
		e.hp_mult = float(pb["hp_mult"])
		e.damage_mult = float(pb["damage_mult"])
		e.body_scale = float(pb["scale"])
		var bdata: Dictionary = DataDB.table("bosses")["bosses"][str(spec["boss_id"])]
		e.name_override = "%s (yer tutucu)" % bdata["name"]
	e.navigator = nav_dir
	world.add_child(e)
	e.global_position = cell_to_world(cell)
	_attach_xray(e, Color(1.0, 0.45, 0.4))
	if e.is_boss:
		_boss_node = e
		hud.boss = e
	return e


func on_wave_started(room_id: int, index: int, total: int) -> void:
	var r := layout.rooms[room_id]
	if r.type == "boss":
		hud.show_message(str(_boss_node.get("display_name")) if _boss_node else "Boss")
	elif total > 1:
		hud.show_message("Dalga %d / %d" % [index + 1, total])
	elif r.type == "elite":
		hud.show_message("Elit!")
	get_tree().create_timer(1.2).timeout.connect(func() -> void:
		if is_instance_valid(hud) and not finished:
			hud.show_message(""))


## Engellerin etrafından dolaşan yön (düz uzayda birim vektör); düşmanlar ve bot kullanır.
func nav_dir(from: Vector2, to: Vector2) -> Vector2:
	if nav == null:
		return Iso.to_cart(to - from).normalized()
	return nav.direction(world_to_cell(from), world_to_cell(to), from, to, cell_to_world)


func has_line_of_sight(from: Vector2, to: Vector2) -> bool:
	return nav == null or nav.line_clear(world_to_cell(from), world_to_cell(to))


func entry_zone(room_id: int) -> Dictionary:
	return _entry_zones.get(room_id, {})


func player_position() -> Vector2:
	return player.global_position


func cell_to_world(c: Vector2i) -> Vector2:
	return floor_layer.map_to_local(c)


func world_to_cell(p: Vector2) -> Vector2i:
	return floor_layer.local_to_map(p)


func room_controller(id: int) -> RoomController:
	return rooms[id]


# --- oyuncu ---

## keep_state: aynı run içinde ayar değişti (konum ve iksirler korunur); false: yeni run.
func _spawn_player(cfg: Dictionary, keep_state: bool = true) -> void:
	var pos := Vector2.ZERO
	var potions := -1
	if player and is_instance_valid(player):
		pos = player.global_position
		if keep_state:
			potions = player.potions
		player.remove_from_group("player")
		player.queue_free()
	player = Player.new()
	player.race_id = str(cfg["race"])
	player.level = int(cfg.get("level", 1))
	var list: Array[Weapon] = []
	for wc: Dictionary in cfg["weapons"]:
		list.append(TestRoom.make_weapon(wc))
	player.weapons = list
	player.autoplay = autoplay
	player.invulnerable = god or bool(cfg.get("god", false))
	player.bot_nav = nav_dir
	player.bot_los = has_line_of_sight
	player.rng.seed = 7 if autoplay else randi()
	world.add_child(player)
	player.global_position = pos
	if potions >= 0:
		player.potions = potions
	player.died.connect(_on_player_died)
	hud.player = player
	_attach_xray(player, Color(0.6, 0.85, 1.0))


# --- ana döngü ---

func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player) or layout == null:
		return
	_elapsed += delta
	_floor_elapsed += delta
	camera.global_position = player.global_position + Vector2(0, -20)
	_secret_hit_cd = maxf(_secret_hit_cd - delta, 0.0)
	_update_xray()
	_track_room()
	_check_secret_wall()
	_update_prompt()
	_update_hud()


func _attach_xray(n: Node2D, color: Color) -> void:
	var x := XRayMarker.new()
	x.color = color
	x.body = n.get("visual")
	x.name = "XRay"
	n.add_child(x)


## Önündeki (ekranda altındaki) karolarda duvar/engel varsa karakterin silueti duvarın üstünde görünür.
func _update_xray() -> void:
	for n: Node2D in [player] + get_tree().get_nodes_in_group("enemies"):
		var x := n.get_node_or_null("XRay") as XRayMarker
		if x:
			x.occluded = not bool(n.get("dead")) and is_occluded(n.global_position)


func is_occluded(pos: Vector2) -> bool:
	var c := world_to_cell(pos)
	for dx: int in range(0, 3):
		for dy: int in range(0, 3):
			if (dx == 0 and dy == 0) or dx + dy > 3:
				continue
			if wall_layer.get_cell_source_id(c + Vector2i(dx, dy)) != -1:
				return true
	return false


## Oyuncunun bulunduğu odayı izler; kapı ağzından uzaklaşıp odanın içine girince oda devreye girer.
func _track_room() -> void:
	if player.dead:
		return
	var cell := world_to_cell(player.global_position)
	# Güvenlik: kilitli odanın dışına düşülürse (örn. Gölge adımı kapının ötesine ışınladı) içeri geri alınır
	if GameState.in_combat and _active_room >= 0:
		if layout.room_at(cell) == _active_room and not (_entry_zones[_active_room] as Dictionary).has(cell):
			_last_inside = player.global_position
		elif layout.room_at(cell) != _active_room and _last_inside != Vector2.INF:
			player.global_position = _last_inside
			cell = world_to_cell(_last_inside)
	var rid := layout.room_at(cell)
	if rid == layout.secret_id and not secrets_open:
		rid = -1
	current_room = rid
	minimap.current_room = rid
	if rid < 0:
		return
	if not visited.has(rid):
		visited[rid] = true
		Events.room_entered.emit(rid)
	var rc := rooms[rid]
	if rc.state == RoomController.State.IDLE and not (_entry_zones[rid] as Dictionary).has(cell):
		rc.enter()
		if rc.state == RoomController.State.ACTIVE:
			_active_room = rid
			_last_inside = player.global_position


func _on_room_cleared(room_id: int) -> void:
	minimap.cleared[room_id] = true
	if room_id == _active_room:
		_active_room = -1
		_last_inside = Vector2.INF
	var r := layout.rooms[room_id]
	if r.has_enemies() and r.type != "boss":
		hud.show_message("Oda temizlendi!")
		get_tree().create_timer(1.2).timeout.connect(func() -> void:
			if is_instance_valid(hud) and not finished:
				hud.show_message(""))


func _on_boss_killed(room_id: int, _enemy: Node2D) -> void:
	hud.boss = null
	_boss_node = null
	# GDD: kat boss'u kesilince can tamamen dolar (Ghost dahil)
	player.restore(player.max_hp - player.hp)
	Events.boss_defeated.emit(GameState.floor_index)
	if GameState.floor_index >= 4:
		finished = true
		victory = true
		hud.show_message("KAZANDIN!\nZindanın dibine ulaştın.\nR: yeni run · M: menü")
		if _autopilot:
			_autopilot.report_floor()
		print("[Zindan] ZAFER (%.1f sn)" % _elapsed)
		if autoplay:
			get_tree().create_timer(1.0).timeout.connect(func() -> void: get_tree().quit(0))
		return
	hud.show_message("Boss yenildi!\nCanın doldu · Merdiven açıldı")
	get_tree().create_timer(2.0).timeout.connect(func() -> void:
		if is_instance_valid(hud) and not finished:
			hud.show_message(""))
	_add_prop("stairs", room_id, layout.rooms[room_id].center())


func _on_player_died() -> void:
	if finished:
		return
	finished = true
	hud.show_message("Öldün\n%d. katta, %d oda gezildi\nR: yeni run · M: menü" % [GameState.floor_index, visited.size()])
	print("[Zindan] OYUNCU ÖLDÜ (%d. kat, %.1f sn)" % [GameState.floor_index, _elapsed])
	if autoplay:
		get_tree().create_timer(1.0).timeout.connect(func() -> void: get_tree().quit(2))


# --- etkileşim ---

func _add_prop(kind: String, room_id: int, cell: Vector2i) -> RoomProp:
	var p := RoomProp.new()
	p.kind = kind
	p.room_id = room_id
	world.add_child(p)
	p.global_position = cell_to_world(cell)
	props.append(p)
	return p


func nearest_prop() -> RoomProp:
	var best: RoomProp = null
	var best_d := float(_dg["interact_range_tiles"])
	for p: RoomProp in props:
		if not is_instance_valid(p) or p.prompt() == "":
			continue
		var d := Iso.tile_distance(p.global_position, player.global_position)
		if d <= best_d:
			best_d = d
			best = p
	return best


func _update_prompt() -> void:
	_prompt_prop = nearest_prop() if not player.dead else null
	hud.prompt_text = _prompt_prop.prompt() if _prompt_prop else ""


## F: en yakın nesneyle etkileşim. Merdiven bir alt kata indirir.
func try_interact() -> bool:
	var p := nearest_prop()
	if p == null or finished:
		return false
	if p.kind == "stairs":
		enter_floor(GameState.floor_index + 1)
		return true
	var msg := p.use()
	if msg != "":
		hud.flash_note(msg)
	return true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and not event.is_echo():
		try_interact()
	elif event is InputEventKey and event.pressed and not event.echo:
		var key := (event as InputEventKey).keycode
		if key == KEY_M:
			menu.open(TestRoom.config)
			menu.set_lock_reason("Savaş sürerken ırk ve silahlar değiştirilemez (oda dışında serbest)." if GameState.in_combat else "")
		elif key == KEY_R and finished:
			new_run(1)
		elif key == KEY_ESCAPE:
			get_tree().quit()


# --- gizli oda ---

## Çatlak duvar: oyuncunun yakın saldırısı (menzil içinde ve duvara dönükken) ya da duvara ulaşan mermi bir vuruş
## sayılır; hits_to_break vuruşta kırılır.
func _check_secret_wall() -> void:
	if secrets_open or layout.secret_wall_cells.is_empty() or player.dead:
		return
	var reach := float(_dg["secret_wall"]["reach_tiles"])
	var hit := false
	var count := player.attack_count()
	if count != _last_attack_count:
		_last_attack_count = count
		for c: Vector2i in layout.secret_wall_cells:
			var wp := cell_to_world(c)
			var to_w := Iso.to_cart(wp - player.global_position)
			var d := to_w.length() / Iso.KARO
			if d <= player.attack_range() + reach and to_w.normalized().dot(player.facing_cart) > 0.35:
				hit = true
				break
	for n: Node in world.get_children():
		if n is Projectile and not _hit_projectiles.has(n.get_instance_id()):
			for c: Vector2i in layout.secret_wall_cells:
				if Iso.tile_distance(cell_to_world(c), (n as Node2D).global_position) <= reach:
					_hit_projectiles[n.get_instance_id()] = true
					hit = true
					break
	if hit and _secret_hit_cd <= 0.0:
		_secret_hit_cd = 0.2
		_secret_hits += 1
		var mid := cell_to_world(layout.secret_wall_cells[1])
		Events.hit_landed.emit(mid + Vector2(0, -24), 1.0, false, true, player.facing_cart)
		if _secret_hits >= int(_dg["secret_wall"]["hits_to_break"]):
			open_secret()
		else:
			Events.floating_text.emit(mid + Vector2(0, -60), "Çatlak!", Color(0.85, 0.8, 0.7), 22)


func open_secret() -> void:
	if secrets_open:
		return
	secrets_open = true
	minimap.secrets_open = true
	paint_tiles()
	nav = DungeonNav.new(layout, true)
	var mid := cell_to_world(layout.secret_wall_cells[1])
	Events.enemy_died_fx.emit(mid + Vector2(0, -20), player.facing_cart)
	Events.secret_found.emit(layout.secret_id)
	print("[Zindan] Gizli oda bulundu (%d. kat)" % GameState.floor_index)
	hud.show_message("Gizli oda bulundu!")
	get_tree().create_timer(1.5).timeout.connect(func() -> void:
		if is_instance_valid(hud) and not finished:
			hud.show_message(""))
	if _autopilot:
		_autopilot.on_secret_opened()


# --- HUD ---

func _update_hud() -> void:
	var fl: Dictionary = DataDB.table("floors")["floors"][str(GameState.floor_index)]
	var names: Dictionary = _dg["room_type_names"]
	var room_txt := "Koridor"
	if current_room >= 0:
		var rc := rooms[current_room]
		room_txt = str(names[rc.info.type])
		if rc.state == RoomController.State.ACTIVE:
			room_txt += " · Dalga %d / %d · Kalan düşman %d" % [maxi(rc.wave_index + 1, 1), rc.info.waves.size(), rc.alive_count()]
		elif rc.state == RoomController.State.CLEARED and rc.has_enemies():
			room_txt += " · temizlendi"
	var slot_txt := "SAVAŞ: slot değişimi kapalı" if GameState.in_combat else "Savaş dışı: slot değişimi serbest"
	hud.wave_text = "%d. Kat — %s   ·   %s\n%s   ·   Seed %d%s" % [GameState.floor_index, fl["name"], room_txt, slot_txt,
		GameState.run_seed, "   ·   ÖLÜMSÜZ (test)" if player.invulnerable else ""]


func _on_menu_applied(c: Dictionary) -> void:
	if GameState.in_combat:
		hud.flash_note("Savaş sürerken ırk ve silahlar değiştirilemez")
		return
	TestRoom.config = c
	_spawn_player(c)
	hud.flash_note("Yeni ayar uygulandı")


func _on_menu_action(action_name: String, c: Dictionary) -> void:
	TestRoom.config = c
	match action_name:
		"new_map":
			new_run(int(c.get("floor", 1)))
		"test_room":
			get_tree().change_scene_to_file(TEST_ROOM_SCENE)


func _show_data_error() -> void:
	var layer := CanvasLayer.new()
	var label := Label.new()
	label.text = "VERİ HATASI:\n" + "\n".join(DataDB.errors)
	label.add_theme_color_override("font_color", Color(1, 0.45, 0.45))
	label.add_theme_font_size_override("font_size", 22)
	label.position = Vector2(40, 40)
	layer.add_child(label)
	add_child(layer)
