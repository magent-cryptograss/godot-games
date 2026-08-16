class_name Tunes
extends RefCounted
## The soundtrack: traditional tunes, played as instrumentals.
##
## Every tune here is traditional and long out of copyright -- fiddle tunes,
## old-time breakdowns, shape-note hymns and ballads, the oldest from the 1700s
## and none later than the 1800s. They are set as instrumentals, with no words,
## which is how most of them are played anyway.
##
## These are arrangements written by ear, not transcriptions. The key, the mode
## and the shape of each phrase are the tune; a fiddler will hear places where a
## turn is straightened out to fit the bar.
##
## STRUCTURE, which is the thing that went wrong the first time. Every track in
## a tune loops on its own cursor, so tracks of different lengths line up for one
## pass and then drift apart for good -- melody over the wrong chords, for ever.
## Eleven of the first seventeen tunes did exactly that. So a tune is now written
## as a melody in whole bars plus one chord progression in whole bars, and every
## other part is generated from that progression. Lengths cannot disagree,
## because there is only one length. build() refuses anything that does not add
## up, and tests/TestAudio.tscn checks the built result as well.

const BEATS_PER_BAR := 4.0


## "G3:1 A3:.5" -> [[note, beats], ...]
static func seq(s: String) -> Array:
	var out := []
	for tok in s.split(" ", false):
		var parts := tok.split(":")
		out.append([parts[0], float(parts[1]) if parts.size() > 1 else 0.5])
	return out


static func beats_of(events: Array) -> float:
	var t := 0.0
	for e in events:
		t += float(e[1])
	return t


const TRIAD := {"maj": [0, 4, 7], "min": [0, 3, 7], "sus": [0, 5, 7], "5": [0, 7, 12]}
const SEMI := {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
const NAMES := ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]


static func midi(n: String) -> int:
	var semi: int = SEMI[n.substr(0, 1)]
	var i := 1
	if n.length() > 1 and (n[1] == "#" or n[1] == "b"):
		semi += 1 if n[1] == "#" else -1
		i = 2
	return (int(n.substr(i)) + 1) * 12 + semi


static func name_of(m: int) -> String:
	return "%s%d" % [NAMES[m % 12], int(m / 12) - 1]


# ------------------------------------------------------- generated backing --
#
# All four of these take the same progression, so all four come out the same
# length. prog is [[root, quality, bars], ...].

## Root and fifth, alternating -- the bass part of every string band there has
## ever been. Root on the first beat of the bar, fifth on the third.
static func bassline(prog: Array, oct: int = -12) -> Array:
	var out := []
	for c in prog:
		var root: int = midi(str(c[0])) + oct
		var fifth: int = root + 7
		for b in int(float(c[2])):
			out.append([name_of(root), 1.0])
			out.append([name_of(root + 12), 1.0])
			out.append([name_of(fifth), 1.0])
			out.append([name_of(root + 12), 1.0])
	return out


## The chop: a short chord on the offbeats, two and four. It is what a mandolin
## does for a living and it is most of why old-time music drives the way it does
## without a drummer anywhere near it.
static func chop(prog: Array) -> Array:
	var out := []
	for c in prog:
		var root: int = midi(str(c[0]))
		for b in int(float(c[2])):
			out.append(["0", 1.0])
			out.append([name_of(root), 1.0])
			out.append(["0", 1.0])
			out.append([name_of(root), 1.0])
	return out


## A rolling arpeggio, one chord tone at a time. This is the part that makes a
## tune sound like it is coming out of a games console rather than off a porch.
static func arp(prog: Array, div: float = 0.5, shape: Array = [0, 1, 2, 1]) -> Array:
	var out := []
	var k := 0
	for c in prog:
		var root: int = midi(str(c[0]))
		var iv: Array = TRIAD[str(c[1])]
		var n := int(round(float(c[2]) * BEATS_PER_BAR / div))
		for i in n:
			out.append([name_of(root + int(iv[int(shape[k % shape.size()])])), div])
			k += 1
	return out


## A held pad, one chord per bar.
static func pad(prog: Array, oct: int = 0) -> Array:
	var out := []
	for c in prog:
		out.append([name_of(midi(str(c[0])) + oct), float(c[2]) * BEATS_PER_BAR])
	return out


