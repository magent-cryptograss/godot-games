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
	field.enter("world", World.town_gate + Vector2i(0, -2))
	field.msg = null


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
	get_tree().quit(0)
