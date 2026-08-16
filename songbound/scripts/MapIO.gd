class_name MapIO
extends RefCounted
## Maps as JSON on disk, in two layers.
##
##   res://maps/   the real ones. Committed to git, shipped with the game.
##   user://maps/  a scratch layer on top, for trying something without
##                 committing it. Delete the scratch file to revert.
##
## The game loads res:// first and lays user:// over it, so user:// always wins
## at runtime. The editor writes to res:// when it can -- which is whenever you
## run from inside Godot -- and falls back to user:// in an exported build,
## where res:// is read-only.

const RES_DIR := "res://maps/"
const USER_DIR := "user://maps/"


## True when running from the Godot editor, where res:// is a real folder on
## disk. False in an exported build, where it lives inside the .pck and cannot
## be written to.
static func can_write_res() -> bool:
	return OS.has_feature("editor")


static func write_dir() -> String:
	return RES_DIR if can_write_res() else USER_DIR


static func ensure_dir(d: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(d))


static func dir_path() -> String:
	return ProjectSettings.globalize_path(write_dir())


static func path_in(dir: String, id: String) -> String:
	return dir + id + ".json"


## Where this map would actually load from, honouring the layering.
static func effective_path(id: String) -> String:
	if FileAccess.file_exists(path_in(USER_DIR, id)):
		return path_in(USER_DIR, id)
	if FileAccess.file_exists(path_in(RES_DIR, id)):
		return path_in(RES_DIR, id)
	return ""


static func has_saved(id: String) -> bool:
	return effective_path(id) != ""


static func to_dict(m: Maps.GameMap) -> Dictionary:
	return {
		"v": 1,
		"id": m.id,
		"w": m.w,
		"h": m.h,
		"tiles": "".join(m.tiles),
		"region": m.region,
		"music": m.music,
		"indoor": m.indoor,
		"start": [m.start.x, m.start.y],
		"warps": m.warps,
		"npcs": _strip_runtime(m.npcs),
		"chests": m.chests,
		"boss": m.boss,
	}


## Drop fields the game adds while running, so saves stay diffable.
static func _strip_runtime(npcs: Array) -> Array:
	var out := []
	for n in npcs:
		var c: Dictionary = n.duplicate(true)
		c.erase("wt")
		out.append(c)
	return out


## Returns [absolute_path, note]. The note mentions a scratch file that was
## cleared, so saving never silently leaves a stale override in front of the
## map you just wrote.
static func save(m: Maps.GameMap) -> Array:
	var dir := write_dir()
	ensure_dir(dir)
	var f := FileAccess.open(path_in(dir, m.id), FileAccess.WRITE)
	if f == null:
		return ["", "could not open %s for writing" % path_in(dir, m.id)]
	f.store_string(JSON.stringify(to_dict(m), "\t"))
	f.close()
	var note := ""
	# If we just wrote the shipped copy, a leftover scratch copy would still win
	# at load time and quietly hide this save.
	if dir == RES_DIR and FileAccess.file_exists(path_in(USER_DIR, m.id)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path_in(USER_DIR, m.id)))
		note = " (cleared scratch copy)"
	return [ProjectSettings.globalize_path(path_in(dir, m.id)), note]


static func from_dict(d: Dictionary) -> Maps.GameMap:
	var m := Maps.GameMap.new(str(d.id), int(d.w), int(d.h), ".")
	var tiles: String = str(d.tiles)
	for i in mini(tiles.length(), m.w * m.h):
		m.tiles[i] = tiles[i]
	m.region = str(d.get("region", "meadow"))
	m.music = str(d.get("music", "field"))
	m.indoor = bool(d.get("indoor", false))
	var st: Array = d.get("start", [1, 1])
	m.start = Vector2i(int(st[0]), int(st[1]))
	m.warps = d.get("warps", [])
	m.npcs = d.get("npcs", [])
	m.chests = d.get("chests", [])
	m.boss = d.get("boss", null)
	return m


static func _read(path: String) -> Maps.GameMap:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("map file is not valid JSON: " + path)
		return null
	return from_dict(parsed)


static func load_map(id: String) -> Maps.GameMap:
	var p := effective_path(id)
	return _read(p) if p != "" else null


static func _ids_in(dir: String) -> Array:
	var out := []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	d.list_dir_begin()
	var fname := d.get_next()
	while fname != "":
		# exported builds append .remap to res:// files
		if fname.ends_with(".json"):
			out.append(fname.get_basename())
		elif fname.ends_with(".json.remap"):
			out.append(fname.get_basename().get_basename())
		fname = d.get_next()
	d.list_dir_end()
	return out


## Delete every saved copy of a map, in both layers, so it falls back to the
## version World.gd generates. Without this a map saved in a browser could never
## be undone: it overrides the generated world on every load, and user:// lives
## inside IndexedDB where the player cannot reach it.
static func revert(id: String) -> bool:
	var removed := false
	for dir in [USER_DIR, RES_DIR]:
		var path := path_in(dir, id)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
			removed = true
	return removed


## Lay the shipped maps down first, then the scratch layer on top.
static func apply_overrides(maps: Dictionary) -> int:
	ensure_dir(USER_DIR)
	var n := 0
	for dir in [RES_DIR, USER_DIR]:
		for id in _ids_in(dir):
			var m := _read(path_in(dir, id))
			if m == null:
				continue
			Maps.prerender(m)
			maps[id] = m
			n += 1
	return n
