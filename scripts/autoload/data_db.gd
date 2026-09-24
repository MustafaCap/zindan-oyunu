## DataDB — data/ klasöründeki tüm denge JSON'larını yükler ve doğrular.
## Oyunda hiçbir denge sayısı koda yazılmaz; hepsi buradan okunur.
## Eksik ya da hatalı bir alan varsa açık bir hata mesajı üretir (errors dizisi + push_error).
extends Node

const DATA_DIR := "res://data"

## Her dosyanın beklenen yapısı.
## - "string" / "number" / "bool" / "array" / "dict": alanın tipi
## - Sözlük: iç içe alanlar
## - "_each": sözlüğün her kaydı bu şemaya uymalı ("_" ile başlayan anahtarlar not sayılır, atlanır)
const SCHEMA := {
	"races": {
		"_each": {
			"name": "string", "family": "string", "base_hp": "number", "hp_per_level": "number",
			"move_speed": "number", "armor": "number",
			"resource": {"type": "string"},
			"costs": "dict", "cooldowns": "dict",
			"abilities": {"q": {"id": "string", "name": "string"}, "e": {"id": "string", "name": "string"}},
			"passive": {"description": "string", "bonuses": "dict"},
			"resistances": "dict",
			"healing": {"potions": "bool", "lifesteal": "bool"},
		},
	},
	"race_weapon_matrix": {"_each": "dict"},
	"weapon_types": {
		"_each": {
			"name": "string", "family": "string", "attacks_per_sec": "number", "range": "number",
			"damage_mult": "number", "heavy": {"id": "string", "name": "string", "description": "string"},
		},
	},
	"rarities": {
		"_each": {"name": "string", "color": "string", "base_damage": "number", "elements": "number", "traits": "array", "unique_passive": "bool"},
	},
	"loot_tables": {
		"floors": {"_each": {"rarity_weights": "dict", "weapon_level": "array"}},
		"legendary_from_floor": "number",
		"upper_rarity_boost": {"sources": "array", "rarities": "array", "multiplier": "number"},
		"boss_min_rarity": "dict",
	},
	"elements": {
		"status_multipliers": {"immune": "number", "resistant": "number", "normal": "number", "weak": "number", "common_vs_ghost": "number"},
		"elements": {"_each": {"name": "string", "status": "string", "description": "string"}},
		"combos": "array",
		"boss_freeze_immunity_sec": "number",
	},
	"traits": {"_each": {"name": "string", "description": "string"}},
	"legendaries": {"passive_templates": "dict", "weapons": "array"},
	"talismans": {"_each": {"name": "string", "description": "string"}},
	"enemies": {
		"materials": {"_each": {"name": "string", "immune": "array", "weak": "array"}},
		"enemies": {"_each": {"name": "string", "floor": "number", "role": "string", "behavior": "string", "immune": "array"}},
	},
	"bosses": {
		"phase2_threshold": "number",
		"first_kill_damage_bonus": "number",
		"bosses": {
			"_each": {
				"name": "string", "floor": "number", "immune": "array", "weak": "array",
				"attacks": "array", "mechanic": {"id": "string", "name": "string"}, "phase2": {"description": "string"},
			},
		},
	},
	"rewards": {
		"choices_per_offer": "number",
		"level_reward_every": "number",
		"level_pool": {"_each": {"name": "string", "value": "number"}},
		"boss_major_pool": {"_each": {"name": "string", "value": "number"}},
		"boss_special_pool": {"_each": {"name": "string", "description": "string"}},
	},
	"progression": {
		"player": {"max_level": "number", "xp_base": "number", "xp_per_level": "number"},
		"enemy_xp": {"_each": {"normal": "number", "elite": "number", "boss": "number"}},
		"weapon": {"max_level": "number", "bonus_step_levels": "number", "bonus_per_step": "number", "catch_up_xp_mult": "number"},
		"mastery": {"max_level": "number", "reference_match_xp": "number", "xp_to_next": "array", "bonus_at_max": "dict", "depth_multipliers": "dict"},
		"stat_caps": "dict",
		"combat": {
			"base_crit_chance": "number", "base_crit_mult": "number", "dash_cooldown": "number", "dash_iframes": "number",
			"non_magical_spell_cooldown_mult": "number", "resonance_locked_pct": "number",
			"resonance_unlocked_pct": "number", "flex_weapon_passive_pct": "number",
			"base_move_speed": "number", "dash_distance": "number", "dash_duration": "number",
			"player_hurt_iframes": "number", "player_radius": "number",
		},
		"feel": {
			"hitstop_sec": "number", "hitstop_heavy_sec": "number", "shake_hit": "number",
			"shake_heavy": "number", "shake_player_hurt": "number", "shake_decay": "number",
			"flash_duration": "number", "knockback_tiles": "number", "knockback_heavy_tiles": "number",
			"knockback_duration": "number",
		},
		"potions": {"start": "number", "max": "number", "heal_pct": "number"},
	},
	"floors": {
		"floors": {
			"_each": {
				"name": "string", "theme": "string", "rooms": "number", "target_minutes": "array",
				"level_range": "array", "enemy_pool": "array", "boss_pool": "array", "placeholder_color": "string",
			},
		},
		"room_types": {"_each": {"description": "string"}},
	},
}

