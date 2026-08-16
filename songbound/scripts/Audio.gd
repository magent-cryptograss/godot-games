extends Node
## Sound. Everything is synthesised at runtime -- no audio files anywhere.
##
## Godot has no WebAudio, so instead of a node graph this renders each note into
## a short PCM buffer and plays it. Buffers are cached by voice/pitch/length,
## which matters because a tune reuses the same handful of notes constantly.

const MIX_RATE := 22050
const POOL := 24

## The echo. 115ms at a bit under half feedback is the sound of most of the
## Super Nintendo's back catalogue; the tail is how long the note is allowed to
## ring on after it stops being played.
const ECHO_S := 0.115
const ECHO_FB := 0.40
const ECHO_TAIL := 0.62

var _cache := {}
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0

var _tune := {}
var _tune_name := ""
var _cursors: Array = []
var _clock := 0.0
var _music_on := true
var _sfx_on := true

var rng := RandomNumberGenerator.new()


func _ready() -> void:
	TUNES = Tunes.all()
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	set_process(true)


# ------------------------------------------------------------------ synth --

func _env(i: int, n: int, attack: float, decay_shape: float) -> float:
	var f := float(i) / float(n)
	var a := minf(1.0, f / maxf(0.0001, attack))
	return a * pow(1.0 - f, decay_shape)


