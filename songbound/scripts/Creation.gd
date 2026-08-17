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
const ED_GY := 32
# 6px cells on a 32x48 grid: 192 by 288, which fills the left of the screen and
# leaves the right for the palette, the four facings and the key list
const ED_CELL := 6
const PAL_X := 212
const PAL_Y := 42
const PAL_CELL := 11
## Where the right-hand column of panels starts
const SIDE_X := 352.0

var step := "name"
var pname := ""
var spr: PackedByteArray = PackedByteArray()      # the canvas being drawn on
var undo_stack: Array = []

## One drawing per facing. spr is whichever of these is currently being edited.
const DIRS := ["down", "up", "left", "right"]
## Standing, then the three steps of the walk.
const FRAMES := 4
var dir := "down"
var frame := 0

## The fighting page: how you stand in a fight, and up to ten frames of swing.
const BATTLE_SLOTS := ["battle", "attack1", "attack2", "attack3", "attack4",
	"attack5", "attack6", "attack7", "attack8", "attack9", "attack10"]
const SLOT_NAMES := {
	"battle": "in a fight", "attack1": "attack 1", "attack2": "attack 2",
	"attack3": "attack 3", "attack4": "attack 4", "attack5": "attack 5",
	"attack6": "attack 6", "attack7": "attack 7", "attack8": "attack 8",
	"attack9": "attack 9", "attack10": "attack 10",
}
var page := "walk"
var bslot := 0
## One canvas held aside, for copy and paste.
var clip := PackedByteArray()
var grids := {}
## Which facings the player has actually touched. An untouched one is rebuilt
## from the front drawing whenever it is opened, so changing your mind about
## your hair does not leave three stale views behind.
var hand := {}

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
	dir = "down"
	frame = 0
	grids = {"down": spr}
	page = "walk"
	bslot = 0
	clip = PackedByteArray()
	hand = {}
	for d in DIRS:
		for f in FRAMES:
			hand[_slot(d, f)] = false
	for key in BATTLE_SLOTS:
		hand[key] = false
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
					hand[cur_key()] = true
					Sprites.flood_fill(spr, cx, cy, colour)
					if mirror:
						Sprites.flood_fill(spr, Sprites.W - 1 - cx, cy, colour)
				KEY_M: mirror = not mirror
				KEY_U:
					if undo_stack.size() > 0:
						spr = undo_stack.pop_back()
				KEY_R:
					push_undo()
					hand[cur_key()] = true
					spr = Sprites.blank()
				KEY_T:
					push_undo()
					hand[cur_key()] = true
					tmpl = (tmpl + 1) % _templates.size()
					spr = _templates[tmpl].call()
				KEY_B:
					# swap pages, landing on the first canvas of the other one
					set_key("down" if page == "battle" else "battle")
				KEY_COMMA: step_slot(-1)
				KEY_PERIOD: step_slot(1)
				KEY_C:
					clip = spr.duplicate()
					Audio.sfx("confirm")
				KEY_V:
					if clip.size() == spr.size():
						push_undo()
						hand[cur_key()] = true
						spr = clip.duplicate()
						Audio.sfx("confirm")
				KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0:
					var n: int = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5,
						KEY_6, KEY_7, KEY_8, KEY_9, KEY_0].find(k.keycode)
					if page == "battle":
						set_key(str(BATTLE_SLOTS[mini(n, BATTLE_SLOTS.size() - 1)]))
					elif n < 4:
						set_slot(str(DIRS[n]), frame)
					elif n < 8:
						set_slot(dir, n - 4)
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


## A new front drawing means the automatic views are out of date. The ones the
## player has drawn by hand are left exactly as they are.
func _front_changed() -> void:
	grids["down"] = spr
	dir = "down"
	frame = 0
	page = "walk"
	for d in DIRS:
		for f in FRAMES:
			var key := _slot(d, f)
			if key != "down" and not bool(hand.get(key, false)):
				grids.erase(key)
	for key in BATTLE_SLOTS:
		if not bool(hand.get(key, false)):
			grids.erase(key)


