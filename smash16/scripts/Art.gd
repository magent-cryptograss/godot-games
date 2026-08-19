extends RefCounted
class_name Art

# ---------------------------------------------------------------------------
# THE ART
#
# Everything is drawn from primitives, no image files anywhere. Crucially,
# every primitive here snaps to whole pixels and fills spans of solid colour
# -- Godot's draw_circle and draw_line would give us smooth antialiased edges,
# which is the one thing that instantly stops looking 16-bit.
#
# Three body plans:
#   humanoid  X, Samus, Link, Fox, Mario, Ness
#   ball      Kirby
#   dino      Yoshi
#
# Then a per-character detail pass bolts on the thing that makes them
# recognisable: a cannon, a sword, a mustache, a tail, a saddle.
# ---------------------------------------------------------------------------

# =========================== PRIMITIVES ====================================

static func px(c: CanvasItem, x: float, y: float, w: float, h: float, col: Color) -> void:
	c.draw_rect(Rect2(round(x), round(y), maxf(1.0, round(w)), maxf(1.0, round(h))), col)


# A filled rect with a one-pixel dark border -- the classic 16-bit sprite look.
static func box(c: CanvasItem, x: float, y: float, w: float, h: float,
		fill: Color, dark: Color) -> void:
	px(c, x - 1.0, y - 1.0, w + 2.0, h + 2.0, dark)
	px(c, x, y, w, h, fill)


# A pixel-perfect filled circle, built from horizontal spans.
static func disc(c: CanvasItem, cx: float, cy: float, r: float, col: Color) -> void:
	var ri := int(round(r))
	if ri <= 0:
		px(c, cx, cy, 1, 1, col)
		return
	for dy in range(-ri, ri + 1):
		var q := r * r - float(dy * dy)
		if q <= 0.0:
			continue
		var dx := int(floor(sqrt(q)))
		if dx <= 0:
			continue
		c.draw_rect(Rect2(round(cx) - dx, round(cy) + dy, dx * 2, 1), col)


static func disc_o(c: CanvasItem, cx: float, cy: float, r: float,
		fill: Color, dark: Color) -> void:
	disc(c, cx, cy, r + 1.0, dark)
	disc(c, cx, cy, r, fill)


# A pixel-perfect filled ellipse. Kirby is made almost entirely of these --
# his eyes, his feet and his blush are all ovals, not circles.
static func ellipse(c: CanvasItem, cx: float, cy: float, rx: float, ry: float,
		col: Color) -> void:
	var ri := int(round(ry))
	if ri <= 0 or rx <= 0.0:
		px(c, cx - rx, cy, maxf(1.0, rx * 2.0), 1, col)
		return
	for dy in range(-ri, ri + 1):
		var q := 1.0 - float(dy * dy) / (ry * ry)
		if q <= 0.0:
			continue
		var dx := int(floor(rx * sqrt(q)))
		if dx <= 0:
			continue
		c.draw_rect(Rect2(round(cx) - dx, round(cy) + dy, dx * 2, 1), col)


static func ellipse_o(c: CanvasItem, cx: float, cy: float, rx: float, ry: float,
		fill: Color, dark: Color) -> void:
	ellipse(c, cx, cy, rx + 1.0, ry + 1.0, dark)
	ellipse(c, cx, cy, rx, ry, fill)


# A chunky limb: stepped squares, so it stays hard-edged at any angle.
static func limb(c: CanvasItem, a: Vector2, b: Vector2, th: float,
		col: Color, dark: Color) -> void:
	_limb_pass(c, a, b, th + 2.0, dark)
	_limb_pass(c, a, b, th, col)


static func _limb_pass(c: CanvasItem, a: Vector2, b: Vector2, th: float, col: Color) -> void:
	var t := maxf(1.0, round(th))
	var n := int(maxf(absf(b.x - a.x), absf(b.y - a.y)))
	if n <= 0:
		px(c, a.x - t * 0.5, a.y - t * 0.5, t, t, col)
		return
	for i in range(n + 1):
		var p := a.lerp(b, float(i) / float(n))
		px(c, p.x - t * 0.5, p.y - t * 0.5, t, t, col)


# =========================== POSE ==========================================
#
# Worked out facing RIGHT, then mirrored once at the end. Doing it any other
# way means every limb offset needs a sign and they all eventually disagree.

