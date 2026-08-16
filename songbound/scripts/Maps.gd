class_name Maps
extends RefCounted
## Maps are built in code rather than authored as TileSets: fewer moving parts,
## and the overworld is generated from a fixed seed so it is the same every run.
##
## Tiles are rendered into a small atlas once (four variants each, picked by a
## coordinate hash so a field of grass is not visibly tiled), then whole maps are
## composed with blit_rect, which is far faster than per-pixel work in GDScript.

const TS := 16

const SOLID := {
	"~": true, "T": true, "P": true, "^": true, "r": true, "%": true, "F": true,
	"#": true, "W": true, "R": true, "V": true, "X": true, "b": true, "c": true,
	"t": true, "p": true, "g": true, "S": true, "w": true, "m": true,
}
# How much a tile multiplies the encounter chance. Tall grass and cave floor
# were at 3, which put caves at a fight every seven steps.
const ENC := {".": 1, ",": 2, "\"": 1, "f": 1, "D": 2}

static var _atlas := {}


static func is_solid(ch: String) -> bool:
	return SOLID.get(ch, false)

static func enc_weight(ch: String) -> int:
	return ENC.get(ch, 0)


static func hash2(x: int, y: int) -> float:
	var h := x * 374761393 + y * 668265263
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(absi(h) % 100000) / 100000.0


# ------------------------------------------------------------------ atlas --

