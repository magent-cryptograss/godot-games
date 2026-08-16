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


## Dither between two tones in a checkerboard. This is how 16-bit art got
## gradients out of a small palette, and it is most of what separates a shaded
## tile from a flat one.
static func _dith(img: Image, x: int, y: int, w: int, h: int, a: Color, b: Color, phase: int = 0) -> void:
	for yy in range(maxi(0, y), mini(TS, y + h)):
		for xx in range(maxi(0, x), mini(TS, x + w)):
			img.set_pixel(xx, yy, a if (xx + yy + phase) % 2 == 0 else b)


## Light comes from the top left in every tile, so surfaces read as solid
## rather than as coloured squares with noise on them.
static func _tile_image(ch: String, v: int) -> Image:
	var img := Image.create(TS, TS, false, Image.FORMAT_RGBA8)
	img.fill(Color("#3e7a42"))
	var r := func(i: int) -> float: return hash2(v * 31 + i, v * 17 + i * 7)
	match ch:
		".", "f":
			var base := Color("#3e7a42")
			var lit := Color("#4d9152")
			var dark := Color("#336a39")
			_fill(img, 0, 0, 16, 16, base)
			# texture scattered by hash, never banded by row: banding would draw
			# the tile grid across the whole map
			for i in 10:
				var mx := int(r.call(i + 30) * 16)
				var my := int(r.call(i + 44) * 16)
				_fill(img, mx, my, 1, 1, lit if i % 2 == 0 else dark)
			for i in 6:
				var bx := int(r.call(i) * 15)
				var by := 2 + int(r.call(i + 9) * 11)
				_fill(img, bx, by, 1, 2, Color("#2d5f33"))
				_fill(img, bx, by, 1, 1, Color("#58a35e"))
			if ch == "f":
				var fc: Color = [Color("#f0d040"), Color("#e878b0"), Color("#f0ecf8"), Color("#a878e0")][v % 4]
				for pos in [Vector2i(4, 6), Vector2i(10, 9), Vector2i(7, 12)]:
					_fill(img, pos.x, pos.y, 2, 2, fc.darkened(0.35))
					_fill(img, pos.x, pos.y, 1, 1, fc)
		",":
			var gbase := Color("#336a39")
			_fill(img, 0, 0, 16, 16, gbase)
			for i in 14:
				var bx2 := int(r.call(i) * 15)
				var by2 := 1 + int(r.call(i + 5) * 10)
				var hgt := 4 + int(r.call(i + 21) * 2)
				_fill(img, bx2, by2, 1, hgt, Color("#27532c"))
				_fill(img, bx2, by2, 1, 2, Color("#4d9152"))
				_fill(img, bx2, by2, 1, 1, Color("#63b268"))
		'"':
			_fill(img, 0, 0, 16, 16, Color("#4a7a44"))
			for i in 8:
				var bx3 := int(r.call(i) * 14)
				var by3 := int(r.call(i + 4) * 13)
				_fill(img, bx3, by3, 2, 2, Color("#3a6636"))
				_fill(img, bx3, by3, 1, 1, Color("#5f9257"))
		"=", "q":
			var road := Color("#9a7c50") if ch == "=" else Color("#8a7048")
			_fill(img, 0, 0, 16, 16, road)
			for i in 9:
				var bx4 := int(r.call(i) * 15)
				var by4 := 2 + int(r.call(i + 6) * 11)
				_fill(img, bx4, by4, 1, 1, road.darkened(0.25))
				if i % 3 == 0:
					_fill(img, bx4, by4 - 1, 1, 1, road.lightened(0.2))
		"o":
			_fill(img, 0, 0, 16, 16, Color("#6e6e6a"))
			for a in 2:
				for b in 2:
					var sx := b * 8
					var sy := a * 8
					var tone := Color("#9a9a94") if hash2(v * 4 + b, a) > 0.5 else Color("#8a8a86")
					_fill(img, sx, sy, 7, 7, tone)
					_fill(img, sx, sy, 7, 1, tone.lightened(0.22))
					_fill(img, sx, sy, 1, 7, tone.lightened(0.12))
					_fill(img, sx, sy + 6, 7, 1, tone.darkened(0.25))
					_fill(img, sx + 6, sy, 1, 7, tone.darkened(0.15))
		"B":
			_fill(img, 0, 0, 16, 16, Color("#22528a"))
			_fill(img, 0, 1, 16, 14, Color("#a07840"))
			for i in 5:
				_fill(img, 0, 1 + i * 3, 16, 1, Color("#7a5628"))
				_fill(img, 0, 2 + i * 3, 16, 1, Color("#b78a4c"))
			_fill(img, 0, 0, 16, 1, Color("#c9a05e"))
			_fill(img, 0, 15, 16, 1, Color("#5e3f1c"))
		"~":
			var deep := Color("#1d4a80")
			var mid := Color("#22528a")
			var topw := Color("#2f6099")
			_fill(img, 0, 0, 16, 16, mid)
			_dith(img, 0, 0, 16, 5, topw, mid)
			_dith(img, 0, 10, 16, 6, mid, deep)
			for i in 3:
				var bx5 := int(r.call(i) * 11)
				var by5 := 2 + int(r.call(i + 7) * 11)
				_fill(img, bx5, by5, 4, 1, Color("#4f8fc4"))
				_fill(img, bx5 + 1, by5 - 1, 2, 1, Color("#79b4dd"))
		"T":
			_fill(img, 0, 0, 16, 16, Color("#3e7a42"))
			_ellipse(img, 8, 14, 6, 2, Color("#2f6135"))
			_fill(img, 7, 9, 2, 6, Color("#4a3018"))
			_fill(img, 7, 9, 1, 6, Color("#63421f"))
			_disc(img, 8, 7, 6, Color("#1f4a24"))
			_disc(img, 7, 6, 5, Color("#2c6431"))
			_disc(img, 6, 5, 3, Color("#3d7d40"))
			_fill(img, 5, 3, 2, 1, Color("#55964f"))
			_fill(img, 4, 4, 1, 1, Color("#55964f"))
		"P":
			_fill(img, 0, 0, 16, 16, Color("#3e7a42"))
			_ellipse(img, 8, 15, 5, 1, Color("#2f6135"))
			_fill(img, 7, 12, 2, 4, Color("#42301a"))
			for i in 4:
				var wd := 3 + i * 3
				var yy2 := 2 + i * 3
				var xx2 := 8 - (wd >> 1)
				_fill(img, xx2, yy2, wd, 3, Color("#1c4a24"))
				_fill(img, xx2, yy2, wd, 1, Color("#2f6c34"))
				_fill(img, xx2, yy2, maxi(1, int(wd / 2)), 1, Color("#3f8543"))
			_fill(img, 7, 0, 2, 3, Color("#2f6c34"))
		"^":
			_fill(img, 0, 0, 16, 16, Color("#5c554c"))
			# two faces: lit to the left of the ridge, shadowed to the right
			for yy3 in 16:
				var half := int((yy3 + 1) / 2) + 1
				_fill(img, maxi(0, 8 - half), yy3, half, 1, Color("#7d766a"))
				_fill(img, 8, yy3, half, 1, Color("#4e483f"))
			for yy4 in range(1, 6):
				_fill(img, 8 - yy4, yy4, yy4 * 2, 1, Color("#e4e6ee") if yy4 < 4 else Color("#b9bcc6"))
			_dith(img, 0, 14, 16, 2, Color("#4e483f"), Color("#3b362f"))
		"r":
			# each variant is a different boulder, or a field of them turns into
			# wallpaper -- four identical rocks in a row is worse than none
			_fill(img, 0, 0, 16, 16, Color("#3e7a42"))
			var rx := 6 + int(r.call(1) * 4)
			var ry := 8 + int(r.call(2) * 3)
			var rw := 4 + int(r.call(3) * 3)
			_ellipse(img, rx, ry + 4, rw, 2, Color("#2f6135"))
			_ellipse(img, rx, ry, rw, rw - 1, Color("#6b645a"))
			_ellipse(img, rx - 1, ry - 1, maxi(2, rw - 2), maxi(2, rw - 3), Color("#8d8578"))
			_fill(img, rx - 2, ry - 3, 2, 1, Color("#a8a094"))
			_ellipse(img, rx + 2, ry + 2, maxi(2, rw - 3), 2, Color("#544e46"))
			if v % 2 == 0:
				# a smaller companion stone
				var sx2 := 2 + int(r.call(4) * 3)
				var sy2 := 10 + int(r.call(5) * 3)
				_ellipse(img, sx2, sy2, 2, 2, Color("#615a52"))
				_fill(img, sx2 - 1, sy2 - 1, 1, 1, Color("#8d8578"))
		"%":
			_fill(img, 0, 0, 16, 16, Color("#3e7a42"))
			_ellipse(img, 8, 14, 5, 2, Color("#2f6135"))
			_disc(img, 8, 9, 6, Color("#1f4a24"))
			_disc(img, 7, 8, 4, Color("#2f6c34"))
			_disc(img, 6, 6, 2, Color("#43884a"))
			if v % 2 == 0:
				for pos2 in [Vector2i(10, 10), Vector2i(5, 12)]:
					_fill(img, pos2.x, pos2.y, 2, 2, Color("#8f2420"))
					_fill(img, pos2.x, pos2.y, 1, 1, Color("#d84b3c"))
		"F":
			_fill(img, 0, 0, 16, 16, Color("#3e7a42"))
			for px in [2, 11]:
				_fill(img, px, 4, 2, 11, Color("#5f4526"))
				_fill(img, px, 4, 1, 11, Color("#8a6a40"))
			for yy5 in [6, 11]:
				_fill(img, 0, yy5, 16, 2, Color("#6b4e2b"))
				_fill(img, 0, yy5, 16, 1, Color("#9a7647"))
		"#":
			_fill(img, 0, 0, 16, 16, Color("#5f5852"))
			for a2 in 4:
				var off := (a2 % 2) * 4
				for b2 in range(-1, 3):
					var bx6 := b2 * 8 + off
					var tone2 := Color("#8b837c") if hash2(v * 9 + b2, a2) > 0.5 else Color("#7b736c")
					_fill(img, bx6 + 1, a2 * 4 + 1, 6, 2, tone2)
					_fill(img, bx6 + 1, a2 * 4 + 1, 6, 1, tone2.lightened(0.18))
		"W":
			_fill(img, 0, 0, 16, 16, Color("#8a6440"))
			for i in 4:
				_fill(img, 0, i * 4, 16, 1, Color("#5e4229"))
				_fill(img, 0, i * 4 + 1, 16, 1, Color("#a07a50"))
			_fill(img, 3, 2, 1, 2, Color("#6b4c2e"))
			_fill(img, 11, 10, 1, 2, Color("#6b4c2e"))
		"R":
			for a3 in 4:
				for b3 in 4:
					var tone3 := Color("#a04438") if (a3 + b3) % 2 == 1 else Color("#8a3830")
					_fill(img, b3 * 4, a3 * 4, 4, 3, tone3)
					_fill(img, b3 * 4, a3 * 4, 4, 1, tone3.lightened(0.2))
					_fill(img, b3 * 4, a3 * 4 + 2, 4, 1, tone3.darkened(0.25))
			_fill(img, 0, 0, 16, 1, Color("#c96a56"))
		"V":
			_fill(img, 0, 0, 16, 16, Color("#6a2a24"))
			_fill(img, 0, 4, 16, 12, Color("#8a3830"))
			_dith(img, 0, 4, 16, 3, Color("#a04438"), Color("#8a3830"))
			_fill(img, 0, 2, 16, 2, Color("#c96a56"))
			_fill(img, 0, 0, 16, 2, Color("#4a1e18"))
			_fill(img, 6, 8, 4, 8, Color("#3a1512"))
		"d":
			_fill(img, 0, 0, 16, 16, Color("#8a6440"))
			_fill(img, 2, 2, 12, 14, Color("#402a14"))
			_fill(img, 3, 3, 10, 13, Color("#71482a"))
			for i in 3:
				_fill(img, 3 + i * 4, 3, 1, 13, Color("#5a3a1e"))
				_fill(img, 4 + i * 4, 3, 1, 13, Color("#835434"))
			_fill(img, 3, 3, 10, 1, Color("#9a6640"))
			_fill(img, 11, 9, 2, 2, Color("#f0d040"))
			_fill(img, 11, 9, 1, 1, Color("#fff0a8"))
		"_":
			_fill(img, 0, 0, 16, 16, Color("#9a7448"))
			for i in 4:
				_fill(img, 0, i * 4 + 3, 16, 1, Color("#6f4e2b"))
				_fill(img, 0, i * 4, 16, 1, Color("#a98255"))
			if v % 2 == 0:
				_fill(img, 4, 1, 1, 2, Color("#7a5630"))
		"l":
			_fill(img, 0, 0, 16, 16, Color("#8d8578"))
			for a4 in 2:
				for b4 in 2:
					var tone4 := Color("#b0a898") if (a4 + b4) % 2 == 1 else Color("#9d9486")
					_fill(img, b4 * 8 + 1, a4 * 8 + 1, 6, 6, tone4)
					_fill(img, b4 * 8 + 1, a4 * 8 + 1, 6, 1, tone4.lightened(0.16))
					_fill(img, b4 * 8 + 1, a4 * 8 + 6, 6, 1, tone4.darkened(0.2))
		"D", "*":
			var cbase := Color("#4a3c48") if ch == "*" else Color("#332a33")
			_fill(img, 0, 0, 16, 16, cbase)
			for i in 7:
				var bx7 := int(r.call(i) * 15)
				var by7 := 2 + int(r.call(i + 8) * 11)
				_fill(img, bx7, by7, 1, 1, cbase.darkened(0.3))
				if i % 2 == 0:
					_fill(img, bx7, by7 - 1, 1, 1, cbase.lightened(0.25))
		"X":
			_fill(img, 0, 0, 16, 16, Color("#1d161c"))
			_ellipse(img, 8, 8, 8, 8, Color("#332734"))
			_ellipse(img, 7, 7, 6, 5, Color("#423444"))
			_ellipse(img, 6, 6, 4, 3, Color("#4f3f50"))
			_fill(img, 4, 3, 2, 1, Color("#61506a"))
			_dith(img, 0, 13, 16, 3, Color("#241c26"), Color("#150f18"))
		"b":
			_fill(img, 0, 0, 16, 16, Color("#9a7448"))
			_fill(img, 1, 1, 14, 14, Color("#c8c0b0"))
			_fill(img, 2, 2, 12, 4, Color("#e8e4dc"))
			_fill(img, 2, 2, 12, 1, Color("#f6f4ee"))
			_fill(img, 1, 8, 14, 7, Color("#7a3840"))
			_fill(img, 1, 8, 14, 1, Color("#a85058"))
			_fill(img, 1, 14, 14, 1, Color("#5c272e"))
		"c":
			_fill(img, 0, 0, 16, 16, Color("#9a7448"))
			_fill(img, 0, 3, 16, 10, Color("#6f4e2b"))
			_fill(img, 0, 2, 16, 2, Color("#b58e5b"))
			_fill(img, 0, 1, 16, 1, Color("#cba272"))
			_fill(img, 0, 12, 16, 1, Color("#4d3419"))
		"t":
			_fill(img, 0, 0, 16, 16, Color("#9a7448"))
			_fill(img, 1, 3, 14, 9, Color("#7f5730"))
			_fill(img, 1, 3, 14, 2, Color("#a87a48"))
			_fill(img, 1, 3, 14, 1, Color("#c1904f"))
			_fill(img, 1, 11, 14, 1, Color("#5d3d1c"))
			_fill(img, 3, 12, 2, 3, Color("#5d3d1c"))
			_fill(img, 11, 12, 2, 3, Color("#5d3d1c"))
		"p":
			_fill(img, 0, 0, 16, 16, Color("#9a7448"))
			_ellipse(img, 8, 13, 5, 2, Color("#6f4e2b"))
			_ellipse(img, 8, 9, 6, 6, Color("#6d4820"))
			_ellipse(img, 7, 8, 4, 4, Color("#8a5c2a"))
			_fill(img, 2, 5, 12, 2, Color("#4a3113"))
			_fill(img, 2, 11, 12, 2, Color("#4a3113"))
			_ellipse(img, 8, 4, 6, 2, Color("#a87a48"))
		"g":
			_fill(img, 0, 0, 16, 16, Color("#3e7a42"))
			_ellipse(img, 8, 15, 6, 2, Color("#2f6135"))
			_fill(img, 4, 4, 8, 11, Color("#7f7a76"))
			_ellipse(img, 8, 4, 4, 3, Color("#7f7a76"))
			_fill(img, 4, 4, 1, 11, Color("#9d9894"))
			_fill(img, 11, 4, 1, 11, Color("#605c58"))
			_fill(img, 6, 6, 4, 1, Color("#4e4a47"))
			_fill(img, 7, 5, 2, 4, Color("#4e4a47"))
		"S":
			_fill(img, 0, 0, 16, 16, Color("#3e7a42"))
			_fill(img, 7, 8, 2, 7, Color("#5a3f21"))
			_fill(img, 7, 8, 1, 7, Color("#7a5a34"))
			_fill(img, 2, 2, 12, 7, Color("#9a7748"))
			_fill(img, 2, 2, 12, 1, Color("#c39960"))
			_fill(img, 2, 8, 12, 1, Color("#6d4f28"))
			for i in 3:
				_fill(img, 4, 4 + i * 2, 8, 1, Color("#5a3f21"))
		"w":
			_fill(img, 0, 0, 16, 16, Color("#3e7a42"))
			_ellipse(img, 8, 10, 6, 5, Color("#6b645a"))
			_ellipse(img, 8, 9, 5, 4, Color("#8d8578"))
			_ellipse(img, 8, 10, 4, 3, Color("#101c2a"))
			_fill(img, 3, 2, 2, 7, Color("#5f4526"))
			_fill(img, 11, 2, 2, 7, Color("#5f4526"))
			_fill(img, 2, 1, 12, 2, Color("#8a3830"))
			_fill(img, 2, 0, 12, 1, Color("#b04c40"))
		"C":
			_fill(img, 0, 0, 16, 16, Color("#5c554c"))
			for yy6 in 16:
				var half2 := int((yy6 + 1) / 2) + 1
				_fill(img, maxi(0, 8 - half2), yy6, half2, 1, Color("#7d766a"))
				_fill(img, 8, yy6, half2, 1, Color("#4e483f"))
			_ellipse(img, 8, 12, 7, 9, Color("#120e14"))
			_ellipse(img, 8, 13, 5, 7, Color("#050307"))
			_fill(img, 2, 3, 12, 1, Color("#8d8578"))
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
		# bands by fraction of the map, so they hold at any world size
		var f := float(y) / float(maxi(1, h))
		return "meadow" if f > 0.62 else ("wood" if f > 0.34 else "crag")


