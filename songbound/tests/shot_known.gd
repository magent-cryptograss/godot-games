extends Node2D
## Play a song at two creatures and check the marks that appear under them.
##
## Both halves matter and they fail differently: the recording can be right
## while nothing is drawn, and the drawing can be right while it records the
## wrong thing. So this runs a real song through a real battle and then
## photographs the result.

const OUT_DIR := "user://shots/"

var battle: Node2D
var frames := 0
var failures := 0


func _expect(cond: bool, what: String) -> void:
	if cond:
		print("  ok   %s" % what)
	else:
		print("  FAIL %s" % what)
		failures += 1


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	print("")
	print("== what the player learns ==")
	Game.new_game("Scout", "fiddle", Sprites.build(Sprites.PRESETS[1].opts), "fire")
	battle = preload("res://scenes/Battle.tscn").instantiate()
	add_child(battle)
	battle.begin("meadow", "", "")

	# one creature fire beats, one that beats fire
	battle.enemies.clear()
	battle.enemies.append(Data.make_enemy("rime", 1.0))       # ice: fire beats it
	battle.enemies.append(Data.make_enemy("mire", 1.0))       # water: it beats fire
	battle._layout()
	battle.phase = "command"

	Game.player.known.clear()
	_expect(Game.player.known_of("rime").is_empty(),
		"a creature starts with nothing known about it")

	# a fire song at everything
	var sd: Dictionary = Data.SONGS["fire"][1].duplicate(true)   # hits all
	sd["elem"] = "fire"
	Game.player.br = 99
	battle.do_song(sd, 0)

	# read from the player's memory, which is where the marks come from now
	var ice_known: Dictionary = Game.player.known_of("rime")
	var water_known: Dictionary = Game.player.known_of("mire")
	_expect(ice_known.has("fire") and bool(ice_known["fire"]),
		"the ice creature is marked weak to fire (%s)" % str(ice_known))
	_expect(water_known.has("fire") and not bool(water_known["fire"]),
		"the water creature is marked as resisting fire (%s)" % str(water_known))
	_expect(not ice_known.has("water"),
		"nothing is claimed about an element never tried (%s)" % str(ice_known))

	# ---- and it is remembered ---------------------------------------------
	# a fresh fight against the same kind of creature knows it already
	var second := preload("res://scenes/Battle.tscn").instantiate()
	add_child(second)
	second.begin("meadow", "", "")
	second.enemies.clear()
	second.enemies.append(Data.make_enemy("rime", 1.0))
	second._layout()
	var remembered: Dictionary = Game.player.known_of("rime")
	_expect(remembered.has("fire") and bool(remembered["fire"]),
		"a new fight against the same kind knows it already (%s)" % str(remembered))
	_expect(Game.player.known_of("thistle").is_empty(),
		"a kind never fought is still unknown")
	second.queue_free()

	# and it survives being saved and loaded
	_expect(Game.save_game(), "the game saved")
	Game.player.known.clear()
	_expect(Game.load_game(), "the game loaded")
	var loaded: Dictionary = Game.player.known_of("rime")
	_expect(loaded.has("fire") and bool(loaded["fire"]),
		"the memory survives a save and load (%s)" % str(loaded))
	var loaded_water: Dictionary = Game.player.known_of("mire")
	_expect(loaded_water.has("fire") and not bool(loaded_water["fire"]),
		"a resistance survives too, still marked as a resistance (%s)" % str(loaded_water))

	battle.phase = "command"


func _process(_d: float) -> void:
	frames += 1
	if frames < 6:
		return
	var vt := get_viewport().get_texture()
	var img: Image = vt.get_image() if vt != null else null
	if img != null:
		img.save_png(OUT_DIR + "known-marks.png")
		print("  shot -> %s" % ProjectSettings.globalize_path(OUT_DIR + "known-marks.png"))
	print("")
	if failures > 0:
		print("FAILURES: %d" % failures)
	else:
		print("KNOWN MARKS PASSED")
	get_tree().quit(1 if failures > 0 else 0)
