extends Node2D
## Character creation: name, sprite (draw your own or pick one), instrument,
## and the first element -- which is a real level-up, because level 1 is a
## song level.

signal finished(player: Player)
signal cancelled

const KB_ROWS := [
	"ABCDEFGHIJKLM",
	"NOPQRSTUVWXYZ",
	"abcdefghijklm",
	"nopqrstuvwxyz",
	"0123456789 -'",
]

const ED_GX := 8
const ED_GY := 26
# 5px cells on a 24x32 grid: finer pixels than the old 6px on 16x24, and the
# drawing area stays about the same size on screen
const ED_CELL := 5
const PAL_X := 136
const PAL_Y := 30
const PAL_CELL := 11

var step := "name"
var pname := ""
var spr: PackedByteArray = PackedByteArray()
var undo_stack: Array = []

var preset_idx := 0
var inst_idx := 0
var elem_idx := 0
var choice_right := false          # sprite-choice: false = draw, true = pick

var cx := 8
var cy := 12
var colour := 23
var mirror := true
var tmpl := 0

var t := 0.0
var repeat_t := {}
var typed: Array[String] = []

@onready var _templates := [
	func() -> PackedByteArray: return Sprites.build({"outlineOnly": true}),
	func() -> PackedByteArray: return Sprites.blank(),
	func() -> PackedByteArray: return Sprites.build({}),
]


func _ready() -> void:
	reset()
	set_process(true)


func reset() -> void:
	step = "name"
	pname = ""
	spr = Sprites.build({"outlineOnly": true})
	undo_stack.clear()
	preset_idx = 0
	inst_idx = 0
	elem_idx = 0
	choice_right = false
	cx = 8
	cy = 12
	colour = 23
	mirror = true
	tmpl = 0
	typed.clear()


# ------------------------------------------------------------------- input --

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if step == "name":
			# Typing is the primary input. Deliberately no Z/X bindings here:
			# 'z' and 'x' are letters people put in names.
			if k.keycode == KEY_BACKSPACE:
				pname = pname.substr(0, maxi(0, pname.length() - 1))
			elif k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER:
				if pname.strip_edges().length() > 0:
					step = "spritechoice"
			elif k.unicode > 0:
				var ch := char(k.unicode)
				if pname.length() < 12 and _is_name_char(ch):
					typed.append(ch)
		elif step == "editor":
			match k.keycode:
				KEY_X: paint(0)
				KEY_Q: colour = wrapi(colour - 1, 0, Sprites.PALETTE.size())
				KEY_E: colour = wrapi(colour + 1, 0, Sprites.PALETTE.size())
				KEY_F:
					push_undo()
					Sprites.flood_fill(spr, cx, cy, colour)
					if mirror:
						Sprites.flood_fill(spr, Sprites.W - 1 - cx, cy, colour)
				KEY_M: mirror = not mirror
				KEY_U:
					if undo_stack.size() > 0:
						spr = undo_stack.pop_back()
				KEY_R:
					push_undo()
					spr = Sprites.blank()
				KEY_T:
					push_undo()
					tmpl = (tmpl + 1) % _templates.size()
					spr = _templates[tmpl].call()
				KEY_ENTER, KEY_KP_ENTER: finish_editor()
				KEY_ESCAPE: step = "spritechoice"


func _is_name_char(c: String) -> bool:
	var code := c.unicode_at(0)
	if code >= 65 and code <= 90: return true
	if code >= 97 and code <= 122: return true
	if code >= 48 and code <= 57: return true
	return c == " " or c == "-" or c == "'"


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


# ------------------------------------------------------------------ update --

func _process(dt: float) -> void:
	t += dt
	while typed.size() > 0:
		var ch: String = typed.pop_front()
		if pname.length() < 12:
			pname += ch
	match step:
		"name": pass
		"spritechoice": up_choice(dt)
		"gallery": up_gallery(dt)
		"editor": up_editor(dt)
		"instrument": up_instrument(dt)
		"element": up_element(dt)
	queue_redraw()


