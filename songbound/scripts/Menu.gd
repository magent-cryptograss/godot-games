extends Node2D
## The pause menu, drawn over a frozen field: status, song book, items, save.

signal closed

const ROOT := ["Status", "Songs", "Items", "Save", "Close"]

var page := "root"
var sel := 0
var sub := 0
var scroll := 0
var note := ""
var t := 0.0
var repeat_t := {}


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


func _process(dt: float) -> void:
	t += dt
	var p := Game.player
	if page == "root":
		if repeated("move_up", dt):
			sel = wrapi(sel - 1, 0, ROOT.size())
			Audio.sfx("cursor")
		if repeated("move_down", dt):
			sel = wrapi(sel + 1, 0, ROOT.size())
			Audio.sfx("cursor")
		if Input.is_action_just_pressed("ui_ok"):
			_pick()
		elif Input.is_action_just_pressed("ui_back") or Input.is_action_just_pressed("ui_menu"):
			_close()
	else:
		match page:
			"songs":
				var n := maxi(1, p.songs.size())
				if repeated("move_up", dt): sub = wrapi(sub - 1, 0, n)
				if repeated("move_down", dt): sub = wrapi(sub + 1, 0, n)
				scroll = clampi(scroll, maxi(0, sub - 9), sub)
			"items":
				var ids := p.items.keys()
				var n := maxi(1, ids.size())
				if repeated("move_up", dt): sub = wrapi(sub - 1, 0, n)
				if repeated("move_down", dt): sub = wrapi(sub + 1, 0, n)
				if Input.is_action_just_pressed("ui_ok") and not ids.is_empty():
					_use(ids[clampi(sub, 0, ids.size() - 1)])
		if Input.is_action_just_pressed("ui_back") or Input.is_action_just_pressed("ui_menu"):
			page = "root"
			sub = 0
			scroll = 0
			note = ""
			Audio.sfx("cancel")
	queue_redraw()


func _pick() -> void:
	Audio.sfx("confirm")
	match ROOT[sel]:
		"Close": _close()
		"Save":
			note = "Saved." if Game.save_game() else "Save failed."
		_:
			page = ROOT[sel].to_lower()
			sub = 0
			scroll = 0
			note = ""


func _use(id: String) -> void:
	var p := Game.player
	var it: Dictionary = Data.ITEMS[id]
	# only the out-of-combat useful ones; the rest are saved for a fight
	if it.kind == "heal" or it.kind == "healall":
		p.hp = mini(p.max_hp(), p.hp + it.pow)
	elif it.kind == "breath":
		p.br = mini(p.max_br(), p.br + it.pow)
	else:
		Audio.sfx("error")
		note = "Save that for a fight."
		return
	p.items[id] -= 1
	if p.items[id] <= 0:
		p.items.erase(id)
	sub = 0
	note = "Used."
	Audio.sfx("heal")


func _close() -> void:
	Audio.sfx("cancel")
	closed.emit()


func _draw() -> void:
	UI.rect(self, 0, 0, UI.SCREEN_W, UI.SCREEN_H, Color(0.04, 0.03, 0.08, 0.55))
	var p := Game.player

	UI.window(self, 4, 30, 88, 96)
	for i in ROOT.size():
		var is_sel := i == sel and page == "root"
		if is_sel:
			UI.cursor(self, 10, 41 + i * 18, t)
		PixelFont.draw(self, ROOT[i], Vector2(22, 42 + i * 18),
			UI.COL_GOLD if is_sel else Color("#c0b8d8"))

	UI.window(self, 4, 130, 88, 44)
	PixelFont.draw(self, "Coin", Vector2(10, 136), Color("#9890b8"))
	PixelFont.draw_right(self, str(p.gold), 86, 136, UI.COL_GOLD)
	PixelFont.draw(self, "Next", Vector2(10, 150), Color("#9890b8"))
	PixelFont.draw_right(self, "-" if p.lv >= Data.MAX_LEVEL else str(maxi(0, Data.xp_to_next(p.lv) - p.xp)),
		86, 150, Color("#c0b8d8"))
	PixelFont.draw(self, "Steps", Vector2(10, 162), Color("#9890b8"))
	PixelFont.draw_right(self, str(Game.steps), 86, 162, Color("#c0b8d8"))

	var px0 := 98.0
	match page:
		"root", "status": _draw_status(px0, p)
		"songs": _draw_songs(px0, p)
		"items": _draw_items(px0, p)
	if note != "":
		PixelFont.draw_centered(self, note, 160, 232, UI.COL_GREEN)


