class_name Tunes
extends RefCounted
## The soundtrack: traditional tunes, played as instrumentals.
##
## Every tune here is traditional and long out of copyright -- fiddle tunes,
## old-time breakdowns, shape-note hymns and ballads, the oldest of them from the
## 1700s and none of them later than the 1800s. They are set as instrumentals,
## with no words, which is how most of them are played anyway.
##
## These are arrangements written out by ear, not transcriptions. The key, the
## mode and the shape of each phrase are the tune; a fiddler will hear places
## where a turn is simplified to fit four bars of game music.
##
## It suits the story better than anything invented would. The premise is that a
## song passed hand to hand is the only memory that lasts, and these are the
## actual songs that did it -- two hundred years of hands, no author left on any
## of them, still here.

# ------------------------------------------------------------------ helpers --

## "G3:1 A3:.5" -> [[note, beats], ...]
static func seq(s: String) -> Array:
	var out := []
	for tok in s.split(" ", false):
		var parts := tok.split(":")
		out.append([parts[0], float(parts[1]) if parts.size() > 1 else 0.5])
	return out


## Repeat a phrase, which is what a bass line or a drum pattern mostly is.
static func rep(s: String, n: int) -> String:
	var out := ""
	for i in n:
		out += s + " "
	return out


const TRIAD := {
	"maj": [0, 4, 7], "min": [0, 3, 7], "sus": [0, 5, 7], "5": [0, 7, 12],
}
const SEMI := {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
const NAMES := ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]


static func _midi(n: String) -> int:
	var semi: int = SEMI[n.substr(0, 1)]
	var i := 1
	if n.length() > 1 and (n[1] == "#" or n[1] == "b"):
		semi += 1 if n[1] == "#" else -1
		i = 2
	return (int(n.substr(i)) + 1) * 12 + semi


static func _name(m: int) -> String:
	return "%s%d" % [NAMES[m % 12], int(m / 12) - 1]


## Break a chord progression into a rolling arpeggio. This is most of what makes
## a tune sound like it is coming out of a Super Nintendo rather than off a
## porch: a busy inner voice under the melody, playing the chord one note at a
## time instead of strumming it.
##
## prog is [[root, quality, beats], ...]; div is the note length.
static func arp(prog: Array, div: float = 0.5, shape: Array = [0, 1, 2, 1]) -> Array:
	var out := []
	for c in prog:
		var root: int = _midi(str(c[0]))
		var iv: Array = TRIAD[str(c[1])]
		var beats: float = float(c[2])
		var n := int(round(beats / div))
		for i in n:
			out.append([_name(root + int(iv[int(shape[i % shape.size()])])), div])
	return out


## A backbeat. Old-time music has no drum kit in it -- the rhythm lives in the
## bow arm and in whoever is chopping on the offbeat -- but a Super Nintendo has
## a kit on everything, and that is the sound being asked for.
##
## The pitch picks the drum: C1 is the kick, C3 the snare, C6 the hat. One track
## can then carry the whole kit, since a track has only one voice.
const KICK := "C1"
const SNARE := "C3"
const HAT := "C6"

static func drums(bars: int, style: String = "reel") -> Array:
	var out := []
	var bar := ""
	match style:
		"reel":
			bar = "%s:.5 %s:.5 %s:.5 %s:.5 %s:.5 %s:.5 %s:.25 %s:.25 %s:.5" % [
				KICK, HAT, SNARE, HAT, KICK, HAT, SNARE, SNARE, HAT]
		"march":
			bar = "%s:1 %s:1 %s:.5 %s:.5 %s:1" % [KICK, SNARE, KICK, KICK, SNARE]
		"waltz":
			bar = "%s:1 %s:1 %s:1" % [KICK, HAT, HAT]
		"slow":
			bar = "%s:2 %s:2" % [KICK, SNARE]
	for b in bars:
		out.append_array(seq(bar))
	return out


