extends RefCounted
class_name Txt

# Tiny text helper. At a 384x216 internal resolution the whole viewport is
# scaled up with nearest-neighbour filtering, so ordinary font rendering comes
# out chunky and pixelated for free -- no bitmap font needed.

static func font() -> Font:
	return ThemeDB.fallback_font


static func width(s: String, size: int) -> float:
	return font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


static func draw(c: CanvasItem, x: float, y: float, s: String, size: int, col: Color) -> void:
	c.draw_string(font(), Vector2(round(x), round(y)), s,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


static func center(c: CanvasItem, cx: float, y: float, s: String, size: int, col: Color) -> void:
	draw(c, cx - width(s, size) * 0.5, y, s, size, col)


# Text with a hard one-pixel drop shadow -- keeps it readable over the sky.
static func shadow(c: CanvasItem, x: float, y: float, s: String, size: int,
		col: Color, sh: Color = Color(0, 0, 0, 0.75)) -> void:
	draw(c, x + 1.0, y + 1.0, s, size, sh)
	draw(c, x, y, s, size, col)


static func center_shadow(c: CanvasItem, cx: float, y: float, s: String, size: int,
		col: Color, sh: Color = Color(0, 0, 0, 0.75)) -> void:
	var x := cx - width(s, size) * 0.5
	shadow(c, x, y, s, size, col, sh)
