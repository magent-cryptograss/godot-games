extends Node2D
## Photograph an overworld town cluster.
##
## The tile data says V/R/W/n -- roof, roof, upper wall, lower wall -- so if the
## bottom of the house comes out green the fault is in the drawing, not in the
## map. This is the picture that tells the two apart.

const OUT_DIR := "user://shots/"

var field: Node2D
var frames := 0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	Game.new_game("Look", "fiddle", Sprites.build(Sprites.PRESETS[3].opts), "plant")
	# build the world before reading where the town ended up: town_gate holds a
	# placeholder until the generator runs, and the placeholder is up in the
	# crags, which is a long way from any house
	World.build_all()
	field = preload("res://scenes/Field.tscn").instantiate()
	add_child(field)
	# the town, which has a ring of trees round it -- the cliff finder is kept
	# below for when the rock faces are what needs looking at
	field.enter("world", World.town_gate + Vector2i(0, -3))
	field.msg = null


## Somewhere with a cliff edge in shot: high ground with walkable ground under
## it. Hunted for rather than named, because a coordinate picked by eye lands in
## a boulder field and photographs the wrong thing entirely -- which is exactly
## what happened the first time.
func _find_cliff() -> Vector2i:
	var m: Maps.GameMap = World.build_all()["world"]
	for y in range(20, m.h - 20, 3):
		for x in range(20, m.w - 20, 3):
			if m.get_tile(x, y) != "^":
				continue
			# want a run of cliff with open ground below it
			var run := 0
			for dx in range(-2, 3):
				if m.get_tile(x + dx, y) == "^":
					run += 1
			if run < 3:
				continue
			if Maps.is_solid(m.get_tile(x, y + 1)):
				continue
			print("  cliff at %d,%d" % [x, y])
			return Vector2i(x, y + 2)
	# say so rather than quietly photographing somewhere else, which is what
	# happened the first time and cost a round of looking at the wrong picture
	print("  NO CLIFF FOUND -- falling back to the town")
	return World.town_gate


func _process(_d: float) -> void:
	frames += 1
	if frames < 4:
		return
	var vt := get_viewport().get_texture()
	var img: Image = vt.get_image() if vt != null else null
	if img == null:
		print("SHOT: no rendering device")
		get_tree().quit(1)
		return
	img.save_png(OUT_DIR + "overworld-town.png")
	print("SHOT: %s" % ProjectSettings.globalize_path(OUT_DIR + "overworld-town.png"))
	print("SHOTS SAVED")
	get_tree().quit(0)