## Render one note. Voices deliberately mirror the HTML build so the instrument
## you pick still changes the character of your songs.
func _render(voice: String, freq: float, dur: float, bright: float, echo: float = 0.0) -> AudioStreamWAV:
	var n := int(MIX_RATE * dur)
	var tail := int(MIX_RATE * ECHO_TAIL) if echo > 0.0 else 0
	var buf := PackedFloat32Array()
	buf.resize(n + tail)
	var phase := 0.0
	var phase2 := 0.0
	var phase3 := 0.0
	var step := freq / MIX_RATE
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var s := 0.0
		match voice:
			"pluck":
				# two detuned saws through a lowpass that closes as the note decays.
				# The cutoff has to be derived from the note's own frequency: a
				# fixed coefficient is a fixed cutoff in Hz, which turned every
				# pitch into the same muffled thud around 140 Hz.
				phase = fmod(phase + step, 1.0)
				phase2 = fmod(phase2 + step * 2.002, 1.0)
				var raw := (phase * 2.0 - 1.0) + (phase2 * 2.0 - 1.0) * 0.3
				var openness := 1.0 - 0.7 * (float(i) / n)
				var fc := clampf(freq * bright * openness, 80.0, MIX_RATE * 0.45)
				var cut := 1.0 - exp(-TAU * fc / MIX_RATE)
				lp += (raw - lp) * cut
				s = lp * _env(i, n, 0.004, 2.4)
			"bow":
				var vib := 1.0 + sin(TAU * 5.5 * float(i) / MIX_RATE) * 0.011
				phase = fmod(phase + step * vib, 1.0)
				s = (phase * 2.0 - 1.0) * _env(i, n, 0.12, 0.9)
			"reed":
				phase = fmod(phase + step, 1.0)
				var sq := 1.0 if phase < 0.5 else -1.0
				s = (sq * 0.7 + (rng.randf() * 2.0 - 1.0) * 0.12) * _env(i, n, 0.05, 1.1)
			"bell":
				var e := _env(i, n, 0.002, 3.0)
				for k in 4:
					var mult: float = [1.0, 2.01, 3.02, 4.7][k]
					s += sin(TAU * freq * mult * float(i) / MIX_RATE) / (k + 1.4)
				s *= e * 0.6
			"bass":
				phase = fmod(phase + step, 1.0)
				var tri := absf(phase * 4.0 - 2.0) - 1.0
				# same lesson: cutoff tracks the note, a few harmonics above it
				var bfc := clampf(freq * 5.0, 100.0, MIX_RATE * 0.45)
				lp += (tri - lp) * (1.0 - exp(-TAU * bfc / MIX_RATE))
				s = lp * _env(i, n, 0.01, 1.6)
			"noise":
				s = (rng.randf() * 2.0 - 1.0) * _env(i, n, 0.001, 3.0)

			"lead":
				# The tune. A sampled-sounding lead: saw and square blended, run
				# through a lowpass that tracks the note, with the vibrato held
				# back until the note has had time to speak. Vibrato from the
				# first sample is the giveaway of a synthesiser; a player puts it
				# on afterwards.
				var f2: float = float(i) / float(n)
				var vb := 1.0 + sin(TAU * 5.2 * float(i) / MIX_RATE) * 0.006 * smoothstep(0.18, 0.55, f2)
				phase = fmod(phase + step * vb, 1.0)
				phase2 = fmod(phase2 + step * vb * 1.004, 1.0)
				var mix := (phase * 2.0 - 1.0) * 0.55 + (1.0 if phase2 < 0.42 else -1.0) * 0.3
				var lfc := clampf(freq * bright * (1.0 - 0.35 * f2), 200.0, MIX_RATE * 0.45)
				lp += (mix - lp) * (1.0 - exp(-TAU * lfc / MIX_RATE))
				s = lp * _env(i, n, 0.03, 0.55)

			"harp":
				# The inner voice, running arpeggios under the tune. Short,
				# round, and quiet enough to sit underneath.
				phase = fmod(phase + step, 1.0)
				var tri2 := absf(phase * 4.0 - 2.0) - 1.0
				var hfc := clampf(freq * 6.0 * (1.0 - 0.5 * float(i) / n), 150.0, MIX_RATE * 0.45)
				lp += (tri2 - lp) * (1.0 - exp(-TAU * hfc / MIX_RATE))
				s = lp * _env(i, n, 0.006, 2.2)

			"strings":
				# Three saws pulled slightly apart. The beating between them is
				# the whole effect -- one saw is a buzz, three is an ensemble.
				phase = fmod(phase + step * 0.997, 1.0)
				phase2 = fmod(phase2 + step, 1.0)
				phase3 = fmod(phase3 + step * 1.003, 1.0)
				var ens := ((phase + phase2 + phase3) * 2.0 / 3.0 - 1.0)
				var sfc := clampf(freq * 4.5, 200.0, MIX_RATE * 0.45)
				lp += (ens - lp) * (1.0 - exp(-TAU * sfc / MIX_RATE))
				s = lp * _env(i, n, 0.28, 0.35) * 0.9

			"flute":
				var f3: float = float(i) / float(n)
				var fv := 1.0 + sin(TAU * 4.8 * float(i) / MIX_RATE) * 0.007 * smoothstep(0.2, 0.6, f3)
				phase = fmod(phase + step * fv, 1.0)
				var body := sin(TAU * phase) + sin(TAU * phase * 2.0) * 0.12
				# breath, filtered so it is air and not hiss
				lp2 += ((rng.randf() * 2.0 - 1.0) - lp2) * 0.22
				s = (body * 0.8 + lp2 * 0.10) * _env(i, n, 0.14, 0.45)

			"drum":
				# One voice, three drums, chosen by the pitch it is asked for --
				# so a single track can carry a whole kit.
				var t3: float = float(i) / MIX_RATE
				if freq < 80.0:
					var swp := 118.0 * exp(-t3 * 26.0) + 41.0
					phase = fmod(phase + swp / MIX_RATE, 1.0)
					s = sin(TAU * phase) * exp(-t3 * 15.0) * 1.1
				elif freq < 400.0:
					phase = fmod(phase + 186.0 / MIX_RATE, 1.0)
					s = (sin(TAU * phase) * 0.35 + (rng.randf() * 2.0 - 1.0) * 0.75) * exp(-t3 * 24.0)
				else:
					var hn := rng.randf() * 2.0 - 1.0
					lp2 += (hn - lp2) * 0.6
					s = (hn - lp2) * exp(-t3 * 90.0) * 0.5

			_:
				phase = fmod(phase + step, 1.0)
				s = (1.0 if phase < 0.5 else -1.0) * _env(i, n, 0.01, 2.0)
		buf[i] = s

	if echo > 0.0:
		_echo(buf, echo)

	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		var v := int(clampf(buf[i], -1.0, 1.0) * 26000.0)
		data[i * 2] = v & 0xFF
		data[i * 2 + 1] = (v >> 8) & 0xFF

	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = MIX_RATE
	w.stereo = false
	w.data = data
	return w


