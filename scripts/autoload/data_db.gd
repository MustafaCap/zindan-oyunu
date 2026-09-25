## DataDB — data/ klasöründeki tüm denge JSON'larını yükler ve doğrular.
## Oyunda hiçbir denge sayısı koda yazılmaz; hepsi buradan okunur.
## Eksik ya da hatalı bir alan varsa açık bir hata mesajı üretir (errors dizisi + push_error).
extends Node

const DATA_DIR := "res://data"
## Ödül havuzlarında kullanılabilen statlar (Player/RaceStats bunları işler) ve boss özel etkileri (Aşama 6).
const REWARD_STATS := ["attack_speed", "damage", "element_damage", "skill_damage", "max_hp", "crit_chance", "crit_damage",
	"attack_range", "move_speed", "cooldown_reduction", "dash_cooldown_reduction", "damage_reduction", "lifesteal",
	"xp_gain", "gold_find"]
const SPECIAL_EFFECTS := ["double_hit", "extra_projectile", "piercing", "element_trail", "combo_master", "crit_chain",
	"resonance_boost", "wrath", "executioner", "spare_potion", "second_chance"]

## Her dosyanın beklenen yapısı.
## - "string" / "number" / "bool" / "array" / "dict": alanın tipi
## - Sözlük: iç içe alanlar
## - "_each": sözlüğün her kaydı bu şemaya uymalı ("_" ile başlayan anahtarlar not sayılır, atlanır)
const SCHEMA := {
	"races": {
		"_each": {
			"name": "string", "family": "string", "placeholder_color": "string", "base_hp": "number", "hp_per_level": "number",
			"move_speed": "number", "armor": "number",
			"resource": {"type": "string", "name": "string", "color": "string"},
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
			"name": "string", "name_compound": "string", "family": "string", "attacks_per_sec": "number", "range": "number",
			"damage_mult": "number", "arc_degrees": "number", "visual": "string",
			"light": {"style": "string"},
			"heavy": {"id": "string", "name": "string", "description": "string", "style": "string"},
		},
	},
	"rarities": {
		"_each": {"name": "string", "color": "string", "base_damage": "number", "elements": "number", "traits": "array", "unique_passive": "bool"},
	},
	"loot_tables": {
		"floors": {"_each": {"rarity_weights": "dict", "weapon_level": "array"}},
		"legendary_from_floor": "number",
		"upper_rarity_boost": {"sources": "array", "rarities": "array", "multiplier": "number"},
	},
	"elements": {
		"status_multipliers": {"immune": "number", "resistant": "number", "normal": "number", "weak": "number", "common_vs_ghost": "number"},
		"physical": {"name": "string", "color": "string"},
		"elements": {"_each": {"name": "string", "color": "string", "status": "string", "description": "string"}},
		"combos": "array",
		"boss_freeze_immunity_sec": "number",
	},
	"traits": {"_each": {"name": "string", "adjective": "string", "description": "string"}},
	"legendaries": {
		"passive_templates": {"_each": {"description": "string", "flex_field": "string"}},
		"skill_templates": {"_each": {"description": "string"}},
		"weapons": "array",
	},
	"talismans": {"_each": {"name": "string", "description": "string"}},
	"enemies": {
		"materials": {"_each": {"name": "string", "prefix": "string", "tint": "string", "immune": "array", "resistant": "array", "weak": "array"}},
		"enemies": {"_each": {"name": "string", "floor": "number", "role": "string", "behavior": "string", "immune": "array", "resistant": "array", "weak": "array"}},
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
		"reward_after_combat": "bool",
		"boss_reward_on_final_floor": "bool",
		"level_pool": {"_each": {"name": "string", "value": "number"}},
		"boss_major_pool": {"_each": {"name": "string", "value": "number"}},
		"boss_special_pool": {"_each": {"name": "string", "description": "string"}},
	},
	"progression": {
		"player": {"max_level": "number", "xp_base": "number", "xp_per_level": "number"},
		"enemy_xp": {"_each": {"normal": "number", "elite": "number", "boss": "number"}},
		"weapon": {"max_level": "number", "bonus_step_levels": "number", "bonus_per_step": "number", "catch_up_xp_mult": "number"},
		"mastery": {"max_level": "number", "start_level": "number", "reference_match_xp": "number", "xp_to_next": "array", "bonus_at_max": "dict", "depth_multipliers": "dict"},
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
				"wall_color": "string", "obstacle_color": "string", "expected_normal_enemies": "number", "expected_elites": "number",
			},
		},
		"room_types": {"_each": {"description": "string"}},
	},
	"economy": {
		"bag_size": "number", "start_weapons": "dict", "floor_gold_mult": "dict",
		"gold": {"normal": "array", "elite": "array", "boss": "array", "chest": "array", "secret_chest": "array"},
		"drops": {"boss_weapons": "number", "chest_weapons": "number",
			"normal_potion_chance": "number", "elite_potion_chance": "number", "boss_potion_chance": "number",
			"chest_talisman_chance": "number"},
		"pickup": {"gold_magnet_tiles": "number", "potion_pickup_tiles": "number", "scatter_tiles": "number"},
		"chest": {"trap_chance": "number", "trap_warning_sec": "number", "trap_radius": "number", "trap_damage_pct": "number"},
		"merchant": {"weapons": "number", "talismans": "number", "weapon_prices": "dict", "talisman_price": "number",
			"potion_price": "number", "sell_pct": "number"},
		"blacksmith": {"level_up_cost_per_level": "number", "reroll_element_cost": "number", "reroll_trait_cost": "number",
			"reroll_cost_growth": "number"},
		"weapon_xp": {"xp_slots": "array", "locked_gains_xp": "bool"},
	},
	"dungeon": {
		"grid_cell_tiles": "number", "corridor_width": "number", "main_path_ratio": "number", "min_combat_rooms": "number",
		"room_jitter_tiles": "number", "template_symmetry": "bool", "door_clear_radius": "number",
		"obstacles": "dict", "template_pools": "dict", "room_type_names": "dict", "room_type_colors": "dict",
		"waves": {"max_per_wave": "number", "min_waves": "number", "max_waves": "number", "wave_delay_sec": "number",
			"first_wave_delay_sec": "number", "enemy_count_mult": "number", "spawn_min_distance_tiles": "number"},
		"prototype_enemies": {"rat_group": "array"},
		"placeholder_elite": {"base_pool": "array", "hp_mult": "number", "damage_mult": "number", "scale": "number"},
		"placeholder_boss": {"base": "string", "hp_mult": "number", "damage_mult": "number", "scale": "number"},
		"secret_wall": {"hits_to_break": "number", "reach_tiles": "number"},
		"interact_range_tiles": "number",
		"templates": {"_each": {"name": "string", "rows": "array"}},
	},
}
## Zindanın oda tipleri (floors.json > room_types ile aynı olmalı) ve şablon karakterleri.
const ROOM_TYPES := ["start", "combat", "elite", "merchant", "blacksmith", "chest", "secret", "boss"]
const TEMPLATE_CHARS := [".", "o", " "]