# ------------------------------------------------------------------- tunes --
#
# Each entry: tempo, and tracks of {voice, vol, seq}. Voices are defined in
# Audio.gd. "lead" carries the tune, "harp"/"strings" fill, "bass" walks,
# "kick"/"snare" keep time.

static func all() -> Dictionary:
	return {

	# --- Wayfaring Stranger (traditional spiritual, early 1800s) --------------
	# A minor, slow, unaccompanied-sounding. The title screen of a game about
	# songs outliving the people who carried them can hardly be anything else.
	"title": {"tempo": 66, "tracks": [
		{"voice": "lead", "vol": -11.0, "bright": 7.0, "seq": seq(
			"A3:1 C4:1 D4:1 E4:2 E4:1 " +
			"G4:1 E4:.5 D4:.5 C4:1 A3:2 0:1 " +
			"A3:1 C4:1 D4:1 E4:2 G4:1 " +
			"A4:1.5 G4:.5 E4:1 D4:1 C4:1 A3:3 0:1")},
		{"voice": "strings", "vol": -19.0, "seq": seq(
			"A2:4 A2:4 F2:4 G2:4 A2:4 A2:4 F2:2 G2:2 A2:4")},
		{"voice": "bass", "vol": -15.0, "seq": seq(
			"A1:2 E2:2 A1:2 E2:2 F1:2 C2:2 G1:2 D2:2 " +
			"A1:2 E2:2 A1:2 E2:2 F1:2 G1:2 A1:4")},
	]},

	# --- Simple Gifts (Shaker tune, 1848) ------------------------------------
	# Plain and cheerful. Played while you are drawing your own face.
	"creation": {"tempo": 100, "tracks": [
		{"voice": "harp", "vol": -13.0, "seq": seq(
			"G3:.5 G3:.5 A3:.5 B3:.5 C4:1 D4:1 " +
			"D4:.5 C4:.5 B3:.5 A3:.5 B3:1 G3:1 " +
			"G3:.5 A3:.5 B3:.5 C4:.5 D4:1 B3:1 " +
			"A3:.5 G3:.5 A3:.5 B3:.5 G3:2 " +
			"D4:1 D4:.5 E4:.5 D4:.5 C4:.5 B3:1 " +
			"C4:1 B3:.5 A3:.5 G3:1 A3:1 " +
			"G3:.5 A3:.5 B3:.5 C4:.5 D4:1 B3:1 " +
			"A3:.5 G3:.5 A3:.5 B3:.5 G3:2")},
		{"voice": "flute", "vol": -18.0, "seq": arp([
			["G3", "maj", 4], ["G3", "maj", 4], ["C4", "maj", 2], ["D4", "maj", 2],
			["G3", "maj", 4], ["D3", "maj", 4], ["G3", "maj", 4], ["G3", "maj", 4]])},
		{"voice": "bass", "vol": -14.0, "seq": seq(
			rep("G2:1 D3:1 G2:1 D3:1", 2) + rep("C3:1 G2:1 D3:1 D3:1", 1) + "G2:2 G2:2")},
	]},

	# --- Angelina Baker (Stephen Foster, 1850) -------------------------------
	# The home town. Bright, square, and everybody knows it.
	"town": {"tempo": 116, "tracks": [
		{"voice": "lead", "vol": -12.0, "bright": 9.0, "seq": seq(
			"D4:.5 F#4:.5 A4:1 A4:.5 B4:.5 A4:.5 F#4:.5 " +
			"E4:1 D4:.5 E4:.5 F#4:1 D4:1 " +
			"D4:.5 F#4:.5 A4:1 A4:.5 B4:.5 A4:.5 F#4:.5 " +
			"E4:.5 F#4:.5 E4:.5 D4:.5 D4:2 " +
			"A4:.5 A4:.5 B4:1 A4:.5 F#4:.5 E4:.5 D4:.5 " +
			"E4:1 F#4:.5 G4:.5 A4:2 " +
			"D5:.5 A4:.5 F#4:.5 A4:.5 G4:.5 E4:.5 D4:.5 E4:.5 " +
			"F#4:.5 E4:.5 D4:.5 C#4:.5 D4:2")},
		{"voice": "harp", "vol": -18.0, "seq": arp([
			["D3", "maj", 4], ["A2", "maj", 4], ["D3", "maj", 4], ["D3", "maj", 4],
			["D3", "maj", 4], ["A2", "maj", 4], ["G3", "maj", 2], ["A2", "maj", 2],
			["D3", "maj", 4]], 0.25)},
		{"voice": "bass", "vol": -13.0, "seq": seq(rep("D2:1 A2:1 D2:1 F#2:1", 4) +
			rep("G2:1 D3:1 A2:1 A2:1", 2) + "D2:2 D2:2")},
		{"voice": "kick", "vol": -16.0, "seq": drums(8, "reel")},
	]},

	# --- Arkansas Traveler (1847) --------------------------------------------
	"town_millbrook": {"tempo": 124, "tracks": [
		{"voice": "lead", "vol": -12.0, "bright": 10.0, "seq": seq(
			"D4:.5 D4:.5 D4:.5 E4:.5 F#4:.5 F#4:.5 F#4:.5 E4:.5 " +
			"D4:.5 D4:.5 C#4:.5 B3:.5 A3:1 A3:1 " +
			"D4:.5 D4:.5 D4:.5 E4:.5 F#4:.5 G4:.5 A4:.5 F#4:.5 " +
			"E4:.5 D4:.5 E4:.5 C#4:.5 D4:2 " +
			"A4:.5 A4:.5 A4:.5 B4:.5 A4:.5 F#4:.5 D4:.5 F#4:.5 " +
			"E4:.5 D4:.5 C#4:.5 B3:.5 A3:1 A3:1 " +
			"D4:.5 F#4:.5 A4:.5 F#4:.5 G4:.5 E4:.5 C#4:.5 E4:.5 " +
			"D4:.5 F#4:.5 E4:.5 C#4:.5 D4:2")},
		{"voice": "harp", "vol": -19.0, "seq": arp([
			["D3", "maj", 4], ["A2", "maj", 4], ["D3", "maj", 4], ["D3", "maj", 4],
			["D3", "maj", 4], ["A2", "maj", 4], ["D3", "maj", 2], ["A2", "maj", 2],
			["D3", "maj", 4]], 0.25)},
		{"voice": "bass", "vol": -13.0, "seq": seq(rep("D2:1 A2:1 D2:1 A2:1", 6) +
			"G2:1 A2:1 D2:2")},
		{"voice": "kick", "vol": -16.0, "seq": drums(8, "reel")},
	]},

	# --- Shady Grove (traditional, A dorian) ---------------------------------
	# A river town. Modal and a little sideways, which is the whole charm of it.
	"town_longferry": {"tempo": 108, "tracks": [
		{"voice": "lead", "vol": -12.0, "bright": 8.0, "seq": seq(
			"A4:.5 C5:.5 D5:1 E5:1 D5:.5 C5:.5 " +
			"A4:1 G4:.5 A4:.5 A4:2 " +
			"A4:.5 C5:.5 D5:1 E5:1 G5:.5 E5:.5 " +
			"D5:1 C5:.5 A4:.5 A4:2 " +
			"E5:1 D5:.5 C5:.5 A4:1 G4:1 " +
			"A4:.5 C5:.5 D5:.5 C5:.5 A4:2 " +
			"A4:.5 C5:.5 D5:1 E5:.5 D5:.5 C5:.5 A4:.5 " +
			"G4:1 A4:1 A4:2")},
		{"voice": "harp", "vol": -19.0, "seq": arp([
			["A2", "min", 4], ["G2", "maj", 4], ["A2", "min", 4], ["A2", "min", 4],
			["A2", "min", 4], ["G2", "maj", 4], ["A2", "min", 4], ["A2", "min", 4]], 0.25)},
		{"voice": "bass", "vol": -13.0, "seq": seq(rep("A1:1 E2:1 A1:1 E2:1", 2) +
			rep("G1:1 D2:1 G1:1 D2:1", 1) + rep("A1:1 E2:1 A1:1 A1:1", 1) +
			rep("A1:1 E2:1 A1:1 E2:1", 4))},
	]},

	# --- I'll Twine 'Mid the Ringlets (1860) ---------------------------------
	# Better known now by the name the Carters gave it. Highwater is the town
	# that half emptied out, and this is a tune for standing in an attic.
	"town_highwater": {"tempo": 96, "tracks": [
		{"voice": "harp", "vol": -12.0, "seq": seq(
			"C4:.5 C4:.5 E4:1 G4:1 G4:.5 E4:.5 " +
			"C4:1 D4:.5 E4:.5 C4:2 " +
			"C4:.5 C4:.5 E4:1 G4:1 A4:.5 G4:.5 " +
			"E4:1 D4:.5 C4:.5 C4:2 " +
			"G4:1 A4:.5 G4:.5 E4:1 G4:1 " +
			"E4:.5 D4:.5 C4:.5 D4:.5 E4:2 " +
			"C4:.5 C4:.5 E4:1 G4:.5 E4:.5 D4:.5 C4:.5 " +
			"D4:1 C4:1 C4:2")},
		{"voice": "strings", "vol": -19.0, "seq": seq(
			"C3:4 C3:4 G2:4 C3:4 C3:4 F2:4 G2:4 C3:4")},
		{"voice": "bass", "vol": -14.0, "seq": seq(rep("C2:1 G2:1 C2:1 G2:1", 3) +
			rep("F2:1 C3:1 G2:1 G2:1", 1) + rep("C2:1 G2:1 C2:1 C2:1", 4))},
	]},

	# --- Bonaparte's Retreat (traditional, modal) ----------------------------
	# Ashfall is a mining town under the crag. This one marches.
	"town_ashfall": {"tempo": 84, "tracks": [
		{"voice": "lead", "vol": -11.0, "bright": 7.0, "seq": seq(
			"A3:2 A3:1 C4:1 D4:2 E4:2 " +
			"E4:1 D4:1 C4:1 A3:1 A3:4 " +
			"A3:2 C4:1 D4:1 E4:2 G4:2 " +
			"A4:2 G4:1 E4:1 D4:2 C4:2 " +
			"D4:2 C4:1 A3:1 A3:4")},
		{"voice": "strings", "vol": -18.0, "seq": seq(
			"A2:4 A2:4 G2:4 A2:4 A2:4 C3:4 G2:4 A2:4 A2:4")},
		{"voice": "bass", "vol": -13.0, "seq": seq(rep("A1:2 A1:1 E2:1", 4) +
			rep("G1:2 D2:2", 2) + rep("A1:2 E2:2", 4))},
		{"voice": "kick", "vol": -17.0, "seq": drums(10, "march")},
	]},

	# --- Cold Frosty Morning (traditional, A dorian) -------------------------
	# The last town before the cave. Nine people and a lot of weather.
	"town_lastchord": {"tempo": 92, "tracks": [
		{"voice": "lead", "vol": -12.0, "bright": 7.0, "seq": seq(
			"A4:1 A4:.5 G4:.5 E4:1 D4:1 " +
			"E4:.5 G4:.5 A4:1 A4:2 " +
			"A4:1 C5:.5 B4:.5 A4:1 G4:1 " +
			"E4:.5 D4:.5 E4:.5 G4:.5 A4:2 " +
			"E5:1 D5:.5 C5:.5 A4:1 G4:1 " +
			"E4:.5 G4:.5 A4:1 A4:2 " +
			"C5:1 A4:.5 G4:.5 E4:1 D4:1 " +
			"E4:.5 G4:.5 A4:1 A4:2")},
		{"voice": "flute", "vol": -19.0, "seq": arp([
			["A3", "min", 4], ["G3", "maj", 4], ["A3", "min", 4], ["A3", "min", 4],
			["A3", "min", 4], ["G3", "maj", 4], ["A3", "min", 4], ["A3", "min", 4]], 0.5)},
		{"voice": "bass", "vol": -14.0, "seq": seq(rep("A1:2 E2:2", 4) +
			rep("G1:2 D2:2", 2) + rep("A1:2 E2:2", 6))},
	]},

	# --- Soldier's Joy (traditional, by the 1760s) ---------------------------
	# The oldest tune in the game and the one for walking a long way. If a fiddle
	# tune can be said to be everywhere, it is this one.
	"field": {"tempo": 118, "tracks": [
		{"voice": "lead", "vol": -12.0, "bright": 10.0, "seq": seq(
			"D4:1 F#4:.5 D4:.5 C#4:.5 D4:.5 E4:.5 C#4:.5 " +
			"D4:1 F#4:.5 D4:.5 E4:1 D4:.5 C#4:.5 " +
			"D4:1 F#4:.5 D4:.5 C#4:.5 D4:.5 E4:.5 F#4:.5 " +
			"G4:.5 F#4:.5 G4:.5 E4:.5 D4:1 D4:.5 A3:.5 " +
			"D4:1 F#4:.5 D4:.5 C#4:.5 D4:.5 E4:.5 C#4:.5 " +
			"D4:1 F#4:.5 D4:.5 E4:1 D4:.5 C#4:.5 " +
			"D4:1 F#4:.5 D4:.5 C#4:.5 D4:.5 E4:.5 F#4:.5 " +
			"G4:.5 F#4:.5 G4:.5 E4:.5 D4:2 " +
			"G4:1 B4:.5 G4:.5 F#4:.5 G4:.5 A4:.5 F#4:.5 " +
			"G4:1 B4:.5 G4:.5 A4:1 G4:.5 A4:.5 " +
			"B4:.5 A4:.5 G4:.5 F#4:.5 E4:.5 D4:.5 C#4:.5 B3:.5 " +
			"A3:1 F#4:.5 A3:.5 B3:1 A3:.5 G3:.5 " +
			"G4:1 B4:.5 G4:.5 F#4:.5 G4:.5 A4:.5 F#4:.5 " +
			"G4:1 B4:.5 G4:.5 A4:1 G4:.5 A4:.5 " +
			"B4:.5 A4:.5 G4:.5 F#4:.5 E4:.5 D4:.5 C#4:.5 E4:.5 " +
			"D4:2 D4:2")},
		{"voice": "harp", "vol": -19.0, "seq": arp([
			["D3", "maj", 8], ["A2", "maj", 4], ["D3", "maj", 4],
			["D3", "maj", 8], ["A2", "maj", 4], ["D3", "maj", 4],
			["G3", "maj", 8], ["D3", "maj", 4], ["A2", "maj", 4],
			["G3", "maj", 8], ["A2", "maj", 4], ["D3", "maj", 4]], 0.25)},
		{"voice": "bass", "vol": -13.0, "seq": seq(rep("D2:1 A2:1 D2:1 F#2:1", 4) +
			rep("D2:1 A2:1 D2:1 A2:1", 2) + rep("G2:1 D3:1 G2:1 B2:1", 2) +
			rep("A2:1 E3:1 D2:1 A2:1", 2) + rep("G2:1 D3:1 A2:1 D2:1", 2))},
		{"voice": "kick", "vol": -16.0, "seq": drums(16, "reel")},
	]},

	# --- June Apple (traditional, A mixolydian) ------------------------------
	# The woods. The flat seventh in it is what makes it sound like shade.
	"field_wood": {"tempo": 112, "tracks": [
		{"voice": "lead", "vol": -12.0, "bright": 9.0, "seq": seq(
			"A4:.5 B4:.5 C#5:.5 E5:.5 C#5:.5 B4:.5 A4:.5 F#4:.5 " +
			"E4:.5 F#4:.5 A4:.5 B4:.5 A4:1 A4:1 " +
			"A4:.5 B4:.5 C#5:.5 E5:.5 G5:.5 E5:.5 C#5:.5 B4:.5 " +
			"A4:.5 B4:.5 A4:.5 F#4:.5 E4:2 " +
			"E5:.5 C#5:.5 A4:.5 C#5:.5 B4:.5 A4:.5 F#4:.5 A4:.5 " +
			"G4:.5 A4:.5 B4:.5 A4:.5 G4:1 E4:1 " +
			"A4:.5 B4:.5 C#5:.5 B4:.5 A4:.5 G4:.5 E4:.5 D4:.5 " +
			"E4:.5 F#4:.5 A4:.5 B4:.5 A4:2")},
		{"voice": "harp", "vol": -19.0, "seq": arp([
			["A3", "maj", 4], ["G3", "maj", 4], ["A3", "maj", 4], ["A3", "maj", 4],
			["A3", "maj", 4], ["G3", "maj", 4], ["A3", "maj", 4], ["A3", "maj", 4]], 0.25)},
		{"voice": "bass", "vol": -13.0, "seq": seq(rep("A2:1 E3:1 A2:1 E3:1", 2) +
			rep("G2:1 D3:1 G2:1 D3:1", 1) + rep("A2:1 E3:1 A2:1 A2:1", 1) +
			rep("A2:1 E3:1 A2:1 E3:1", 2) + rep("G2:1 D3:1 A2:1 A2:1", 2))},
		{"voice": "kick", "vol": -17.0, "seq": drums(8, "reel")},
	]},

	# --- The Red Haired Boy (traditional, A mixolydian) ----------------------
	# High country. A big striding tune, older than any of the towns in it.
	"field_crag": {"tempo": 104, "tracks": [
		{"voice": "lead", "vol": -11.0, "bright": 10.0, "seq": seq(
			"E4:.5 A4:1 A4:.5 B4:.5 A4:.5 F#4:.5 A4:.5 " +
			"E4:.5 D4:.5 E4:.5 F#4:.5 G4:1 E4:1 " +
			"E4:.5 A4:1 A4:.5 B4:.5 C#5:.5 D5:.5 C#5:.5 " +
			"B4:.5 A4:.5 F#4:.5 E4:.5 A4:2 " +
			"A4:.5 C#5:1 C#5:.5 D5:.5 C#5:.5 B4:.5 A4:.5 " +
			"B4:.5 A4:.5 F#4:.5 E4:.5 G4:1 E4:1 " +
			"E4:.5 A4:.5 C#5:.5 E5:.5 D5:.5 C#5:.5 B4:.5 A4:.5 " +
			"B4:.5 A4:.5 G4:.5 E4:.5 A4:2")},
		{"voice": "strings", "vol": -19.0, "seq": seq(
			"A2:4 A2:4 G2:4 A2:4 A2:4 G2:4 D3:2 E3:2 A2:4")},
		{"voice": "bass", "vol": -13.0, "seq": seq(rep("A2:1 E3:1 A2:1 C#3:1", 2) +
			rep("G2:1 D3:1 G2:1 B2:1", 1) + rep("A2:1 E3:1 A2:1 A2:1", 1) +
			rep("A2:1 E3:1 A2:1 C#3:1", 2) + rep("D3:1 A2:1 E3:1 A2:1", 2))},
		{"voice": "kick", "vol": -17.0, "seq": drums(8, "reel")},
	]},

	# --- Cluck Old Hen (traditional, A modal) --------------------------------
	# Underground. It is a comic tune above ground and a menacing one down here,
	# which is entirely down to how slowly you play it.
	"cave": {"tempo": 76, "tracks": [
		{"voice": "harp", "vol": -13.0, "seq": seq(
			"A4:1 A4:.5 G4:.5 E4:1 D4:1 " +
			"E4:.5 D4:.5 C4:.5 D4:.5 E4:2 " +
			"A4:1 C5:.5 A4:.5 G4:1 E4:1 " +
			"D4:.5 E4:.5 G4:.5 E4:.5 D4:2 " +
			"0:2 A3:1 C4:1 D4:2 E4:2 " +
			"G4:1 E4:.5 D4:.5 C4:1 A3:1 A3:2 0:2")},
		{"voice": "strings", "vol": -20.0, "seq": seq(
			"A2:8 G2:4 A2:4 A2:8 F2:4 G2:4 A2:8")},
		{"voice": "bass", "vol": -15.0, "seq": seq(
			rep("A1:2 A1:2 G1:2 G1:2", 2) + rep("A1:2 E2:2 A1:2 A1:2", 2))},
	]},

	# --- Pretty Polly (traditional ballad, modal) ----------------------------
	# The deep dark. Three-line phrases that never quite resolve, which is the
	# oldest trick there is for making somebody uneasy.
	"deep": {"tempo": 68, "tracks": [
		{"voice": "strings", "vol": -13.0, "seq": seq(
			"A3:2 C4:1 D4:1 E4:3 D4:1 " +
			"C4:2 A3:2 A3:4 " +
			"E4:2 G4:1 E4:1 D4:2 C4:2 " +
			"A3:2 G3:2 A3:4 " +
			"A3:1 C4:1 E4:2 G4:2 E4:2 " +
			"D4:2 C4:2 A3:4")},
		{"voice": "flute", "vol": -20.0, "seq": seq(
			"0:8 A4:2 G4:2 E4:4 0:8 D5:2 C5:2 A4:4")},
		{"voice": "bass", "vol": -14.0, "seq": seq(rep("A1:4 A1:4", 2) +
			rep("F1:4 G1:4", 1) + rep("A1:4 E2:4", 1) + rep("A1:4 A1:4", 2))},
	]},

	# --- Cripple Creek (traditional) -----------------------------------------
	"battle": {"tempo": 152, "tracks": [
		{"voice": "lead", "vol": -11.0, "bright": 12.0, "seq": seq(
			"A4:.5 A4:.5 C#5:.5 A4:.5 B4:.5 A4:.5 F#4:.5 E4:.5 " +
			"D4:.5 E4:.5 F#4:.5 A4:.5 B4:1 A4:1 " +
			"A4:.5 A4:.5 C#5:.5 A4:.5 B4:.5 C#5:.5 D5:.5 B4:.5 " +
			"A4:.5 F#4:.5 E4:.5 F#4:.5 A4:2 " +
			"E5:.5 C#5:.5 A4:.5 C#5:.5 E5:.5 C#5:.5 A4:.5 F#4:.5 " +
			"E4:.5 F#4:.5 A4:.5 B4:.5 A4:1 A4:1 " +
			"E5:.5 C#5:.5 A4:.5 C#5:.5 B4:.5 A4:.5 F#4:.5 E4:.5 " +
			"D4:.5 E4:.5 F#4:.5 A4:.5 A4:2")},
		{"voice": "harp", "vol": -18.0, "seq": arp([
			["A3", "maj", 4], ["E3", "maj", 4], ["A3", "maj", 4], ["A3", "maj", 4],
			["A3", "maj", 4], ["E3", "maj", 4], ["A3", "maj", 4], ["A3", "maj", 4]], 0.25)},
		{"voice": "bass", "vol": -12.0, "seq": seq(rep("A2:.5 A2:.5 E3:.5 E3:.5", 8) +
			rep("D3:.5 D3:.5 A2:.5 A2:.5", 4) + rep("E3:.5 E3:.5 A2:.5 A2:.5", 4))},
		{"voice": "kick", "vol": -14.0, "seq": drums(16, "reel")},
	]},

	# --- The Devil's Dream (traditional) -------------------------------------
	# All arpeggio and no rest. It has been the tune for a fiddle contest with
	# something unpleasant at stake for about two hundred years.
	"boss": {"tempo": 160, "tracks": [
		{"voice": "lead", "vol": -11.0, "bright": 13.0, "seq": seq(
			"A4:.25 C#5:.25 E5:.25 A5:.25 E5:.25 C#5:.25 A4:.25 E4:.25 " +
			"A4:.25 C#5:.25 E5:.25 A5:.25 E5:.25 C#5:.25 A4:.25 C#5:.25 " +
			"B4:.25 D5:.25 F#5:.25 B5:.25 F#5:.25 D5:.25 B4:.25 F#4:.25 " +
			"E4:.25 G#4:.25 B4:.25 E5:.25 B4:.25 G#4:.25 E4:.25 B3:.25 " +
			"A4:.25 C#5:.25 E5:.25 A5:.25 E5:.25 C#5:.25 A4:.25 E4:.25 " +
			"A4:.25 C#5:.25 E5:.25 A5:.25 E5:.25 C#5:.25 A4:.25 C#5:.25 " +
			"D5:.25 B4:.25 G#4:.25 B4:.25 E5:.25 C#5:.25 A4:.25 C#5:.25 " +
			"B4:.5 A4:.5 A4:1")},
		{"voice": "strings", "vol": -17.0, "seq": seq(
			"A3:2 A3:2 B3:2 E3:2 A3:2 A3:2 E3:2 A3:2")},
		{"voice": "bass", "vol": -11.0, "seq": seq(rep("A1:.5 A1:.5 A2:.5 A1:.5", 4) +
			rep("B1:.5 B1:.5 B2:.5 B1:.5", 2) + rep("E2:.5 E2:.5 E1:.5 E2:.5", 2) +
			rep("A1:.5 A1:.5 A2:.5 A1:.5", 4) + rep("E2:.5 E2:.5 A1:.5 A1:.5", 4))},
		{"voice": "kick", "vol": -13.0, "seq": drums(16, "reel")},
	]},

	# --- a cadence out of Soldier's Joy --------------------------------------
	"victory": {"tempo": 140, "loop": false, "tracks": [
		{"voice": "lead", "vol": -9.0, "bright": 11.0, "seq": seq(
			"D4:.5 F#4:.5 A4:.5 D5:1 C#5:.5 D5:1.5 0:8")},
		{"voice": "harp", "vol": -14.0, "seq": seq(
			"D4:.25 F#4:.25 A4:.25 D5:.25 A4:.25 F#4:.25 A4:1.5 0:8")},
		{"voice": "bass", "vol": -12.0, "seq": seq("D2:1 A2:1 D2:2 0:8")},
	]},

	# --- Shenandoah (traditional, early 1800s) -------------------------------
	# For the end. A tune about a river and about not seeing somebody again, sung
	# by people a long way from where they started, which is the whole game.
	"ending": {"tempo": 72, "tracks": [
		{"voice": "flute", "vol": -11.0, "seq": seq(
			"D4:1 F#4:1 A4:2 A4:1 B4:.5 A4:.5 F#4:1 D4:1 " +
			"E4:4 0:2 " +
			"D4:1 F#4:1 A4:2 D5:1 C#5:.5 B4:.5 A4:1 F#4:1 " +
			"D4:2 E4:1 D4:3 0:2 " +
			"A4:1 B4:1 D5:2 D5:1 C#5:.5 B4:.5 A4:1 F#4:1 " +
			"E4:4 0:2 " +
			"D4:1 F#4:1 A4:2 B4:1 A4:.5 F#4:.5 E4:1 D4:1 " +
			"D4:4 0:4")},
		{"voice": "strings", "vol": -17.0, "seq": seq(
			"D3:6 A2:6 D3:6 G2:3 D3:3 D3:6 A2:6 D3:6 D3:6 G2:4 D3:8")},
		{"voice": "bass", "vol": -14.0, "seq": seq(
			"D2:3 A2:3 D2:3 A2:3 D2:3 A2:3 G2:3 D2:3 " +
			"D2:3 A2:3 D2:3 A2:3 G2:3 D2:3 A2:3 D2:3")},
	]},
	}
