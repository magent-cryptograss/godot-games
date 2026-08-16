extends Node2D
## A map editor you can actually use.
##
## Reachable from the title screen, so it works in the web build too -- opening
## a scene in the Godot editor is no use to somebody playing in a browser.
##
## Paint tiles, place NPCs, chests, warps, the boss and the player start, then
## save. Saved maps live in user://maps/*.json and override the generated ones
## at load, so you can redraw one corner of the game without touching code.

const VIEW_X := 0
const VIEW_Y := 12
const VIEW_W := 250
const VIEW_H := 216
const PAL_X := 253
const PAL_Y := 22
const PAL_CELL := 17
const EXIT_X := 284

signal closed

const TILE_ORDER := [
	".", ",", "\"", "f", "=", "o", "q", "B",
	"~", "T", "P", "^", "r", "%", "F", "#",
	"W", "R", "V", "d", "_", "l", "D", "*",
	"X", "b", "c", "t", "p", "g", "S", "w",
	"C", "m",
]
const TILE_NAMES := {
	".": "grass", ",": "tall grass", "\"": "scrub", "f": "flowers", "=": "road",
	"o": "stone path", "q": "dirt", "B": "bridge", "~": "water", "T": "tree",
	"P": "pine", "^": "mountain", "r": "rock", "%": "bush", "F": "fence",
	"#": "stone wall", "W": "wood wall", "R": "roof", "V": "roof peak",
	"d": "door", "_": "wood floor", "l": "tiles", "D": "cave floor",
	"*": "lit floor", "X": "cave wall", "b": "bed", "c": "counter", "t": "table",
	"p": "barrel", "g": "grave", "S": "sign", "w": "well", "C": "cave mouth",
	"m": "void",
}

var map_ids: Array = []
var map_idx := 0
var map: Maps.GameMap = null

var zoom := 8
var cam := Vector2i(0, 0)
var brush := "."
var mode := "tiles"                 # tiles | objects
var obj_kind := "npc"               # start | npc | chest | warp | boss
var npc_look := "woman"
var npc_lines := "OLDMAN"
var chest_item := "tonic"
var warp_to := "town"
var status := "ready"
var status_t := 0.0
var show_grid := true
var undo_stack: Array = []

var t := 0.0
var repeat_t := {}
var _tex := {}
var _was_left := false
var _was_right := false


func _ready() -> void:
	var maps := World.build_all()
	MapIO.apply_overrides(maps)
	map_ids = maps.keys()
	map_ids.sort()
	_load(0)
	for ch in TILE_ORDER:
		var imgs: Array = Maps.atlas().get(ch, [])
		if imgs.size() > 0:
			_tex[ch] = ImageTexture.create_from_image(imgs[0])
	set_process(true)


func _load(i: int) -> void:
	map_idx = wrapi(i, 0, map_ids.size())
	map = World.build_all()[map_ids[map_idx]]
	cam = Vector2i(0, 0)
	undo_stack.clear()
	_say("loaded %s (%dx%d)" % [map.id, map.w, map.h])


func _say(s: String) -> void:
	status = s
	status_t = 0.0


func repeated(action: String, dt: float) -> bool:
	if Input.is_action_just_pressed(action):
		repeat_t[action] = 0.0
		return true
	if Input.is_action_pressed(action):
		repeat_t[action] = repeat_t.get(action, 0.0) + dt
		if repeat_t[action] > 0.25:
			repeat_t[action] -= 0.04
			return true
	else:
		repeat_t[action] = 0.0
	return false


func _tiles_across() -> int:
	return int(VIEW_W / zoom)

func _tiles_down() -> int:
	return int(VIEW_H / zoom)


func mouse_in(x: float, y: float, w: float, h: float) -> bool:
	var m := get_local_mouse_position()
	return m.x >= x and m.y >= y and m.x < x + w and m.y < y + h


func cursor_tile() -> Vector2i:
	var m := get_local_mouse_position()
	if m.x < VIEW_X or m.x >= VIEW_X + VIEW_W or m.y < VIEW_Y or m.y >= VIEW_Y + VIEW_H:
		return Vector2i(-1, -1)
	return Vector2i(cam.x + int((m.x - VIEW_X) / zoom), cam.y + int((m.y - VIEW_Y) / zoom))


