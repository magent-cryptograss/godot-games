extends Node

const FRAME_W = 56
const FRAME_H = 52
const COLS = 16

# X and Axl share the same sheet layout (173/177 frames, same animation structure)
const ANIMS_X = {
	"idle": [13, 14, 15, 14],
	"walk": [39, 40, 41, 42, 43, 44, 45, 46],
	"dash": [59, 60, 61],
	"jump": [64, 65, 66],
	"fall": [74, 75, 76],
	"wall_slide": [80, 81],
	"wall_jump": [64, 65],
	"shoot": [22, 23],
	"idle_shoot": [22, 23],
	"walk_shoot": [54, 55, 56, 57],
	"dash_shoot": [59, 60],
	"jump_shoot": [70, 71, 72],
	"hurt": [96, 97, 98],
	"death": [128, 129, 130, 131],
	"ladder": [112, 113],
	"ladder_shoot": [114, 115],
	"land": [13],
}

# Zero has his own frame layout (41 frames from individual strips)
# idle:0-4, walk_start:5, walk:6-15, dash:16-19, jump:20-24,
# double_jump:25-33, wall_slide:34-36, hit:37-40
const ANIMS_ZERO = {
	"idle": [0, 1, 2, 3, 4, 3, 2, 1],
	"walk": [6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
	"dash": [16, 17, 18, 19],
	"jump": [20, 21, 22],
	"fall": [23, 24],
	"wall_slide": [34, 35, 36],
	"wall_jump": [20, 21],
	"shoot": [0, 1],  # Zero slashes, reuse idle for now
	"idle_shoot": [0, 1],
	"walk_shoot": [6, 7, 8, 9],
	"dash_shoot": [16, 17],
	"jump_shoot": [20, 21],
	"hurt": [37, 38, 39, 40],
	"death": [37, 38, 39, 40],
	"ladder": [0, 1],
	"ladder_shoot": [0, 1],
	"land": [0],
}

var x_tex: Texture2D = null
var zero_tex: Texture2D = null
var axl_tex: Texture2D = null

func _ready() -> void:
	x_tex = _load("res://sprites/x_uniform.png")
	zero_tex = _load("res://sprites/zero_uniform.png")
	axl_tex = _load("res://sprites/axl_uniform.png")

func _load(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	return null

func draw_character(canvas: CanvasItem, char_id: int, x: float, y: float, anim_name: String, anim_time: float, flip_h: bool = false) -> void:
	var tex: Texture2D = null
	var anims: Dictionary

	match char_id:
		0:  # Axl — uses same layout as X
			tex = axl_tex
			anims = ANIMS_X
		1:  # Zero — unique layout
			tex = zero_tex
			anims = ANIMS_ZERO
		2:  # X
			tex = x_tex
			anims = ANIMS_X

	if tex == null:
		return

	var frames = anims.get(anim_name, anims["idle"])
	if frames.size() == 0:
		return

	var fps = 10.0
	var fi = int(anim_time * fps) % frames.size()
	var sheet_frame = frames[fi]

	var col = sheet_frame % COLS
	var row = sheet_frame / COLS
	var src = Rect2(col * FRAME_W, row * FRAME_H, FRAME_W, FRAME_H)

	var dx = x - FRAME_W / 2.0
	var dy = y - FRAME_H

	if flip_h:
		canvas.draw_texture_rect_region(tex, Rect2(dx + FRAME_W, dy, -FRAME_W, FRAME_H), src)
	else:
		canvas.draw_texture_rect_region(tex, Rect2(dx, dy, FRAME_W, FRAME_H), src)