static func _pose(f: Fighter) -> Dictionary:
	var s: float = float(f.ch["size"])
	var H: float = 22.0 * s
	var t: float = f.anim

	var head_r := 0.185 * H
	var head_y := -0.805 * H
	var sh_y := -0.615 * H
	var hip_y := -0.395 * H
	var leg := -hip_y
	var arm := 0.30 * H

	var bob := 0.0
	var lean := 0.0
	var squash := 1.0

	var foot_a := Vector2(-1.4 * s, 0.0)
	var foot_b := Vector2(1.6 * s, 0.0)
	var hand_a := Vector2(-2.2 * s, sh_y + arm)   # back hand
	var hand_b := Vector2(2.2 * s, sh_y + arm)    # front hand

	match f.state:
		"idle", "shield":
			bob = sin(t * 0.09) * 0.7 * s
			hand_a = Vector2(-2.6 * s, sh_y + arm * 0.95 + bob)
			hand_b = Vector2(2.6 * s, sh_y + arm * 0.95 + bob)
		"run":
			var ph := t * 0.34
			var sw := 5.2 * s
			foot_a = Vector2(sin(ph) * sw, -maxf(0.0, cos(ph)) * 2.6 * s)
			foot_b = Vector2(sin(ph + PI) * sw, -maxf(0.0, cos(ph + PI)) * 2.6 * s)
			hand_a = Vector2(-sin(ph) * 4.0 * s, sh_y + arm * 0.85)
			hand_b = Vector2(-sin(ph + PI) * 4.0 * s, sh_y + arm * 0.85)
			bob = absf(sin(ph)) * -0.8 * s
			lean = 0.10
		"crouch":
			squash = 0.74
			hand_a = Vector2(-3.0 * s, sh_y + arm * 0.7)
			hand_b = Vector2(3.0 * s, sh_y + arm * 0.7)
		"air", "helpless":
			foot_a = Vector2(-3.4 * s, -2.6 * s)
			foot_b = Vector2(2.8 * s, -0.6 * s)
			hand_a = Vector2(-4.4 * s, sh_y + arm * 0.35)
			hand_b = Vector2(3.6 * s, sh_y + arm * 0.30)
			lean = 0.06
			if f.state == "helpless":
				lean = sin(t * 0.5) * 0.35
		"hitstun":
			lean = -0.34
			foot_a = Vector2(-4.0 * s, -1.4 * s)
			foot_b = Vector2(3.2 * s, -2.6 * s)
			hand_a = Vector2(-5.2 * s, sh_y + arm * 0.15)
			hand_b = Vector2(-3.0 * s, sh_y - 1.0 * s)
		"broken":
			lean = sin(t * 0.9) * 0.22
			hand_a = Vector2(-5.0 * s, sh_y + arm * 0.2)
			hand_b = Vector2(5.0 * s, sh_y + arm * 0.2)
		"roll", "dodge":
			squash = 0.80
			lean = 0.5 * sin(f.st * 0.4)
			hand_a = Vector2(-2.0 * s, sh_y + arm * 0.5)
			hand_b = Vector2(2.0 * s, sh_y + arm * 0.5)
		"charging":
			squash = 0.92
			var sh := sin(t * 1.4) * 0.5 * s
			hand_a = Vector2(-2.0 * s + sh, sh_y + arm * 0.6)
			hand_b = Vector2(5.0 * s + sh, sh_y + arm * 0.55)
			lean = -0.08
		"attack":
			var d := _attack_pose(f, s, H, sh_y, arm, leg)
			hand_a = d["hand_a"]
			hand_b = d["hand_b"]
			foot_a = d["foot_a"]
			foot_b = d["foot_b"]
			lean = d["lean"]
			squash = d["squash"]

	var fc := float(f.facing)
	var mirror := func(v: Vector2) -> Vector2: return Vector2(v.x * fc, v.y * squash + bob)

	return {
		"s": s, "H": H, "fc": fc, "squash": squash, "lean": lean,
		"head_r": head_r,
		"head": Vector2(lean * H * 0.35 * fc, head_y * squash + bob),
		"sh": Vector2(lean * H * 0.20 * fc, sh_y * squash + bob),
		"hip": Vector2(0.0, hip_y * squash + bob),
		"hand_a": mirror.call(hand_a),
		"hand_b": mirror.call(hand_b),
		"foot_a": mirror.call(foot_a),
		"foot_b": mirror.call(foot_b),
	}


