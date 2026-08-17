extends Node
## Global game state and save/load.

const SAVE_PATH := "user://songbound_save.json"

var player: Player = null
var map_id: String = "town"
var tile_pos := Vector2i.ZERO
## Last position on the overworld, kept so the map can say "you are here" from
## inside a town or a cave, where tile_pos is a local coordinate.
var world_pos := Vector2i.ZERO
var facing: String = "down"
var steps: int = 0
var pending_ending := false
var level_queue: Array[int] = []

signal level_gained(levels: Array)


func new_game(p_name: String, inst_id: String, spr: PackedByteArray, first_element: String,
		views: Dictionary = {}) -> Player:
	var p := Player.new(p_name, inst_id, spr)
	# whatever the player drew by hand; the rest are filled in from the front
	p.back = views.get("up", PackedByteArray())
	p.side_l = views.get("left", PackedByteArray())
	p.side_r = views.get("right", PackedByteArray())
	p.derive_views()
	# level 1 is itself a song level, so the first element pick teaches a song
	p.apply_level_choice(first_element, 1)
	player = p
	map_id = "town"
	steps = 0
	pending_ending = false
	level_queue.clear()
	return p


func award_xp(amount: int) -> Array[int]:
	if player == null:
		return []
	var gained := player.grant_xp(amount)
	if gained.size() > 0:
		level_queue = gained.duplicate()
		level_gained.emit(gained)
	return gained


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> bool:
	if player == null:
		return false
	var d := player.to_dict()
	d["map_id"] = map_id
	d["tile_x"] = tile_pos.x
	d["tile_y"] = tile_pos.y
	d["world_x"] = world_pos.x
	d["world_y"] = world_pos.y
	d["facing"] = facing
	d["steps"] = steps
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(d))
	f.close()
	return true


func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var txt := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	player = Player.from_dict(parsed)
	player.back = Sprites.back_view(player.spr)
	map_id = str(parsed.get("map_id", "town"))
	tile_pos = Vector2i(int(parsed.get("tile_x", 0)), int(parsed.get("tile_y", 0)))
	world_pos = Vector2i(int(parsed.get("world_x", 0)), int(parsed.get("world_y", 0)))
	facing = str(parsed.get("facing", "down"))
	steps = int(parsed.get("steps", 0))
	return true


func erase_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
