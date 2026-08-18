extends Node2D
## How much is there to find, per screen of ground you can actually walk on?
##
## Not a pass/fail test -- a measurement, run by hand when the world feels thin:
##
##   godot --headless --path <proj> res://tests/Density.tscn
##
## "Big" and "full" are different things, and this is the number that tells them
## apart: a world can grow a hundredfold and get emptier with every step.
##
## Runs as a scene rather than with --script, because --script skips the
## autoloads and half the scripts in the project then compile to nothing --
## which looks exactly like a world full of broken signposts.

func _ready() -> void:
	var maps := World.build_all()
	var m: Maps.GameMap = maps["world"]

	# flood fill from the town gate, walking the same rule the player does
	var seen := {}
	var stack: Array[Vector2i] = [World.town_gate]
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		if p.x < 0 or p.y < 0 or p.x >= m.w or p.y >= m.h:
			continue
		if seen.has(p):
			continue
		if Maps.is_solid(m.get_tile(p.x, p.y)):
			continue
		seen[p] = true
		var here := m.get_tile(p.x, p.y)
		for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = p + step
			if Maps.levels_connect(here, m.get_tile(n.x, n.y)):
				stack.append(n)

	var walkable := seen.size()
	# what one screen of an 800x600 window holds, at 48 pixels to the tile
	var per_screen := 17 * 13
	var screens := float(walkable) / float(per_screen)

	print("world           %d x %d = %d tiles" % [m.w, m.h, m.w * m.h])
	print("reachable       %d tiles (%.0f%%)" % [walkable, 100.0 * walkable / float(m.w * m.h)])
	print("that is         %.0f screenfuls of walking" % screens)

	var chests := _reachable(m.chests, seen)
	# a signpost stands on a solid square -- you read it from beside it, so what
	# counts is whether you can stand next to it, not on it
	var npcs := _reachable(m.npcs, seen)
	var warps: int = m.warps.size()
	print("chests          %d of %d you can get to" % [chests, m.chests.size()])
	print("npcs/signs      %d of %d you can stand beside" % [npcs, m.npcs.size()])
	print("doors           %d" % warps)

	var things := chests + npcs + warps
	print("---")
	print("%d things over %.0f screens" % [things, screens])
	print("SOMETHING TO SEE every %.1f screens" % (screens / float(maxi(things, 1))))
	get_tree().quit()


## Can the player get to this, or stand next to it?
static func _reachable(list: Array, seen: Dictionary) -> int:
	var n := 0
	for e in list:
		var p := Vector2i(int(e.x), int(e.y))
		if seen.has(p) or seen.has(p + Vector2i(0, 1)) or seen.has(p + Vector2i(0, -1)) \
				or seen.has(p + Vector2i(1, 0)) or seen.has(p + Vector2i(-1, 0)):
			n += 1
	return n
