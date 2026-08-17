extends Node
## The elemental matchups, checked pair by pair against what was asked for.
##
## A rules table is exactly the kind of thing that looks right in the source and
## is wrong in play, because nothing about a dictionary of strings will ever
## fail on its own. Every line below is one of the stated rules written out
## again independently, so a typo in the table shows up as a disagreement rather
## than as a fight that feels slightly off.

var failures := 0


func _expect(cond: bool, what: String) -> void:
	if cond:
		print("  ok   %s" % what)
	else:
		print("  FAIL %s" % what)
		failures += 1


func _ready() -> void:
	print("")
	print("== elemental matchups ==")

	# ---- weakness, as specified ------------------------------------------
	var asked := {
		"fire": ["water", "earth"],
		"water": ["ice", "electric"],
		"earth": ["water"],
		"ice": ["fire", "electric"],
		"electric": ["earth", "wind"],
		"plant": ["fire", "dark"],
		"wind": ["earth"],
		"dark": ["fire", "electric"],
	}
	var wrong: Array = []
	for elem in asked:
		var got: Array = Data.WEAK.get(elem, [])
		var want: Array = asked[elem]
		if got.size() != want.size():
			wrong.append("%s: %s not %s" % [elem, str(got), str(want)])
			continue
		for w in want:
			if not got.has(w):
				wrong.append("%s is not weak to %s" % [elem, w])
	_expect(wrong.is_empty(), "every weakness is as asked (%s)" % str(wrong))
	_expect(Data.WEAK.size() == 8, "all eight elements have a weakness row (%d)" % Data.WEAK.size())

	# ---- resistance is the exact inverse ----------------------------------
	var bad: Array = []
	for a in Data.ELEMENTS:
		for b in Data.ELEMENTS:
			var strong_against: bool = Data.WEAK.get(b.id, []).has(a.id)
			if Data.resists(a.id, b.id) != strong_against:
				bad.append("%s vs %s" % [a.id, b.id])
	_expect(bad.is_empty(), "everything resists what it beats, and only that (%s)" % str(bad))

	# nothing should beat itself or resist itself
	var selfish: Array = []
	for e in Data.ELEMENTS:
		if Data.WEAK.get(e.id, []).has(e.id) or Data.resists(e.id, e.id):
			selfish.append(str(e.id))
	_expect(selfish.is_empty(), "no element beats or resists itself (%s)" % str(selfish))

	# ---- and the multiplier follows the table -----------------------------
	_expect(Data.elem_effect("water", "fire") > 1.0, "water lands hard on fire")
	_expect(Data.elem_effect("fire", "water") < 1.0, "fire glances off water")
	_expect(is_equal_approx(Data.elem_effect("fire", "wind"), 1.0),
		"an unrelated pair is neither (%0.2f)" % Data.elem_effect("fire", "wind"))
	_expect(Data.elem_effect("fire", "plant") > 1.0 and Data.elem_effect("dark", "plant") > 1.0,
		"plant is beaten by both of the two that beat it")

	# ---- charging, as specified -------------------------------------------
	var charge_asked := {
		"fire": ["plant", "wind"],
		"water": ["electric", "ice"],
		"earth": ["plant"],
		"ice": ["water"],
		"electric": ["water"],
		"plant": ["water", "earth"],
		"wind": ["water", "plant"],
		"dark": ["dark"],
	}
	var cwrong: Array = []
	for elem in charge_asked:
		var got: Array = Data.CHARGED_BY.get(elem, [])
		var want: Array = charge_asked[elem]
		if got.size() != want.size():
			cwrong.append("%s: %s not %s" % [elem, str(got), str(want)])
			continue
		for w in want:
			if not got.has(w):
				cwrong.append("%s is not charged by %s" % [elem, w])
	_expect(cwrong.is_empty(), "every charge is as asked (%s)" % str(cwrong))

	# read the other way round: a hit of water should charge four things
	var from_water := Data.charges_from("water")
	from_water.sort()
	_expect(str(from_water) == '["electric", "ice", "plant", "wind"]',
		"a water hit charges ice, electric, plant and wind (%s)" % str(from_water))
	var from_dark := Data.charges_from("dark")
	_expect(str(from_dark) == '["dark"]', "a dark hit charges only dark (%s)" % str(from_dark))
	_expect(Data.charges_from("fire").is_empty(),
		"a fire hit charges nothing (%s)" % str(Data.charges_from("fire")))

	# charging is deliberately not the same shape as weakness -- water charges
	# ice and electric even though it is not weak to either
	_expect(Data.CHARGED_BY["water"].has("ice") and not Data.WEAK["ice"].has("water"),
		"a charge can come from an element you are not weak to")

	# ---- every creature has an element the tables know about ---------------
	var unknown: Array = []
	for id in Data.BESTIARY:
		var elem := str(Data.BESTIARY[id].get("elem", ""))
		if not Data.WEAK.has(elem):
			unknown.append("%s (%s)" % [id, elem])
	_expect(unknown.is_empty(), "every creature has a known element (%s)" % str(unknown))

	print("")
	if failures > 0:
		print("FAILURES: %d" % failures)
	else:
		print("ELEMENTS PASSED")
	get_tree().quit(1 if failures > 0 else 0)
