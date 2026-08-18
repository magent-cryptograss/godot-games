extends Node2D
## Scene routing. Title and the ending crawl are drawn here; everything else is
## a child scene swapped in and out.

enum S { TITLE, CREATION, FIELD, BATTLE, LEVELUP, SHOP, ENDING, MAPEDIT }

var state: int = S.TITLE
var current: Node = null

var t := 0.0
var title_sel := 0
var end_t := 0.0
var end_lines: PackedStringArray = PackedStringArray()
var shop_list: Array = []
var shop_sel := 0
var shop_note := ""
var shop_pane: Node2D = null
var repeat_t := {}
var _was_click := false
var fade := 0.0
var fade_dir := 0
var fade_cb: Callable = Callable()

const CREATION := preload("res://scenes/Creation.tscn")
const FIELD := preload("res://scenes/Field.tscn")
const BATTLE := preload("res://scenes/Battle.tscn")
const LEVELUP := preload("res://scenes/LevelUp.tscn")
const MENU := preload("res://scenes/Menu.tscn")
const MAPEDIT := preload("res://scenes/MapEditor.tscn")
# preloaded rather than referred to by class_name: a brand-new script is not in
# the class cache until something rescans the project, and a headless run never
# does -- which shows up as Main failing to parse rather than as a missing file
const OVERLAY := preload("res://scripts/Overlay.gd")

var menu: Node2D = null


func _ready() -> void:
	Audio.play_music("title")
	set_process(true)


func _swap(scene: PackedScene) -> Node:
	if current != null:
		current.queue_free()
		current = null
	var n: Node = scene.instantiate()
	add_child(n)
	current = n
	return n


func _clear() -> void:
	if current != null:
		current.queue_free()
		current = null


func fade_to(cb: Callable, speed: float = 3.0) -> void:
	fade_dir = 1
	fade_cb = cb
	set_meta("fade_speed", speed)


# ------------------------------------------------------------- transitions --

func start_creation() -> void:
	state = S.CREATION
	var c := _swap(CREATION)
	c.finished.connect(_on_created)
	Audio.play_music("creation")


func _on_created(_p: Player) -> void:
	fade_to(func() -> void:
		_enter_field(Game.map_id, Vector2i(-1, -1))
		current.say(Story.OPENING)
	)


func _enter_field(map_id: String, at: Vector2i) -> void:
	state = S.FIELD
	var f := _swap(FIELD)
	f.encounter.connect(_on_encounter)
	f.boss_encounter.connect(_on_boss)
	f.open_shop.connect(_on_shop)
	f.open_inn.connect(_on_inn)
	f.open_menu.connect(_on_menu)
	f.enter(map_id, at, Game.facing)
	Audio.play_music(f.map.music)


func _on_encounter(region: String) -> void:
	_start_battle(region, "", "")


func _on_boss(id: String, flag: String) -> void:
	var m: Maps.GameMap = World.build_all()[Game.map_id]
	_start_battle(m.region if m.region != "" else "deep", id, flag)


func _start_battle(region: String, boss: String, flag: String) -> void:
	state = S.BATTLE
	var b := _swap(BATTLE)
	b.finished.connect(_on_battle_done)
	b.begin(region, boss, flag)


func _on_battle_done(result: String) -> void:
	if result == "lose":
		# not a game over: you wake in town, lighter of pocket
		Game.player.hp = Game.player.max_hp()
		Game.player.br = Game.player.max_br()
		Game.player.gold = int(Game.player.gold / 2)
		fade_to(func() -> void:
			Game.map_id = "town"
			_enter_field("town", World.build_all()["town"].start)
			current.say(Story.REVIVE_LINES)
		)
		return
	if not Game.level_queue.is_empty():
		state = S.LEVELUP
		var lu := _swap(LEVELUP)
		lu.finished.connect(_on_levels_done)
		lu.begin(Game.level_queue.duplicate())
		Game.level_queue.clear()
		Audio.sfx("levelup")
		return
	_after_battle()


func _on_levels_done() -> void:
	_after_battle()


func _after_battle() -> void:
	if Game.pending_ending:
		Game.pending_ending = false
		fade_to(func() -> void: _start_ending(), 1.5)
		return
	fade_to(func() -> void: _enter_field(Game.map_id, Game.tile_pos))