func enter_sprite_mode() -> void:
	if choice_right:
		step = "gallery"
		spr = Sprites.build(Sprites.PRESETS[0].opts)
	else:
		step = "editor"
		spr = _templates[0].call()
		undo_stack.clear()
	_front_changed()


func up_gallery(dt: float) -> void:
	var n := Sprites.PRESETS.size()
	if repeated("move_left", dt):
		preset_idx = wrapi(preset_idx - 1, 0, n)
		spr = Sprites.build(Sprites.PRESETS[preset_idx].opts)
		_front_changed()
	if repeated("move_right", dt):
		preset_idx = wrapi(preset_idx + 1, 0, n)
		spr = Sprites.build(Sprites.PRESETS[preset_idx].opts)
		_front_changed()
	if repeated("move_up", dt):
		preset_idx = wrapi(preset_idx - 4, 0, n)
		spr = Sprites.build(Sprites.PRESETS[preset_idx].opts)
		_front_changed()
	if repeated("move_down", dt):
		preset_idx = wrapi(preset_idx + 4, 0, n)
		spr = Sprites.build(Sprites.PRESETS[preset_idx].opts)
		_front_changed()
	for i in n:
		var x := 22 + (i % 4) * 72
		var y := 56 + int(i / 4) * 74
		if hit(x, y, 64, 66):
			if preset_idx != i:
				preset_idx = i
				spr = Sprites.build(Sprites.PRESETS[i].opts)
				_front_changed()
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


const FRAME_NAMES := ["stand", "walk 1", "walk 2", "walk 3"]


## Where the four preview cells are, and which canvas each one shows.
##
## Worked out once and used by both the drawing and the click handling: a click
## target that has drifted away from the picture it is under is worse than not
## being able to click at all.
func _panel_cells() -> Array:
	var slots := page_slots()
	var here: int = slots.find(cur_key())
	var start := 0
	if page == "battle":
		# a window that slides along, since eleven will not fit in four
		start = clampi(here - 1, 0, maxi(0, slots.size() - 4))
	else:
		start = int(here / FRAMES) * FRAMES
	var out: Array = []
	for i in 4:
		var idx := start + i
		if idx >= slots.size():
			break
		out.append({
			"key": str(slots[idx]),
			"x": SIDE_X + 10.0 + (i % 2) * 54.0,
			"y": 38.0 + int(i / 2) * 62.0,
		})
	return out


## The short form, for a cell that is 32 pixels wide.
func _short_label(key: String) -> String:
	if key == "battle":
		return "stance"
	if key.begins_with("attack"):
		return "atk " + key.substr(6)
	for d in DIRS:
		for f in FRAMES:
			if _slot(d, f) == key:
				return FRAME_NAMES[f]
	return key


## What a canvas is called, for the labels.
func _slot_label(key: String) -> String:
	if SLOT_NAMES.has(key):
		return str(SLOT_NAMES[key])
	for d in DIRS:
		for f in FRAMES:
			if _slot(d, f) == key:
				return "%s %s" % [d, FRAME_NAMES[f]] if f > 0 else d
	return key


## Whatever should be shown for any canvas by name.
func _key_grid(key: String) -> PackedByteArray:
	if key == cur_key():
		return spr
	if bool(hand.get(key, false)) and grids.has(key):
		return grids[key]
	return _derive_key(key)


## Whatever should be shown for a canvas: what was drawn on it, or the automatic
## version if nobody has touched it.
func _slot_grid(d: String, f: int) -> PackedByteArray:
	var key := _slot(d, f)
	if bool(hand.get(key, false)) and grids.has(key):
		return grids[key]
	return _derive(d, f)


## The name of one of the sixteen canvases: a facing, and which step of its walk.
static func _slot(d: String, f: int) -> String:
	return d if f == 0 else "%s%d" % [d, f]


## Which canvas is being drawn on.
func cur_key() -> String:
	return BATTLE_SLOTS[bslot] if page == "battle" else _slot(dir, frame)


