extends Node2D
## Drives the whole loop -- title, field, battle, level-up, menu, shop, ending --
## and screenshots each. Catches the wiring mistakes that only appear when the
## scenes are actually talking to each other.
##
## Note the shape of the step list: a step either CHANGES something or TAKES A
## PICTURE, never both. get_viewport().get_texture() returns the frame that has
## already been drawn, so shooting in the same step as the change captures the
## previous screen and silently mislabels every shot.

const OUT_DIR := "user://shots/"

var main: Node2D
var failures := 0
var step := 0
var wait := 0
var shots := 0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	main = preload("res://scenes/Main.tscn").instantiate()
	add_child(main)


## An invisible protagonist is the worst thing character creation can produce,
## and clearing the canvas and pressing done is a legal way to ask for one. The
## real web build did exactly that: the character walked into town as a bare
## outline while every NPC around them drew fine.
func _check_blank_sprite() -> void:
	var c := preload("res://scenes/Creation.tscn").instantiate()
	add_child(c)
	c.set_process(false)
	c.pname = "Blank"
	c.preset_idx = 2

	var empty := PackedByteArray()
	empty.resize(Sprites.W * Sprites.H)
	c.spr = empty
	var painted := 0
	for b in c._usable_sprite():
		if b != 0:
			painted += 1
	_expect(painted > 100, "an empty canvas falls back to a preset (%d pixels drawn)" % painted)

	# the one that actually happened: "design your own" hands you an outline to
	# draw inside, and pressing done on it is hundreds of painted pixels of
	# nothing at all
	c.spr = Sprites.build({"outlineOnly": true})
	var fill := 0
	for b in c._usable_sprite():
		if b != 0 and b != Sprites.OUTLINE:
			fill += 1
	_expect(fill > 100, "an undrawn outline falls back to a preset (%d filled)" % fill)

	var drawn: PackedByteArray = Sprites.build(Sprites.PRESETS[0].opts)
	c.spr = drawn
	_expect(c._usable_sprite() == drawn, "a drawn sprite is used exactly as drawn")
	c.queue_free()


## Sixteen canvases: four standing and twelve walking.
##
## The point of the derivation rules is that nobody has to draw twelve extra
## pictures, and that anybody who draws one gets to keep it. Both halves of that
## are easy to break and neither would fail loudly.
func _check_walk_frames() -> void:
	var c := preload("res://scenes/Creation.tscn").instantiate()
	add_child(c)
	c.set_process(false)
	c.reset()
	c.spr = Sprites.build(Sprites.PRESETS[3].opts)
	c._front_changed()

	_expect(c.DIRS.size() * c.FRAMES == 16,
		"there are sixteen canvases (%d)" % [c.DIRS.size() * c.FRAMES])

	# an untouched walk frame is the standing drawing, shifted -- so it must
	# differ from standing, and must not be empty
	var stand: PackedByteArray = c._slot_grid("down", 0)
	var step: PackedByteArray = c._slot_grid("down", 1)
	_expect(_fingerprint(step) != _fingerprint(stand),
		"an automatic walk frame differs from standing")
	var painted := 0
	for b in step:
		if b != 0:
			painted += 1
	_expect(painted > 100, "an automatic walk frame is not empty (%d pixels)" % painted)

	# frames 1 and 3 are opposite steps, so they must differ from each other
	_expect(_fingerprint(c._slot_grid("down", 1)) != _fingerprint(c._slot_grid("down", 3)),
		"the two striding frames are not the same picture")

	# nothing drawn yet, so nothing is carried in the save
	_expect(c.all_frames().is_empty(),
		"undrawn walk frames are not saved (%d carried)" % c.all_frames().size())

	# draw on one, and it is kept and carried
	c.set_slot("left", 2)
	c.cx = 8
	c.cy = 20
	c.colour = 14
	c.paint(14)
	var mine: PackedByteArray = c.grids["left2"].duplicate()
	c.set_slot("down", 0)
	c.set_slot("left", 2)
	_expect(_fingerprint(c.grids["left2"]) == _fingerprint(mine),
		"a walk frame you drew on is not regenerated")
	var carried: Dictionary = c.all_frames()
	_expect(carried.has("left2") and carried.size() == 1,
		"only the drawn frame is carried (%s)" % str(carried.keys()))

	# and the player hands it back for that facing and step, and nothing for the
	# ones nobody drew
	var p := Game.new_game("Frames", "fiddle", c._usable_sprite(), "fire",
		c.all_views(), c.all_frames())
	_expect(p.walk_grid("left", 2).size() > 0, "the drawn frame reaches the player")
	_expect(p.walk_grid("left", 1).is_empty(),
		"an undrawn frame is left for the animator to shift")
	_expect(p.walk_grid("down", 0).is_empty(), "standing is not a walk frame")
	c.queue_free()