func mouse() -> Vector2:
	return get_local_mouse_position()


func hit(x: float, y: float, w: float, h: float) -> bool:
	var m := mouse()
	return m.x >= x and m.y >= y and m.x < x + w and m.y < y + h


func up_choice(dt: float) -> void:
	if repeated("move_left", dt) or repeated("move_right", dt):
		choice_right = not choice_right
	var boxes := [Vector2(34, 74), Vector2(168, 74)]
	for i in 2:
		if hit(boxes[i].x, boxes[i].y, 118, 96):
			choice_right = (i == 1)
			if Input.is_action_just_pressed("ui_ok") or _click():
				enter_sprite_mode()
				return
	if Input.is_action_just_pressed("ui_ok"):
		enter_sprite_mode()
	elif Input.is_action_just_pressed("ui_back"):
		step = "name"


var _was_click := false
func _click() -> bool:
	var down := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var fired := down and not _was_click
	_was_click = down
	return fired


func enter_sprite_mode() -> void:
	if choice_right:
		step = "gallery"
		spr = Sprites.build(Sprites.PRESETS[0].opts)
	else:
		step = "editor"
		spr = _templates[0].call()
		undo_stack.clear()


func up_gallery(dt: float) -> void:
	var n := Sprites.PRESETS.size()
	if repeated("move_left", dt):
		preset_idx = wrapi(preset_idx - 1, 0, n)
		spr = Sprites.build(Sprites.PRESETS[preset_idx].opts)
	if repeated("move_right", dt):
		preset_idx = wrapi(preset_idx + 1, 0, n)
		spr = Sprites.build(Sprites.PRESETS[preset_idx].opts)
	if repeated("move_up", dt):
		preset_idx = wrapi(preset_idx - 4, 0, n)
		spr = Sprites.build(Sprites.PRESETS[preset_idx].opts)
	if repeated("move_down", dt):
		preset_idx = wrapi(preset_idx + 4, 0, n)
		spr = Sprites.build(Sprites.PRESETS[preset_idx].opts)
	for i in n:
		var x := 22 + (i % 4) * 72
		var y := 56 + int(i / 4) * 74
		if hit(x, y, 64, 66):
			if preset_idx != i:
				preset_idx = i
				spr = Sprites.build(Sprites.PRESETS[i].opts)
			if _click():
				step = "instrument"
				return
	if Input.is_action_just_pressed("ui_ok"):
		step = "instrument"
	elif Input.is_action_just_pressed("ui_menu"):
		step = "editor"
		undo_stack.clear()
	elif Input.is_action_just_pressed("ui_back"):
		step = "spritechoice"


func push_undo() -> void:
	undo_stack.append(spr.duplicate())
	if undo_stack.size() > 30:
		undo_stack.pop_front()


func paint(v: int) -> void:
	push_undo()
	Sprites.set_px(spr, cx, cy, v)
	if mirror:
		Sprites.set_px(spr, Sprites.W - 1 - cx, cy, v)


func up_editor(dt: float) -> void:
	if repeated("move_left", dt): cx = wrapi(cx - 1, 0, Sprites.W)
	if repeated("move_right", dt): cx = wrapi(cx + 1, 0, Sprites.W)
	if repeated("move_up", dt): cy = wrapi(cy - 1, 0, Sprites.H)
	if repeated("move_down", dt): cy = wrapi(cy + 1, 0, Sprites.H)
	# Z paints continuously; it is read as a raw key so that holding Enter to
	# finish does not also scribble on the canvas.
	if Input.is_key_pressed(KEY_Z) or Input.is_key_pressed(KEY_SPACE):
		if Sprites.get_px(spr, cx, cy) != colour:
			paint(colour)

	var gw := Sprites.W * ED_CELL
	var gh := Sprites.H * ED_CELL
	if hit(ED_GX, ED_GY, gw, gh):
		var m := mouse()
		cx = clampi(int((m.x - ED_GX) / ED_CELL), 0, Sprites.W - 1)
		cy = clampi(int((m.y - ED_GY) / ED_CELL), 0, Sprites.H - 1)
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Sprites.get_px(spr, cx, cy) != colour:
			paint(colour)
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			paint(0)
	for i in Sprites.PALETTE.size():
		var x := PAL_X + (i % 8) * PAL_CELL
		var y := PAL_Y + int(i / 8) * PAL_CELL
		if hit(x, y, PAL_CELL, PAL_CELL) and _click():
			colour = i
	if hit(232, 190, 76, 18) and _click():
		finish_editor()


