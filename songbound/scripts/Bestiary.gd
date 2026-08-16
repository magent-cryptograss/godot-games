class_name Bestiary
extends RefCounted
## Creature art. Every one is drawn in code -- no sprite sheets -- so the whole
## game stays a handful of scripts.
##
## In fiction these are not animals: an abandoned instrument takes the shape of
## the last thing that heard it, so a fiddle left in a briar patch comes back
## briar. That is why the bestiary looks like wildlife and reads as instruments.

static func draw_art(ci: CanvasItem, art: String, x: float, y: float, t: float) -> void:
	match art:
		"thistle": _thistle(ci, x, y, t)
		"mire": _mire(ci, x, y, t)
		"cinder": _cinder(ci, x, y, t)
		"rime": _rime(ci, x, y, t)
		"sparkhare": _sparkhare(ci, x, y, t)
		"galecrow": _galecrow(ci, x, y, t)
		"sentinel": _sentinel(ci, x, y, t)
		"gloomcap": _gloomcap(ci, x, y, t)
		"gravehound": _gravehound(ci, x, y, t)
		"discord": _discord(ci, x, y, t)
		"bogwitch": _bogwitch(ci, x, y, t)
		"thunderram": _thunderram(ci, x, y, t)
		"gravebell": _gravebell(ci, x, y, t)
		"conductor": _conductor(ci, x, y, t)
		"quiet": _quiet(ci, x, y, t)
		_: _thistle(ci, x, y, t)


static func _r(ci: CanvasItem, x: float, y: float, w: float, h: float, c: Color) -> void:
	ci.draw_rect(Rect2(round(x), round(y), w, h), c, true)

static func _line(ci: CanvasItem, x0: float, y0: float, x1: float, y1: float, c: Color) -> void:
	ci.draw_line(Vector2(round(x0), round(y0)), Vector2(round(x1), round(y1)), c, 1.0)

static func _hash(x: int, y: int) -> float:
	return Maps.hash2(x, y)


static func _thistle(ci: CanvasItem, x: float, y: float, t: float) -> void:
	var sw := sin(t * 3.8) * 2.0
	UI.pellipse(ci, x + 20, y + 30, 11, 5, Color("#2e5020"))
	for i in 7:
		var a := i * 0.85 + t * 1.1
		_line(ci, x + 20, y + 30, x + 20 + cos(a) * (12 + sw),
			y + 30 - absf(sin(a)) * 20 - 3, Color("#3a7028") if i % 2 == 1 else Color("#4a8a30"))
	UI.pellipse(ci, x + 20, y + 16, 9, 8, Color("#6ac83a"))
	UI.pellipse(ci, x + 18, y + 14, 6, 5, Color("#8ae052"))
	_r(ci, x + 15, y + 14, 3, 3, Color("#f8f0a0"))
	_r(ci, x + 22, y + 14, 3, 3, Color("#f8f0a0"))
	_r(ci, x + 16, y + 15, 2, 2, Color("#0d0a14"))
	_r(ci, x + 23, y + 15, 2, 2, Color("#0d0a14"))
	_r(ci, x + 17, y + 20, 7, 2, Color("#285018"))


static func _mire(ci: CanvasItem, x: float, y: float, t: float) -> void:
	var wob := sin(t * 3.3) * 2.0
	UI.pellipse(ci, x + 20, y + 26 + wob * 0.3, 14 + wob, 10 - wob * 0.4, Color("#1a5a90"))
	UI.pellipse(ci, x + 20, y + 23, 12, 7, Color("#2078b0"))
	UI.pellipse(ci, x + 17, y + 21, 6, 3, Color("#50b0e8"))
	_r(ci, x + 14, y + 20, 4, 4, Color("#f0ecf8"))
	_r(ci, x + 23, y + 20, 4, 4, Color("#f0ecf8"))
	_r(ci, x + 15, y + 21, 2, 2, Color("#0d0a14"))
	_r(ci, x + 24, y + 21, 2, 2, Color("#0d0a14"))
	for i in 4:
		var dy := fmod(t * 120.0 + i * 40.0, 34.0)
		_r(ci, x + 10 + i * 7, y + 10 + dy * 0.4, 2, 3, Color("#50b0e8"))