static func _fill(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(maxi(0, y), mini(TS, y + h)):
		for xx in range(maxi(0, x), mini(TS, x + w)):
			img.set_pixel(xx, yy, c)


static func _tile_image(ch: String, v: int) -> Image:
	var img := Image.create(TS, TS, false, Image.FORMAT_RGBA8)
	img.fill(Color("#3e7a42"))
	var r := func(i: int) -> float: return hash2(v * 31 + i, v * 17 + i * 7)
	match ch:
		".", "f":
			_fill(img, 0, 0, 16, 16, Color("#3e7a42"))
			_fill(img, 0, 0, 16, 1, Color("#4a8c4e"))
			for i in 5:
				_fill(img, int(r.call(i) * 15), int(r.call(i + 9) * 15), 1, 2,
					Color("#356a38") if r.call(i + 3) > 0.5 else Color("#529456"))
			if ch == "f":
				var fc: Color = [Color("#f0d040"), Color("#e878b0"), Color("#f0ecf8"), Color("#a878e0")][v % 4]
				_fill(img, 4, 5, 2, 2, fc)
				_fill(img, 10, 9, 2, 2, fc)
				_fill(img, 7, 12, 2, 2, fc)
		",":
			_fill(img, 0, 0, 16, 16, Color("#356a38"))
			for i in 12:
				_fill(img, int(r.call(i) * 15), int(r.call(i + 5) * 12) + 2, 1, 4,
					Color("#46803f") if i % 3 != 0 else Color("#2a5a2c"))
			_fill(img, 0, 15, 16, 1, Color("#28502a"))
		"\"":
			_fill(img, 0, 0, 16, 16, Color("#4a7a44"))
			for i in 7:
				_fill(img, int(r.call(i) * 14), int(r.call(i + 4) * 14), 2, 2, Color("#3c6638"))
		"=", "q":
			_fill(img, 0, 0, 16, 16, Color("#9a7c50") if ch == "=" else Color("#8a7048"))
			for i in 8:
				_fill(img, int(r.call(i) * 15), int(r.call(i + 6) * 15), 1, 1,
					Color("#b09468") if r.call(i + 2) > 0.5 else Color("#7e6440"))
		"o":
			_fill(img, 0, 0, 16, 16, Color("#8a8a86"))
			for a in 2:
				for b in 2:
					_fill(img, b * 8 + 1, a * 8 + 1, 6, 6,
						Color("#9a9a94") if hash2(v * 4 + b, a) > 0.5 else Color("#7e7e7a"))
		"B":
			_fill(img, 0, 0, 16, 16, Color("#2a5a90"))
			_fill(img, 0, 1, 16, 14, Color("#a07840"))
			for i in 5:
				_fill(img, 0, 1 + i * 3, 16, 1, Color("#7a5628"))
			_fill(img, 0, 0, 16, 1, Color("#c09858"))
			_fill(img, 0, 15, 16, 1, Color("#c09858"))
		"~":
			_fill(img, 0, 0, 16, 16, Color("#22528a"))
			_fill(img, 0, 0, 16, 8, Color("#2a5f9c"))
			for i in 3:
				_fill(img, int(r.call(i) * 12), int(r.call(i + 7) * 14), 3, 1, Color("#4a86bc"))
		"T":
			_fill(img, 0, 0, 16, 16, Color("#3e7a42"))
			_fill(img, 7, 10, 2, 6, Color("#5a3e22"))
			_disc(img, 8, 7, 6, Color("#255a2a"))
			_disc(img, 6, 5, 4, Color("#33753a"))
			_disc(img, 10, 8, 3, Color("#1d4a22"))
		"P":
			_fill(img, 0, 0, 16, 16, Color("#3e7a42"))
			_fill(img, 7, 12, 2, 4, Color("#4a3018"))
			for i in 4:
				var wd := 3 + i * 3
				_fill(img, 8 - (wd >> 1), 2 + i * 3, wd, 3,
					Color("#1c4a24") if i % 2 == 1 else Color("#26582e"))
			_fill(img, 7, 0, 2, 3, Color("#26582e"))
		"^":
			_fill(img, 0, 0, 16, 16, Color("#6a6258"))
			for i in range(1, 8):
				_fill(img, 8 - i, 1 + i * 2, i * 2, 2,
					Color("#e8e8f0") if i < 3 else (Color("#7a7268") if i % 2 == 1 else Color("#645c52")))
			_fill(img, 0, 14, 16, 2, Color("#4a443c"))
		"r":
			_fill(img, 0, 0, 16, 16, Color("#3e7a42"))
			_ellipse(img, 8, 10, 6, 5, Color("#7a7268"))
			_ellipse(img, 7, 8, 4, 3, Color("#948c80"))
			_fill(img, 3, 13, 10, 2, Color("#565046"))
		"%":
			_fill(img, 0, 0, 16, 16, Color("#3e7a42"))
			_disc(img, 8, 9, 6, Color("#255a2a"))
			_disc(img, 6, 7, 3, Color("#33753a"))
			if v % 2 == 0:
				_fill(img, 10, 10, 2, 2, Color("#c03828"))
				_fill(img, 5, 12, 2, 2, Color("#c03828"))
		"F":
			_fill(img, 0, 0, 16, 16, Color("#3e7a42"))
			_fill(img, 2, 4, 2, 11, Color("#7a5a34"))
			_fill(img, 11, 4, 2, 11, Color("#7a5a34"))
			_fill(img, 0, 6, 16, 2, Color("#8a6a40"))
			_fill(img, 0, 11, 16, 2, Color("#8a6a40"))
		"#":
			_fill(img, 0, 0, 16, 16, Color("#78706a"))
			for a in 4:
				var off := (a % 2) * 4
				for b in range(-1, 3):
					_fill(img, b * 8 + off + 1, a * 4 + 1, 6, 2,
						Color("#88807a") if hash2(v * 9 + b, a) > 0.5 else Color("#6a625c"))
		"W":
			_fill(img, 0, 0, 16, 16, Color("#8a6440"))
			for i in 4:
				_fill(img, 0, i * 4, 16, 1, Color("#6a4a2c"))
			_fill(img, 3, 2, 1, 2, Color("#a07a50"))
			_fill(img, 11, 10, 1, 2, Color("#a07a50"))
		"R":
			for a in 4:
				for b in 4:
					_fill(img, b * 4, a * 4, 4, 3,
						Color("#a04438") if (a + b) % 2 == 1 else Color("#7a3028"))
			_fill(img, 0, 0, 16, 1, Color("#c05848"))
		"V":
			_fill(img, 0, 0, 16, 16, Color("#6a2a24"))
			_fill(img, 0, 4, 16, 12, Color("#8a3830"))
			_fill(img, 0, 3, 16, 2, Color("#c05848"))
			_fill(img, 6, 8, 4, 8, Color("#4a1e18"))
		"d":
			_fill(img, 0, 0, 16, 16, Color("#8a6440"))
			_fill(img, 2, 2, 12, 14, Color("#5a3a1e"))
			_fill(img, 3, 3, 10, 13, Color("#71482a"))
			for i in 3:
				_fill(img, 3 + i * 4, 3, 1, 13, Color("#5a3a1e"))
			_fill(img, 11, 9, 2, 2, Color("#f0d040"))
		"_":
			_fill(img, 0, 0, 16, 16, Color("#9a7448"))
			for i in 4:
				_fill(img, 0, i * 4 + 3, 16, 1, Color("#7a5630"))
		"l":
			_fill(img, 0, 0, 16, 16, Color("#a09888"))
			for a in 2:
				for b in 2:
					_fill(img, b * 8 + 1, a * 8 + 1, 6, 6,
						Color("#b0a898") if (a + b) % 2 == 1 else Color("#948c7e"))
		"D", "*":
			_fill(img, 0, 0, 16, 16, Color("#5a4a52") if ch == "*" else Color("#3a2e38"))
			for i in 6:
				_fill(img, int(r.call(i) * 15), int(r.call(i + 8) * 15), 1, 1,
					Color("#4a3c46") if r.call(i + 2) > 0.5 else Color("#2e242c"))
		"X":
			_fill(img, 0, 0, 16, 16, Color("#221a20"))
			_ellipse(img, 8, 8, 8, 8, Color("#382c34"))
			_ellipse(img, 6, 6, 5, 4, Color("#483a44"))
			_fill(img, 0, 14, 16, 2, Color("#181218"))
		"b":
			_fill(img, 0, 0, 16, 16, Color("#9a7448"))
			_fill(img, 1, 1, 14, 14, Color("#c8c0b0"))
			_fill(img, 2, 2, 12, 4, Color("#e8e4dc"))
			_fill(img, 1, 8, 14, 7, Color("#8a4048"))
			_fill(img, 1, 8, 14, 1, Color("#a85058"))
		"c":
			_fill(img, 0, 0, 16, 16, Color("#9a7448"))
			_fill(img, 0, 3, 16, 10, Color("#7a5630"))
			_fill(img, 0, 2, 16, 2, Color("#b08a58"))
			_fill(img, 0, 12, 16, 1, Color("#5a3e20"))
		"t":
			_fill(img, 0, 0, 16, 16, Color("#9a7448"))
			_fill(img, 1, 3, 14, 9, Color("#8a5e34"))
			_fill(img, 1, 3, 14, 2, Color("#a87a48"))
			_fill(img, 3, 12, 2, 3, Color("#6a4626"))
			_fill(img, 11, 12, 2, 3, Color("#6a4626"))
		"p":
			_fill(img, 0, 0, 16, 16, Color("#9a7448"))
			_ellipse(img, 8, 9, 6, 6, Color("#7a5228"))
			_fill(img, 2, 5, 12, 2, Color("#5a3a18"))
			_fill(img, 2, 11, 12, 2, Color("#5a3a18"))
		"g":
			_fill(img, 0, 0, 16, 16, Color("#3e7a42"))
			_fill(img, 4, 4, 8, 11, Color("#9a9490"))
			_ellipse(img, 8, 4, 4, 3, Color("#9a9490"))
			_fill(img, 6, 6, 4, 1, Color("#6a6460"))
			_fill(img, 7, 5, 2, 4, Color("#6a6460"))
			_fill(img, 3, 14, 10, 2, Color("#356a38"))
		"S":
			_fill(img, 0, 0, 16, 16, Color("#3e7a42"))
			_fill(img, 7, 8, 2, 7, Color("#6a4a28"))
			_fill(img, 2, 2, 12, 7, Color("#b08a58"))
			_fill(img, 2, 2, 12, 1, Color("#d0a878"))
			for i in 3:
				_fill(img, 4, 4 + i * 2, 8, 1, Color("#6a4a28"))
		"w":
			_fill(img, 0, 0, 16, 16, Color("#3e7a42"))
			_ellipse(img, 8, 10, 6, 5, Color("#78706a"))
			_ellipse(img, 8, 9, 4, 3, Color("#16283a"))
			_fill(img, 3, 2, 2, 7, Color("#7a5a34"))
			_fill(img, 11, 2, 2, 7, Color("#7a5a34"))
			_fill(img, 2, 1, 12, 2, Color("#8a3830"))
		"C":
			_fill(img, 0, 0, 16, 16, Color("#6a6258"))
			_ellipse(img, 8, 12, 7, 9, Color("#181218"))
			_ellipse(img, 8, 13, 5, 7, Color("#070508"))
			_fill(img, 0, 0, 16, 3, Color("#544c44"))
		"m":
			_fill(img, 0, 0, 16, 16, Color("#000000"))
		_:
			_fill(img, 0, 0, 16, 16, Color("#3e7a42"))
	return img


static func _disc(img: Image, cx: int, cy: int, r: int, c: Color) -> void:
	for dy in range(-r, r + 1):
		var dx := int(sqrt(maxf(0.0, float(r * r - dy * dy))))
		_fill(img, cx - dx, cy + dy, dx * 2 + 1, 1, c)


static func _ellipse(img: Image, cx: int, cy: int, rx: int, ry: int, c: Color) -> void:
	for dy in range(-ry, ry + 1):
		var dx := int(rx * sqrt(maxf(0.0, 1.0 - float(dy * dy) / float(ry * ry))))
		_fill(img, cx - dx, cy + dy, dx * 2 + 1, 1, c)


static func atlas() -> Dictionary:
	if not _atlas.is_empty():
		return _atlas
	var chars := ". , \" f = o q B ~ T P ^ r % F # W R V d _ l D * X b c t p g S w C m".split(" ")
	for ch in chars:
		var variants := []
		for v in 4:
			variants.append(_tile_image(ch, v))
		_atlas[ch] = variants
	return _atlas


# ------------------------------------------------------------- map objects --

class GameMap extends RefCounted:
	var id: String
	var w: int
	var h: int
	var tiles: PackedStringArray = PackedStringArray()
	var warps: Array = []
	var npcs: Array = []
	var chests: Array = []
	var region: String = "meadow"
	var music: String = "field"
	var indoor := false
	var start := Vector2i(1, 1)
	var boss = null
	var texture: ImageTexture = null

	func _init(p_id: String, p_w: int, p_h: int, fill: String = ".") -> void:
		id = p_id
		w = p_w
		h = p_h
		tiles.resize(w * h)
		for i in w * h:
			tiles[i] = fill

	func get_tile(x: int, y: int) -> String:
		if x < 0 or y < 0 or x >= w or y >= h:
			return "^"
		return tiles[y * w + x]

	func set_tile(x: int, y: int, c: String) -> void:
		if x >= 0 and y >= 0 and x < w and y < h:
			tiles[y * w + x] = c

	func rect(x0: int, y0: int, rw: int, rh: int, c: String) -> void:
		for y in range(y0, y0 + rh):
			for x in range(x0, x0 + rw):
				set_tile(x, y, c)

	func hline(x0: int, x1: int, y: int, c: String) -> void:
		for x in range(mini(x0, x1), maxi(x0, x1) + 1):
			set_tile(x, y, c)

	func vline(y0: int, y1: int, x: int, c: String) -> void:
		for y in range(mini(y0, y1), maxi(y0, y1) + 1):
			set_tile(x, y, c)

	## Carve a road, turning water into bridge as it goes.
	func road(x0: int, y0: int, x1: int, y1: int) -> void:
		var x := x0
		var y := y0
		while x != x1:
			set_tile(x, y, "B" if get_tile(x, y) == "~" else "=")
			x += 1 if x < x1 else -1
		while y != y1:
			set_tile(x, y, "B" if get_tile(x, y) == "~" else "=")
			y += 1 if y < y1 else -1
		set_tile(x1, y1, "B" if get_tile(x1, y1) == "~" else "=")

	func building(x: int, y: int, bw: int, bh: int, door_off: int) -> Vector2i:
		rect(x, y, bw, 1, "V")
		rect(x, y + 1, bw, bh - 2, "R")
		rect(x, y + bh - 1, bw, 1, "W")
		var dx := x + door_off
		set_tile(dx, y + bh - 1, "d")
		return Vector2i(dx, y + bh - 1)

	func can_walk(x: int, y: int, opened: Dictionary) -> bool:
		if x < 0 or y < 0 or x >= w or y >= h:
			return false
		if Maps.is_solid(get_tile(x, y)):
			return false
		for n in npcs:
			if n.get("sign", false):
				continue
			if n.x == x and n.y == y:
				return false
		for c in chests:
			if c.x == x and c.y == y and not opened.get("chest_" + c.id, false):
				return false
		return true

	func warp_at(x: int, y: int):
		for wp in warps:
			if wp.x == x and wp.y == y:
				return wp
		return null

	func region_at(_x: int, y: int) -> String:
		if id != "world":
			return region
		return "meadow" if y > 40 else ("wood" if y > 22 else "crag")


## Compose the whole map into one texture, once.
static func prerender(m: GameMap) -> void:
	var a := atlas()
	var img := Image.create(m.w * TS, m.h * TS, false, Image.FORMAT_RGBA8)
	var src := Rect2i(0, 0, TS, TS)
	for y in m.h:
		for x in m.w:
			var ch := m.get_tile(x, y)
			var variants: Array = a.get(ch, a["."])
			var v := int(hash2(x, y) * 4.0) % variants.size()
			img.blit_rect(variants[v], src, Vector2i(x * TS, y * TS))
	m.texture = ImageTexture.create_from_image(img)