## Every canvas on the page currently open, in order.
func page_slots() -> Array:
	if page == "battle":
		return BATTLE_SLOTS.duplicate()
	var out: Array = []
	for d in DIRS:
		for f in FRAMES:
			out.append(_slot(d, f))
	return out


## Move to another canvas, saving the one being left and rebuilding the one
## being opened if it has never been touched.
func set_key(key: String) -> void:
	if key == cur_key():
		return
	grids[cur_key()] = spr
	if BATTLE_SLOTS.has(key):
		page = "battle"
		bslot = BATTLE_SLOTS.find(key)
	else:
		page = "walk"
		for d in DIRS:
			for f in FRAMES:
				if _slot(d, f) == key:
					dir = d
					frame = f
	if not bool(hand.get(key, false)) or not grids.has(key):
		grids[key] = _derive_key(key)
	spr = grids[key]
	undo_stack.clear()
	Audio.sfx("cursor")


func set_slot(d: String, f: int) -> void:
	set_key(_slot(d, f))


## Step to the next or previous canvas on this page.
func step_slot(by: int) -> void:
	var slots := page_slots()
	var i: int = slots.find(cur_key())
	set_key(str(slots[wrapi(i + by, 0, slots.size())]))


## What an untouched canvas shows.
##
## The fighting stance starts as the front view, so nothing about how the game
## looks changes until somebody draws a proper one; each attack frame starts as
## the stance, so drawing a swing means moving an arm rather than starting from
## an empty grid.
func _derive_key(key: String) -> PackedByteArray:
	if key == "battle":
		return _slot_grid("down", 0).duplicate()
	if key.begins_with("attack"):
		var stance := "battle"
		if bool(hand.get(stance, false)) and grids.has(stance):
			return grids[stance].duplicate()
		return _derive_key(stance)
	for d in DIRS:
		for f in FRAMES:
			if _slot(d, f) == key:
				return _derive(d, f)
	return spr.duplicate()


## What a canvas looks like if nobody has drawn on it: the standing facings come
## from the front drawing, and the walk frames come from shifting the standing
## drawing of their own facing, which is how the game animates them anyway.
func _derive(d: String, f: int = 0) -> PackedByteArray:
	var front: PackedByteArray = grids.get("down", spr)
	if f > 0:
		var stand: PackedByteArray = grids[d] if (bool(hand.get(d, false)) and grids.has(d)) \
			else _derive(d, 0)
		var look := UI.FACE_FRONT
		if d == "left":
			look = UI.FACE_LEFT
		elif d == "right":
			look = UI.FACE_RIGHT
		return Sprites.walk_frame(stand, f, look)
	match d:
		"up":
			return Sprites.back_view(front)
		"left":
			return Sprites.mirrored(Sprites.side_view(front))
		"right":
			return Sprites.side_view(front)
	return front.duplicate()


## The four standing drawings, with untouched ones filled in from the front.
func all_views() -> Dictionary:
	grids[cur_key()] = spr
	var out := {}
	for d in DIRS:
		if d == "down":
			continue
		out[d] = grids[d] if bool(hand.get(d, false)) and grids.has(d) else _derive(d, 0)
	return out


## Only the walk frames somebody actually drew. An undrawn one is left out
## entirely so the game animates it by shifting, rather than carrying twelve
## copies of a shift around in every save file.
func all_frames() -> Dictionary:
	grids[cur_key()] = spr
	var out := {}
	for d in DIRS:
		for f in range(1, FRAMES):
			var key := _slot(d, f)
			if bool(hand.get(key, false)) and grids.has(key):
				out[key] = grids[key]
	for key in BATTLE_SLOTS:
		if bool(hand.get(key, false)) and grids.has(key):
			out[key] = grids[key]
	return out


func push_undo() -> void:
	undo_stack.append(spr.duplicate())
	if undo_stack.size() > 30:
		undo_stack.pop_front()


