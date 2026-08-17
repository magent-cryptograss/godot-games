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

	var before: Dictionary = battle.enemies[0].known
	_expect(before.is_empty(), "a creature starts with nothing known about it")

	# a fire song at everything
	var sd: Dictionary = Data.SONGS["fire"][1].duplicate(true)   # hits all
	sd["elem"] = "fire"
	Game.player.br = 99
	battle.do_song(sd, 0)

	var ice_known: Dictionary = battle.enemies[0].known
	var water_known: Dictionary = battle.enemies[1].known
	_expect(ice_known.has("fire") and bool(ice_known["fire"]),
		"the ice creature is marked weak to fire (%s)" % str(ice_known))
	_expect(water_known.has("fire") and not bool(water_known["fire"]),
		"the water creature is marked as resisting fire (%s)" % str(water_known))
	_expect(not ice_known.has("water"),
		"nothing is claimed about an element never tried (%s)" % str(ice_known))

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