## The menu sits on top of a frozen field rather than replacing it, so closing
## it puts you back exactly where you stood.
func _on_menu() -> void:
	if menu != null:
		return
	menu = MENU.instantiate()
	add_child(menu)
	menu.closed.connect(_close_menu)
	if current != null:
		current.set_process(false)


func _close_menu() -> void:
	if menu != null:
		menu.queue_free()
		menu = null
	if current != null:
		current.set_process(true)


func _close_editor() -> void:
	_clear()
	state = S.TITLE
	title_sel = 0
	# maps may have changed underneath the generated world
	World.maps.clear()
	Audio.play_music("title")


func _on_shop(list: Array) -> void:
	shop_list = list
	shop_sel = 0
	shop_note = ""
	state = S.SHOP
	# on top of the shop floor, not underneath it -- and the floor stops running
	# while you are at the counter, or you go on walking and meeting monsters
	# behind a screen you are reading
	if current != null:
		current.set_process(false)
	if shop_pane == null:
		shop_pane = OVERLAY.new()
		shop_pane.painter = _draw_shop
		add_child(shop_pane)


func _close_shop() -> void:
	if shop_pane != null:
		shop_pane.queue_free()
		shop_pane = null
	if current != null:
		current.set_process(true)
	state = S.FIELD


func _on_inn(price: int) -> void:
	var p := Game.player
	if p.gold < price:
		current.say(["You are short. Come back with coin."])
		return
	p.gold -= price
	fade_to(func() -> void:
		p.hp = p.max_hp()
		p.br = p.max_br()
		Audio.sfx("heal")
		current.say(["You sleep without dreaming, which is a mercy lately.", "Fully restored."])
	, 2.0)


func _start_ending() -> void:
	_clear()
	state = S.ENDING
	end_t = 0.0
	end_lines = PackedStringArray()
	for l in Story.ENDING:
		if l == "" or l == Story.TITLE:
			end_lines.append(l)
		else:
			for w in PixelFont.wrap_text(l, UI.SCREEN_W - 24):
				end_lines.append(w)
	Audio.play_music("ending")
	Game.save_game()


# ------------------------------------------------------------------ update --

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


func _process(dt: float) -> void:
	t += dt
	if fade_dir == 1:
		fade = minf(1.0, fade + dt * float(get_meta("fade_speed", 3.0)))
		if fade >= 1.0:
			fade_dir = -1
			var cb := fade_cb
			fade_cb = Callable()
			if cb.is_valid():
				cb.call()
	elif fade_dir == -1:
		fade = maxf(0.0, fade - dt * float(get_meta("fade_speed", 3.0)))
		if fade <= 0.0:
			fade_dir = 0

	if fade_dir != 0:
		queue_redraw()
		return

	match state:
		S.TITLE: _up_title(dt)
		S.SHOP: _up_shop(dt)
		S.ENDING: _up_ending(dt)
	queue_redraw()


func title_options() -> Array:
	var o := ["Continue", "New Game"] if Game.has_save() else ["New Game"]
	o.append("Map Editor")
	if Game.has_save():
		o.append("Erase Save")
	return o


func _up_title(dt: float) -> void:
	var opts := title_options().size()
	if repeated("move_up", dt): title_sel = wrapi(title_sel - 1, 0, opts)
	if repeated("move_down", dt): title_sel = wrapi(title_sel + 1, 0, opts)
	for i in opts:
		if get_local_mouse_position().y >= 138 + i * 22 and get_local_mouse_position().y < 154 + i * 22 \
				and get_local_mouse_position().x > 100 and get_local_mouse_position().x < 220:
			title_sel = i
			if _click():
				_title_pick()
				return
	if Input.is_action_just_pressed("ui_ok"):
		_title_pick()


func _title_pick() -> void:
	Audio.sfx("confirm")
	var opts := title_options()
	match opts[title_sel]:
		"Map Editor":
			state = S.MAPEDIT
			var ed := _swap(MAPEDIT)
			ed.closed.connect(_close_editor)
			return
		"Continue":
			if Game.load_game():
				fade_to(func() -> void: _enter_field(Game.map_id, Game.tile_pos))
			else:
				Audio.sfx("error")
		"New Game":
			start_creation()
		"Erase Save":
			Game.erase_save()
			title_sel = 0