const FAMILIES := ["warrior", "ghost", "archer", "magical"]
## 1. kat düşmanlarında (Aşama 2'den itibaren) zorunlu stat alanları.
const ENEMY_STAT_FIELDS := ["hp", "damage", "armor", "move_speed", "radius", "attack_range",
	"attack_arc_degrees", "attack_windup", "attack_cooldown", "knockback_resist"]
## Kombo sayılarının zorunlu alanları (kombo id -> alanlar).
const COMBO_FIELDS := {
	"electroshock": ["damage_pct", "range"], "melt": ["bonus_damage_pct"], "freeze": ["freeze_duration"],
	"shatter": [], "poison_burst": ["damage_pct", "radius"], "steam": ["radius", "miss_chance", "duration"],
	"rot": ["poison_mult", "duration"],
}
## Element id -> DamageCalc/StatusEffects'in okuduğu zorunlu sayılar.
const ELEMENT_FIELDS := {
	"fire": ["duration", "dps_pct"], "water": ["duration", "damage_mult"],
	"lightning": ["chain_targets", "chain_damage_pct", "chain_range"],
	"poison": ["duration_per_stack", "dps_pct_per_stack", "max_stacks"],
	"ice": ["slow_per_stack", "freeze_at_stacks", "freeze_duration", "stack_duration"],
	"dark": ["backstab_mult", "duration", "backstab_angle_degrees"],
}
## Irk kaynak tipi -> zorunlu sayılar (Aşama 3).
const RESOURCE_FIELDS := {
	"energy": ["max", "regen_per_sec", "gain_on_hit"],
	"mana": ["base_max", "max_per_level", "regen_pct_per_sec"],
	"cooldown": [],
}
## Kaynak tipine göre hangi harcama (costs) ve bekleme (cooldowns) anahtarları zorunlu.
const RESOURCE_KEYS := {
	"energy": {"costs": ["q", "e"], "cooldowns": ["heavy"]},
	"mana": {"costs": ["light", "heavy", "q", "e"], "cooldowns": []},
	"cooldown": {"costs": [], "cooldowns": ["heavy", "q", "e"]},
}
## Irk yeteneği id -> zorunlu sayılar (kodda karşılığı olan yetenekler).
const ABILITY_FIELDS := {
	"armor_up": ["damage_bonus", "armor_bonus", "duration"],
	"ground_slam": ["skill_mult", "range", "arc_degrees"],
	"phase": ["max_duration"],
	"shadow_step": ["range", "behind_distance", "iframes"],
	"back_leap": ["arrows", "distance", "duration", "spread_degrees", "skill_mult", "arrow_range", "arrow_speed"],
	"arrow_rain": ["max_range", "radius", "waves", "interval", "skill_mult", "delay"],
	"flight": ["duration", "speed_bonus", "hover_px"],
	"element_storm": ["max_range", "radius", "pulses", "interval", "skill_mult"],
}
## Sol tık stili -> zorunlu sayılar.
const LIGHT_STYLE_FIELDS := {
	"arc": [], "thrust": [],
	"projectile": ["speed", "radius"],
	"blast": ["radius", "delay"],
}
## Sağ tık stili -> zorunlu sayılar.
const HEAVY_STYLE_FIELDS := {
	"spin": ["damage_mult", "radius"],
	"boomerang": ["damage_mult", "distance", "speed", "radius"],
	"flurry": ["hits", "interval", "damage_mult", "range", "arc_degrees", "stun_duration", "boss_slow", "boss_slow_duration"],
	"arc": ["damage_mult", "range", "arc_degrees", "backstab_bonus"],
	"backstab": ["damage_mult", "search_range", "dash_duration", "fallback_distance"],
	"smash": ["damage_mult", "radius", "offset", "slow", "slow_duration"],
	"charge_shot": ["min_mult", "max_mult", "charge_time", "speed", "range", "radius"],
	"fan": ["bolts", "spread_degrees", "damage_mult", "range", "speed", "radius"],
	"spear_throw": ["damage_mult", "range", "speed", "return_speed", "auto_return_sec", "radius"],
	"homing": ["projectiles", "damage_mult", "speed", "turn_rate", "range", "seek_range", "radius"],
	"orb": ["damage_mult", "speed", "range", "radius", "explosion_radius"],
	"trap": ["damage_mult", "max_range", "arm_time", "trigger_radius", "radius", "lifetime"],
}
## Efsanevi pasif ve sağ tık eki (skill) şablonları -> zorunlu sayılar.
const PASSIVE_FIELDS := {
	"sky_lightning": ["every_n_hits", "damage_pct", "radius"], "death_burst": ["damage_pct", "radius"],
	"combo_reset": ["chance"], "kill_frenzy": ["attack_speed", "duration"], "crit_nova": ["damage_pct", "radius"],
}
const SKILL_FIELDS := {
	"heavy_nova": ["radius", "skill_mult", "delay"],
	"heavy_strikes": ["count", "skill_mult", "radius", "spread", "delay", "interval", "max_range"],
	"heavy_shards": ["count", "skill_mult", "speed", "seek_range", "range", "radius", "turn_rate"],
}
## Tılsım id -> zorunlu sayılar (kodda karşılığı olan tılsımlar).
const TALISMAN_FIELDS := {
	"blood_stone": ["damage_per_stack", "duration", "max_stacks"],
	"wind_feather": ["dash_cooldown_reduction", "move_speed_bonus", "duration"],
	"element_heart": ["element_damage_bonus", "duration"],
}
const TRAIT_FIELDS := {
	"fury": ["per_hit", "max"], "execute": ["threshold", "boss_threshold"], "lifesteal": ["pct"],
	"ricochet": ["chance", "damage_pct", "range"], "stun": ["chance", "duration", "boss_slow_duration", "boss_slow"],
}

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
		_check_race(race_id, tables["races"][race_id])
		var fam: String = tables["races"][race_id]["family"]
		if not fam in FAMILIES:
			errors.append("races.%s.family: bilinmeyen aile '%s'" % [race_id, fam])
		if not tables["race_weapon_matrix"].has(race_id):
			errors.append("race_weapon_matrix: '%s' ırkı için satır yok" % race_id)
		else:
			for f: String in FAMILIES:
				if not (tables["race_weapon_matrix"][race_id] as Dictionary).has(f):
					errors.append("race_weapon_matrix.%s: '%s' ailesi için değer yok" % [race_id, f])
					continue
				var cell: Variant = tables["race_weapon_matrix"][race_id][f]
				if typeof(cell) != TYPE_DICTIONARY:
					errors.append("race_weapon_matrix.%s.%s: nesne ({...}) olmalı" % [race_id, f])
					continue
				for stat: String in (cell as Dictionary).keys():
					if not stat in ["max_hp", "attack_speed", "damage", "element_damage"]:
						errors.append("race_weapon_matrix.%s.%s: bilinmeyen stat '%s'" % [race_id, f, stat])
					elif not _type_ok(cell[stat], "number"):
						errors.append("race_weapon_matrix.%s.%s.%s: 'number' tipinde olmalı" % [race_id, f, stat])

	for wt: String in _records(tables["weapon_types"]):
		var fam2: String = tables["weapon_types"][wt]["family"]
		if not fam2 in FAMILIES:
			errors.append("weapon_types.%s.family: bilinmeyen aile '%s'" % [wt, fam2])
		var light: Dictionary = tables["weapon_types"][wt]["light"]
		var ls: String = light["style"]
		if LIGHT_STYLE_FIELDS.has(ls):
			_require_numbers(light, LIGHT_STYLE_FIELDS[ls], "weapon_types.%s.light" % wt)
		else:
			errors.append("weapon_types.%s.light.style: bilinmeyen stil '%s' (kodda karşılığı yok)" % [wt, ls])
		var heavy: Dictionary = tables["weapon_types"][wt]["heavy"]
		var hs: String = heavy["style"]
		if HEAVY_STYLE_FIELDS.has(hs):
			_require_numbers(heavy, HEAVY_STYLE_FIELDS[hs], "weapon_types.%s.heavy" % wt)
		else:
			errors.append("weapon_types.%s.heavy.style: bilinmeyen stil '%s' (kodda karşılığı yok)" % [wt, hs])

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

	var elements: Dictionary = tables["elements"]["elements"]
	for el_id: String in ELEMENT_FIELDS.keys():
		if not elements.has(el_id):
			errors.append("elements.elements: '%s' elementi yok" % el_id)
			continue
		_require_numbers(elements[el_id], ELEMENT_FIELDS[el_id], "elements.elements.%s" % el_id)
	for c: Variant in tables["elements"]["combos"]:
		var combo: Dictionary = c
		var ok := true
		for k: String in ["id", "name", "first", "second", "color"]:
			if not combo.has(k):
				errors.append("elements.combos: bir kombo kaydında '%s' eksik" % k)
				ok = false
		if not ok:
			continue
		var cid: String = combo["id"]
		for k2: String in ["first", "second"]:
			var el: String = combo[k2]
			if not (el in element_ids or el == "frozen"):
				errors.append("elements.combos.%s.%s: bilinmeyen element '%s'" % [cid, k2, el])
		if COMBO_FIELDS.has(cid):
			_require_numbers(combo, COMBO_FIELDS[cid], "elements.combos.%s" % cid)
		else:
			errors.append("elements.combos: bilinmeyen kombo id '%s' (kodda karşılığı yok)" % cid)
	for tid: String in TRAIT_FIELDS.keys():
		if not tables["traits"].has(tid):
			errors.append("traits: '%s' özelliği yok" % tid)
			continue
		_require_numbers(tables["traits"][tid], TRAIT_FIELDS[tid], "traits.%s" % tid)

	for mid: String in _records(tables["enemies"]["materials"]):
		for k3: String in ["immune", "resistant", "weak"]:
			for el2: Variant in tables["enemies"]["materials"][mid][k3]:
				if not el2 in damage_kinds:
					errors.append("enemies.materials.%s.%s: bilinmeyen hasar türü '%s'" % [mid, k3, el2])
	var enemy_ids: Array = _records(tables["enemies"]["enemies"])
	for eid: String in enemy_ids:
		var en: Dictionary = tables["enemies"]["enemies"][eid]
		for k4: String in ["immune", "resistant", "weak"]:
			for imm: Variant in en[k4]:
				if not imm in damage_kinds:
					errors.append("enemies.%s.%s: bilinmeyen hasar türü '%s'" % [eid, k4, imm])
		if int(en["floor"]) == 1:
			if not en.has("stats") or typeof(en["stats"]) != TYPE_DICTIONARY:
				errors.append("enemies.%s: 1. kat düşmanında 'stats' olmalı" % eid)
			else:
				_require_numbers(en["stats"], ENEMY_STAT_FIELDS, "enemies.%s.stats" % eid)
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

	_check_dungeon(enemy_ids)
	_check_loot(rarity_ids, element_ids)

	var mastery: Dictionary = tables["progression"]["mastery"]
	if (mastery["xp_to_next"] as Array).size() != int(mastery["max_level"]) - 1:
		errors.append("progression.mastery.xp_to_next: %d eleman olmalı (max_level - 1)" % (int(mastery["max_level"]) - 1))
	for dk: String in ["death_floor_1", "death_floor_2", "clear_floor_2", "death_floor_3", "death_floor_4", "victory"]:
		if not (mastery["depth_multipliers"] as Dictionary).has(dk):
			errors.append("progression.mastery.depth_multipliers: eksik alan '%s'" % dk)
	for mk: String in ["damage", "attack_speed", "attack_range", "element_damage"]:
		if not (mastery["bonus_at_max"] as Dictionary).has(mk):
			errors.append("progression.mastery.bonus_at_max: eksik alan '%s'" % mk)
	# Ödül havuzlarındaki statlar oyunun tanıdığı statlar olmalı (RaceStats.REWARD_STATS)
	for pool: String in ["level_pool", "boss_major_pool"]:
		for sid: String in _records(tables["rewards"][pool]):
			if not sid in REWARD_STATS:
				errors.append("rewards.%s: bilinmeyen stat '%s'" % [pool, sid])
	for sp: String in _records(tables["rewards"]["boss_special_pool"]):
		if not sp in SPECIAL_EFFECTS:
			errors.append("rewards.boss_special_pool: bilinmeyen özel etki '%s'" % sp)


