extends Node2D
## Exercises the map editor: paint, place objects, save, reload, and confirm
## the round trip preserves everything. Also screenshots the editor UI.

const OUT_DIR := "user://shots/"

var ed: Node2D
var failures := 0
var frames := 0
var shot_idx := 0
var done_logic := false


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	Game.new_game("Wren", "fiddle", Sprites.build(Sprites.PRESETS[3].opts), "plant")
	ed = preload("res://scenes/MapEditor.tscn").instantiate()
	add_child(ed)
	ed.set_process(false)


func _expect(cond: bool, what: String) -> void:
	if cond:
		print("  ok   %s" % what)
	else:
		print("  FAIL %s" % what)
		failures += 1


func _logic() -> void:
	print("")
	print("== map editor ==")
	_expect(ed.map != null, "editor opened a map (%s)" % (ed.map.id if ed.map else "-"))
	_expect(ed.map_ids.size() == 10, "all %d maps listed" % ed.map_ids.size())

	# switch to a small interior so the test is quick and deterministic
	var target: int = ed.map_ids.find("house1")
	ed._load(target)
	_expect(ed.map.id == "house1", "switched to house1")

	var before: String = ed.map.get_tile(4, 5)
	ed.push_undo()
	ed.map.set_tile(4, 5, "p")
	_expect(ed.map.get_tile(4, 5) == "p", "painted a barrel at 4,5")
	ed.map.tiles = ed.undo_stack.pop_back()
	_expect(ed.map.get_tile(4, 5) == before, "undo restored the tile")

	# paint a patch, place objects, then save
	ed.brush = "l"
	ed.push_undo()
	for y in range(3, 7):
		for x in range(3, 8):
			ed.map.set_tile(x, y, "l")
	var painted: int = 0
	for y in range(3, 7):
		for x in range(3, 8):
			if ed.map.get_tile(x, y) == "l":
				painted += 1
	_expect(painted == 20, "painted a 5x4 patch (%d tiles)" % painted)

	ed.obj_kind = "chest"
	ed.chest_item = "rosin2"
	ed._place(Vector2i(4, 4))
	ed.obj_kind = "npc"
	ed.npc_look = "miner"
	ed.npc_lines = "MINER"
	ed._place(Vector2i(6, 6))
	ed.obj_kind = "start"
	ed._place(Vector2i(5, 7))

	var n_chests: int = ed.map.chests.size()
	var n_npcs: int = ed.map.npcs.size()
	_expect(n_chests >= 2, "chest placed (%d on map)" % n_chests)
	_expect(n_npcs >= 2, "npc placed (%d on map)" % n_npcs)
	_expect(ed.map.start == Vector2i(5, 7), "start moved")

	var saved: Array = MapIO.save(ed.map)
	var path: String = saved[0]
	_expect(path != "", "saved to %s" % path)
	_expect(MapIO.has_saved("house1"), "save file exists")
	# in the editor this must be the committed copy, not the scratch layer
	_expect(MapIO.can_write_res(), "running with a writable res:// (editor build)")
	_expect(path.ends_with("maps/house1.json"), "wrote to the project maps folder")

	# round trip
	var reloaded := MapIO.load_map("house1")
	_expect(reloaded != null, "reloaded from disk")
	if reloaded != null:
		_expect(reloaded.w == ed.map.w and reloaded.h == ed.map.h, "size survives")
		var same := true
		for i in ed.map.tiles.size():
			if reloaded.tiles[i] != ed.map.tiles[i]:
				same = false
				break
		_expect(same, "every tile survives the round trip")
		_expect(reloaded.chests.size() == n_chests, "chests survive (%d)" % reloaded.chests.size())
		_expect(reloaded.npcs.size() == n_npcs, "npcs survive (%d)" % reloaded.npcs.size())
		_expect(reloaded.start == Vector2i(5, 7), "start survives")
		var found_npc := false
		for n in reloaded.npcs:
			if n.get("lines_key", "") == "MINER":
				found_npc = true
		_expect(found_npc, "editor-placed npc kept its dialogue key")
		_expect(Story.lines_for("MINER").size() > 0, "that key resolves to real dialogue")

	# a saved map must override the generated one on next world build
	World.maps.clear()
	var maps := World.build_all()
	var live: Maps.GameMap = maps["house1"]
	_expect(live.start == Vector2i(5, 7), "saved map overrides the generated one")

	# the scratch layer must win over the shipped copy
	MapIO.ensure_dir(MapIO.USER_DIR)
	var scratch: Maps.GameMap = MapIO.load_map("house1")
	scratch.start = Vector2i(3, 3)
	var uf := FileAccess.open(MapIO.path_in(MapIO.USER_DIR, "house1"), FileAccess.WRITE)
	uf.store_string(JSON.stringify(MapIO.to_dict(scratch), "\t"))
	uf.close()
	World.maps.clear()
	var layered: Maps.GameMap = World.build_all()["house1"]
	_expect(layered.start == Vector2i(3, 3), "scratch layer overrides the project copy")

	# saving again from the editor should clear the stale scratch file, so what
	# you just saved is what the game actually loads
	ed.map = layered
	ed.map.start = Vector2i(5, 7)
	var again: Array = MapIO.save(ed.map)
	_expect(again[1] != "", "saving cleared the stale scratch copy%s" % again[1])
	_expect(not FileAccess.file_exists(MapIO.path_in(MapIO.USER_DIR, "house1")),
		"scratch file really is gone")
	World.maps.clear()
	_expect(World.build_all()["house1"].start == Vector2i(5, 7), "the save is what loads")

	# X in the editor must be able to undo a bad save, or a map saved in a
	# browser can never be taken back
	ed.map.start = Vector2i(9, 9)
	MapIO.save(ed.map)
	_expect(MapIO.has_saved("house1"), "a saved map exists to revert")
	World.maps.clear()
	_expect(World.build_all()["house1"].start == Vector2i(9, 9), "the bad save is live")
	_expect(MapIO.revert("house1"), "revert removed the saved copy")
	_expect(not MapIO.has_saved("house1"), "no saved copy remains in either layer")
	World.maps.clear()
	_expect(World.build_all()["house1"].start != Vector2i(9, 9),
		"the generated map is back")

	# clean up so the repo does not gain a test map
	DirAccess.remove_absolute(ProjectSettings.globalize_path(MapIO.path_in(MapIO.RES_DIR, "house1")))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(MapIO.path_in(MapIO.USER_DIR, "house1")))
	World.maps.clear()
	_expect(not MapIO.has_saved("house1"), "test map cleaned up from both layers")
	print("")


func _process(_d: float) -> void:
	if not done_logic:
		_logic()
		done_logic = true
		ed._load(ed.map_ids.find("world"))
		ed.zoom = 8
		ed.cam = Vector2i(10, 40)
		ed.brush = "T"
		ed.queue_redraw()
		frames = 0
		return
	frames += 1
	if frames < 4:
		return
	frames = 0
	var img := get_viewport().get_texture().get_image()
	if img == null:
		# headless has no rendering device; the logic checks above are the point
		print("  (headless: skipping screenshots)")
		print("FAILURES: %d" % failures if failures > 0 else "EDITOR TESTS PASSED")
		get_tree().quit(1 if failures > 0 else 0)
		return
	img.save_png(OUT_DIR + "editor-%d.png" % shot_idx)
	print("  shot editor-%d" % shot_idx)
	shot_idx += 1
	if shot_idx == 1:
		ed._load(ed.map_ids.find("town"))
		ed.zoom = 16
		ed.cam = Vector2i(2, 2)
		ed.mode = "objects"
		ed.obj_kind = "npc"
		ed.queue_redraw()
		return
	print("FAILURES: %d" % failures if failures > 0 else "EDITOR TESTS PASSED")
	get_tree().quit(1 if failures > 0 else 0)