## Buy whatever the cursor is on, if there is the coin for it.
func _buy() -> void:
	if shop_sel < 0 or shop_sel >= shop_list.size():
		return
	var id: String = shop_list[shop_sel]
	var it: Dictionary = Data.ITEMS[id]
	if Game.player.gold < it.price:
		Audio.sfx("error")
		shop_note = "Not enough coin."
		return
	Game.player.gold -= int(it.price)
	Game.player.items[id] = Game.player.items.get(id, 0) + 1
	Audio.sfx("confirm")
	shop_note = "Bought " + it.name + "."


func _up_shop(dt: float) -> void:
	var n := shop_list.size()
	if repeated("move_up", dt): shop_sel = wrapi(shop_sel - 1, 0, n)
	if repeated("move_down", dt): shop_sel = wrapi(shop_sel + 1, 0, n)
	if Input.is_action_just_pressed("ui_ok"):
		_buy()
	elif Input.is_action_just_pressed("ui_back"):
		Audio.sfx("cancel")
		_close_shop()


func _up_ending(dt: float) -> void:
	end_t += dt
	if end_t > 2.0 and (Input.is_action_just_pressed("ui_ok") or _click()):
		state = S.TITLE
		title_sel = 0
		_clear()
		Audio.play_music("title")


# -------------------------------------------------------------------- draw --

func _draw() -> void:
	match state:
		S.TITLE: _draw_title()
		S.ENDING: _draw_ending()
	if fade > 0.0:
		UI.rect(self, 0, 0, UI.SCREEN_W, UI.SCREEN_H, Color(0, 0, 0, fade))


func _draw_title() -> void:
	UI.vgrad(self, 0, 0, UI.SCREEN_W, UI.SCREEN_H, Color("#150e26"), Color("#07050c"), 16)
	for i in 26:
		var tt := t + i
		var x := fmod(absf(Maps.hash2(i, 4)) * UI.SCREEN_W + tt * (6 + Maps.hash2(i, 5) * 10),
			UI.SCREEN_W + 20) - 10
		var y := 30 + Maps.hash2(i, 6) * 170 + sin(tt + i) * 6
		var c: Color = [Color("#6038a0"), Color("#2068a8"), Color("#a03878"), Color("#3a8828")][i % 4]
		UI.rect(self, x, y, 3, 3, c)
		UI.rect(self, x + 2, y - 5, 1, 6, c)
	for i in 5:
		UI.rect(self, 0, 96 + i * 7 + sin(t * 0.9) * 2, UI.SCREEN_W, 1, Color(0.78, 0.75, 0.94, 0.09))

	_draw_big_title(Story.TITLE, 160, 52 + sin(t * 0.9) * 2)
	PixelFont.draw_centered(self, Story.SUBTITLE, 160, 92, Color("#8878b0"))

	var opts := title_options()
	for i in opts.size():
		var y := 140 + i * 22
		var sel := i == title_sel
		if sel:
			UI.cursor(self, 112, y - 1, t)
		PixelFont.draw_centered(self, opts[i], 168, y,
			UI.COL_GOLD if sel else UI.COL_DIM, {"outline": UI.COL_INK} if sel else {})
	PixelFont.draw_centered(self, "arrows / Z    (mouse works too)", 160, 214, Color("#5a5470"))
	# There is an older single-file HTML build of this game on the same server
	# with a near-identical title screen and no map editor. Say which this is.
	PixelFont.draw_centered(self, "godot build  -  /games/songbound-godot/", 160, 228, Color("#3a3450"))


func _draw_big_title(word: String, cx: float, cy: float) -> void:
	# the same glyphs at 3x, with a coloured vertical ramp
	var w := PixelFont.width(word) * 3
	var x0 := cx - w / 2.0
	for i in word.length():
		var ch := word[i]
		PixelFont.draw(self, ch, Vector2(x0 + i * 18 + 2, cy + 3), Color("#2a1048"),
			{"scale": 3, "shadow": false})
	for i in word.length():
		var ch := word[i]
		PixelFont.draw(self, ch, Vector2(x0 + i * 18, cy), Color("#e0d0f8"),
			{"scale": 3, "shadow": false})