## The preview cells you can click.
##
## The drawing and the click handling read the same layout, so they cannot
## disagree about where a cell is -- what is worth checking is that the cells
## show what you are actually on, that the window follows you along the fighting
## page, and that none of them is drawn outside the panel they live in.
func _check_panel_cells() -> void:
	var c := preload("res://scenes/Creation.tscn").instantiate()
	add_child(c)
	c.set_process(false)
	c.reset()
	c.spr = Sprites.build(Sprites.PRESETS[0].opts)
	c._front_changed()

	var cells: Array = c._panel_cells()
	_expect(cells.size() == 4, "four cells on the walking page (%d)" % cells.size())
	var keys: Array = []
	for cell in cells:
		keys.append(str(cell.key))
	_expect(keys.has(c.cur_key()), "the canvas you are on is one of them (%s)" % str(keys))
	_expect(keys == ["down", "down1", "down2", "down3"],
		"they are the four steps of this facing (%s)" % str(keys))

	# step to another facing and the cells follow
	c.set_slot("left", 2)
	keys.clear()
	for cell in c._panel_cells():
		keys.append(str(cell.key))
	_expect(keys == ["left", "left1", "left2", "left3"],
		"changing facing changes the cells (%s)" % str(keys))

	# on the fighting page the window slides so the current one is always shown
	var missing: Array = []
	for slot in c.BATTLE_SLOTS:
		c.set_key(str(slot))
		var shown: Array = []
		for cell in c._panel_cells():
			shown.append(str(cell.key))
		if not shown.has(str(slot)):
			missing.append(str(slot))
	_expect(missing.is_empty(),
		"every fighting canvas is visible when you are on it (%s)" % str(missing))

	# and nothing is drawn outside the panel it lives in
	# measured off the panel's own constants: written as literals, this check
	# went stale the moment the panel changed size and reported a fault that
	# was not there
	var outside: Array = []
	for cell in c._panel_cells():
		if cell.x < c.SIDE_X or cell.x + Sprites.W > c.SIDE_X + c.PANEL_W:
			outside.append("%s x" % cell.key)
		if cell.y < 22 or cell.y + Sprites.H > 22 + c.PANEL_H:
			outside.append("%s y" % cell.key)
	_expect(outside.is_empty(), "every cell sits inside the panel (%s)" % str(outside))
	c.queue_free()