## Irkın kaynak, harcama, bekleme ve yetenek sayılarını denetler.
func _check_race(race_id: String, r: Dictionary) -> void:
	var where := "races.%s" % race_id
	var rtype: String = r["resource"]["type"]
	if not RESOURCE_FIELDS.has(rtype):
		errors.append("%s.resource.type: bilinmeyen kaynak '%s'" % [where, rtype])
		return
	_require_numbers(r["resource"], RESOURCE_FIELDS[rtype], where + ".resource")
	var keys: Dictionary = RESOURCE_KEYS[rtype]
	_require_numbers(r["costs"], keys["costs"], where + ".costs")
	for k: String in keys["cooldowns"]:
		var cd: Variant = (r["cooldowns"] as Dictionary).get(k)
		var ok := _type_ok(cd, "number") or (typeof(cd) == TYPE_ARRAY and (cd as Array).size() == 2)
		if not ok:
			errors.append("%s.cooldowns: '%s' sayı ya da [en az, en çok] olmalı" % [where, k])
	for slot: String in ["q", "e"]:
		var ab: Dictionary = r["abilities"][slot]
		var aid: String = ab["id"]
		if ABILITY_FIELDS.has(aid):
			_require_numbers(ab, ABILITY_FIELDS[aid], "%s.abilities.%s" % [where, slot])
		else:
			errors.append("%s.abilities.%s: bilinmeyen yetenek '%s' (kodda karşılığı yok)" % [where, slot, aid])
	var stat_keys := ["attack_range", "crit_chance", "element_damage", "damage", "attack_speed", "max_hp"]
	for b: String in (r["passive"]["bonuses"] as Dictionary).keys():
		if not b in stat_keys:
			errors.append("%s.passive.bonuses: bilinmeyen stat '%s'" % [where, b])


