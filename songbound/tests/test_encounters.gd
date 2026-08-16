extends Node
## Measures how far you actually walk between fights.
##
## Encounter rate is the thing a player notices first and complains about first,
## and it is invisible in every other test. This walks a million simulated steps
## and reports steps-per-encounter for each region and terrain, using the same
## constants the game uses rather than a copy of them.

const FieldScript := preload("res://scripts/Field.gd")
const STEPS := 200000

var failures := 0


func _ready() -> void:
	print("")
	print("== encounter spacing ==")
	print("region    terrain        chance/step   steps between fights")
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242

	for region in ["meadow", "wood", "crag", "cave", "deep",
			"hollow", "chapel", "kennel", "spire", "thicket"]:
		var terrains := [".", ","] if region in ["meadow", "wood", "crag"] else ["D"]
		for tile in terrains:
			var wgt := Maps.enc_weight(tile)
			var rate: float = Data.REGIONS[region].rate
			var p := rate * wgt * FieldScript.ENCOUNTER_SCALE
			var spacing := _walk(region, tile, rng)
			print("%-9s %-14s %-13.4f %.1f" % [region, _name_of(tile), p, spacing])
			# Under about 15 steps is harassment; over about 70 and the world
			# feels empty and the player never levels.
			if spacing < 15.0:
				_fail("%s/%s: a fight every %.1f steps is too often" % [region, _name_of(tile), spacing])
			if spacing > 70.0:
				_fail("%s/%s: a fight every %.1f steps is too rare" % [region, _name_of(tile), spacing])

	print("")
	_note("grace after each fight: %d steps" % FieldScript.ENCOUNTER_GRACE)
	print("")
	if failures == 0:
		print("ENCOUNTER SPACING PASSED")
	else:
		print("FAILURES: %d" % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _fail(what: String) -> void:
	print("  FAIL %s" % what)
	failures += 1

func _note(what: String) -> void:
	print("  ok   %s" % what)


func _name_of(tile: String) -> String:
	match tile:
		".": return "open ground"
		",": return "tall grass"
		"D": return "cave floor"
	return tile


## Replays exactly what Field does per step: burn the grace period down, then
## roll. Returns the mean number of steps between encounters.
func _walk(region: String, tile: String, rng: RandomNumberGenerator) -> float:
	var wgt := Maps.enc_weight(tile)
	var chance: float = Data.REGIONS[region].rate * wgt * FieldScript.ENCOUNTER_SCALE
	var cool := FieldScript.ENCOUNTER_GRACE
	var encounters := 0
	for i in STEPS:
		if cool > 0:
			cool -= 1
			continue
		if rng.randf() < chance:
			encounters += 1
			cool = FieldScript.ENCOUNTER_GRACE
	if encounters == 0:
		return 9999.0
	return float(STEPS) / float(encounters)