# How the limbs sit during each attack. The front hand is thrown toward
# wherever the hitbox is, so the animation reads as the actual attack.
static func _attack_pose(f: Fighter, s: float, H: float, sh_y: float,
		arm: float, leg: float) -> Dictionary:
	var m: Dictionary = Moves.TABLE[f.move_name]
	var start := int(m["startup"])
	var act := int(m["active"])
	# 0 while winding up, 1 while the hitbox is out, easing back down after
	var e := 0.0
	if f.move_f <= start:
		e = -0.45 * (float(f.move_f) / maxf(1.0, float(start)))
	elif f.move_f <= start + act:
		e = 1.0
	else:
		var rec := maxf(1.0, float(m["rec"]))
		e = 1.0 - clampf((float(f.move_f - start - act)) / rec, 0.0, 1.0)

	var out := {
		"hand_a": Vector2(-2.4 * s, sh_y + arm * 0.9),
		"hand_b": Vector2(2.4 * s, sh_y + arm * 0.9),
		"foot_a": Vector2(-2.0 * s, 0.0),
		"foot_b": Vector2(2.2 * s, 0.0),
		"lean": 0.0, "squash": 1.0,
	}

	match f.move_name:
		"jab":
			out["hand_b"] = Vector2((3.0 + 7.0 * e) * s, sh_y + 2.0 * s)
			out["lean"] = 0.06 * e
		"side", "fair", "dashslash":
			out["hand_b"] = Vector2((3.0 + 10.0 * e) * s, sh_y + 3.0 * s)
			out["hand_a"] = Vector2(-4.0 * s, sh_y + arm * 0.6)
			out["lean"] = 0.16 * e
			if f.move_name == "dashslash":
				out["lean"] = 0.30 * e
				out["hand_b"] = Vector2((4.0 + 12.0 * e) * s, sh_y + 2.0 * s)
			if f.move_name == "fair":
				out["foot_a"] = Vector2(-3.0 * s, -2.0 * s)
				out["foot_b"] = Vector2(2.0 * s, -1.0 * s)
		"up", "uair", "usp_boost", "usp_punch", "usp_cutter", "usp_pkt", "usp_saber":
			out["hand_b"] = Vector2(2.0 * s, sh_y - (4.0 + 7.0 * e) * s)
			out["hand_a"] = Vector2(-2.0 * s, sh_y - (2.0 + 5.0 * e) * s)
			out["lean"] = -0.08 * e
			if not f.on_ground:
				out["foot_a"] = Vector2(-2.4 * s, -1.6 * s)
				out["foot_b"] = Vector2(2.4 * s, -1.6 * s)
		"down":
			out["squash"] = 0.80
			out["hand_b"] = Vector2((4.0 + 8.0 * e) * s, -2.0 * s)
			out["lean"] = 0.10 * e
		"dair", "usp_egg":
			out["hand_b"] = Vector2(2.6 * s, sh_y + (arm + 6.0 * e) * s * 0.5)
			out["hand_a"] = Vector2(-2.6 * s, sh_y + (arm + 6.0 * e) * s * 0.5)
			out["foot_a"] = Vector2(-2.0 * s, (2.0 + 3.0 * e) * s)
			out["foot_b"] = Vector2(2.0 * s, (2.0 + 3.0 * e) * s)
			out["lean"] = 0.0
		"nair":
			out["hand_b"] = Vector2((4.0 + 6.0 * e) * s, sh_y + 4.0 * s)
			out["hand_a"] = Vector2((-4.0 - 6.0 * e) * s, sh_y + 4.0 * s)
			out["foot_a"] = Vector2(-4.0 * s, -1.4 * s)
			out["foot_b"] = Vector2(4.0 * s, -1.4 * s)
		"hammer":
			# big overhead wind-up, then down
			var sw := lerpf(-2.4, 1.2, clampf(e, 0.0, 1.0))
			out["hand_b"] = Vector2(cos(sw) * 10.0 * s, sh_y + sin(sw) * 10.0 * s)
			out["hand_a"] = Vector2(cos(sw) * 7.0 * s, sh_y + sin(sw) * 7.0 * s)
			out["lean"] = 0.22 * e
		"usp_screw", "usp_spin", "usp_firefox":
			var spin := f.anim * 0.9
			out["hand_b"] = Vector2(cos(spin) * 7.0 * s, sh_y + sin(spin) * 5.0 * s)
			out["hand_a"] = Vector2(-cos(spin) * 7.0 * s, sh_y - sin(spin) * 5.0 * s)
			out["foot_a"] = Vector2(-cos(spin) * 4.0 * s, -1.0 * s)
			out["foot_b"] = Vector2(cos(spin) * 4.0 * s, -1.0 * s)
		"cast":
			out["hand_b"] = Vector2((4.0 + 6.0 * e) * s, sh_y + 3.0 * s)
			out["hand_a"] = Vector2(-3.0 * s, sh_y + arm * 0.7)
			out["lean"] = 0.10 * e
		_:
			pass
	return out


# =========================== MAIN ENTRY ====================================

static func draw_fighter(f: Fighter) -> void:
	if f.ko_timer > 0:
		return

	var s: float = float(f.ch["size"])
	var pal: Dictionary = f.ch["pal"]

	# Blink while invulnerable, so respawn safety is readable at a glance.
	if f.invuln > 0 and (int(f.anim) / 3) % 2 == 0:
		return

	_shadow(f, s)

	var P := _pose(f)
	match String(f.ch["plan"]):
		"ball": _draw_ball(f, P, pal)
		"dino": _draw_dino(f, P, pal)
		_:     _draw_humanoid(f, P, pal)

	_details(f, P, pal)

	# hit flash
	if f.flash > 0 and f.flash % 2 == 1:
		var hb := f.hurtbox()
		px(f, hb.position.x - f.position.x, hb.position.y - f.position.y,
			hb.size.x, hb.size.y, Color(1, 1, 1, 0.55))

	if f.state == "shield":
		var r := 15.0 * s * (0.55 + 0.45 * (f.shield_hp / Rules.SHIELD_MAX))
		var col := Color(0.45, 0.8, 1.0, 0.34)
		disc(f, 0.0, -11.0 * s, r, col)
		disc(f, 0.0, -11.0 * s, r - 2.0, Color(0.7, 0.92, 1.0, 0.16))

	if f.state == "charging":
		var g := float(f.charge) / float(Moves.SPECIALS[f.ch["special"]]["max_charge"])
		var gr := 2.0 + 6.0 * g
		var gc: Color = pal["accent"]
		gc.a = 0.75
		disc(f, P["hand_b"].x, P["hand_b"].y, gr + sin(f.anim * 0.6) * 1.0, gc)
		if g >= 1.0:
			disc(f, P["hand_b"].x, P["hand_b"].y, gr + 3.0, Color(1, 1, 1, 0.45))

	if f.state == "broken":
		for i in range(3):
			var a := f.anim * 0.16 + float(i) * TAU / 3.0
			px(f, cos(a) * 8.0 * s - 1.0, -26.0 * s + sin(a) * 3.0 - 1.0, 3, 3,
				Color("f2e14a"))


