## TestRoom — Aşama 2 savaş çekirdeği test odası: tek izometrik oda, dalga dalga 1. kat düşmanları
## (Taş ve Hayalet varyantlarıyla, bağışıklık ikonları görünür). Oyuncunun iki elementli kılıcı var; Tab ile geçip kombo yapılır.
## Hata ayıklama tuşları: 2-7 aktif silahın elementi, 0 elementsiz, 8 özellik değiştir, N yeni dalga.
## Oda temizlenince ya da oyuncu ölünce R ile yeniden başlanır.
## Komut satırı (geliştirme/test için, "--" sonrasına yazılır):
##   --autoplay        Oyuncuyu bot oynatır; oda temizlenirse çıkış kodu 0, ölürse 2, süre dolarsa 3,
##                     hiç kombo yapılmadıysa 4.
##   --loadout=su,yıldırım  İki silahın elementi (element id: fire, water, lightning, poison, ice, dark, physical).
##   --shots=KLASÖR    Belirli anlarda ekran görüntüsü kaydeder (görsel kontrol için).
##   --shot-times=0.5,2,3   Görüntü alınacak anlar (saniye).
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
@export var pillars: Array[Vector2i] = [Vector2i(4, 4), Vector2i(11, 4), Vector2i(4, 11), Vector2i(11, 11)]
@export var autoplay_timeout_sec: float = 120.0

var player: Player
var world: Node2D
var floor_layer: TileMapLayer
var wall_layer: TileMapLayer
var juice: Juice
var hud: Hud
var camera: Camera2D

var wave_index: int = -1
var finished: bool = false
var rng := RandomNumberGenerator.new()

var _autoplay: bool = false
var _shots_dir: String = ""
var _shot_times: Array[float] = [0.5, 2.0, 3.0, 4.5, 6.0, 8.0]
var _elapsed: float = 0.0
var _between_waves: float = -1.0
var _combo_log: Dictionary = {}
var _loadout: PackedStringArray = ["water", "lightning"]


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--autoplay":
			_autoplay = true
		elif arg.begins_with("--loadout="):
			_loadout = arg.get_slice("=", 1).split(",")
		elif arg.begins_with("--shots="):
			_shots_dir = arg.get_slice("=", 1)
		elif arg.begins_with("--shot-times="):
			_shot_times.clear()
			for t: String in arg.get_slice("=", 1).split(","):
				_shot_times.append(float(t))
	if _autoplay:
		rng.seed = 1
	else:
		rng.randomize()

	if not DataDB.loaded:
		_show_data_error()
		return

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

	player = Player.new()
	player.weapons = []
	for el: String in _loadout:
		var w := Weapon.make("sword", "rare", el)
		_debug_fix_rarity(w)
		player.weapons.append(w)
	player.autoplay = _autoplay
	player.rng.seed = 7 if _autoplay else randi()
	world.add_child(player)
	player.global_position = floor_layer.map_to_local(Vector2i(room_size / 2, room_size / 2))
	player.died.connect(_on_player_died)

	camera = Camera2D.new()
	camera.zoom = Vector2(1.6, 1.6)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	add_child(camera)
	camera.global_position = player.global_position

	juice = Juice.new()
	juice.camera = camera
	add_child(juice)

	hud = Hud.new()
	hud.player = player
	add_child(hud)

	Events.enemy_killed.connect(_on_enemy_killed)
	Events.combo_triggered.connect(func(id: String, _t: Node) -> void:
		_combo_log[id] = int(_combo_log.get(id, 0)) + 1
		if _autoplay:
			print("[TestRoom] kombo %s (%.2f sn)" % [id, _elapsed]))
	_start_wave(0)


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
	if player == null:
		return
	_elapsed += delta
	camera.global_position = player.global_position + Vector2(0, -20)
	if _between_waves > 0.0:
		_between_waves -= delta
		if _between_waves <= 0.0:
			_start_wave(wave_index + 1)
	hud.wave_text = "Dalga %d / %d   ·   Kalan düşman: %d" % [wave_index + 1, waves.size(), _alive_enemies()]
	_handle_debug_capture()
	if _autoplay and _elapsed > autoplay_timeout_sec and not finished:
		print("[TestRoom] SÜRE DOLDU")
		get_tree().quit(3)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key := (event as InputEventKey).keycode
		if DEBUG_ELEMENT_KEYS.has(key) and player and not player.dead:
			_debug_set_element(DEBUG_ELEMENT_KEYS[key])
		elif key == KEY_8 and player and not player.dead:
			_debug_cycle_trait()
		elif key == KEY_N and player and not player.dead:
			finished = false
			_start_wave((wave_index + 1) % waves.size())
		elif key == KEY_R:
			Engine.time_scale = 1.0
			get_tree().reload_current_scene()
		elif key == KEY_ESCAPE:
			get_tree().quit()


func _start_wave(i: int) -> void:
	wave_index = i
	_between_waves = -1.0
	hud.show_message("Dalga %d" % (i + 1))
	get_tree().create_timer(1.2).timeout.connect(func() -> void:
		if not finished:
			hud.show_message(""))
	var free_cells := _spawn_cells()
	for spec: Variant in waves[i]:
		var parts := str(spec).split(":")
		var e := EnemyMelee.new()
		e.enemy_id = parts[0]
		e.material_id = parts[1] if parts.size() > 1 else ""
		e.rng.seed = rng.randi()
		world.add_child(e)
		var idx := rng.randi_range(0, free_cells.size() - 1)
		e.global_position = floor_layer.map_to_local(free_cells[idx])
		free_cells.remove_at(idx)


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


func _on_enemy_killed(_enemy: Node, _elite: bool, _boss: bool) -> void:
	if finished:
		return
	# Sinyal düşman gruptan çıktıktan sonra gelir.
	if _alive_enemies() > 0:
		return
	if wave_index + 1 < waves.size():
		_between_waves = 1.5
	else:
		finished = true
		hud.show_message("Oda temizlendi!\nN: yeni dalga · R: yeniden başla")
		print("[TestRoom] ODA TEMİZLENDİ (%.1f sn, can %d/%d, kombo %d: %s)" % [_elapsed, player.hp, player.max_hp, player.combos_done, _combo_log])
		if _autoplay:
			var code := 0 if player.combos_done > 0 else 4
			if code == 4:
				print("[TestRoom] HİÇ KOMBO YAPILMADI")
			get_tree().create_timer(1.0).timeout.connect(func() -> void: get_tree().quit(code))


func _on_player_died() -> void:
	if finished:
		return
	finished = true
	hud.show_message("Öldün\nR: yeniden başla")
	print("[TestRoom] OYUNCU ÖLDÜ (%.1f sn)" % _elapsed)
	if _autoplay:
		get_tree().create_timer(1.0).timeout.connect(func() -> void: get_tree().quit(2))


func _handle_debug_capture() -> void:
	if _shots_dir == "" or _shot_times.is_empty():
		return
	if _elapsed >= _shot_times[0]:
		var t: float = _shot_times.pop_front()
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		DirAccess.make_dir_recursive_absolute(_shots_dir)
		img.save_png("%s/shot_%04.1f.png" % [_shots_dir, t])


## Hata ayıklama: aktif silahın elementini değiştirir; nadirlik elemente/özelliğe göre ayarlanır.
func _debug_set_element(el: String) -> void:
	var w := player.weapon()
	w.element = el
	_debug_fix_rarity(w)
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
	_debug_fix_rarity(w)
	hud.flash_note("%d. silah: %s" % [player.active_index + 1, w.display_name()])


func _debug_fix_rarity(w: Weapon) -> void:
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