static func _cinder(ci: CanvasItem, x: float, y: float, t: float) -> void:
	var fl := sin(t * 10.0)
	for i in 10:
		var a := t * 5.0 + i * 0.63
		_r(ci, x + 20 + cos(a) * (13 + fl * 2), y + 20 + sin(a) * (13 + fl * 2), 2, 2,
			Color("#ff7a30") if i % 2 == 1 else Color("#f0d040"))
	UI.pellipse(ci, x + 20, y + 22, 8, 9, Color("#a02808"))
	UI.pellipse(ci, x + 20, y + 20, 6, 6, Color("#ff7a30"))
	UI.pellipse(ci, x + 19, y + 18, 4, 3, Color("#f8f0a0"))
	_r(ci, x + 16, y + 19, 3, 3, Color("#0d0a14"))
	_r(ci, x + 22, y + 19, 3, 3, Color("#0d0a14"))
	_r(ci, x + 17, y + 25, 7, 2, Color("#501838"))
	_line(ci, x + 14, y + 12, x + 11, y + 4 + fl * 2, Color("#ff7a30"))
	_line(ci, x + 26, y + 12, x + 29, y + 4 - fl * 2, Color("#ff7a30"))
	_r(ci, x + 14, y + 30, 4, 3, Color("#a02808"))
	_r(ci, x + 22, y + 30, 4, 3, Color("#a02808"))


static func _rime(ci: CanvasItem, x: float, y: float, t: float) -> void:
	var b := sin(t * 2.5) * 2.0
	UI.pcircle(ci, x + 20, y + 20 + b, 15, Color(0.66, 0.88, 0.97, 0.35))
	for i in 6:
		var a := i * 1.05 + t * 1.2
		_line(ci, x + 20, y + 20 + b, x + 20 + cos(a) * 13, y + 20 + b + sin(a) * 13, Color("#a8e0f8"))
		_r(ci, x + 20 + cos(a) * 13, y + 20 + b + sin(a) * 13, 2, 2, Color("#f0ecf8"))
	UI.pcircle(ci, x + 20, y + 20 + b, 7, Color("#50b0e8"))
	UI.pcircle(ci, x + 20, y + 20 + b, 5, Color("#a8e0f8"))
	_r(ci, x + 17, y + 18 + b, 2, 3, Color("#103858"))
	_r(ci, x + 22, y + 18 + b, 2, 3, Color("#103858"))


static func _sparkhare(ci: CanvasItem, x: float, y: float, t: float) -> void:
	var b := sin(t * 6.0) * 2.0
	UI.pellipse(ci, x + 21, y + 26 + b, 9, 7, Color("#c8a068"))
	UI.pellipse(ci, x + 14, y + 20 + b, 6, 6, Color("#e8c090"))
	_r(ci, x + 11, y + 19 + b, 3, 3, Color("#f0d040"))
	_r(ci, x + 16, y + 19 + b, 2, 2, Color("#0d0a14"))
	_r(ci, x + 12, y + 8 + b, 3, 10, Color("#c8a068"))
	_r(ci, x + 17, y + 7 + b, 3, 11, Color("#c8a068"))
	_r(ci, x + 13, y + 10 + b, 1, 7, Color("#e878b0"))
	_r(ci, x + 18, y + 9 + b, 1, 8, Color("#e878b0"))
	_r(ci, x + 26, y + 22 + b, 5, 4, Color("#e8c090"))
	_r(ci, x + 16, y + 31, 4, 3, Color("#a06840"))
	_r(ci, x + 23, y + 31, 4, 3, Color("#a06840"))
	var fr := int(t * 14.0)
	for i in 6:
		var a := _hash(i, fr) * 6.28
		var rr := 12.0 + _hash(i + 5, fr) * 8.0
		_r(ci, x + 20 + cos(a) * rr, y + 20 + sin(a) * rr, 2, 2, Color("#f0d040"))