static func _shadow(f: Fighter, s: float) -> void:
	# Cast on whichever surface is actually underneath, so it reads as height.
	var ground = _surface_below(f.position)
	if ground == null:
		return
	var d: float = float(ground) - f.position.y
	if d < -1.0 or d > 90.0:
		return
	var k := clampf(1.0 - d / 90.0, 0.16, 1.0)
	var w := 11.0 * s * k
	var col := Color(0, 0, 0, 0.26 * k)
	f.draw_rect(Rect2(round(-w), round(d - 1.0), round(w * 2.0), 2), col)


static func _surface_below(p: Vector2):
	var best = null
	var s: Rect2 = Rules.SOLID
	if p.x > s.position.x and p.x < s.position.x + s.size.x and s.position.y >= p.y - 1.0:
		best = s.position.y
	for pl in Rules.PLATS:
		var pr: Rect2 = pl
		if p.x > pr.position.x and p.x < pr.position.x + pr.size.x and pr.position.y >= p.y - 1.0:
			if best == null or pr.position.y < float(best):
				best = pr.position.y
	return best


# =========================== BODY PLANS ====================================

static func _draw_humanoid(f: Fighter, P: Dictionary, pal: Dictionary) -> void:
	var s: float = P["s"]
	var dark: Color = pal["dark"]
	var hip: Vector2 = P["hip"]
	var sh: Vector2 = P["sh"]

	# back limbs first, shaded darker so the figure reads as having depth
	var back := pal["main2"] as Color
	limb(f, hip + Vector2(-1.0 * P["fc"], 0), P["foot_a"], 3.2 * s, back, dark)
	limb(f, sh + Vector2(-1.0 * P["fc"], 0), P["hand_a"], 2.8 * s, back, dark)

	# torso
	var tw := 9.0 * s
	var th := (hip.y - sh.y) + 4.0 * s
	box(f, sh.x - tw * 0.5, sh.y - 2.0 * s, tw, th, pal["main"], dark)
	# chest highlight
	px(f, sh.x - tw * 0.5 + 1.0, sh.y - 1.0 * s, tw * 0.34, th * 0.5, pal["trim"])

	# front limbs
	limb(f, hip + Vector2(1.0 * P["fc"], 0), P["foot_b"], 3.4 * s, pal["main"], dark)
	limb(f, sh + Vector2(1.0 * P["fc"], 0), P["hand_b"], 3.0 * s, pal["skin"], dark)

	# boots
	_boot(f, P["foot_a"], s, back, dark, P["fc"])
	_boot(f, P["foot_b"], s, pal["main"], dark, P["fc"])

	# head
	var hd: Vector2 = P["head"]
	disc_o(f, hd.x, hd.y, P["head_r"], pal["skin"], dark)
	_eyes(f, P, pal)


static func _boot(f: Fighter, p: Vector2, s: float, col: Color, dark: Color, fc: float) -> void:
	box(f, p.x - 2.2 * s + (0.8 * s * fc), p.y - 1.0 * s, 4.6 * s, 2.4 * s, col, dark)


static func _eyes(f: Fighter, P: Dictionary, pal: Dictionary) -> void:
	var s: float = P["s"]
	var hd: Vector2 = P["head"]
	var fc: float = P["fc"]
	var dark: Color = pal["dark"]
	var ex := hd.x + 1.6 * s * fc
	var ey := hd.y - 0.4 * s
	if f.state == "hitstun" or f.state == "broken":
		# scrunched shut
		px(f, ex - 1.0, ey, 2.6 * s, 1.0, dark)
		px(f, ex + 2.0 * s * fc - 1.0, ey, 2.0 * s, 1.0, dark)
	else:
		px(f, ex, ey - 1.4 * s, 1.6 * s, 2.8 * s, Color(1, 1, 1, 0.92))
		px(f, ex + 0.5 * s * fc, ey - 0.6 * s, 1.2 * s, 1.8 * s, dark)


