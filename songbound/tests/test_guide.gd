extends Node2D
## Checks the things that tell the player what to do.
##
## The complaint that started this was "it isn't clear what I'm supposed to do",
## so the checks are the literal claims being made: every place has a name, the
## goal advances as the story does, the compass points the right way, and the
## roads are still visible after the overworld is squashed onto a 200-pixel map
## -- that last one is the whole reason the map is worth opening.

const OUT_DIR := "user://shots/"

var failures := 0
var menu: Node2D = null
var frames := 0
var shot := 0


func _expect(cond: bool, what: String) -> void:
	if cond:
		print("  ok   %s" % what)
	else:
		print("  FAIL %s" % what)
		failures += 1


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	print("")
	print("== guidance ==")
	Game.new_game("Wren", "fiddle", Sprites.build(Sprites.PRESETS[3].opts), "plant")
	var maps := World.build_all()

	# 1. every place a player can stand in and wonder about has a name
	var unnamed: Array = []
	for t in Places.towns():
		if Guide.place_name(t.id) == "":
			unnamed.append(t.id)
	for d in Places.dungeons():
		for i in int(d.floors):
			if Guide.place_name("%s%d" % [d.id, i + 1]) == "":
				unnamed.append("%s%d" % [d.id, i + 1])
	for id in ["town", "cave1", "cave2", "cave3", "final"]:
		if Guide.place_name(id) == "":
			unnamed.append(id)
	_expect(unnamed.is_empty(), "every town and dungeon floor has a name (%s)" % str(unnamed))

	# 2. the goal moves along with the story rather than sitting on step one
	var p := Game.player
	p.flags = {}
	var g1 := Guide.objective()
	p.flags["seen_world"] = true
	var g2 := Guide.objective()
	p.flags["boss_gravebell"] = true
	var g3 := Guide.objective()
	p.flags["boss_conductor"] = true
	p.flags["boss_quiet"] = true
	var g4 := Guide.objective()
	_expect(g1.title != g2.title and g2.title != g3.title and g3.title != g4.title,
		"the goal advances (%s -> %s -> %s -> %s)" % [g1.title, g2.title, g3.title, g4.title])
	_expect(g2.map == "world" and g2.at == World.cave_mouth,
		"the second goal points at the cave mouth")

	# 3. the compass agrees with the map. The cave is north of town and the town
	#    is south of the cave, and if those two ever disagree it is pointing at
	#    nothing.
	var up := Guide.compass(World.town_gate, World.cave_mouth)
	var down := Guide.compass(World.cave_mouth, World.town_gate)
	_expect(up.begins_with("north"), "the cave lies %s of town" % up)
	_expect(down.begins_with("south"), "town lies %s of the cave" % down)
	_expect(Guide.compass(World.town_gate, World.town_gate) == "here",
		"standing on a place reads as 'here'")

	# 4. every place is listed, nearest first
	var places := Guide.places_from(World.town_gate)
	_expect(places.size() == 12, "all 12 places listed (got %d)" % places.size())
	var ordered := true
	for i in range(1, places.size()):
		if places[i].dist < places[i - 1].dist:
			ordered = false
	_expect(ordered, "listed nearest first")

	# 5. THE ONE THAT MATTERS. The overworld is squashed by about 4x to fit the
	#    screen, and a road is one tile wide -- under any averaging it vanishes,
	#    and a map with no roads on it is a picture of some hills.
	var tex := Guide.world_texture(202, 162)
	var img := tex.get_image()
	var road_px := 0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.is_equal_approx(Color(Guide.MAP_COLS["="])) or c.is_equal_approx(Color(Guide.MAP_COLS["B"])):
				road_px += 1
	print("  (map is %dx%d at 1px per %d tiles; %d road pixels)" % [
		img.get_width(), img.get_height(), Guide.map_scale(), road_px])
	_expect(road_px > 300, "roads survive the shrink (%d road pixels)" % road_px)

	# A site is one tile and is not meant to survive the shrink -- the menu
	# draws a marker for each. What can go wrong is a marker landing off the
	# edge of the picture, so check every one of them lands on it.
	var sc := float(Guide.map_scale())
	var off: Array = []
	for pl in Guide.places_from(World.town_gate):
		var mx := int(float(pl.at.x) / sc)
		var my := int(float(pl.at.y) / sc)
		if mx < 1 or my < 1 or mx >= img.get_width() - 1 or my >= img.get_height() - 1:
			off.append("%s at %d,%d" % [pl.name, mx, my])
	_expect(off.is_empty(), "every place marker lands on the map (%s)" % str(off))

	# 6. signposts name real places rather than repeating one generic notice
	var world: Maps.GameMap = maps["world"]
	var sign_bodies := {}
	for n in world.npcs:
		if n.get("sign", false):
			sign_bodies[str(n.lines)] = true
	_expect(sign_bodies.size() >= 8,
		"roadside signs differ from each other (%d distinct)" % sign_bodies.size())

	# and now photograph the two new pages
	menu = preload("res://scenes/Menu.tscn").instantiate()
	add_child(menu)
	menu.set_process(false)
	menu.page = "where"
	menu.queue_redraw()


func _process(_d: float) -> void:
	frames += 1
	if frames < 4:
		return
	frames = 0
	var vt := get_viewport().get_texture()
	var img: Image = vt.get_image() if vt != null else null
	if img == null:
		print("  (no rendering device -- logic checks only)")
		_finish()
		return
	var names := ["where", "map"]
	img.save_png(OUT_DIR + "guide-%02d-%s.png" % [shot, names[shot]])
	print("  shot guide-%s" % names[shot])
	shot += 1
	if shot >= names.size():
		_finish()
		return
	menu.page = names[shot]
	menu.sub = 3
	menu.queue_redraw()


func _finish() -> void:
	print("")
	if failures > 0:
		print("FAILURES: %d" % failures)
	else:
		print("GUIDANCE PASSED")
	get_tree().quit(1 if failures > 0 else 0)
