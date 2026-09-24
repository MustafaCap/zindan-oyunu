## DungeonNav — zindanda engellerin etrafından dolaşmak için basit yol bulma (düşmanlar ve smoke botu kullanır).
## Hedefle arada engel yoksa doğrudan hedefe gidilir; varsa hedef karodan başlayan bir mesafe haritası (BFS,
## hedefin odasıyla sınırlı) çıkarılır ve bir sonraki adım en yakın komşu karoya doğru atılır.
## Mesafe haritaları hedef karoya göre önbelleklenir (oyuncu aynı karodayken yeniden hesaplanmaz).
class_name DungeonNav
extends RefCounted

const MAX_CACHE := 12
const CORRIDOR_DEPTH := 30
const DIRS8: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]

var layout: DungeonLayout
var walk: Dictionary = {}
var _fields: Dictionary = {}       ## hedef karo -> {karo: mesafe}
var _order: Array[Vector2i] = []


func _init(l: DungeonLayout, secrets_open: bool) -> void:
	layout = l
	walk = l.walkable(secrets_open)


## from → to için düz (zemin) uzayda birim yön. Yol yoksa doğrudan hedefe.
func direction(from_cell: Vector2i, to_cell: Vector2i, from_pos: Vector2, to_pos: Vector2, cell_to_world: Callable) -> Vector2:
	var direct := Iso.to_cart(to_pos - from_pos)
	if direct.length() < 0.001:
		return Vector2.ZERO
	if from_cell == to_cell or line_clear(from_cell, to_cell):
		return direct.normalized()
	var field := _field(to_cell)
	if not field.has(from_cell):
		return direct.normalized()
	var best := from_cell
	var best_d: int = field[from_cell]
	for d: Vector2i in DIRS8:
		var n := from_cell + d
		if not field.has(n):
			continue
		# çaprazda köşe kesilmesin
		if d.x != 0 and d.y != 0 and (not walk.has(from_cell + Vector2i(d.x, 0)) or not walk.has(from_cell + Vector2i(0, d.y))):
			continue
		if int(field[n]) < best_d:
			best_d = field[n]
			best = n
	if best == from_cell:
		return direct.normalized()
	var v := Iso.to_cart((cell_to_world.call(best) as Vector2) - from_pos)
	return v.normalized() if v.length() > 0.001 else direct.normalized()


## İki karo arasında bir gövde (yarıçap ~0,4 karo) engele takılmadan düz gidebilir mi? Çizgi ve iki yanındaki
## paralel çizgiler çeyrek karo adımlarla örneklenir (köşeye sürtünüp takılmayı da yakalar).
func line_clear(a: Vector2i, b: Vector2i) -> bool:
	var av := Vector2(a)
	var bv := Vector2(b)
	var d := bv - av
	var length := d.length()
	if length < 0.01:
		return true
	var n := Vector2(-d.y, d.x) / length * 0.42
	var steps := ceili(length * 4.0)
	for off: Vector2 in [Vector2.ZERO, n, -n]:
		for i: int in range(1, steps):
			var p := av + d * (float(i) / float(steps)) + off
			if not walk.has(Vector2i(roundi(p.x), roundi(p.y))):
				return false
	return true


func _field(target: Vector2i) -> Dictionary:
	if _fields.has(target):
		return _fields[target]
	var room_id := layout.room_at(target)
	var field := {target: 0}
	var queue: Array[Vector2i] = [target]
	var head := 0
	while head < queue.size():
		var c := queue[head]
		head += 1
		var dist: int = field[c]
		if room_id < 0 and dist >= CORRIDOR_DEPTH:
			continue
		for d: Vector2i in DIRS8:
			var n := c + d
			if field.has(n) or not walk.has(n):
				continue
			if room_id >= 0 and layout.room_at(n) != room_id:
				continue
			if d.x != 0 and d.y != 0 and (not walk.has(c + Vector2i(d.x, 0)) or not walk.has(c + Vector2i(0, d.y))):
				continue
			field[n] = dist + 1
			queue.append(n)
	_fields[target] = field
	_order.append(target)
	if _order.size() > MAX_CACHE:
		_fields.erase(_order.pop_front())
	return field