## Painted by the overlay pane, into the pane -- not into Main.
func _draw_shop(ci: CanvasItem) -> void:
	# The shop floor stays visible behind a scrim rather than being blacked out.
	# You are standing at a counter talking to somebody; blanking the room turns
	# that into an abstract menu that arrived from nowhere.
	UI.rect(ci, 0, 0, UI.SCREEN_W, UI.SCREEN_H, Color(0.04, 0.03, 0.08, 0.72))

	# Laid out from the screen size rather than from the numbers this was born
	# with. It was written for a 320x240 window and never moved when the window
	# became 800x600, so it sat in the top-left corner like a postage stamp.
	var w := 560.0
	var h := 400.0
	var x := (UI.SCREEN_W - w) / 2.0
	var y := (UI.SCREEN_H - h) / 2.0
	var pad := 20.0
	var big := {"scale": 2}
	UI.window(ci, x, y, w, h)
	PixelFont.draw(ci, "Supplies", Vector2(x + pad, y + pad),
		UI.COL_TEXT, {"outline": UI.COL_INK, "scale": 2})
	PixelFont.draw_right(ci, "Coin %d" % Game.player.gold, x + w - pad, y + pad,
		UI.COL_GOLD, big)

	var row_y := y + 64.0
	for i in shop_list.size():
		var id: String = shop_list[i]
		var it: Dictionary = Data.ITEMS[id]
		var ry := row_y + i * 30.0
		var sel := i == shop_sel
		if sel:
			UI.cursor(ci, x + pad, ry + 4, t)
		var afford: bool = Game.player.gold >= it.price
		PixelFont.draw(ci, it.name, Vector2(x + pad + 32, ry),
			UI.COL_GOLD if sel else (Color("#d8d0e8") if afford else Color("#6a6480")), big)
		PixelFont.draw_right(ci, str(it.price), x + w - 110, ry,
			Color("#c0b8d8") if afford else Color("#6a6480"), big)
		var have: int = Game.player.items.get(id, 0)
		if have > 0:
			PixelFont.draw_right(ci, "x%d" % have, x + w - pad, ry, UI.COL_FAINT, big)

	if shop_sel < shop_list.size():
		PixelFont.draw(ci, Data.ITEMS[shop_list[shop_sel]].desc,
			Vector2(x + pad, y + h - 62), UI.COL_DIM, big)
	PixelFont.draw(ci, shop_note if shop_note != "" else "Z to buy,  X to leave",
		Vector2(x + pad, y + h - 34),
		UI.COL_GREEN if shop_note != "" else UI.COL_FAINT, big)


func _draw_ending() -> void:
	UI.vgrad(self, 0, 0, UI.SCREEN_W, UI.SCREEN_H, Color("#120c22"), Color("#06040c"), 16)
	for i in 30:
		var tt := t * 0.6 + i
		var x := fmod(absf(Maps.hash2(i, 14)) * UI.SCREEN_W + tt * (5 + Maps.hash2(i, 15) * 9),
			UI.SCREEN_W + 20) - 10
		var y := 20 + Maps.hash2(i, 16) * 190 + sin(tt + i) * 5
		var c: Color = [Color("#6038a0"), Color("#2068a8"), Color("#3a8828"), Color("#a03878")][i % 4]
		UI.rect(self, x, y, 3, 3, c)
		UI.rect(self, x + 2, y - 5, 1, 6, c)
	var scroll := maxf(0.0, (end_t - 0.6) * 21.0)
	for i in end_lines.size():
		var y := UI.SCREEN_H + 10 + i * 14 - scroll
		if y < -12 or y > UI.SCREEN_H + 12:
			continue
		if end_lines[i] == Story.TITLE:
			_draw_big_title(end_lines[i], 160, y)
		else:
			PixelFont.draw_centered(self, end_lines[i], 160, y, Color("#d8d0e8"), {"outline": UI.COL_INK})
	if end_t > 2.0:
		PixelFont.draw_centered(self, "Z", 160, 228, Color("#5a5470"))
