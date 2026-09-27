## Audio — ses merkezi (Aşama 9): kanallar (Master, Music, SFX, UI), ses efektleri, müzik ve ses ayarları.
## Efektler assets/audio/sfx/<id>_<n>.wav (tools/audio/sfx_synth.py üretir); hangi olayda hangi sesin çalacağı,
## ses düzeyleri, perde oynaması, aynı anda en fazla kaç tane ve iki çalma arası en az süre data/audio.json'dadır.
## Dünyadaki sesler konumludur (AudioStreamPlayer2D havuzu; dinleyici kamera), arayüz ve oyuncu sesleri ortadan.
## Müzik: kat başına ambiyans döngüsü, boss dövüşünde boss müziği (çapraz geçiş); run bitince söner, zafer/yenilgi vurgusu.
## Ses düzeyleri O tuşuyla açılan panelden (AudioSettingsUI) değiştirilir ve user://settings.json'a kaydedilir.
## Olayları çoğunlukla Events sinyallerinden dinler; saldırı, yetenek, tehlike gibi yerlerden play() doğrudan çağrılır.
extends Node

const BUSES: Array[String] = ["Music", "SFX", "UI"]
const VOLUME_BUSES: Array[String] = ["Master", "Music", "SFX", "UI"]
const SFX_DIR := "res://assets/audio/sfx"
const MUSIC_DIR := "res://assets/audio/music"

## Testler kapatabilir (false iken hiçbir ses çalınmaz; ayarlar yine işler).
var enabled: bool = true
var settings_path: String = "user://settings.json"
var volumes: Dictionary = {}          ## kanal -> 0..1
var muted: bool = false
var music_id: String = ""             ## çalan müzik parçası ("" = yok)
var last_played: String = ""          ## son çalınan ses (testler için)
var play_count: int = 0

var _cfg: Dictionary = {}
var _defaults: Dictionary = {}
var _sounds: Dictionary = {}          ## id -> {streams, db, pitch, poly, gap_ms, bus, positional}
var _last_ms: Dictionary = {}
var _last_variant: Dictionary = {}
var _world: Array[AudioStreamPlayer2D] = []
var _flat: Array[AudioStreamPlayer] = []
var _music: Array[AudioStreamPlayer] = []
var _music_active: int = 0
var _music_tweens: Array[Tween] = [null, null]
var _return_timer: SceneTreeTimer
var _heart_t: float = 0.0
var _hp_check_t: float = 0.0
var _settings_ui: CanvasLayer
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_ensure_buses()
	if not DataDB.loaded:
		return
	_cfg = DataDB.table("audio")
	_defaults = _cfg["defaults"]
	load_settings()
	_build_players()
	_load_sounds()
	var files := 0
	for id: String in _sounds.keys():
		files += (_sounds[id]["streams"] as Array).size()
	print("[Ses] %d ses (%d dosya) yüklendi" % [_sounds.size(), files])
	_connect_events()
	get_tree().node_added.connect(_on_node_added)


## Kapanışta çalan sesler durdurulur ve akışlar bırakılır (kaynak sızıntısı uyarısı çıkmasın).
func _exit_tree() -> void:
	for p: Node in _world + _flat + _music:
		p.call("stop")
		p.set("stream", null)
	_sounds.clear()


# --- kanallar ve ayarlar ---

## Music, SFX ve UI kanalları Master'a bağlanır; Master'ın sonunda tepe sınırlayıcı (çok ses üst üste binince bozulmasın).
func _ensure_buses() -> void:
	for b: String in BUSES:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")
	var m := AudioServer.get_bus_index("Master")
	var has_limiter := false
	for k: int in AudioServer.get_bus_effect_count(m):
		if AudioServer.get_bus_effect(m, k) is AudioEffectHardLimiter:
			has_limiter = true
	if not has_limiter:
		var lim := AudioEffectHardLimiter.new()
		lim.ceiling_db = float(DataDB.get_value("audio", "limiter_ceiling_db")) if DataDB.loaded else -0.5
		AudioServer.add_bus_effect(m, lim)