static func _draw_ball(f: Fighter, P: Dictionary, pal: Dictionary) -> void:
	# KIRBY
	#
	# He is one sphere and everything hangs off it. What actually makes him
	# read as Kirby rather than as a pink ball, in order of how much it matters:
	#   1. the body is LIT from the upper left with a darker rim along the
	#      lower right -- a flat pink circle looks like a bouncy ball
	#   2. the eyes are TALL ovals with the white shine in the TOP half
	#   3. the feet are big maroon ovals splayed outward, not little discs
	#   4. the blush is soft and rosy, not a red stripe
	var s: float = P["s"]
	var sq: float = float(P["squash"])
	var fc: float = P["fc"]
	var dark: Color = pal["dark"]
	var r := 9.0 * s
	var cy: float = -10.6 * s * sq

	var body: Color = pal["main"]
	var body_dark: Color = pal["main2"]
	var blush: Color = body.lerp(pal["accent"], 0.42)
	var eye_col := Color("26214e")

	# Feet track the run cycle but stay pinned wide apart under the body.
	var fa := Vector2(clampf(P["foot_a"].x, -7.0 * s, 7.0 * s) - 2.5 * s,
		minf(P["foot_a"].y, 0.0) - 2.3 * s)
	var fb := Vector2(clampf(P["foot_b"].x, -7.0 * s, 7.0 * s) + 2.5 * s,
		minf(P["foot_b"].y, 0.0) - 2.3 * s)

	# back foot, behind the body and shaded down
	_kirby_foot(f, fa, s, pal["accent"].darkened(0.30), dark, -fc)

	# Body: lay down the dark ball, then the lit pink offset up-and-left. What
	# is left showing along the lower right IS the shadow -- cheaper and
	# cleaner than trying to draw a crescent.
	disc_o(f, 0.0, cy, r, body_dark, dark)
	disc(f, -r * 0.09, cy - r * 0.11, r * 0.93, body)
	ellipse(f, -r * 0.36, cy - r * 0.42, r * 0.34, r * 0.24, pal["trim"])

	# Stubby mitts. They point wherever the pose points but stay pinned close
	# to the body, so he never sprouts human arms.
	_kirby_arm(f, P["hand_a"], Vector2(0.0, cy), r, s, body_dark, dark)
	_kirby_arm(f, P["hand_b"], Vector2(0.0, cy), r, s, body, dark)

	# front foot
	_kirby_foot(f, fb, s, pal["accent"], dark, fc)

	# --- face, shifted toward whichever way he is looking ---
	var fx := fc * 1.3 * s
	var ey := cy - 2.9 * s
	var ex := 2.5 * s
	var open: bool = f.state == "attack" or f.state == "hitstun" or f.state == "broken"

	if f.state == "hitstun" or f.state == "broken":
		for sgn in [-1.0, 1.0]:
			var bx: float = fx + sgn * ex
			px(f, bx - 1.8 * s, ey - 0.4 * s, 3.6 * s, 1.3, eye_col)
			px(f, bx - 1.0 * s, ey - 1.7 * s, 2.0 * s, 1.3, eye_col)
	else:
		for sgn2 in [-1.0, 1.0]:
			var bx2: float = fx + sgn2 * ex
			ellipse(f, bx2, ey, 1.55 * s, 3.1 * s, eye_col)
			# The shine belongs in the TOP of the eye. Centre it and he stops
			# looking like Kirby immediately.
			ellipse(f, bx2, ey - 1.5 * s, 1.05 * s, 1.25 * s, Color(1, 1, 1, 0.95))
			ellipse(f, bx2, ey + 2.0 * s, 0.75 * s, 0.7 * s, Color(0.42, 0.53, 0.95, 0.8))

	ellipse(f, fx - 5.9 * s, cy + 0.7 * s, 2.1 * s, 1.35 * s, blush)
	ellipse(f, fx + 5.9 * s, cy + 0.7 * s, 2.1 * s, 1.35 * s, blush)

	# mouth: a tiny nub normally, open when swinging or hurting
	if open:
		ellipse_o(f, fx, cy + 3.1 * s, 1.9 * s, 2.0 * s, Color("8e2a4a"), dark)
		ellipse(f, fx, cy + 3.9 * s, 1.1 * s, 0.85 * s, Color("e0708e"))
	else:
		ellipse(f, fx, cy + 2.5 * s, 1.0 * s, 0.75 * s, eye_col)


static func _kirby_foot(f: Fighter, p: Vector2, s: float, col: Color,
		dark: Color, fc: float) -> void:
	# Wide oval nudged outward in the direction it points, so the pair splay
	# apart the way they do in the sprite.
	var lean := 0.7 * s * signf(fc if absf(fc) > 0.01 else 1.0)
	ellipse_o(f, p.x + lean, p.y, 4.1 * s, 2.5 * s, col, dark)
	ellipse(f, p.x - lean * 0.5, p.y - 1.0 * s, 2.0 * s, 0.85 * s, col.lightened(0.30))


static func _kirby_arm(f: Fighter, hand: Vector2, centre: Vector2, r: float,
		s: float, col: Color, dark: Color) -> void:
	var d := hand - centre
	if d.length() < 0.1:
		d = Vector2(-1.0, 0.2)
	d = d.normalized()
	var tip := centre + d * r * 1.16
	limb(f, centre + d * r * 0.55, tip, 3.2 * s, col, dark)
	disc_o(f, tip.x, tip.y, 2.3 * s, col, dark)


