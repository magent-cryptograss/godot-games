class_name UI
extends RefCounted
## Shared chrome: translucent bevelled windows, bars, the pointing cursor.
## All drawn with rects so it stays crisp at the 320x240 base resolution.

## The picture is 480x360 and the window shows it doubled. It was 320x240, which
## put every pixel on screen as a three-by-three block -- too coarse for a tile
## to carry any detail. Anything positioned against the right or the bottom must
## be written against these rather than as a number, or it lands off the screen
## the next time this changes.
const SCREEN_W := 480
const SCREEN_H := 360

const COL_TEXT := Color("#f4f0e8")
const COL_DIM := Color("#b0a8c8")
const COL_FAINT := Color("#8880a0")
const COL_GOLD := Color("#ffe08a")
const COL_GREEN := Color("#90e8b0")
const COL_RED := Color("#f06848")
const COL_BLUE := Color("#78b8f0")
const COL_INK := Color("#0d0a14")


static func rect(ci: CanvasItem, x: float, y: float, w: float, h: float, c: Color) -> void:
	ci.draw_rect(Rect2(round(x), round(y), w, h), c, true)


## Banded vertical gradient -- kept pixelly rather than smooth on purpose.
static func vgrad(ci: CanvasItem, x: float, y: float, w: float, h: float, top: Color, bot: Color, steps: int = 10) -> void:
	var band: float = maxf(1.0, ceilf(h / float(steps)))
	for i in steps:
		var f := 0.0 if steps == 1 else float(i) / float(steps - 1)
		ci.draw_rect(Rect2(x, y + i * band, w, band), top.lerp(bot, f), true)


static func window(ci: CanvasItem, x: float, y: float, w: float, h: float, opts: Dictionary = {}) -> void:
	var a: float = opts.get("alpha", 0.88)
	var top: Color = opts.get("top", Color("#2a2050"))
	var bot: Color = opts.get("bot", Color("#140e2c"))
	top.a = a
	bot.a = a
	vgrad(ci, x + 2, y + 2, w - 4, h - 4, top, bot, 10)
	# outer dark frame
	rect(ci, x + 1, y, w - 2, 1, COL_INK)
	rect(ci, x + 1, y + h - 1, w - 2, 1, COL_INK)
	rect(ci, x, y + 1, 1, h - 2, COL_INK)
	rect(ci, x + w - 1, y + 1, 1, h - 2, COL_INK)
	# bright bevel
	rect(ci, x + 2, y + 1, w - 4, 1, Color("#b8a8e0"))
	rect(ci, x + 1, y + 2, 1, h - 4, Color("#9888c8"))
	rect(ci, x + 2, y + h - 2, w - 4, 1, Color("#4a3a70"))
	rect(ci, x + w - 2, y + 2, 1, h - 4, Color("#5a4a84"))
	rect(ci, x + 3, y + 3, w - 6, 1, Color(0.71, 0.63, 0.90, 0.30))
	rect(ci, x + 3, y + 3, 1, h - 6, Color(0.71, 0.63, 0.90, 0.20))


static func cursor(ci: CanvasItem, x: float, y: float, t: float) -> void:
	var bob: float = roundf(sin(t * 6.6) * 1.5)
	var px: float = x + bob
	for i in 5:
		rect(ci, px + i, y + i, 1, 9 - i * 2, Color("#2a1c08"))
	for i in 4:
		rect(ci, px + i, y + 1 + i, 1, 7 - i * 2, COL_GOLD)
	for i in 2:
		rect(ci, px + i, y + 2 + i, 1, 3 - i, Color("#fff0b0"))


static func bar(ci: CanvasItem, x: float, y: float, w: float, h: float, frac: float,
		c1: Color = Color("#70e890"), c2: Color = Color("#1c8840")) -> void:
	frac = clampf(frac, 0.0, 1.0)
	rect(ci, x - 1, y - 1, w + 2, h + 2, COL_INK)
	rect(ci, x, y, w, h, Color("#241c3a"))
	var fw: float = roundf(w * frac)
	if fw > 0:
		vgrad(ci, x, y, fw, h, c1, c2, 3)
		rect(ci, x, y, fw, 1, c1.lightened(0.25))


static func pcircle(ci: CanvasItem, cx: float, cy: float, r: float, c: Color) -> void:
	var ri := int(r)
	for dy in range(-ri, ri + 1):
		var dx: int = int(floor(sqrt(maxf(0.0, r * r - dy * dy))))
		ci.draw_rect(Rect2(round(cx - dx), round(cy + dy), dx * 2 + 1, 1), c, true)


