extends Node2D
## Renders every map and checks the world is actually connected and walkable,
## then saves a PNG of each so the tiles can be eyeballed.
##
##   xvfb-run -a godot --path <proj> res://tests/TestField.tscn --rendering-driver opengl3

const OUT_DIR := "user://shots/"
const TOUR := [
	["town", Vector2i(15, 22)],
	["world", Vector2i(20, 55)],
	["world", Vector2i(34, 30)],
	["shop", Vector2i(6, 8)],
	["millbrook", Vector2i(14, 23)],
	["ashfall", Vector2i(14, 23)],
	["barrow1", Vector2i(6, 28)],
	["thicket3", Vector2i(6, 20)],
	["cave1", Vector2i(8, 24)],
	["cave2", Vector2i(6, 22)],
	["cave3", Vector2i(5, 20)],
	["final", Vector2i(10, 17)],
]

var field: Node2D
var idx := 0
var frames := 0
var failures := 0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	Game.new_game("Wren", "fiddle", Sprites.build(Sprites.PRESETS[3].opts), "plant")
	field = preload("res://scenes/Field.tscn").instantiate()
	add_child(field)
	field.set_process(false)
	_audit()
	_go(0)


func _expect(cond: bool, what: String) -> void:
	if cond:
		print("  ok   %s" % what)
	else:
		print("  FAIL %s" % what)
		failures += 1


