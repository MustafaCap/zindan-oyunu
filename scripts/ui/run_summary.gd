## RunSummary — run sonu ekranı (Aşama 6 özeti; Aşama 10: "Kazandın" / "Öldün" ekranı ve menü düğmeleri).
## Önce ekran kararır ve büyük başlık gelir: zaferde altın "KAZANDIN", ölümde kan kırmızısı "ÖLDÜN", duraklatma
## menüsünden bırakılan run'da "RUN BIRAKILDI" (ölüm sayılır); başlığın altından kan damlar. ~1,4 sn sonra (ya da bir
## tuşa/tıklamaya basınca) özet paneli açılır: ulaşılan kat, level, süre, öldürme, altın, XP, alınan run ödülleri, silah
## tiplerine göre hasar payı ve kazanılan ustalık XP'si (level atlayanlar yeşil), boss ilk kesişleri. Ustalık bu ekran
## açılmadan kaydedilmiştir. Düğmeler: "Yeni run" (R; aynı ırkla) ve "Ana menü" (Esc).
class_name RunSummary
extends CanvasLayer

signal new_run_requested
signal main_menu_requested

const DETAIL_DELAY := 1.4

var _root: Control
var _dim: ColorRect
var _head: VBoxContainer
var _title: Label
var _sub: Label
var _drips: BloodDrips
var _panel: PanelContainer
var _body: RichTextLabel
var _new_btn: Button
var _menu_btn: Button
var _details_t: float = -1.0


func _ready() -> void:
	layer = 24
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UiTheme.theme()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_dim = ColorRect.new()
	_dim.color = Color(0.02, 0.0, 0.0, 0.0)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_dim)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_top = 70
	col.offset_bottom = -50
	col.add_theme_constant_override("separation", 10)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(col)
	_head = VBoxContainer.new()
	_head.add_theme_constant_override("separation", 0)
	_head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_head)
	_title = UiTheme.title("", 112, UiTheme.BLOOD_LIGHT)
	_head.add_child(_title)
	_drips = BloodDrips.new()
	_drips.custom_minimum_size = Vector2(620, 90)
	_drips.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_drips.max_len = 80.0
	_drips.count = 11
	_head.add_child(_drips)
	_sub = UiTheme.label("", 22, UiTheme.ASH)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_head.add_child(_sub)
	_panel = PanelContainer.new()
	_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	_panel.add_child(box)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.scroll_active = false
	_body.custom_minimum_size = Vector2(1000, 0)
	box.add_child(_body)
	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 24)
	box.add_child(bar)
	_new_btn = UiTheme.menu_button("Yeni run  (R)", 300)
	_new_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_new_btn.pressed.connect(func() -> void: new_run_requested.emit())
	bar.add_child(_new_btn)
	_menu_btn = UiTheme.menu_button("Ana menü  (Esc)", 300)
	_menu_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu_btn.pressed.connect(func() -> void: main_menu_requested.emit())
	bar.add_child(_menu_btn)


## info: {"victory", "floor", "level", "time", "kills", "gold", "xp", "depth_key", "mastery": Mastery.apply_run sonucu,
## "first_kills": [boss adları], "rewards": [metinler], "saved": bool, "abandoned": bool (isteğe bağlı), "subtitle"}
func show_summary(info: Dictionary) -> void:
	var victory := bool(info["victory"])
	var abandoned := bool(info.get("abandoned", false))
	_title.text = "KAZANDIN" if victory else ("RUN BIRAKILDI" if abandoned else "ÖLDÜN")
	_title.add_theme_color_override("font_color", UiTheme.GOLD if victory else (UiTheme.ASH if abandoned else UiTheme.BLOOD_LIGHT))
	_title.add_theme_font_size_override("font_size", 84 if abandoned else 112)
	_drips.color = UiTheme.BLOOD if not victory else Color(0.45, 0.05, 0.03)
	_sub.text = str(info.get("subtitle", ""))
	_body.text = summary_text(info)
	visible = true
	_details_t = DETAIL_DELAY
	_panel.modulate.a = 0.0
	_panel.visible = false
	_head.modulate.a = 0.0
	_head.scale = Vector2.ONE
	_dim.color.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(_dim, "color:a", 0.78, 1.0)
	tw.tween_property(_head, "modulate:a", 1.0, 0.7).set_delay(0.25)


## Özet panelini hemen açar (başlık animasyonu beklenmeden; tuş/tıklama ya da süre dolunca).
func show_details() -> void:
	if not visible or _panel.visible:
		return
	_details_t = -1.0
	_panel.visible = true
	_head.modulate.a = 1.0
	_dim.color.a = 0.78
	create_tween().tween_property(_panel, "modulate:a", 1.0, 0.45)
	_new_btn.grab_focus.call_deferred()