## Zindan: oda tipleri, şablon havuzları, şablonların şekli ve kat başına prototip düşman havuzları.
func _check_dungeon(enemy_ids: Array) -> void:
	var dg: Dictionary = tables["dungeon"]
	var templates: Dictionary = dg["templates"]
	for tid: String in _records(templates):
		var rows: Array = templates[tid]["rows"]
		if rows.is_empty():
			errors.append("dungeon.templates.%s.rows: boş" % tid)
			continue
		var w := str(rows[0]).length()
		var floor_count := 0
		for i: int in rows.size():
			var row := str(rows[i])
			if row.length() != w:
				errors.append("dungeon.templates.%s.rows[%d]: satır uzunluğu %d olmalı (bulunan %d)" % [tid, i, w, row.length()])
			for ch: String in row:
				if not ch in TEMPLATE_CHARS:
					errors.append("dungeon.templates.%s.rows[%d]: bilinmeyen karakter '%s' (izinli: . o boşluk)" % [tid, i, ch])
				elif ch == ".":
					floor_count += 1
		if floor_count == 0:
			errors.append("dungeon.templates.%s: hiç zemin (.) yok" % tid)
		if w + 4 > int(dg["grid_cell_tiles"]) or rows.size() + 4 > int(dg["grid_cell_tiles"]):
			errors.append("dungeon.templates.%s: %d×%d şablon %d karoluk hücreye sığmıyor" % [tid, w, rows.size(), int(dg["grid_cell_tiles"])])
	for rt: String in ROOM_TYPES:
		for key: String in ["template_pools", "obstacles", "room_type_names", "room_type_colors"]:
			if not (dg[key] as Dictionary).has(rt):
				errors.append("dungeon.%s: '%s' oda tipi eksik" % [key, rt])
		if not tables["floors"]["room_types"].has(rt) and rt != "start":
			errors.append("floors.room_types: '%s' oda tipi eksik" % rt)
	for rt: String in _records(dg["template_pools"]):
		var pool: Array = dg["template_pools"][rt]
		if pool.is_empty():
			errors.append("dungeon.template_pools.%s: boş" % rt)
		for tid: Variant in pool:
			if not templates.has(str(tid)):
				errors.append("dungeon.template_pools.%s: bilinmeyen şablon '%s'" % [rt, tid])
	var materials: Dictionary = tables["enemies"]["materials"]
	var enemies: Dictionary = tables["enemies"]["enemies"]
	for fid: String in _records(tables["floors"]["floors"]):
		var pe: Dictionary = dg["prototype_enemies"]
		if not pe.has(fid) or typeof(pe[fid]) != TYPE_DICTIONARY or not (pe[fid] as Dictionary).has("pool"):
			errors.append("dungeon.prototype_enemies: %s. kat için havuz yok" % fid)
			continue
		for entry: Variant in pe[fid]["pool"]:
			if typeof(entry) != TYPE_ARRAY or (entry as Array).size() != 3:
				errors.append("dungeon.prototype_enemies.%s.pool: her kayıt [düşman, malzeme, ağırlık] olmalı" % fid)
				continue
			var eid := str(entry[0])
			if not eid in enemy_ids or not (enemies[eid] as Dictionary).has("stats"):
				errors.append("dungeon.prototype_enemies.%s: '%s' düşmanının statları yok" % [fid, eid])
			if str(entry[1]) != "" and not materials.has(str(entry[1])):
				errors.append("dungeon.prototype_enemies.%s: bilinmeyen malzeme '%s'" % [fid, entry[1]])
	for eid: Variant in dg["placeholder_elite"]["base_pool"] + [dg["placeholder_boss"]["base"]]:
		if not str(eid) in enemy_ids or not (enemies[str(eid)] as Dictionary).has("stats"):
			errors.append("dungeon: yer tutucu elit/boss için '%s' düşmanının statları yok" % eid)