func finish_editor() -> void:
	var lit := 0
	for i in spr.size():
		if spr[i] != 0:
			lit += 1
	if lit < 12:
		return
	step = "instrument"


func up_instrument(dt: float) -> void:
	var n := Data.INSTRUMENTS.size()
	if repeated("move_left", dt): inst_idx = wrapi(inst_idx - 1, 0, n)
	if repeated("move_right", dt): inst_idx = wrapi(inst_idx + 1, 0, n)
	if repeated("move_up", dt): inst_idx = wrapi(inst_idx - 4, 0, n)
	if repeated("move_down", dt): inst_idx = wrapi(inst_idx + 4, 0, n)
	for i in n:
		var x := 16 + (i % 4) * 74
		var y := 46 + int(i / 4) * 46
		if hit(x, y, 68, 40):
			inst_idx = i
			if _click():
				step = "element"
				return
	if Input.is_action_just_pressed("ui_ok"):
		step = "element"
	elif Input.is_action_just_pressed("ui_back"):
		step = "spritechoice"


func up_element(dt: float) -> void:
	var n := Data.ELEMENTS.size()
	if repeated("move_left", dt): elem_idx = wrapi(elem_idx - 1, 0, n)
	if repeated("move_right", dt): elem_idx = wrapi(elem_idx + 1, 0, n)
	if repeated("move_up", dt): elem_idx = wrapi(elem_idx - 4, 0, n)
	if repeated("move_down", dt): elem_idx = wrapi(elem_idx + 4, 0, n)
	for i in n:
		var x := 16 + (i % 4) * 74
		var y := 50 + int(i / 4) * 48
		if hit(x, y, 68, 42):
			elem_idx = i
			if _click():
				do_finish()
				return
	if Input.is_action_just_pressed("ui_ok"):
		do_finish()
	elif Input.is_action_just_pressed("ui_back"):
		step = "instrument"


func do_finish() -> void:
	var p := Game.new_game(
		pname.strip_edges(),
		Data.INSTRUMENTS[inst_idx].id,
		spr,
		Data.ELEMENTS[elem_idx].id)
	finished.emit(p)


# -------------------------------------------------------------------- draw --

func _draw() -> void:
	UI.menu_bg(self, t)
	match step:
		"name": draw_name()
		"spritechoice": draw_choice()
		"gallery": draw_gallery()
		"editor": draw_editor()
		"instrument": draw_instrument()
		"element": draw_element()


func draw_name() -> void:
	UI.window(self, 28, 16, 264, 42)
	PixelFont.draw_centered(self, "What is your name?", 160, 26, UI.COL_TEXT, {"outline": UI.COL_INK})
	var caret := "_" if fmod(t, 0.8) < 0.4 else " "
	PixelFont.draw_centered(self, pname + caret, 160, 42, UI.COL_GOLD, {"outline": UI.COL_INK})

	UI.window(self, 46, 68, 228, 108)
	for r in KB_ROWS.size():
		var row: String = KB_ROWS[r]
		for c in row.length():
			var x := 58 + c * 16
			var y := 80 + r * 18
			var hot := hit(x - 3, y - 3, 14, 14)
			if hot:
				UI.rect(self, x - 3, y - 3, 14, 14, Color("#6a5aa8"))
				UI.rect(self, x - 3, y - 3, 14, 1, Color("#b8a8e0"))
			PixelFont.draw_centered(self, row[c], x + 2, y,
				Color("#fff4c0") if hot else Color("#d8d0e8"), {"outline": UI.COL_INK} if hot else {})
	PixelFont.draw_centered(self, "Type your name, or click the letters.", 160, 186, UI.COL_DIM)
	PixelFont.draw_centered(self, "BACKSPACE deletes      ENTER when done", 160, 200, UI.COL_FAINT)


