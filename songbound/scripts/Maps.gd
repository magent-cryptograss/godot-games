class_name Maps
extends RefCounted
## Maps are built in code rather than authored as TileSets: fewer moving parts,
## and the overworld is generated from a fixed seed so it is the same every run.
##
## Tiles are rendered into a small atlas once (four variants each, picked by a
## coordinate hash so a field of grass is not visibly tiled), then whole maps are
## composed with blit_rect, which is far faster than per-pixel work in GDScript.

const TS := 48

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
## Tiles are 48x48. They were 16, then 32. Each step is spent on structure that
## would not fit before rather than on the same drawing enlarged: at 16 a wall
## could have a noise field, at 32 it could have courses, at 48 the courses can
## have half-stones at their ends and mortar that varies.
static func _tile_image(ch: String, v: int) -> Image:
	var img := Image.create(TS, TS, false, Image.FORMAT_RGBA8)
	img.fill(Color("#4a7a44"))
	var r := func(i: int) -> float: return hash2(v * 31 + i, v * 17 + i * 7)
	match ch:
		".", "f":
			# Grass in four tones: a body, broad soft patches drifting through
			# it, and blades standing up with lit tips. Scattered by hash and
			# never banded by row -- banding draws the tile grid across the map.
			_fill(img, 0, 0, 48, 48, Color("#4a7a44"))
			for i in 14:
				var px := int(r.call(i) * 41)
				var py := int(r.call(i + 9) * 41)
				_fill(img, px, py, 9, 6, Color("#436e3e") if i % 2 == 0 else Color("#537f4a"))
			for i in 8:
				_dith(img, int(r.call(i + 20) * 36), int(r.call(i + 26) * 40), 12, 6,
					Color("#537f4a"), Color("#4a7a44"))
			for i in 34:
				var bx := 1 + int(r.call(i + 3) * 45)
				var by := 3 + int(r.call(i + 17) * 40)
				var bh := 4 + int(r.call(i + 60) * 3)
				_fill(img, bx, by, 1, bh, Color("#3b6537"))
				_fill(img, bx, by, 1, 2, Color("#5b8a52"))
				_fill(img, bx, by, 1, 1, Color("#6d9b60"))
			if ch == "f":
				var fc: Color = [Color("#e8d27a"), Color("#d9dbe8"), Color("#c98fb4"),
					Color("#e0a05c")][v % 4]
				for pos in [Vector2i(12, 16), Vector2i(31, 27), Vector2i(21, 36),
						Vector2i(37, 11), Vector2i(7, 31)]:
					_fill(img, pos.x, pos.y + 4, 1, 5, Color("#3b6537"))
					_fill(img, pos.x - 2, pos.y - 1, 5, 5, fc.darkened(0.45))
					_fill(img, pos.x - 1, pos.y, 3, 3, fc)
					_fill(img, pos.x, pos.y, 1, 1, fc.lightened(0.35))
		"\"":
			# dry grass: the same ground with the green gone and bare earth
			# showing through
			_fill(img, 0, 0, 48, 48, Color("#7f8a4e"))
			for i in 15:
				_fill(img, int(r.call(i) * 41), int(r.call(i + 5) * 41), 8, 5,
					Color("#74804a"))
			for i in 9:
				_dith(img, int(r.call(i + 14) * 36), int(r.call(i + 19) * 40), 12, 6,
					Color("#8a7a52"), Color("#7f8a4e"))
			for i in 26:
				var bx2 := int(r.call(i + 30) * 46)
				var by2 := int(r.call(i + 40) * 43)
				_fill(img, bx2, by2, 1, 4, Color("#6d7742"))
				_fill(img, bx2, by2, 1, 1, Color("#9aa463"))
		",":
			# deep grass, tall enough to lose things in
			_fill(img, 0, 0, 48, 48, Color("#3a6339"))
			for i in 12:
				_fill(img, int(r.call(i + 30) * 41), int(r.call(i + 37) * 41), 9, 6,
					Color("#345a34"))
			for i in 52:
				var bx3 := int(r.call(i) * 47)
				var by3 := int(r.call(i + 5) * 34)
				var hgt := 10 + int(r.call(i + 21) * 6)
				_fill(img, bx3, by3, 1, hgt, Color("#2a4f2e"))
				_fill(img, bx3, by3, 1, 4, Color("#46764a"))
				_fill(img, bx3, by3, 1, 2, Color("#5f9663"))
		"=", "q":
			# Packed earth: a body, a rut worn down the middle where the feet
			# go, and stones pressed into it, each with a lit top and a dark
			# underside.
			var road := Color("#9c8258") if ch == "=" else Color("#8a7048")
			_fill(img, 0, 0, 48, 48, road)
			_fill(img, 0, 16, 48, 17, road.darkened(0.10))
			_dith(img, 0, 12, 48, 5, road.darkened(0.10), road)
			_dith(img, 0, 32, 48, 5, road.darkened(0.10), road)
			for i in 26:
				var bx4 := 1 + int(r.call(i) * 43)
				var by4 := 2 + int(r.call(i + 6) * 41)
				var sw := 2 + int(r.call(i + 18) * 4)
				_fill(img, bx4, by4, sw, 4, road.darkened(0.30))
				_fill(img, bx4, by4, sw, 1, road.lightened(0.26))
				_fill(img, bx4, by4 + 3, sw, 1, road.darkened(0.44))
			for i in 10:
				_fill(img, int(r.call(i + 41) * 46), int(r.call(i + 47) * 46), 2, 1,
					Color("#5d7a49"))
		"o":
			# Laid stone in a proper bond: courses offset by half, half-stones at
			# the ends of every other one, each slab lit on top and shaded below.
			_fill(img, 0, 0, 48, 48, Color("#4f4d4b"))
			for row in 4:
				var off := 0 if row % 2 == 0 else 12
				for col in 3:
					var sx := -off + col * 24
					var st := Color("#7d7b76") if (row + col) % 2 == 0 else Color("#74726d")
					if hash2(v * 13 + row, col) > 0.78:
						st = Color("#867f77")
					_fill(img, sx, row * 12, 23, 11, st)
					_fill(img, sx, row * 12, 23, 2, st.lightened(0.18))
					_fill(img, sx, row * 12 + 9, 23, 2, st.darkened(0.26))
					_fill(img, sx, row * 12, 2, 11, st.lightened(0.08))
					for k in 3:
						if hash2(v * 5 + row * 3 + col, k) > 0.62:
							_fill(img, sx + 4 + k * 6, row * 12 + 4 + k, 2, 1,
								st.darkened(0.18))
		"B":
			# a plank bridge over water, with nail heads and end grain
			_fill(img, 0, 0, 48, 48, Color("#22528a"))
			_fill(img, 0, 3, 48, 42, Color("#a07840"))
			for i in 5:
				var py2 := 3 + i * 8
				_fill(img, 0, py2, 48, 7, Color("#a07840"))
				_fill(img, 0, py2, 48, 2, Color("#c09a5e"))
				_fill(img, 0, py2 + 6, 48, 1, Color("#6b4a24"))
				_fill(img, 5, py2 + 3, 2, 2, Color("#5e3f1c"))
				_fill(img, 41, py2 + 3, 2, 2, Color("#5e3f1c"))
				_fill(img, 22, py2 + 2, 1, 4, Color("#8a6438"))
			_fill(img, 0, 0, 48, 3, Color("#c9a05e"))
			_fill(img, 0, 45, 48, 3, Color("#5e3f1c"))
		"~":
			# three wave scales, with the light catching along the crests
			var deep := Color("#1d4a80")
			var mid := Color("#22528a")
			var topw := Color("#2f6099")
			_fill(img, 0, 0, 48, 48, mid)
			_dith(img, 0, 0, 48, 15, topw, mid)
			_dith(img, 0, 30, 48, 18, mid, deep)
			for i in 10:
				var bx5 := int(r.call(i) * 36)
				var by5 := 4 + int(r.call(i + 7) * 38)
				_fill(img, bx5, by5, 12, 2, Color("#4f8fc4"))
				_fill(img, bx5 + 3, by5 - 2, 6, 2, Color("#79b4dd"))
				_fill(img, bx5 + 5, by5 - 3, 3, 1, Color("#a5d2ee"))
			for i in 6:
				_fill(img, int(r.call(i + 30) * 44), int(r.call(i + 36) * 44), 3, 1,
					Color("#8fc4e4"))
		"T":
			# A canopy of overlapping lobes with branches showing under it, lit
			# from the top left and sat on the ground with a cast shadow. Every
			# measurement out of the variant, so a wood is not one tree printed
			# forty times.
			_fill(img, 0, 0, 48, 48, Color("#4a7a44"))
			var tx4 := 21 + int(r.call(1) * 7)
			var cw := 15 + int(r.call(2) * 6)
			var ct := 18 + int(r.call(3) * 6)
			_ellipse(img, tx4 + 4, 42, cw + 2, 6, Color("#3c6438"))
			_fill(img, tx4, ct + 6, 7, 38 - ct, Color("#4a3018"))
			_fill(img, tx4, ct + 6, 3, 38 - ct, Color("#6b4823"))
			_fill(img, tx4 + 6, ct + 6, 1, 38 - ct, Color("#33200f"))
			# branches, which is what 48 pixels buys over 32
			_fill(img, tx4 - 5, ct + 9, 6, 2, Color("#4a3018"))
			_fill(img, tx4 + 6, ct + 13, 6, 2, Color("#4a3018"))
			_disc(img, tx4 + 3, ct, cw + 2, Color("#1d4423"))
			for k in 5:
				_disc(img, tx4 + 3 + int((r.call(k + 10) - 0.5) * cw * 1.5),
					ct + int((r.call(k + 20) - 0.5) * cw), 7 + int(r.call(k + 30) * 5),
					Color("#2b6231"))
			for k in 4:
				_disc(img, tx4 + int((r.call(k + 40) - 0.5) * cw),
					ct - 3 + int((r.call(k + 45) - 0.5) * cw * 0.8),
					4 + int(r.call(k + 50) * 4), Color("#3a7a3e"))
			_disc(img, tx4 - cw + 6, ct - cw + 7, 6, Color("#4d9350"))
			_fill(img, tx4 - cw + 3, ct - cw + 4, 6, 3, Color("#63a862"))
			_dith(img, tx4 - cw + 3, ct + 5, cw * 2 - 6, 9,
				Color("#1d4423"), Color("#2b6231"))
			for i in 18:
				_fill(img, 6 + int(r.call(i) * 36), 6 + int(r.call(i + 9) * 30), 2, 1,
					Color("#4d9350"))
		"P":
			_fill(img, 0, 0, 48, 48, Color("#4a7a44"))
			var px5 := 21 + int(r.call(1) * 7)
			var top := 2 + int(r.call(2) * 7)
			var spread := 6 + int(r.call(3) * 3)
			_ellipse(img, px5 + 6, 45, 15, 4, Color("#3c6438"))
			_fill(img, px5, 36, 7, 12, Color("#42301a"))
			_fill(img, px5, 36, 3, 12, Color("#63421f"))
			# skirts of needles, lit along the top and dark underneath so the
			# tiers read as tiers rather than as stripes
			for i in 5:
				var wd := 9 + i * spread
				var yy := top + i * 8
				var xx := px5 + 3 - (wd >> 1)
				_fill(img, xx, yy, wd, 9, Color("#1b4522"))
				_fill(img, xx, yy, wd, 3, Color("#2e6a33"))
				_fill(img, xx, yy, maxi(1, int(wd / 2)), 2, Color("#41894a"))
				_fill(img, xx, yy + 8, wd, 1, Color("#12301a"))
				for k in 3:
					_fill(img, xx + 2 + k * int(wd / 3), yy + 2, 1, 4, Color("#153a1c"))
			_fill(img, px5 + 1, top - 3, 5, 7, Color("#2e6a33"))
			_fill(img, px5 + 1, top - 3, 2, 5, Color("#41894a"))
		"^":
			# a peak with a lit face, a shaded face, snow, and gullies down it
			_fill(img, 0, 0, 48, 48, Color("#6b645a"))
			for i in 48:
				var half := int((i + 1) / 2) + 3
				_fill(img, maxi(0, 24 - half), i, half, 1, Color("#8d8578"))
				_fill(img, 24, i, half, 1, Color("#4e483f"))
			if v % 3 != 2:
				var sx5 := 15 + int(r.call(1) * 9)
				_fill(img, sx5, 3, 12, 8, Color("#d8d4cc"))
				_fill(img, sx5 + 3, 1, 8, 5, Color("#f0ece4"))
				_fill(img, sx5 + 6, 6, 6, 6, Color("#b4aea4"))
			for i in 8:
				var cy := 12 + int(r.call(i) * 30)
				var gx := 24 - int(r.call(i + 8) * 10)
				_fill(img, gx, cy, 2, 4 + int(r.call(i + 16) * 5), Color("#5d564d"))
				_fill(img, 26 + int(r.call(i + 24) * 8), cy, 1, 4, Color("#413b34"))
		"r":
			# Boulders sitting on the ground, and no two the same: size, lean and
			# how many of them all come out of the variant.
			_fill(img, 0, 0, 48, 48, Color("#4a7a44"))
			if v % 4 == 3:
				for k in 2:
					var kx := 14 + k * 19 + int(r.call(k) * 4)
					var ky := 24 + k * 7
					var kr := 8 + int(r.call(k + 4) * 4)
					_ellipse(img, kx + 2, ky + kr - 1, kr + 3, 4, Color("#3c6438"))
					_ellipse(img, kx, ky, kr + 1, kr, Color("#4f4941"))
					_ellipse(img, kx - 2, ky - 2, kr, kr - 1, Color("#6b645a"))
					_ellipse(img, kx - 3, ky - 3, kr - 3, kr - 4, Color("#847c70"))
			else:
				var cx2 := 21 + int(r.call(1) * 7)
				var cy2 := 24 + int(r.call(2) * 6)
				var rx := 15 + int(r.call(3) * 6)
				var ry := 12 + int(r.call(4) * 6)
				_ellipse(img, cx2 + 2, cy2 + ry - 1, rx + 3, 5, Color("#3c6438"))
				_ellipse(img, cx2, cy2, rx, ry, Color("#4f4941"))
				_ellipse(img, cx2 - 2, cy2 - 3, rx - 3, ry - 3, Color("#6b645a"))
				_ellipse(img, cx2 - 4, cy2 - 6, rx - 8, ry - 8, Color("#847c70"))
				_ellipse(img, cx2 - 6, cy2 - 9, rx - 12, ry - 12, Color("#9a9186"))
				_dith(img, cx2 - rx + 3, cy2 + 3, rx * 2 - 9, 9,
					Color("#4f4941"), Color("#6b645a"))
				for k in 5:
					_fill(img, cx2 - 6 + int(r.call(k + 9) * 15),
						cy2 - 5 + int(r.call(k + 13) * 12), 4, 1, Color("#3f3a34"))
		"%":
			_fill(img, 0, 0, 48, 48, Color("#4a7a44"))
			_ellipse(img, 25, 41, 18, 5, Color("#3c6438"))
			for k in 4:
				_disc(img, 14 + int(r.call(k) * 21), 21 + int(r.call(k + 5) * 12),
					9 + int(r.call(k + 9) * 6), Color("#22522a"))
			for k in 4:
				_disc(img, 14 + int(r.call(k + 12) * 18), 19 + int(r.call(k + 16) * 10),
					6 + int(r.call(k + 20) * 4), Color("#2f6c34"))
			_disc(img, 15 + int(r.call(24) * 9), 16 + int(r.call(25) * 6), 6,
				Color("#43884a"))
			for i in 12:
				_fill(img, 8 + int(r.call(i + 30) * 32), 12 + int(r.call(i + 40) * 24),
					2, 1, Color("#57a45c"))
		"F":
			# a rail fence: posts with grain, two rails, and a shadow beneath
			_fill(img, 0, 0, 48, 48, Color("#4a7a44"))
			for px2 in [6, 33]:
				_fill(img, px2, 12, 8, 33, Color("#5f4526"))
				_fill(img, px2, 12, 3, 33, Color("#8a6a40"))
				_fill(img, px2, 12, 8, 2, Color("#a3814f"))
				_fill(img, px2 + 5, 16, 1, 24, Color("#4a3419"))
			for yy2 in [18, 33]:
				_fill(img, 0, yy2, 48, 6, Color("#6b4e2b"))
				_fill(img, 0, yy2, 48, 2, Color("#9a7647"))
				_fill(img, 0, yy2 + 5, 48, 1, Color("#4a3419"))
			_ellipse(img, 24, 46, 20, 2, Color("#3c6438"))
		"#":
			# courses of stone with half-stones at alternate ends
			_fill(img, 0, 0, 48, 48, Color("#463f3a"))
			for row2 in 4:
				var off2 := 0 if row2 % 2 == 0 else 9
				for col2 in 4:
					var sx2 := -off2 + col2 * 18
					var tone := Color("#8b837c") if hash2(v * 9 + row2, col2) > 0.5 else Color("#7b736c")
					_fill(img, sx2, row2 * 12, 17, 11, tone)
					_fill(img, sx2, row2 * 12, 17, 2, tone.lightened(0.18))
					_fill(img, sx2, row2 * 12 + 9, 17, 2, tone.darkened(0.3))
					_fill(img, sx2, row2 * 12, 2, 11, tone.lightened(0.08))
					if hash2(v + row2, col2 * 7) > 0.7:
						_fill(img, sx2 + 5, row2 * 12 + 5, 5, 2, tone.darkened(0.14))
		"W":
			# The front of a building. The dark band across the top is the shadow
			# the overhanging roof throws on it, and it is the reason the roof
			# reads as being in front of the wall rather than beside it.
			var plaster := Color("#c9b189")
			_fill(img, 0, 0, 48, 48, plaster)
			_fill(img, 0, 36, 48, 12, Color("#a08a66"))
			_dith(img, 0, 30, 48, 6, Color("#a08a66"), plaster)
			_fill(img, 0, 0, 48, 9, Color("#6d5a41"))
			_fill(img, 0, 9, 48, 3, Color("#8f7859"))
			_fill(img, 0, 12, 3, 36, Color("#6b4c2e"))
			_fill(img, 45, 12, 3, 36, Color("#6b4c2e"))
			if v % 2 == 0:
				_fill(img, 12, 18, 24, 21, Color("#5a3f22"))
				_fill(img, 15, 21, 18, 15, Color("#3c4a63"))
				_fill(img, 15, 21, 9, 7, Color("#5d7194"))
				_fill(img, 15, 21, 6, 3, Color("#8fa4c4"))
				_fill(img, 23, 21, 2, 15, Color("#5a3f22"))
				_fill(img, 15, 27, 18, 2, Color("#5a3f22"))
				_fill(img, 10, 38, 28, 3, Color("#8a6c47"))
			else:
				_fill(img, 9, 21, 3, 24, Color("#a58f6b"))
				_fill(img, 36, 27, 3, 18, Color("#a58f6b"))
		"n":
			# the lower course of the front wall: no eave shadow, that belongs
			# only on the row the roof actually overhangs
			var plaster2 := Color("#c9b189")
			_fill(img, 0, 0, 48, 48, plaster2)
			_fill(img, 0, 33, 48, 15, Color("#a08a66"))
			_dith(img, 0, 27, 48, 6, Color("#a08a66"), plaster2)
			_fill(img, 0, 0, 3, 48, Color("#6b4c2e"))
			_fill(img, 45, 0, 3, 48, Color("#6b4c2e"))
			_fill(img, 0, 44, 48, 4, Color("#5a4527"))
			_fill(img, 0, 42, 48, 2, Color("#8a7a5c"))
			if v % 3 == 0:
				_fill(img, 15, 9, 18, 18, Color("#5a3f22"))
				_fill(img, 18, 12, 12, 12, Color("#3c4a63"))
				_fill(img, 18, 12, 6, 6, Color("#5d7194"))
				_fill(img, 13, 27, 22, 3, Color("#8a6c47"))
			else:
				_fill(img, 12, 6, 3, 33, Color("#a58f6b"))
				_fill(img, 33, 15, 3, 24, Color("#a58f6b"))
		"R":
			# Courses of shingles with rounded butts, each lit along its upper
			# edge with a dark seam beneath, offset course to course so the
			# joins do not line up into a grid.
			_fill(img, 0, 0, 48, 48, Color("#9c4034"))
			for course in 4:
				var cy2 := course * 12
				var off3 := 0 if course % 2 == 0 else 6
				_fill(img, 0, cy2, 48, 12, Color("#9c4034"))
				_fill(img, 0, cy2, 48, 3, Color("#c2604c"))
				_fill(img, 0, cy2, 48, 1, Color("#d68a72"))
				_fill(img, 0, cy2 + 9, 48, 3, Color("#5f231d"))
				for tile3 in 5:
					var tx3 := -off3 + tile3 * 12
					_fill(img, tx3, cy2 + 3, 2, 6, Color("#7d3129"))
					# the rounded butt, which is what tells a shingle from a plank
					_fill(img, tx3 + 2, cy2 + 9, 8, 1, Color("#5f231d"))
					if hash2(v * 7 + course, tile3) > 0.62:
						_fill(img, tx3 + 3, cy2 + 3, 6, 3, Color("#b1523f"))
		"V":
			# the ridge along the top: a capping course standing proud of the
			# slope, bright where it faces the sky
			_fill(img, 0, 0, 48, 48, Color("#9c4034"))
			_fill(img, 0, 0, 48, 4, Color("#4a1e18"))
			_fill(img, 0, 4, 48, 9, Color("#d2735c"))
			_fill(img, 0, 4, 48, 3, Color("#e89178"))
			_fill(img, 0, 13, 48, 3, Color("#6a2a24"))
			for course in 3:
				var cy3 := 16 + course * 11
				_fill(img, 0, cy3, 48, 3, Color("#c2604c"))
				_fill(img, 0, cy3 + 8, 48, 3, Color("#5f231d"))
				for tile4 in 4:
					_fill(img, tile4 * 12 + (course % 2) * 6, cy3 + 3, 2, 5,
						Color("#7d3129"))
		"d":
			# set into the same wall, so the eave shadow across the top has to
			# line up with the tiles either side
			_fill(img, 0, 0, 48, 48, Color("#c9b189"))
			_fill(img, 0, 0, 48, 9, Color("#6d5a41"))
			_fill(img, 0, 9, 48, 3, Color("#8f7859"))
			_fill(img, 6, 12, 36, 36, Color("#5a3f22"))
			_fill(img, 9, 15, 30, 33, Color("#7b5230"))
			_fill(img, 9, 15, 30, 3, Color("#96663d"))
			_fill(img, 9, 15, 3, 33, Color("#8d5f39"))
			_fill(img, 36, 15, 3, 33, Color("#5f4023"))
			for panel in 2:
				var py3 := 20 + panel * 13
				_fill(img, 15, py3, 18, 10, Color("#6b4629"))
				_fill(img, 15, py3, 18, 2, Color("#8a5c35"))
				_fill(img, 15, py3 + 9, 18, 1, Color("#4d3319"))
			_fill(img, 30, 30, 4, 4, Color("#e8c25c"))
			_fill(img, 30, 30, 2, 2, Color("#fff0a8"))
			_fill(img, 3, 45, 42, 3, Color("#9a9086"))
		"_":
			# floorboards with ends, grain and nail heads
			_fill(img, 0, 0, 48, 48, Color("#9a7448"))
			for i in 4:
				var by6 := i * 12
				_fill(img, 0, by6, 48, 12, Color("#9a7448") if i % 2 == 0 else Color("#946f44"))
				_fill(img, 0, by6, 48, 2, Color("#b08a5c"))
				_fill(img, 0, by6 + 10, 48, 2, Color("#6f4e2b"))
				var seam := (i * 19 + v * 11) % 48
				_fill(img, seam, by6, 2, 12, Color("#6f4e2b"))
				_fill(img, seam + 4, by6 + 4, 2, 2, Color("#5e4126"))
				_fill(img, seam + 30, by6 + 6, 2, 2, Color("#5e4126"))
				_fill(img, seam + 12, by6 + 5, 10, 1, Color("#8a6a42"))
		"l":
			_fill(img, 0, 0, 48, 48, Color("#8d8578"))
			for a4 in 2:
				for b4 in 2:
					var tone4 := Color("#b0a898") if (a4 + b4) % 2 == 1 else Color("#9d9486")
					_fill(img, b4 * 24 + 3, a4 * 24 + 3, 18, 18, tone4)
					_fill(img, b4 * 24 + 3, a4 * 24 + 3, 18, 3, tone4.lightened(0.18))
					_fill(img, b4 * 24 + 3, a4 * 24 + 18, 18, 3, tone4.darkened(0.22))
		"D", "*":
			# cave floor: worn rock with grit, pebbles and damp patches
			var cbase := Color("#4a3c48") if ch == "*" else Color("#332a33")
			_fill(img, 0, 0, 48, 48, cbase)
			for i in 9:
				_dith(img, int(r.call(i + 30) * 36), int(r.call(i + 36) * 40), 15, 8,
					cbase.lightened(0.12), cbase)
			for i in 34:
				var bx7 := int(r.call(i) * 45)
				var by7 := 2 + int(r.call(i + 8) * 42)
				_fill(img, bx7, by7, 3, 2, cbase.darkened(0.34))
				if i % 2 == 0:
					_fill(img, bx7, by7 - 1, 3, 1, cbase.lightened(0.28))
		"X":
			# cave rock, catching a little light on its upper left
			_fill(img, 0, 0, 48, 48, Color("#1d161c"))
			_ellipse(img, 24, 24, 24, 24, Color("#332734"))
			_ellipse(img, 21, 21, 18, 15, Color("#423444"))
			_ellipse(img, 18, 18, 12, 9, Color("#4f3f50"))
			_ellipse(img, 15, 15, 6, 5, Color("#5d4c60"))
			_fill(img, 12, 9, 6, 3, Color("#61506a"))
			_dith(img, 0, 36, 48, 12, Color("#241c26"), Color("#150f18"))
			for i in 10:
				_fill(img, int(r.call(i) * 42), 6 + int(r.call(i + 9) * 34), 3, 2,
					Color("#2a212c"))
		"b":
			# a bed: frame, sheet, turned-down top, pillow and a fold
			_fill(img, 0, 0, 48, 48, Color("#9a7448"))
			_fill(img, 3, 3, 42, 42, Color("#6f4e2b"))
			_fill(img, 5, 5, 38, 38, Color("#c8c0b0"))
			_fill(img, 7, 7, 34, 13, Color("#e8e4dc"))
			_fill(img, 7, 19, 34, 3, Color("#a8a096"))
			_fill(img, 10, 9, 28, 9, Color("#f4f2ee"))
			_fill(img, 5, 5, 38, 2, Color("#e8e4dc"))
			_fill(img, 5, 41, 38, 2, Color("#a8a096"))
			_dith(img, 7, 30, 34, 11, Color("#bcb4a4"), Color("#c8c0b0"))
			_fill(img, 7, 34, 34, 2, Color("#b0a898"))
		"c":
			# a counter with a lit front edge and panelled front
			_fill(img, 0, 0, 48, 48, Color("#9a7448"))
			_fill(img, 0, 6, 48, 36, Color("#7b5230"))
			_fill(img, 0, 6, 48, 4, Color("#a97a4c"))
			_fill(img, 0, 38, 48, 4, Color("#4d3319"))
			for i in 4:
				_fill(img, i * 12 + 4, 14, 3, 21, Color("#6b4629"))
				_fill(img, i * 12 + 4, 14, 1, 21, Color("#8a5c35"))
			_fill(img, 0, 10, 48, 2, Color("#c09a5e"))
		"t":
			_fill(img, 0, 0, 48, 48, Color("#9a7448"))
			_ellipse(img, 26, 29, 19, 15, Color("#4d3319"))
			_ellipse(img, 24, 26, 19, 15, Color("#8a5c35"))
			_ellipse(img, 21, 21, 13, 9, Color("#a97a4c"))
			_fill(img, 18, 13, 9, 3, Color("#c09a5e"))
		"p":
			# a barrel, hooped, with staves
			_fill(img, 0, 0, 48, 48, Color("#9a7448"))
			_ellipse(img, 26, 42, 17, 4, Color("#4d3319"))
			_fill(img, 9, 9, 31, 35, Color("#7b5230"))
			_fill(img, 9, 9, 9, 35, Color("#96663d"))
			_fill(img, 34, 9, 6, 35, Color("#5f4023"))
			for k in 4:
				_fill(img, 13 + k * 6, 12, 1, 29, Color("#66452a"))
			for yy3 in [14, 26, 38]:
				_fill(img, 8, yy3, 33, 3, Color("#4d3319"))
				_fill(img, 8, yy3, 33, 1, Color("#8a6c47"))
			_ellipse(img, 24, 11, 15, 4, Color("#a97a4c"))
			_ellipse(img, 22, 9, 12, 3, Color("#c09a5e"))
		"g":
			# a headstone with a carved face, leaning very slightly
			_fill(img, 0, 0, 48, 48, Color("#4a7a44"))
			_ellipse(img, 26, 42, 17, 4, Color("#3c6438"))
			_fill(img, 12, 12, 24, 32, Color("#6f6a64"))
			_fill(img, 12, 12, 8, 32, Color("#8d8880"))
			_fill(img, 30, 12, 6, 32, Color("#514c47"))
			_disc(img, 24, 14, 12, Color("#6f6a64"))
			_disc(img, 21, 12, 9, Color("#8d8880"))
			_fill(img, 18, 24, 12, 3, Color("#514c47"))
			_fill(img, 22, 19, 3, 13, Color("#514c47"))
			_fill(img, 16, 34, 16, 2, Color("#5b5650"))
			_fill(img, 9, 41, 30, 4, Color("#5b5650"))
		"S":
			# a signpost: a board on a stake with writing scratched on it
			_fill(img, 0, 0, 48, 48, Color("#4a7a44"))
			_ellipse(img, 26, 44, 12, 3, Color("#3c6438"))
			_fill(img, 21, 24, 6, 21, Color("#5f4526"))
			_fill(img, 21, 24, 3, 21, Color("#8a6a40"))
			_fill(img, 4, 7, 40, 20, Color("#4d3319"))
			_fill(img, 6, 9, 36, 16, Color("#a3814f"))
			_fill(img, 6, 9, 36, 3, Color("#c09a5e"))
			for i in 4:
				_fill(img, 10, 14 + i * 4, 22 - i * 4, 2, Color("#6b4e2b"))
		"w":
			# a well: a stone ring, dark water, and a roof beam over it
			_fill(img, 0, 0, 48, 48, Color("#4a7a44"))
			_ellipse(img, 26, 38, 19, 9, Color("#3c6438"))
			_ellipse(img, 24, 33, 20, 12, Color("#5b5650"))
			_ellipse(img, 22, 30, 18, 11, Color("#8d8578"))
			for k in 8:
				_fill(img, 6 + k * 5, 26 + int(r.call(k) * 3), 4, 3, Color("#7a736a"))
			_ellipse(img, 24, 31, 12, 6, Color("#1a2430"))
			_ellipse(img, 23, 30, 9, 4, Color("#101820"))
			_fill(img, 10, 6, 5, 24, Color("#6b4e2b"))
			_fill(img, 34, 6, 5, 24, Color("#6b4e2b"))
			_fill(img, 7, 2, 35, 6, Color("#8a3830"))
			_fill(img, 7, 2, 35, 3, Color("#a04438"))
		"C":
			# a mouth in the rock, dark all the way in
			_fill(img, 0, 0, 48, 48, Color("#6b645a"))
			for i in 48:
				var half2 := int((i + 1) / 2) + 3
				_fill(img, maxi(0, 24 - half2), i, half2, 1, Color("#7d766a"))
				_fill(img, 24, i, half2, 1, Color("#4e483f"))
			_ellipse(img, 24, 36, 21, 27, Color("#120e14"))
			_ellipse(img, 24, 39, 15, 21, Color("#050307"))
			_fill(img, 6, 9, 36, 3, Color("#8d8578"))
			_fill(img, 9, 6, 30, 3, Color("#9a9186"))
		"m":
			_fill(img, 0, 0, 48, 48, Color("#000000"))
		_:
			_fill(img, 0, 0, 48, 48, Color("#4a7a44"))
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