func push_undo() -> void:
	undo_stack.append(map.tiles.duplicate())
	if undo_stack.size() > 40:
		undo_stack.pop_front()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var k := event as InputEventKey
	match k.keycode:
		KEY_TAB:
			mode = "objects" if mode == "tiles" else "tiles"
			_say("mode: " + mode)
		KEY_BRACKETLEFT:
			_load(map_idx - 1)
		KEY_BRACKETRIGHT:
			_load(map_idx + 1)
		KEY_MINUS:
			zoom = maxi(4, zoom / 2)
			_say("zoom %d" % zoom)
		KEY_EQUAL:
			zoom = mini(16, zoom * 2)
			_say("zoom %d" % zoom)
		KEY_G:
			show_grid = not show_grid
		KEY_U:
			if undo_stack.size() > 0:
				map.tiles = undo_stack.pop_back()
				_say("undo")
		KEY_F:
			var c := cursor_tile()
			if c.x >= 0:
				push_undo()
				_flood(c, brush)
				_say("filled")
		KEY_ESCAPE, KEY_Q:
			# ESC alone is not enough: browsers grab it for fullscreen and
			# pointer-lock, so in a web build it never reaches the game. Q works
			# everywhere, and there is a clickable EXIT button as well.
			closed.emit()
		KEY_C:
			# In a browser, res:// is read-only and user:// is buried in
			# IndexedDB, so the clipboard is the only way a map gets out.
			DisplayServer.clipboard_set(JSON.stringify(MapIO.to_dict(map), "\t"))
			_say("map JSON copied to clipboard")
		KEY_S:
			var res: Array = MapIO.save(map)
			var p: String = res[0]
			var note: String = res[1]
			if p == "":
				_say("SAVE FAILED: " + note)
			else:
				var layer := "project" if MapIO.can_write_res() else "scratch"
				_say("saved to %s%s" % [layer, note])
			print("[editor] saved %s -> %s%s" % [map.id, p, note])
		KEY_X:
			# undo a bad save: drop the file and go back to the generated map
			var had := MapIO.revert(map.id)
			World.maps.clear()
			var regenerated: Maps.GameMap = World.build_all()[map.id]
			map = regenerated
			undo_stack.clear()
			_say("reverted to the generated map" if had else "no saved copy to revert")
		KEY_R:
			var fresh := MapIO.load_map(map.id)
			if fresh != null:
				World.build_all()[map.id] = fresh
				map = fresh
				_say("reloaded from disk")
			else:
				_say("no saved file for " + map.id)
		KEY_1: obj_kind = "start"; mode = "objects"; _say("place: start")
		KEY_2: obj_kind = "npc"; mode = "objects"; _say("place: npc")
		KEY_3: obj_kind = "chest"; mode = "objects"; _say("place: chest")
		KEY_4: obj_kind = "warp"; mode = "objects"; _say("place: warp")
		KEY_5: obj_kind = "boss"; mode = "objects"; _say("place: boss")
		KEY_COMMA: _cycle_obj_prop(-1)
		KEY_PERIOD: _cycle_obj_prop(1)
		KEY_DELETE, KEY_BACKSPACE:
			var c := cursor_tile()
			if c.x >= 0:
				_erase_object(c)


func _cycle_obj_prop(d: int) -> void:
	match obj_kind:
		"npc":
			var looks := Sprites.NPC_LOOKS.keys()
			npc_look = looks[wrapi(looks.find(npc_look) + d, 0, looks.size())]
			_say("npc look: " + npc_look)
		"chest":
			var items := Data.ITEMS.keys()
			chest_item = items[wrapi(items.find(chest_item) + d, 0, items.size())]
			_say("chest item: " + Data.item_name(chest_item))
		"warp":
			warp_to = map_ids[wrapi(map_ids.find(warp_to) + d, 0, map_ids.size())]
			_say("warp to: " + warp_to)
		_:
			pass


func _flood(at: Vector2i, to: String) -> void:
	var from := map.get_tile(at.x, at.y)
	if from == to:
		return
	var stack := [at]
	var guard := 0
	while stack.size() > 0 and guard < 60000:
		guard += 1
		var p: Vector2i = stack.pop_back()
		if p.x < 0 or p.y < 0 or p.x >= map.w or p.y >= map.h:
			continue
		if map.get_tile(p.x, p.y) != from:
			continue
		map.set_tile(p.x, p.y, to)
		stack.append(p + Vector2i(1, 0))
		stack.append(p + Vector2i(-1, 0))
		stack.append(p + Vector2i(0, 1))
		stack.append(p + Vector2i(0, -1))


func _erase_object(c: Vector2i) -> void:
	for i in range(map.npcs.size() - 1, -1, -1):
		if map.npcs[i].x == c.x and map.npcs[i].y == c.y:
			map.npcs.remove_at(i)
			_say("removed npc")
			return
	for i in range(map.chests.size() - 1, -1, -1):
		if map.chests[i].x == c.x and map.chests[i].y == c.y:
			map.chests.remove_at(i)
			_say("removed chest")
			return
	for i in range(map.warps.size() - 1, -1, -1):
		if map.warps[i].x == c.x and map.warps[i].y == c.y:
			map.warps.remove_at(i)
			_say("removed warp")
			return
	if map.boss != null and map.boss.x == c.x and map.boss.y == c.y:
		map.boss = null
		_say("removed boss")