func draw_choice() -> void:
	UI.window(self, 28, 16, 264, 40)
	PixelFont.draw_centered(self, "How should you look?", 160, 26, UI.COL_TEXT, {"outline": UI.COL_INK})
	PixelFont.draw_centered(self, "You can always redraw later.", 160, 40, Color("#a8a0c0"))
	var titles := ["Draw your own", "Pick one"]
	var subs := ["a pixel editor", "eight ready-made"]
	var xs := [34, 168]
	for i in 2:
		var sel := choice_right == (i == 1)
		var o := {"top": Color("#4a3a80"), "bot": Color("#241a48")} if sel else {}
		UI.window(self, xs[i], 74, 118, 96, o)
		if sel:
			UI.rect(self, xs[i], 74, 118, 1, UI.COL_GOLD)
			UI.rect(self, xs[i], 169, 118, 1, UI.COL_GOLD)
		PixelFont.draw_centered(self, titles[i], xs[i] + 59, 84,
			UI.COL_GOLD if sel else Color("#d0c8e0"), {"outline": UI.COL_INK} if sel else {})
		PixelFont.draw_centered(self, subs[i], xs[i] + 59, 96, Color("#9890b8"))
		if i == 0:
			var gx: int = xs[i] + 34
			for yy in 12:
				for xx in 12:
					UI.rect(self, gx + xx * 4, 110 + yy * 4, 3, 3,
						Color("#2a2448") if (xx + yy) % 2 == 1 else Color("#332a54"))
			draw_sprite_grid(Sprites.build({"outlineOnly": true}), gx + 12, 104, 2)
		else:
			draw_sprite_grid(Sprites.build(Sprites.PRESETS[1].opts), xs[i] + 24, 108, 2)
			draw_sprite_grid(Sprites.build(Sprites.PRESETS[3].opts), xs[i] + 62, 108, 2)
	PixelFont.draw_centered(self, "LEFT / RIGHT to choose,  Z to confirm", 160, 190, UI.COL_DIM)


func draw_gallery() -> void:
	PixelFont.draw_centered(self, "Pick a look", 160, 12, UI.COL_TEXT, {"outline": UI.COL_INK})
	for i in Sprites.PRESETS.size():
		var x := 22 + (i % 4) * 72
		var y := 56 + int(i / 4) * 74
		var sel := i == preset_idx
		UI.window(self, x, y, 64, 66,
			{"top": Color("#4a3a80"), "bot": Color("#241a48")} if sel else {"alpha": 0.7})
		draw_sprite_grid(Sprites.build(Sprites.PRESETS[i].opts), x + 8, y + 2, 2)
		PixelFont.draw_centered(self, Sprites.PRESETS[i].name, x + 32, y + 56,
			UI.COL_GOLD if sel else Color("#a8a0c0"))
	PixelFont.draw_centered(self, "Z to take this one    C to open it in the editor", 160, 208, UI.COL_DIM)
	PixelFont.draw_centered(self, "X to go back", 160, 222, UI.COL_FAINT)