func default_volumes() -> Dictionary:
	var out := {}
	for b: String in VOLUME_BUSES:
		out[b] = float(_cfg["buses"][b]) if not _cfg.is_empty() else 0.8
	return out


## Ayarları okur; dosya yoksa ya da bozuksa varsayılanlar (bozuk değerler atlanır, 0-1'e sıkıştırılır).
func load_settings() -> void:
	volumes = default_volumes()
	muted = false
	if FileAccess.file_exists(settings_path):
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(settings_path)) == OK and typeof(json.data) == TYPE_DICTIONARY:
			var d: Dictionary = json.data
			var v: Variant = d.get("volumes", {})
			if typeof(v) == TYPE_DICTIONARY:
				for b: String in VOLUME_BUSES:
					var x: Variant = (v as Dictionary).get(b)
					if typeof(x) == TYPE_FLOAT or typeof(x) == TYPE_INT:
						volumes[b] = clampf(float(x), 0.0, 1.0)
			muted = bool(d.get("muted", false)) if typeof(d.get("muted", false)) == TYPE_BOOL else false
	apply_volumes()


func save_settings() -> bool:
	var f := FileAccess.open(settings_path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify({"version": 1, "volumes": volumes, "muted": muted}, "  "))
	f.close()
	return true


func set_volume(bus: String, value: float) -> void:
	volumes[bus] = clampf(value, 0.0, 1.0)
	apply_volumes()


func set_muted(value: bool) -> void:
	muted = value
	apply_volumes()


func apply_volumes() -> void:
	for b: String in VOLUME_BUSES:
		var i := AudioServer.get_bus_index(b)
		if i < 0:
			continue
		var v := float(volumes.get(b, 0.8))
		AudioServer.set_bus_mute(i, v <= 0.001 or (muted and b == "Master"))
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.001)))


# --- oynatıcılar ve sesler ---

func _build_players() -> void:
	var pos: Dictionary = _cfg["positional"]
	for i: int in int(_cfg["pool"]["world"]):
		var p := AudioStreamPlayer2D.new()
		p.max_distance = float(pos["max_distance"])
		p.attenuation = float(pos["attenuation"])
		p.panning_strength = float(pos["panning_strength"])
		p.process_mode = Node.PROCESS_MODE_PAUSABLE   # oyun durunca (envanter, ödül) dünya sesleri de durur
		add_child(p)
		_world.append(p)
	for i: int in int(_cfg["pool"]["flat"]):
		var q := AudioStreamPlayer.new()
		add_child(q)
		_flat.append(q)
	for i: int in 2:
		var m := AudioStreamPlayer.new()
		m.bus = "Music"
		m.volume_db = -80.0
		add_child(m)
		_music.append(m)


func _load_sounds() -> void:
	var sounds: Dictionary = _cfg["sounds"]
	for id: String in DataDB.records(sounds):
		var e: Dictionary = sounds[id]
		var streams: Array[AudioStream] = []
		for n: int in range(1, int(e["variants"]) + 1):
			var path := "%s/%s_%d.wav" % [SFX_DIR, id, n]
			if ResourceLoader.exists(path):
				streams.append(load(path))
		if streams.size() != int(e["variants"]):
			push_warning("[Ses] %s: %d/%d dosya bulunamadı (make sfx)" % [id, int(e["variants"]) - streams.size(), int(e["variants"])])
		_sounds[id] = {
			"streams": streams,
			"db": float(e.get("db", _defaults["db"])),
			"pitch": float(e.get("pitch", _defaults["pitch"])),
			"poly": int(e.get("poly", _defaults["poly"])),
			"gap_ms": int(float(e.get("gap", _defaults["gap"])) * 1000.0),
			"bus": str(e.get("bus", _defaults["bus"])),
			"positional": bool(e.get("positional", _defaults["positional"])),
		}


func has_sound(id: String) -> bool:
	return _sounds.has(id) and not (_sounds[id]["streams"] as Array).is_empty()