## The fighting page: a stance and up to ten attack frames, plus copy and paste.
func _check_battle_frames() -> void:
	var c := preload("res://scenes/Creation.tscn").instantiate()
	add_child(c)
	c.set_process(false)
	c.reset()
	c.spr = Sprites.build(Sprites.PRESETS[2].opts)
	c._front_changed()

	_expect(c.BATTLE_SLOTS.size() == 11,
		"a stance and ten attack frames (%d)" % c.BATTLE_SLOTS.size())
	_expect(c.page_slots().size() == 16, "the walking page holds sixteen")
	c.set_key("battle")
	_expect(c.page == "battle" and c.page_slots().size() == 11,
		"the fighting page holds eleven")

	# stepping wraps round the page it is on rather than falling off the end
	c.set_key("attack10")
	c.step_slot(1)
	_expect(c.cur_key() == "battle", "stepping past the last wraps to the first (%s)" % c.cur_key())

	# an untouched stance is the front view, and an untouched attack is the
	# stance -- so drawing a swing is moving an arm, not starting from nothing
	c.set_key("battle")
	var stance_painted := 0
	for b in c.spr:
		if b != 0:
			stance_painted += 1
	_expect(stance_painted > 100, "an untouched stance is not empty (%d)" % stance_painted)
	_expect(_fingerprint(c._key_grid("attack1")) == _fingerprint(c._key_grid("battle")),
		"an untouched attack frame starts from the stance")

	# copy and paste
	c.set_key("attack1")
	c.cx = 10
	c.cy = 20
	c.colour = 14
	c.paint(14)
	var drawn: PackedByteArray = c.spr.duplicate()
	c.clip = c.spr.duplicate()
	c.set_key("attack2")
	c.hand["attack2"] = true
	c.spr = c.clip.duplicate()
	_expect(_fingerprint(c.spr) == _fingerprint(drawn), "paste puts the copy on the new canvas")

	var carried: Dictionary = c.all_frames()
	_expect(carried.has("attack1") and carried.has("attack2"),
		"drawn attack frames are carried (%s)" % str(carried.keys()))
	_expect(not carried.has("battle"),
		"an untouched stance is not carried (%s)" % str(carried.keys()))

	# ---- and the swing-length rule ----------------------------------------
	var p := Game.new_game("Fight", "fiddle", c._usable_sprite(), "fire",
		c.all_views(), c.all_frames())
	_expect(p.attack_count() == 2, "two drawn frames make a two-frame swing (%d)" % p.attack_count())
	_expect(p.battle_grid().size() > 0, "there is always something to stand as")

	# a gap stops the count: frames 1, 2 and 7 is a two-frame swing, not five
	# frames of nothing followed by a twitch
	p.frames["attack7"] = drawn.duplicate()
	_expect(p.attack_count() == 2,
		"a gap ends the swing rather than being played through (%d)" % p.attack_count())

	p.frames.erase("attack1")
	_expect(p.attack_count() == 0, "no first frame means no swing (%d)" % p.attack_count())
	c.queue_free()


## The walk cycle, checked as arithmetic rather than by watching it.
##
## The old cycle split the figure at column 8 and shifted everything either side
## of it. The legs are drawn at columns 8 to 15, so both legs were always on the
## same side of that line and moved together -- a limp, not a walk.
func _check_walk() -> void:
	# A leg pixel either side of the middle, on a striding frame. The probes are
	# taken from the figure's own measurements rather than written as numbers --
	# when the sprites grew from 24x32 to 32x48 the old fixed coordinates stopped
	# landing on legs at all, and the test failed while the code was fine.
	var leg_y: int = UI.LEG_Y + 4
	var arm_y: int = UI.TORSO_Y + 4
	var l_front := UI.walk_offset(UI.MID - 4, leg_y, 1, 0, UI.FACE_FRONT)
	var l_back := UI.walk_offset(UI.MID + 3, leg_y, 1, 0, UI.FACE_FRONT)
	_expect(l_front.x != 0 and l_back.x != 0 and sign(l_front.x) != sign(l_back.x),
		"seen from the front, the legs scissor (%d and %d)" % [l_front.x, l_back.x])

	# in profile, the same
	var s_front := UI.walk_offset(UI.MID + 3, leg_y, 1, 0, UI.FACE_RIGHT)
	var s_back := UI.walk_offset(UI.MID - 4, leg_y, 1, 0, UI.FACE_RIGHT)
	_expect(s_front.x != 0 and s_back.x != 0 and sign(s_front.x) != sign(s_back.x),
		"in profile, the legs scissor (%d and %d)" % [s_front.x, s_back.x])

	# and the arm swings against the leading leg, which is the thing that makes
	# a side-on walk read as walking rather than sliding
	var arm := UI.walk_offset(UI.MID + 4, arm_y, 1, 0, UI.FACE_RIGHT)
	_expect(arm.x != 0 and sign(arm.x) != sign(s_front.x),
		"in profile, the arm swings against the leading leg (%d vs %d)" % [arm.x, s_front.x])

	# facing left is the same cycle, reflected
	var left_front := UI.walk_offset(UI.MID - 4, leg_y, 1, 0, UI.FACE_LEFT)
	_expect(sign(left_front.x) == sign(s_front.x) * -1 or left_front.x != s_front.x,
		"facing left strides the other way (%d vs %d)" % [left_front.x, s_front.x])

	# standing still means standing still
	var still := UI.walk_offset(UI.MID - 4, leg_y, 0, 0, UI.FACE_RIGHT)
	_expect(still == Vector2i.ZERO, "a standing frame does not move (%s)" % str(still))

	# and the weight shift lifts the upper body without shoving it sideways
	var head := UI.walk_offset(UI.MID, 6, 1, 1, UI.FACE_RIGHT)
	_expect(head.y == 1 and head.x == 0, "the body bobs without sliding (%s)" % str(head))


