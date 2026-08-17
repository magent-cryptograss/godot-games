class_name Sprites
extends RefCounted
## Player sprites are a 24x32 grid of palette indices, index 0 transparent.
## The same format is used by the editor, the presets and the field renderer,
## so anything you can draw, the game can animate.

const W := 24
const H := 32

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

	# ---- head: rows 3-15, a good third of the figure ----
	fill.call(7, 3, 16, 14, skin)
	fill.call(6, 5, 6, 12, skin)          # cheeks
	fill.call(17, 5, 17, 12, skin)
	fill.call(7, 13, 16, 14, skin_d)      # under the jaw
	fill.call(8, 15, 15, 15, skin_d)      # neck

	if not outline_only:
		# eyes: white, pupil, and a lash line above -- the whole reason for 24x32
		fill.call(9, 8, 10, 9, 6)
		fill.call(13, 8, 14, 9, 6)
		fill.call(9, 8, 9, 8, OUT)
		fill.call(13, 8, 13, 8, OUT)
		fill.call(9, 9, 10, 9, 22)
		fill.call(13, 9, 14, 9, 22)
		fill.call(9, 7, 10, 7, OUT)
		fill.call(13, 7, 14, 7, OUT)
		fill.call(11, 10, 12, 11, skin_d)  # nose
		fill.call(10, 12, 13, 12, skin_d)  # mouth line
		fill.call(11, 12, 12, 12, 13)

	# ---- hair ----
	if style != "bald":
		fill.call(6, 1, 17, 4, hair)
		fill.call(7, 0, 16, 0, hair)
		fill.call(5, 3, 5, 9, hair)        # sideburns down each side
		fill.call(18, 3, 18, 9, hair)
		if style == "fringe":
			fill.call(7, 5, 16, 6, hair)
			fill.call(8, 7, 11, 7, hair)
		if style == "tall":
			fill.call(8, -2 + 2, 15, 0, hair)
			fill.call(10, 0, 13, 0, hair)
		if long_hair:
			fill.call(4, 4, 5, 18, hair)
			fill.call(18, 4, 19, 18, hair)
			fill.call(4, 18, 6, 19, hair)
			fill.call(17, 18, 19, 19, hair)
	if o.has("hat"):
		fill.call(4, 2, 19, 4, o.get("hat"))
		fill.call(7, 0, 16, 2, o.get("hat"))
		fill.call(4, 4, 19, 4, o.get("hatBand", o.get("hat")))

	# ---- torso: rows 16-25 ----
	fill.call(7, 16, 16, 25, shirt)
	fill.call(7, 23, 16, 25, shirt_d)      # hem in shadow
	fill.call(11, 16, 12, 25, shirt_d)     # a fold down the middle
	if o.has("vest"):
		fill.call(8, 16, 9, 24, o.get("vest"))
		fill.call(14, 16, 15, 24, o.get("vest"))
	if o.has("belt"):
		fill.call(7, 24, 16, 25, o.get("belt"))

	# ---- arms ----
	fill.call(4, 17, 6, 24, shirt)
	fill.call(17, 17, 19, 24, shirt)
	fill.call(4, 23, 6, 24, shirt_d)
	fill.call(17, 23, 19, 24, shirt_d)
	fill.call(4, 25, 6, 27, skin)          # hands
	fill.call(17, 25, 19, 27, skin)

	# ---- legs ----
	fill.call(8, 26, 11, 30, pants)
	fill.call(12, 26, 15, 30, pants)
	fill.call(11, 26, 12, 30, pants)
	fill.call(8, 31, 11, 31, shoe)
	fill.call(12, 31, 15, 31, shoe)
	fill.call(7, 31, 7, 31, shoe)
	fill.call(16, 31, 16, 31, shoe)

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
	var hair := _common(s, 6, 1, 17, 4)
	var skin := _common(s, 9, 7, 14, 11)
	var skin_d := _common(s, 8, 13, 15, 14)
	var shirt := _common(s, 9, 18, 15, 22)
	var shirt_d := _common(s, 8, 24, 15, 25)
	var pants := _common(s, 9, 27, 14, 30)
	var shoe := _common(s, 8, 31, 15, 31)
	if skin == 0:
		skin = _common(s, 6, 3, 17, 14)
	if skin == 0:
		return s.duplicate()
	if skin_d == 0:
		skin_d = skin
	if shirt == 0:
		shirt = _common(s, 6, 16, 17, 25)
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
	fill.call(8, 3, 16, 14, skin)
	fill.call(9, 13, 16, 14, skin_d)
	fill.call(17, 8, 17, 10, skin)          # the nose, which is the whole tell
	fill.call(8, 2, 15, 6, hair)            # crown and the back of the head
	fill.call(7, 4, 8, 12, hair)
	fill.call(9, 3, 12, 8, hair)            # fringe over the near eye
	fill.call(14, 8, 15, 9, OUTLINE)        # one eye, since the other is behind
	fill.call(15, 8, 15, 8, 6)
	fill.call(14, 12, 16, 12, skin_d)       # mouth line
	fill.call(11, 15, 14, 15, skin_d)       # neck

	# body, half the width of the front view
	fill.call(10, 16, 15, 25, shirt)
	fill.call(10, 23, 15, 25, shirt_d)
	# the near arm, hanging a little forward
	fill.call(13, 17, 16, 24, shirt)
	fill.call(13, 23, 16, 24, shirt_d)
	fill.call(13, 25, 16, 27, skin)

	# legs together, and the feet point the way the figure is facing
	fill.call(10, 26, 14, 30, pants)
	fill.call(10, 31, 16, 31, shoe)
	fill.call(9, 31, 9, 31, shoe)

	# outline, then the same shading pass the front view gets
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
	for y in range(1, 5):
		for x in range(4, 20):
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
	for y in range(3, 16):
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