## A feedback delay, darkening as it repeats. The darkening matters: a bright
## echo sounds like a fault, a dark one sounds like a room.
func _echo(buf: PackedFloat32Array, amount: float) -> void:
	var d := int(ECHO_S * MIX_RATE)
	if d < 1 or d >= buf.size():
		return
	var damp := 0.0
	for i in range(d, buf.size()):
		damp += (buf[i - d] - damp) * 0.45
		buf[i] += damp * ECHO_FB * amount


func _stream(voice: String, freq: float, dur: float, bright: float, echo: float) -> AudioStreamWAV:
	var key := "%s:%d:%d:%d:%d" % [voice, int(freq), int(dur * 100), int(bright), int(echo * 10)]
	if not _cache.has(key):
		_cache[key] = _render(voice, freq, dur, bright, echo)
	return _cache[key]


func _play(voice: String, freq: float, dur: float, vol_db: float, bright: float = 8.0,
		echo: float = 0.0) -> void:
	var p := _players[_next_player]
	_next_player = (_next_player + 1) % POOL
	p.stream = _stream(voice, freq, dur, bright, echo)
	p.volume_db = vol_db
	p.play()


# ------------------------------------------------------------------ notes --

const NOTE_BASE := {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}

func note_freq(n: String) -> float:
	if n == "" or n == "0":
		return 0.0
	var letter := n.substr(0, 1)
	if not NOTE_BASE.has(letter):
		return 0.0
	var semi: int = NOTE_BASE[letter]
	var idx := 1
	if n.length() > 1 and (n[1] == "#" or n[1] == "b"):
		semi += 1 if n[1] == "#" else -1
		idx = 2
	var oct := int(n.substr(idx))
	return 440.0 * pow(2.0, ((oct + 1) * 12 + semi - 69) / 12.0)


## "G3:1 A3:.5 0:.5" -> [[note, beats], ...]
static func seq(s: String) -> Array:
	var out := []
	for tok in s.split(" ", false):
		var parts := tok.split(":")
		var beats := float(parts[1]) if parts.size() > 1 else 0.5
		out.append([parts[0], beats])
	return out


# ------------------------------------------------------------------ tunes --

## The soundtrack lives in Tunes.gd: traditional fiddle tunes, breakdowns,
## hymns and ballads, all of them old enough to have no author left on them.
var TUNES := {}


## How wet each voice sits in the echo. The tune and its inner voices want to be
## in a big room; the kick drum wants to be in the front of it, or the low end
## turns to mud.
const VOICE_ECHO := {
	"lead": 0.95, "flute": 1.0, "strings": 0.9, "harp": 0.8, "bell": 0.9,
	"bow": 0.8, "pluck": 0.7, "reed": 0.7, "bass": 0.3, "drum": 0.25,
}


# ------------------------------------------------------------------ music --

func play_music(name: String) -> void:
	if not _music_on or name == _tune_name:
		return
	if not TUNES.has(name):
		return
	_tune_name = name
	_tune = TUNES[name]
	_clock = 0.0
	_cursors.clear()
	for tr in _tune.tracks:
		_cursors.append({"i": 0, "next": 0.0})


func stop_music() -> void:
	_tune = {}
	_tune_name = ""


func current_music() -> String:
	return _tune_name


