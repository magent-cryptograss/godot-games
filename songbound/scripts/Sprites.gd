class_name Sprites
extends RefCounted
## Player sprites are a 24x32 grid of palette indices, index 0 transparent.
## The same format is used by the editor, the presets and the field renderer,
## so anything you can draw, the game can animate.

## Characters are 32 wide and 48 tall -- one tile across and a tile and a half
## up, against 32-pixel tiles. At 24x32 the figure was smaller than a single
## tile and less detailed than the ground it stood on.
const W := 32
const H := 48

const PALETTE := [
	Color(0, 0, 0, 0),                                                    # 0 transparent
	Color("#0d0a14"), Color("#2a2438"), Color("#4a4458"),
	Color("#7a7488"), Color("#b0aac0"), Color("#f0ecf8"),                 # 1-6 greys
	Color("#5a2a18"), Color("#8a4a24"), Color("#c07840"),                 # 7-9 browns
	Color("#f0c090"), Color("#d09860"), Color("#a06840"),                 # 10-12 skin
	Color("#782818"), Color("#c03828"), Color("#f06848"),                 # 13-15 reds
	Color("#e8a020"), Color("#f0d040"), Color("#f8f0a0"),                 # 16-18 yellows
	Color("#285018"), Color("#3a8828"), Color("#78d048"),                 # 19-21 greens
	Color("#103858"), Color("#2068a8"), Color("#50b0e8"), Color("#a8e0f8"),# 22-25 blues
	Color("#302060"), Color("#6038a0"), Color("#a878e0"),                 # 26-28 purples
	Color("#501838"), Color("#a03878"), Color("#e878b0"),                 # 29-31 magentas
]

const PRESETS := [
	{"name": "Wanderer",    "opts": {"skin": 10, "skinD": 11, "hair": 7,  "shirt": 23, "shirtD": 22, "pants": 2,  "shoe": 1, "belt": 8}},
	{"name": "Firebrand",   "opts": {"skin": 11, "skinD": 12, "hair": 13, "shirt": 14, "shirtD": 13, "pants": 7,  "shoe": 1, "hairStyle": "tall"}},
	{"name": "Greenhand",   "opts": {"skin": 10, "skinD": 11, "hair": 19, "shirt": 20, "shirtD": 19, "pants": 7,  "shoe": 8, "hairLong": true}},
	{"name": "Tidecaller",  "opts": {"skin": 10, "skinD": 11, "hair": 22, "shirt": 24, "shirtD": 23, "pants": 22, "shoe": 2, "hairLong": true, "hairStyle": "fringe"}},
	{"name": "Sparkwright", "opts": {"skin": 11, "skinD": 12, "hair": 17, "shirt": 16, "shirtD": 8,  "pants": 2,  "shoe": 1, "vest": 3}},
	{"name": "Stonewalk",   "opts": {"skin": 12, "skinD": 7,  "hair": 4,  "shirt": 9,  "shirtD": 8,  "pants": 3,  "shoe": 1, "hat": 8, "hatBand": 13}},
	{"name": "Nightjar",    "opts": {"skin": 11, "skinD": 12, "hair": 1,  "shirt": 27, "shirtD": 26, "pants": 26, "shoe": 1, "hairLong": true}},
	{"name": "Snowfinch",   "opts": {"skin": 10, "skinD": 11, "hair": 5,  "shirt": 25, "shirtD": 24, "pants": 4,  "shoe": 3, "hairStyle": "fringe"}},
]

## The palette index used for a figure's outline. Lifted out of build() because
## "is there anything inside this outline" is a question worth asking elsewhere.
const OUTLINE := 1