## Four canvases, one per facing.
##
## Before this, "left" and "right" were the front drawing flipped, so three of
## the four facings were the same picture and a character walking sideways
## stared out of the screen. The check is that the four are actually four.
func _check_four_facings() -> void:
	var c := preload("res://scenes/Creation.tscn").instantiate()
	add_child(c)
	c.set_process(false)
	c.reset()
	c.spr = Sprites.build(Sprites.PRESETS[3].opts)
	c._front_changed()

	var views: Dictionary = c.all_views()
	_expect(views.has("up") and views.has("left") and views.has("right"),
		"the other three facings are generated (%s)" % str(views.keys()))

	var front: PackedByteArray = c.grids["down"]
	var seen := {}
	seen[_fingerprint(front)] = "down"
	var same: Array = []
	for d in ["up", "left", "right"]:
		var fp := _fingerprint(views[d])
		if seen.has(fp):
			same.append("%s is identical to %s" % [d, seen[fp]])
		seen[fp] = d
	_expect(same.is_empty(), "all four facings are different drawings (%s)" % str(same))

	# the profile should be narrower than the front -- that is what makes it a
	# profile rather than the same picture with one eye painted out
	_expect(_width_of(views["right"]) < _width_of(front),
		"the profile is narrower than the front (%d vs %d)" % [
			_width_of(views["right"]), _width_of(front)])

	# left is right, the other way round
	_expect(_fingerprint(views["left"]) == _fingerprint(Sprites.mirrored(views["right"])),
		"facing left is facing right, mirrored")

	# and a facing the player has drawn on is theirs and stays theirs
	c.set_slot("left", 0)
	c.cx = 6
	c.cy = 6
	c.colour = 14
	c.paint(14)
	var mine: PackedByteArray = c.grids["left"].duplicate()
	c.set_slot("down", 0)
	c.set_slot("up", 0)
	c.set_slot("left", 0)
	_expect(_fingerprint(c.grids["left"]) == _fingerprint(mine),
		"a facing you have drawn on is not regenerated")

	# while an untouched one follows the front drawing
	c.set_slot("down", 0)
	c.spr = Sprites.build(Sprites.PRESETS[6].opts)
	c._front_changed()
	var before := _fingerprint(c.all_views()["up"])
	c.spr = Sprites.build(Sprites.PRESETS[1].opts)
	c._front_changed()
	_expect(_fingerprint(c.all_views()["up"]) != before,
		"an untouched facing follows the front drawing")
	c.queue_free()


func _fingerprint(g: PackedByteArray) -> String:
	var h := 0
	for i in g.size():
		h = (h * 31 + int(g[i]) * (i + 1)) % 1000000007
	return str(h)


func _width_of(g: PackedByteArray) -> int:
	var lo := Sprites.W
	var hi := -1
	for y in Sprites.H:
		for x in Sprites.W:
			if Sprites.get_px(g, x, y) != 0:
				lo = mini(lo, x)
				hi = maxi(hi, x)
	return maxi(0, hi - lo + 1)


func _expect(cond: bool, what: String) -> void:
	if cond:
		print("  ok   %s" % what)
	else:
		print("  FAIL %s" % what)
		failures += 1


