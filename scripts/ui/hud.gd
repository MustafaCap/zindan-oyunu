## Hud — prototip arayüzü: can ve kaynak barı, sağ tık / Q / E / Space göstergeleri, dalga bilgisi, ortadaki mesajlar.
## Aşama 2: iki aktif silah paneli (element ikonu, ad, nadirlik rengi; aktif olan vurgulu) ve hata ayıklama notları.
## Aşama 3: ırk ve level, Enerji/Mana barı, yetenek adları ve bedelleri, iksir sayısı.
## Aşama 4: kat/oda bilgisi, etkileşim ipucu ("F: ..."), boss can barı; tuş ipuçları sahneye göre değişir.
## Aşama 5: altın, iksir (x / maks), silah levelleri (kilitliyse işaret), Rezonans ve Esnek slot kutuları.
## Aşama 6: XP barı (level, XP / sonraki level), alınan run ödülleri satırı, bekleyen ödül uyarısı.
## Ayrıntılı arayüz tasarımı sonraya bırakıldı (GDD Açık Kararlar); bu yalnızca test için.
class_name Hud
extends CanvasLayer

var player: Player
var wave_text: String = ""
var prompt_text: String = ""          ## etkileşim ipucu (ekranın ortasının altında)
var boss: Node2D                      ## doluysa üstte boss can barı
var stage_text: String = "Aşama 3 · ırklar ve silahlar"
var show_economy: bool = false        ## zindanda: altın, iksir sınırı, Rezonans ve Esnek slot
var _panel: Control
var _center: Label
var _info: Label
var _hint_lines: PackedStringArray = []
var _note_text: String = ""
var _note_t: float = 0.0
var _ver: Label


func _ready() -> void:
	layer = 10
	_panel = Control.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.draw.connect(_draw_panel)
	add_child(_panel)

	_center = _make_label(48, Color(1, 0.9, 0.6))
	_center.set_anchors_preset(Control.PRESET_CENTER)
	_center.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_center.grow_vertical = Control.GROW_DIRECTION_BOTH
	_center.position.y -= 160

	_info = _make_label(22, Color(0.85, 0.85, 0.9))
	_info.position = Vector2(32, 112)

	_hint_lines = PackedStringArray([
		"WASD yürü · Fare nişan · Sol/Sağ tık saldırı · Q/E yetenek · Space atılma · Tab silah değiştir · 1 iksir · R yeniden başla · Esc çık",
		"M: HATA AYIKLAMA MENÜSÜ (ırk, silah, element) · Kısayol: 2-7 element · 0 elementsiz · 8 özellik · N yeni dalga",
	])

	var ver := _make_label(16, Color(0.5, 0.5, 0.55))
	ver.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	ver.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ver.position = Vector2(-32, 24)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ver = ver
	_ver.text = "v%s · %s" % [ProjectSettings.get_setting("application/config/version", "?"), stage_text]


func _make_label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


## Alt kısımdaki tuş ipucu satırları.
func set_hints(lines: PackedStringArray) -> void:
	_hint_lines = lines


func show_message(text: String) -> void:
	_center.text = text


## Ekranın altında kısa süre görünen not (örn. silah değişti).
func flash_note(text: String) -> void:
	_note_text = text
	_note_t = 2.0


func _process(delta: float) -> void:
	_info.text = wave_text
	if _ver:
		_ver.text = "v%s · %s" % [ProjectSettings.get_setting("application/config/version", "?"), stage_text]
	_note_t = maxf(_note_t - delta, 0.0)
	_panel.queue_redraw()


