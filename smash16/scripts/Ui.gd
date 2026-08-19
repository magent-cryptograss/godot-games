extends Node2D

# Title / character select / countdown / results overlays.

var main = null


func _ready() -> void:
	z_index = 70


func _draw() -> void:
	if main == null:
		return
	match main.screen:
		main.Screen.TITLE:  _title()
		main.Screen.SELECT: _select()
		main.Screen.COUNT:  _count()
		main.Screen.RESULT: _result()


# ---------------------------------------------------------------------------
func _title() -> void:
	var t: float = main.t
	draw_rect(Rect2(0, 0, Rules.VW, Rules.VH), Color(0, 0, 0, 0.45))

	var bob := sin(t * 0.05) * 2.0
	Txt.center_shadow(self, Rules.VW * 0.5, 62.0 + bob, "SMASH 16", 40, Color("f2e14a"))
	Txt.center_shadow(self, Rules.VW * 0.5, 80.0 + bob, "A 16-BIT PLATFORM FIGHTER", 9,
		Color("aec6e4"))

	Txt.center_shadow(self, Rules.VW * 0.5, 112.0,
		"BUILD UP THEIR PERCENT. KNOCK THEM OFF THE SCREEN.", 8, Color("e8e8f0"))
	Txt.center_shadow(self, Rules.VW * 0.5, 124.0,
		"THE HIGHER THE NUMBER, THE FURTHER THEY FLY.", 8, Color("95b3dd"))

	if int(t / 26.0) % 2 == 0:
		Txt.center_shadow(self, Rules.VW * 0.5, 156.0, "PRESS  F  OR  SPACE", 13,
			Color("ffffff"))

	Txt.center_shadow(self, Rules.VW * 0.5, 190.0,
		"P1  A/D MOVE   W/S AIM   SPACE JUMP   F ATTACK   G SPECIAL   C SHIELD", 7,
		Color("7c9ed4"))
	Txt.center_shadow(self, Rules.VW * 0.5, 200.0,
		"P2  ARROWS   RSHIFT JUMP   . ATTACK   / SPECIAL   , SHIELD", 7,
		Color("7c9ed4"))


# ---------------------------------------------------------------------------
func _select() -> void:
	draw_rect(Rect2(0, 0, Rules.VW, Rules.VH), Color(0, 0, 0, 0.52))
	Txt.center_shadow(self, Rules.VW * 0.5, 18.0, "CHOOSE YOUR FIGHTER", 14, Color("f2e14a"))

	var cw: float = main.CELL_W
	var chh: float = main.CELL_H

	# grid cells
	for i in Chars.count():
		var c: Vector2 = main._cell_center(i)
		var ch: Dictionary = Chars.get_char(i)
		var pal: Dictionary = ch["pal"]
		draw_rect(Rect2(c.x - cw * 0.5 + 1.0, c.y - main.CELL_TOP, cw - 2.0, chh), Color(0, 0, 0, 0.42))
		Art.px(self, c.x - cw * 0.5 + 1.0, c.y - main.CELL_TOP, cw - 2.0, 1, Color(1, 1, 1, 0.10))
		Art.px(self, c.x - cw * 0.5 + 1.0, c.y - main.CELL_TOP, 2.0, chh, pal["main"])
		Txt.center_shadow(self, c.x, c.y + 30.0, String(ch["name"]), 7, Color("e8e8f0"))

	# cursors
	_cursor(0, Color("6cc8ff"), "P1")
	_cursor(1, Color("ff7a7a"), "CPU" if main.p2_cpu else "P2")

	# blurb for whoever P1 is hovering
	var sel_ch: Dictionary = Chars.get_char(int(main.sel[0]))
	Txt.center_shadow(self, Rules.VW * 0.5, 190.0, String(sel_ch["from"]), 8, Color("95b3dd"))
	Txt.center_shadow(self, Rules.VW * 0.5, 201.0, String(sel_ch["blurb"]), 8, Color("f4f4f0"))

	# options line
	var cpu_names := ["EASY", "NORMAL", "HARD"]
	var mode: String = "CPU %s" % cpu_names[main.cpu_level] if main.p2_cpu else "2 PLAYER"
	Txt.center_shadow(self, Rules.VW * 0.5, 216.0,
		"TAB: %s    G: CPU LEVEL    1-5: %d STOCKS    ATTACK: LOCK IN" %
		[mode, main.stock_count], 7, Color("7c9ed4"))


func _cursor(p: int, col: Color, label: String) -> void:
	var i: int = int(main.sel[p])
	var c: Vector2 = main._cell_center(i)
	var cw: float = main.CELL_W
	var chh: float = main.CELL_H
	var pad: float = 2.0 if main.locked[p] else (sin(main.t * 0.14) * 1.2 + 2.2)
	var x: float = c.x - cw * 0.5 + 1.0 - pad
	var y: float = c.y - main.CELL_TOP - pad
	var w: float = cw - 2.0 + pad * 2.0
	var h: float = chh + pad * 2.0
	var th: float = 2.0 if main.locked[p] else 1.0
	Art.px(self, x, y, w, th, col)
	Art.px(self, x, y + h - th, w, th, col)
	Art.px(self, x, y, th, h, col)
	Art.px(self, x + w - th, y, th, h, col)
	# Tag sits INSIDE the cell -- P1 top-left, P2 top-right -- so the two
	# never collide with each other or with the character name below.
	var tag: String = label + ("!" if main.locked[p] else "")
	if p == 0:
		Txt.shadow(self, c.x - cw * 0.5 + 5.0, c.y - main.CELL_TOP + 8.0, tag, 7, col)
	else:
		Txt.shadow(self, c.x + cw * 0.5 - 5.0 - Txt.width(tag, 7),
			c.y - main.CELL_TOP + 8.0, tag, 7, col)


# ---------------------------------------------------------------------------
func _count() -> void:
	var n: int = main.count_t
	var s := ""
	var col := Color("ffffff")
	if n > 135:
		s = "3"
	elif n > 90:
		s = "2"
	elif n > 45:
		s = "1"
	else:
		s = "GO!"
		col = Color("f2e14a")
	# pop in, then settle
	var phase := float(n % 45) / 45.0
	var size := int(lerpf(46.0, 30.0, clampf((1.0 - phase) * 2.2, 0.0, 1.0)))
	Txt.center_shadow(self, Rules.VW * 0.5, 96.0, s, size, col)


# ---------------------------------------------------------------------------
func _result() -> void:
	draw_rect(Rect2(0, 0, Rules.VW, Rules.VH), Color(0, 0, 0, 0.5))
	if main.winner != null:
		var w = main.winner
		Txt.center_shadow(self, Rules.VW * 0.5, 78.0, String(w.ch["name"]) + " WINS",
			26, w.ch["pal"]["main"])
		Txt.center_shadow(self, Rules.VW * 0.5, 98.0,
			"%d STOCK%s LEFT   %d%% DAMAGE" %
			[w.stocks, "" if w.stocks == 1 else "S", int(round(w.percent))],
			9, Color("e8e8f0"))
	else:
		Txt.center_shadow(self, Rules.VW * 0.5, 84.0, "DRAW", 26, Color("e8e8f0"))

	if main.result_t > 60 and int(main.t / 26.0) % 2 == 0:
		Txt.center_shadow(self, Rules.VW * 0.5, 140.0, "PRESS ATTACK", 12, Color("ffffff"))
