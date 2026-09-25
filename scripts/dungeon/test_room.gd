## TestRoom — hata ayıklama odası (Aşama 3; Aşama 4'ten beri ana sahne zindan, buraya M menüsünden geçilir): tek izometrik oda, 4 ırk × 12 silah tipi denenebilir.
## M ile hata ayıklama menüsü açılır (ırk, level, iki silahın tipi/elementi/özelliği, düşman türü).
## Düşmanlar: 1. kat dalgaları (Taş ve Hayalet varyantlarıyla) ya da saldırmayan kuklalar.
## Kısayollar: 2-7 aktif silahın elementi, 0 elementsiz, 8 özellik değiştir, N yeni dalga, R yeniden başla.
## Seçilen ayar (config) statik değişkende tutulur; R ile yeniden başlayınca korunur.
## Komut satırı (geliştirme/test için, "--" sonrasına yazılır):
##   --autoplay        Oyuncuyu bot oynatır; oda temizlenirse çıkış kodu 0, ölürse 2, süre dolarsa 3,
##                     hiç kombo yapılmadıysa 4.
##   --race=ghost      Irk (warrior, ghost, archer, magical).   --level=20   Oyuncu leveli.
##   --weapons=sword:water,staff:lightning   İki silah (tip:element[:özellik]).
##   --loadout=su,yıldırım  (Aşama 2 uyumu) iki kılıcın elementi.   --dummies  Kukla modu.
##   --matrix          Her ırk × silah tipi kombinasyonunu sırayla otomatik dener (sol tık, sağ tık, Q, E, Tab);
##                     hepsi çalışırsa çıkış kodu 0, biri bile çalışmazsa 5.
##   --shots=KLASÖR    Belirli anlarda ekran görüntüsü kaydeder.  --shot-times=0.5,2,3  Görüntü anları (saniye).
class_name TestRoom
extends Node2D

@export var room_size: int = 16
## Her dalga düşman listesi: "düşman_id" ya da "düşman_id:malzeme".
var waves: Array = [
	["skeleton_warrior", "skeleton_warrior", "skeleton_warrior"],
	["skeleton_warrior:stone", "skeleton_warrior:ghost", "skeleton_warrior", "skeleton_warrior"],
	["cave_rat", "cave_rat", "cave_rat", "cave_rat", "cave_rat", "vein_mass"],
]
## Hata ayıklama tuşlarıyla seçilebilen elementler (tuş → element).
const DEBUG_ELEMENT_KEYS := {KEY_2: "fire", KEY_3: "water", KEY_4: "lightning", KEY_5: "poison", KEY_6: "ice", KEY_7: "dark", KEY_0: "physical"}
const DEBUG_TRAITS := ["", "fury", "execute", "lifesteal", "ricochet", "stun"]
const DUMMY_HP := 1000000.0
const DUNGEON_SCENE := "res://scenes/game.tscn"
@export var pillars: Array[Vector2i] = [Vector2i(4, 4), Vector2i(11, 4), Vector2i(4, 11), Vector2i(11, 11)]
@export var autoplay_timeout_sec: float = 120.0

## Menüde seçilen ayar; sahne yeniden yüklenince de korunur.
static var config: Dictionary = {}

var player: Player
var world: Node2D
var floor_layer: TileMapLayer
var wall_layer: TileMapLayer
var juice: Juice
var hud: Hud
var menu: DebugMenu
var camera: Camera2D

var wave_index: int = -1
var finished: bool = false
var rng := RandomNumberGenerator.new()

var open_menu_on_start: bool = false
var _autoplay: bool = false
var _matrix: MatrixRunner
var _shots_dir: String = ""
var _shot_times: Array[float] = [0.5, 2.0, 3.0, 4.5, 6.0, 8.0]
var _elapsed: float = 0.0
var _between_waves: float = -1.0
var _combo_log: Dictionary = {}


static func default_config() -> Dictionary:
	return {
		"race": "warrior", "level": 1, "enemies": "waves", "floor": 1,
		"weapons": [
			{"type": "sword", "element": "water", "trait": ""},
			{"type": "sword", "element": "lightning", "trait": ""},
		],
	}


