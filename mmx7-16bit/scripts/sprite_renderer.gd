extends Node

# Sprite sheet renderer for X, Zero, Axl
# Sheets are 16 columns x 11 rows, 56x52 pixels per frame

const FRAME_W = 56
const FRAME_H = 52
const COLS = 16
const ROWS = 11

# Animation frame mappings (frame indices into the uniform sheet)
# Determined by examining the X8 16-bit sprite sheet layout
const ANIMS = {
	# Row 0: special effects (hp bar, charge drop, teleport in)
	# Row 1: teleport sequence, idle intro
	# Row 2: idle, idle blink
	"idle": [12, 13, 14, 13],
	"idle_shoot": [22, 23],
	# Row 3: charge frames, shoot standing
	"shoot": [20, 21, 22],
	"charge_idle": [24, 25, 26, 27],
	# Row 4: walk/run
	"walk": [38, 39, 40, 41, 42, 43, 44, 45, 46, 47],
	"walk_shoot": [48, 49, 50, 51],
	# Row 5: dash
	"dash": [55, 56, 57],
	"dash_shoot": [58, 59],
	# Row 6: jump / fall
	"jump": [64, 65, 66],
	"fall": [67, 68],
	"jump_shoot": [69, 70, 71],
	# Row 7: wall slide, wall jump
	"wall_slide": [80, 81],
	"wall_jump": [82, 83, 84],
	# Row 8: hurt, death
	"hurt": [96, 97, 98],
	"death": [99, 100, 101, 102],
	# Row 9: ladder
	"ladder": [112, 113],
	"ladder_shoot": [114, 115],
	# Row 10: landing, misc
	"land": [128, 129],
}

var x_texture: Texture2D = null
var zero_texture: Texture2D = null
var axl_texture: Texture2D = null

func _ready() -> void:
	# Load sprite sheets
	x_texture = _load_tex("res://sprites/x_uniform.png")
	zero_texture = _load_tex("res://sprites/zero_uniform.png")
	axl_texture = _load_tex("res://sprites/axl_uniform.png")

func _load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	return null

func get_texture(char_id: int) -> Texture2D:
	match char_id:
		0: return axl_texture
		1: return zero_texture
		2: return x_texture
	return x_texture

func get_frame_rect(frame_idx: int) -> Rect2:
	var col = frame_idx % COLS
	var row = frame_idx / COLS
	return Rect2(col * FRAME_W, row * FRAME_H, FRAME_W, FRAME_H)

func draw_character(canvas: CanvasItem, char_id: int, x: float, y: float, anim_name: String, anim_time: float, flip_h: bool = false) -> void:
	var tex = get_texture(char_id)
	if tex == null:
		return

	# Get animation frames
	var frames = ANIMS.get(anim_name, ANIMS["idle"])
	if frames.size() == 0:
		return

	# Calculate current frame
	var fps = 8.0
	var frame_idx = int(anim_time * fps) % frames.size()
	var sheet_frame = frames[frame_idx]

	# Source rectangle in the sheet
	var src = get_frame_rect(sheet_frame)

	# Destination: centered on x, bottom at y
	var dst_x = x - FRAME_W / 2.0
	var dst_y = y - FRAME_H

	if flip_h:
		# Flip horizontally
		canvas.draw_texture_rect_region(tex, Rect2(dst_x + FRAME_W, dst_y, -FRAME_W, FRAME_H), src)
	else:
		canvas.draw_texture_rect_region(tex, Rect2(dst_x, dst_y, FRAME_W, FRAME_H), src)