static func _galecrow(ci: CanvasItem, x: float, y: float, t: float) -> void:
	var fl := sin(t * 7.7)
	UI.pellipse(ci, x + 20, y + 22, 7, 9, Color("#2a2438"))
	UI.pcircle(ci, x + 20, y + 12, 5, Color("#4a4458"))
	_r(ci, x + 17, y + 11, 3, 3, Color("#a0f0d0"))
	_r(ci, x + 22, y + 11, 3, 3, Color("#a0f0d0"))
	_r(ci, x + 18, y + 12, 1, 1, Color("#0d0a14"))
	_r(ci, x + 23, y + 12, 1, 1, Color("#0d0a14"))
	_r(ci, x + 19, y + 15, 4, 2, Color("#e8a020"))
	for i in 7:
		_line(ci, x + 14, y + 18, x + 5 - i, y + 16 + i * 2 + fl * 5, Color("#2a2438"))
		_line(ci, x + 26, y + 18, x + 35 + i, y + 16 + i * 2 + fl * 5, Color("#2a2438"))
	_r(ci, x + 17, y + 30, 2, 5, Color("#e8a020"))
	_r(ci, x + 22, y + 30, 2, 5, Color("#e8a020"))


static func _sentinel(ci: CanvasItem, x: float, y: float, t: float) -> void:
	var b := sin(t * 2.0)
	_r(ci, x + 11, y + 14 + b, 18, 18, Color("#6a4a28"))
	_r(ci, x + 11, y + 14 + b, 18, 3, Color("#c8a068"))
	_r(ci, x + 13, y + 18 + b, 5, 5, Color("#8a6a38"))
	_r(ci, x + 22, y + 18 + b, 5, 5, Color("#8a6a38"))
	_r(ci, x + 6, y + 17 + b, 5, 12, Color("#6a4a28"))
	_r(ci, x + 29, y + 17 + b, 5, 12, Color("#6a4a28"))
	_r(ci, x + 14, y + 6 + b, 12, 9, Color("#8a6a38"))
	_r(ci, x + 16, y + 9 + b, 3, 3, Color("#f0d040"))
	_r(ci, x + 22, y + 9 + b, 3, 3, Color("#f0d040"))
	_r(ci, x + 13, y + 32, 6, 4, Color("#4a3418"))
	_r(ci, x + 22, y + 32, 6, 4, Color("#4a3418"))


static func _gloomcap(ci: CanvasItem, x: float, y: float, t: float) -> void:
	var b := sin(t * 2.9)
	_r(ci, x + 16, y + 20 + b, 8, 12, Color("#b0aac0"))
	_r(ci, x + 16, y + 20 + b, 3, 12, Color("#f0ecf8"))
	UI.pellipse(ci, x + 20, y + 18 + b, 13, 8, Color("#503078"))
	UI.pellipse(ci, x + 20, y + 16 + b, 12, 6, Color("#6038a0"))
	for i in 5:
		UI.pcircle(ci, x + 11 + i * 5, y + 14 + b + (i % 2) * 2, 2, Color("#a878e0"))
	_r(ci, x + 16, y + 24 + b, 2, 3, Color("#0d0a14"))
	_r(ci, x + 22, y + 24 + b, 2, 3, Color("#0d0a14"))
	for i in 5:
		_r(ci, x + 12 + i * 4, y + 6 + b - fmod(t * 50.0 + i * 7.0, 8.0), 1, 2, Color(0.66, 0.47, 0.88, 0.6))