static func _draw_dino(f: Fighter, P: Dictionary, pal: Dictionary) -> void:
	# Yoshi: egg body, snout, saddle, big boots, tail.
	var s: float = P["s"]
	var dark: Color = pal["dark"]
	var hip: Vector2 = P["hip"]
	var fc: float = P["fc"]
	var body_y: float = -11.0 * s * float(P["squash"])

	# tail behind everything
	var tail_sw := sin(f.anim * 0.16) * 2.0 * s
	limb(f, Vector2(-4.0 * s * fc, body_y + 1.0 * s),
		Vector2(-11.0 * s * fc, body_y + 3.0 * s + tail_sw), 3.4 * s, pal["main2"], dark)

	# legs + big shoes
	limb(f, hip, P["foot_a"], 3.6 * s, pal["main2"], dark)
	limb(f, hip, P["foot_b"], 3.8 * s, pal["main"], dark)
	box(f, P["foot_a"].x - 3.0 * s + 1.0 * s * fc, P["foot_a"].y - 1.4 * s,
		6.2 * s, 3.0 * s, pal["metal"], dark)
	box(f, P["foot_b"].x - 3.0 * s + 1.0 * s * fc, P["foot_b"].y - 1.4 * s,
		6.4 * s, 3.2 * s, pal["metal"], dark)

	# egg-shaped body
	disc_o(f, 0.0, body_y, 7.4 * s, pal["main"], dark)
	disc(f, 0.0, body_y + 2.4 * s, 6.2 * s, pal["trim"])
	# saddle
	px(f, -5.4 * s, body_y - 5.4 * s, 10.8 * s, 3.0 * s, pal["accent"])
	px(f, -5.4 * s, body_y - 5.4 * s, 10.8 * s, 1.0 * s, pal["metal"])

	# arms
	limb(f, Vector2(0.0, body_y - 2.0 * s), P["hand_a"] * 0.85, 2.8 * s, pal["main2"], dark)
	limb(f, Vector2(0.0, body_y - 2.0 * s), P["hand_b"] * 0.85, 3.0 * s, pal["main"], dark)

	# head + snout
	var hd := Vector2(P["head"].x + 1.0 * s * fc, P["head"].y - 1.0 * s)
	disc_o(f, hd.x, hd.y, 5.0 * s, pal["main"], dark)
	box(f, hd.x + (1.0 * s * fc if fc > 0 else -7.6 * s), hd.y + 0.4 * s,
		6.6 * s, 3.4 * s, pal["main"], dark)
	px(f, hd.x + (6.0 * s * fc if fc > 0 else -6.8 * s), hd.y + 1.2 * s, 1.4 * s, 1.2 * s, dark)
	# eye
	px(f, hd.x + 0.6 * s * fc, hd.y - 3.2 * s, 2.2 * s, 3.4 * s, Color(1, 1, 1, 0.94))
	px(f, hd.x + 1.2 * s * fc, hd.y - 2.4 * s, 1.4 * s, 2.0 * s, dark)


# =========================== PER-CHARACTER DETAIL ==========================