func details_visible() -> bool:
	return _panel.visible


func _process(delta: float) -> void:
	if _details_t > 0.0:
		_details_t -= delta
		if _details_t <= 0.0:
			show_details()


func _input(event: InputEvent) -> void:
	if not visible or _panel.visible:
		return
	var skip := (event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo) or \
		(event is InputEventMouseButton and (event as InputEventMouseButton).pressed)
	if skip and _details_t < DETAIL_DELAY - 0.4:
		show_details()
		get_viewport().set_input_as_handled()


## Panel açıkken R yeni run, Esc ana menü (dünya dursa da çalışır).
func _unhandled_input(event: InputEvent) -> void:
	if not visible or not _panel.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if k == KEY_R:
			new_run_requested.emit()
		elif k == KEY_ESCAPE:
			main_menu_requested.emit()
		else:
			return
		get_viewport().set_input_as_handled()


func hide_summary() -> void:
	visible = false
	_details_t = -1.0


static func summary_text(info: Dictionary) -> String:
	var lines: PackedStringArray = []
	var t := float(info["time"])
	lines.append("[b]%d. kat[/b] · Level [b]%d[/b] · Süre %d:%02d · Öldürme %d · Altın %d · Kazanılan XP %d" % [
		int(info["floor"]), int(info["level"]), floori(t / 60.0), floori(fmod(t, 60.0)), int(info["kills"]), int(info["gold"]), roundi(float(info["xp"]))])
	var rw: Array = info.get("rewards", [])
	lines.append("[color=#948578]Run ödülleri (run bitince kaybolur):[/color] %s" % (", ".join(rw) if not rw.is_empty() else "—"))
	var key := str(info["depth_key"])
	lines.append("")
	lines.append("[b]Silah tipi ustalığı[/b] (kalıcı) — derinlik çarpanı ×%s (%s), toplam %d XP" % [
		_num(Mastery.depth_multiplier(key)), DEPTH_NAMES.get(key, key), roundi(Mastery.run_xp(key))])
	var ms: Array = info.get("mastery", [])
	if ms.is_empty():
		lines.append("[color=#948578]Hasar verilmediği için ustalık XP'si yok.[/color]")
	for m: Dictionary in ms:
		var tname := str(DataDB.table("weapon_types")[str(m["type"])]["name"])
		var lvl_txt := "Level %d" % int(m["to_level"])
		if int(m["to_level"]) > int(m["from_level"]):
			lvl_txt = "[color=#8fd07a]Level %d → %d ↑[/color]" % [int(m["from_level"]), int(m["to_level"])]
		var prog := "maks" if float(m["xp_next"]) <= 0.0 else "%d / %d" % [floori(float(m["xp_now"])), roundi(float(m["xp_next"]))]
		var b := Mastery.stat_bonuses(int(m["to_level"]))
		lines.append("  %s: hasarın %%%d · +%d XP · %s (%s) · bonus: hasar +%%%s, hız +%%%s, menzil +%%%s, element +%%%s" % [
			tname, roundi(float(m["share"]) * 100.0), roundi(float(m["xp"])), lvl_txt, prog,
			_num(Mastery.bonus(int(m["to_level"]), "damage") * 100.0), _num(float(b["attack_speed"]) * 100.0),
			_num(float(b["attack_range"]) * 100.0), _num(float(b["element_damage"]) * 100.0)])
	var fk: Array = info.get("first_kills", [])
	if not fk.is_empty():
		lines.append("")
		lines.append("[color=#dba458]Boss ilk kesişi (kalıcı +%%0,3 hasar): %s[/color]" % ", ".join(fk))
	lines.append("")
	lines.append("[color=#948578]%s[/color]" % ("İlerleme kaydedildi." if bool(info.get("saved", true)) else "UYARI: kayıt yazılamadı!"))
	return "\n".join(lines)


const DEPTH_NAMES := {"death_floor_1": "1. katta ölüm", "death_floor_2": "2. katta ölüm", "clear_floor_2": "2. katı bitirme",
	"death_floor_3": "3. katta ölüm", "death_floor_4": "4. katta ölüm", "victory": "zafer"}


static func _num(f: float) -> String:
	if absf(f - roundf(f)) < 0.01:
		return str(roundi(f))
	return ("%.2f" % f).rstrip("0").rstrip(".").replace(".", ",")