const NPC_LOOKS := {
	"oldman":   {"skin": 11, "skinD": 12, "hair": 5, "shirt": 4,  "shirtD": 3,  "pants": 3,  "shoe": 1, "hairLong": true},
	"kid":      {"skin": 10, "skinD": 11, "hair": 8, "shirt": 17, "shirtD": 16, "pants": 23, "shoe": 1},
	"woman":    {"skin": 10, "skinD": 11, "hair": 7, "shirt": 20, "shirtD": 19, "pants": 26, "shoe": 1, "hairLong": true},
	"shopkeep": {"skin": 11, "skinD": 12, "hair": 2, "shirt": 5,  "shirtD": 4,  "pants": 2,  "shoe": 1, "vest": 8},
	"preacher": {"skin": 10, "skinD": 11, "hair": 1, "shirt": 2,  "shirtD": 1,  "pants": 1,  "shoe": 1},
	"miner":    {"skin": 12, "skinD": 7,  "hair": 2, "shirt": 22, "shirtD": 22, "pants": 3,  "shoe": 1, "hat": 16},
	"drifter":  {"skin": 11, "skinD": 12, "hair": 7, "shirt": 9,  "shirtD": 8,  "pants": 7,  "shoe": 1, "hat": 8},
	# Five towns wearing the same seven faces reads as one town copied five times.
	"miller":   {"skin": 10, "skinD": 11, "hair": 5, "shirt": 6,  "shirtD": 5,  "pants": 4,  "shoe": 2, "vest": 4},
	"ferry":    {"skin": 12, "skinD": 7,  "hair": 2, "shirt": 23, "shirtD": 22, "pants": 7,  "shoe": 1, "hat": 4},
	"widow":    {"skin": 11, "skinD": 12, "hair": 4, "shirt": 2,  "shirtD": 1,  "pants": 1,  "shoe": 1, "hairLong": true},
	"smith":    {"skin": 12, "skinD": 7,  "hair": 1, "shirt": 13, "shirtD": 13, "pants": 3,  "shoe": 1, "vest": 7},
	"girl":     {"skin": 10, "skinD": 11, "hair": 16, "shirt": 30, "shirtD": 29, "pants": 26, "shoe": 1, "hairLong": true, "hairStyle": "fringe"},
}


## Each palette entry's neighbours within its own colour ramp, so a sprite can
## be shaded without introducing colours that are not in the palette.
const DARKER := {
	2: 1, 3: 2, 4: 3, 5: 4, 6: 5,
	8: 7, 9: 8,
	10: 11, 11: 12,
	14: 13, 15: 14,
	17: 16, 18: 17,
	20: 19, 21: 20,
	23: 22, 24: 23, 25: 24,
	27: 26, 28: 27,
	30: 29, 31: 30,
}
const LIGHTER := {
	1: 2, 2: 3, 3: 4, 4: 5, 5: 6,
	7: 8, 8: 9,
	12: 11, 11: 10,
	13: 14, 14: 15,
	16: 17, 17: 18,
	19: 20, 20: 21,
	22: 23, 23: 24, 24: 25,
	26: 27, 27: 28,
	29: 30, 30: 31,
}


## Light from the top left, same as the tiles. A pixel with empty space or
## outline to its left catches the light; one with empty space to its right
## falls away. Cheap, and it turns flat fills into something with volume.
static func shade(g: PackedByteArray) -> PackedByteArray:
	var out := g.duplicate()
	for y in H:
		for x in W:
			var v := get_px(g, x, y)
			if v == 0 or v == 1:
				continue
			var left := get_px(g, x - 1, y)
			var right := get_px(g, x + 1, y)
			var up := get_px(g, x, y - 1)
			if (left == 0 or left == 1) and LIGHTER.has(v):
				out[y * W + x] = LIGHTER[v]
			elif (right == 0 or right == 1) and DARKER.has(v):
				out[y * W + x] = DARKER[v]
			elif (up == 0 or up == 1) and LIGHTER.has(v):
				out[y * W + x] = LIGHTER[v]
	return out


static func blank() -> PackedByteArray:
	var g := PackedByteArray()
	g.resize(W * H)
	g.fill(0)
	return g