## Aşama 5: efsanevi silahlar, tılsımlar ve ekonomi (başlangıç silahları, kat çarpanları, fiyatlar).
func _check_loot(rarity_ids: Array, element_ids: Array) -> void:
	var lg: Dictionary = tables["legendaries"]
	for pid: String in _records(lg["passive_templates"]):
		if PASSIVE_FIELDS.has(pid):
			_require_numbers(lg["passive_templates"][pid], PASSIVE_FIELDS[pid], "legendaries.passive_templates.%s" % pid)
			var ff := str(lg["passive_templates"][pid]["flex_field"])
			if not ff in PASSIVE_FIELDS[pid]:
				errors.append("legendaries.passive_templates.%s.flex_field: '%s' pasifin sayılarından biri olmalı" % [pid, ff])
		else:
			errors.append("legendaries.passive_templates: bilinmeyen pasif '%s' (kodda karşılığı yok)" % pid)
	for sid: String in _records(lg["skill_templates"]):
		if SKILL_FIELDS.has(sid):
			_require_numbers(lg["skill_templates"][sid], SKILL_FIELDS[sid], "legendaries.skill_templates.%s" % sid)
		else:
			errors.append("legendaries.skill_templates: bilinmeyen skill '%s' (kodda karşılığı yok)" % sid)
	var ids := {}
	for i: int in (lg["weapons"] as Array).size():
		var w: Variant = lg["weapons"][i]
		var where := "legendaries.weapons[%d]" % i
		if typeof(w) != TYPE_DICTIONARY:
			errors.append(where + ": nesne ({...}) olmalı")
			continue
		var ok := true
		for k: String in ["id", "name", "type", "element", "passive", "skill"]:
			if not (w as Dictionary).has(k) or typeof(w[k]) != TYPE_STRING:
				errors.append("%s: '%s' metni eksik" % [where, k])
				ok = false
		if not ok:
			continue
		if ids.has(w["id"]):
			errors.append("%s: aynı id iki kez '%s'" % [where, w["id"]])
		ids[w["id"]] = true
		if not tables["weapon_types"].has(w["type"]):
			errors.append("%s.type: bilinmeyen silah tipi '%s'" % [where, w["type"]])
		if not w["element"] in element_ids:
			errors.append("%s.element: bilinmeyen element '%s'" % [where, w["element"]])
		if not (lg["passive_templates"] as Dictionary).has(w["passive"]):
			errors.append("%s.passive: bilinmeyen pasif '%s'" % [where, w["passive"]])
		if not (lg["skill_templates"] as Dictionary).has(w["skill"]):
			errors.append("%s.skill: bilinmeyen skill '%s'" % [where, w["skill"]])
	if (lg["weapons"] as Array).is_empty():
		errors.append("legendaries.weapons: en az bir efsanevi silah olmalı")
	for tid: String in TALISMAN_FIELDS.keys():
		if not tables["talismans"].has(tid):
			errors.append("talismans: '%s' tılsımı yok" % tid)
			continue
		_require_numbers(tables["talismans"][tid], TALISMAN_FIELDS[tid], "talismans.%s" % tid)
	var ec: Dictionary = tables["economy"]
	for rid: String in _records(tables["races"]):
		var sw: Variant = (ec["start_weapons"] as Dictionary).get(rid)
		if sw == null or not tables["weapon_types"].has(str(sw)):
			errors.append("economy.start_weapons.%s: geçerli bir silah tipi olmalı" % rid)
	for fid: String in _records(tables["floors"]["floors"]):
		if not _type_ok((ec["floor_gold_mult"] as Dictionary).get(fid), "number"):
			errors.append("economy.floor_gold_mult: %s. kat için sayı yok" % fid)
	for r: String in rarity_ids:
		if not _type_ok((ec["merchant"]["weapon_prices"] as Dictionary).get(r), "number"):
			errors.append("economy.merchant.weapon_prices: '%s' nadirliği için fiyat yok" % r)
	for k: String in (ec["gold"] as Dictionary).keys():
		var g: Array = ec["gold"][k]
		if g.size() != 2 or not _type_ok(g[0], "number") or not _type_ok(g[1], "number") or float(g[0]) > float(g[1]):
			errors.append("economy.gold.%s: [en az, en çok] olmalı" % k)
	for s: Variant in ec["weapon_xp"]["xp_slots"]:
		if not str(s) in ["active_1", "active_2", "resonance", "flex"]:
			errors.append("economy.weapon_xp.xp_slots: bilinmeyen slot '%s'" % s)
	for fid2: String in _records(tables["loot_tables"]["floors"]):
		var wl: Array = tables["loot_tables"]["floors"][fid2]["weapon_level"]
		if wl.size() != 2 or int(wl[0]) > int(wl[1]) or int(wl[0]) < 1:
			errors.append("loot_tables.floors.%s.weapon_level: [en az, en çok] olmalı" % fid2)


## Sözlükte verilen alanların hepsi sayı olmalı.
func _require_numbers(d: Dictionary, fields: Array, where: String) -> void:
	for f: String in fields:
		if not d.has(f):
			errors.append("%s: eksik alan '%s'" % [where, f])
		elif not _type_ok(d[f], "number"):
			errors.append("%s.%s: 'number' tipinde olmalı, bulunan: %s" % [where, f, _type_name(d[f])])


## Sözlüğün "_" ile başlamayan (not olmayan) anahtarları.
func records(d: Dictionary) -> Array:
	return _records(d)


func _records(d: Dictionary) -> Array:
	var out: Array = []
	for k: String in d.keys():
		if not k.begins_with("_"):
			out.append(k)
	return out
