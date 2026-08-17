class_name Maps
extends RefCounted
## Maps are built in code rather than authored as TileSets: fewer moving parts,
## and the overworld is generated from a fixed seed so it is the same every run.
##
## Tiles are rendered into a small atlas once (four variants each, picked by a
## coordinate hash so a field of grass is not visibly tiled), then whole maps are
## composed with blit_rect, which is far faster than per-pixel work in GDScript.

const TS := 32

const SOLID := {
	"~": true, "T": true, "P": true, "^": true, "r": true, "%": true, "F": true,
	"#": true, "W": true, "n": true, "R": true, "V": true, "X": true, "b": true, "c": true,
	"t": true, "p": true, "g": true, "S": true, "w": true, "m": true,
}
# How much a tile multiplies the encounter chance. Tall grass and cave floor
# were at 3, which put caves at a fight every seven steps.
const ENC := {".": 1, ",": 2, "\"": 1, "f": 1, "D": 2}

## What each ground reads as when it spills over an edge, and which grounds win.
## Higher rank grows over lower: grass over a path, undergrowth over grass.
const BLEND_COL := {
	"=": "#9c8258", "q": "#8a7048", "o": "#6d6b66", "\"": "#7f8a4e",
	".": "#4a7a44", "f": "#4a7a44", ",": "#3a6339", "D": "#4a4458",
}
const BLEND_RANK := {
	"o": 0, "=": 1, "q": 1, "\"": 2, ".": 3, "f": 3, ",": 4,
}

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
##
## Tiles are 32x32. They were 16x16, which is not enough room for a surface to
## have structure -- a wall could have a noise field on it but not courses of
## stone, a floor could have stripes but not boards with ends and nails.
static func _tile_image(ch: String, v: int) -> Image:
	var img := Image.create(TS, TS, false, Image.FORMAT_RGBA8)
	img.fill(Color("#4a7a44"))
	var r := func(i: int) -> float: return hash2(v * 31 + i, v * 17 + i * 7)
	match ch:
		".", "f":
			# Grass in four tones: a body, broad soft patches drifting through
			# it, and blades standing up with lit tips. Scattered by hash and
			# never banded by row -- banding draws the tile grid across the map.
			_fill(img, 0, 0, 32, 32, Color("#4a7a44"))
			for i in 9:
				var px := int(r.call(i) * 27)
				var py := int(r.call(i + 9) * 27)
				_fill(img, px, py, 6, 4, Color("#436e3e") if i % 2 == 0 else Color("#537f4a"))
			for i in 5:
				_dith(img, int(r.call(i + 20) * 24), int(r.call(i + 26) * 26), 8, 4,
					Color("#537f4a"), Color("#4a7a44"))
			for i in 16:
				var bx := 1 + int(r.call(i + 3) * 29)
				var by := 2 + int(r.call(i + 17) * 26)
				_fill(img, bx, by, 1, 4, Color("#3b6537"))
				_fill(img, bx, by, 1, 2, Color("#5b8a52"))
				_fill(img, bx, by, 1, 1, Color("#6d9b60"))
			if ch == "f":
				var fc: Color = [Color("#e8d27a"), Color("#d9dbe8"), Color("#c98fb4"),
					Color("#e0a05c")][v % 4]
				for pos in [Vector2i(8, 11), Vector2i(21, 18), Vector2i(14, 24), Vector2i(25, 7)]:
					_fill(img, pos.x, pos.y + 3, 1, 3, Color("#3b6537"))
					_fill(img, pos.x - 1, pos.y, 3, 3, fc.darkened(0.4))
					_fill(img, pos.x, pos.y, 2, 2, fc)
					_fill(img, pos.x, pos.y, 1, 1, fc.lightened(0.3))
		"\"":
			# dry grass: the same ground with the green gone out of it and bare
			# earth showing through
			_fill(img, 0, 0, 32, 32, Color("#7f8a4e"))
			for i in 10:
				var dx := int(r.call(i) * 27)
				var dy := int(r.call(i + 5) * 27)
				_fill(img, dx, dy, 5, 3, Color("#74804a"))
			for i in 6:
				_dith(img, int(r.call(i + 14) * 24), int(r.call(i + 19) * 26), 8, 4,
					Color("#8a7a52"), Color("#7f8a4e"))
			for i in 14:
				var bx2 := int(r.call(i + 30) * 30)
				var by2 := int(r.call(i + 40) * 28)
				_fill(img, bx2, by2, 1, 3, Color("#6d7742"))
				_fill(img, bx2, by2, 1, 1, Color("#9aa463"))
		",":
			# deep grass, tall enough to hide things in
			_fill(img, 0, 0, 32, 32, Color("#3a6339"))
			for i in 8:
				_fill(img, int(r.call(i + 30) * 27), int(r.call(i + 37) * 27), 6, 4,
					Color("#345a34"))
			for i in 26:
				var bx3 := int(r.call(i) * 31)
				var by3 := int(r.call(i + 5) * 22)
				var hgt := 7 + int(r.call(i + 21) * 4)
				_fill(img, bx3, by3, 1, hgt, Color("#2a4f2e"))
				_fill(img, bx3, by3, 1, 3, Color("#46764a"))
				_fill(img, bx3, by3, 1, 1, Color("#5f9663"))
		"=", "q":
			# Packed earth: a body, a rut worn down the middle where the feet go,
			# and stones pressed into it. Every stone gets a lit top and a dark
			# underside, which is what makes a flat tile look like it has things
			# sitting on it.
			var road := Color("#9c8258") if ch == "=" else Color("#8a7048")
			_fill(img, 0, 0, 32, 32, road)
			_fill(img, 0, 11, 32, 11, road.darkened(0.10))
			_dith(img, 0, 8, 32, 4, road.darkened(0.10), road)
			_dith(img, 0, 21, 32, 4, road.darkened(0.10), road)
			for i in 14:
				var bx4 := 1 + int(r.call(i) * 28)
				var by4 := 2 + int(r.call(i + 6) * 26)
				var sw := 2 + int(r.call(i + 18) * 3)
				_fill(img, bx4, by4, sw, 3, road.darkened(0.30))
				_fill(img, bx4, by4, sw, 1, road.lightened(0.24))
				_fill(img, bx4, by4 + 2, sw, 1, road.darkened(0.42))
			for i in 6:
				_fill(img, int(r.call(i + 41) * 31), int(r.call(i + 47) * 31), 2, 1,
					Color("#5d7a49"))
		"o":
			# Laid stone, offset course to course, each slab with a lit top edge,
			# a shaded bottom and grout between.
			_fill(img, 0, 0, 32, 32, Color("#4f4d4b"))
			for row in 4:
				var off := 0 if row % 2 == 0 else 8
				for col in 3:
					var sx := -off + col * 16
					var st := Color("#7d7b76") if (row + col) % 2 == 0 else Color("#74726d")
					if hash2(v * 13 + row, col) > 0.78:
						st = Color("#867f77")
					_fill(img, sx, row * 8, 15, 7, st)
					_fill(img, sx, row * 8, 15, 1, st.lightened(0.18))
					_fill(img, sx, row * 8 + 6, 15, 1, st.darkened(0.26))
					_fill(img, sx, row * 8, 1, 7, st.lightened(0.08))
					if hash2(v * 5 + row, col * 3) > 0.6:
						_fill(img, sx + 3, row * 8 + 3, 2, 1, st.darkened(0.16))
		"B":
			# a plank bridge, over water
			_fill(img, 0, 0, 32, 32, Color("#22528a"))
			_fill(img, 0, 2, 32, 28, Color("#a07840"))
			for i in 5:
				var py2 := 2 + i * 6
				_fill(img, 0, py2, 32, 5, Color("#a07840"))
				_fill(img, 0, py2, 32, 1, Color("#c09a5e"))
				_fill(img, 0, py2 + 4, 32, 1, Color("#6b4a24"))
				_fill(img, 4, py2 + 2, 1, 1, Color("#5e3f1c"))
				_fill(img, 27, py2 + 2, 1, 1, Color("#5e3f1c"))
			_fill(img, 0, 0, 32, 2, Color("#c9a05e"))
			_fill(img, 0, 30, 32, 2, Color("#5e3f1c"))
		"~":
			# three depths, with the light catching along the crests
			var deep := Color("#1d4a80")
			var mid := Color("#22528a")
			var topw := Color("#2f6099")
			_fill(img, 0, 0, 32, 32, mid)
			_dith(img, 0, 0, 32, 10, topw, mid)
			_dith(img, 0, 20, 32, 12, mid, deep)
			for i in 6:
				var bx5 := int(r.call(i) * 24)
				var by5 := 3 + int(r.call(i + 7) * 24)
				_fill(img, bx5, by5, 8, 1, Color("#4f8fc4"))
				_fill(img, bx5 + 2, by5 - 1, 4, 1, Color("#79b4dd"))
				_fill(img, bx5 + 3, by5 - 2, 2, 1, Color("#a5d2ee"))
		"T":
			# A canopy of overlapping lobes rather than one disc, lit from the top
			# left, with a cast shadow to sit it on the ground. One flat circle
			# reads as a bush.
			# Canopy of overlapping lobes, lit from the top left, with a cast
			# shadow to sit it on the ground -- and every measurement taken from
			# the variant, so a wood is not one tree printed forty times.
			_fill(img, 0, 0, 32, 32, Color("#4a7a44"))
			var tx4 := 14 + int(r.call(1) * 5)          # where the trunk stands
			var cw := 10 + int(r.call(2) * 4)           # how wide the canopy is
			var ct := 12 + int(r.call(3) * 4)           # and how high
			_ellipse(img, tx4 + 3, 28, cw + 1, 4, Color("#3c6438"))
			_fill(img, tx4, ct + 4, 5, 26 - ct, Color("#4a3018"))
			_fill(img, tx4, ct + 4, 2, 26 - ct, Color("#6b4823"))
			_fill(img, tx4 + 4, ct + 4, 1, 26 - ct, Color("#33200f"))
			_disc(img, tx4 + 2, ct, cw + 1, Color("#1d4423"))
			for k in 4:
				_disc(img, tx4 + 2 + int((r.call(k + 10) - 0.5) * cw * 1.4),
					ct + int((r.call(k + 20) - 0.5) * cw), 5 + int(r.call(k + 30) * 3),
					Color("#2b6231"))
			for k in 3:
				_disc(img, tx4 + int((r.call(k + 40) - 0.5) * cw),
					ct - 2 + int((r.call(k + 45) - 0.5) * cw * 0.8),
					3 + int(r.call(k + 50) * 3), Color("#3a7a3e"))
			_disc(img, tx4 - cw + 4, ct - cw + 5, 4, Color("#4d9350"))
			_fill(img, tx4 - cw + 2, ct - cw + 3, 4, 2, Color("#63a862"))
			_dith(img, tx4 - cw + 2, ct + 3, cw * 2 - 4, 6,
				Color("#1d4423"), Color("#2b6231"))
			for i in 10:
				_fill(img, 4 + int(r.call(i) * 24), 4 + int(r.call(i + 9) * 20), 1, 1,
					Color("#4d9350"))
		"P":
			_fill(img, 0, 0, 32, 32, Color("#4a7a44"))
			# height, girth and lean all out of the variant
			var px5 := 14 + int(r.call(1) * 5)
			var top := 1 + int(r.call(2) * 5)
			var spread := 4 + int(r.call(3) * 2)
			_ellipse(img, px5 + 4, 30, 10, 3, Color("#3c6438"))
			_fill(img, px5, 24, 5, 8, Color("#42301a"))
			_fill(img, px5, 24, 2, 8, Color("#63421f"))
			# skirts of needles, lit along the top and dark underneath so the
			# tiers read as tiers rather than as stripes
			for i in 5:
				var wd := 6 + i * spread
				var yy := top + i * 5
				var xx := px5 + 2 - (wd >> 1)
				_fill(img, xx, yy, wd, 6, Color("#1b4522"))
				_fill(img, xx, yy, wd, 2, Color("#2e6a33"))
				_fill(img, xx, yy, maxi(1, int(wd / 2)), 1, Color("#41894a"))
				_fill(img, xx, yy + 5, wd, 1, Color("#12301a"))
			_fill(img, px5, top - 2, 4, 5, Color("#2e6a33"))
			_fill(img, px5, top - 2, 2, 3, Color("#41894a"))
		"^":
			# a peak with a lit face, a shaded face and snow on top
			_fill(img, 0, 0, 32, 32, Color("#6b645a"))
			for i in 32:
				var half := int((i + 1) / 2) + 2
				_fill(img, maxi(0, 16 - half), i, half, 1, Color("#8d8578"))
				_fill(img, 16, i, half, 1, Color("#4e483f"))
			# snow on some peaks and not others, and never in quite the same place
			if v % 3 != 2:
				var sx5 := 10 + int(r.call(1) * 6)
				_fill(img, sx5, 2, 8, 5, Color("#d8d4cc"))
				_fill(img, sx5 + 2, 1, 5, 3, Color("#f0ece4"))
				_fill(img, sx5 + 4, 4, 4, 4, Color("#b4aea4"))
			for i in 5:
				var cy := 8 + int(r.call(i) * 20)
				_fill(img, 16 - int(r.call(i + 8) * 6), cy, 3, 1, Color("#5d564d"))
		"r":
			# Boulders sitting on the ground rather than grey squares, and no two
			# the same: the size, the lean and the number of them all come out of
			# the variant.
			_fill(img, 0, 0, 32, 32, Color("#4a7a44"))
			if v % 4 == 3:
				# a pair of smaller stones instead of one big one
				for k in 2:
					var kx := 9 + k * 13 + int(r.call(k) * 3)
					var ky := 16 + k * 5
					var kr := 5 + int(r.call(k + 4) * 3)
					_ellipse(img, kx + 1, ky + kr - 1, kr + 2, 3, Color("#3c6438"))
					_ellipse(img, kx, ky, kr + 1, kr, Color("#4f4941"))
					_ellipse(img, kx - 1, ky - 1, kr, kr - 1, Color("#6b645a"))
					_ellipse(img, kx - 2, ky - 2, kr - 2, kr - 3, Color("#847c70"))
			else:
				var cx2 := 14 + int(r.call(1) * 5)
				var cy2 := 16 + int(r.call(2) * 4)
				var rx := 10 + int(r.call(3) * 4)
				var ry := 8 + int(r.call(4) * 4)
				_ellipse(img, cx2 + 1, cy2 + ry - 1, rx + 2, 4, Color("#3c6438"))
				_ellipse(img, cx2, cy2, rx, ry, Color("#4f4941"))
				_ellipse(img, cx2 - 1, cy2 - 2, rx - 2, ry - 2, Color("#6b645a"))
				_ellipse(img, cx2 - 3, cy2 - 4, rx - 5, ry - 5, Color("#847c70"))
				_ellipse(img, cx2 - 4, cy2 - 6, rx - 8, ry - 8, Color("#9a9186"))
				_dith(img, cx2 - rx + 2, cy2 + 2, rx * 2 - 6, 6,
					Color("#4f4941"), Color("#6b645a"))
				for k in 3:
					_fill(img, cx2 - 4 + int(r.call(k + 9) * 10),
						cy2 - 3 + int(r.call(k + 13) * 8), 3, 1, Color("#3f3a34"))
		"%":
			_fill(img, 0, 0, 32, 32, Color("#4a7a44"))
			_ellipse(img, 17, 27, 12, 3, Color("#3c6438"))
			for k in 3:
				_disc(img, 10 + int(r.call(k) * 14), 14 + int(r.call(k + 5) * 8),
					6 + int(r.call(k + 9) * 4), Color("#22522a"))
			for k in 3:
				_disc(img, 10 + int(r.call(k + 12) * 12), 13 + int(r.call(k + 16) * 7),
					4 + int(r.call(k + 20) * 3), Color("#2f6c34"))
			_disc(img, 10 + int(r.call(24) * 6), 11 + int(r.call(25) * 4), 4,
				Color("#43884a"))
			for i in 8:
				_fill(img, 5 + int(r.call(i) * 22), 8 + int(r.call(i + 7) * 16), 1, 1,
					Color("#57a45c"))
		"F":
			# a rail fence, posts and two rails
			_fill(img, 0, 0, 32, 32, Color("#4a7a44"))
			for px2 in [4, 22]:
				_fill(img, px2, 8, 5, 22, Color("#5f4526"))
				_fill(img, px2, 8, 2, 22, Color("#8a6a40"))
				_fill(img, px2, 8, 5, 1, Color("#a3814f"))
			for yy2 in [12, 22]:
				_fill(img, 0, yy2, 32, 4, Color("#6b4e2b"))
				_fill(img, 0, yy2, 32, 1, Color("#9a7647"))
				_fill(img, 0, yy2 + 3, 32, 1, Color("#4a3419"))
		"#":
			# courses of stone, offset row to row
			_fill(img, 0, 0, 32, 32, Color("#463f3a"))
			for row2 in 4:
				var off2 := 0 if row2 % 2 == 0 else 6
				for col2 in 4:
					var sx2 := -off2 + col2 * 12
					var tone := Color("#8b837c") if hash2(v * 9 + row2, col2) > 0.5 else Color("#7b736c")
					_fill(img, sx2, row2 * 8, 11, 7, tone)
					_fill(img, sx2, row2 * 8, 11, 1, tone.lightened(0.18))
					_fill(img, sx2, row2 * 8 + 6, 11, 1, tone.darkened(0.3))
					_fill(img, sx2, row2 * 8, 1, 7, tone.lightened(0.08))
		"W":
			# The front of a building. The dark band across the top is the shadow
			# the overhanging roof throws on it, and it is the reason the roof
			# reads as being in front of the wall rather than beside it.
			var plaster := Color("#c9b189")
			_fill(img, 0, 0, 32, 32, plaster)
			_fill(img, 0, 24, 32, 8, Color("#a08a66"))
			_dith(img, 0, 20, 32, 4, Color("#a08a66"), plaster)
			_fill(img, 0, 0, 32, 6, Color("#6d5a41"))
			_fill(img, 0, 6, 32, 2, Color("#8f7859"))
			_fill(img, 0, 8, 2, 24, Color("#6b4c2e"))
			_fill(img, 30, 8, 2, 24, Color("#6b4c2e"))
			if v % 2 == 0:
				_fill(img, 8, 12, 16, 14, Color("#5a3f22"))
				_fill(img, 10, 14, 12, 10, Color("#3c4a63"))
				_fill(img, 10, 14, 6, 5, Color("#5d7194"))
				_fill(img, 10, 14, 4, 2, Color("#8fa4c4"))
				_fill(img, 15, 14, 2, 10, Color("#5a3f22"))
				_fill(img, 10, 18, 12, 2, Color("#5a3f22"))
				_fill(img, 7, 25, 18, 2, Color("#8a6c47"))
			else:
				_fill(img, 6, 14, 2, 16, Color("#a58f6b"))
				_fill(img, 24, 18, 2, 12, Color("#a58f6b"))
		"n":
			# the lower course of the wall: no eave shadow, that belongs only on
			# the row the roof actually overhangs
			var plaster2 := Color("#c9b189")
			_fill(img, 0, 0, 32, 32, plaster2)
			_fill(img, 0, 22, 32, 10, Color("#a08a66"))
			_dith(img, 0, 18, 32, 4, Color("#a08a66"), plaster2)
			_fill(img, 0, 0, 2, 32, Color("#6b4c2e"))
			_fill(img, 30, 0, 2, 32, Color("#6b4c2e"))
			_fill(img, 0, 29, 32, 3, Color("#5a4527"))
			_fill(img, 0, 28, 32, 1, Color("#8a7a5c"))
			if v % 3 == 0:
				_fill(img, 10, 6, 12, 12, Color("#5a3f22"))
				_fill(img, 12, 8, 8, 8, Color("#3c4a63"))
				_fill(img, 12, 8, 4, 4, Color("#5d7194"))
				_fill(img, 9, 18, 14, 2, Color("#8a6c47"))
			else:
				_fill(img, 8, 4, 2, 22, Color("#a58f6b"))
				_fill(img, 22, 10, 2, 16, Color("#a58f6b"))
		"R":
			# Courses of shingles across the slope, each lit along its upper edge
			# with a dark seam beneath, offset course to course so the joins do
			# not line up into a grid.
			_fill(img, 0, 0, 32, 32, Color("#9c4034"))
			for course in 4:
				var cy2 := course * 8
				var off3 := 0 if course % 2 == 0 else 4
				_fill(img, 0, cy2, 32, 8, Color("#9c4034"))
				_fill(img, 0, cy2, 32, 2, Color("#c2604c"))
				_fill(img, 0, cy2, 32, 1, Color("#d68a72"))
				_fill(img, 0, cy2 + 6, 32, 2, Color("#5f231d"))
				for tile3 in 5:
					var tx3 := -off3 + tile3 * 8
					_fill(img, tx3, cy2 + 2, 1, 4, Color("#7d3129"))
					if hash2(v * 7 + course, tile3) > 0.62:
						_fill(img, tx3 + 2, cy2 + 2, 4, 2, Color("#b1523f"))
		"V":
			# the ridge along the top: a capping course standing proud of the
			# slope, bright where it faces the sky
			_fill(img, 0, 0, 32, 32, Color("#9c4034"))
			_fill(img, 0, 0, 32, 3, Color("#4a1e18"))
			_fill(img, 0, 3, 32, 6, Color("#d2735c"))
			_fill(img, 0, 3, 32, 2, Color("#e89178"))
			_fill(img, 0, 9, 32, 2, Color("#6a2a24"))
			for course in 3:
				var cy3 := 11 + course * 7
				_fill(img, 0, cy3, 32, 2, Color("#c2604c"))
				_fill(img, 0, cy3 + 5, 32, 2, Color("#5f231d"))
				for tile4 in 4:
					_fill(img, tile4 * 8 + (course % 2) * 4, cy3 + 2, 1, 3, Color("#7d3129"))
		"d":
			# set into the same wall, so the eave shadow across the top must line
			# up with the tiles either side or the front of the house breaks
			_fill(img, 0, 0, 32, 32, Color("#c9b189"))
			_fill(img, 0, 0, 32, 6, Color("#6d5a41"))
			_fill(img, 0, 6, 32, 2, Color("#8f7859"))
			_fill(img, 4, 8, 24, 24, Color("#5a3f22"))
			_fill(img, 6, 10, 20, 22, Color("#7b5230"))
			_fill(img, 6, 10, 20, 2, Color("#96663d"))
			_fill(img, 6, 10, 2, 22, Color("#8d5f39"))
			_fill(img, 24, 10, 2, 22, Color("#5f4023"))
			for panel in 2:
				var py3 := 13 + panel * 9
				_fill(img, 10, py3, 12, 7, Color("#6b4629"))
				_fill(img, 10, py3, 12, 1, Color("#8a5c35"))
				_fill(img, 10, py3 + 6, 12, 1, Color("#4d3319"))
			_fill(img, 20, 20, 3, 3, Color("#e8c25c"))
			_fill(img, 20, 20, 2, 2, Color("#fff0a8"))
			_fill(img, 2, 30, 28, 2, Color("#9a9086"))
		"_":
			# floorboards, with ends and nail heads
			_fill(img, 0, 0, 32, 32, Color("#9a7448"))
			for i in 4:
				var by6 := i * 8
				_fill(img, 0, by6, 32, 8, Color("#9a7448") if i % 2 == 0 else Color("#946f44"))
				_fill(img, 0, by6, 32, 1, Color("#b08a5c"))
				_fill(img, 0, by6 + 7, 32, 1, Color("#6f4e2b"))
				var seam := (i * 13 + v * 7) % 32
				_fill(img, seam, by6, 1, 8, Color("#6f4e2b"))
				_fill(img, seam + 3, by6 + 3, 1, 1, Color("#5e4126"))
				_fill(img, seam + 20, by6 + 4, 1, 1, Color("#5e4126"))
		"l":
			_fill(img, 0, 0, 32, 32, Color("#8d8578"))
			for a4 in 2:
				for b4 in 2:
					var tone4 := Color("#b0a898") if (a4 + b4) % 2 == 1 else Color("#9d9486")
					_fill(img, b4 * 16 + 2, a4 * 16 + 2, 12, 12, tone4)
					_fill(img, b4 * 16 + 2, a4 * 16 + 2, 12, 2, tone4.lightened(0.18))
					_fill(img, b4 * 16 + 2, a4 * 16 + 12, 12, 2, tone4.darkened(0.22))
		"D", "*":
			# cave floor: worn rock with grit and the odd pebble
			var cbase := Color("#4a3c48") if ch == "*" else Color("#332a33")
			_fill(img, 0, 0, 32, 32, cbase)
			for i in 6:
				_dith(img, int(r.call(i + 30) * 24), int(r.call(i + 36) * 26), 10, 5,
					cbase.lightened(0.12), cbase)
			for i in 18:
				var bx7 := int(r.call(i) * 30)
				var by7 := 2 + int(r.call(i + 8) * 27)
				_fill(img, bx7, by7, 2, 2, cbase.darkened(0.34))
				if i % 2 == 0:
					_fill(img, bx7, by7 - 1, 2, 1, cbase.lightened(0.28))
		"X":
			# cave rock, catching a little light on its upper left
			_fill(img, 0, 0, 32, 32, Color("#1d161c"))
			_ellipse(img, 16, 16, 16, 16, Color("#332734"))
			_ellipse(img, 14, 14, 12, 10, Color("#423444"))
			_ellipse(img, 12, 12, 8, 6, Color("#4f3f50"))
			_ellipse(img, 10, 10, 4, 3, Color("#5d4c60"))
			_fill(img, 8, 6, 4, 2, Color("#61506a"))
			_dith(img, 0, 24, 32, 8, Color("#241c26"), Color("#150f18"))
			for i in 6:
				_fill(img, int(r.call(i) * 28), 4 + int(r.call(i + 9) * 22), 2, 1,
					Color("#2a212c"))
		"b":
			# a bed: frame, sheet, turned-down top and a pillow
			_fill(img, 0, 0, 32, 32, Color("#9a7448"))
			_fill(img, 2, 2, 28, 28, Color("#6f4e2b"))
			_fill(img, 3, 3, 26, 26, Color("#c8c0b0"))
			_fill(img, 4, 4, 24, 9, Color("#e8e4dc"))
			_fill(img, 4, 12, 24, 2, Color("#a8a096"))
			_fill(img, 6, 5, 20, 6, Color("#f4f2ee"))
			_fill(img, 3, 3, 26, 1, Color("#e8e4dc"))
			_fill(img, 3, 28, 26, 1, Color("#a8a096"))
			_dith(img, 4, 20, 24, 8, Color("#bcb4a4"), Color("#c8c0b0"))
		"c":
			# a counter, seen from above with a lit front edge
			_fill(img, 0, 0, 32, 32, Color("#9a7448"))
			_fill(img, 0, 4, 32, 24, Color("#7b5230"))
			_fill(img, 0, 4, 32, 3, Color("#a97a4c"))
			_fill(img, 0, 25, 32, 3, Color("#4d3319"))
			for i in 4:
				_fill(img, i * 8 + 3, 9, 2, 14, Color("#6b4629"))
			_fill(img, 0, 7, 32, 1, Color("#c09a5e"))
		"t":
			_fill(img, 0, 0, 32, 32, Color("#9a7448"))
			_ellipse(img, 17, 19, 13, 10, Color("#4d3319"))
			_ellipse(img, 16, 17, 13, 10, Color("#8a5c35"))
			_ellipse(img, 14, 14, 9, 6, Color("#a97a4c"))
			_fill(img, 12, 9, 6, 2, Color("#c09a5e"))
		"p":
			# a barrel, hooped
			_fill(img, 0, 0, 32, 32, Color("#9a7448"))
			_ellipse(img, 17, 28, 11, 3, Color("#4d3319"))
			_fill(img, 6, 6, 21, 23, Color("#7b5230"))
			_fill(img, 6, 6, 6, 23, Color("#96663d"))
			_fill(img, 23, 6, 4, 23, Color("#5f4023"))
			for yy3 in [9, 17, 25]:
				_fill(img, 5, yy3, 23, 2, Color("#4d3319"))
				_fill(img, 5, yy3, 23, 1, Color("#8a6c47"))
			_ellipse(img, 16, 7, 10, 3, Color("#a97a4c"))
			_ellipse(img, 15, 6, 8, 2, Color("#c09a5e"))
		"g":
			# a headstone, leaning very slightly
			_fill(img, 0, 0, 32, 32, Color("#4a7a44"))
			_ellipse(img, 17, 28, 11, 3, Color("#3c6438"))
			_fill(img, 8, 8, 16, 21, Color("#6f6a64"))
			_fill(img, 8, 8, 5, 21, Color("#8d8880"))
			_fill(img, 20, 8, 4, 21, Color("#514c47"))
			_disc(img, 16, 9, 8, Color("#6f6a64"))
			_disc(img, 14, 8, 6, Color("#8d8880"))
			_fill(img, 12, 16, 8, 2, Color("#514c47"))
			_fill(img, 15, 13, 2, 8, Color("#514c47"))
			_fill(img, 6, 27, 20, 3, Color("#5b5650"))
		"S":
			# a signpost: a board on a stake with writing scratched on it
			_fill(img, 0, 0, 32, 32, Color("#4a7a44"))
			_ellipse(img, 17, 29, 8, 2, Color("#3c6438"))
			_fill(img, 14, 16, 4, 14, Color("#5f4526"))
			_fill(img, 14, 16, 2, 14, Color("#8a6a40"))
			_fill(img, 3, 5, 26, 13, Color("#4d3319"))
			_fill(img, 4, 6, 24, 11, Color("#a3814f"))
			_fill(img, 4, 6, 24, 2, Color("#c09a5e"))
			for i in 3:
				_fill(img, 7, 9 + i * 3, 14 - i * 3, 1, Color("#6b4e2b"))
		"w":
			# a well: a stone ring with dark water and a little roof beam
			_fill(img, 0, 0, 32, 32, Color("#4a7a44"))
			_ellipse(img, 17, 25, 13, 6, Color("#3c6438"))
			_ellipse(img, 16, 22, 13, 8, Color("#5b5650"))
			_ellipse(img, 15, 20, 12, 7, Color("#8d8578"))
			_ellipse(img, 16, 21, 8, 4, Color("#1a2430"))
			_ellipse(img, 15, 20, 6, 3, Color("#101820"))
			_fill(img, 7, 4, 3, 16, Color("#6b4e2b"))
			_fill(img, 23, 4, 3, 16, Color("#6b4e2b"))
			_fill(img, 5, 2, 23, 4, Color("#8a3830"))
			_fill(img, 5, 2, 23, 2, Color("#a04438"))
		"C":
			# a mouth in the rock, dark all the way in
			_fill(img, 0, 0, 32, 32, Color("#6b645a"))
			for i in 32:
				var half2 := int((i + 1) / 2) + 2
				_fill(img, maxi(0, 16 - half2), i, half2, 1, Color("#7d766a"))
				_fill(img, 16, i, half2, 1, Color("#4e483f"))
			_ellipse(img, 16, 24, 14, 18, Color("#120e14"))
			_ellipse(img, 16, 26, 10, 14, Color("#050307"))
			_fill(img, 4, 6, 24, 2, Color("#8d8578"))
			_fill(img, 6, 4, 20, 2, Color("#9a9186"))
		"m":
			_fill(img, 0, 0, 32, 32, Color("#000000"))
		_:
			_fill(img, 0, 0, 32, 32, Color("#4a7a44"))
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
	var chars := ". , \" f = o q B ~ T P ^ r % F # W n R V d _ l D * X b c t p g S w C m".split(" ")
	for ch in chars:
		var variants := []
		for v in variant_count(ch):
			variants.append(_tile_image(ch, v))
		_atlas[ch] = variants
	# A tile with no entry here silently falls back to grass when it is drawn,
	# which is how every house came to have a lawn across its bottom courses.
	# Anything the world can be solid on has to have been given art.
	for ch in SOLID:
		if not _atlas.has(ch):
			push_error("tile '%s' has no art and will be drawn as grass" % ch)
	return _atlas