static func _gravehound(ci: CanvasItem, x: float, y: float, t: float) -> void:
	var b := sin(t * 4.2) * 1.5
	UI.pellipse(ci, x + 24, y + 24 + b, 13, 8, Color("#2a2438"))
	_r(ci, x + 14, y + 30, 4, 6, Color("#1a1424"))
	_r(ci, x + 21, y + 30, 4, 6, Color("#1a1424"))
	_r(ci, x + 28, y + 30, 4, 6, Color("#1a1424"))
	UI.pellipse(ci, x + 11, y + 18 + b, 8, 7, Color("#2a2438"))
	UI.pellipse(ci, x + 4, y + 20 + b, 4, 3, Color("#1a1424"))
	_r(ci, x + 7, y + 16 + b, 3, 3, Color("#c03828"))
	_r(ci, x + 13, y + 16 + b, 3, 3, Color("#c03828"))
	_r(ci, x + 8, y + 16 + b, 1, 1, Color("#f06848"))
	_r(ci, x + 14, y + 16 + b, 1, 1, Color("#f06848"))
	_line(ci, x + 8, y + 11 + b, x + 6, y + 4 + b, Color("#2a2438"))
	_line(ci, x + 15, y + 11 + b, x + 17, y + 4 + b, Color("#2a2438"))
	for i in 4:
		_r(ci, x + 2 + i * 3, y + 23 + b, 1, 3, Color("#f0ecf8"))
	_line(ci, x + 36, y + 21 + b, x + 42, y + 12 + b, Color("#2a2438"))


static func _discord(ci: CanvasItem, x: float, y: float, t: float) -> void:
	# a smashed instrument that will not stop playing
	UI.pellipse(ci, x + 20, y + 22, 10, 12, Color("#8a4a24"))
	UI.pellipse(ci, x + 20, y + 22, 8, 10, Color("#c07840"))
	UI.pcircle(ci, x + 20, y + 22, 4, Color("#2a2438"))
	_r(ci, x + 18, y + 2, 4, 12, Color("#5a2a18"))
	_r(ci, x + 16, y + 0, 8, 3, Color("#4a4458"))
	for i in 4:
		var off := sin(t * 7.5 + i) * 2.0
		_line(ci, x + 17 + i * 2, y + 3, x + 17 + i * 2 + off, y + 30, Color("#f0ecf8"))
	_r(ci, x + 14, y + 18, 4, 4, Color("#0d0a14"))
	_r(ci, x + 23, y + 18, 4, 4, Color("#0d0a14"))
	_r(ci, x + 15, y + 19, 2, 2, Color("#c03828"))
	_r(ci, x + 24, y + 19, 2, 2, Color("#c03828"))
	for i in 5:
		var a := t * 5.0 + i * 1.25
		_r(ci, x + 20 + cos(a) * 17, y + 20 + sin(a) * 15, 2, 3, Color("#b0aac0"))


static func _bogwitch(ci: CanvasItem, x: float, y: float, t: float) -> void:
	var b := sin(t * 2.6)
	_r(ci, x + 13, y + 16 + b, 14, 18, Color("#285018"))
	_r(ci, x + 13, y + 30 + b, 14, 4, Color("#1a3810"))
	_r(ci, x + 9, y + 18 + b, 4, 10, Color("#285018"))
	_r(ci, x + 27, y + 18 + b, 4, 10, Color("#285018"))
	_r(ci, x + 9, y + 27 + b, 4, 2, Color("#a06840"))
	_r(ci, x + 27, y + 27 + b, 4, 2, Color("#a06840"))
	UI.pellipse(ci, x + 20, y + 11 + b, 6, 6, Color("#a06840"))
	_r(ci, x + 16, y + 10 + b, 3, 2, Color("#f0d040"))
	_r(ci, x + 22, y + 10 + b, 3, 2, Color("#f0d040"))
	_r(ci, x + 18, y + 14 + b, 4, 1, Color("#0d0a14"))
	_r(ci, x + 12, y + 4 + b, 17, 3, Color("#2a2438"))
	for i in 5:
		_r(ci, x + 17 + i, y - 2 - i + b, 3, 4, Color("#2a2438"))
	_line(ci, x + 31, y + 30 + b, x + 33, y + 6 + b, Color("#5a2a18"))
	UI.pcircle(ci, x + 33, y + 5 + b, 3, Color("#78d048"))
	UI.pcircle(ci, x + 33, y + 5 + b, 6, Color(0.47, 0.82, 0.28, 0.4))