## Multiply a run of pixels, for contact shadows and rim light.
static func _shade(img: Image, x: int, y: int, w: int, h: int, amount: float) -> void:
	var iw := img.get_width()
	var ih := img.get_height()
	for yy in range(maxi(0, y), mini(ih, y + h)):
		for xx in range(maxi(0, x), mini(iw, x + w)):
			var c := img.get_pixel(xx, yy)
			if amount < 1.0:
				img.set_pixel(xx, yy, Color(c.r * amount, c.g * amount, c.b * amount, c.a))
			else:
				img.set_pixel(xx, yy, c.lightened(amount - 1.0))


## Terrain transitions. Two effects, both cheap and both doing a lot of work:
## a contact shadow on the ground beneath anything solid, and a bright rim where
## water meets land. Without these the map reads as flat squares laid side by
## side, which is the thing that looks 8-bit however well each tile is shaded.
static func _edge_pass(m: GameMap, img: Image) -> void:
	for y in m.h:
		for x in m.w:
			var here := m.get_tile(x, y)
			var px := x * TS
			var py := y * TS

			if here == "~":
				# foam where the water meets anything that is not water
				if m.get_tile(x, y - 1) != "~":
					_shade(img, px, py, TS, 1, 1.35)
					_shade(img, px, py + 1, TS, 1, 1.18)
				if m.get_tile(x, y + 1) != "~":
					_shade(img, px, py + TS - 1, TS, 1, 1.2)
				if m.get_tile(x - 1, y) != "~":
					_shade(img, px, py, 1, TS, 1.2)
				if m.get_tile(x + 1, y) != "~":
					_shade(img, px + TS - 1, py, 1, TS, 1.2)
				continue

			if is_solid(here):
				continue

			# ground in the lee of something solid falls into shadow
			if is_solid(m.get_tile(x, y - 1)):
				_shade(img, px, py, TS, 1, 0.62)
				_shade(img, px, py + 1, TS, 1, 0.76)
				_shade(img, px, py + 2, TS, 1, 0.88)
			if is_solid(m.get_tile(x - 1, y)):
				_shade(img, px, py, 1, TS, 0.72)
				_shade(img, px + 1, py, 1, TS, 0.86)
			if is_solid(m.get_tile(x + 1, y)):
				_shade(img, px + TS - 1, py, 1, TS, 0.82)
			# No rim light on the near side of a solid: it outlines every
			# isolated rock and tree with a bright box, which reads as a UI
			# selection rather than as terrain.


## Tile textures, built once from the atlas. Drawing from these each frame
## replaces composing the whole map into a single image, which put a hard
## ceiling on how big a world could be.
static var _tex := {}

static func textures() -> Dictionary:
	if not _tex.is_empty():
		return _tex
	for ch in atlas():
		var arr: Array = []
		for img in atlas()[ch]:
			arr.append(ImageTexture.create_from_image(img))
		_tex[ch] = arr
	return _tex


## Which of the four variants a tile uses. Deterministic, so a tile does not
## shimmer between variants as the camera moves.
static func variant_of(x: int, y: int, count: int) -> int:
	return int(hash2(x, y) * 4.0) % maxi(1, count)


## Kept so callers that still ask for it do not break; nothing is composed now.
static func prerender(_m: GameMap) -> void:
	pass