func draw_editor() -> void:
	PixelFont.draw(self, "Draw yourself", Vector2(12, 8), UI.COL_TEXT, {"outline": UI.COL_INK})
	PixelFont.draw_right(self, "mirror: " + ("on" if mirror else "off"), 308, 8,
		UI.COL_GREEN if mirror else UI.COL_FAINT)

	var gw := Sprites.W * ED_CELL
	var gh := Sprites.H * ED_CELL
	UI.rect(self, ED_GX - 2, ED_GY - 2, gw + 4, gh + 4, UI.COL_INK)
	for y in Sprites.H:
		for x in Sprites.W:
			var v := spr[y * Sprites.W + x]
			var c: Color = Sprites.PALETTE[v] if v != 0 else (Color("#2a2448") if (x + y) % 2 == 1 else Color("#332a54"))
			UI.rect(self, ED_GX + x * ED_CELL, ED_GY + y * ED_CELL, ED_CELL, ED_CELL, c)
	# guides at the centre line and the waist
	UI.rect(self, ED_GX + 12 * ED_CELL, ED_GY, 1, gh, Color(0.66, 0.88, 0.97, 0.25))
	UI.rect(self, ED_GX, ED_GY + 26 * ED_CELL, gw, 1, Color(0.66, 0.88, 0.97, 0.25))
	# cursor
	var cxp := ED_GX + cx * ED_CELL
	var cyp := ED_GY + cy * ED_CELL
	UI.rect(self, cxp - 1, cyp - 1, ED_CELL + 2, 1, UI.COL_GOLD)
	UI.rect(self, cxp - 1, cyp + ED_CELL, ED_CELL + 2, 1, UI.COL_GOLD)
	UI.rect(self, cxp - 1, cyp, 1, ED_CELL, UI.COL_GOLD)
	UI.rect(self, cxp + ED_CELL, cyp, 1, ED_CELL, UI.COL_GOLD)
	if mirror:
		var mxp := ED_GX + (Sprites.W - 1 - cx) * ED_CELL
		UI.rect(self, mxp - 1, cyp - 1, ED_CELL + 2, 1, Color(0.66, 0.88, 0.97, 0.5))
		UI.rect(self, mxp - 1, cyp + ED_CELL, ED_CELL + 2, 1, Color(0.66, 0.88, 0.97, 0.5))

	PixelFont.draw(self, "Colours", Vector2(PAL_X, PAL_Y - 10), UI.COL_DIM)
	for i in Sprites.PALETTE.size():
		var x := PAL_X + (i % 8) * PAL_CELL
		var y := PAL_Y + int(i / 8) * PAL_CELL
		if i == 0:
			UI.rect(self, x, y, PAL_CELL - 1, PAL_CELL - 1, Color("#332a54"))
			draw_line(Vector2(x, y + PAL_CELL - 2), Vector2(x + PAL_CELL - 2, y), Color("#c03828"), 1.0)
		else:
			UI.rect(self, x, y, PAL_CELL - 1, PAL_CELL - 1, Sprites.PALETTE[i])
		if i == colour:
			UI.rect(self, x - 1, y - 1, PAL_CELL + 1, 1, UI.COL_GOLD)
			UI.rect(self, x - 1, y + PAL_CELL - 1, PAL_CELL + 1, 1, UI.COL_GOLD)
			UI.rect(self, x - 1, y - 1, 1, PAL_CELL + 1, UI.COL_GOLD)
			UI.rect(self, x + PAL_CELL - 1, y - 1, 1, PAL_CELL + 1, UI.COL_GOLD)
	UI.rect(self, PAL_X, PAL_Y + 50, 16, 16, UI.COL_INK)
	if colour != 0:
		UI.rect(self, PAL_X + 1, PAL_Y + 51, 14, 14, Sprites.PALETTE[colour])
	else:
		UI.rect(self, PAL_X + 1, PAL_Y + 51, 14, 14, Color("#332a54"))
	PixelFont.draw(self, ("colour %d" % colour) if colour != 0 else "eraser",
		Vector2(PAL_X + 21, PAL_Y + 55), Color("#d0c8e0"))

	UI.window(self, 240, 26, 76, 104, {"alpha": 0.8})
	PixelFont.draw_centered(self, "preview", 278, 30, Color("#9890b8"))
	var dirs := ["down", "left", "up", "right"]
	var d: String = dirs[int(t / 1.1) % 4]
	draw_sprite_grid(Sprites.back_view(spr) if d == "up" else spr, 254, 42, 2, d == "left")
	PixelFont.draw_centered(self, d, 278, 118, UI.COL_FAINT)

	UI.window(self, 8, 186, 214, 48, {"alpha": 0.82})
	PixelFont.draw(self, "move: arrows   paint: Z   erase: X", Vector2(16, 192), Color("#c8c0dc"))
	PixelFont.draw(self, "colour: Q/E or click   fill: F", Vector2(16, 204), Color("#c8c0dc"))
	PixelFont.draw(self, "mirror: M  undo: U  clear: R  template: T", Vector2(16, 216), Color("#c8c0dc"))
	var hot := hit(232, 190, 76, 18)
	UI.window(self, 232, 190, 76, 18, {"top": Color("#5a4a98")} if hot else {})
	PixelFont.draw_centered(self, "ENTER  done", 270, 196, Color("#fff4c0") if hot else UI.COL_GOLD)


