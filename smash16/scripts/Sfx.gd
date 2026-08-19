extends Node

# ---------------------------------------------------------------------------
# SOUND
#
# Every sound is synthesised into a raw 16-bit buffer when the game boots.
# No .wav files, nothing to load, and the whole bank costs a few kilobytes.
# Square and noise waves are exactly what the SNES-era sound chips leaned on,
# so building them by hand is also the historically honest way to do it.
# ---------------------------------------------------------------------------

const RATE := 22050

var _bank: Dictionary = {}
var _players: Array = []
var _next: int = 0
var enabled: bool = true


func _ready() -> void:
	for i in range(14):
		var p := AudioStreamPlayer.new()
		p.volume_db = -6.0
		add_child(p)
		_players.append(p)
	_build_bank()


func _build_bank() -> void:
	_bank["jump"]    = _wave(0.085, 420.0, 760.0, "square", 0.32, 1.6)
	_bank["land"]    = _wave(0.055, 180.0, 90.0,  "noise",  0.22, 2.4)
	_bank["hit"]     = _mix(_wave(0.10, 240.0, 90.0, "square", 0.34, 2.0),
							_wave(0.10, 800.0, 200.0, "noise", 0.28, 2.6))
	_bank["bighit"]  = _mix(_wave(0.20, 170.0, 55.0, "square", 0.42, 1.4),
							_wave(0.20, 700.0, 120.0, "noise", 0.34, 1.8))
	_bank["shield"]  = _wave(0.07, 520.0, 400.0, "sine",   0.24, 2.0)
	_bank["break"]   = _mix(_wave(0.40, 900.0, 90.0, "saw", 0.38, 1.1),
							_wave(0.40, 400.0, 60.0, "noise", 0.24, 1.5))
	_bank["dodge"]   = _wave(0.06, 900.0, 1400.0, "noise", 0.16, 2.6)
	_bank["shot"]    = _wave(0.065, 980.0, 520.0, "square", 0.26, 2.0)
	_bank["bounce"]  = _wave(0.05, 620.0, 940.0, "square", 0.22, 2.2)
	_bank["special"] = _wave(0.14, 300.0, 980.0, "square", 0.30, 1.4)
	_bank["charged"] = _wave(0.10, 700.0, 1300.0, "tri",   0.28, 1.6)
	_bank["ko"]      = _mix(_wave(0.55, 760.0, 70.0, "saw", 0.40, 1.0),
							_wave(0.55, 300.0, 50.0, "square", 0.26, 1.2))
	_bank["select"]  = _wave(0.05, 700.0, 980.0, "square", 0.24, 2.0)
	_bank["confirm"] = _wave(0.16, 520.0, 1180.0, "square", 0.30, 1.4)
	_bank["back"]    = _wave(0.09, 600.0, 320.0, "square", 0.24, 1.8)
	_bank["count"]   = _wave(0.10, 880.0, 880.0, "square", 0.28, 2.2)
	_bank["go"]      = _wave(0.28, 660.0, 1320.0, "square", 0.34, 1.2)


# Build one tone: a pitch slide from f0 to f1 with an exponential decay.
func _wave(dur: float, f0: float, f1: float, kind: String,
		vol: float, decay: float) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in range(n):
		var t := float(i) / float(n)
		var freq := lerpf(f0, f1, t)
		phase += freq / float(RATE)
		var q := fposmod(phase, 1.0)
		var s := 0.0
		match kind:
			"square": s = 1.0 if q < 0.5 else -1.0
			"saw":    s = q * 2.0 - 1.0
			"tri":    s = (4.0 * q - 1.0) if q < 0.5 else (3.0 - 4.0 * q)
			"noise":  s = randf() * 2.0 - 1.0
			_:        s = sin(phase * TAU)
		var env := pow(maxf(0.0, 1.0 - t), decay)
		var v := int(clampf(s * env * vol, -1.0, 1.0) * 32000.0)
		data.encode_s16(i * 2, v)
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = RATE
	st.stereo = false
	st.data = data
	return st


# Layering a tone under a noise burst is what makes a hit sound like impact
# rather than a beep.
func _mix(a: AudioStreamWAV, b: AudioStreamWAV) -> AudioStreamWAV:
	var da := a.data
	var db := b.data
	var n := mini(da.size(), db.size()) / 2
	var out := PackedByteArray()
	out.resize(n * 2)
	for i in range(n):
		var va := da.decode_s16(i * 2)
		var vb := db.decode_s16(i * 2)
		out.encode_s16(i * 2, clampi(va + vb, -32000, 32000))
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = RATE
	st.stereo = false
	st.data = out
	return st


func play(name: String, pitch: float = 1.0, vol_db: float = -6.0) -> void:
	if not enabled or not _bank.has(name):
		return
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _bank[name]
	p.pitch_scale = clampf(pitch, 0.3, 3.0)
	p.volume_db = vol_db
	p.play()
