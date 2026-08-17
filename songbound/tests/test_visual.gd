extends Node2D
## Renders the ported sprite pipeline and saves a PNG, so visual work can be
## checked without a human at a monitor. Needs a real display:
##
##   xvfb-run -a godot --path . res://tests/TestVisual.tscn --rendering-driver opengl3

var frames := 0
const OUT := "user://visual.png"


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#150e26"))

	# the eight presets, walking left to right
	for i in Sprites.PRESETS.size():
		var s := Sprite2D.new()
		s.texture = Sprites.to_texture(Sprites.build(Sprites.PRESETS[i].opts))
		s.centered = false
		s.scale = Vector2(2, 2)
		s.position = Vector2(8 + i * 38, 30)
		add_child(s)
		var l := Label.new()
		l.text = Sprites.PRESETS[i].name.substr(0, 6)
		l.position = Vector2(6 + i * 38, 82)
		l.add_theme_font_size_override("font_size", 8)
		add_child(l)

	# front / back derivation
	var g := Sprites.build(Sprites.PRESETS[3].opts)
	var front := Sprite2D.new()
	front.texture = Sprites.to_texture(g)
	front.centered = false
	front.scale = Vector2(3, 3)
	front.position = Vector2(20, 120)
	add_child(front)
	var back := Sprite2D.new()
	back.texture = Sprites.to_texture(Sprites.back_view(g))
	back.centered = false
	back.scale = Vector2(3, 3)
	back.position = Vector2(80, 120)
	add_child(back)

	# the NPC cast
	var idx := 0
	for key in Sprites.NPC_LOOKS:
		var s := Sprite2D.new()
		s.texture = Sprites.to_texture(Sprites.build(Sprites.NPC_LOOKS[key]))
		s.centered = false
		s.scale = Vector2(2, 2)
		s.position = Vector2(150 + idx * 24, 130)
		add_child(s)
		idx += 1

	var title := Label.new()
	title.text = "SONGBOUND -- Godot port: sprite pipeline"
	title.position = Vector2(8, 8)
	title.add_theme_font_size_override("font_size", 10)
	add_child(title)

	var note := Label.new()
	note.text = "front / back derived        NPC cast"
	note.position = Vector2(20, 196)
	note.add_theme_font_size_override("font_size", 8)
	add_child(note)


func _process(_d: float) -> void:
	frames += 1
	if frames < 8:
		return
	var tex := get_viewport().get_texture()
	if tex == null:
		print("VISUAL: no viewport texture")
	else:
		var img := tex.get_image()
		if img == null:
			print("VISUAL: no image (headless has no rendering device)")
		else:
			var lit := 0
			for y in range(0, img.get_height(), 3):
				for x in range(0, img.get_width(), 3):
					var c := img.get_pixel(x, y)
					if c.r + c.g + c.b > 0.35:
						lit += 1
			img.save_png(OUT)
			print("VISUAL: %dx%d, %d lit samples -> %s" % [
				img.get_width(), img.get_height(), lit, ProjectSettings.globalize_path(OUT)])
	print("SHOTS SAVED")
	get_tree().quit()