func _draw_panel() -> void:
	if player == null:
		return
	# Can barı
	var pos := Vector2(32, 32)
	var size := Vector2(360, 26)
	_panel.draw_rect(Rect2(pos - Vector2(3, 3), size + Vector2(6, 6)), Color(0, 0, 0, 0.75))
	_panel.draw_rect(Rect2(pos, size), Color(0.25, 0.08, 0.08))
	_panel.draw_rect(Rect2(pos, Vector2(size.x * player.hp / player.max_hp, size.y)), Color(0.85, 0.18, 0.2))
	var font := ThemeDB.fallback_font
	_text(pos + Vector2(10, 20), "%d / %d" % [ceili(player.hp), roundi(player.max_hp)], 18, Color.WHITE)
	var race: Dictionary = DataDB.table("races")[player.race_id]
	var eco := ""
	if show_economy and player.inventory:
		eco = " / %d · Altın %d" % [player.inventory.potion_max, player.inventory.gold]
	_text(pos + Vector2(size.x + 16, 20), "%s · Level %d · İksir %d%s" % [race["name"], player.level, player.potions, eco], 18, Color(0.9, 0.9, 0.95))
	# Kaynak barı (Enerji / Mana)
	var kit := player.kit
	if kit.uses_resource():
		var rp := pos + Vector2(0, size.y + 8)
		var rs := Vector2(size.x, 14)
		_panel.draw_rect(Rect2(rp - Vector2(3, 3), rs + Vector2(6, 6)), Color(0, 0, 0, 0.75))
		_panel.draw_rect(Rect2(rp, rs), kit.resource_color().darkened(0.7))
		_panel.draw_rect(Rect2(rp, Vector2(rs.x * kit.resource / maxf(kit.resource_max, 1.0), rs.y)), kit.resource_color())
		_text(rp + Vector2(8, 12), "%s %d / %d" % [kit.resource_name(), floori(kit.resource), roundi(kit.resource_max)], 13, Color.WHITE)
	# XP barı (zindanda: oyuncu leveli ve XP)
	if show_economy:
		var xp_pos := pos + Vector2(0, 56)
		var xs := Vector2(size.x, 8)
		var need := Leveling.xp_to_next(GameState.level)
		var maxed := GameState.level >= Leveling.max_level()
		var k := 1.0 if maxed else clampf(GameState.xp / maxf(need, 1.0), 0.0, 1.0)
		_panel.draw_rect(Rect2(xp_pos - Vector2(2, 2), xs + Vector2(4, 4)), Color(0, 0, 0, 0.75))
		_panel.draw_rect(Rect2(xp_pos, xs), Color(0.15, 0.13, 0.05))
		_panel.draw_rect(Rect2(xp_pos, Vector2(xs.x * k, xs.y)), Color(0.95, 0.8, 0.25))
		var xp_txt := "Level %d · XP %s" % [GameState.level, "MAKS" if maxed else "%d / %d" % [floori(GameState.xp), roundi(need)]]
		if not GameState.pending_rewards.is_empty():
			xp_txt += " · Ödül bekliyor (oda temizlenince)"
		_text(xp_pos + Vector2(xs.x + 12, 9), xp_txt, 15, Color(1.0, 0.9, 0.55))
		var bt := rewards_text()
		if bt != "":
			_text(Vector2(32, vp_bonus_y()), bt, 15, Color(0.75, 0.85, 1.0))
	# Yetenek göstergeleri (alt orta): Sağ tık, Q, E, Space
	var vp := _panel.size
	var w := player.weapon()
	var fam := w.family()
	var heavy: Dictionary = w.type_data()["heavy"]
	var boxes := [
		["Sağ tık", str(heavy["name"]), "heavy"],
		["Q", str(race["abilities"]["q"]["name"]), "q"],
		["E", str(race["abilities"]["e"]["name"]), "e"],
	]
	var bx := vp.x * 0.5 - 2.0 * 112.0
	for b: Array in boxes:
		var slot: String = b[2]
		var cost := kit.cost(slot, fam)
		_cooldown_box(Vector2(bx, vp.y - 190), str(b[0]), str(b[1]), float(kit.cooldowns[slot]), float(kit.cooldown_totals[slot]), kit.resource + 0.001 >= cost, cost)
		bx += 112.0
	_cooldown_box(Vector2(bx, vp.y - 190), "Space", "Atılma", player.dash_cd, player.dash_cd_max, true, 0.0)
	# Silah paneli (sol alt): iki aktif silah
	var wy := vp.y - 250.0
	for i: int in player.weapons.size():
		_weapon_box(Vector2(32, wy + i * 52.0), player.weapons[i], i == player.active_index, i + 1)
	_panel.draw_string_outline(ThemeDB.fallback_font, Vector2(32, wy - 12), "Tab: silah değiştir", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color.BLACK)
	_panel.draw_string(ThemeDB.fallback_font, Vector2(32, wy - 12), "Tab: silah değiştir", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.8, 0.8, 0.85))
	# Rezonans ve Esnek slot (zindanda)
	if show_economy and player.effects:
		_mini_slot(Vector2(32, wy - 84.0), "Rezonans", player.effects.resonance)
		_mini_slot(Vector2(32 + 278.0, wy - 84.0), "Esnek", player.effects.flex)
	# Alt satırlar: tuş ipuçları
	for i: int in _hint_lines.size():
		var hp := Vector2(32, vp.y - 44 + i * 24)
		_panel.draw_string_outline(ThemeDB.fallback_font, hp, _hint_lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, 4, Color.BLACK)
		_panel.draw_string(ThemeDB.fallback_font, hp, _hint_lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.62, 0.62, 0.68))
	# Etkileşim ipucu
	if prompt_text != "":
		var pp := Vector2(0, vp.y * 0.5 + 90)
		_panel.draw_string_outline(ThemeDB.fallback_font, pp, prompt_text, HORIZONTAL_ALIGNMENT_CENTER, vp.x, 26, 7, Color.BLACK)
		_panel.draw_string(ThemeDB.fallback_font, pp, prompt_text, HORIZONTAL_ALIGNMENT_CENTER, vp.x, 26, Color(1, 0.95, 0.7))
	# Boss can barı (üst orta)
	if boss != null and is_instance_valid(boss) and not boss.get("dead"):
		var bw := 600.0
		var bp := Vector2((vp.x - bw) * 0.5 + 40.0, 44)
		var k := clampf(float(boss.get("hp")) / maxf(float(boss.get("max_hp")), 1.0), 0.0, 1.0)
		_panel.draw_rect(Rect2(bp - Vector2(3, 3), Vector2(bw + 6, 26)), Color(0, 0, 0, 0.8))
		_panel.draw_rect(Rect2(bp, Vector2(bw, 20)), Color(0.25, 0.05, 0.05))
		_panel.draw_rect(Rect2(bp, Vector2(bw * k, 20)), Color(0.8, 0.12, 0.15))
		var bn := str(boss.get("display_name"))
		_panel.draw_string_outline(ThemeDB.fallback_font, bp + Vector2(0, -8), bn, HORIZONTAL_ALIGNMENT_CENTER, bw, 20, 5, Color.BLACK)
		_panel.draw_string(ThemeDB.fallback_font, bp + Vector2(0, -8), bn, HORIZONTAL_ALIGNMENT_CENTER, bw, 20, Color(1, 0.8, 0.75))
	# Kısa not (silah değişti vb.)
	if _note_t > 0.0:
		var a := clampf(_note_t / 0.5, 0.0, 1.0)
		var np := Vector2(0, vp.y - 250)
		_panel.draw_string_outline(ThemeDB.fallback_font, np, _note_text, HORIZONTAL_ALIGNMENT_CENTER, vp.x, 28, 7, Color(0, 0, 0, a))
		_panel.draw_string(ThemeDB.fallback_font, np, _note_text, HORIZONTAL_ALIGNMENT_CENTER, vp.x, 28, Color(1, 0.95, 0.8, a))