static func _details(f: Fighter, P: Dictionary, pal: Dictionary) -> void:
	var s: float = P["s"]
	var fc: float = P["fc"]
	var dark: Color = pal["dark"]
	var hd: Vector2 = P["head"]
	var hr: float = P["head_r"]
	var hand: Vector2 = P["hand_b"]
	var kit: Dictionary = f.ch.get("kit", {})

	match String(f.ch["id"]):
		"x":
			# helmet with the forward fin, and the buster on the front arm
			disc_o(f, hd.x, hd.y - 0.6 * s, hr + 0.8 * s, pal["main"], dark)
			px(f, hd.x - hr, hd.y - 0.2 * s, hr * 2.0, hr * 0.9, pal["skin"])
			_eyes(f, P, pal)
			px(f, hd.x + hr * 0.2 * fc, hd.y - hr - 1.6 * s, hr * 1.5, 1.8 * s, pal["trim"])
			px(f, hd.x - hr * 1.1 * fc, hd.y - 0.8 * s, 1.6 * s, 2.2 * s, pal["accent"])
			_cannon(f, P, pal, 3.6)
		"samus":
			# Shoulder plates sit low and wide. Drawn any higher they swallow
			# the helmet and she turns into an orange blob.
			disc_o(f, P["sh"].x - 5.2 * s, P["sh"].y + 1.6 * s, 3.0 * s, pal["main2"], dark)
			disc_o(f, P["sh"].x + 5.2 * s, P["sh"].y + 1.6 * s, 3.2 * s, pal["main"], dark)
			disc_o(f, hd.x, hd.y - 0.4 * s, hr + 0.7 * s, pal["main"], dark)
			# the green visor, wrapping the front of the helmet
			px(f, hd.x - hr * 0.35 + 0.7 * s * fc, hd.y - 1.4 * s, hr * 1.55, hr * 1.15,
				pal["accent"])
			px(f, hd.x - hr * 0.35 + 0.7 * s * fc, hd.y - 1.4 * s, hr * 0.55, hr * 0.45,
				Color(1, 1, 1, 0.55))
			# crest ridge
			px(f, hd.x - hr * 0.7, hd.y - hr - 1.2 * s, hr * 1.4, 1.6 * s, pal["trim"])
			_cannon(f, P, pal, 4.4)
		"zero":
			# red helmet with a crest, and the long blond ponytail
			var pt0 := Vector2(hd.x - hr * 0.5 * fc, hd.y - hr * 0.5)
			var swing := sin(f.anim * 0.14) * 2.2 * s
			var pt1 := Vector2(hd.x - hr * 2.4 * fc, hd.y + hr * 1.4 + swing)
			var pt2 := Vector2(hd.x - hr * 3.2 * fc, P["hip"].y - 1.0 * s + swing * 1.4)
			limb(f, pt0, pt1, 3.0 * s, pal["hair"], dark)
			limb(f, pt1, pt2, 2.2 * s, pal["hair"], dark)
			disc_o(f, hd.x, hd.y - 0.5 * s, hr + 0.7 * s, pal["main"], dark)
			px(f, hd.x - hr * 0.9, hd.y + 0.1 * s, hr * 1.9, hr * 0.85, pal["skin"])
			_eyes(f, P, pal)
			# crest fin
			px(f, hd.x - hr * 0.3, hd.y - hr - 2.0 * s, hr * 0.7, 2.4 * s, pal["accent"])
			px(f, hd.x - hr * 1.2 * fc, hd.y - 1.0 * s, 1.6 * s, 2.4 * s, pal["accent"])
			# shoulder pads
			disc_o(f, P["sh"].x + 4.6 * s, P["sh"].y + 0.6 * s, 2.8 * s, pal["main"], dark)
			_saber(f, P, pal)
		"link":
			# green cap with the long point trailing behind
			disc_o(f, hd.x, hd.y - 0.8 * s, hr + 0.6 * s, pal["main"], dark)
			px(f, hd.x - hr, hd.y + 0.2 * s, hr * 2.0, hr, pal["skin"])
			limb(f, Vector2(hd.x - hr * 0.4 * fc, hd.y - hr),
				Vector2(hd.x - hr * 2.6 * fc, hd.y - hr * 0.2), 2.2 * s, pal["main"], dark)
			# blond hair under the cap
			px(f, hd.x - hr * 1.1, hd.y + hr * 0.35, hr * 2.2, 1.6 * s, pal["hair"])
			_eyes(f, P, pal)
			if kit.get("shield", false):
				box(f, hd.x - (5.6 * s * fc) - 1.6 * s, P["sh"].y + 1.0 * s,
					3.2 * s, 8.0 * s, pal["accent"], dark)
			if kit.get("sword", false):
				_sword(f, P, pal)
		"fox":
			# muzzle, ears, tail
			disc_o(f, hd.x, hd.y, hr, pal["skin"], dark)
			px(f, hd.x + hr * 0.5 * fc, hd.y + 0.2 * s, hr * 1.5, hr * 0.85, pal["trim"])
			px(f, hd.x + hr * 1.5 * fc, hd.y + 0.4 * s, 1.4 * s, 1.2 * s, dark)
			# ears
			limb(f, Vector2(hd.x - hr * 0.6, hd.y - hr * 0.7),
				Vector2(hd.x - hr * 1.1, hd.y - hr * 2.1), 2.2 * s, pal["skin"], dark)
			limb(f, Vector2(hd.x + hr * 0.6, hd.y - hr * 0.7),
				Vector2(hd.x + hr * 1.1, hd.y - hr * 2.1), 2.2 * s, pal["skin"], dark)
			_eyes(f, P, pal)
			# tail with a white tip
			var tsw := sin(f.anim * 0.2) * 2.4 * s
			var t0 := Vector2(-3.0 * s * fc, P["hip"].y + 1.0 * s)
			var t1 := Vector2(-10.5 * s * fc, P["hip"].y - 1.0 * s + tsw)
			limb(f, t0, t1, 4.0 * s, pal["skin"], dark)
			disc_o(f, t1.x, t1.y, 2.4 * s, pal["main"], dark)
			# jacket collar
			px(f, P["sh"].x - 4.5 * s, P["sh"].y - 1.0 * s, 9.0 * s, 2.0 * s, pal["trim"])
		"mario":
			# red cap with a brim, and the mustache
			disc_o(f, hd.x, hd.y - 0.7 * s, hr + 0.5 * s, pal["main"], dark)
			px(f, hd.x - hr, hd.y + 0.1 * s, hr * 2.0, hr * 1.0, pal["skin"])
			px(f, hd.x + hr * 0.2 * fc, hd.y - hr * 0.9, hr * 1.9, 1.8 * s, pal["main"])
			px(f, hd.x - hr * 1.2, hd.y + hr * 0.4, hr * 2.4, 1.4 * s, pal["hair"])
			_eyes(f, P, pal)
			# mustache
			px(f, hd.x + hr * 0.1 * fc - 1.0 * s, hd.y + hr * 0.55, hr * 1.6, 1.8 * s,
				pal["hair"])
			# overalls
			px(f, P["sh"].x - 4.5 * s, P["hip"].y - 5.0 * s, 9.0 * s, 6.0 * s, pal["accent"])
			px(f, P["sh"].x - 3.0 * s, P["sh"].y - 1.0 * s, 1.8 * s, 5.0 * s, pal["accent"])
			px(f, P["sh"].x + 1.4 * s, P["sh"].y - 1.0 * s, 1.8 * s, 5.0 * s, pal["accent"])
			px(f, P["sh"].x - 1.0 * s, P["hip"].y - 4.0 * s, 2.0 * s, 2.0 * s, pal["metal"])
		"ness":
			# ball cap, striped shirt, backpack, and the bat when he swings
			px(f, P["sh"].x - 6.2 * s, P["sh"].y - 0.5 * s, 3.0 * s, 7.0 * s, pal["metal"])
			disc_o(f, hd.x, hd.y - 0.6 * s, hr + 0.5 * s, pal["main"], dark)
			px(f, hd.x - hr, hd.y + 0.2 * s, hr * 2.0, hr * 0.9, pal["skin"])
			px(f, hd.x + hr * 0.3 * fc, hd.y - hr * 0.85, hr * 1.9, 1.6 * s, pal["main"])
			px(f, hd.x - hr * 1.1, hd.y + hr * 0.45, hr * 2.2, 1.5 * s, pal["hair"])
			_eyes(f, P, pal)
			# shirt stripes
			for i in range(3):
				px(f, P["sh"].x - 4.5 * s, P["sh"].y + (0.5 + float(i) * 2.4) * s,
					9.0 * s, 1.2 * s, pal["trim"])
			if kit.get("bat", false) and f.move_name in ["side", "fair", "down"]:
				limb(f, P["sh"], hand + Vector2(7.0 * s * fc, -1.0 * s),
					2.6 * s, pal["metal"], dark)
		"kirby":
			pass
		"yoshi":
			pass
		_:
			pass