static func _thunderram(ci: CanvasItem, x: float, y: float, t: float) -> void:
	var b := sin(t * 3.6)
	UI.pellipse(ci, x + 22, y + 24 + b, 13, 9, Color("#b0aac0"))
	UI.pellipse(ci, x + 22, y + 21 + b, 12, 6, Color("#f0ecf8"))
	_r(ci, x + 14, y + 31, 4, 5, Color("#4a4458"))
	_r(ci, x + 21, y + 31, 4, 5, Color("#4a4458"))
	_r(ci, x + 27, y + 31, 4, 5, Color("#4a4458"))
	UI.pellipse(ci, x + 10, y + 18 + b, 7, 6, Color("#f0ecf8"))
	_r(ci, x + 5, y + 17 + b, 3, 3, Color("#f0d040"))
	_r(ci, x + 11, y + 17 + b, 3, 3, Color("#f0d040"))
	_r(ci, x + 6, y + 18 + b, 1, 1, Color("#0d0a14"))
	_r(ci, x + 12, y + 18 + b, 1, 1, Color("#0d0a14"))
	for i in 6:
		var a := i * 0.7
		_r(ci, x + 6 - sin(a) * 5, y + 12 + b - i, 3, 2, Color("#c8a068"))
		_r(ci, x + 15 + sin(a) * 5, y + 12 + b - i, 3, 2, Color("#c8a068"))
	if _hash(int(t * 16.0), 3) > 0.55:
		_line(ci, x + 22, y + 4, x + 19, y + 12, Color("#f0d040"))
		_line(ci, x + 19, y + 12, x + 25, y + 10, Color("#f0d040"))
		_line(ci, x + 25, y + 10, x + 21, y + 18, Color("#f8f0a0"))


static func _gravebell(ci: CanvasItem, x: float, y: float, t: float) -> void:
	var sw := sin(t * 3.3) * 3.0
	_r(ci, x + 20 + sw * 0.3, y - 4, 4, 10, Color("#4a4458"))
	UI.pellipse(ci, x + 22 + sw, y + 24, 20, 22, Color("#6a4a28"))
	UI.pellipse(ci, x + 22 + sw, y + 22, 18, 19, Color("#c8a068"))
	UI.pellipse(ci, x + 18 + sw, y + 16, 8, 9, Color("#e8c090"))
	_r(ci, x + 2 + sw, y + 40, 40, 5, Color("#8a6a38"))
	_r(ci, x + 2 + sw, y + 40, 40, 2, Color("#e8c090"))
	UI.pellipse(ci, x + 22 + sw * 2.2, y + 47, 5, 5, Color("#4a4458"))
	_r(ci, x + 12 + sw, y + 20, 6, 7, Color("#0d0a14"))
	_r(ci, x + 26 + sw, y + 20, 6, 7, Color("#0d0a14"))
	_r(ci, x + 13 + sw, y + 21, 3, 4, Color("#f0d040"))
	_r(ci, x + 27 + sw, y + 21, 3, 4, Color("#f0d040"))
	_r(ci, x + 16 + sw, y + 32, 13, 3, Color("#0d0a14"))
	for i in 3:
		UI.pring(ci, x + 22, y + 26, 26 + i * 9 + fmod(t * 33.0, 9.0), Color(0.78, 0.63, 0.41, 0.18), 1)