const FAMILIES := ["warrior", "ghost", "archer", "magical"]

var tables: Dictionary = {}
var errors: PackedStringArray = []
var loaded: bool = false
## false ise hatalar konsola basılmaz (testlerde beklenen hatalar için).
var report_errors: bool = true


func _ready() -> void:
	load_all(DATA_DIR)


## Tüm dosyaları yükler. Hata yoksa true döner.
func load_all(dir: String) -> bool:
	tables.clear()
	errors.clear()
	for file_name: String in SCHEMA.keys():
		var path := "%s/%s.json" % [dir, file_name]
		var data: Variant = _read_json(path)
		if data == null:
			continue
		tables[file_name] = data
		_check(data, SCHEMA[file_name], file_name)
	if errors.is_empty():
		_cross_check()
	loaded = errors.is_empty()
	if report_errors:
		for e: String in errors:
			push_error("[DataDB] " + e)
	return loaded


## Bir tabloyu döndürür (örn. table("races")).
func table(name: String) -> Dictionary:
	if not tables.has(name):
		push_error("[DataDB] Bilinmeyen tablo: %s" % name)
		return {}
	return tables[name]


## Nokta ile ayrılmış yol ile değer okur (örn. get_value("progression", "player.max_level")).
func get_value(table_name: String, dotted_path: String) -> Variant:
	var node: Variant = table(table_name)
	for part: String in dotted_path.split("."):
		if typeof(node) != TYPE_DICTIONARY or not (node as Dictionary).has(part):
			push_error("[DataDB] %s.json içinde '%s' bulunamadı" % [table_name, dotted_path])
			return null
		node = (node as Dictionary)[part]
	return node


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		errors.append("%s: dosya bulunamadı" % path)
		return null
	var text := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		errors.append("%s: JSON hatası, satır %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	if typeof(json.data) != TYPE_DICTIONARY:
		errors.append("%s: kök bir nesne ({...}) olmalı" % path)
		return null
	return json.data


func _check(value: Variant, rule: Variant, where: String) -> void:
	if typeof(rule) == TYPE_STRING:
		if not _type_ok(value, rule as String):
			errors.append("%s: '%s' tipinde olmalı, bulunan: %s" % [where, rule, _type_name(value)])
		return
	# rule bir sözlük: value da sözlük olmalı
	if typeof(value) != TYPE_DICTIONARY:
		errors.append("%s: nesne ({...}) olmalı, bulunan: %s" % [where, _type_name(value)])
		return
	var dict: Dictionary = value
	var rules: Dictionary = rule
	for key: String in rules.keys():
		if key == "_each":
			var count := 0
			for sub_key: String in dict.keys():
				if sub_key.begins_with("_"):
					continue
				count += 1
				_check(dict[sub_key], rules["_each"], "%s.%s" % [where, sub_key])
			if count == 0:
				errors.append("%s: en az bir kayıt olmalı" % where)
			continue
		if not dict.has(key):
			errors.append("%s: eksik alan '%s'" % [where, key])
			continue
		_check(dict[key], rules[key], "%s.%s" % [where, key])


func _type_ok(v: Variant, t: String) -> bool:
	match t:
		"string": return typeof(v) == TYPE_STRING
		"number": return typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT
		"bool": return typeof(v) == TYPE_BOOL
		"array": return typeof(v) == TYPE_ARRAY
		"dict": return typeof(v) == TYPE_DICTIONARY
	return false


func _type_name(v: Variant) -> String:
	match typeof(v):
		TYPE_NIL: return "boş"
		TYPE_STRING: return "string"
		TYPE_FLOAT, TYPE_INT: return "number"
		TYPE_BOOL: return "bool"
		TYPE_ARRAY: return "array"
		TYPE_DICTIONARY: return "dict"
	return type_string(typeof(v))


## Dosyalar arası tutarlılık kontrolleri (id referansları, olasılık toplamları...).
func _cross_check() -> void:
	var element_ids: Array = (tables["elements"]["elements"] as Dictionary).keys()
	var damage_kinds: Array = element_ids + ["physical"]

	for race_id: String in _records(tables["races"]):
		var fam: String = tables["races"][race_id]["family"]
		if not fam in FAMILIES:
			errors.append("races.%s.family: bilinmeyen aile '%s'" % [race_id, fam])
		if not tables["race_weapon_matrix"].has(race_id):
			errors.append("race_weapon_matrix: '%s' ırkı için satır yok" % race_id)
		else:
			for f: String in FAMILIES:
				if not (tables["race_weapon_matrix"][race_id] as Dictionary).has(f):
					errors.append("race_weapon_matrix.%s: '%s' ailesi için değer yok" % [race_id, f])

	for wt: String in _records(tables["weapon_types"]):
		var fam2: String = tables["weapon_types"][wt]["family"]
		if not fam2 in FAMILIES:
			errors.append("weapon_types.%s.family: bilinmeyen aile '%s'" % [wt, fam2])

	var rarity_ids: Array = _records(tables["rarities"])
	for floor_id: String in _records(tables["loot_tables"]["floors"]):
		var weights: Dictionary = tables["loot_tables"]["floors"][floor_id]["rarity_weights"]
		var total := 0.0
		for r: String in weights.keys():
			if not r in rarity_ids:
				errors.append("loot_tables.floors.%s: bilinmeyen nadirlik '%s'" % [floor_id, r])
			total += float(weights[r])
		if absf(total - 1.0) > 0.0001:
			errors.append("loot_tables.floors.%s: nadirlik oranlarının toplamı 1 olmalı (bulunan %.4f)" % [floor_id, total])

	for c: Variant in tables["elements"]["combos"]:
		var combo: Dictionary = c
		for k: String in ["id", "name", "first", "second"]:
			if not combo.has(k):
				errors.append("elements.combos: bir kombo kaydında '%s' eksik" % k)

	var enemy_ids: Array = _records(tables["enemies"]["enemies"])
	for eid: String in enemy_ids:
		for imm: Variant in tables["enemies"]["enemies"][eid]["immune"]:
			if not imm in damage_kinds:
				errors.append("enemies.%s.immune: bilinmeyen hasar türü '%s'" % [eid, imm])
	var boss_ids: Array = _records(tables["bosses"]["bosses"])
	for bid: String in boss_ids:
		for k2: String in ["immune", "weak"]:
			for el: Variant in tables["bosses"]["bosses"][bid][k2]:
				if not el in damage_kinds:
					errors.append("bosses.%s.%s: bilinmeyen hasar türü '%s'" % [bid, k2, el])

	for fid: String in _records(tables["floors"]["floors"]):
		var fl: Dictionary = tables["floors"]["floors"][fid]
		for e: Variant in fl["enemy_pool"]:
			if not e in enemy_ids:
				errors.append("floors.%s.enemy_pool: bilinmeyen düşman '%s'" % [fid, e])
		for b: Variant in fl["boss_pool"]:
			if not b in boss_ids:
				errors.append("floors.%s.boss_pool: bilinmeyen boss '%s'" % [fid, b])
		if not tables["progression"]["enemy_xp"].has(fid):
			errors.append("progression.enemy_xp: %s. kat için XP değerleri yok" % fid)
		if not tables["loot_tables"]["floors"].has(fid):
			errors.append("loot_tables.floors: %s. kat için tablo yok" % fid)

	var mastery: Dictionary = tables["progression"]["mastery"]
	if (mastery["xp_to_next"] as Array).size() != int(mastery["max_level"]) - 1:
		errors.append("progression.mastery.xp_to_next: %d eleman olmalı (max_level - 1)" % (int(mastery["max_level"]) - 1))


func _records(d: Dictionary) -> Array:
	var out: Array = []
	for k: String in d.keys():
		if not k.begins_with("_"):
			out.append(k)
	return out