func paint(v: int) -> void:
	push_undo()
	hand[cur_key()] = true
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
	for cell in _panel_cells():
		if hit(cell.x - 3, cell.y - 3, Sprites.W + 6, Sprites.H + 6) and _click():
			set_key(str(cell.key))
			return
	for i in Sprites.PALETTE.size():
		var x := PAL_X + (i % 8) * PAL_CELL
		var y := PAL_Y + int(i / 8) * PAL_CELL
		if hit(x, y, PAL_CELL, PAL_CELL) and _click():
			colour = i
	if hit(8, 324, 92, 24) and _click():
		clip = spr.duplicate()
		Audio.sfx("confirm")
		return
	if hit(108, 324, 92, 24) and _click() and clip.size() == spr.size():
		push_undo()
		hand[cur_key()] = true
		spr = clip.duplicate()
		Audio.sfx("confirm")
		return
	if hit(PAL_X, 330, 130, 24) and _click():
		finish_editor()


func finish_editor() -> void:
	grids[cur_key()] = spr
	var lit := 0
	for i in PackedByteArray(grids.get("down", spr)):
		if i != 0:
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


## How much filled-in body counts as a character rather than an accident.
## Counting painted pixels is not enough: "design your own" starts you on an
## outline of a figure to draw inside, which is hundreds of pixels and still
## invisible to play as. A drawn face alone is over a hundred filled pixels, so
## this only catches someone who drew nothing at all.
const MIN_FILL := 40

func do_finish() -> void:
	var front := _usable_sprite()
	# if the guard swapped in a preset, the automatic views must come from that
	if front != grids.get("down", front):
		grids["down"] = front
	var p := Game.new_game(
		pname.strip_edges(),
		Data.INSTRUMENTS[inst_idx].id,
		front,
		Data.ELEMENTS[elem_idx].id,
		all_views(),
		all_frames())
	finished.emit(p)


