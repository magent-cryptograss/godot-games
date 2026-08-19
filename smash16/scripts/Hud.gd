extends Node2D
class_name Hud

# ---------------------------------------------------------------------------
# THE HUD
#
# The percent number is the entire scoreboard, so it gets the biggest type on
# screen and it changes colour as it climbs. By the time it is red you should
# feel nervous just looking at it -- that is the point.
# ---------------------------------------------------------------------------

var fighters: Array = []


func _ready() -> void:
	z_index = 60


func percent_color(p: float) -> Color:
	if p < 40.0:
		return Color("f4f4f0")
	if p < 80.0:
		return Color("f2e14a")
	if p < 120.0:
		return Color("f2953a")
	if p < 160.0:
		return Color("e8503a")
	return Color("ff2a2a")


func _draw() -> void:
	if fighters.is_empty():
		return

	var n := fighters.size()
	var panel_w := 88.0
	var gap := 14.0
	var total := panel_w * n + gap * (n - 1)
	var x0 := (float(Rules.VW) - total) * 0.5
	var y0 := float(Rules.VH) - 32.0

	for i in n:
		var f = fighters[i]
		var x := x0 + float(i) * (panel_w + gap)
		_panel(f, x, y0, panel_w)


func _panel(f, x: float, y: float, w: float) -> void:
	var pal: Dictionary = f.ch["pal"]
	var dead: bool = f.stocks <= 0

	# backing plate
	Art.px(self, x, y, w, 30, Color(0, 0, 0, 0.42))
	Art.px(self, x, y, w, 1, Color(1, 1, 1, 0.14))
	Art.px(self, x, y, 3, 30, pal["main"] if not dead else Color(0.3, 0.3, 0.3))

	# name + who is driving
	var label: String = String(f.ch["name"])
	var tag: String = "CPU" if f.is_cpu else ("P%d" % (f.slot + 1))
	Txt.shadow(self, x + 7.0, y + 10.0, label, 8,
		Color(1, 1, 1, 0.9) if not dead else Color(0.55, 0.55, 0.55))
	Txt.shadow(self, x + w - 20.0, y + 10.0, tag, 8, Color(0.72, 0.78, 0.9))

	if dead:
		Txt.shadow(self, x + 7.0, y + 25.0, "OUT", 14, Color(0.5, 0.5, 0.5))
		return

	# the percent -- the number that matters
	var p := int(round(f.percent))
	var col := percent_color(f.percent)
	var s := "%d" % p
	Txt.shadow(self, x + 7.0, y + 26.0, s, 15, col)
	Txt.shadow(self, x + 7.0 + Txt.width(s, 15) + 1.0, y + 26.0, "%", 9, col)

	# stock icons
	for k in range(f.stocks):
		var sx := x + w - 8.0 - float(k) * 8.0
		Art.disc(self, sx, y + 22.0, 3.0, Color(0, 0, 0, 0.5))
		Art.disc(self, sx, y + 22.0, 2.4, pal["main"])
		Art.px(self, sx - 1.0, y + 20.5, 1, 1, Color(1, 1, 1, 0.7))

	# shield meter, only while it actually matters
	if f.shield_hp < Rules.SHIELD_MAX - 0.5:
		var frac := clampf(f.shield_hp / Rules.SHIELD_MAX, 0.0, 1.0)
		Art.px(self, x + 7.0, y + 28.0, w - 30.0, 2, Color(0, 0, 0, 0.5))
		Art.px(self, x + 7.0, y + 28.0, (w - 30.0) * frac, 2,
			Color("6cc8ff") if frac > 0.3 else Color("ff5a5a"))