func _process(dt: float) -> void:
	if _tune.is_empty():
		return
	_clock += dt
	var spb := 60.0 / float(_tune.tempo)
	for k in _tune.tracks.size():
		var tr: Dictionary = _tune.tracks[k]
		var c: Dictionary = _cursors[k]
		var guard := 0
		while c.next <= _clock and guard < 32:
			guard += 1
			if c.i >= tr.seq.size():
				if not _tune.get("loop", true):
					break
				c.i = 0
			var ev: Array = tr.seq[c.i]
			var beats: float = ev[1]
			var dur := beats * spb
			var f := note_freq(str(ev[0]))
			if f > 0.0:
				_play(tr.voice, f, minf(dur * 0.95, 2.0), tr.vol, tr.get("bright", 8.0),
					VOICE_ECHO.get(str(tr.voice), 0.6))
			c.next += dur
			c.i += 1


# -------------------------------------------------------------------- sfx --

func sfx(name: String) -> void:
	if not _sfx_on:
		return
	match name:
		"cursor": _play("square", 1050, 0.04, -20.0)
		"confirm": _play("pluck", 660, 0.22, -12.0, 9.0)
		"cancel": _play("square", 340, 0.09, -18.0)
		"hit": _play("noise", 400, 0.13, -12.0)
		"crit": _play("noise", 600, 0.24, -9.0)
		"miss": _play("noise", 3000, 0.13, -20.0)
		"heal": _play("bell", 784, 0.5, -13.0, 8.0, 0.8)
		"buff": _play("bell", 880, 0.35, -14.0, 8.0, 0.8)
		"debuff": _play("bow", 260, 0.3, -14.0)
		"levelup": _play("bell", 1046, 0.8, -10.0, 8.0, 0.9)
		"chest": _play("bell", 880, 0.45, -12.0, 8.0, 0.7)
		"door": _play("noise", 300, 0.2, -18.0)
		"step": _play("noise", 500, 0.04, -28.0)
		"encounter": _play("square", 220, 0.2, -13.0)
		"down": _play("bow", 150, 0.6, -11.0)
		"flee": _play("square", 700, 0.2, -16.0)
		"error": _play("square", 150, 0.15, -16.0)
		"draw": _play("square", 1400, 0.02, -30.0)


## The head of the song being played, in the player's own instrument.
##
## Every song used to make the same flourish -- five notes up the element's
## scale, identical across all eight of an element's songs. Each one is a named
## traditional tune now and gets its own phrase, so the eight songs of an
## element are eight different tunes rather than one sound played eight times.
func play_song(elem: String, inst: Dictionary, tune: String = "") -> void:
	if not _sfx_on:
		return
	var voice: String = inst.get("voice", "pluck")
	if voice == "drum" or voice == "noise":
		voice = "pluck"
	var bright: float = inst.get("bright", 8.0)

	if tune != "":
		var at := 0.0
		for ev in Tunes.seq(tune):
			var f := note_freq(str(ev[0]))
			var beats: float = float(ev[1])
			if f > 0.0:
				# staggered with timers: the battle has no sequencer of its own
				get_tree().create_timer(at).timeout.connect(
					func() -> void: _play(voice, f, maxf(beats * 1.6, 0.28), -12.0, bright, 0.85))
			at += beats
		return

	# nothing written down for this one: fall back to the old flourish
	var scale: Array = {
		"fire": [392, 466, 587, 698], "water": [349, 440, 523, 659],
		"plant": [330, 415, 494, 622], "ice": [523, 622, 784, 932],
		"electric": [440, 554, 659, 880], "earth": [196, 233, 294, 349],
		"wind": [587, 698, 880, 1047], "dark": [262, 311, 392, 466],
	}.get(elem, [440, 554, 659, 880])
	for i in 5:
		var f2: float = scale[i % scale.size()] * (2.0 if i >= scale.size() else 1.0)
		get_tree().create_timer(i * 0.075).timeout.connect(
			func() -> void: _play(voice, f2, 0.4, -13.0, bright, 0.7))


