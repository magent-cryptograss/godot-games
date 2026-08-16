extends Node2D
## Captures the river over several frames and measures how much the water
## pixels actually change, so "it animates" is a number rather than a claim.

const OUT_DIR := "user://shots/"

var field: Node2D
var frames := 0
var shots := 0
var prev: Image = null
var diffs: Array = []


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	Game.new_game("Wren", "fiddle", Sprites.build(Sprites.PRESETS[3].opts), "water")
	field = preload("res://scenes/Field.tscn").instantiate()
	add_child(field)
	field.enter("world", _find_water())
	field.msg = null


## Somewhere with a good deal of river in shot. Hunting for it rather than
## naming a tile means the test survives the next time the world is resized --
## the hardcoded coordinate this replaced ended up in dry mountain, and the test
## dutifully reported that the rock was not moving.
func _find_water() -> Vector2i:
	var m: Maps.GameMap = World.build_all()["world"]
	var best := Vector2i(m.w / 2, m.h / 2)
	var best_n := -1
	for y in range(6, m.h - 6, 7):
		for x in range(6, m.w - 6, 7):
			if Maps.is_solid(m.get_tile(x, y)):
				continue
			var n := 0
			for dy in range(-4, 5):
				for dx in range(-6, 7):
					if m.get_tile(x + dx, y + dy) == "~":
						n += 1
			if n > best_n:
				best_n = n
				best = Vector2i(x, y)
				if n > 60:
					return best
	print("WATER: standing at %s with %d water tiles in view" % [best, best_n])
	return best


func _process(_d: float) -> void:
	frames += 1
	if frames < 12:
		return
	frames = 0
	var img := get_viewport().get_texture().get_image()
	if img == null:
		print("WATER: no rendering device")
		get_tree().quit(1)
		return
	img.save_png(OUT_DIR + "water-%d.png" % shots)
	if prev != null:
		# count pixels that changed between frames -- if the water is animating
		# this is thousands; if it is a still picture it is nearly zero
		var changed := 0
		for y in range(0, img.get_height(), 2):
			for x in range(0, img.get_width(), 2):
				if img.get_pixel(x, y) != prev.get_pixel(x, y):
					changed += 1
		diffs.append(changed)
		print("WATER: frame %d, %d sampled pixels changed" % [shots, changed])
	prev = img
	shots += 1
	if shots >= 4:
		var total := 0
		for d in diffs:
			total += d
		var avg := float(total) / float(maxi(1, diffs.size()))
		print("WATER: average %.0f changed pixels per capture" % avg)
		if avg > 200.0:
			print("WATER ANIMATION PASSED")
			get_tree().quit(0)
		else:
			print("FAIL: the surface is not moving")
			get_tree().quit(1)
