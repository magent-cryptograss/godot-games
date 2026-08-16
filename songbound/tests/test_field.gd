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
	_expect(maps.size() == 10, "10 maps built (got %d)" % maps.size())

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
	var reach := _flood(world, Vector2i(20, 53))
	_expect(reach.has(Vector2i(48, 10)), "cave mouth is reachable from the town gate")
	_expect(reach.has(Vector2i(62, 46)), "the shrine clearing is reachable")
	print("  (overworld reachable tiles from town: %d)" % reach.size())

	# each cave floor must connect its entrance to its exit
	for pair in [["cave1", Vector2i(8, 24), Vector2i(33, 7)],
			["cave2", Vector2i(6, 22), Vector2i(17, 2)],
			["cave3", Vector2i(5, 20), Vector2i(16, 1)]]:
		var m: Maps.GameMap = maps[pair[0]]
		var r := _flood(m, pair[1])
		_expect(r.has(pair[2]), "%s: entrance connects to the way on" % pair[0])


func _flood(m: Maps.GameMap, from: Vector2i) -> Dictionary:
	var seen := {}
	var stack := [from]
	var guard := 0
	while stack.size() > 0 and guard < 200000:
		guard += 1
		var p: Vector2i = stack.pop_back()
		if seen.has(p):
			continue
		if p.x < 0 or p.y < 0 or p.x >= m.w or p.y >= m.h:
			continue
		if Maps.is_solid(m.get_tile(p.x, p.y)):
			continue
		seen[p] = true
		stack.append(p + Vector2i(1, 0))
		stack.append(p + Vector2i(-1, 0))
		stack.append(p + Vector2i(0, 1))
		stack.append(p + Vector2i(0, -1))
	return seen


func _go(i: int) -> void:
	field.enter(TOUR[i][0], TOUR[i][1])
	field.t = 1.0
	field.queue_redraw()


func _process(_d: float) -> void:
	frames += 1
	if frames < 4:
		return
	frames = 0
	var img := get_viewport().get_texture().get_image()
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