## Sesi çalar. pos verilirse (ve ses konumluysa) dünyadaki o noktadan duyulur. Aynı sesin art arda çalınması
## (gap) ve aynı anda çalan sayısı (poly) sınırlıdır; havuz doluysa en eski ses kesilir. Çalındıysa oynatıcıyı döndürür.
func play(id: String, pos: Vector2 = Vector2.INF, pitch_mul: float = 1.0, db_add: float = 0.0) -> Node:
	if not enabled or id == "" or not _sounds.has(id):
		return null
	var s: Dictionary = _sounds[id]
	var streams: Array = s["streams"]
	if streams.is_empty():
		return null
	var now := Time.get_ticks_msec()
	if now - int(_last_ms.get(id, -1000000)) < int(s["gap_ms"]):
		return null
	var positional := bool(s["positional"]) and pos != Vector2.INF
	if _active_count(id) >= int(s["poly"]):
		return null
	_last_ms[id] = now
	var vi := _rng.randi_range(0, streams.size() - 1)
	if streams.size() > 1 and vi == int(_last_variant.get(id, -1)):
		vi = (vi + 1) % streams.size()
	_last_variant[id] = vi
	var p: Node = _take(_world if positional else _flat)
	p.set("stream", streams[vi])
	p.set("bus", str(s["bus"]))
	p.set("volume_db", float(s["db"]) + db_add)
	var pr := float(s["pitch"])
	p.set("pitch_scale", maxf(pitch_mul * (1.0 + _rng.randf_range(-pr, pr)), 0.05))
	if positional:
		(p as AudioStreamPlayer2D).global_position = pos
	p.set_meta("sid", id)
	p.set_meta("t", now)
	p.call("play")
	last_played = id
	play_count += 1
	return p


## Arayüz sesi (konumsuz).
func play_ui(id: String) -> void:
	play(id)


func _active_count(id: String) -> int:
	var n := 0
	for p: Node in _world:
		if (p as AudioStreamPlayer2D).playing and p.get_meta("sid", "") == id:
			n += 1
	for q: Node in _flat:
		if (q as AudioStreamPlayer).playing and q.get_meta("sid", "") == id:
			n += 1
	return n


func _take(pool: Array) -> Node:
	var oldest: Node = pool[0]
	for p: Node in pool:
		if not bool(p.get("playing")):
			return p
		if int(p.get_meta("t", 0)) < int(oldest.get_meta("t", 0)):
			oldest = p
	oldest.call("stop")
	return oldest


## Veri eşlemesinden ses id'si: section.key (ör. "weapons.sword.light"); yoksa "".
func sound_for(path: String) -> String:
	var node: Variant = _cfg
	for part: String in path.split("."):
		if typeof(node) != TYPE_DICTIONARY or not (node as Dictionary).has(part):
			return ""
		node = (node as Dictionary)[part]
	return str(node) if typeof(node) == TYPE_STRING else ""


# --- oyundan çağrılan yardımcılar ---

## Silah saldırısı sesi: kind "light" (sol tık) ya da "heavy" (sağ tık).
func weapon(type_id: String, kind: String, pos: Vector2) -> void:
	play(sound_for("weapons.%s.%s" % [type_id, kind]), pos)


## Düşmanın gövdesi (vuruş ve ölüm sesi için): boss → kendi, malzeme varyantı → malzemenin, yoksa düşmanın ya da varsayılan.
func body_of(enemy: Node) -> String:
	var b: Dictionary = _cfg["body"]
	var boss_id := str(enemy.get("boss_id")) if enemy.get("boss_id") != null else ""
	if boss_id != "" and (b["bosses"] as Dictionary).has(boss_id):
		return str(b["bosses"][boss_id])
	var mat := str(enemy.get("material_id")) if enemy.get("material_id") != null else ""
	if mat != "" and (b["materials"] as Dictionary).has(mat):
		return str(b["materials"][mat])
	var base := str(enemy.get("enemy_id")) if enemy.get("enemy_id") != null else ""
	return str((b["enemies"] as Dictionary).get(base, b["default"]))