## The drawn sprite, or a preset if there is effectively nothing drawn.
func _usable_sprite() -> PackedByteArray:
	grids[cur_key()] = spr
	var front: PackedByteArray = grids.get("down", spr)
	var filled := 0
	for b in front:
		if b != 0 and b != Sprites.OUTLINE:
			filled += 1
	if filled >= MIN_FILL:
		return front
	return Sprites.build(Sprites.PRESETS[preset_idx % Sprites.PRESETS.size()].opts)


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
	PixelFont.draw_right(self, "mirror: " + ("on" if mirror else "off"), UI.SCREEN_W - 12, 8,
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
	UI.rect(self, ED_GX + int(Sprites.W / 2) * ED_CELL, ED_GY, 1, gh,
		Color(0.66, 0.88, 0.97, 0.25))
	UI.rect(self, ED_GX, ED_GY + int(Sprites.H * 3 / 4) * ED_CELL, gw, 1,
		Color(0.66, 0.88, 0.97, 0.25))
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

	# All four at once, with the one being drawn ringed. A facing that has not
	# been touched shows the automatic version, so you can see what you are
	# getting for free before deciding whether to draw it yourself.
	UI.window(self, SIDE_X, 22, 120, 216, {"alpha": 0.8})
	PixelFont.draw_centered(self, "fighting" if page == "battle" else dir,
		SIDE_X + 60, 26, Color("#9890b8"))
	PixelFont.draw(self, "drawing: " + _slot_label(cur_key()), Vector2(168, 8), UI.COL_GOLD)
	grids[cur_key()] = spr
	# Four canvases at a time, with the one being drawn ringed. On the walking
	# page that is the four steps of this facing; on the fighting page it is a
	# window that slides along as you step, since eleven will not fit.
	for cell in _panel_cells():
		var key: String = cell.key
		var gx: float = cell.x
		var gy: float = cell.y
		# the one under the pointer lifts, so it is clear it can be pressed
		if hit(gx - 3, gy - 3, Sprites.W + 6, Sprites.H + 6) and key != cur_key():
			UI.rect(self, gx - 3, gy - 3, Sprites.W + 6, Sprites.H + 6, Color("#3d3468"))
		if key == cur_key():
			UI.rect(self, gx - 3, gy - 3, Sprites.W + 6, Sprites.H + 6, Color("#5a4a98"))
			UI.rect(self, gx - 2, gy - 2, Sprites.W + 4, Sprites.H + 4,
				Color(0.09, 0.07, 0.16, 0.9))
		draw_sprite_grid(_key_grid(key), gx, gy, 1, false)
		# short labels: "down walk 1" side by side is wider than the two cells
		# it sits under, and the header above already says which facing this is
		PixelFont.draw_centered(self, _short_label(key), gx + int(Sprites.W / 2),
			gy + Sprites.H + 2, UI.COL_GOLD if key == cur_key() else UI.COL_FAINT)

	# and it running, which is the only way to tell whether it actually moves
	if page == "battle":
		var drawn: Array = []
		for key in BATTLE_SLOTS:
			if key != "battle" and bool(hand.get(key, false)) and grids.has(key):
				drawn.append(key)
		PixelFont.draw_centered(self, "swinging" if drawn.size() > 0 else "no swing yet",
			SIDE_X + 60, 166, Color("#9890b8"))
		var show: String = "battle"
		if drawn.size() > 0:
			show = str(drawn[int(t * 8.0) % drawn.size()])
		draw_sprite_grid(_key_grid(show), SIDE_X + 44, 178, 1, false)
	else:
		var beat := int(t * 7.0) % FRAMES
		PixelFont.draw_centered(self, "walking", SIDE_X + 60, 166, Color("#9890b8"))
		draw_sprite_grid(_slot_grid(dir, beat), SIDE_X + 44, 178, 1, false)

	UI.window(self, PAL_X, 230, UI.SCREEN_W - PAL_X - 8, 94, {"alpha": 0.82})
	PixelFont.draw(self, "move: arrows   paint: Z   erase: X", Vector2(PAL_X + 8, 236), Color("#c8c0dc"))
	PixelFont.draw(self, "colour: Q/E or click   fill: F", Vector2(PAL_X + 8, 250), Color("#c8c0dc"))
	PixelFont.draw(self, "mirror: M  undo: U  clear: R  template: T", Vector2(PAL_X + 8, 264), Color("#c8c0dc"))
	PixelFont.draw(self, "facing: 1 down  2 up  3 left  4 right", Vector2(PAL_X + 8, 278), UI.COL_GOLD)
	PixelFont.draw(self, "frame:  5 stand  6/7/8 walking", Vector2(PAL_X + 8, 292), UI.COL_GOLD)
	PixelFont.draw(self, "B fighting page   , . step   C/V copy paste",
		Vector2(PAL_X + 8, 306), UI.COL_GREEN)
	# COPY and PASTE under the canvas. Most frames of an animation are the last
	# frame with one arm moved, and redrawing a whole figure to move an arm is
	# how somebody stops bothering.
	var copy_hot := hit(8, 324, 92, 24)
	UI.window(self, 8, 324, 92, 24, {"top": Color("#5a4a98")} if copy_hot else {})
	PixelFont.draw_centered(self, "COPY  C", 54, 332,
		Color("#fff4c0") if copy_hot else UI.COL_TEXT)
	var paste_hot := hit(108, 324, 92, 24)
	var can_paste: bool = clip.size() == spr.size()
	UI.window(self, 108, 324, 92, 24, {"top": Color("#5a4a98")} if paste_hot and can_paste else {})
	PixelFont.draw_centered(self, "PASTE  V", 154, 332,
		(Color("#fff4c0") if paste_hot else UI.COL_TEXT) if can_paste else Color("#6a6480"))

	var hot := hit(PAL_X, 330, 130, 24)
	UI.window(self, PAL_X, 330, 130, 24, {"top": Color("#5a4a98")} if hot else {})
	PixelFont.draw_centered(self, "ENTER  done", PAL_X + 65, 338,
		Color("#fff4c0") if hot else UI.COL_GOLD)


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