func _place(c: Vector2i) -> void:
	match obj_kind:
		"start":
			map.start = c
			_say("start set to %d,%d" % [c.x, c.y])
		"npc":
			_erase_object(c)
			map.npcs.append({"x": c.x, "y": c.y, "look": npc_look, "dir": "down",
				"lines_key": npc_lines})
			_say("npc placed (%s)" % npc_look)
		"chest":
			_erase_object(c)
			var cid := "%s_%d_%d" % [map.id, c.x, c.y]
			map.chests.append({"x": c.x, "y": c.y, "item": chest_item, "id": cid})
			_say("chest placed (%s)" % Data.item_name(chest_item))
		"warp":
			_erase_object(c)
			var dest: Maps.GameMap = World.build_all()[warp_to]
			map.warps.append({"x": c.x, "y": c.y, "to": warp_to,
				"tx": dest.start.x, "ty": dest.start.y})
			_say("warp -> %s (lands at its start tile)" % warp_to)
		"boss":
			map.boss = {"x": c.x, "y": c.y, "id": "gravebell", "flag": "gravebell",
				"intro": Story.BOSS_GRAVEBELL}
			_say("boss placed")


func _process(dt: float) -> void:
	t += dt
	status_t += dt
	var pan := maxi(1, int(8 / zoom * 2))
	if repeated("move_left", dt): cam.x -= pan
	if repeated("move_right", dt): cam.x += pan
	if repeated("move_up", dt): cam.y -= pan
	if repeated("move_down", dt): cam.y += pan
	cam.x = clampi(cam.x, 0, maxi(0, map.w - _tiles_across()))
	cam.y = clampi(cam.y, 0, maxi(0, map.h - _tiles_down()))

	var m := get_local_mouse_position()
	var left := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var right := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)

	# palette click
	if left and not _was_left and m.x >= PAL_X:
		for i in TILE_ORDER.size():
			var px := PAL_X + (i % 4) * PAL_CELL
			var py := PAL_Y + int(i / 4) * PAL_CELL
			if m.x >= px and m.x < px + PAL_CELL and m.y >= py and m.y < py + PAL_CELL:
				brush = TILE_ORDER[i]
				_say("brush: " + TILE_NAMES.get(brush, brush))
				break

	# EXIT button in the top bar
	if left and not _was_left and mouse_in(EXIT_X, 1, 34, 9):
		closed.emit()
		_was_left = true
		return

	var c := cursor_tile()
	if c.x >= 0 and c.x < map.w and c.y >= 0 and c.y < map.h:
		if mode == "tiles":
			if left:
				if not _was_left:
					push_undo()
				if map.get_tile(c.x, c.y) != brush:
					map.set_tile(c.x, c.y, brush)
			elif right and not _was_right:
				brush = map.get_tile(c.x, c.y)
				_say("picked: " + TILE_NAMES.get(brush, brush))
		else:
			if left and not _was_left:
				_place(c)
	_was_left = left
	_was_right = right
	queue_redraw()


# -------------------------------------------------------------------- draw --

func _draw() -> void:
	draw_rect(Rect2(0, 0, UI.SCREEN_W, UI.SCREEN_H), Color("#14101c"), true)
	_draw_map()
	_draw_palette()
	_draw_bars()


func _draw_map() -> void:
	var across := _tiles_across()
	var down := _tiles_down()
	for ty in down + 1:
		for tx in across + 1:
			var mx := cam.x + tx
			var my := cam.y + ty
			if mx >= map.w or my >= map.h:
				continue
			var ch := map.get_tile(mx, my)
			var tex: ImageTexture = _tex.get(ch, null)
			var r := Rect2(VIEW_X + tx * zoom, VIEW_Y + ty * zoom, zoom, zoom)
			if tex != null:
				draw_texture_rect(tex, r, false)
			else:
				draw_rect(r, Color("#3e7a42"), true)
	if show_grid and zoom >= 8:
		for tx in range(across + 1):
			UI.rect(self, VIEW_X + tx * zoom, VIEW_Y, 1, VIEW_H, Color(1, 1, 1, 0.06))
		for ty in range(down + 1):
			UI.rect(self, VIEW_X, VIEW_Y + ty * zoom, VIEW_W, 1, Color(1, 1, 1, 0.06))

	# objects
	for wp in map.warps:
		_marker(wp.x, wp.y, "W", Color("#50b0e8"))
	for ch in map.chests:
		_marker(ch.x, ch.y, "C", Color("#f0d040"))
	for n in map.npcs:
		_marker(n.x, n.y, "S" if n.get("sign", false) else "N", Color("#78d048"))
	if map.boss != null:
		_marker(map.boss.x, map.boss.y, "B", Color("#e878b0"))
	_marker(map.start.x, map.start.y, "@", Color("#ffe08a"))

	# cursor
	var c := cursor_tile()
	if c.x >= 0 and c.x < map.w and c.y >= 0 and c.y < map.h:
		var sx := VIEW_X + (c.x - cam.x) * zoom
		var sy := VIEW_Y + (c.y - cam.y) * zoom
		UI.rect(self, sx, sy, zoom, 1, UI.COL_GOLD)
		UI.rect(self, sx, sy + zoom - 1, zoom, 1, UI.COL_GOLD)
		UI.rect(self, sx, sy, 1, zoom, UI.COL_GOLD)
		UI.rect(self, sx + zoom - 1, sy, 1, zoom, UI.COL_GOLD)