func draw_instrument() -> void:
	PixelFont.draw_centered(self, "Choose your instrument", 160, 10, UI.COL_TEXT, {"outline": UI.COL_INK})
	PixelFont.draw_centered(self, "This is how your songs will sound.", 160, 24, Color("#a8a0c0"))
	for i in Data.INSTRUMENTS.size():
		var it: Dictionary = Data.INSTRUMENTS[i]
		var x := 16 + (i % 4) * 74
		var y := 46 + int(i / 4) * 46
		var sel := i == inst_idx
		UI.window(self, x, y, 68, 40,
			{"top": Color("#4a3a80"), "bot": Color("#241a48")} if sel else {"alpha": 0.7})
		draw_inst_icon(it.id, x + 34, y + 16, sel)
		PixelFont.draw_centered(self, it.name, x + 34, y + 30, UI.COL_GOLD if sel else Color("#a8a0c0"))
	var cur: Dictionary = Data.INSTRUMENTS[inst_idx]
	UI.window(self, 12, 142, 296, 62)
	PixelFont.draw(self, cur.name, Vector2(20, 148), UI.COL_GOLD, {"outline": UI.COL_INK})
	var lines := PixelFont.wrap_text(cur.desc, 280)
	for i in lines.size():
		PixelFont.draw(self, lines[i], Vector2(20, 160 + i * 10), Color("#d8d0e8"))
	var keys := [["HP", cur.mods.hp], ["BR", cur.mods.br], ["ATK", cur.mods.atk],
		["DEF", cur.mods.def], ["MUS", cur.mods.mus], ["SPD", cur.mods.spd]]
	for i in keys.size():
		var x := 20 + i * 48
		PixelFont.draw(self, keys[i][0], Vector2(x, 186), Color("#9890b8"))
		var v: int = keys[i][1]
		var c := UI.COL_GREEN if v > 0 else (UI.COL_RED if v < 0 else UI.COL_FAINT)
		PixelFont.draw(self, ("+%d" % v) if v > 0 else str(v), Vector2(x + 22, 186), c)
	PixelFont.draw_centered(self, "Z to choose", 160, 214, UI.COL_DIM)


func draw_element() -> void:
	PixelFont.draw_centered(self, "Choose your first element", 160, 8, UI.COL_TEXT, {"outline": UI.COL_INK})
	PixelFont.draw_centered(self, "Level 1 is a song level. This one you learn now.", 160, 22, Color("#a8a0c0"))
	for i in Data.ELEMENTS.size():
		var e: Dictionary = Data.ELEMENTS[i]
		var x := 16 + (i % 4) * 74
		var y := 50 + int(i / 4) * 48
		var sel := i == elem_idx
		UI.window(self, x, y, 68, 42,
			{"top": Color(e.col2), "bot": Color("#181030")} if sel else {"alpha": 0.7})
		UI.elem_icon(self, e, x + 34, y + 16, t, sel)
		PixelFont.draw_centered(self, e.name, x + 34, y + 30,
			Color(e.col) if sel else Color("#a8a0c0"), {"outline": UI.COL_INK} if sel else {})
	var el: Dictionary = Data.ELEMENTS[elem_idx]
	var s0: Dictionary = Data.SONGS[el.id][0]
	UI.window(self, 12, 150, 296, 56)
	PixelFont.draw(self, el.name, Vector2(20, 156), Color(el.col), {"outline": UI.COL_INK})
	PixelFont.draw(self, el.desc, Vector2(20 + PixelFont.width(el.name) + 10, 156), Color("#a8a0c0"))
	PixelFont.draw(self, "First song:  " + s0.name, Vector2(20, 172), UI.COL_TEXT)
	PixelFont.draw(self, Data.describe_song(s0), Vector2(20, 186), Color("#c0b8d8"))
	PixelFont.draw_centered(self, "Z to begin", 160, 216, UI.COL_DIM)