func _draw_status(px0: float, p: Player) -> void:
	UI.window(self, px0, 30, 218, 196)
	UI.sprite(self, p.spr, px0 + 14, 42, 2, false, true, int(t * 5.0))
	PixelFont.draw(self, p.name, Vector2(px0 + 66, 42), UI.COL_TEXT, {"outline": UI.COL_INK})
	PixelFont.draw(self, "Level %d" % p.lv, Vector2(px0 + 66, 56), UI.COL_GOLD)
	PixelFont.draw(self, Data.instrument(p.inst).name, Vector2(px0 + 66, 68), Color("#c0b8d8"))

	PixelFont.draw(self, "HP", Vector2(px0 + 14, 100), Color("#9890b8"))
	UI.bar(self, px0 + 36, 101, 70, 5, float(p.hp) / float(p.max_hp()))
	PixelFont.draw_right(self, "%d/%d" % [p.hp, p.max_hp()], px0 + 200, 98, Color("#d8d0e8"))
	PixelFont.draw(self, "BR", Vector2(px0 + 14, 114), Color("#9890b8"))
	UI.bar(self, px0 + 36, 115, 70, 5, float(p.br) / float(p.max_br()), Color("#78b8f0"), Color("#2a5a9c"))
	PixelFont.draw_right(self, "%d/%d" % [p.br, p.max_br()], px0 + 200, 112, Color("#d8d0e8"))

	var stats := [["ATK", p.stat_atk()], ["DEF", p.stat_def()], ["MUSIC", p.stat_mus()], ["SPD", p.stat_spd()]]
	for i in stats.size():
		var x := px0 + 14 + (i % 2) * 100
		var y := 132 + int(i / 2) * 14
		PixelFont.draw(self, str(stats[i][0]), Vector2(x, y), Color("#9890b8"))
		PixelFont.draw_right(self, str(stats[i][1]), x + 76, y, UI.COL_TEXT)

	PixelFont.draw(self, "Affinity", Vector2(px0 + 14, 168), Color("#9890b8"))
	for i in Data.ELEMENTS.size():
		var e: Dictionary = Data.ELEMENTS[i]
		var x := px0 + 14 + (i % 4) * 50
		var y := 182 + int(i / 4) * 20
		var aff: int = p.affinity.get(e.id, 0)
		UI.elem_icon(self, e, x + 6, y + 6, t, aff > 0)
		PixelFont.draw(self, str(aff), Vector2(x + 18, y + 3),
			Color(e.col) if aff > 0 else Color("#5a5470"))


func _draw_songs(px0: float, p: Player) -> void:
	UI.window(self, px0, 30, 218, 196)
	PixelFont.draw(self, "Songs", Vector2(px0 + 10, 36), Color("#9890b8"))
	PixelFont.draw_right(self, "%d known" % p.songs.size(), px0 + 208, 36, Color("#c0b8d8"))
	var songs := p.song_book()
	if songs.is_empty():
		PixelFont.draw(self, "None yet.", Vector2(px0 + 14, 56), Color("#6a6480"))
		return
	for i in 10:
		var idx := scroll + i
		if idx >= songs.size():
			break
		var s: Dictionary = songs[idx]
		var el: Dictionary = Data.element(s.elem)
		var y := 52 + i * 14
		var is_sel := idx == sub
		if is_sel:
			UI.cursor(self, px0 + 6, y - 1, t)
		UI.rect(self, px0 + 18, y + 1, 5, 5, Color(el.col))
		var label: String = s.name + (" +%d" % s.upgraded if s.upgraded > 0 else "")
		PixelFont.draw(self, label, Vector2(px0 + 27, y), UI.COL_GOLD if is_sel else Color("#d8d0e8"))
		PixelFont.draw_right(self, str(s.cost), px0 + 208, y, UI.COL_BLUE)
	if sub < songs.size():
		var sd: Dictionary = songs[sub]
		PixelFont.draw(self, Data.describe_song(sd), Vector2(px0 + 10, 200), UI.COL_DIM)
		PixelFont.draw(self, Data.element(sd.elem).name, Vector2(px0 + 10, 212), Color(Data.element(sd.elem).col))


func _draw_items(px0: float, p: Player) -> void:
	UI.window(self, px0, 30, 218, 196)
	PixelFont.draw(self, "Items", Vector2(px0 + 10, 36), Color("#9890b8"))
	var ids := p.items.keys()
	if ids.is_empty():
		PixelFont.draw(self, "Empty.", Vector2(px0 + 14, 56), Color("#6a6480"))
		return
	for i in ids.size():
		var y := 52 + i * 14
		var is_sel := i == sub
		if is_sel:
			UI.cursor(self, px0 + 6, y - 1, t)
		PixelFont.draw(self, Data.item_name(ids[i]), Vector2(px0 + 20, y),
			UI.COL_GOLD if is_sel else Color("#d8d0e8"))
		PixelFont.draw_right(self, "x%d" % p.items[ids[i]], px0 + 208, y, Color("#c0b8d8"))
	if sub < ids.size():
		PixelFont.draw(self, Data.ITEMS[ids[sub]].desc, Vector2(px0 + 10, 205), UI.COL_DIM)
