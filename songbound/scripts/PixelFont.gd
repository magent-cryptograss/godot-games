class_name PixelFont
extends RefCounted
## The 5x7 bitmap font from the HTML build, drawn with rects.
##
## Godot's default font is a TrueType face and looks wrong at a 320x240 base
## resolution -- it antialiases and the stems land off-pixel. This is the same
## hand-encoded table as the original, so text matches exactly.

const GLYPH_W := 6
const GLYPH_H := 8

const FONT := {
	"A": "0E11111F111111", "B": "1E11111E11111E", "C": "0E11101010110E", "D": "1E11111111111E",
	"E": "1F10101E10101F", "F": "1F10101E101010", "G": "0E11101711110E", "H": "1111111F111111",
	"I": "0E04040404040E", "J": "0702020202120C", "K": "11121418141211", "L": "1010101010101F",
	"M": "111B1515111111", "N": "11191513111111", "O": "0E11111111110E", "P": "1E11111E101010",
	"Q": "0E11111115120D", "R": "1E11111E141211", "S": "0F10100E01011E", "T": "1F040404040404",
	"U": "1111111111110E", "V": "11111111110A04", "W": "11111115151B11", "X": "11110A040A1111",
	"Y": "11110A04040404", "Z": "1F01020408101F",
	"a": "00000E010F110F", "b": "10101E1111111E", "c": "00000E1010110E", "d": "01010F1111110F",
	"e": "00000E111F100E", "f": "0609081C080808", "g": "00000F110F010E", "h": "10101E11111111",
	"i": "04000C0404040E", "j": "0200060202120C", "k": "10101214181412", "l": "0C04040404040E",
	"m": "00001A15151515", "n": "00001E11111111", "o": "00000E1111110E", "p": "00001E111E1010",
	"q": "00000F110F0101", "r": "00001619101010", "s": "00000F100E011E", "t": "08081C08080906",
	"u": "0000111111130D", "v": "00001111110A04", "w": "0000151515150A", "x": "0000110A040A11",
	"y": "000011110F010E", "z": "00001F0204081F",
	"0": "0E11131519110E", "1": "040C040404040E", "2": "0E11010608101F", "3": "1F01020601110E",
	"4": "02060A121F0202", "5": "1F101E0101110E", "6": "0608101E11110E", "7": "1F010204080808",
	"8": "0E11110E11110E", "9": "0E11110F01020C",
	" ": "00000000000000", ".": "00000000000C0C", ",": "000000000C0C08", "'": "0C0C0800000000",
	"!": "04040404040004", "?": "0E110102040004", "-": "0000001F000000", ":": "000C0C000C0C00",
	"/": "01010204081010", "%": "191A0204080B13", "+": "0004041F040400", "*": "00150E1F0E1500",
	"(": "02040808080402", ")": "08040202020408", "<": "01020408040201", ">": "10080402040810",
	"\"": "0A0A0000000000", "=": "00001F001F0000", "$": "040F140E051E04", ";": "000C0C000C0C08",
	"_": "0000000000001F", "#": "0A1F0A0A1F0A00", "&": "0C120C1A15120D", "@": "0E111715160E00",
}

static var _rows := {}


static func _ensure() -> void:
	if not _rows.is_empty():
		return
	for ch in FONT:
		var hx: String = FONT[ch]
		var r := PackedInt32Array()
		for i in 7:
			r.append(hx.substr(i * 2, 2).hex_to_int())
		_rows[ch] = r


static func width(s: String) -> int:
	return s.length() * GLYPH_W


static func _pass(ci: CanvasItem, s: String, pos: Vector2, col: Color, sc: int) -> void:
	var cx := pos.x
	for i in s.length():
		var ch := s[i]
		if _rows.has(ch):
			var r: PackedInt32Array = _rows[ch]
			for row in 7:
				var bits := r[row]
				if bits == 0:
					continue
				# collapse runs of set bits into one rect instead of five
				var start := -1
				for b in range(6):
					var on := b < 5 and (bits & (1 << (4 - b))) != 0
					if on and start < 0:
						start = b
					elif not on and start >= 0:
						ci.draw_rect(Rect2(cx + start * sc, pos.y + row * sc, (b - start) * sc, sc), col, true)
						start = -1
		cx += GLYPH_W * sc


## Draw text. opts: {"shadow": bool, "outline": Color|null, "scale": int}
static func draw(ci: CanvasItem, s: String, pos: Vector2, col: Color = Color("#f4f0e8"), opts: Dictionary = {}) -> int:
	_ensure()
	var sc: int = opts.get("scale", 1)
	var p := Vector2(roundf(pos.x), roundf(pos.y))
	if opts.has("outline"):
		var oc: Color = opts.outline
		_pass(ci, s, p + Vector2(-sc, 0), oc, sc)
		_pass(ci, s, p + Vector2(sc, 0), oc, sc)
		_pass(ci, s, p + Vector2(0, -sc), oc, sc)
		_pass(ci, s, p + Vector2(0, sc), oc, sc)
	if opts.get("shadow", true):
		_pass(ci, s, p + Vector2(sc, sc), opts.get("shadow_color", Color(0.03, 0.02, 0.05, 0.75)), sc)
	_pass(ci, s, p, col, sc)
	return s.length() * GLYPH_W * sc


static func draw_centered(ci: CanvasItem, s: String, cx: float, y: float, col: Color = Color("#f4f0e8"), opts: Dictionary = {}) -> int:
	var sc: int = opts.get("scale", 1)
	return draw(ci, s, Vector2(cx - width(s) * sc / 2.0, y), col, opts)


static func draw_right(ci: CanvasItem, s: String, rx: float, y: float, col: Color = Color("#f4f0e8"), opts: Dictionary = {}) -> int:
	var sc: int = opts.get("scale", 1)
	return draw(ci, s, Vector2(rx - width(s) * sc, y), col, opts)


## Word-wrap to a pixel width. Honours existing newlines.
## Named wrap_text, not wrap: GDScript already has a global wrap(value, min, max).
static func wrap_text(s: String, px_width: int, sc: int = 1) -> PackedStringArray:
	var max_chars := maxi(1, int(px_width / float(GLYPH_W * sc)))
	var out := PackedStringArray()
	for para in s.split("\n"):
		var line := ""
		for w in para.split(" ", false):
			if line.is_empty():
				line = w
			elif (line + " " + w).length() <= max_chars:
				line += " " + w
			else:
				out.append(line)
				line = w
		out.append(line)
	return out


## Split a passage into pages that fit a box of `rows` lines, so a long line
## does not run off the bottom edge and lose its last clause.
static func paginate(lines: Array, px_width: int, rows: int) -> PackedStringArray:
	var out := PackedStringArray()
	for l in lines:
		var w := wrap_text(str(l), px_width)
		var i := 0
		while i < w.size():
			var chunk := PackedStringArray()
			for k in range(i, mini(i + rows, w.size())):
				chunk.append(w[k])
			out.append("\n".join(chunk))
			i += rows
	if out.is_empty():
		out.append("")
	return out