func _ready() -> void:
	process_priority = -10  # matris sürücüsü oyuncudan önce çalışsın
	# Test odası run dışıdır: zindandan gelinse de run ödülleri ve envanter taşınmaz (ustalık kalıcıdır, geçerli)
	GameState.reset_run()
	if config.is_empty():
		config = default_config()
	var matrix_mode := false
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--autoplay":
			_autoplay = true
		elif arg == "--matrix":
			matrix_mode = true
		elif arg == "--dummies":
			config["enemies"] = "dummies"
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
		elif arg.begins_with("--loadout="):
			var els := arg.get_slice("=", 1).split(",")
			for i: int in mini(els.size(), 2):
				config["weapons"][i] = {"type": "sword", "element": els[i], "trait": ""}
		elif arg == "--open-menu":
			open_menu_on_start = true
		elif arg.begins_with("--shots="):
			_shots_dir = arg.get_slice("=", 1)
		elif arg.begins_with("--shot-times="):
			_shot_times.clear()
			for t: String in arg.get_slice("=", 1).split(","):
				_shot_times.append(float(t))
	if _autoplay or matrix_mode:
		rng.seed = 1
	else:
		rng.randomize()

	if not DataDB.loaded:
		_show_data_error()
		return
	var cfg_error := validate_config(config)
	if cfg_error != "":
		push_error("[TestRoom] " + cfg_error)
		config = default_config()

	var floor_color := Color(DataDB.table("floors")["floors"]["1"]["placeholder_color"])
	var ts := IsoTileset.build(floor_color)

	floor_layer = TileMapLayer.new()
	floor_layer.tile_set = ts
	floor_layer.z_index = -10
	add_child(floor_layer)

	world = Node2D.new()
	world.y_sort_enabled = true
	add_child(world)

	wall_layer = TileMapLayer.new()
	wall_layer.tile_set = ts
	wall_layer.y_sort_enabled = true
	world.add_child(wall_layer)

	_build_room()

	camera = Camera2D.new()
	camera.zoom = Vector2(1.6, 1.6)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	add_child(camera)

	juice = Juice.new()
	juice.camera = camera
	add_child(juice)

	hud = Hud.new()
	hud.stage_text = "Test odası"
	add_child(hud)

	menu = DebugMenu.new()
	add_child(menu)
	menu.applied.connect(func(c: Dictionary) -> void:
		config = c
		get_tree().reload_current_scene())
	menu.action.connect(func(_name: String, c: Dictionary) -> void:
		config = c
		get_tree().change_scene_to_file(DUNGEON_SCENE))

	Events.enemy_killed.connect(_on_enemy_killed)
	Events.combo_triggered.connect(_on_combo)

	if matrix_mode:
		juice.hitstop_enabled = false
		_matrix = MatrixRunner.new()
		_matrix.room = self
		add_child(_matrix)
		return

	spawn_player(config)
	camera.global_position = player.global_position
	if config.get("enemies", "waves") == "dummies":
		spawn_dummies()
	else:
		_start_wave(0)
	if _shots_dir != "":
		var shots := ShotTaker.new()
		shots.dir = _shots_dir
		shots.times = _shot_times
		add_child(shots)
	if open_menu_on_start:
		menu.open.call_deferred(config)


func _exit_tree() -> void:
	get_tree().paused = false


## config'e göre oyuncuyu (yeniden) kurar. Eski oyuncu ve onun mermileri kaldırılır.
func spawn_player(cfg: Dictionary) -> Player:
	if player and is_instance_valid(player):
		player.remove_from_group("player")
		player.queue_free()
	for n: Node in world.get_children():
		if n is Projectile or n is GroundEffect:
			n.queue_free()
	player = Player.new()
	player.race_id = str(cfg["race"])
	player.level = int(cfg.get("level", 1))
	var list: Array[Weapon] = []
	for wc: Dictionary in cfg["weapons"]:
		list.append(make_weapon(wc))
	player.weapons = list
	player.autoplay = _autoplay
	player.rng.seed = 7 if (_autoplay or _matrix != null) else randi()
	world.add_child(player)
	player.global_position = floor_layer.map_to_local(Vector2i(room_size / 2, room_size / 2))
	player.died.connect(_on_player_died)
	hud.player = player
	return player


## {"type", "element", "trait"} → Weapon (nadirlik element/özelliğe göre ayarlanır).
static func make_weapon(wc: Dictionary) -> Weapon:
	var traits: Array[String] = []
	if str(wc.get("trait", "")) != "":
		traits.append(str(wc["trait"]))
	var w := Weapon.make(str(wc["type"]), "common", str(wc.get("element", "physical")), traits)
	_fix_rarity(w)
	return w


static func validate_config(cfg: Dictionary) -> String:
	if not DataDB.table("races").has(str(cfg.get("race", ""))):
		return "bilinmeyen ırk '%s'" % cfg.get("race", "")
	for wc: Dictionary in cfg["weapons"]:
		if not DataDB.table("weapon_types").has(str(wc["type"])):
			return "bilinmeyen silah tipi '%s'" % wc["type"]
		var el := str(wc.get("element", "physical"))
		if el != "physical" and not DataDB.table("elements")["elements"].has(el):
			return "bilinmeyen element '%s'" % el
	return ""