static func get_px(g: PackedByteArray, x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= W or y >= H:
		return 0
	return g[y * W + x]

static func set_px(g: PackedByteArray, x: int, y: int, v: int) -> void:
	if x >= 0 and y >= 0 and x < W and y < H:
		g[y * W + x] = v


## Procedural sprite builder. Used for the eight presets, the NPCs and the
## editor's starting templates, so "draw your own" and "pick one" share a look.
##
## Proportions follow the 16-bit JRPG convention rather than realism: the head
## is nearly a third of the figure, because at this size a realistic head is
## four pixels wide and cannot hold a face.
static func build(o: Dictionary) -> PackedByteArray:
	var s := blank()
	const OUT := 1
	var skin: int = o.get("skin", 10)
	var skin_d: int = o.get("skinD", 11)
	var hair: int = o.get("hair", 7)
	var shirt: int = o.get("shirt", 23)
	var shirt_d: int = o.get("shirtD", 22)
	var pants: int = o.get("pants", 2)
	var shoe: int = o.get("shoe", 1)
	var outline_only: bool = o.get("outlineOnly", false)
	var long_hair: bool = o.get("hairLong", false)
	var style: String = o.get("hairStyle", "")

	var fill := func(x0: int, y0: int, x1: int, y1: int, v: int) -> void:
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				set_px(s, x, y, v)

	# ---- head: rows 4-21, a good third of the figure ----
	fill.call(9, 4, 22, 21, skin)
	fill.call(8, 7, 8, 17, skin)          # cheeks
	fill.call(23, 7, 23, 17, skin)
	# the jaw narrows toward the chin; as wide at the chin as at the temples
	# reads as a box with a face drawn on it
	fill.call(9, 19, 9, 21, 0)
	fill.call(22, 19, 22, 21, 0)
	fill.call(10, 21, 10, 21, 0)
	fill.call(21, 21, 21, 21, 0)
	fill.call(10, 19, 21, 21, skin_d)     # under the jaw
	fill.call(13, 22, 18, 23, skin_d)     # neck

	if not outline_only:
		# Eyes with parts: a white, an iris sitting low in it, a lash line over
		# the top and one pixel of catchlight. The catchlight is the difference
		# between a face and a face painted on.
		fill.call(11, 12, 14, 15, 6)
		fill.call(17, 12, 20, 15, 6)
		fill.call(12, 13, 14, 15, 22)     # iris
		fill.call(17, 13, 19, 15, 22)
		fill.call(13, 14, 13, 15, 1)      # pupil
		fill.call(18, 14, 18, 15, 1)
		fill.call(12, 13, 12, 13, 6)      # catchlight
		fill.call(17, 13, 17, 13, 6)
		fill.call(11, 11, 14, 11, OUT)    # lashes
		fill.call(17, 11, 20, 11, OUT)
		fill.call(11, 9, 14, 9, skin_d)   # brows
		fill.call(17, 9, 20, 9, skin_d)
		fill.call(15, 15, 16, 17, skin_d) # nose
		fill.call(15, 16, 15, 16, 0)
		fill.call(13, 19, 18, 19, skin_d) # mouth
		fill.call(14, 19, 17, 19, 13)

	# ---- hair ----
	if style != "bald":
		# The crown only, stopping above the brows. Taken down to row 8 across
		# the full width it swallowed the face and the figure became a haircut
		# with legs.
		fill.call(9, 2, 22, 7, hair)
		fill.call(10, 0, 21, 1, hair)
		fill.call(8, 4, 8, 11, hair)      # sideburns, short
		fill.call(23, 4, 23, 11, hair)
		fill.call(9, 8, 12, 8, hair)      # a little fringe at the temples
		fill.call(19, 8, 22, 8, hair)
		if not outline_only:
			# a little shade under the fringe at the temples -- across the whole
			# brow it only makes the face murky
			fill.call(9, 9, 11, 9, DARKER.get(skin, skin_d))
			fill.call(20, 9, 22, 9, DARKER.get(skin, skin_d))
			var hair_lit: int = LIGHTER.get(hair, hair)
			fill.call(11, 2, 17, 3, hair_lit)
			fill.call(9, 4, 13, 5, hair_lit)
			fill.call(8, 5, 8, 8, hair_lit)
		if style == "fringe":
			fill.call(9, 8, 22, 10, hair)
		if style == "tall":
			fill.call(11, 0, 20, 1, hair)
			fill.call(14, 0, 18, 0, hair)
		if long_hair:
			fill.call(6, 6, 8, 30, hair)
			fill.call(23, 6, 25, 30, hair)
			fill.call(6, 30, 9, 32, hair)
			fill.call(22, 30, 25, 32, hair)
	if o.has("hat"):
		fill.call(5, 3, 26, 7, o.get("hat"))
		fill.call(10, 0, 21, 3, o.get("hat"))
		fill.call(5, 7, 26, 7, o.get("hatBand", o.get("hat")))

	# ---- torso: rows 24-37 ----
	fill.call(9, 24, 22, 37, shirt)
	fill.call(9, 24, 10, 24, 0)           # shoulders slope rather than square
	fill.call(21, 24, 22, 24, 0)
	fill.call(11, 24, 20, 25, LIGHTER.get(shirt, shirt))
	fill.call(9, 34, 22, 37, shirt_d)     # hem in shadow
	fill.call(15, 24, 16, 37, shirt_d)    # a fold down the middle
	if not outline_only:
		# where the sleeve meets the body; nothing across the chest, which reads
		# as a pair of braces
		fill.call(11, 26, 11, 31, shirt_d)
		fill.call(20, 26, 20, 31, shirt_d)
	if o.has("vest"):
		fill.call(11, 24, 13, 36, o.get("vest"))
		fill.call(18, 24, 20, 36, o.get("vest"))
	if o.has("belt"):
		fill.call(9, 35, 22, 37, o.get("belt"))

	# ---- arms ----
	fill.call(5, 25, 8, 36, shirt)
	fill.call(23, 25, 26, 36, shirt)
	fill.call(5, 34, 8, 36, shirt_d)
	fill.call(23, 34, 26, 36, shirt_d)
	fill.call(5, 37, 8, 40, skin)         # hands
	fill.call(23, 37, 26, 40, skin)

	# ---- legs ----
	fill.call(11, 38, 20, 45, pants)
	if not outline_only:
		fill.call(15, 40, 16, 45, 0)      # daylight between the legs
		fill.call(14, 40, 14, 45, DARKER.get(pants, pants))
		fill.call(17, 40, 17, 45, DARKER.get(pants, pants))
	fill.call(11, 45, 20, 45, DARKER.get(pants, pants))
	fill.call(10, 46, 14, 47, shoe)
	fill.call(17, 46, 21, 47, shoe)
	if not outline_only:
		fill.call(10, 46, 14, 46, LIGHTER.get(shoe, shoe))
		fill.call(17, 46, 21, 46, LIGHTER.get(shoe, shoe))

	# outline pass: any empty pixel touching a filled one becomes outline
	var src := s.duplicate()
	for y in H:
		for x in W:
			if src[y * W + x] != 0:
				continue
			if get_px(src, x - 1, y) != 0 or get_px(src, x + 1, y) != 0 \
					or get_px(src, x, y - 1) != 0 or get_px(src, x, y + 1) != 0:
				set_px(s, x, y, OUT)
	if outline_only:
		for i in s.size():
			if s[i] != OUT:
				s[i] = 0
		return s
	return shade(s)


## One step of the automatic walk, baked into a grid.
##
## The game animates an undrawn walk by shifting pixels as it draws. This does
## the same shift into a new grid instead, so the editor can show what the
## automatic frame looks like -- and so somebody can start from it and change
## the bits they do not like rather than from a blank canvas.
static func walk_frame(g: PackedByteArray, frame: int, facing: int) -> PackedByteArray:
	var out := blank()
	var bob := 1 if (frame % 4 == 1 or frame % 4 == 3) else 0
	var leg := UI.STRIDE if frame % 4 == 1 else (-UI.STRIDE if frame % 4 == 3 else 0)
	for y in H:
		for x in W:
			var v := get_px(g, x, y)
			if v == 0:
				continue
			var off := UI.walk_offset(x, y, leg, bob, facing)
			set_px(out, x + off.x, y + off.y, v)
	return out


## Flip a grid left to right.
static func mirrored(s: PackedByteArray) -> PackedByteArray:
	var m := blank()
	for y in H:
		for x in W:
			set_px(m, W - 1 - x, y, get_px(s, x, y))
	return m


## The commonest real colour in a patch, used to read a palette back out of a
## drawing. Outline and empty do not count.
static func _common(s: PackedByteArray, x0: int, y0: int, x1: int, y1: int) -> int:
	var tally := {}
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var v := get_px(s, x, y)
			if v != 0 and v != OUTLINE:
				tally[v] = tally.get(v, 0) + 1
	var best := 0
	var got := 0
	for k in tally:
		if tally[k] > best:
			best = tally[k]
			got = k
	return got


## Draw the figure in profile, facing right, in the colours of the drawing it is
## given. The field flips it for facing left.
static func side_view(s: PackedByteArray) -> PackedByteArray:
	var hair := _common(s, 8, 2, 23, 6)
	var skin := _common(s, 12, 10, 19, 17)
	var skin_d := _common(s, 11, 19, 20, 21)
	var shirt := _common(s, 12, 27, 20, 33)
	var shirt_d := _common(s, 10, 35, 21, 37)
	var pants := _common(s, 12, 40, 19, 45)
	var shoe := _common(s, 11, 46, 20, 47)
	if skin == 0:
		skin = _common(s, 8, 4, 23, 21)
	if skin == 0:
		return s.duplicate()
	if skin_d == 0:
		skin_d = skin
	if shirt == 0:
		shirt = _common(s, 9, 24, 22, 37)
	if shirt_d == 0:
		shirt_d = shirt
	if pants == 0:
		pants = shirt_d
	if shoe == 0:
		shoe = pants
	if hair == 0:
		hair = skin_d

	var b := blank()
	var fill := func(x0: int, y0: int, x1: int, y1: int, v: int) -> void:
		if v == 0:
			return
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				set_px(b, x, y, v)

	# head, narrower than the front and pushed forward
	fill.call(11, 4, 22, 21, skin)
	fill.call(12, 19, 22, 21, skin_d)
	fill.call(23, 12, 23, 15, skin)          # the nose, which is the whole tell
	fill.call(11, 2, 21, 9, hair)            # crown and the back of the head
	fill.call(10, 5, 11, 18, hair)
	fill.call(12, 4, 17, 12, hair)           # fringe over the near eye
	fill.call(19, 12, 21, 14, 6)             # one eye, the other is behind
	fill.call(20, 13, 21, 14, 22)
	fill.call(19, 11, 21, 11, 1)
	fill.call(20, 18, 22, 18, skin_d)        # mouth line
	fill.call(15, 22, 19, 23, skin_d)        # neck

	# body, about half the width of the front view
	fill.call(13, 24, 21, 37, shirt)
	fill.call(13, 34, 21, 37, shirt_d)
	# the near arm, hanging a little forward
	fill.call(18, 25, 22, 36, shirt)
	fill.call(18, 34, 22, 36, shirt_d)
	fill.call(18, 37, 22, 40, skin)

	# legs together, and the feet point the way the figure is facing
	fill.call(13, 38, 20, 45, pants)
	fill.call(14, 46, 23, 47, shoe)
	fill.call(12, 46, 14, 47, shoe)

	# outline, then the same shading the front view gets
	var src := b.duplicate()
	for y in H:
		for x in W:
			if src[y * W + x] != 0:
				continue
			if get_px(src, x - 1, y) != 0 or get_px(src, x + 1, y) != 0 \
					or get_px(src, x, y - 1) != 0 or get_px(src, x, y + 1) != 0:
				set_px(b, x, y, OUTLINE)
	return shade(b)


## Derive a back view so the character does not stare at you while walking away:
## the face area is filled with whatever colour the hair is.
static func back_view(s: PackedByteArray) -> PackedByteArray:
	var b := s.duplicate()
	var tally := {}
	for y in range(2, 8):
		for x in range(8, 24):
			var v := get_px(s, x, y)
			if v != 0 and v != 1:
				tally[v] = tally.get(v, 0) + 1
	var hair := 0
	var best := 0
	for k in tally:
		if tally[k] > best:
			best = tally[k]
			hair = k
	if hair == 0:
		return b
	# Fill the interior of the head with hair, but leave pixels that sit on the
	# silhouette edge alone so the outline survives. Filling by colour instead
	# would keep the eyes, which are drawn in the outline colour -- the back of
	# a head should not be looking at you.
	for y in range(4, 22):
		for x in W:
			var v := get_px(s, x, y)
			if v == 0:
				continue
			var on_edge := get_px(s, x - 1, y) == 0 or get_px(s, x + 1, y) == 0 \
					or get_px(s, x, y - 1) == 0 or get_px(s, x, y + 1) == 0
			if not on_edge:
				set_px(b, x, y, hair)
	return b


static func to_image(g: PackedByteArray) -> Image:
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	for y in H:
		for x in W:
			img.set_pixel(x, y, PALETTE[g[y * W + x]])
	return img

static func to_texture(g: PackedByteArray) -> ImageTexture:
	return ImageTexture.create_from_image(to_image(g))


static func flood_fill(g: PackedByteArray, x: int, y: int, to: int) -> void:
	var from := get_px(g, x, y)
	if from == to:
		return
	var stack := [Vector2i(x, y)]
	var guard := 0
	while stack.size() > 0 and guard < 2000:
		guard += 1
		var p: Vector2i = stack.pop_back()
		if p.x < 0 or p.y < 0 or p.x >= W or p.y >= H:
			continue
		if g[p.y * W + p.x] != from:
			continue
		g[p.y * W + p.x] = to
		stack.append(Vector2i(p.x + 1, p.y))
		stack.append(Vector2i(p.x - 1, p.y))
		stack.append(Vector2i(p.x, p.y + 1))
		stack.append(Vector2i(p.x, p.y - 1))
