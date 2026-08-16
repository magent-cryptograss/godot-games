extends Node
## Checks the synth actually makes sound, at roughly the right pitch, and mixes
## every tune down to a WAV so a human can hear what no test can judge.
##
##   godot --headless --path <project> res://tests/TestAudio.tscn

const OUT_DIR := "user://audio/"

var failures := 0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	print("")
	print("== audio ==")
	_check_voices()
	_check_pitch()
	_check_tunes()
	_render_all()
	print("")
	print("FAILURES: %d" % failures if failures > 0 else "AUDIO CHECKS PASSED")
	get_tree().quit(1 if failures > 0 else 0)


func _expect(cond: bool, what: String) -> void:
	if cond:
		print("  ok   %s" % what)
	else:
		print("  FAIL %s" % what)
		failures += 1


func _check_voices() -> void:
	# every voice must produce audible signal, not silence and not a DC blast
	for voice in ["pluck", "bow", "reed", "bell", "bass", "noise"]:
		var w := Audio._render(voice, 440.0, 0.5, 8.0)
		var s := Audio._samples_of(w)
		var level := Audio.rms(s)
		_expect(level > 0.01 and level < 0.9, "%s sounds (rms %.3f)" % [voice, level])
		# and it has to decay, or notes will smear into each other
		var head := Audio.rms(s.slice(0, int(s.size() * 0.2)))
		var tail := Audio.rms(s.slice(int(s.size() * 0.8)))
		_expect(tail < head, "%s decays (%.3f -> %.3f)" % [voice, head, tail])


func _check_pitch() -> void:
	# a note asked for at 440 should come out near 440, not an octave adrift
	for f in [220.0, 440.0, 880.0]:
		var s := Audio._samples_of(Audio._render("pluck", f, 0.4, 8.0))
		var got := Audio.estimate_pitch(s)
		var off: float = absf(got - f) / f
		_expect(off < 0.15, "pluck at %d Hz reads as %d Hz" % [int(f), int(got)])

	# and the note table itself
	for pair in [["A4", 440.0], ["A3", 220.0], ["C4", 261.6], ["G3", 196.0]]:
		var got: float = Audio.note_freq(pair[0])
		_expect(absf(got - pair[1]) / pair[1] < 0.01,
			"%s = %.1f Hz" % [pair[0], got])
	_expect(Audio.note_freq("0") == 0.0, "rest is silent")


func _check_tunes() -> void:
	_expect(Audio.TUNES.size() == 9, "%d tunes defined" % Audio.TUNES.size())
	for name in Audio.TUNES:
		var tune: Dictionary = Audio.TUNES[name]
		var bad := 0
		for tr in tune.tracks:
			for ev in tr.seq:
				var n := str(ev[0])
				if n != "0" and Audio.note_freq(n) <= 0.0:
					print("    %s: unparseable note '%s'" % [name, n])
					bad += 1
				if float(ev[1]) <= 0.0:
					print("    %s: note with no duration" % name)
					bad += 1
		_expect(bad == 0, "%s parses cleanly (%d tracks)" % [name, tune.tracks.size()])


func _render_all() -> void:
	print("")
	for name in ["title", "town", "field", "battle", "boss", "cave", "ending"]:
		var secs := 12.0
		var mix := Audio.render_tune(name, secs)
		var level := Audio.rms(mix)
		var path := Audio.save_wav(mix, OUT_DIR + name + ".wav")
		_expect(level > 0.02, "%s mixed down (rms %.3f)" % [name, level])
		print("       -> %s" % path)