static func _conductor(ci: CanvasItem, x: float, y: float, t: float) -> void:
	var b := sin(t * 2.4)
	var wave := sin(t * 6.2) * 7.0
	_r(ci, x + 15, y + 14 + b, 18, 30, Color("#1a1424"))
	_r(ci, x + 15, y + 14 + b, 18, 3, Color("#2a2438"))
	_r(ci, x + 23, y + 17 + b, 2, 27, Color("#302060"))
	_r(ci, x + 8, y + 15 + b, 7, 16, Color("#1a1424"))
	_r(ci, x + 33, y + 15 + b, 7, 16 + wave * 0.3, Color("#1a1424"))
	_r(ci, x + 20, y + 15 + b, 8, 9, Color("#f0ecf8"))
	_r(ci, x + 23, y + 16 + b, 2, 13, Color("#c03828"))
	UI.pellipse(ci, x + 24, y + 8 + b, 7, 7, Color("#b0aac0"))
	_r(ci, x + 19, y + 6 + b, 4, 3, Color("#0d0a14"))
	_r(ci, x + 26, y + 6 + b, 4, 3, Color("#0d0a14"))
	_r(ci, x + 20, y + 7 + b, 2, 1, Color("#c03828"))
	_r(ci, x + 27, y + 7 + b, 2, 1, Color("#c03828"))
	_r(ci, x + 19, y + 12 + b, 11, 2, Color("#0d0a14"))
	_r(ci, x + 16, y - 1 + b, 17, 3, Color("#0d0a14"))
	_r(ci, x + 19, y - 7 + b, 11, 7, Color("#0d0a14"))
	_line(ci, x + 40, y + 20 + b, x + 48, y + 8 + wave + b, Color("#f0ecf8"))
	for i in 5:
		var a := t * 4.0 + i * 1.25
		_r(ci, x + 24 + cos(a) * 26, y + 18 + sin(a) * 20, 3, 4, Color("#a878e0"))


static func _quiet(ci: CanvasItem, x: float, y: float, t: float) -> void:
	# rim light first: the mass is nearly the value of its own background, and
	# without an edge it simply vanishes
	var pulse := 0.55 + sin(t * 1.7) * 0.15
	UI.pcircle(ci, x + 30, y + 28, 38, Color(0.38, 0.22, 0.63, 0.30 * pulse))
	UI.pring(ci, x + 30, y + 28, 29, Color(0.66, 0.47, 0.88, 0.55), 2)
	UI.pring(ci, x + 30, y + 28, 27, Color(0.38, 0.22, 0.63, 0.45), 3)
	for i in 6:
		var r := 26 - i * 3 + sin(t * 2.0 + i) * 2.0
		UI.pcircle(ci, x + 30, y + 28, r + 9, Color(0.14, 0.09, 0.22, 0.2))
		UI.pcircle(ci, x + 30, y + 28, r, Color("#150f22") if i % 2 == 1 else Color("#241640"))
	for i in 8:
		var a := t * 1.25 + i * 0.79
		var mx := x + 30 + cos(a) * (15 + sin(t * 3.3 + i) * 4)
		var my := y + 28 + sin(a * 1.15) * (15 + cos(t * 2.5 + i) * 4)
		var open := 2 + absf(sin(t * 3.8 + i * 2)) * 4
		UI.pellipse(ci, mx, my, 5, open, Color.BLACK)
		_r(ci, mx - 4, my - open, 9, 1, Color("#503078"))
		_r(ci, mx - 4, my + open, 9, 1, Color("#503078"))
		for k in 4:
			_r(ci, mx - 3 + k * 2, my - open, 1, 2, Color("#a878e0"))
	var fr := int(t * 5.0)
	for i in 50:
		var a := _hash(i, fr) * 6.28
		var rr := 30.0 + _hash(i + 3, fr) * 18.0
		_r(ci, x + 30 + cos(a) * rr, y + 28 + sin(a) * rr, 1, 1, Color(0.66, 0.47, 0.88, 0.45))