func _build_room() -> void:
	for x: int in room_size:
		for y: int in room_size:
			var c := Vector2i(x, y)
			var border := x == 0 or y == 0 or x == room_size - 1 or y == room_size - 1
			if border:
				wall_layer.set_cell(c, IsoTileset.BLOCK_SOURCE, IsoTileset.WALL)
			else:
				var alt := IsoTileset.FLOOR_A if (x + y) % 2 == 0 else IsoTileset.FLOOR_B
				floor_layer.set_cell(c, IsoTileset.FLOOR_SOURCE, alt)
	for p: Vector2i in pillars:
		wall_layer.set_cell(p, IsoTileset.BLOCK_SOURCE, IsoTileset.PILLAR)


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	_elapsed += delta
	camera.global_position = player.global_position + Vector2(0, -20)
	if _between_waves > 0.0:
		_between_waves -= delta
		if _between_waves <= 0.0:
			_start_wave(wave_index + 1)
	if config.get("enemies", "waves") == "dummies":
		hud.wave_text = "Kukla modu · M: menü · N: kuklaları yenile"
	else:
		hud.wave_text = "Dalga %d / %d   ·   Kalan düşman: %d   ·   M: menü" % [wave_index + 1, waves.size(), _alive_enemies()]
	if _autoplay and _elapsed > autoplay_timeout_sec and not finished:
		print("[TestRoom] SÜRE DOLDU")
		get_tree().quit(3)


func _unhandled_input(event: InputEvent) -> void:
	if _matrix:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key := (event as InputEventKey).keycode
		if key == KEY_M:
			menu.open(config)
		elif DEBUG_ELEMENT_KEYS.has(key) and player and not player.dead:
			_debug_set_element(DEBUG_ELEMENT_KEYS[key])
		elif key == KEY_8 and player and not player.dead:
			_debug_cycle_trait()
		elif key == KEY_N and player and not player.dead:
			finished = false
			if config.get("enemies", "waves") == "dummies":
				spawn_dummies()
			else:
				_start_wave((wave_index + 1) % waves.size())
		elif key == KEY_R:
			Engine.time_scale = 1.0
			get_tree().reload_current_scene()
		elif key == KEY_ESCAPE:
			get_tree().quit()


func clear_enemies() -> void:
	for n: Node in get_tree().get_nodes_in_group("enemies"):
		n.remove_from_group("enemies")
		n.queue_free()


## Kukla modu: oyuncunun önünde, saldırmayan ve ölmeyen 5 hedef (biri Taş, biri Hayalet).
func spawn_dummies(offsets: Array = []) -> Array[Enemy]:
	clear_enemies()
	var center := Vector2i(room_size / 2, room_size / 2)
	var cells: Array = offsets if not offsets.is_empty() else [
		[Vector2i(3, 0), ""], [Vector2i(3, 2), "stone"], [Vector2i(3, -2), "ghost"], [Vector2i(5, 1), ""], [Vector2i(5, -1), ""]]
	var out: Array[Enemy] = []
	for c: Array in cells:
		var e := Enemy.new()
		e.enemy_id = "skeleton_warrior"
		e.material_id = str(c[1])
		e.dummy = true
		e.hp_override = DUMMY_HP
		e.facing_cart = Vector2.LEFT
		world.add_child(e)
		var off: Variant = c[0]
		if off is Vector2i:
			e.global_position = floor_layer.map_to_local(center + (off as Vector2i))
		else:
			# Karo cinsinden kesirli konum (matris testi)
			e.global_position = floor_layer.map_to_local(center) + Iso.to_screen((off as Vector2) * Iso.KARO)
		out.append(e)
	return out


func _start_wave(i: int) -> void:
	wave_index = i
	_between_waves = -1.0
	hud.show_message("Dalga %d" % (i + 1))
	get_tree().create_timer(1.2).timeout.connect(func() -> void:
		if not finished and is_instance_valid(hud):
			hud.show_message(""))
	var free_cells := _spawn_cells()
	for spec: Variant in wave_specs(i):
		var parts := str(spec).split(":")
		var e := Enemy.new()
		e.enemy_id = parts[0]
		e.material_id = parts[1] if parts.size() > 1 and parts[1] != "elite" else ""
		e.is_elite = str(spec).ends_with(":elite")
		# Tek tür denemesinde düşman kendi katının gücüyle gelir (kat ölçeklemesi)
		e.floor_index = int(Enemy.record(parts[0]).get("floor", 1)) if str(config.get("enemies", "waves")).contains(":") else 1
		e.rng.seed = rng.randi()
		world.add_child(e)
		var idx := rng.randi_range(0, free_cells.size() - 1)
		e.global_position = floor_layer.map_to_local(free_cells[idx])
		free_cells.remove_at(idx)


