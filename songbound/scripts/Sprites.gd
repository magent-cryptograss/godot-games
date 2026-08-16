class_name Sprites
extends RefCounted
## Player sprites are a 16x24 grid of palette indices, index 0 transparent.
## The same format is used by the editor, the presets and the field renderer,
## so anything you can draw, the game can animate.

const W := 16
const H := 24

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

const NPC_LOOKS := {
	"oldman":   {"skin": 11, "skinD": 12, "hair": 5, "shirt": 4,  "shirtD": 3,  "pants": 3,  "shoe": 1, "hairLong": true},
	"kid":      {"skin": 10, "skinD": 11, "hair": 8, "shirt": 17, "shirtD": 16, "pants": 23, "shoe": 1},
	"woman":    {"skin": 10, "skinD": 11, "hair": 7, "shirt": 20, "shirtD": 19, "pants": 26, "shoe": 1, "hairLong": true},
	"shopkeep": {"skin": 11, "skinD": 12, "hair": 2, "shirt": 5,  "shirtD": 4,  "pants": 2,  "shoe": 1, "vest": 8},
	"preacher": {"skin": 10, "skinD": 11, "hair": 1, "shirt": 2,  "shirtD": 1,  "pants": 1,  "shoe": 1},
	"miner":    {"skin": 12, "skinD": 7,  "hair": 2, "shirt": 22, "shirtD": 22, "pants": 3,  "shoe": 1, "hat": 16},
	"drifter":  {"skin": 11, "skinD": 12, "hair": 7, "shirt": 9,  "shirtD": 8,  "pants": 7,  "shoe": 1, "hat": 8},
}


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


## Procedural builder, shared by the eight presets, the NPCs and the editor's
## starting templates, so "draw your own" and "pick one" share a look.
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

	var fill := func(x0: int, y0: int, x1: int, y1: int, v: int) -> void:
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				set_px(s, x, y, v)

	# head
	fill.call(5, 3, 10, 9, skin)
	fill.call(5, 9, 10, 9, skin_d)
	if not outline_only:
		set_px(s, 6, 6, OUT)
		set_px(s, 9, 6, OUT)
	fill.call(7, 8, 8, 8, skin_d)
	# hair
	if o.get("hairStyle", "") != "bald":
		fill.call(4, 1, 11, 2, hair)
		var hair_bottom: int = 8 if o.get("hairLong", false) else 5
		fill.call(4, 3, 4, hair_bottom, hair)
		fill.call(11, 3, 11, hair_bottom, hair)
		if o.get("hairStyle", "") == "fringe":
			fill.call(5, 3, 10, 3, hair)
		if o.get("hairStyle", "") == "tall":
			fill.call(5, 0, 10, 0, hair)
	if o.has("hat"):
		fill.call(3, 1, 12, 2, o.hat)
		fill.call(5, 0, 10, 0, o.hat)
		fill.call(3, 2, 12, 2, o.get("hatBand", o.hat))
	# torso
	fill.call(4, 10, 11, 16, shirt)
	fill.call(4, 15, 11, 16, shirt_d)
	if o.has("belt"):
		fill.call(4, 16, 11, 16, o.belt)
	if o.has("vest"):
		fill.call(5, 10, 6, 15, o.vest)
		fill.call(9, 10, 10, 15, o.vest)
	# arms
	fill.call(2, 11, 3, 15, shirt)
	fill.call(12, 11, 13, 15, shirt)
	fill.call(2, 16, 3, 17, skin)
	fill.call(12, 16, 13, 17, skin)
	# legs
	fill.call(5, 17, 7, 21, pants)
	fill.call(8, 17, 10, 21, pants)
	fill.call(5, 22, 7, 23, shoe)
	fill.call(8, 22, 10, 23, shoe)

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


## Derive a back view so the character does not stare at you while walking away:
## the face area is filled with whatever colour the hair is.
static func back_view(s: PackedByteArray) -> PackedByteArray:
	var b := s.duplicate()
	var tally := {}
	for y in range(1, 4):
		for x in range(3, 13):
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
	for y in range(3, 10):
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