## Static checks that catch a broken world before anyone has to walk it.
func _audit() -> void:
	print("")
	print("== world audit ==")
	var maps := World.build_all()
	# derived rather than a magic number, so adding a town does not mean editing
	# the test -- but still exact, so a map that fails to build is still caught
	var expect := 10 + Places.towns().size() * 4
	for d in Places.dungeons():
		expect += int(d.floors)
	_expect(maps.size() == expect, "%d maps built (got %d)" % [expect, maps.size()])

	# every warp must land on a tile that exists and is not solid
	var bad_warps := 0
	for id in maps:
		var m: Maps.GameMap = maps[id]
		for wp in m.warps:
			if not maps.has(wp.to):
				print("    %s -> missing map %s" % [id, wp.to])
				bad_warps += 1
				continue
			var dest: Maps.GameMap = maps[wp.to]
			if Maps.is_solid(dest.get_tile(wp.tx, wp.ty)):
				print("    %s -> %s lands in solid tile '%s' at %d,%d" % [
					id, wp.to, dest.get_tile(wp.tx, wp.ty), wp.tx, wp.ty])
				bad_warps += 1
	_expect(bad_warps == 0, "every warp lands somewhere walkable")

	# a warp should not drop you straight back onto another warp
	var loops := 0
	for id in maps:
		var m: Maps.GameMap = maps[id]
		for wp in m.warps:
			var dest: Maps.GameMap = maps.get(wp.to)
			if dest == null:
				continue
			var back = dest.warp_at(wp.tx, wp.ty)
			if back != null and back.to == id:
				print("    %s <-> %s warp loop at %d,%d" % [id, wp.to, wp.tx, wp.ty])
				loops += 1
	_expect(loops == 0, "no warp lands directly on a return warp")

	# every start tile must be standable
	for id in maps:
		var m: Maps.GameMap = maps[id]
		if Maps.is_solid(m.get_tile(m.start.x, m.start.y)):
			_expect(false, "%s start tile is solid" % id)

	# NPCs, chests and bosses must not be buried in walls
	var buried := 0
	for id in maps:
		var m: Maps.GameMap = maps[id]
		for n in m.npcs:
			if n.get("sign", false):
				continue
			if Maps.is_solid(m.get_tile(n.x, n.y)):
				print("    %s: npc in solid tile at %d,%d" % [id, n.x, n.y])
				buried += 1
		for c in m.chests:
			if Maps.is_solid(m.get_tile(c.x, c.y)):
				print("    %s: chest in solid tile at %d,%d" % [id, c.x, c.y])
				buried += 1
		if m.boss != null and Maps.is_solid(m.get_tile(m.boss.x, m.boss.y)):
			print("    %s: boss in solid tile" % id)
			buried += 1
	_expect(buried == 0, "no NPC, chest or boss is buried in a wall")

	# the town exit must reach the cave mouth on the overworld: flood fill
	var world: Maps.GameMap = maps["world"]
	var reach := _flood(world, World.town_gate)
	_expect(reach.has(World.cave_mouth),
		"cave mouth at %s is reachable from the town gate at %s" % [World.cave_mouth, World.town_gate])
	print("  (overworld is %dx%d = %d tiles; %d reachable on foot from town)" % [
		world.w, world.h, world.w * world.h, reach.size()])

	# ---- high ground -------------------------------------------------------
	var high := 0
	var teasing := 0
	var first_bad := Vector2i(-1, -1)
	var neighbours: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(0, 1), Vector2i(0, -1)]
	for y in range(1, world.h - 1):
		for x in range(1, world.w - 1):
			if world.get_tile(x, y) != Maps.HIGH:
				continue
			high += 1
			if reach.has(Vector2i(x, y)):
				continue
			# stranded -- but that only matters if somebody can stand at its foot
			for step in neighbours:
				var n: Vector2i = Vector2i(x, y) + step
				if Maps.level_of(world.get_tile(n.x, n.y)) == 0 and reach.has(n):
					teasing += 1
					if first_bad.x < 0:
						first_bad = Vector2i(x, y)
					break
	_expect(high > 200, "there is high ground to climb (%d squares)" % high)
	_expect(teasing == 0,
		"no plateau you can reach the foot of but never climb (%d, first %s)" % [
			teasing, first_bad])

	# a ledge has to stop you, or the rock face is decoration over nothing
	var ledges := 0
	var leaks := 0
	for y in range(1, world.h - 1):
		for x in range(1, world.w - 1):
			if world.get_tile(x, y) != Maps.HIGH:
				continue
			var below := world.get_tile(x, y + 1)
			if Maps.level_of(below) != 0 or Maps.is_solid(below):
				continue
			ledges += 1
			if world.can_step(x, y + 1, x, y, {}):
				leaks += 1
	_expect(ledges > 30, "there are ledges (%d)" % ledges)
	_expect(leaks == 0, "you cannot walk up a ledge (%d places you could)" % leaks)

	# and the steps are the way through
	var steps := 0
	for y in world.h:
		for x in world.w:
			if world.get_tile(x, y) == Maps.STEPS:
				steps += 1
	_expect(steps > 0, "there are steps (%d)" % steps)
	_expect(Maps.levels_connect(Maps.STEPS, Maps.HIGH)
			and Maps.levels_connect(".", Maps.STEPS),
		"steps join the low ground to the high")
	_expect(not Maps.levels_connect(".", Maps.HIGH),
		"low ground and high ground do not join directly")

	# each cave floor must connect its entrance to its exit
	for pair in [["cave1", Vector2i(8, 24), Vector2i(33, 7)],
			["cave2", Vector2i(6, 22), Vector2i(17, 2)],
			["cave3", Vector2i(5, 20), Vector2i(16, 1)]]:
		var m: Maps.GameMap = maps[pair[0]]
		var r := _flood(m, pair[1])
		_expect(r.has(pair[2]), "%s: entrance connects to the way on" % pair[0])

	# The generated dungeons get the same treatment, and need it more: nobody
	# has ever looked at these floors. Walk from where the player lands to the
	# stairs down, or on the last floor to the boss and the prize behind it.
	var walled := 0
	for d in Places.dungeons():
		for i in int(d.floors):
			var id := "%s%d" % [d.id, i + 1]
			var m: Maps.GameMap = maps[id]
			var r := _flood(m, m.start)
			var targets: Array[Vector2i] = []
			for wp in m.warps:
				if str(wp.to).begins_with(d.id):
					targets.append(Vector2i(wp.x, wp.y))
			if m.boss != null:
				targets.append(Vector2i(m.boss.x, m.boss.y))
			for c in m.chests:
				targets.append(Vector2i(c.x, c.y))
			for t in targets:
				if not r.has(t):
					print("    %s: %s is walled off from the entrance" % [id, t])
					walled += 1
	_expect(walled == 0, "every generated dungeon floor is walkable end to end")

	# and every town must let you back out of the gate you came in by
	var stuck := 0
	for t in Places.towns():
		var m: Maps.GameMap = maps[t.id]
		var r := _flood(m, m.start)
		for wp in m.warps:
			if not r.has(Vector2i(wp.x, wp.y)):
				print("    %s: door at %d,%d cannot be reached" % [t.id, wp.x, wp.y])
				stuck += 1
	_expect(stuck == 0, "every town door can be walked to from the gate")


