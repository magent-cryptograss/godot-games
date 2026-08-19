extends Node2D
class_name Stage

# ---------------------------------------------------------------------------
# THE STAGE
#
# Sky is drawn as hard horizontal bands rather than a smooth gradient. Real
# 16-bit hardware had a limited palette and banding was unavoidable, so
# leaning into it reads as period-correct instead of as a mistake.
# ---------------------------------------------------------------------------

var t: float = 0.0
# The island is hidden on the title and select screens -- bright green
# platforms slicing through the roster grid looked like a bug.
var show_platforms: bool = true

const SKY := [
	"1b2a5e", "24397a", "2f4a93", "3d5da8", "4f72bb", "6488c9",
	"7c9ed4", "95b3dd", "aec6e4", "c6d8ea",
]

var clouds: Array = []
var stars: Array = []


func _ready() -> void:
	z_index = 0
	var r := RandomNumberGenerator.new()
	r.seed = 20260819
	for i in range(7):
		clouds.append({
			"x": r.randf_range(-40.0, float(Rules.VW) + 40.0),
			"y": r.randf_range(14.0, 74.0),
			"w": r.randf_range(18.0, 40.0),
			"sp": r.randf_range(0.045, 0.13),
		})
	for i in range(26):
		stars.append(Vector2(r.randf_range(0, Rules.VW), r.randf_range(0, 40)))


func tick() -> void:
	t += 1.0
	for c in clouds:
		c["x"] += c["sp"]
		if c["x"] > float(Rules.VW) + 50.0:
			c["x"] = -50.0
	queue_redraw()


func _draw() -> void:
	_sky()
	_mountains()
	if show_platforms:
		_platform()


func _sky() -> void:
	var band := float(Rules.VH) / float(SKY.size())
	for i in SKY.size():
		Art.px(self, 0, float(i) * band, Rules.VW, band + 1.0, Color(SKY[i]))

	# a few faint stars still hanging on up top
	for s in stars:
		var a := 0.20 + 0.16 * sin(t * 0.02 + s.x)
		Art.px(self, s.x, s.y, 1, 1, Color(1, 1, 1, a))

	# sun
	Art.disc(self, 318, 34, 15, Color(1, 1, 1, 0.10))
	Art.disc(self, 318, 34, 11, Color(1, 1, 1, 0.16))
	Art.disc(self, 318, 34, 8, Color("fff3c4"))

	for c in clouds:
		var col := Color(1, 1, 1, 0.5)
		Art.px(self, c["x"], c["y"], c["w"], 3, col)
		Art.px(self, c["x"] + c["w"] * 0.18, c["y"] - 3.0, c["w"] * 0.55, 3, col)
		Art.px(self, c["x"] + c["w"] * 0.42, c["y"] - 5.0, c["w"] * 0.28, 2, col)


func _mountains() -> void:
	# The horizon sits LOW and far away on purpose. The stage floats well
	# above it, so the empty space under the stage reads as a long way down
	# rather than as a bit of blank grass.
	_ridge(168.0, 20.0, 92.0, Color("4c5f8e"))
	_ridge(186.0, 16.0, 62.0, Color("41547f"))
	_ridge(200.0, 12.0, 44.0, Color("36603f"))
	Art.px(self, 0, 206, Rules.VW, Rules.VH - 206, Color("2b4d34"))

	# a distant treeline, kept tiny so it stays far away
	var r := RandomNumberGenerator.new()
	r.seed = 990211
	for i in range(34):
		var x := r.randf_range(-6.0, float(Rules.VW))
		var h := r.randf_range(3.0, 6.0)
		Art.px(self, x, 206.0 - h, 1.0, h, Color("1f3a27"))
		Art.disc(self, x, 206.0 - h, 1.8, Color("264a30"))

	# haze band where the ground meets the air
	Art.px(self, 0, 162, Rules.VW, 8, Color(0.72, 0.80, 0.92, 0.16))


func _ridge(base_y: float, amp: float, wl: float, col: Color) -> void:
	for x in range(Rules.VW):
		var fx := float(x)
		var y := base_y - amp * (0.5 + 0.5 * sin(fx / wl)) - amp * 0.28 * sin(fx / (wl * 0.37))
		Art.px(self, fx, y, 1.0, base_y + 40.0 - y, col)


func _platform() -> void:
	var s: Rect2 = Rules.SOLID

	# grass cap
	Art.px(self, s.position.x, s.position.y, s.size.x, 4, Color("57c04a"))
	Art.px(self, s.position.x, s.position.y, s.size.x, 1, Color("7ee06a"))
	# dirt
	Art.px(self, s.position.x, s.position.y + 4.0, s.size.x, 10, Color("8a5a34"))
	Art.px(self, s.position.x, s.position.y + 14.0, s.size.x, s.size.y - 14.0, Color("6b4526"))
	# rocky underside, tapering so it reads as a floating island
	for i in range(int(s.size.y) - 10):
		var fy := float(i)
		var inset := fy * 1.35
		if inset * 2.0 >= s.size.x:
			break
		Art.px(self, s.position.x + inset, s.position.y + 10.0 + fy,
			s.size.x - inset * 2.0, 1, Color("5a3a20").lerp(Color("2e1d10"), fy / 34.0))

	# a little speckle in the dirt so it is not a flat slab
	var r := RandomNumberGenerator.new()
	r.seed = 4242
	for i in range(40):
		var px_ := r.randf_range(s.position.x + 2.0, s.position.x + s.size.x - 3.0)
		var py := r.randf_range(s.position.y + 5.0, s.position.y + 26.0)
		var inset2 := (py - s.position.y - 10.0) * 1.35
		if px_ < s.position.x + inset2 or px_ > s.position.x + s.size.x - inset2:
			continue
		Art.px(self, px_, py, 2, 1, Color(0, 0, 0, 0.16))

	# edge highlight
	Art.px(self, s.position.x, s.position.y, 1, 14, Color(1, 1, 1, 0.10))
	Art.px(self, s.position.x + s.size.x - 1.0, s.position.y, 1, 14, Color(0, 0, 0, 0.18))

	# soft platforms -- you jump up through these and drop down with DOWN
	for p in Rules.PLATS:
		var pr: Rect2 = p
		Art.px(self, pr.position.x, pr.position.y - 1.0, pr.size.x, 1, Color("9ad880"))
		Art.px(self, pr.position.x, pr.position.y, pr.size.x, 3, Color("57c04a"))
		Art.px(self, pr.position.x, pr.position.y + 3.0, pr.size.x, 2, Color("6b4526"))
		Art.px(self, pr.position.x, pr.position.y + 5.0, pr.size.x, 1, Color(0, 0, 0, 0.25))