func _marker(mx: int, my: int, letter: String, col: Color) -> void:
	var tx := mx - cam.x
	var ty := my - cam.y
	if tx < 0 or ty < 0 or tx * zoom >= VIEW_W or ty * zoom >= VIEW_H:
		return
	var sx := VIEW_X + tx * zoom
	var sy := VIEW_Y + ty * zoom
	UI.rect(self, sx, sy, zoom, zoom, Color(col.r, col.g, col.b, 0.45))
	if zoom >= 8:
		PixelFont.draw(self, letter, Vector2(sx + 1, sy + 1), col, {"outline": UI.COL_INK})


func _draw_palette() -> void:
	UI.rect(self, PAL_X - 3, 0, UI.SCREEN_W - PAL_X + 3, UI.SCREEN_H, Color("#1c1628"))
	PixelFont.draw(self, "tiles", Vector2(PAL_X, 13), UI.COL_DIM)
	for i in TILE_ORDER.size():
		var ch: String = TILE_ORDER[i]
		var px := PAL_X + (i % 4) * PAL_CELL
		var py := PAL_Y + int(i / 4) * PAL_CELL
		var tex: ImageTexture = _tex.get(ch, null)
		if tex != null:
			draw_texture_rect(tex, Rect2(px, py, 16, 16), false)
		else:
			UI.rect(self, px, py, 16, 16, Color("#3a3048"))
		if ch == brush:
			UI.rect(self, px - 1, py - 1, 18, 1, UI.COL_GOLD)
			UI.rect(self, px - 1, py + 16, 18, 1, UI.COL_GOLD)
			UI.rect(self, px - 1, py - 1, 1, 18, UI.COL_GOLD)
			UI.rect(self, px + 16, py - 1, 1, 18, UI.COL_GOLD)
	var by := PAL_Y + int((TILE_ORDER.size() + 3) / 4) * PAL_CELL + 4
	PixelFont.draw(self, TILE_NAMES.get(brush, brush).substr(0, 10), Vector2(PAL_X, by), UI.COL_GOLD)
	PixelFont.draw(self, "solid" if Maps.is_solid(brush) else "walk",
		Vector2(PAL_X, by + 11), UI.COL_RED if Maps.is_solid(brush) else UI.COL_GREEN)


func _draw_bars() -> void:
	UI.rect(self, 0, 0, UI.SCREEN_W, 11, Color("#241c34"))
	PixelFont.draw(self, "%s  %dx%d" % [map.id, map.w, map.h], Vector2(3, 2), UI.COL_TEXT)
	var c := cursor_tile()
	if c.x >= 0:
		PixelFont.draw(self, "%d,%d" % [c.x, c.y], Vector2(120, 2), UI.COL_DIM)
	PixelFont.draw_right(self, mode + (":" + obj_kind if mode == "objects" else ""),
		EXIT_X - 6, 2, UI.COL_GOLD)
	var hot := mouse_in(EXIT_X, 1, 34, 9)
	UI.rect(self, EXIT_X, 1, 34, 9, Color("#5a3a48") if hot else Color("#3a2a38"))
	PixelFont.draw(self, "EXIT", Vector2(EXIT_X + 6, 2), Color("#fff4c0") if hot else UI.COL_GOLD)

	UI.rect(self, 0, UI.SCREEN_H - 11, UI.SCREEN_W, 11, Color("#241c34"))
	# 320px at 6px a glyph is 53 characters before it runs off the edge
	var hint := "[ ]map -+zoom TAB F fill U undo S save C copy X revert Q quit"
	if mode == "objects":
		hint = "1start 2npc 3chest 4warp 5boss ,.cycle DEL S save ESC"
	PixelFont.draw(self, hint, Vector2(3, UI.SCREEN_H - 9), UI.COL_DIM)

	if status_t < 4.0:
		var w := PixelFont.width(status) + 8
		UI.window(self, 3, 13, mini(w, 244), 13, {"alpha": 0.9})
		PixelFont.draw(self, status, Vector2(7, 15), UI.COL_GREEN)