## How many different drawings a tile gets. Things you see in bulk and in the
## open -- rock, trees, undergrowth -- need more than four or a hillside is one
## boulder printed forty times.
static func variant_count(ch: String) -> int:
	match ch:
		"r", "T", "P", "^", "%", "X":
			return 12
		".", "f", ",", "\"", "=", "q", "D", "*":
			return 6
	return 4


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

	## A house seen from slightly above and in front: a ridge, a roof, and a
	## front wall two tiles tall with the door in the bottom of it. One row of
	## wall under three of roof reads as a shed with a big hat.
	func building(x: int, y: int, bw: int, bh: int, door_off: int) -> Vector2i:
		var wall_rows: int = 2 if bh >= 4 else 1
		var roof_rows: int = maxi(0, bh - 1 - wall_rows)
		rect(x, y, bw, 1, "V")
		if roof_rows > 0:
			rect(x, y + 1, bw, roof_rows, "R")
		rect(x, y + bh - wall_rows, bw, 1, "W")
		if wall_rows > 1:
			rect(x, y + bh - wall_rows + 1, bw, wall_rows - 1, "n")
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


## Dig a round chamber out of solid rock.
static func carve(m: GameMap, x: int, y: int, r: int) -> void:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dy * dy <= r * r + 1:
				m.set_tile(x + dx, y + dy, "D")


## Dig chambers at every point and corridors between them, in order. Caves are
## generated this way rather than from noise because a chain is connected by
## construction -- there is no chance of a floor whose stairs are walled off.
static func tunnel(m: GameMap, pts: Array, r: int) -> void:
	for i in range(1, pts.size()):
		var a: Vector2i = pts[i - 1]
		var b: Vector2i = pts[i]
		var x := a.x
		var y := a.y
		while x != b.x:
			carve(m, x, y, r)
			x += 1 if x < b.x else -1
		while y != b.y:
			carve(m, x, y, r)
			y += 1 if y < b.y else -1
		carve(m, b.x, b.y, r + 1)


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
	return int(hash2(x, y) * float(maxi(1, count))) % maxi(1, count)


## Kept so callers that still ask for it do not break; nothing is composed now.
static func prerender(_m: GameMap) -> void:
	pass