func _weapon_box(p: Vector2, w: Weapon, active: bool, slot: int) -> void:
	var s := Vector2(540, 44)
	_panel.draw_rect(Rect2(p, s), Color(0.12, 0.12, 0.16, 0.92 if active else 0.6))
	_panel.draw_rect(Rect2(p, s), w.rarity_color() if active else Color(0.35, 0.35, 0.4), false, 3.0 if active else 1.0)
	ElementIcons.draw_badge(_panel, w.element, p + Vector2(24, 22), 14.0)
	var font := ThemeDB.fallback_font
	var name_col := w.rarity_color().lightened(0.25) if active else Color(0.6, 0.6, 0.65)
	_panel.draw_string(font, p + Vector2(48, 20), "%d. %s · Lv %d" % [slot, w.display_name(), w.level], HORIZONTAL_ALIGNMENT_LEFT, s.x - 56, 19, name_col)
	var sub := "%s · %s · %s" % [w.rarity_name(), Weapon.kind_name(w.element), RaceStats.matrix_text(player.race_id, w.family())]
	if not w.traits.is_empty():
		sub += " · " + str(Traits.data(w.traits[0])["name"])
	_panel.draw_string(font, p + Vector2(48, 38), sub, HORIZONTAL_ALIGNMENT_LEFT, s.x - 56, 14, Color(0.7, 0.7, 0.75))


