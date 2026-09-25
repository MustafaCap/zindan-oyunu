## LootDrop — yerdeki loot (placeholder çizim): altın, iksir, silah ya da tılsım.
## GDD Görsel Stil > Loot: düşen eşyanın nadirliğine göre ışık sütunu (Yaygın gri, Ender mavi, Destansı mor,
## Efsanevi turuncu; nadirlik arttıkça sütun uzar, efsanevi nabız gibi atar).
## Altın yaklaşınca kendiliğinden toplanır, iksir üstünden geçince (taşıma sınırı dolmadıysa); silah ve tılsım F ile
## alınır (DungeonRun); uygun boş slot yoksa F yerdekiyle değiştirir ve eski eşya yere düşer. Oyuncu yakındayken eşyanın adı sütunun üstünde görünür.
class_name LootDrop
extends Node2D

const BEAM_HEIGHT := {"common": 46.0, "rare": 80.0, "epic": 120.0, "legendary": 175.0}
const GOLD_COLOR := Color(1.0, 0.82, 0.25)
const POTION_COLOR := Color(0.95, 0.3, 0.4)

var kind: String = "gold"       ## gold, potion, weapon, talisman
var amount: int = 0             ## altın miktarı
var item: Variant               ## Weapon ya da Talisman
var player_near: bool = false   ## DungeonRun işaretler: ad etiketi görünür
var picked: bool = false
var _t: float = 0.0
var _toss_k: float = 1.0
var _toss_from: Vector2 = Vector2.ZERO


static func make(p_kind: String, p_item: Variant = null, p_amount: int = 0) -> LootDrop:
	var d := LootDrop.new()
	d.kind = p_kind
	d.item = p_item
	d.amount = p_amount
	return d


func _ready() -> void:
	_t = randf() * 3.0


func is_item() -> bool:
	return kind == "weapon" or kind == "talisman"


func color() -> Color:
	match kind:
		"weapon": return (item as Weapon).rarity_color()
		"talisman": return (item as Talisman).color()
		"potion": return POTION_COLOR
	return GOLD_COLOR


func label_text() -> String:
	match kind:
		"weapon":
			var w := item as Weapon
			return "%s · Lv %d" % [w.display_name(), w.level]
		"talisman": return "Tılsım: %s" % (item as Talisman).display_name()
		"potion": return "İksir"
	return "%d altın" % amount


## Etkileşim ipucu (yalnızca silah ve tılsım F ile alınır).
func prompt() -> String:
	if picked or not is_item():
		return ""
	var inv := GameState.inventory
	if inv and inv.free_slot_for(item, GameState.level) == "" and inv.first_free_bag() < 0:
		var slot := inv.swap_slot_for(item, GameState.level)
		var old: Variant = inv.slots.get(slot)
		if old != null:
			return "F: Değiştir — %s  ↔  %s: %s (yere düşer)" % [label_text(), Inventory.SLOT_TITLES[slot], (old as Object).call("display_name")]
	return "F: Al — %s" % label_text()


func beam_height() -> float:
	match kind:
		"weapon": return float(BEAM_HEIGHT.get((item as Weapon).rarity_id, 46.0))
		"talisman": return float(BEAM_HEIGHT["epic"])
	return 0.0


## Yerden kalkış animasyonu: düşmanın yerinden hedef noktaya sekerek (0,35 sn).
func toss(from: Vector2, to: Vector2) -> void:
	global_position = to
	_toss_from = from - to
	_toss_k = 0.0
	var tw := create_tween()
	tw.tween_property(self, "_toss_k", 1.0, 0.35)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var k := _toss_k
	var off := Vector2.ZERO
	if k < 1.0:
		off = _toss_from * (1.0 - k) + Vector2(0, -40.0 * sin(k * PI))
	var col := color()
	var h := beam_height()
	if h > 0.0 and k >= 1.0:
		var pulse := 1.0
		if kind == "weapon" and (item as Weapon).rarity_id == "legendary":
			pulse = 0.75 + 0.25 * sin(_t * 5.0)
		var w0 := 9.0
		var pts := PackedVector2Array([Vector2(-w0, 0), Vector2(w0, 0), Vector2(w0 * 0.5, -h), Vector2(-w0 * 0.5, -h)])
		var cols := PackedColorArray([Color(col, 0.55 * pulse), Color(col, 0.55 * pulse), Color(col, 0.0), Color(col, 0.0)])
		draw_polygon(pts, cols)
		var core := PackedVector2Array([Vector2(-2.5, 0), Vector2(2.5, 0), Vector2(1, -h * 0.85), Vector2(-1, -h * 0.85)])
		draw_polygon(core, PackedColorArray([Color(1, 1, 1, 0.7 * pulse), Color(1, 1, 1, 0.7 * pulse), Color(1, 1, 1, 0), Color(1, 1, 1, 0)]))
		var ring := Shapes.iso_ellipse(0.45 + 0.05 * sin(_t * 3.0), 20)
		draw_colored_polygon(ring, Color(col, 0.22 * pulse))
	match kind:
		"gold":
			for i: int in mini(3 + amount / 20, 6):
				var p := off + Vector2((i % 3 - 1) * 6.0, -3.0 - (i / 3) * 4.0)
				draw_circle(p, 4.5, GOLD_COLOR.darkened(0.3))
				draw_circle(p + Vector2(-1, -1), 3.5, GOLD_COLOR)
		"potion":
			draw_circle(off + Vector2(0, -8), 7.0, POTION_COLOR)
			draw_rect(Rect2(off + Vector2(-2.5, -20), Vector2(5, 6)), Color(0.85, 0.85, 0.9))
			draw_circle(off + Vector2(-2, -10), 2.0, Color(1, 1, 1, 0.7))
		"weapon":
			var w := item as Weapon
			var c2 := Weapon.kind_color(w.element)
			draw_line(off + Vector2(-12, -2), off + Vector2(12, -14), Color(0, 0, 0, 0.6), 6.0)
			draw_line(off + Vector2(-12, -2), off + Vector2(12, -14), c2, 3.5)
			draw_line(off + Vector2(-8, -9), off + Vector2(-4, 1), w.rarity_color(), 3.0)
		"talisman":
			var t := item as Talisman
			draw_colored_polygon(PackedVector2Array([off + Vector2(0, -20), off + Vector2(8, -10), off + Vector2(0, 0), off + Vector2(-8, -10)]), t.color())
			draw_polyline(PackedVector2Array([off + Vector2(0, -20), off + Vector2(8, -10), off + Vector2(0, 0), off + Vector2(-8, -10), off + Vector2(0, -20)]), Color(1, 1, 1, 0.7), 1.5)
	if player_near and k >= 1.0 and kind != "gold":
		var font := ThemeDB.fallback_font
		var txt := label_text()
		var y := -maxf(h, 30.0) - 8.0
		draw_string_outline(font, Vector2(-160, y), txt, HORIZONTAL_ALIGNMENT_CENTER, 320, 15, 4, Color.BLACK)
		draw_string(font, Vector2(-160, y), txt, HORIZONTAL_ALIGNMENT_CENTER, 320, 15, col.lightened(0.35))
