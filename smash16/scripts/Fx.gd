extends Node2D
class_name Fx

# ---------------------------------------------------------------------------
# HIT EFFECTS
#
# Feedback is most of what sells a fighting game. A hit that lands with no
# spark, no freeze and no screen shake feels like nothing happened, even if
# the damage number went up.
# ---------------------------------------------------------------------------

var parts: Array = []
var flashes: Array = []
var shake: float = 0.0
var _seed := RandomNumberGenerator.new()


func _ready() -> void:
	_seed.randomize()
	z_index = 40


func spark(pos: Vector2, power: float, col: Color) -> void:
	var n := clampi(int(4.0 + power * 2.2), 4, 22)
	for i in range(n):
		var a := _seed.randf() * TAU
		var sp := _seed.randf_range(0.7, 1.0) * (1.2 + power * 0.55)
		parts.append({
			"p": pos, "v": Vector2(cos(a), sin(a)) * sp,
			"life": _seed.randi_range(8, 16), "max": 16.0,
			"col": col, "size": _seed.randf_range(1.0, 2.4),
			"grav": 0.06, "kind": "spark",
		})
	# a white flash ring right at the contact point
	flashes.append({"p": pos, "t": 0.0, "max": 7.0, "r": 3.0 + power * 1.4,
					"col": Color(1, 1, 1, 0.9)})
	shake = maxf(shake, minf(9.0, 1.6 + power * 0.75))


func puff(pos: Vector2) -> void:
	for i in range(5):
		var a := -PI * 0.5 + _seed.randf_range(-1.3, 1.3)
		parts.append({
			"p": pos + Vector2(_seed.randf_range(-3, 3), 0),
			"v": Vector2(cos(a), sin(a)) * _seed.randf_range(0.3, 0.9),
			"life": _seed.randi_range(7, 13), "max": 13.0,
			"col": Color(0.92, 0.92, 0.86, 0.75), "size": _seed.randf_range(1.0, 2.0),
			"grav": -0.01, "kind": "puff",
		})


func ko_burst(pos: Vector2, col: Color) -> void:
	# The classic: they turn into a star and go.
	for i in range(26):
		var a := _seed.randf() * TAU
		var sp := _seed.randf_range(1.4, 4.4)
		parts.append({
			"p": pos, "v": Vector2(cos(a), sin(a)) * sp,
			"life": _seed.randi_range(16, 34), "max": 34.0,
			"col": col if _seed.randf() < 0.55 else Color(1, 1, 1, 1),
			"size": _seed.randf_range(1.0, 3.0), "grav": 0.02, "kind": "star",
		})
	flashes.append({"p": pos, "t": 0.0, "max": 16.0, "r": 22.0,
					"col": Color(1, 1, 1, 0.95)})
	shake = maxf(shake, 10.0)


func tick() -> void:
	var keep: Array = []
	for q in parts:
		q["life"] -= 1
		if q["life"] <= 0:
			continue
		q["v"].y += q["grav"]
		q["v"] *= 0.96
		q["p"] += q["v"]
		keep.append(q)
	parts = keep

	var fk: Array = []
	for fl in flashes:
		fl["t"] += 1.0
		if fl["t"] < fl["max"]:
			fk.append(fl)
	flashes = fk

	shake = maxf(0.0, shake - 0.55)
	queue_redraw()


func shake_offset() -> Vector2:
	if shake <= 0.05:
		return Vector2.ZERO
	return Vector2(_seed.randf_range(-shake, shake), _seed.randf_range(-shake, shake) * 0.6)


func _draw() -> void:
	for fl in flashes:
		var t: float = fl["t"] / fl["max"]
		var r: float = fl["r"] * (0.35 + t * 0.9)
		var c: Color = fl["col"]
		c.a = (1.0 - t) * 0.75
		Art.disc(self, fl["p"].x, fl["p"].y, r, c)
		c.a = (1.0 - t) * 0.35
		Art.disc(self, fl["p"].x, fl["p"].y, r * 1.5, c)

	for q in parts:
		var t2: float = float(q["life"]) / q["max"]
		var c2: Color = q["col"]
		c2.a = clampf(t2 * 1.3, 0.0, 1.0)
		var sz: float = maxf(1.0, q["size"] * (0.5 + t2 * 0.8))
		if q["kind"] == "star":
			# four-point star, the SNES way: two crossed bars
			Art.px(self, q["p"].x - sz, q["p"].y - sz * 0.35, sz * 2.0, sz * 0.7, c2)
			Art.px(self, q["p"].x - sz * 0.35, q["p"].y - sz, sz * 0.7, sz * 2.0, c2)
		else:
			Art.px(self, q["p"].x - sz * 0.5, q["p"].y - sz * 0.5, sz, sz, c2)