## Kit, one bar at a time, so it is always exactly as long as everything else.
## The pitch picks the drum: C1 kick, C3 snare, C6 hat.
const KICK := "C1"
const SNARE := "C3"
const HAT := "C6"

static func drums(bars: int, style: String = "reel") -> Array:
	var bar := ""
	match style:
		"reel":
			bar = "%s:.5 %s:.5 %s:.5 %s:.5 %s:.5 %s:.5 %s:.25 %s:.25 %s:.5" % [
				KICK, HAT, SNARE, HAT, KICK, HAT, SNARE, SNARE, HAT]
		"march":
			bar = "%s:1 %s:1 %s:.5 %s:.5 %s:1" % [KICK, SNARE, KICK, KICK, SNARE]
		"slow":
			bar = "%s:2 %s:2" % [KICK, SNARE]
	var out := []
	for b in bars:
		out.append_array(seq(bar))
	return out


# ----------------------------------------------------------------- builder --

## Assemble a tune and refuse to assemble a broken one.
##
## melody is an array of one-bar strings -- one bar each, so a miscounted bar is
## visible on the line it is on rather than buried in a wall of notes. Every bar
## must come to four beats and there must be as many bars as the progression has.
static func build(id: String, tempo: int, melody: Array, prog: Array, opts: Dictionary = {}) -> Dictionary:
	var mel := []
	for i in melody.size():
		var bar := seq(str(melody[i]))
		var b := beats_of(bar)
		if absf(b - BEATS_PER_BAR) > 0.001:
			push_error("%s: bar %d is %.2f beats, not %.1f" % [id, i + 1, b, BEATS_PER_BAR])
		mel.append_array(bar)

	var prog_bars := 0.0
	for c in prog:
		prog_bars += float(c[2])
	if absf(prog_bars - float(melody.size())) > 0.001:
		push_error("%s: %d bars of melody but %.1f bars of chords" % [
			id, melody.size(), prog_bars])

	var bars := melody.size()
	var tracks: Array = [{
		"voice": str(opts.get("lead", "lead")), "vol": float(opts.get("lead_vol", -12.0)),
		"bright": float(opts.get("bright", 9.0)), "seq": mel,
	}]
	if opts.get("arp", true):
		tracks.append({"voice": str(opts.get("arp_voice", "harp")),
			"vol": float(opts.get("arp_vol", -19.0)),
			"seq": arp(prog, float(opts.get("arp_div", 0.5)))})
	if opts.get("pad", false):
		tracks.append({"voice": "strings", "vol": float(opts.get("pad_vol", -19.0)),
			"seq": pad(prog, int(opts.get("pad_oct", -12)))})
	if opts.get("chop", false):
		tracks.append({"voice": "chop", "vol": float(opts.get("chop_vol", -17.0)),
			"seq": chop(prog)})
	if opts.get("bass", true):
		tracks.append({"voice": "bass", "vol": float(opts.get("bass_vol", -13.0)),
			"seq": bassline(prog, int(opts.get("bass_oct", -12)))})
	if opts.has("drums"):
		tracks.append({"voice": "drum", "vol": float(opts.get("drum_vol", -16.0)),
			"seq": drums(bars, str(opts.drums))})

	var out := {"tempo": tempo, "tracks": tracks, "bars": bars}
	if opts.has("loop"):
		out["loop"] = opts.loop
	return out


# ------------------------------------------------------------------- tunes --

