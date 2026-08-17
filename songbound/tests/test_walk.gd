extends Node2D
## Draws the whole walk sheet: four facings across, four frames down.
##
## The cycle is checked as arithmetic in TestFlow, which proves the legs move in
## opposite directions but not that the result looks like a person walking. This
## is the picture for judging that by eye.
##
##   xvfb-run -a godot --path <proj> res://tests/TestWalk.tscn --rendering-driver opengl3

const OUT_DIR := "user://shots/"
const SC := 1

var frames := 0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	Game.new_game("Walker", "fiddle", Sprites.build(Sprites.PRESETS[3].opts), "plant")


func _draw() -> void:
	draw_rect(Rect2(0, 0, UI.SCREEN_W, UI.SCREEN_H), Color("#2a2438"), true)
	var p := Game.player
	var dirs := [
		["down", UI.FACE_FRONT], ["up", UI.FACE_FRONT],
		["left", UI.FACE_LEFT], ["right", UI.FACE_RIGHT],
	]
	# facings down the page, frames across it. Four 32-tall sprites will not fit
	# in four rows at any scale above 1 on a 240-tall screen.
	for f in 4:
		PixelFont.draw(self, "frame %d" % f, Vector2(80 + f * 100, 8), UI.COL_FAINT)
	for r in dirs.size():
		var d: String = dirs[r][0]
		var look: int = dirs[r][1]
		var y := 22 + r * 84
		PixelFont.draw(self, d, Vector2(8, y + 20), UI.COL_GOLD)
		for f in 4:
			var x := 80 + f * 100
			UI.rect(self, x - 3, y - 3, Sprites.W * SC + 6, Sprites.H * SC + 6,
				Color(0, 0, 0, 0.28))
			UI.sprite(self, p.view(d), x, y, SC, false, true, f, null, look)


func _process(_d: float) -> void:
	frames += 1
	if frames < 4:
		return
	var vt := get_viewport().get_texture()
	var img: Image = vt.get_image() if vt != null else null
	if img == null:
		print("WALK: no rendering device")
		get_tree().quit(1)
		return
	img.save_png(OUT_DIR + "walksheet.png")
	print("WALK SHEET: %s" % ProjectSettings.globalize_path(OUT_DIR + "walksheet.png"))
	get_tree().quit(0)
