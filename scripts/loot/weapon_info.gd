## WeaponInfo — eşya tooltip'i ve stat karşılaştırması (GDD: Görsel Stil > Arayüz: stat karşılaştırmalı tooltip).
## Saf hesaptır: silahın oyuncunun ırkı ve leveliyle vuruş hasarı, saldırı hızı, DPS ve menzili; karşılaştırılan silaha
## (aktif silah) göre farklar. Metin RichTextLabel için BBCode'dur.
class_name WeaponInfo
extends RefCounted

const PCT_FIELDS := ["damage_pct", "attack_speed"]
const GOOD := "#7dff8a"
const BAD := "#ff7a6e"
const DIM := "#a8a8b4"


## Silahın bu ırk ve levelle statları (ustalık ve ödüller hariç; onlar Aşama 6'da).
static func stats(w: Weapon, race_id: String, player_level: int) -> Dictionary:
	var s := RaceStats.compute(race_id, player_level, w.family())
	var caps: Dictionary = DataDB.get_value("progression", "stat_caps")
	var hit := w.hit_damage() * (1.0 + s.damage_buffs)
	if w.is_elemental():
		var el: Dictionary = DataDB.table("elements")["elements"][w.element]
		hit *= (1.0 + s.element_bonus) * float(el.get("damage_mult", 1.0))
	var aps := float(w.type_data()["attacks_per_sec"]) * (1.0 + minf(s.attack_speed_bonus, float(caps["attack_speed"])))
	return {
		"hit": hit, "aps": aps, "dps": hit * aps,
		"range": float(w.type_data()["range"]) * (1.0 + s.attack_range_bonus),
		"max_hp": s.max_hp,
	}


## Şablon açıklamasındaki {alan}'ları sayılarla doldurur (yüzdeler ×100).
static func fill(template: String, d: Dictionary, element: String = "") -> String:
	var out := template
	for k: Variant in d.keys():
		var v: Variant = d[k]
		var txt := str(v)
		if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT:
			var f := float(v)
			if str(k) in PCT_FIELDS:
				f *= 100.0
			txt = _num(f)
		out = out.replace("{%s}" % k, txt)
	if element != "":
		out = out.replace("{element_name}", Weapon.kind_name(element))
	return out


static func _num(f: float) -> String:
	if absf(f - roundf(f)) < 0.001:
		return str(roundi(f))
	return ("%.2f" % f).rstrip("0").replace(".", ",")


## Tooltip metni. compare: karşılaştırılacak silah (null = yok). context: "" / "merchant" (fiyatla) / "sell".
static func tooltip(item: Variant, race_id: String, player_level: int, compare: Weapon = null, floor_i: int = 1, price_line: String = "") -> String:
	if item is Talisman:
		var t := item as Talisman
		var lines_t: PackedStringArray = [
			"[font_size=22][color=#%s]%s[/color][/font_size]" % [t.color().to_html(false), t.display_name()],
			"[color=%s]Tılsım · yalnızca Esnek slotta etki eder[/color]" % DIM,
			t.description(),
		]
		if price_line != "":
			lines_t.append(price_line)
		return "\n".join(lines_t)
	if not item is Weapon:
		return ""
	var w := item as Weapon
	var st := stats(w, race_id, player_level)
	var lines: PackedStringArray = []
	lines.append("[font_size=22][color=#%s]%s[/color][/font_size]" % [w.rarity_color().lightened(0.2).to_html(false), w.display_name()])
	var fam_name := str(DataDB.table("races")[w.family()]["name"])
	var sub := "%s · %s (%s ailesi) · Level %d" % [w.rarity_name(), w.type_name(), fam_name, w.level]
	lines.append("[color=%s]%s[/color]" % [DIM, sub])
	if w.is_locked(player_level):
		lines.append("[color=%s]KİLİTLİ — level %d gerekli (Rezonans ya da Esnek slota konabilir)[/color]" % [BAD, w.level])
	var el_line := "Element: [color=#%s]%s[/color]" % [Weapon.kind_color(w.element).to_html(false), Weapon.kind_name(w.element)]
	lines.append(el_line)
	for tid: String in w.traits:
		var td := Traits.data(tid)
		lines.append("Özellik: [b]%s[/b] — %s" % [td["name"], td["description"]])
	if w.is_legendary():
		var pd := w.passive_data()
		var sd := w.skill_data()
		lines.append("[color=#ffb35c]Efsanevi pasif:[/color] %s" % fill(str(pd["description"]), pd, w.element))
		lines.append("[color=#ffb35c]Sağ tık eki:[/color] %s" % fill(str(sd["description"]), sd, w.element))
	lines.append("Vuruş hasarı [b]%d[/b] · Saldırı/sn [b]%s[/b] · DPS [b]%d[/b] · Menzil [b]%s[/b] karo" % [
		roundi(st["hit"]), _num(snappedf(float(st["aps"]), 0.01)), roundi(st["dps"]), _num(snappedf(float(st["range"]), 0.1))])
	lines.append("Sağ tık: %s · Irk etkisi: %s" % [w.type_data()["heavy"]["name"], RaceStats.matrix_text(race_id, w.family())])
	var combat: Dictionary = DataDB.get_value("progression", "combat")
	var rpct := float(combat["resonance_locked_pct"] if w.is_locked(player_level) else combat["resonance_unlocked_pct"])
	lines.append("[color=%s]Rezonans'ta: her vuruşa +%d %s hasarı (%%%d) · Esnek'te: özellikler ve pasif %%%d[/color]" % [
		DIM, roundi(w.hit_damage() * rpct), Weapon.kind_name(w.element), roundi(rpct * 100.0), roundi(float(combat["flex_weapon_passive_pct"]) * 100.0)])
	if w.level < Weapon.max_level():
		lines.append("[color=%s]XP %d / %d[/color]" % [DIM, floori(w.xp), roundi(Weapon.xp_to_next(w.level))])
	if compare != null and compare != w:
		lines.append(compare_line(w, compare, race_id, player_level))
	if price_line != "":
		lines.append(price_line)
	return "\n".join(lines)


## "Aktif silahla kıyas (Kılıç): DPS +%12 · Vuruş −%5 · Menzil +0,5"
static func compare_line(w: Weapon, other: Weapon, race_id: String, player_level: int) -> String:
	var a := stats(w, race_id, player_level)
	var b := stats(other, race_id, player_level)
	var parts: PackedStringArray = []
	parts.append("DPS " + _pct_diff(float(a["dps"]), float(b["dps"])))
	parts.append("Vuruş " + _pct_diff(float(a["hit"]), float(b["hit"])))
	var dr := float(a["range"]) - float(b["range"])
	var col := GOOD if dr > 0.05 else (BAD if dr < -0.05 else DIM)
	parts.append("Menzil [color=%s]%s%s[/color]" % [col, "+" if dr >= 0.0 else "−", _num(snappedf(absf(dr), 0.1))])
	if absf(float(a["max_hp"]) - float(b["max_hp"])) >= 1.0:
		parts.append("Maks can " + _pct_diff(float(a["max_hp"]), float(b["max_hp"])))
	return "[color=%s]Aktif silahla kıyas (%s):[/color] %s" % [DIM, other.display_name(), " · ".join(parts)]


static func _pct_diff(x: float, y: float) -> String:
	if y <= 0.0:
		return "—"
	var d := (x / y - 1.0) * 100.0
	var col := GOOD if d > 0.5 else (BAD if d < -0.5 else DIM)
	return "[color=%s]%s%%%d[/color]" % [col, "+" if d >= 0.0 else "−", roundi(absf(d))]