static func pellipse(ci: CanvasItem, cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
	var ryi := int(ry)
	for dy in range(-ryi, ryi + 1):
		var dx: int = int(floor(rx * sqrt(maxf(0.0, 1.0 - float(dy * dy) / (ry * ry)))))
		ci.draw_rect(Rect2(round(cx - dx), round(cy + dy), dx * 2 + 1, 1), c, true)


static func pring(ci: CanvasItem, cx: float, cy: float, r: float, c: Color, thick: float = 1.0) -> void:
	var ri := int(r)
	for dy in range(-ri, ri + 1):
		var o: int = int(floor(sqrt(maxf(0.0, r * r - dy * dy))))
		var inner: float = r - thick
		var i := -1
		if absi(dy) <= int(inner):
			i = int(floor(sqrt(maxf(0.0, inner * inner - dy * dy))))
		if i < 0:
			ci.draw_rect(Rect2(round(cx - o), round(cy + dy), o * 2 + 1, 1), c, true)
		else:
			ci.draw_rect(Rect2(round(cx - o), round(cy + dy), o - i, 1), c, true)
			ci.draw_rect(Rect2(round(cx + i + 1), round(cy + dy), o - i, 1), c, true)


static func shadow(ci: CanvasItem, cx: float, cy: float, rx: float, ry: float) -> void:
	pellipse(ci, cx, cy, rx, ry, Color(0, 0, 0, 0.3))


## Where the figure is looking, which decides how the walk cycle is built.
enum { FACE_FRONT, FACE_RIGHT, FACE_LEFT }

## The middle of the figure. The legs are drawn either side of it, so this is
## where they have to be split for them to scissor rather than slide.
const MID := 12

## How far a leg swings, in pixels. One pixel on a 24-wide figure is a shuffle;
## two is a stride you can see at a glance.
const STRIDE := 2

## Rows. Below TORSO_Y is arms and body, below LEG_Y is legs.
const TORSO_Y := 17
const LEG_Y := 26


## Draw a palette-index sprite, animating a walk out of one still drawing.
##
## Four frames: stand, one leg forward, stand, the other leg forward, with a
## one-pixel bob on the upper body as the weight shifts.
static func sprite(ci: CanvasItem, g: PackedByteArray, x: float, y: float, sc: int = 1,
		flip: bool = false, walking: bool = false, frame: int = 0, tint = null,
		facing: int = FACE_FRONT) -> void:
	var bob := 1 if walking and (frame % 4 == 1 or frame % 4 == 3) else 0
	var leg := 0
	if walking:
		leg = STRIDE if frame % 4 == 1 else (-STRIDE if frame % 4 == 3 else 0)
	# a profile drawn facing left has its front where a right-facing one has its
	# back, so every comparison below is reflected rather than assumed

	for yy in Sprites.H:
		for xx in Sprites.W:
			var sx := (Sprites.W - 1 - xx) if flip else xx
			var v := g[yy * Sprites.W + sx]
			if v == 0:
				continue
			var c: Color = tint if tint != null else Sprites.PALETTE[v]
			var off := walk_offset(xx, yy, leg, bob, facing)
			ci.draw_rect(Rect2(round(x + (xx + off.x) * sc), round(y + (yy + off.y) * sc),
				sc, sc), c, true)


## Where one pixel of the figure moves to on this frame of the walk.
##
## leg is -1, 0 or +1 for the stride, bob is 0 or 1 for the weight shift. Kept
## out of the draw loop so tests can check the shape of the cycle rather than a
## person having to watch it.
static func walk_offset(xx: int, yy: int, leg: int, bob: int, facing: int) -> Vector2i:
	# a profile drawn facing left has its front where a right-facing one has its
	# back, so the comparisons are reflected rather than assumed
	var s := -1 if facing == FACE_LEFT else 1
	var lead: bool = (xx - MID) * s >= 0        # on the leading side

	if yy < TORSO_Y:
		return Vector2i(0, bob)
	if facing == FACE_FRONT:
		# seen head-on: one leg swings forward as the other swings back, and the
		# arms follow the opposite leg
		return Vector2i(leg if xx < MID else -leg, 0)
	if yy < LEG_Y:
		# in profile the arm is the frontmost mass in these rows, and it swings
		# against the leading leg. The torso behind it stays put.
		return Vector2i(-leg * s if lead else 0, 0)
	# the legs scissor about the middle of the figure
	return Vector2i((leg * s) if lead else (-leg * s), 0)


## Element sigils, used on the level-up cards and in creation.
static func elem_icon(ci: CanvasItem, e: Dictionary, cx: float, cy: float, t: float, lit: bool) -> void:
	var col := Color(e.col)
	var col2 := Color(e.col2)
	if not lit:
		col.a = 0.55
		col2.a = 0.55
	match e.id:
		"fire":
			for i in 3:
				var o: float = sin(t * 8.0 + i) * 1.5
				var c: Color = col2 if i == 0 else (col if i == 1 else Color("#f8f0a0"))
				pellipse(ci, cx + o, cy + 2 - i * 3, 6 - i * 1.6, 8 - i * 2, c)
		"water":
			pellipse(ci, cx, cy + 3, 7, 6, col2)
			pellipse(ci, cx, cy + 2, 6, 5, col)
			for i in 3:
				rect(ci, cx - 5 + i * 4, cy + 1 + sin(t * 5.0 + i) * 1.5, 3, 1, Color("#d0f0ff"))
		"plant":
			rect(ci, cx - 1, cy, 2, 8, Color("#5a2a18"))
			pellipse(ci, cx - 5, cy - 1 + sin(t * 3.0), 4, 3, col2)
			pellipse(ci, cx + 5, cy - 3 + cos(t * 3.0), 4, 3, col)
			pellipse(ci, cx, cy - 6, 4, 4, col)
		"ice":
			for i in 3:
				var a: float = i * 1.05 + t
				ci.draw_line(Vector2(cx - cos(a) * 8, cy - sin(a) * 8), Vector2(cx + cos(a) * 8, cy + sin(a) * 8), col, 1.0)
			pcircle(ci, cx, cy, 2, Color("#f0ecf8"))
		"electric":
			ci.draw_line(Vector2(cx + 2, cy - 8), Vector2(cx - 3, cy + 1), col, 1.0)
			ci.draw_line(Vector2(cx - 3, cy + 1), Vector2(cx + 3, cy), col, 1.0)
			ci.draw_line(Vector2(cx + 3, cy), Vector2(cx - 2, cy + 8), col2, 1.0)
			if sin(t * 11.0) > 0.0:
				var g: Color = col
				g.a *= 0.5
				pcircle(ci, cx, cy, 9, g)
		"earth":
			pellipse(ci, cx, cy + 4, 8, 4, col2)
			pellipse(ci, cx - 2, cy, 5, 5, col)
			pellipse(ci, cx + 4, cy + 2, 4, 3, col2)
		"wind":
			for i in 3:
				var o: float = fmod(t * 80.0 + i * 14.0, 22.0) - 11.0
				ci.draw_line(Vector2(cx - 8, cy - 4 + i * 4), Vector2(cx + 4 + o * 0.3, cy - 4 + i * 4), col, 1.0)
				rect(ci, cx + 5 + o * 0.3, cy - 5 + i * 4, 2, 3, col2)
		"dark":
			pcircle(ci, cx, cy, 8, col2)
			pcircle(ci, cx, cy, 5, COL_INK)
			for i in 4:
				var a: float = t + i * 1.57
				rect(ci, cx + cos(a) * 9, cy + sin(a) * 9, 2, 2, col)


## The shared starfield-and-staves backdrop for the menu screens.
static func menu_bg(ci: CanvasItem, t: float) -> void:
	vgrad(ci, 0, 0, SCREEN_W, SCREEN_H, Color("#1a1030"), Color("#0a0714"), 14)
	for i in 40:
		var x: float = fmod(sin(i * 12.9898) * 43758.5453, 1.0)
		var y: float = fmod(sin(i * 78.233) * 43758.5453, 1.0)
		x = absf(x) * SCREEN_W
		y = absf(y) * SCREEN_H
		var tw: float = sin(t * 2.0 + i) * 0.5 + 0.5
		rect(ci, x, y, 1, 1, Color(0.78, 0.75, 0.94, 0.15 + tw * 0.35))
	for i in 5:
		rect(ci, 0, 60 + i * 8 + sin(t * 1.1) * 3, SCREEN_W, 1, Color(0.78, 0.75, 0.94, 0.07))