## Dalganın düşmanları: "waves" modunda sabit liste; "type:<id>" modunda o türden 3 (sürüde 5); "elite:<id>" modunda
## o türün tek eliti (Aşama 7: menüden her düşman türü ayrı denenebilir).
func wave_specs(i: int) -> Array:
	var mode := str(config.get("enemies", "waves"))
	if mode.begins_with("type:"):
		var id := mode.get_slice(":", 1)
		var out: Array = []
		for k: int in (5 if Enemy.record(id).has("pack") else 3):
			out.append(id)
		return out
	if mode.begins_with("elite:"):
		return [mode.get_slice(":", 1) + ":elite"]
	return waves[i]


## Oyuncudan en az 4 karo uzakta, sütun olmayan zemin karoları.
func _spawn_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for x: int in range(2, room_size - 2):
		for y: int in range(2, room_size - 2):
			var c := Vector2i(x, y)
			if c in pillars:
				continue
			if Iso.tile_distance(floor_layer.map_to_local(c), player.global_position) < 4.0:
				continue
			out.append(c)
	return out


func _alive_enemies() -> int:
	return get_tree().get_nodes_in_group("enemies").size()


func _on_combo(id: String, _t: Node) -> void:
	_combo_log[id] = int(_combo_log.get(id, 0)) + 1
	if _autoplay:
		print("[TestRoom] kombo %s (%.2f sn)" % [id, _elapsed])


func _on_enemy_killed(_enemy: Node, _elite: bool, _boss: bool) -> void:
	if finished or _matrix or config.get("enemies", "waves") == "dummies":
		return
	# Sinyal düşman gruptan çıktıktan sonra gelir.
	if _alive_enemies() > 0:
		return
	if wave_index + 1 < waves.size():
		_between_waves = 1.5
	else:
		finished = true
		hud.show_message("Oda temizlendi!\nN: yeni dalga · R: yeniden başla · M: menü")
		print("[TestRoom] ODA TEMİZLENDİ (%s, %.1f sn, can %d/%d, kombo %d: %s)" % [player.race_id, _elapsed, player.hp, player.max_hp, player.combos_done, _combo_log])
		if _autoplay:
			var code := 0 if player.combos_done > 0 else 4
			if code == 4:
				print("[TestRoom] HİÇ KOMBO YAPILMADI")
			get_tree().create_timer(1.0).timeout.connect(func() -> void: get_tree().quit(code))


func _on_player_died() -> void:
	if finished or _matrix:
		return
	finished = true
	hud.show_message("Öldün\nR: yeniden başla · M: menü")
	print("[TestRoom] OYUNCU ÖLDÜ (%s, %.1f sn)" % [player.race_id, _elapsed])
	if _autoplay:
		get_tree().create_timer(1.0).timeout.connect(func() -> void: get_tree().quit(2))


## Hata ayıklama: aktif silahın elementini değiştirir; nadirlik elemente/özelliğe göre ayarlanır.
func _debug_set_element(el: String) -> void:
	var w := player.weapon()
	w.element = el
	_fix_rarity(w)
	config["weapons"][player.active_index]["element"] = el
	player.refresh_weapon_visual()
	hud.flash_note("%d. silah: %s" % [player.active_index + 1, w.display_name()])


## Hata ayıklama: aktif silahın özelliğini sırayla değiştirir (yok → Öfke → İnfaz → Can Emme → Sekme → Sersemletme).
func _debug_cycle_trait() -> void:
	var w := player.weapon()
	var cur := w.traits[0] if not w.traits.is_empty() else ""
	var next: String = DEBUG_TRAITS[(DEBUG_TRAITS.find(cur) + 1) % DEBUG_TRAITS.size()]
	w.traits.clear()
	if next != "":
		w.traits.append(next)
	_fix_rarity(w)
	config["weapons"][player.active_index]["trait"] = next
	hud.flash_note("%d. silah: %s" % [player.active_index + 1, w.display_name()])


static func _fix_rarity(w: Weapon) -> void:
	if not w.traits.is_empty():
		w.rarity_id = "epic"
	elif w.is_elemental():
		w.rarity_id = "rare"
	else:
		w.rarity_id = "common"


func _show_data_error() -> void:
	var layer := CanvasLayer.new()
	var label := Label.new()
	label.text = "VERİ HATASI:\n" + "\n".join(DataDB.errors)
	label.add_theme_color_override("font_color", Color(1, 0.45, 0.45))
	label.add_theme_font_size_override("font_size", 22)
	label.position = Vector2(40, 40)
	layer.add_child(label)
	add_child(layer)


## Belirli anlarda ekran görüntüsü kaydeder (--shots). Oyun duraklatılmışken (menü açık) de çalışır.
class ShotTaker:
	extends Node
	var dir: String = ""
	var times: Array[float] = []
	var _t: float = 0.0

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _process(delta: float) -> void:
		_t += delta
		if times.is_empty() or _t < times[0]:
			return
		var t: float = times.pop_front()
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		DirAccess.make_dir_recursive_absolute(dir)
		img.save_png("%s/shot_%04.1f.png" % [dir, t])
