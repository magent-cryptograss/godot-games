class_name Sprites
extends RefCounted
## Player sprites are a 24x32 grid of palette indices, index 0 transparent.
## The same format is used by the editor, the presets and the field renderer,
## so anything you can draw, the game can animate.

## Characters are 32 wide and 48 tall -- one tile across and a tile and a half
## up, against 32-pixel tiles. At 24x32 the figure was smaller than a single
## tile and less detailed than the ground it stood on.
const W := 48
const H := 72

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

	# ---- head: rows 6-32, a good third of the figure ----
	fill.call(13, 6, 34, 32, skin)
	fill.call(12, 11, 12, 26, skin)       # cheeks
	fill.call(35, 11, 35, 26, skin)
	# the jaw narrows toward the chin; as wide at the chin as at the temples
	# reads as a box with a face drawn on it
	fill.call(13, 29, 13, 32, 0)
	fill.call(34, 29, 34, 32, 0)
	fill.call(14, 31, 15, 32, 0)
	fill.call(32, 31, 33, 32, 0)
	fill.call(15, 29, 32, 32, skin_d)     # under the jaw
	fill.call(19, 33, 28, 35, skin_d)     # neck
	if not outline_only:
		fill.call(19, 33, 28, 33, DARKER.get(skin_d, skin_d))   # shade under the chin

	if not outline_only:
		# Eyes with every part: a white, an iris, a pupil inside it, a lash line
		# over the top and one pixel of catchlight. At 32x48 there was room for
		# a white and an iris and that was all.
		fill.call(16, 18, 21, 23, 6)
		fill.call(26, 18, 31, 23, 6)
		fill.call(17, 19, 21, 23, 22)     # iris
		fill.call(26, 19, 30, 23, 22)
		fill.call(18, 20, 20, 23, 1)      # pupil
		fill.call(27, 20, 29, 23, 1)
		fill.call(17, 19, 18, 20, 6)      # catchlight
		fill.call(26, 19, 27, 20, 6)
		fill.call(16, 16, 21, 17, OUT)    # lashes
		fill.call(26, 16, 31, 17, OUT)
		fill.call(16, 13, 21, 14, skin_d) # brows
		fill.call(26, 13, 31, 14, skin_d)
		fill.call(22, 22, 25, 26, skin_d) # nose
		fill.call(22, 22, 23, 24, 0)
		fill.call(19, 28, 28, 29, skin_d) # mouth
		fill.call(21, 28, 26, 28, 13)

	# ---- hair ----
	if style != "bald":
		# the crown only, stopping above the brows
		fill.call(13, 3, 34, 11, hair)
		fill.call(15, 0, 32, 2, hair)
		fill.call(12, 6, 12, 17, hair)    # sideburns, short
		fill.call(35, 6, 35, 17, hair)
		fill.call(13, 12, 18, 12, hair)   # a little fringe at the temples
		fill.call(29, 12, 34, 12, hair)
		if not outline_only:
			fill.call(13, 13, 15, 13, DARKER.get(skin, skin_d))
			fill.call(32, 13, 34, 13, DARKER.get(skin, skin_d))
			var hair_lit: int = LIGHTER.get(hair, hair)
			fill.call(16, 3, 26, 5, hair_lit)
			fill.call(13, 6, 20, 8, hair_lit)
			fill.call(12, 8, 12, 13, hair_lit)
		if style == "fringe":
			fill.call(13, 12, 34, 15, hair)
		if style == "tall":
			fill.call(16, 0, 31, 2, hair)
			fill.call(21, 0, 27, 0, hair)
		if long_hair:
			fill.call(9, 9, 12, 45, hair)
			fill.call(35, 9, 38, 45, hair)
			fill.call(9, 45, 14, 48, hair)
			fill.call(33, 45, 38, 48, hair)
	if o.has("hat"):
		fill.call(8, 5, 39, 11, o.get("hat"))
		fill.call(15, 0, 32, 5, o.get("hat"))
		fill.call(8, 11, 39, 11, o.get("hatBand", o.get("hat")))

	# ---- torso: rows 36-56 ----
	fill.call(13, 36, 34, 56, shirt)
	fill.call(13, 36, 15, 36, 0)          # shoulders slope rather than square
	fill.call(32, 36, 34, 36, 0)
	fill.call(16, 36, 31, 38, LIGHTER.get(shirt, shirt))
	fill.call(13, 51, 34, 56, shirt_d)    # hem in shadow
	fill.call(22, 36, 25, 56, shirt_d)    # a fold down the middle
	if not outline_only:
		fill.call(16, 39, 17, 47, shirt_d)   # where the sleeve meets the body
		fill.call(30, 39, 31, 47, shirt_d)
		fill.call(19, 44, 20, 49, shirt_d)   # a crease where cloth gathers
		fill.call(27, 46, 28, 51, shirt_d)
	if o.has("vest"):
		fill.call(16, 36, 20, 54, o.get("vest"))
		fill.call(27, 36, 31, 54, o.get("vest"))
	if o.has("belt"):
		fill.call(13, 53, 34, 56, o.get("belt"))

	# ---- arms ----
	fill.call(7, 38, 12, 54, shirt)
	fill.call(35, 38, 40, 54, shirt)
	fill.call(7, 51, 12, 54, shirt_d)
	fill.call(35, 51, 40, 54, shirt_d)
	fill.call(7, 55, 12, 60, skin)        # hands
	fill.call(35, 55, 40, 60, skin)
	if not outline_only:
		fill.call(7, 55, 12, 56, LIGHTER.get(skin, skin))

	# ---- legs ----
	fill.call(16, 57, 31, 68, pants)
	if not outline_only:
		fill.call(22, 60, 25, 68, 0)      # daylight between the legs
		fill.call(20, 60, 21, 68, DARKER.get(pants, pants))
		fill.call(26, 60, 27, 68, DARKER.get(pants, pants))
	fill.call(16, 67, 31, 68, DARKER.get(pants, pants))
	fill.call(14, 69, 21, 71, shoe)
	fill.call(26, 69, 33, 71, shoe)
	if not outline_only:
		fill.call(14, 69, 21, 69, LIGHTER.get(shoe, shoe))
		fill.call(26, 69, 33, 69, LIGHTER.get(shoe, shoe))

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
	var hair := _common(s, 13, 3, 34, 9)
	var skin := _common(s, 18, 15, 29, 26)
	var skin_d := _common(s, 17, 29, 30, 32)
	var shirt := _common(s, 18, 40, 30, 50)
	var shirt_d := _common(s, 15, 52, 32, 56)
	var pants := _common(s, 18, 60, 29, 68)
	var shoe := _common(s, 16, 69, 31, 71)
	if skin == 0:
		skin = _common(s, 12, 6, 35, 32)
	if skin == 0:
		return s.duplicate()
	if skin_d == 0:
		skin_d = skin
	if shirt == 0:
		shirt = _common(s, 13, 36, 34, 56)
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
	fill.call(17, 6, 34, 32, skin)
	fill.call(18, 29, 34, 32, skin_d)
	fill.call(35, 18, 35, 23, skin)          # the nose, which is the whole tell
	fill.call(17, 3, 32, 14, hair)           # crown and the back of the head
	fill.call(15, 8, 17, 28, hair)
	fill.call(18, 6, 26, 18, hair)           # fringe over the near eye
	fill.call(29, 18, 32, 22, 6)             # one eye, the other is behind
	fill.call(30, 19, 32, 22, 22)
	fill.call(31, 20, 32, 22, 1)
	fill.call(29, 16, 32, 17, 1)
	fill.call(30, 27, 34, 28, skin_d)        # mouth line
	fill.call(23, 33, 29, 35, skin_d)        # neck

	# body, about half the width of the front view
	fill.call(20, 36, 32, 56, shirt)
	fill.call(20, 51, 32, 56, shirt_d)
	# the near arm, hanging a little forward
	fill.call(27, 38, 34, 54, shirt)
	fill.call(27, 51, 34, 54, shirt_d)
	fill.call(27, 55, 34, 60, skin)

	# legs together, and the feet point the way the figure is facing
	fill.call(20, 57, 31, 68, pants)
	fill.call(21, 69, 35, 71, shoe)
	fill.call(18, 69, 21, 71, shoe)

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
	for y in range(3, 12):
		for x in range(12, 36):
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
	for y in range(6, 33):
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
