extends Node2D
## Walks the creation screens and saves a PNG of each, so the drawing code can
## be checked without a human at a monitor.
##
##   xvfb-run -a godot --path . res://tests/TestCreation.tscn --rendering-driver opengl3

const OUT_DIR := "user://shots/"
const STEPS := ["name", "spritechoice", "gallery", "editor", "instrument", "element"]

var creation: Node2D
var idx := 0
var frames := 0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	creation = preload("res://scenes/Creation.tscn").instantiate()
	add_child(creation)
	creation.set_process(false)          # freeze animation so shots are stable
	_setup(0)


func _setup(i: int) -> void:
	creation.step = STEPS[i]
	creation.pname = "Rosalie"
	creation.t = 1.0
	match STEPS[i]:
		"gallery":
			creation.preset_idx = 3
			creation.spr = Sprites.build(Sprites.PRESETS[3].opts)
		"editor":
			creation.spr = Sprites.build(Sprites.PRESETS[1].opts)
			creation.colour = 14
			creation.cx = 7
			creation.cy = 11
		"instrument":
			creation.inst_idx = 2
		"element":
			creation.elem_idx = 4
	creation.queue_redraw()


func _process(_d: float) -> void:
	frames += 1
	if frames < 4:
		return
	frames = 0
	var img := get_viewport().get_texture().get_image()
	if img == null:
		print("CREATION: no image")
		get_tree().quit(1)
		return
	var path := OUT_DIR + "%02d-%s.png" % [idx, STEPS[idx]]
	img.save_png(path)
	var lit := 0
	for y in range(0, img.get_height(), 4):
		for x in range(0, img.get_width(), 4):
			var c := img.get_pixel(x, y)
			if c.r + c.g + c.b > 0.5:
				lit += 1
	print("CREATION: %-14s %d lit -> %s" % [STEPS[idx], lit, path])
	if lit < 40:
		print("  WARNING: %s looks nearly empty" % STEPS[idx])
	idx += 1
	if idx >= STEPS.size():
		print("CREATION: done, %s" % ProjectSettings.globalize_path(OUT_DIR))
		print("SHOTS SAVED")
		get_tree().quit(0)
		return
	_setup(idx)