static func _cannon(f: Fighter, P: Dictionary, pal: Dictionary, size: float) -> void:
	# The arm cannon: a fat barrel replacing the front forearm.
	var s: float = P["s"]
	var fc: float = P["fc"]
	var hand: Vector2 = P["hand_b"]
	var dark: Color = pal["dark"]
	var sh_pt: Vector2 = P["sh"]
	var dir: Vector2 = (hand - sh_pt).normalized()
	if dir.length() < 0.01:
		dir = Vector2(fc, 0)
	var back: Vector2 = hand - dir * 2.0 * s
	limb(f, back, hand + dir * 2.0 * s, size * s, pal["main"], dark)
	var muzzle: Vector2 = hand + dir * 3.0 * s
	disc_o(f, muzzle.x, muzzle.y, size * 0.45 * s, pal["dark"], dark)
	# glow while charging
	if f.state == "charging":
		var g := float(f.charge) / float(Moves.SPECIALS[f.ch["special"]]["max_charge"])
		var gc: Color = pal["accent"]
		gc.a = 0.85
		disc(f, muzzle.x, muzzle.y, 1.0 + 4.0 * g, gc)


# The Z-Saber: a beam, so it is drawn as a bright core inside a wider glow
# rather than as a metal blade.
static func _saber(f: Fighter, P: Dictionary, pal: Dictionary) -> void:
	var s: float = P["s"]
	var fc: float = P["fc"]
	var hand: Vector2 = P["hand_b"]
	var dark: Color = pal["dark"]
	var swinging: bool = f.state == "attack"
	var dir := Vector2(fc, -0.25).normalized()
	if f.move_name in ["up", "uair", "usp_saber"]:
		dir = Vector2(0.25 * fc, -1.0).normalized()
	elif f.move_name == "dair":
		dir = Vector2(0.1 * fc, 1.0).normalized()
	elif not swinging:
		dir = Vector2(0.7 * fc, -0.7).normalized()

	# hilt
	limb(f, hand - dir * 1.6 * s, hand + dir * 1.8 * s, 3.0 * s, pal["metal"], dark)
	if not swinging and f.state not in ["idle", "run", "air", "helpless"]:
		return
	var blade := 13.0 * s if swinging else 10.0 * s
	var tip := hand + dir * blade
	var glow: Color = pal["accent"]
	glow.a = 0.40
	_limb_pass(f, hand + dir * 2.0 * s, tip, 5.0 * s, glow)
	_limb_pass(f, hand + dir * 2.0 * s, tip, 2.6 * s, pal["accent"])
	_limb_pass(f, hand + dir * 2.0 * s, tip, 1.2 * s, Color(1, 1, 1, 0.95))


static func _sword(f: Fighter, P: Dictionary, pal: Dictionary) -> void:
	var s: float = P["s"]
	var fc: float = P["fc"]
	var hand: Vector2 = P["hand_b"]
	var dark: Color = pal["dark"]
	var dir := Vector2(fc, 0.0)
	# point it wherever the attack is going
	if f.move_name in ["up", "uair", "usp_spin"]:
		dir = Vector2(0.2 * fc, -1.0).normalized()
	elif f.move_name in ["dair"]:
		dir = Vector2(0.1 * fc, 1.0).normalized()
	elif f.state == "idle" or f.state == "run" or f.state == "air":
		dir = Vector2(0.85 * fc, -0.5).normalized()
	var tip := hand + dir * 11.0 * s
	# guard
	limb(f, hand - dir * 1.0 * s, hand + dir * 1.4 * s, 4.0 * s, pal["metal"], dark)
	limb(f, hand + dir * 1.5 * s, tip, 2.2 * s, pal["metal"], dark)
	px(f, tip.x - 1.0, tip.y - 1.0, 2, 2, Color(1, 1, 1, 0.8))