## Düşmana isabet: gövdeye göre; kritikte kemik kırılması + parlama, ağır vuruşta (ette) daha ağır ses.
func enemy_hit(enemy: Node2D, crit: bool, heavy: bool) -> void:
	var body := body_of(enemy)
	var pos := enemy.global_position
	if crit:
		play(sound_for("hits.crit"), pos)
		if body != "flesh":
			play(sound_for("hits." + body), pos)
	elif heavy and body == "flesh":
		play(sound_for("hits.heavy"), pos)
	else:
		play(sound_for("hits." + body), pos)


## Element durumu bırakan vuruşun ek sesi.
func element(kind: String, pos: Vector2) -> void:
	play(sound_for("elements." + kind), pos)


## Boss olayları: "roar" (giriş; 2. fazda daha kalın), saldırı başlangıcı.
func boss_roar(boss_id: String, phase2: bool = false) -> void:
	var pitch := float(_cfg["boss_phase2_pitch"]) if phase2 else 1.0
	play(sound_for("bosses.%s.roar" % boss_id), Vector2.INF, pitch)


func boss_attack(boss_id: String, attack_id: String, pos: Vector2) -> void:
	play(sound_for("bosses.%s.attacks.%s" % [boss_id, attack_id]), pos)


## Yerdeki tehlike: işaret belirince (boss'unkilerde) uyarı sesi.
func hazard_warned(h: Node2D, warn: float, from_boss: bool) -> void:
	if from_boss and warn >= float(_cfg["hazards"]["telegraph_min_warn"]):
		play(sound_for("hazards.telegraph"), h.global_position)


## Yerdeki tehlike: uyarı bitip etkin olunca (etikete, yoksa biçim ve türe göre).
func hazard_fired(label: String, mode: String, kind: String, pos: Vector2) -> void:
	var hz: Dictionary = _cfg["hazards"]
	var id := ""
	if (hz["labels"] as Dictionary).has(label):
		id = str(hz["labels"][label])
	elif label.ends_with("_death"):
		id = str((hz["death"] as Dictionary).get(mode, ""))
	elif mode == "burst" or mode == "zone":
		id = str((hz[mode] as Dictionary).get(kind, ""))
	play(id, pos)


# --- müzik ---

func play_music(track_id: String, fade: float = -1.0) -> void:
	if track_id == music_id or _cfg.is_empty():
		return
	var tracks: Dictionary = _cfg["music"]["tracks"]
	if not tracks.has(track_id):
		return
	var path := "%s/%s" % [MUSIC_DIR, str(tracks[track_id]["file"])]
	if not ResourceLoader.exists(path):
		return
	var stream: AudioStream = load(path)
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	if fade < 0.0:
		fade = float(_cfg["music"]["crossfade_sec"])
	_cancel_return()
	var old := _music[_music_active]
	_music_active = 1 - _music_active
	var cur := _music[_music_active]
	music_id = track_id
	cur.stream = stream
	cur.volume_db = -60.0 if fade > 0.0 else float(tracks[track_id]["db"])
	if enabled:
		cur.play()
	_fade(_music_active, float(tracks[track_id]["db"]), fade, false)
	if old.playing:
		_fade(1 - _music_active, -60.0, fade, true)


func stop_music(fade: float = 1.0) -> void:
	_cancel_return()
	music_id = ""
	for i: int in 2:
		if _music[i].playing:
			_fade(i, -60.0, fade, true)


func _fade(i: int, to_db: float, sec: float, stop_after: bool) -> void:
	if _music_tweens[i] and _music_tweens[i].is_valid():
		_music_tweens[i].kill()
	var p := _music[i]
	if sec <= 0.0:
		p.volume_db = to_db
		if stop_after:
			p.stop()
		return
	var tw := create_tween()
	tw.tween_property(p, "volume_db", to_db, sec)
	if stop_after:
		tw.tween_callback(p.stop)
	_music_tweens[i] = tw


func _cancel_return() -> void:
	if _return_timer and _return_timer.timeout.is_connected(_return_to_floor):
		_return_timer.timeout.disconnect(_return_to_floor)
	_return_timer = null


