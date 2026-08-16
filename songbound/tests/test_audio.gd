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
	_check_drums()
	_check_echo()
	_check_phase()
	_report_shape()
	_check_names()
	_check_song_tunes()
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
	for voice in ["pluck", "bow", "reed", "bell", "bass", "noise",
			"lead", "harp", "strings", "flute"]:
		var w := Audio._render(voice, 440.0, 0.5, 8.0)
		var s := Audio._samples_of(w)
		var level := Audio.rms(s)
		_expect(level > 0.01 and level < 0.9, "%s sounds (rms %.3f)" % [voice, level])
		# and it has to decay, or notes will smear into each other
		var head := Audio.rms(s.slice(0, int(s.size() * 0.2)))
		var tail := Audio.rms(s.slice(int(s.size() * 0.8)))
		_expect(tail < head, "%s decays (%.3f -> %.3f)" % [voice, head, tail])


## The kit is one voice that picks its drum from the pitch it is handed, so the
## three of them have to actually come out different.
func _check_drums() -> void:
	var levels := {}
	for d in [["kick", 32.7], ["snare", 130.8], ["hat", 1046.5]]:
		var s := Audio._samples_of(Audio._render("drum", float(d[1]), 0.3, 8.0))
		levels[d[0]] = Audio.rms(s)
		_expect(levels[d[0]] > 0.01, "%s sounds (rms %.3f)" % [d[0], levels[d[0]]])
	# a kick is mostly low energy and a hat is mostly high; if the branch ever
	# stops branching they come out identical
	var kick := Audio._samples_of(Audio._render("drum", 32.7, 0.3, 8.0))
	var hat := Audio._samples_of(Audio._render("drum", 1046.5, 0.3, 8.0))
	var kz := _crossings(kick)
	var hz := _crossings(hat)
	_expect(hz > kz * 4, "the hat is far brighter than the kick (%d vs %d crossings)" % [hz, kz])


func _crossings(s: PackedFloat32Array) -> int:
	var n := 0
	for i in range(1, s.size()):
		if (s[i - 1] < 0.0) != (s[i] < 0.0):
			n += 1
	return n


## The echo is the sound being asked for, so it gets a real check: with it on,
## the note has to keep ringing after the note has stopped.
func _check_echo() -> void:
	var dry := Audio._samples_of(Audio._render("lead", 440.0, 0.35, 9.0, 0.0))
	var wet := Audio._samples_of(Audio._render("lead", 440.0, 0.35, 9.0, 1.0))
	_expect(wet.size() > dry.size(),
		"the echo leaves room to ring (%d samples vs %d)" % [wet.size(), dry.size()])

	# energy in the second after the note ends -- silence in a dry render
	var tail_from := dry.size()
	var tail := PackedFloat32Array()
	for i in range(tail_from, wet.size()):
		tail.append(wet[i])
	var tail_level := Audio.rms(tail)
	_expect(tail_level > 0.004,
		"the note is still ringing after it stops (tail rms %.4f)" % tail_level)

	# and it has to die away rather than run forever
	var first := PackedFloat32Array()
	var last := PackedFloat32Array()
	var half := int(tail.size() / 2)
	for i in half:
		first.append(tail[i])
		last.append(tail[half + i])
	_expect(Audio.rms(last) < Audio.rms(first),
		"the echo dies away (%.4f -> %.4f)" % [Audio.rms(first), Audio.rms(last)])


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


## The song row: name drawn from x=125 in the menu, breath cost right-aligned at
## x=306, and an upgraded song gains a " +1" on the end. That leaves about 150px
## for the name itself.
const NAME_BUDGET := 150

func _check_names() -> void:
	var worst := 0
	var over: Array = []
	for elem in Data.SONGS:
		for song in Data.SONGS[elem]:
			var w := PixelFont.width(str(song.name) + " +1")
			worst = maxi(worst, w)
			if w > NAME_BUDGET:
				over.append("%s (%dpx)" % [song.name, w])
	print("  (widest song name is %dpx of %dpx)" % [worst, NAME_BUDGET])
	_expect(over.is_empty(), "every song name fits its row (%s)" % str(over))


## Each song is a named tune and should play that tune, not a generic flourish.
func _check_song_tunes() -> void:
	var missing: Array = []
	var bad: Array = []
	for elem in Data.SONGS:
		for song in Data.SONGS[elem]:
			var t := str(song.get("tune", ""))
			if t == "":
				missing.append(song.name)
				continue
			var notes := Tunes.seq(t)
			if notes.size() < 4:
				bad.append("%s (%d notes)" % [song.name, notes.size()])
			for ev in notes:
				if Audio.note_freq(str(ev[0])) <= 0.0:
					bad.append("%s has an unplayable note %s" % [song.name, ev[0]])
	_expect(missing.is_empty(), "all 64 songs have a tune (%s)" % str(missing))
	_expect(bad.is_empty(), "every tune is playable (%s)" % str(bad))


## Tracks must be the same length, or an exact divisor of the longest, or they
## walk out of phase with each other and never come back.
func _check_phase() -> void:
	var drifting: Array = []
	var ragged: Array = []
	for name in Audio.TUNES:
		var tune: Dictionary = Audio.TUNES[name]
		var longest := 0.0
		var lens: Array = []
		for tr in tune.tracks:
			var b := Tunes.beats_of(tr.seq)
			lens.append("%s=%g" % [tr.voice, b])
			longest = maxf(longest, b)
		for tr in tune.tracks:
			var b := Tunes.beats_of(tr.seq)
			if b <= 0.0 or fmod(longest, b) > 0.001:
				drifting.append("%s: %s" % [name, ", ".join(PackedStringArray(lens))])
				break
		# and the whole thing has to be a whole number of bars
		if fmod(longest, Tunes.BEATS_PER_BAR) > 0.001:
			ragged.append("%s (%g beats)" % [name, longest])
	_expect(drifting.is_empty(), "every tune's tracks stay in phase (%s)" % str(drifting))
	_expect(ragged.is_empty(), "every tune is a whole number of bars (%s)" % str(ragged))


## A tune that is a bar and a half of melody looping under eight bars of chords
## is not a tune. Print the shape of each so a wrong one is visible.
func _report_shape() -> void:
	print("  tune             tempo  bars  tracks")
	for name in Audio.TUNES:
		var tune: Dictionary = Audio.TUNES[name]
		var voices: Array = []
		for tr in tune.tracks:
			voices.append(str(tr.voice))
		print("  %-16s %-6d %-5d %s" % [name, int(tune.tempo),
			int(tune.get("bars", 0)), ", ".join(PackedStringArray(voices))])


func _check_tunes() -> void:
	var expect: int = Tunes.all().size()
	_expect(Audio.TUNES.size() == expect,
		"all %d traditional tunes loaded (got %d)" % [expect, Audio.TUNES.size()])
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
	for name in Tunes.all().keys():
		var secs := 12.0
		var mix := Audio.render_tune(name, secs)
		var level := Audio.rms(mix)
		var path := Audio.save_wav(mix, OUT_DIR + name + ".wav")
		_expect(level > 0.02, "%s mixed down (rms %.3f)" % [name, level])
		print("       -> %s" % path)