func _shot(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	if img == null:
		return
	img.save_png(OUT_DIR + "flow-%02d-%s.png" % [shots, name])
	shots += 1


func _process(_d: float) -> void:
	wait += 1
	if wait < 5:
		return
	wait = 0
	match step:
		0:
			print("")
			print("== full flow ==")
			_expect(main.state == main.S.TITLE, "boots to the title")
			_check_blank_sprite()
			_check_four_facings()
			_check_walk()
			_check_walk_frames()
			_check_battle_frames()
			_check_panel_cells()
		1: _shot("title")
		2:
			# make a character the way creation would, then walk into the world
			Game.new_game("Wren", "banjo", Sprites.build(Sprites.PRESETS[1].opts), "fire")
			_expect(Game.player != null, "player created")
			_expect(Game.player.songs.size() == 1, "level 1 taught one song")
			main._enter_field("town", Vector2i(15, 22))
			_expect(main.state == main.S.FIELD, "entered the field")
			_expect(main.current.map.id == "town", "in town")
		3: _shot("town")
		4: main.current.say(Story.OPENING)
		5: _shot("opening")
		6:
			main.current.msg = null
			main._start_battle("meadow", "", "")
			_expect(main.state == main.S.BATTLE, "battle started")
			_expect(main.current.enemies.size() >= 1,
				"%d creature(s) turned up" % main.current.enemies.size())
		7: _shot("battle-intro")
		8:
			var b: Node = main.current
			b.phase = "command"
			_expect(b.alive().size() > 0, "creatures alive at the command prompt")
		9: _shot("battle-command")
		10:
			var b: Node = main.current
			b.phase = "songmenu"
			b.sel = 0
		11: _shot("battle-songs")
		12:
			var b: Node = main.current
			var before_br: int = Game.player.br
			var songs: Array = Game.player.song_book()
			b.do_song(songs[0], 0)
			_expect(Game.player.br < before_br,
				"casting spent breath (%d -> %d)" % [before_br, Game.player.br])
		13: _shot("battle-song-fx")
		14:
			var b: Node = main.current
			for e in b.enemies:
				e.hp = 0
				e["dead"] = true
			b._end(true)
			_expect(b.phase == "victory", "victory screen reached")
			_expect(b.reward.xp > 0, "xp awarded (%d)" % b.reward.xp)
		15: _shot("battle-victory")
		16:
			Game.award_xp(4000)
			_expect(not Game.level_queue.is_empty(), "levels queued (%d)" % Game.level_queue.size())
			main._on_battle_done("win")
			_expect(main.state == main.S.LEVELUP, "level-up screen shown")
		17: _shot("levelup")
		18:
			var lu: Node = main.current
			var songs_before: int = Game.player.songs.size()
			lu.sel = 1                       # first element card
			lu._choose()
			_expect(lu.phase == "result", "a choice was applied")
			_expect(Game.player.songs.size() >= songs_before, "song book did not shrink")
		19: _shot("levelup-result")
		20:
			# the pause menu, sitting over a live field
			main._enter_field("town", Vector2i(15, 22))
			main._on_menu()
			_expect(main.menu != null, "menu opened")
			_expect(not main.current.is_processing(), "field frozen while the menu is up")
		21: _shot("menu-status")
		22: main.menu.page = "songs"
		23: _shot("menu-songs")
		24: main.menu.page = "items"
		25: _shot("menu-items")
		26:
			main._close_menu()
			_expect(main.menu == null, "menu closed")
			_expect(main.current.is_processing(), "field resumed")
		27:
			main._on_shop(["tonic", "rosin", "strings"])
			_expect(main.state == main.S.SHOP, "shop opened")
		28: _shot("shop")
		29:
			main.state = main.S.FIELD
			main._start_ending()
			_expect(main.state == main.S.ENDING, "ending started")
			_expect(main.end_lines.size() > 20, "%d ending lines" % main.end_lines.size())
			var too_wide := 0
			for l in main.end_lines:
				if PixelFont.width(l) > UI.SCREEN_W:
					too_wide += 1
			_expect(too_wide == 0, "no ending line is wider than the screen")
		30: main.end_t = 6.0
		31: _shot("ending")
		32: main.end_t = 22.0
		33: _shot("ending-late")
		34:
			print("")
			print("FAILURES: %d" % failures if failures > 0 else "FLOW TESTS PASSED")
			get_tree().quit(1 if failures > 0 else 0)
	step += 1
