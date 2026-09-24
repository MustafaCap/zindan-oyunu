## print_dungeon.gd'nin asıl kodu (bkz. orası).
extends RefCounted

func run() -> void:
	var fi := 1
	var sd := 42
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--floor="): fi = int(a.get_slice("=", 1))
		if a.begins_with("--seed="): sd = int(a.get_slice("=", 1))
	var L := DungeonGenerator.generate(fi, sd)
	var b := L.bounds()
	var letters := {"start": "S", "combat": "c", "elite": "E", "merchant": "M", "blacksmith": "B", "chest": "C", "secret": "?", "boss": "X"}
	var walls := {}
	for c: Vector2i in L.wall_cells(false): walls[c] = true
	var sw := {}
	for c: Vector2i in L.secret_wall_cells: sw[c] = true
	for y: int in range(b.position.y, b.end.y):
		var line := ""
		for x: int in range(b.position.x, b.end.x):
			var c := Vector2i(x, y)
			var rid := L.room_at(c)
			if sw.has(c): line += "%"
			elif L.is_obstacle(c) and (L.floor_cells.has(c) or L.secret_floor.has(c)): line += "o"
			elif rid >= 0 and c == L.rooms[rid].center(): line += letters[L.rooms[rid].type]
			elif L.floor_cells.has(c): line += "." if rid >= 0 else ","
			elif L.secret_floor.has(c): line += ":"
			elif walls.has(c): line += "#"
			else: line += " "
		print(line)
	for r: DungeonLayout.Room in L.rooms:
		var n := 0
		for w: Array in r.waves: n += w.size()
		print("%d %s grid=%s tpl=%s sym=%d depth=%d main=%s dalga=%d düşman=%d engel=%d" % [r.id, r.type, r.grid, r.template_id, r.symmetry, r.depth, r.on_main_path, r.waves.size(), n, r.obstacles.size()])
