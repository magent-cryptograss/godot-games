extends Node2D
## The level-up choice: General, or one of the eight elements.
##
## On a song level (1, then every level ending in 5 or 0) an element teaches
## its next song. On any other level it gives ATK, DEF and affinity instead.

signal finished

var queue: Array[int] = []
var lv := 1
var sel := 0
var phase := "choose"        # choose | result
var lines: Array[String] = []
var t := 0.0
var phase_t := 0.0
var repeat_t := {}
var _was_click := false


func begin(levels: Array) -> void:
	queue.clear()
	for l in levels:
		queue.append(int(l))
	_next()


func _next() -> void:
	if queue.is_empty():
		finished.emit()
		return
	lv = queue.pop_front()
	sel = 0
	phase = "choose"
	phase_t = 0.0
	lines.clear()


func cards() -> Array:
	var out := [{"id": "general", "name": "General", "col": Color("#e8e0f0"), "elem": null}]
	for e in Data.ELEMENTS:
		out.append({"id": e.id, "name": e.name, "col": Color(e.col), "elem": e})
	return out


func repeated(action: String, dt: float) -> bool:
	if Input.is_action_just_pressed(action):
		repeat_t[action] = 0.0
		return true
	if Input.is_action_pressed(action):
		repeat_t[action] = repeat_t.get(action, 0.0) + dt
		if repeat_t[action] > 0.28:
			repeat_t[action] -= 0.11
			return true
	else:
		repeat_t[action] = 0.0
	return false


func _click() -> bool:
	var down := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var fired := down and not _was_click
	_was_click = down
	return fired


func hit(x: float, y: float, w: float, h: float) -> bool:
	var m := get_local_mouse_position()
	return m.x >= x and m.y >= y and m.x < x + w and m.y < y + h


func _process(dt: float) -> void:
	t += dt
	phase_t += dt
	var cs := cards()
	if phase == "choose":
		if repeated("move_left", dt): sel = wrapi(sel - 1, 0, cs.size())
		if repeated("move_right", dt): sel = wrapi(sel + 1, 0, cs.size())
		if repeated("move_up", dt): sel = wrapi(sel - 3, 0, cs.size())
		if repeated("move_down", dt): sel = wrapi(sel + 3, 0, cs.size())
		for i in cs.size():
			var x := 8 + (i % 3) * 102
			var y := 46 + int(i / 3) * 42
			if hit(x, y, 96, 38):
				sel = i
				if _click():
					_choose()
					break
		if Input.is_action_just_pressed("ui_ok"):
			_choose()
	else:
		if phase_t > 0.3 and (Input.is_action_just_pressed("ui_ok") or _click()):
			_next()
	queue_redraw()


func _choose() -> void:
	var c: Dictionary = cards()[sel]
	lines = Game.player.apply_level_choice(c.id, lv)
	phase = "result"
	phase_t = 0.0


## What this pick actually gives, shown before committing to it.
func preview(c: Dictionary) -> Array[String]:
	if c.id == "general":
		return ["ATK +3   DEF +3   MUSIC +3", "Steady growth, no new song."]
	if not Data.is_song_level(lv):
		return ["ATK +2   DEF +2",
			"%s affinity +1 (songs of this element hit harder)." % c.name]
	var idx: int = Game.player.next_song_index(c.id)
	if idx < 0:
		return ["ATK +1   DEF +1", "Ladder complete: every %s song grows stronger." % c.name]
	var s: Dictionary = Data.SONGS[c.id][idx]
	return ["Learn: %s   (%d breath)" % [s.name, s.cost], Data.describe_song(s)]


func _draw() -> void:
	UI.menu_bg(self, t)
	var song_lv := Data.is_song_level(lv)
	UI.window(self, 8, 6, 304, 34)
	PixelFont.draw_centered(self, "Level %d" % lv, 160, 12, UI.COL_GOLD, {"outline": UI.COL_INK})
	PixelFont.draw_centered(self,
		"A song level. Choose an element to learn its next song." if song_lv else "Choose your growth.",
		160, 26, UI.COL_GREEN if song_lv else UI.COL_DIM)

	var cs := cards()
	for i in cs.size():
		var c: Dictionary = cs[i]
		var x := 8 + (i % 3) * 102
		var y := 46 + int(i / 3) * 42
		var is_sel := i == sel
		var o := {}
		if is_sel:
			o = {"top": Color(c.elem.col2) if c.elem != null else Color("#4a3a80"), "bot": Color("#181030")}
		else:
			o = {"alpha": 0.72}
		UI.window(self, x, y, 96, 38, o)
		if is_sel:
			UI.rect(self, x, y, 96, 1, UI.COL_GOLD)
			UI.rect(self, x, y + 37, 96, 1, UI.COL_GOLD)
		if c.elem != null:
			UI.elem_icon(self, c.elem, x + 18, y + 19, t, is_sel)
			PixelFont.draw(self, c.name, Vector2(x + 34, y + 8),
				c.col if is_sel else Color("#c0b8d8"), {"outline": UI.COL_INK} if is_sel else {})
			var known: int = Game.player.songs_of(c.id)
			PixelFont.draw(self, "%d/%d songs" % [known, Data.SONGS[c.id].size()],
				Vector2(x + 34, y + 20), Color("#9890b8"))
			var up: int = Game.player.upgrades.get(c.id, 0)
			if up > 0:
				PixelFont.draw(self, "+%d" % up, Vector2(x + 84, y + 20), UI.COL_GREEN)
			# a green pip marks an element that has a song waiting for you
			if song_lv and Game.player.next_song_index(c.id) >= 0:
				UI.rect(self, x + 88, y + 6, 4, 4, UI.COL_GREEN)
		else:
			PixelFont.draw(self, "General", Vector2(x + 10, y + 8),
				UI.COL_GOLD if is_sel else Color("#c0b8d8"), {"outline": UI.COL_INK} if is_sel else {})
			PixelFont.draw(self, "ATK  DEF  MUSIC", Vector2(x + 10, y + 22), Color("#9890b8"))

	if phase == "choose":
		var info := preview(cs[sel])
		UI.window(self, 8, 178, 304, 42)
		PixelFont.draw(self, info[0], Vector2(16, 184), UI.COL_TEXT)
		var wrapped := PixelFont.wrap_text(info[1], 288)
		for i in wrapped.size():
			PixelFont.draw(self, wrapped[i], Vector2(16, 198 + i * 11), UI.COL_DIM)
		PixelFont.draw_centered(self, "Z to choose", 160, 228, UI.COL_FAINT)
	else:
		UI.window(self, 48, 150, 224, 76)
		PixelFont.draw_centered(self, "Level %d" % lv, 160, 156, UI.COL_GOLD, {"outline": UI.COL_INK})
		for i in lines.size():
			var col := UI.COL_GREEN if lines[i].begins_with("LEARNED") else Color("#e8e0f0")
			PixelFont.draw_centered(self, lines[i], 160, 172 + i * 12, col)
		if phase_t > 0.3:
			PixelFont.draw_centered(self, "Z", 160, 214, UI.COL_FAINT)