func _return_to_floor() -> void:
	_return_timer = null
	play_music(str(_cfg["music"]["floors"].get(str(GameState.floor_index), "")))


# --- olaylar ---

func _connect_events() -> void:
	Events.floor_entered.connect(_on_floor_entered)
	Events.boss_fight_started.connect(_on_boss_fight_started)
	Events.boss_defeated.connect(_on_boss_defeated)
	Events.run_ended.connect(_on_run_ended)
	Events.player_damaged.connect(func(_a: float) -> void: play("player_hurt"))
	Events.player_died.connect(func() -> void: play("player_death"))
	Events.player_dashed.connect(func(p: Vector2) -> void: play("dash", p))
	Events.weapon_swapped.connect(func(_i: int) -> void: play("weapon_swap"))
	Events.level_up.connect(func(_l: int) -> void: play("level_up"))
	Events.combo_triggered.connect(_on_combo)
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.secret_found.connect(func(_r: int) -> void: play("secret_found"))


func _on_floor_entered(index: int) -> void:
	play_music(str(_cfg["music"]["floors"].get(str(index), "")))


func _on_boss_fight_started(boss_id: String) -> void:
	boss_roar(boss_id)
	play_music(sound_for("bosses.%s.music" % boss_id), float(_cfg["music"]["boss_crossfade_sec"]))


func _on_boss_defeated(floor_index: int) -> void:
	if floor_index >= 4:
		return  # zafer: run_ended müziği kapatır
	_cancel_return()
	_return_timer = get_tree().create_timer(float(_cfg["music"]["return_delay_sec"]))
	_return_timer.timeout.connect(_return_to_floor)


func _on_run_ended(victory: bool, _floor_index: int) -> void:
	stop_music(float(_cfg["music"]["end_fade_sec"]))
	play("victory" if victory else "defeat")


func _on_combo(combo_id: String, target: Node) -> void:
	var pos := (target as Node2D).global_position if target is Node2D else Vector2.INF
	play(sound_for("combos." + combo_id), pos)


func _on_enemy_killed(enemy: Node, is_elite: bool, is_boss: bool) -> void:
	if not enemy is Node2D:
		return
	var pos := (enemy as Node2D).global_position
	if is_boss:
		play(sound_for("deaths.boss"))
		return
	play(sound_for("deaths." + body_of(enemy)), pos)
	if is_elite:
		play(sound_for("deaths.elite"), pos)


# --- kalp atışı, arayüz düğmeleri, ayar paneli ---

func _process(delta: float) -> void:
	if _cfg.is_empty():
		return
	_hp_check_t -= delta
	_heart_t -= delta
	if _hp_check_t > 0.0:
		return
	_hp_check_t = 0.1
	var p := get_tree().get_first_node_in_group("player")
	if p == null or get_tree().paused or bool(p.get("dead")):
		return
	var mx := float(p.get("max_hp"))
	if mx > 0.0 and float(p.get("hp")) / mx < float(_cfg["low_hp"]["threshold"]) and _heart_t <= 0.0:
		_heart_t = float(_cfg["low_hp"]["interval_sec"])
		play("heartbeat")


## Arayüzdeki her düğmeye tıklama ve üzerine gelme sesi (düğmeler hangi ekranda yaratılırsa yaratılsın).
func _on_node_added(n: Node) -> void:
	if n is BaseButton:
		var b := n as BaseButton
		b.pressed.connect(func() -> void: play("ui_click"))
		b.mouse_entered.connect(func() -> void:
			if not b.disabled:
				play("ui_hover"))


## O: ses ayarları paneli (oyun durur). Panel açıkken O ya da Esc kapatır (panel kendi girdisini işler).
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_O:
		toggle_settings()
		get_viewport().set_input_as_handled()


func toggle_settings() -> void:
	if _settings_ui == null:
		_settings_ui = AudioSettingsUI.new()
		add_child(_settings_ui)
	if _settings_ui.visible:
		_settings_ui.call("close")
	else:
		_settings_ui.call("open")