static func all() -> Dictionary:
	return {

	# --- Wayfaring Stranger (traditional, early 1800s) -----------------------
	# A minor. The title screen of a game about songs outliving the people who
	# carried them can hardly be anything else.
	"title": build("title", 68, [
		"A3:1 A3:1 C4:1 D4:1",
		"E4:2 E4:1 E4:1",
		"G4:1 E4:.5 D4:.5 C4:1 A3:1",
		"A3:3 A3:1",
		"A3:1 C4:1 D4:1 E4:1",
		"G4:2 A4:1 G4:1",
		"E4:1 D4:1 C4:1 A3:1",
		"A3:4",
	], [
		["A2", "min", 2], ["F2", "maj", 1], ["G2", "maj", 1],
		["A2", "min", 2], ["C3", "maj", 1], ["G2", "maj", 1],
	], {"lead_vol": -11.0, "bright": 7.0, "arp": false, "pad": true, "pad_vol": -18.0}),

	# --- Simple Gifts (Shaker tune, 1848) ------------------------------------
	"creation": build("creation", 100, [
		"G3:.5 G3:.5 A3:.5 B3:.5 C4:1 D4:1",
		"D4:.5 C4:.5 B3:.5 A3:.5 B3:1 G3:1",
		"G3:.5 A3:.5 B3:.5 C4:.5 D4:1 B3:1",
		"A3:.5 G3:.5 A3:.5 B3:.5 G3:2",
		"D4:1 D4:.5 E4:.5 D4:.5 C4:.5 B3:1",
		"C4:1 B3:.5 A3:.5 G3:1 A3:1",
		"G3:.5 A3:.5 B3:.5 C4:.5 D4:1 B3:1",
		"A3:.5 G3:.5 A3:.5 B3:.5 G3:2",
	], [
		["G3", "maj", 2], ["C4", "maj", 1], ["G3", "maj", 1],
		["D4", "maj", 1], ["C4", "maj", 1], ["G3", "maj", 2],
	], {"lead": "harp", "lead_vol": -13.0, "arp_voice": "flute", "arp_div": 1.0,
		"arp_vol": -20.0}),

	# --- Angelina Baker (Stephen Foster, 1850) -------------------------------
	# The home town. Bright, square, and everybody knows it.
	"town": build("town", 116, [
		"D4:.5 F#4:.5 A4:1 A4:.5 B4:.5 A4:.5 F#4:.5",
		"E4:1 D4:.5 E4:.5 F#4:1 D4:1",
		"D4:.5 F#4:.5 A4:1 A4:.5 B4:.5 A4:.5 F#4:.5",
		"E4:.5 F#4:.5 E4:.5 D4:.5 D4:2",
		"A4:.5 A4:.5 B4:1 A4:.5 F#4:.5 E4:.5 D4:.5",
		"E4:1 F#4:.5 G4:.5 A4:2",
		"D5:.5 A4:.5 F#4:.5 A4:.5 G4:.5 E4:.5 D4:.5 E4:.5",
		"F#4:.5 E4:.5 D4:.5 C#4:.5 D4:2",
	], [
		["D3", "maj", 2], ["A2", "maj", 1], ["D3", "maj", 1],
		["D3", "maj", 1], ["A2", "maj", 1], ["G3", "maj", 1], ["D3", "maj", 1],
	], {"arp_div": 0.25, "chop": true, "drums": "reel"}),

	# --- Arkansas Traveler (1847) --------------------------------------------
	"town_millbrook": build("town_millbrook", 124, [
		"D4:.5 D4:.5 D4:.5 E4:.5 F#4:.5 F#4:.5 F#4:.5 E4:.5",
		"D4:.5 D4:.5 C#4:.5 B3:.5 A3:1 A3:1",
		"D4:.5 D4:.5 D4:.5 E4:.5 F#4:.5 G4:.5 A4:.5 F#4:.5",
		"E4:.5 D4:.5 E4:.5 C#4:.5 D4:2",
		"A4:.5 A4:.5 A4:.5 B4:.5 A4:.5 F#4:.5 D4:.5 F#4:.5",
		"E4:.5 D4:.5 C#4:.5 B3:.5 A3:1 A3:1",
		"D4:.5 F#4:.5 A4:.5 F#4:.5 G4:.5 E4:.5 C#4:.5 E4:.5",
		"D4:.5 F#4:.5 E4:.5 C#4:.5 D4:2",
	], [
		["D3", "maj", 1], ["A2", "maj", 1], ["D3", "maj", 1], ["D3", "maj", 1],
		["D3", "maj", 1], ["A2", "maj", 1], ["D3", "maj", 1], ["A2", "maj", 1],
	], {"arp_div": 0.25, "chop": true, "drums": "reel"}),

	# --- Shady Grove (traditional, A dorian) ---------------------------------
	"town_longferry": build("town_longferry", 108, [
		"A4:.5 C5:.5 D5:1 E5:1 D5:.5 C5:.5",
		"A4:1 G4:.5 A4:.5 A4:2",
		"A4:.5 C5:.5 D5:1 E5:1 G5:.5 E5:.5",
		"D5:1 C5:.5 A4:.5 A4:2",
		"E5:1 D5:.5 C5:.5 A4:1 G4:1",
		"A4:.5 C5:.5 D5:.5 C5:.5 A4:2",
		"A4:.5 C5:.5 D5:1 E5:.5 D5:.5 C5:.5 A4:.5",
		"G4:1 A4:1 A4:2",
	], [
		["A3", "min", 2], ["G3", "maj", 1], ["A3", "min", 1],
		["A3", "min", 1], ["G3", "maj", 1], ["A3", "min", 2],
	], {"arp_div": 0.25, "chop": true, "chop_vol": -19.0}),

	# --- I'll Twine 'Mid the Ringlets (1860) ---------------------------------
	"town_highwater": build("town_highwater", 96, [
		"C4:.5 C4:.5 E4:1 G4:1 G4:.5 E4:.5",
		"C4:1 D4:.5 E4:.5 C4:2",
		"C4:.5 C4:.5 E4:1 G4:1 A4:.5 G4:.5",
		"E4:1 D4:.5 C4:.5 C4:2",
		"G4:1 A4:.5 G4:.5 E4:1 G4:1",
		"E4:.5 D4:.5 C4:.5 D4:.5 E4:2",
		"C4:.5 C4:.5 E4:1 G4:.5 E4:.5 D4:.5 C4:.5",
		"D4:1 C4:1 C4:2",
	], [
		["C3", "maj", 2], ["G2", "maj", 1], ["C3", "maj", 1],
		["C3", "maj", 1], ["F3", "maj", 1], ["G2", "maj", 1], ["C3", "maj", 1],
	], {"lead": "harp", "lead_vol": -12.0, "arp": false, "pad": true}),

	# --- Bonaparte's Retreat (traditional, modal) ----------------------------
	# A mining town under the crag. This one marches.
	"town_ashfall": build("town_ashfall", 84, [
		"A3:2 A3:1 C4:1",
		"D4:2 E4:2",
		"E4:1 D4:1 C4:1 A3:1",
		"A3:4",
		"A3:2 C4:1 D4:1",
		"E4:2 G4:2",
		"A4:2 G4:1 E4:1",
		"D4:2 C4:1 A3:1",
	], [
		["A2", "min", 2], ["G2", "maj", 1], ["A2", "min", 1],
		["A2", "min", 2], ["C3", "maj", 1], ["A2", "min", 1],
	], {"lead_vol": -11.0, "bright": 7.0, "arp": false, "pad": true,
		"drums": "march", "drum_vol": -17.0}),

	# --- Cold Frosty Morning (traditional, A dorian) -------------------------
	"town_lastchord": build("town_lastchord", 92, [
		"A4:1 A4:.5 G4:.5 E4:1 D4:1",
		"E4:.5 G4:.5 A4:1 A4:2",
		"A4:1 C5:.5 B4:.5 A4:1 G4:1",
		"E4:.5 D4:.5 E4:.5 G4:.5 A4:2",
		"E5:1 D5:.5 C5:.5 A4:1 G4:1",
		"E4:.5 G4:.5 A4:1 A4:2",
		"C5:1 A4:.5 G4:.5 E4:1 D4:1",
		"E4:.5 G4:.5 A4:1 A4:2",
	], [
		["A3", "min", 2], ["G3", "maj", 1], ["A3", "min", 1],
		["A3", "min", 2], ["G3", "maj", 1], ["A3", "min", 1],
	], {"bright": 7.0, "arp_voice": "flute", "arp_div": 1.0, "arp_vol": -20.0}),

	# --- Soldier's Joy (traditional, by the 1760s) ---------------------------
	# The oldest tune in the game and the one for walking a long way. Sixteen
	# bars: eight of the A part, eight of the B.
	"field": build("field", 118, [
		"D4:1 F#4:.5 D4:.5 C#4:.5 D4:.5 E4:.5 C#4:.5",
		"D4:1 F#4:.5 D4:.5 E4:1 D4:.5 C#4:.5",
		"D4:1 F#4:.5 D4:.5 C#4:.5 D4:.5 E4:.5 F#4:.5",
		"G4:.5 F#4:.5 G4:.5 E4:.5 D4:1 D4:.5 A3:.5",
		"D4:1 F#4:.5 D4:.5 C#4:.5 D4:.5 E4:.5 C#4:.5",
		"D4:1 F#4:.5 D4:.5 E4:1 D4:.5 C#4:.5",
		"D4:1 F#4:.5 D4:.5 C#4:.5 D4:.5 E4:.5 F#4:.5",
		"G4:.5 F#4:.5 G4:.5 E4:.5 D4:2",
		"G4:1 B4:.5 G4:.5 F#4:.5 G4:.5 A4:.5 F#4:.5",
		"G4:1 B4:.5 G4:.5 A4:1 G4:.5 A4:.5",
		"B4:.5 A4:.5 G4:.5 F#4:.5 E4:.5 D4:.5 C#4:.5 B3:.5",
		"A3:1 F#4:.5 A4:.5 B4:1 A4:.5 G4:.5",
		"G4:1 B4:.5 G4:.5 F#4:.5 G4:.5 A4:.5 F#4:.5",
		"G4:1 B4:.5 G4:.5 A4:1 G4:.5 A4:.5",
		"B4:.5 A4:.5 G4:.5 F#4:.5 E4:.5 D4:.5 C#4:.5 E4:.5",
		"D4:2 D4:2",
	], [
		["D3", "maj", 3], ["A2", "maj", 1], ["D3", "maj", 2], ["A2", "maj", 1], ["D3", "maj", 1],
		["G3", "maj", 2], ["D3", "maj", 1], ["A2", "maj", 1],
		["G3", "maj", 2], ["A2", "maj", 1], ["D3", "maj", 1],
	], {"bright": 10.0, "arp_div": 0.25, "chop": true, "drums": "reel"}),

	# --- June Apple (traditional, A mixolydian) ------------------------------
	"field_wood": build("field_wood", 112, [
		"A4:.5 B4:.5 C#5:.5 E5:.5 C#5:.5 B4:.5 A4:.5 F#4:.5",
		"E4:.5 F#4:.5 A4:.5 B4:.5 A4:1 A4:1",
		"A4:.5 B4:.5 C#5:.5 E5:.5 G5:.5 E5:.5 C#5:.5 B4:.5",
		"A4:.5 B4:.5 A4:.5 F#4:.5 E4:2",
		"E5:.5 C#5:.5 A4:.5 C#5:.5 B4:.5 A4:.5 F#4:.5 A4:.5",
		"G4:.5 A4:.5 B4:.5 A4:.5 G4:1 E4:1",
		"A4:.5 B4:.5 C#5:.5 B4:.5 A4:.5 G4:.5 E4:.5 D4:.5",
		"E4:.5 F#4:.5 A4:.5 B4:.5 A4:2",
	], [
		["A3", "maj", 1], ["G3", "maj", 1], ["A3", "maj", 2],
		["A3", "maj", 1], ["G3", "maj", 1], ["A3", "maj", 1], ["G3", "maj", 1],
	], {"arp_div": 0.25, "chop": true, "drums": "reel", "drum_vol": -17.0}),

	# --- The Red Haired Boy (traditional, A mixolydian) ----------------------
	"field_crag": build("field_crag", 104, [
		"E4:.5 A4:1 A4:.5 B4:.5 A4:.5 F#4:.5 A4:.5",
		"E4:.5 D4:.5 E4:.5 F#4:.5 G4:1 E4:1",
		"E4:.5 A4:1 A4:.5 B4:.5 C#5:.5 D5:.5 C#5:.5",
		"B4:.5 A4:.5 F#4:.5 E4:.5 A4:2",
		"A4:.5 C#5:1 C#5:.5 D5:.5 C#5:.5 B4:.5 A4:.5",
		"B4:.5 A4:.5 F#4:.5 E4:.5 G4:1 E4:1",
		"E4:.5 A4:.5 C#5:.5 E5:.5 D5:.5 C#5:.5 B4:.5 A4:.5",
		"B4:.5 A4:.5 G4:.5 E4:.5 A4:2",
	], [
		["A3", "maj", 1], ["G3", "maj", 1], ["A3", "maj", 1], ["A3", "maj", 1],
		["D4", "maj", 1], ["G3", "maj", 1], ["A3", "maj", 1], ["A3", "maj", 1],
	], {"bright": 10.0, "lead_vol": -11.0, "arp": false, "pad": true,
		"chop": true, "drums": "reel", "drum_vol": -17.0}),

	# --- Cluck Old Hen (traditional, A modal) --------------------------------
	# It is a comic tune above ground and a menacing one down here, which is
	# entirely down to how slowly you play it.
	"cave": build("cave", 76, [
		"A4:1 A4:.5 G4:.5 E4:1 D4:1",
		"E4:.5 D4:.5 C4:.5 D4:.5 E4:2",
		"A4:1 C5:.5 A4:.5 G4:1 E4:1",
		"D4:.5 E4:.5 G4:.5 E4:.5 D4:2",
		"0:2 A3:1 C4:1",
		"D4:2 E4:2",
		"G4:1 E4:.5 D4:.5 C4:1 A3:1",
		"A3:2 0:2",
	], [
		["A2", "min", 2], ["G2", "maj", 1], ["A2", "min", 1],
		["A2", "min", 2], ["G2", "maj", 1], ["A2", "min", 1],
	], {"lead": "harp", "lead_vol": -13.0, "arp": false, "pad": true,
		"pad_vol": -21.0, "bass_vol": -15.0}),

	# --- Pretty Polly (traditional ballad, modal) ----------------------------
	# Phrases that never quite resolve, which is the oldest trick there is for
	# making somebody uneasy.
	"deep": build("deep", 68, [
		"A3:2 C4:1 D4:1",
		"E4:3 D4:1",
		"C4:2 A3:2",
		"A3:4",
		"E4:2 G4:1 E4:1",
		"D4:2 C4:2",
		"A3:2 G3:2",
		"A3:4",
	], [
		["A2", "min", 2], ["F2", "maj", 1], ["A2", "min", 1],
		["A2", "min", 2], ["G2", "maj", 1], ["A2", "min", 1],
	], {"lead": "strings", "lead_vol": -13.0, "arp_voice": "flute", "arp_div": 2.0,
		"arp_vol": -22.0, "bass_vol": -14.0}),

	# --- Cripple Creek (traditional) -----------------------------------------
	"battle": build("battle", 150, [
		"A4:.5 A4:.5 C#5:.5 A4:.5 B4:.5 A4:.5 F#4:.5 E4:.5",
		"D4:.5 E4:.5 F#4:.5 A4:.5 B4:1 A4:1",
		"A4:.5 A4:.5 C#5:.5 A4:.5 B4:.5 C#5:.5 D5:.5 B4:.5",
		"A4:.5 F#4:.5 E4:.5 F#4:.5 A4:2",
		"E5:.5 C#5:.5 A4:.5 C#5:.5 E5:.5 C#5:.5 A4:.5 F#4:.5",
		"E4:.5 F#4:.5 A4:.5 B4:.5 A4:1 A4:1",
		"E5:.5 C#5:.5 A4:.5 C#5:.5 B4:.5 A4:.5 F#4:.5 E4:.5",
		"D4:.5 E4:.5 F#4:.5 A4:.5 A4:2",
	], [
		["A3", "maj", 1], ["D4", "maj", 1], ["A3", "maj", 1], ["E3", "maj", 1],
		["A3", "maj", 1], ["D4", "maj", 1], ["A3", "maj", 1], ["E3", "maj", 1],
	], {"lead_vol": -11.0, "bright": 12.0, "arp_div": 0.25, "chop": true,
		"chop_vol": -16.0, "bass_vol": -12.0, "drums": "reel", "drum_vol": -15.0}),

	# --- The Devil's Dream (traditional) -------------------------------------
	# All arpeggio and no rest.
	"boss": build("boss", 158, [
		"A4:.25 C#5:.25 E5:.25 A5:.25 E5:.25 C#5:.25 A4:.25 E4:.25 A4:.25 C#5:.25 E5:.25 A5:.25 E5:.25 C#5:.25 A4:.25 C#5:.25",
		"B4:.25 D5:.25 F#5:.25 B5:.25 F#5:.25 D5:.25 B4:.25 F#4:.25 B4:.25 D5:.25 F#5:.25 B5:.25 F#5:.25 D5:.25 B4:.25 D5:.25",
		"E4:.25 G#4:.25 B4:.25 E5:.25 B4:.25 G#4:.25 E4:.25 B3:.25 E4:.25 G#4:.25 B4:.25 E5:.25 G#5:.25 B5:.25 G#5:.25 E5:.25",
		"A5:.25 E5:.25 C#5:.25 A4:.25 E4:.25 C#4:.25 A3:.25 C#4:.25 E4:.5 A4:.5 C#5:.5 A4:.5",
		"A4:.25 C#5:.25 E5:.25 A5:.25 E5:.25 C#5:.25 A4:.25 E4:.25 A4:.25 C#5:.25 E5:.25 A5:.25 E5:.25 C#5:.25 A4:.25 C#5:.25",
		"D5:.25 F#5:.25 A5:.25 D6:.25 A5:.25 F#5:.25 D5:.25 A4:.25 D5:.25 F#5:.25 A5:.25 F#5:.25 D5:.25 A4:.25 F#4:.25 D4:.25",
		"E4:.25 G#4:.25 B4:.25 E5:.25 B4:.25 G#4:.25 E4:.25 B3:.25 E5:.25 D5:.25 C#5:.25 B4:.25 A4:.25 B4:.25 C#5:.25 D5:.25",
		"E5:.5 C#5:.5 A4:1 A4:2",
	], [
		["A3", "maj", 1], ["B3", "min", 1], ["E3", "maj", 1], ["A3", "maj", 1],
		["A3", "maj", 1], ["D4", "maj", 1], ["E3", "maj", 1], ["A3", "maj", 1],
	], {"lead_vol": -11.0, "bright": 13.0, "arp": false, "pad": true, "pad_vol": -18.0,
		"chop": true, "chop_vol": -15.0, "bass_vol": -11.0, "drums": "reel",
		"drum_vol": -14.0}),

	# --- a cadence out of Soldier's Joy --------------------------------------
	"victory": build("victory", 140, [
		"D4:.5 F#4:.5 A4:.5 D5:.5 C#5:.5 D5:1.5",
		"0:4",
		"0:4",
	], [
		["D3", "maj", 1], ["D3", "maj", 1], ["D3", "maj", 1],
	], {"lead_vol": -9.0, "bright": 11.0, "arp_div": 0.25, "arp_vol": -15.0,
		"bass_vol": -12.0, "loop": false}),

	# --- Shenandoah (traditional, early 1800s) -------------------------------
	# A tune about a river and about not seeing somebody again, sung by people a
	# long way from where they started, which is the whole game.
	"ending": build("ending", 72, [
		"D4:1 F#4:1 A4:2",
		"A4:1 B4:.5 A4:.5 F#4:1 D4:1",
		"E4:4",
		"0:2 D4:1 F#4:1",
		"A4:2 D5:1 C#5:.5 B4:.5",
		"A4:1 F#4:1 D4:2",
		"E4:1 D4:3",
		"0:4",
		"A4:1 B4:1 D5:2",
		"D5:1 C#5:.5 B4:.5 A4:1 F#4:1",
		"E4:4",
		"0:2 D4:1 F#4:1",
		"A4:2 B4:1 A4:.5 F#4:.5",
		"E4:1 D4:1 D4:2",
		"D4:4",
		"0:4",
	], [
		["D3", "maj", 1], ["A2", "maj", 1], ["D3", "maj", 1], ["D3", "maj", 1],
		["G3", "maj", 1], ["D3", "maj", 1], ["A2", "maj", 1], ["D3", "maj", 1],
		["D3", "maj", 1], ["A2", "maj", 1], ["D3", "maj", 1], ["D3", "maj", 1],
		["G3", "maj", 1], ["A2", "maj", 1], ["D3", "maj", 2],
	], {"lead": "flute", "lead_vol": -11.0, "arp": false, "pad": true,
		"pad_vol": -18.0, "bass_vol": -14.0}),
	}
