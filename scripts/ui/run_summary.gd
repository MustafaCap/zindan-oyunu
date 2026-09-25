## RunSummary — run sonu özet ekranı (Aşama 6; GDD Uygulama Rehberi 6.4): ölüm ya da zafer, ulaşılan kat, level, süre,
## öldürme, altın, alınan ödüller, silah tiplerine göre hasar payı ve kazanılan ustalık XP'si (level atlayanlar vurgulu),
## boss ilk kesişleri. Ustalık bu ekran açılmadan kaydedilmiştir. "Yeni run" düğmesi ya da R yeni run başlatır.
## Nihai arayüz değildir (ayrıntılı arayüz tasarımı GDD Açık Kararlar'da).
class_name RunSummary
extends CanvasLayer

signal new_run_requested

var _body: RichTextLabel
var _title: Label


func _ready() -> void:
	layer = 24
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.08, 0.11, 0.96)
	sb.border_color = Color(0.9, 0.78, 0.45)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(26)
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.custom_minimum_size = Vector2(900, 0)
	panel.add_child(box)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 40)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.scroll_active = false
	_body.custom_minimum_size = Vector2(900, 0)
	_body.add_theme_font_size_override("normal_font_size", 19)
	_body.add_theme_font_size_override("bold_font_size", 19)
	box.add_child(_body)
	var btn := Button.new()
	btn.text = "Yeni run (R)"
	btn.custom_minimum_size = Vector2(240, 48)
	btn.add_theme_font_size_override("font_size", 20)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(func() -> void: new_run_requested.emit())
	box.add_child(btn)


## info: {"victory", "floor", "level", "time", "kills", "gold", "xp", "depth_key", "mastery": Mastery.apply_run sonucu,
## "first_kills": [boss adları], "rewards": [metinler], "saved": bool}
func show_summary(info: Dictionary) -> void:
	var victory := bool(info["victory"])
	_title.text = "KAZANDIN!" if victory else "Öldün"
	_title.add_theme_color_override("font_color", Color(1, 0.85, 0.4) if victory else Color(1, 0.5, 0.45))
	var lines: PackedStringArray = []
	var t := float(info["time"])
	lines.append("[b]%d. kat[/b] · Level [b]%d[/b] · Süre %d:%02d · Öldürme %d · Altın %d · Kazanılan XP %d" % [
		int(info["floor"]), int(info["level"]), floori(t / 60.0), floori(fmod(t, 60.0)), int(info["kills"]), int(info["gold"]), roundi(float(info["xp"]))])
	var rw: Array = info.get("rewards", [])
	lines.append("[color=#a8a8b4]Run ödülleri (run bitince kaybolur):[/color] %s" % (", ".join(rw) if not rw.is_empty() else "—"))
	var key := str(info["depth_key"])
	lines.append("")
	lines.append("[b]Silah tipi ustalığı[/b] (kalıcı) — derinlik çarpanı ×%s (%s), toplam %d XP" % [
		_num(Mastery.depth_multiplier(key)), DEPTH_NAMES.get(key, key), roundi(Mastery.run_xp(key))])
	var ms: Array = info.get("mastery", [])
	if ms.is_empty():
		lines.append("[color=#a8a8b4]Hasar verilmediği için ustalık XP'si yok.[/color]")
	for m: Dictionary in ms:
		var tname := str(DataDB.table("weapon_types")[str(m["type"])]["name"])
		var lvl_txt := "Level %d" % int(m["to_level"])
		if int(m["to_level"]) > int(m["from_level"]):
			lvl_txt = "[color=#7dff8a]Level %d → %d ↑[/color]" % [int(m["from_level"]), int(m["to_level"])]
		var prog := "maks" if float(m["xp_next"]) <= 0.0 else "%d / %d" % [floori(float(m["xp_now"])), roundi(float(m["xp_next"]))]
		var b := Mastery.stat_bonuses(int(m["to_level"]))
		lines.append("  %s: hasarın %%%d · +%d XP · %s (%s) · bonus: hasar +%%%s, hız +%%%s, menzil +%%%s, element +%%%s" % [
			tname, roundi(float(m["share"]) * 100.0), roundi(float(m["xp"])), lvl_txt, prog,
			_num(Mastery.bonus(int(m["to_level"]), "damage") * 100.0), _num(float(b["attack_speed"]) * 100.0),
			_num(float(b["attack_range"]) * 100.0), _num(float(b["element_damage"]) * 100.0)])
	var fk: Array = info.get("first_kills", [])
	if not fk.is_empty():
		lines.append("")
		lines.append("[color=#ffd27a]Boss ilk kesişi (kalıcı +%%0,3 hasar): %s[/color]" % ", ".join(fk))
	lines.append("")
	lines.append("[color=#a8a8b4]%s[/color]" % ("İlerleme kaydedildi." if bool(info.get("saved", true)) else "UYARI: kayıt yazılamadı!"))
	_body.text = "\n".join(lines)
	visible = true


func hide_summary() -> void:
	visible = false


const DEPTH_NAMES := {"death_floor_1": "1. katta ölüm", "death_floor_2": "2. katta ölüm", "clear_floor_2": "2. katı bitirme",
	"death_floor_3": "3. katta ölüm", "death_floor_4": "4. katta ölüm", "victory": "zafer"}


static func _num(f: float) -> String:
	if absf(f - roundf(f)) < 0.01:
		return str(roundi(f))
	return ("%.2f" % f).rstrip("0").rstrip(".").replace(".", ",")
