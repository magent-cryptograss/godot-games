extends Node
## Writes the whole overworld out as one pixel per tile, which is the only way
## to actually look at a map this size.

const COLS := {
	".": "#4d8f4f", "f": "#6aa85c", ",": "#3d7a42", "\"": "#5c8a52",
	"=": "#b08c58", "q": "#9a7c50", "o": "#a8a8a2", "B": "#c09858",
	"~": "#2f6099", "T": "#245a28", "P": "#1c4a24", "^": "#8d8578",
	"r": "#6b645a", "%": "#2f6c34", "F": "#8a6a40", "#": "#7b736c",
	"W": "#8a6440", "R": "#a04438", "V": "#8a3830", "d": "#71482a",
	"C": "#120e14", "S": "#c39960", "g": "#7f7a76", "w": "#8d8578",
}


func _ready() -> void:
	var maps := World.build_all()
	var m: Maps.GameMap = maps["world"]
	var img := Image.create(m.w, m.h, false, Image.FORMAT_RGBA8)
	for y in m.h:
		for x in m.w:
			img.set_pixel(x, y, Color(COLS.get(m.get_tile(x, y), "#4d8f4f")))

	# mark what matters, big enough to find by eye
	_blob(img, World.town_gate, 5, Color("#ffe08a"))
	_blob(img, World.cave_mouth, 5, Color("#e05050"))
	for c in m.chests:
		_blob(img, Vector2i(c.x, c.y), 2, Color("#ffffff"))
	for n in m.npcs:
		if n.get("sign", false):
			_blob(img, Vector2i(n.x, n.y), 2, Color("#70d0ff"))

	var path := "user://worldmap.png"
	img.save_png(path)
	print("WORLDMAP: %dx%d tiles -> %s" % [m.w, m.h, ProjectSettings.globalize_path(path)])
	print("  town gate %s   cave mouth %s   chests %d   signs %d" % [
		World.town_gate, World.cave_mouth, m.chests.size(), m.npcs.size()])
	get_tree().quit()


func _blob(img: Image, p: Vector2i, r: int, c: Color) -> void:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var x := p.x + dx
			var y := p.y + dy
			if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
				img.set_pixel(x, y, c)