## ----------------------------------------------------------------------------
## Offline rendering. This machine has no audio device, so the only way to know
## what the synth actually sounds like is to mix a tune down to a file and
## listen to it somewhere else.
## ----------------------------------------------------------------------------

## Decode a rendered note back to float samples so it can be mixed.
func _samples_of(w: AudioStreamWAV) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var n := int(w.data.size() / 2)
	out.resize(n)
	for i in n:
		var lo := w.data[i * 2]
		var hi := w.data[i * 2 + 1]
		var v := lo | (hi << 8)
		if v >= 32768:
			v -= 65536
		out[i] = float(v) / 32768.0
	return out


func render_tune(name: String, seconds: float) -> PackedFloat32Array:
	var mix := PackedFloat32Array()
	var total := int(MIX_RATE * seconds)
	mix.resize(total)
	mix.fill(0.0)
	if not TUNES.has(name):
		return mix
	var tune: Dictionary = TUNES[name]
	var spb := 60.0 / float(tune.tempo)
	for tr in tune.tracks:
		var at := 0.0
		var i := 0
		var guard := 0
		while at < seconds and guard < 4000:
			guard += 1
			if i >= tr.seq.size():
				if not tune.get("loop", true):
					break
				i = 0
			var ev: Array = tr.seq[i]
			var dur: float = ev[1] * spb
			var f := note_freq(str(ev[0]))
			if f > 0.0:
				var w := _stream(tr.voice, f, minf(dur * 0.95, 2.0), tr.get("bright", 8.0),
					VOICE_ECHO.get(str(tr.voice), 0.6))
				var s := _samples_of(w)
				var off := int(at * MIX_RATE)
				# tracks are written at their own level, then summed
				var gain: float = db_to_linear(tr.vol) * 3.0
				for k in s.size():
					var idx := off + k
					if idx >= total:
						break
					mix[idx] += s[k] * gain
			at += dur
			i += 1
	# soft-clip rather than letting sums wrap round
	for i in total:
		mix[i] = clampf(mix[i], -1.0, 1.0)
	return mix


func save_wav(samples: PackedFloat32Array, path: String) -> String:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		var v := int(clampf(samples[i], -1.0, 1.0) * 32000.0)
		if v < 0:
			v += 65536
		data[i * 2] = v & 0xFF
		data[i * 2 + 1] = (v >> 8) & 0xFF
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = MIX_RATE
	w.stereo = false
	w.data = data
	var abs_path := ProjectSettings.globalize_path(path)
	w.save_to_wav(abs_path)
	return abs_path


## Pitch by autocorrelation, measured over the steady middle of the note.
##
## Counting zero crossings was the obvious approach and it was wrong: a voice
## built from two detuned saws an octave apart has far more crossings than its
## fundamental, so the estimate ran high and the test blamed the synth.
func estimate_pitch(samples: PackedFloat32Array) -> float:
	var a := int(samples.size() * 0.15)
	var b := int(samples.size() * 0.6)
	if b - a < 512:
		return 0.0
	var win := samples.slice(a, b)
	var n := win.size()
	var min_lag := int(MIX_RATE / 1500.0)
	var max_lag := mini(int(MIX_RATE / 60.0), int(n / 2))
	var best_lag := 0
	var best := -1.0
	for lag in range(min_lag, max_lag):
		var acc := 0.0
		var count := n - lag
		for i in count:
			acc += win[i] * win[i + lag]
		acc /= count
		if acc > best:
			best = acc
			best_lag = lag
	if best_lag <= 0:
		return 0.0
	return float(MIX_RATE) / float(best_lag)


func rms(samples: PackedFloat32Array) -> float:
	if samples.is_empty():
		return 0.0
	var acc := 0.0
	for s in samples:
		acc += s * s
	return sqrt(acc / samples.size())


func set_music_enabled(on: bool) -> void:
	_music_on = on
	if not on:
		stop_music()

func set_sfx_enabled(on: bool) -> void:
	_sfx_on = on