## Rezonans / Esnek slot kutusu: eşyanın adı ve etkisi.
func _mini_slot(p: Vector2, title: String, it: Variant) -> void:
	var s := Vector2(262, 44)
	var font := ThemeDB.fallback_font
	_panel.draw_rect(Rect2(p, s), Color(0.12, 0.12, 0.16, 0.6))
	var border := Color(0.35, 0.35, 0.4)
	var line1 := "%s: boş" % title
	var line2 := "I: envanteri aç"
	if it is Weapon:
		var w := it as Weapon
		border = w.rarity_color()
		line1 = "%s: %s · Lv %d" % [title, w.display_name(), w.level]
		if title == "Rezonans":
			var rp := player.effects.resonance_pct()
			line2 = "+%d %s/vuruş (%s %%%d)" % [roundi(w.hit_damage() * rp), Weapon.kind_name(w.element), "kilitli" if w.is_locked(player.level) else "açık", roundi(rp * 100.0)]
		else:
			line2 = "özellik/pasif %%9: %s" % (", ".join(w.traits.map(func(t: String) -> String: return str(Traits.data(t)["name"]))) if not w.traits.is_empty() else "özelliği yok")
	elif it is Talisman:
		var t := it as Talisman
		border = t.color()
		line1 = "%s: %s" % [title, t.display_name()]
		line2 = t.description()
	_panel.draw_rect(Rect2(p, s), border, false, 1.5)
	_panel.draw_string(font, p + Vector2(10, 19), line1, HORIZONTAL_ALIGNMENT_LEFT, s.x - 16, 15, border.lightened(0.3))
	_panel.draw_string(font, p + Vector2(10, 37), line2, HORIZONTAL_ALIGNMENT_LEFT, s.x - 16, 12, Color(0.7, 0.7, 0.75))


## Yetenek kutusu: tuş, kalan bekleme süresi ya da kaynak bedeli; altında yeteneğin adı.
func _cooldown_box(p: Vector2, key: String, label: String, cd: float, cd_max: float, affordable: bool, cost: float) -> void:
	var s := Vector2(96, 70)
	var font := ThemeDB.fallback_font
	_panel.draw_rect(Rect2(p, s), Color(0.12, 0.12, 0.16, 0.9))
	if not affordable:
		_panel.draw_rect(Rect2(p, s), Color(0.1, 0.2, 0.5, 0.55))
	_panel.draw_string(font, p + Vector2(0, 26), key, HORIZONTAL_ALIGNMENT_CENTER, s.x, 20, Color(0.95, 0.9, 0.75))
	if cd > 0.0 and cd_max > 0.0:
		var k := clampf(cd / cd_max, 0.0, 1.0)
		_panel.draw_rect(Rect2(p + Vector2(0, s.y * (1.0 - k)), Vector2(s.x, s.y * k)), Color(0, 0, 0, 0.65))
		_panel.draw_string(font, p + Vector2(0, 54), "%.1f" % cd, HORIZONTAL_ALIGNMENT_CENTER, s.x, 20, Color.WHITE)
	elif cost > 0.0:
		_panel.draw_string(font, p + Vector2(0, 54), "%d %s" % [roundi(cost), player.kit.resource_name()], HORIZONTAL_ALIGNMENT_CENTER, s.x, 14, player.kit.resource_color().lightened(0.3))
	var ready := cd <= 0.0 and affordable
	_panel.draw_rect(Rect2(p, s), Color(0.9, 0.8, 0.5) if ready else Color(0.4, 0.4, 0.45), false, 2.0)
	_panel.draw_string_outline(font, p + Vector2(-8, s.y + 18), label, HORIZONTAL_ALIGNMENT_CENTER, s.x + 16, 12, 4, Color.BLACK)
	_panel.draw_string(font, p + Vector2(-8, s.y + 18), label, HORIZONTAL_ALIGNMENT_CENTER, s.x + 16, 12, Color(0.8, 0.8, 0.85))


## Alınan run ödülleri: "Ödüller: Hasar +%10 · Kritik şansı +%3 · Çift vuruş" (boşsa "").
func rewards_text() -> String:
	var parts: PackedStringArray = []
	var pool: Dictionary = DataDB.table("rewards")["level_pool"]
	for k: Variant in GameState.buffs.keys():
		var v := float(GameState.buffs[k])
		if v > 0.0 and pool.has(str(k)):
			parts.append("%s %s" % [pool[str(k)]["name"], Rewards.stat_text(str(k), v)])
	for sp: String in GameState.special_effects:
		parts.append(str(Rewards.special_data(sp)["name"]))
	if parts.is_empty():
		return ""
	return "Ödüller: " + " · ".join(parts)


## Ödül satırının yeri: kat/oda bilgisinin altında.
func vp_bonus_y() -> float:
	return 192.0


func _text(p: Vector2, text: String, size: int, color: Color) -> void:
	var font := ThemeDB.fallback_font
	_panel.draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, Color.BLACK)
	_panel.draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