## Flood fill over a flat byte buffer. The old version kept a Dictionary keyed
## by Vector2i, which allocated an object per visited tile -- fine at 5,000
## tiles, ruinous at 512,000.
class Reach extends RefCounted:
	var seen: PackedByteArray
	var w: int
	var h: int
	var count: int = 0
	func _init(p_w: int, p_h: int) -> void:
		w = p_w
		h = p_h
		seen.resize(w * h)
	func has(p: Vector2i) -> bool:
		if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h:
			return false
		return seen[p.y * w + p.x] == 1
	func size() -> int:
		return count


func _flood(m: Maps.GameMap, from: Vector2i) -> Reach:
	var r := Reach.new(m.w, m.h)
	var stack: Array[Vector2i] = [from]
	while stack.size() > 0:
		var p: Vector2i = stack.pop_back()
		if p.x < 0 or p.y < 0 or p.x >= m.w or p.y >= m.h:
			continue
		var idx := p.y * m.w + p.x
		if r.seen[idx] == 1:
			continue
		if Maps.is_solid(m.get_tile(p.x, p.y)):
			continue
		r.seen[idx] = 1
		r.count += 1
		# the same height rule the player walks by: without it the fill strolls
		# up a cliff and reports a plateau as reachable because the squares
		# happen to be next to each other
		var here := m.get_tile(p.x, p.y)
		var steps: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0),
			Vector2i(0, 1), Vector2i(0, -1)]
		for step in steps:
			var n: Vector2i = p + step
			if Maps.levels_connect(here, m.get_tile(n.x, n.y)):
				stack.append(n)
	return r


func _go(i: int) -> void:
	field.enter(TOUR[i][0], TOUR[i][1])
	field.t = 1.0
	field.queue_redraw()


func _process(_d: float) -> void:
	frames += 1
	if frames < 4:
		return
	frames = 0
	var vt := get_viewport().get_texture()
	var img: Image = vt.get_image() if vt != null else null
	if img == null:
		print("  (no rendered image -- run under xvfb with --rendering-driver opengl3)")
		print("")
		print("FAILURES: %d" % failures if failures > 0 else "WORLD AUDIT PASSED (no screenshots)")
		get_tree().quit(1 if failures > 0 else 0)
		return
	var name := "%02d-%s-%d" % [idx, TOUR[idx][0], idx]
	img.save_png(OUT_DIR + name + ".png")
	var lit := 0
	for y in range(0, img.get_height(), 4):
		for x in range(0, img.get_width(), 4):
			var c := img.get_pixel(x, y)
			if c.r + c.g + c.b > 0.25:
				lit += 1
	print("  shot %-18s %d lit" % [name, lit])
	if lit < 100:
		print("    WARNING: %s looks nearly black" % name)
	idx += 1
	if idx >= TOUR.size():
		print("")
		print("FAILURES: %d" % failures if failures > 0 else "WORLD AUDIT PASSED")
		get_tree().quit(1 if failures > 0 else 0)
		return
	_go(idx)
