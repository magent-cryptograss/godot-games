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