func draw_sprite_grid(g: PackedByteArray, x: float, y: float, sc: int, flip: bool = false) -> void:
	for yy in Sprites.H:
		for xx in Sprites.W:
			var sx := (Sprites.W - 1 - xx) if flip else xx
			var v := g[yy * Sprites.W + sx]
			if v == 0:
				continue
			UI.rect(self, x + xx * sc, y + yy * sc, sc, sc, Sprites.PALETTE[v])


func draw_inst_icon(id: String, cx0: float, cy0: float, lit: bool) -> void:
	var c1 := Color("#e8c090") if lit else Color("#a89078")
	var c2 := Color("#8a4a24") if lit else Color("#5a3a24")
	match id:
		"guitar":
			UI.pellipse(self, cx0, cy0 + 3, 7, 8, c1)
			UI.pcircle(self, cx0, cy0 + 3, 2, Color("#2a1a10"))
			UI.rect(self, cx0 - 1, cy0 - 11, 2, 10, c2)
		"fiddle":
			UI.pellipse(self, cx0 - 2, cy0 + 3, 5, 7, c1)
			UI.rect(self, cx0 - 3, cy0 - 8, 2, 8, c2)
			draw_line(Vector2(cx0 + 4, cy0 - 6), Vector2(cx0 - 6, cy0 + 8),
				Color("#f0ecf8") if lit else Color("#a0a0b0"), 1.0)
		"banjo":
			UI.pcircle(self, cx0, cy0 + 3, 7, Color("#f0ecf8") if lit else Color("#b0aac0"))
			UI.pring(self, cx0, cy0 + 3, 7, c2, 2)
			UI.rect(self, cx0 - 1, cy0 - 11, 2, 11, c2)
		"mandolin":
			UI.pellipse(self, cx0, cy0 + 4, 6, 6, c1)
			UI.rect(self, cx0 - 1, cy0 - 8, 2, 9, c2)
			UI.pcircle(self, cx0, cy0 + 4, 2, Color("#2a1a10"))
		"bass":
			UI.pellipse(self, cx0, cy0 + 4, 8, 9, c1)
			UI.rect(self, cx0 - 1, cy0 - 12, 2, 11, c2)
			UI.pellipse(self, cx0, cy0 + 4, 3, 3, Color("#2a1a10"))
		"dulcimer":
			UI.rect(self, cx0 - 9, cy0 - 1, 18, 8, c1)
			UI.rect(self, cx0 - 9, cy0 - 1, 18, 2, Color("#f0d040") if lit else Color("#a89040"))
			for i in 5:
				UI.rect(self, cx0 - 7 + i * 3, cy0 + 1, 1, 5, c2)
		"harmonica":
			UI.rect(self, cx0 - 9, cy0 - 2, 18, 7, Color("#b0aac0") if lit else Color("#7a7488"))
			UI.rect(self, cx0 - 9, cy0, 18, 2, Color("#2a2438"))
			for i in 6:
				UI.rect(self, cx0 - 8 + i * 3, cy0, 1, 2, Color("#f0ecf8") if lit else Color("#8a84a0"))
		_:
			UI.pcircle(self, cx0, cy0 + 1, 9, c2)
			UI.pcircle(self, cx0, cy0 + 1, 7, Color("#e8d8b8") if lit else Color("#a89878"))
			UI.pring(self, cx0, cy0 + 1, 9, c1, 2)
