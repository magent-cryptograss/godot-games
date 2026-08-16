extends Node
## Static game data and the progression maths.
##
## Ported from the original single-file HTML build. The numbers here were tuned
## against a headless balance probe, so they are deliberately identical -- see
## tests/test_balance.gd, which re-runs that probe against this table.

const MAX_LEVEL := 100

# ---------------------------------------------------------------- elements --

const ELEMENTS := [
	{"id": "fire",     "name": "Fire",     "col": "#ff7a30", "col2": "#a02808", "desc": "Burns. Keeps burning."},
	{"id": "water",    "name": "Water",    "col": "#40b8e8", "col2": "#1a5a90", "desc": "Mends, and carries away."},
	{"id": "plant",    "name": "Plant",    "col": "#6ac83a", "col2": "#2e7028", "desc": "Poisons, roots, and grows back."},
	{"id": "ice",      "name": "Ice",      "col": "#a8e0f8", "col2": "#4878a8", "desc": "Slows the whole world down."},
	{"id": "electric", "name": "Electric", "col": "#f0e050", "col2": "#a07818", "desc": "Sudden. Loud. Rude."},
	{"id": "earth",    "name": "Earth",    "col": "#c8a068", "col2": "#6a4a28", "desc": "Endures, then falls on you."},
	{"id": "wind",     "name": "Wind",     "col": "#a0f0d0", "col2": "#30a080", "desc": "Fast, and never only once."},
	{"id": "dark",     "name": "Dark",     "col": "#b088e0", "col2": "#503078", "desc": "Takes, and gives it to you."},
]

func element(id: String) -> Dictionary:
	for e in ELEMENTS:
		if e.id == id:
			return e
	return ELEMENTS[0]

func element_index(id: String) -> int:
	for i in ELEMENTS.size():
		if ELEMENTS[i].id == id:
			return i
	return 0

# ------------------------------------------------------------- instruments --
## The instrument biases the stat curve AND supplies the synth voice songs are
## played through, so the choice is audible as well as numeric.

const INSTRUMENTS := [
	{"id": "guitar", "name": "Guitar", "voice": "pluck", "bright": 8.0,
		"desc": "Steady and even. Good at everything, best at nothing.",
		"mods": {"hp": 0, "br": 0, "atk": 0, "def": 0, "mus": 0, "spd": 0}},
	{"id": "fiddle", "name": "Fiddle", "voice": "bow", "bright": 6.0,
		"desc": "Sings high and fast. Strong music, thin skin.",
		"mods": {"hp": -4, "br": 4, "atk": -1, "def": -2, "mus": 4, "spd": 3}},
	{"id": "banjo", "name": "Banjo", "voice": "pluck", "bright": 14.0,
		"desc": "All drive and attack. Rolls faster than sense allows.",
		"mods": {"hp": -2, "br": -2, "atk": 4, "def": -1, "mus": 1, "spd": 4}},
	{"id": "mandolin", "name": "Mandolin", "voice": "pluck", "bright": 12.0,
		"desc": "Quick and bright. Chops hard on the offbeat.",
		"mods": {"hp": -2, "br": 1, "atk": 2, "def": 0, "mus": 2, "spd": 5}},
	{"id": "bass", "name": "Upright Bass", "voice": "bass", "bright": 4.0,
		"desc": "Holds the bottom. Slow, and very hard to knock over.",
		"mods": {"hp": 8, "br": -1, "atk": 2, "def": 5, "mus": -1, "spd": -4}},
	{"id": "dulcimer", "name": "Dulcimer", "voice": "bell", "bright": 7.0,
		"desc": "Rings a long time. Deep well of breath, weak arm.",
		"mods": {"hp": -3, "br": 6, "atk": -3, "def": 1, "mus": 5, "spd": 0}},
	{"id": "harmonica", "name": "Harmonica", "voice": "reed", "bright": 5.0,
		"desc": "Fits in a pocket. Never runs out of wind for long.",
		"mods": {"hp": 1, "br": 5, "atk": -1, "def": 1, "mus": 2, "spd": 2}},
	{"id": "drum", "name": "Frame Drum", "voice": "drum", "bright": 3.0,
		"desc": "No melody at all, and it does not need one.",
		"mods": {"hp": 6, "br": -3, "atk": 5, "def": 3, "mus": -2, "spd": 1}},
]

func instrument(id: String) -> Dictionary:
	for i in INSTRUMENTS:
		if i.id == id:
			return i
	return INSTRUMENTS[0]

# ---------------------------------------------------------------- statuses --

const STATUS := {
	"burn":   {"name": "Burn",   "col": "#ff7a30", "dot": 0.07, "turns": 3},
	"poison": {"name": "Poison", "col": "#a0e060", "dot": 0.06, "turns": 4},
	"stun":   {"name": "Stun",   "col": "#f0e050", "skip": true, "turns": 1},
	"slow":   {"name": "Slow",   "col": "#a8e0f8", "mod": {"spd": -0.4}, "turns": 4},
	"weak":   {"name": "Weak",   "col": "#b088e0", "mod": {"atk": -0.3}, "turns": 4},
	"guard":  {"name": "Guard",  "col": "#c8a068", "mod": {"def": 0.5}, "turns": 4, "good": true},
	"haste":  {"name": "Haste",  "col": "#90e8b0", "mod": {"spd": 0.5}, "turns": 4, "good": true},
	"rage":   {"name": "Rage",   "col": "#ff7a30", "mod": {"atk": 0.5}, "turns": 4, "good": true},
	"focus":  {"name": "Focus",  "col": "#ffe8a0", "mod": {"mus": 0.5}, "turns": 4, "good": true},
	"regen":  {"name": "Regen",  "col": "#40b8e8", "regen": 0.08, "turns": 4, "good": true},
}

# ------------------------------------------------------------------- songs --
## Eight per element, learned in order at song levels (1, then every level
## ending in 5 or 0). Finish a ladder and further picks upgrade that element.
## kind: dmg | heal | revive | buff | debuff   target: one | all | ally | party | self

const SONGS := {
"fire": [
	{"name": "Kindling Air",         "cost": 3,  "kind": "dmg",  "target": "one",   "pow": 1.3},
	{"name": "Crackle Reel",         "cost": 6,  "kind": "dmg",  "target": "all",   "pow": 0.9},
	{"name": "Ashfall Lament",       "cost": 8,  "kind": "dmg",  "target": "one",   "pow": 1.5, "status": "burn"},
	{"name": "Forge Hymn",           "cost": 10, "kind": "buff", "target": "party", "status": "rage"},
	{"name": "Wildfire Breakdown",   "cost": 14, "kind": "dmg",  "target": "all",   "pow": 1.5},
	{"name": "Emberflow",            "cost": 16, "kind": "dmg",  "target": "one",   "pow": 2.6},
	{"name": "Pyre Chorus",          "cost": 24, "kind": "dmg",  "target": "all",   "pow": 2.1, "status": "burn"},
	{"name": "The Last Bright Thing","cost": 40, "kind": "dmg",  "target": "all",   "pow": 3.6, "status": "burn"},
],
"water": [
	{"name": "Springwater Air",      "cost": 3,  "kind": "heal", "target": "ally",  "pow": 1.4},
	{"name": "Ripple Round",         "cost": 6,  "kind": "dmg",  "target": "all",   "pow": 0.9},
	{"name": "Current Reel",         "cost": 8,  "kind": "dmg",  "target": "one",   "pow": 1.4, "status": "slow"},
	{"name": "Mending Tide",         "cost": 12, "kind": "heal", "target": "party", "pow": 1.2},
	{"name": "Undertow Dirge",       "cost": 15, "kind": "dmg",  "target": "one",   "pow": 2.4},
	{"name": "Rainfall Canon",       "cost": 18, "kind": "heal", "target": "party", "pow": 1.8, "cure": true},
	{"name": "Floodwater March",     "cost": 24, "kind": "dmg",  "target": "all",   "pow": 2.2},
	{"name": "The Wide Water",       "cost": 38, "kind": "heal", "target": "party", "pow": 4.0, "status": "regen", "cure": true},
],
"plant": [
	{"name": "Green Air",            "cost": 3,  "kind": "heal", "target": "ally",  "pow": 1.1, "status": "regen"},
	{"name": "Thornthrow",           "cost": 5,  "kind": "dmg",  "target": "one",   "pow": 1.3},
	{"name": "Creeping Root",        "cost": 8,  "kind": "dmg",  "target": "one",   "pow": 1.2, "status": "stun", "schance": 0.4},
	{"name": "Nettle Round",         "cost": 11, "kind": "dmg",  "target": "all",   "pow": 1.1, "status": "poison"},
	{"name": "Second Growth",        "cost": 18, "kind": "revive","target": "ally", "pow": 0.5},
	{"name": "Bramble Breakdown",    "cost": 22, "kind": "dmg",  "target": "all",   "pow": 1.8, "status": "poison"},
	{"name": "Deeproot Hymn",        "cost": 24, "kind": "heal", "target": "party", "pow": 2.2, "status": "guard"},
	{"name": "The Old Forest",       "cost": 40, "kind": "dmg",  "target": "all",   "pow": 3.2, "status": "poison"},
],
"ice": [
	{"name": "Hoarfrost Air",        "cost": 4,  "kind": "dmg",  "target": "one",   "pow": 1.3, "status": "slow"},
	{"name": "Glass Round",          "cost": 6,  "kind": "dmg",  "target": "all",   "pow": 1.0},
	{"name": "Chill Hymn",           "cost": 9,  "kind": "debuff","target": "all",  "status": "weak"},
	{"name": "Icicle Reel",          "cost": 12, "kind": "dmg",  "target": "one",   "pow": 1.1, "hits": 2},
	{"name": "Frozen Silence",       "cost": 16, "kind": "dmg",  "target": "all",   "pow": 1.5, "status": "stun", "schance": 0.25},
	{"name": "Winter's Drone",       "cost": 18, "kind": "debuff","target": "all",  "status": "slow", "extra": "weak"},
	{"name": "Blizzard Breakdown",   "cost": 26, "kind": "dmg",  "target": "all",   "pow": 2.4},
	{"name": "The Long Winter",      "cost": 40, "kind": "dmg",  "target": "all",   "pow": 3.3, "status": "slow"},
],
"electric": [
	{"name": "Static Air",           "cost": 4,  "kind": "dmg",  "target": "one",   "pow": 1.3, "status": "stun", "schance": 0.25},
	{"name": "Thunderhead Round",    "cost": 7,  "kind": "dmg",  "target": "all",   "pow": 1.1},
	{"name": "Lightning Lick",       "cost": 10, "kind": "dmg",  "target": "one",   "pow": 2.1},
	{"name": "Charged Strings",      "cost": 10, "kind": "buff", "target": "self",  "status": "focus"},
	{"name": "Rolling Thunder",      "cost": 16, "kind": "dmg",  "target": "all",   "pow": 1.6, "status": "stun", "schance": 0.3},
	{"name": "Galvanic Reel",        "cost": 20, "kind": "dmg",  "target": "one",   "pow": 1.1, "hits": 3},
	{"name": "Skyfire Chorus",       "cost": 26, "kind": "dmg",  "target": "all",   "pow": 2.5},
	{"name": "The Sky Splits Open",  "cost": 42, "kind": "dmg",  "target": "all",   "pow": 3.5, "status": "stun", "schance": 0.5},
],
"earth": [
	{"name": "Bedrock Drone",        "cost": 4,  "kind": "buff", "target": "party", "status": "guard"},
	{"name": "Gravel March",         "cost": 5,  "kind": "dmg",  "target": "one",   "pow": 1.4},
	{"name": "Stoneskin Round",      "cost": 8,  "kind": "buff", "target": "ally",  "status": "guard", "pow": 2.0},
	{"name": "Landslide Reel",       "cost": 12, "kind": "dmg",  "target": "all",   "pow": 1.3},
	{"name": "Mountain's Rest",      "cost": 14, "kind": "heal", "target": "ally",  "pow": 2.2, "status": "guard"},
	{"name": "Granite Hymn",         "cost": 17, "kind": "dmg",  "target": "one",   "pow": 2.5, "status": "stun", "schance": 0.35},
	{"name": "Quake Breakdown",      "cost": 26, "kind": "dmg",  "target": "all",   "pow": 2.4},
	{"name": "The Old Mountain",     "cost": 40, "kind": "dmg",  "target": "all",   "pow": 3.4, "status": "stun", "schance": 0.4},
],
"wind": [
	{"name": "Breeze Jig",           "cost": 3,  "kind": "dmg",  "target": "one",   "pow": 1.2},
	{"name": "Swiftfoot Air",        "cost": 6,  "kind": "buff", "target": "party", "status": "haste"},
	{"name": "Whirl Reel",           "cost": 8,  "kind": "dmg",  "target": "all",   "pow": 1.1},
	{"name": "Cutting Wind",         "cost": 11, "kind": "dmg",  "target": "one",   "pow": 1.0, "hits": 2},
	{"name": "Updraft Hymn",         "cost": 13, "kind": "heal", "target": "ally",  "pow": 1.8, "status": "haste"},
	{"name": "Cyclone Breakdown",    "cost": 18, "kind": "dmg",  "target": "all",   "pow": 1.1, "hits": 2},
	{"name": "Windshear",            "cost": 22, "kind": "dmg",  "target": "one",   "pow": 3.2},
	{"name": "The Long Wind",        "cost": 38, "kind": "dmg",  "target": "all",   "pow": 1.5, "hits": 3},
],
"dark": [
	{"name": "Shadow Air",           "cost": 4,  "kind": "dmg",  "target": "one",   "pow": 1.2, "drain": 0.4},
	{"name": "Muted Round",          "cost": 7,  "kind": "debuff","target": "all",  "status": "weak"},
	{"name": "Nightfall Reel",       "cost": 9,  "kind": "dmg",  "target": "all",   "pow": 1.2},
	{"name": "Gloom Hymn",           "cost": 11, "kind": "debuff","target": "one",  "status": "weak", "extra": "slow"},
	{"name": "Soulpull Dirge",       "cost": 15, "kind": "dmg",  "target": "one",   "pow": 2.2, "drain": 0.5},
	{"name": "Blackwater Chorus",    "cost": 20, "kind": "dmg",  "target": "all",   "pow": 1.7, "status": "poison"},
	{"name": "Eclipse Breakdown",    "cost": 26, "kind": "dmg",  "target": "all",   "pow": 2.5},
	{"name": "The Long Dark",        "cost": 42, "kind": "dmg",  "target": "all",   "pow": 3.3, "drain": 0.4},
],
}

# ------------------------------------------------------------------- items --

const ITEMS := {
	"tonic":   {"name": "Throat Tonic", "kind": "heal",    "pow": 60,  "price": 30,  "desc": "Restores 60 HP."},
	"tonic2":  {"name": "Strong Tonic", "kind": "heal",    "pow": 220, "price": 120, "desc": "Restores 220 HP."},
	"rosin":   {"name": "Rosin Cake",   "kind": "breath",  "pow": 25,  "price": 45,  "desc": "Restores 25 Breath."},
	"rosin2":  {"name": "Amber Rosin",  "kind": "breath",  "pow": 90,  "price": 180, "desc": "Restores 90 Breath."},
	"strings": {"name": "Fresh Strings","kind": "revive",  "pow": 0.5, "price": 200, "desc": "Revives you when you fall."},
	"salve":   {"name": "Bitter Salve", "kind": "cure",    "pow": 0,   "price": 40,  "desc": "Clears bad conditions."},
	"bread":   {"name": "Road Bread",   "kind": "healall", "pow": 80,  "price": 150, "desc": "Restores 80 HP."},
	"charm":   {"name": "Quiet Charm",  "kind": "escape",  "pow": 0,   "price": 60,  "desc": "Escape any fight but a boss."},
}

func item_name(id: String) -> String:
	return ITEMS[id].name if ITEMS.has(id) else id

# --------------------------------------------------------------- bestiary --

const BESTIARY := {
	"thistle":   {"name": "Thistlebeast", "art": "thistle", "elem": "plant", "hp": 44, "atk": 8, "def": 5, "spd": 7, "xp": 10, "gold": 8,
		"skills": [{"name": "Thorn Lash", "pow": 1.0}, {"name": "Spore Puff", "pow": 0.8, "status": "poison", "chance": 0.3}]},
	"mire":      {"name": "Mireling", "art": "mire", "elem": "water", "hp": 54, "atk": 7, "def": 8, "spd": 5, "xp": 12, "gold": 10,
		"skills": [{"name": "Slap", "pow": 1.0}, {"name": "Douse", "pow": 0.9, "status": "slow", "chance": 0.3}]},
	"cinder":    {"name": "Cinder Imp", "art": "cinder", "elem": "fire", "hp": 48, "atk": 11, "def": 4, "spd": 11, "xp": 15, "gold": 14,
		"skills": [{"name": "Scratch", "pow": 1.0}, {"name": "Ember Spit", "pow": 1.1, "status": "burn", "chance": 0.35}]},
	"rime":      {"name": "Rimewisp", "art": "rime", "elem": "ice", "hp": 32, "atk": 9, "def": 6, "spd": 12, "xp": 16, "gold": 12,
		"skills": [{"name": "Chill Touch", "pow": 1.0, "status": "slow", "chance": 0.25}, {"name": "Frost Bite", "pow": 1.3}]},
	"sparkhare": {"name": "Spark Hare", "art": "sparkhare", "elem": "electric", "hp": 42, "atk": 10, "def": 4, "spd": 16, "xp": 15, "gold": 13,
		"skills": [{"name": "Kick", "pow": 1.0}, {"name": "Jolt", "pow": 1.1, "status": "stun", "chance": 0.2}]},
	"galecrow":  {"name": "Galecrow", "art": "galecrow", "elem": "wind", "hp": 36, "atk": 10, "def": 5, "spd": 14, "xp": 17, "gold": 14,
		"skills": [{"name": "Rake", "pow": 1.0}, {"name": "Downdraft", "pow": 0.7, "hits": 2}]},
	"sentinel":  {"name": "Stone Sentinel", "art": "sentinel", "elem": "earth", "hp": 70, "atk": 11, "def": 16, "spd": 3, "xp": 26, "gold": 24,
		"skills": [{"name": "Slam", "pow": 1.2}, {"name": "Rockfall", "pow": 1.4, "status": "stun", "chance": 0.2}]},
	"gloomcap":  {"name": "Gloomcap", "art": "gloomcap", "elem": "dark", "hp": 44, "atk": 9, "def": 7, "spd": 8, "xp": 20, "gold": 18,
		"skills": [{"name": "Drain", "pow": 1.0, "drain": 0.5}, {"name": "Dim", "pow": 0.6, "status": "weak", "chance": 0.4}]},
	"gravehound":{"name": "Grave Hound", "art": "gravehound", "elem": "dark", "hp": 52, "atk": 14, "def": 8, "spd": 13, "xp": 30, "gold": 26,
		"skills": [{"name": "Maul", "pow": 1.2}, {"name": "Howl", "pow": 0.5, "status": "weak", "chance": 0.5}]},
	"discord":   {"name": "Discord", "art": "discord", "elem": "", "hp": 58, "atk": 13, "def": 10, "spd": 10, "xp": 34, "gold": 30,
		"skills": [{"name": "Wrong Note", "pow": 1.2}, {"name": "Screech", "pow": 1.0, "status": "stun", "chance": 0.25}]},
	"bogwitch":  {"name": "Bog Witch", "art": "bogwitch", "elem": "plant", "hp": 62, "atk": 12, "def": 9, "spd": 9, "xp": 38, "gold": 40,
		"skills": [{"name": "Hex", "pow": 1.1, "status": "poison", "chance": 0.4}, {"name": "Green Mend", "pow": 0.0, "heal": 0.4}]},
	"thunderram":{"name": "Thunder Ram", "art": "thunderram", "elem": "electric", "hp": 78, "atk": 16, "def": 11, "spd": 12, "xp": 46, "gold": 44,
		"skills": [{"name": "Charge", "pow": 1.4}, {"name": "Thunderclap", "pow": 1.2, "all": true, "status": "stun", "chance": 0.2}]},

	"gravebell": {"name": "The Gravebell", "art": "gravebell", "elem": "earth", "hp": 520, "atk": 30, "def": 40, "spd": 8, "xp": 300, "gold": 400, "boss": true,
		"skills": [{"name": "Toll", "pow": 1.3}, {"name": "Deep Ring", "pow": 1.1, "all": true, "status": "stun", "chance": 0.3}, {"name": "Iron Peal", "pow": 1.8}]},
	"conductor": {"name": "The Discordant", "art": "conductor", "elem": "dark", "hp": 1100, "atk": 46, "def": 60, "spd": 15, "xp": 700, "gold": 900, "boss": true,
		"skills": [{"name": "Downbeat", "pow": 1.4}, {"name": "Dissonance", "pow": 1.2, "all": true},
			{"name": "Silence Them", "pow": 0.8, "all": true, "status": "weak", "chance": 0.7}, {"name": "Grand Pause", "pow": 2.0}]},
	"quiet":     {"name": "The Quiet", "art": "quiet", "elem": "dark", "hp": 2400, "atk": 62, "def": 72, "spd": 18, "xp": 2000, "gold": 2000, "boss": true,
		"skills": [{"name": "Unsong", "pow": 1.5}, {"name": "The Long Hush", "pow": 1.3, "all": true, "status": "weak", "chance": 0.5},
			{"name": "Forgetting", "pow": 1.2, "all": true, "drain": 0.4}, {"name": "Nothing At All", "pow": 2.4}]},
}

const REGIONS := {
	"meadow": {"tier": 1.0, "music": "field", "bg": "meadow", "rate": 0.055, "mobs": ["thistle", "mire", "sparkhare", "cinder"]},
	"wood":   {"tier": 1.8, "music": "field", "bg": "wood",   "rate": 0.065, "mobs": ["thistle", "galecrow", "gloomcap", "bogwitch", "gravehound"]},
	"crag":   {"tier": 3.0, "music": "field", "bg": "crag",   "rate": 0.070, "mobs": ["sentinel", "rime", "thunderram", "galecrow", "discord"]},
	# 4.2 and 5.5 put the win rate at 60% across 40 fights apiece -- the dungeon
	# was killing the player two times in five, and that was with a soak player
	# who never stops to heal.
	"cave":   {"tier": 3.4, "music": "cave",  "bg": "cave",   "rate": 0.062, "mobs": ["sentinel", "gravehound", "discord", "gloomcap", "thunderram"]},
	"deep":   {"tier": 4.2, "music": "cave",  "bg": "deep",   "rate": 0.066, "mobs": ["discord", "thunderram", "gravehound", "bogwitch", "sentinel"]},
}

# --------------------------------------------------------- the damage model --
## Defence gives diminishing returns rather than flat subtraction. With flat
## subtraction the same monster is lethal at level 3 and harmless at level 15,
## because the player's DEF climbs by a fixed amount every single level.

const DEF_K := 90.0

func mitigate(power: float, def_val: float, rng: RandomNumberGenerator = null) -> int:
	var variance := 0.9 + (rng.randf() if rng else randf()) * 0.2
	return maxi(1, roundi(power * (1.0 - def_val / (def_val + DEF_K)) * variance))

func phys_damage(atk: float, def_val: float, rng: RandomNumberGenerator = null) -> int:
	return mitigate(atk * 1.7, def_val, rng)

## Enemies hit for much less per swing than the player does, because there are
## usually two or three of them and they all swing every round. The first pass
## used 1.55 -- the same order as the player's own multiplier -- and the soak
## test showed the player losing 90% of their health per fight and losing half
## of them outright. A one-against-one damage comparison cannot see this.
func enemy_damage(atk: float, def_val: float, rng: RandomNumberGenerator = null) -> int:
	return mitigate(atk * 0.95, def_val, rng)

## Songs are powered by MUSIC plus affinity in that element. This matters:
## only the General pick raises MUSIC, so without the affinity term a player who
## always picks an element -- exactly the specialist the level system invites --
## would have a permanently feeble stat behind every song they own.
func song_music(mus: float, aff: int) -> float:
	return mus + float(aff) * 3.0

func song_damage(mus: float, pow_val: float, def_val: float, aff: int, rng: RandomNumberGenerator = null) -> int:
	return mitigate(song_music(mus, aff) * 2.6 * pow_val, def_val, rng)

func song_heal(mus: float, pow_val: float, aff: int) -> int:
	return roundi(song_music(mus, aff) * pow_val * 2.2)

# ------------------------------------------------------------- progression --

## Songs are earned per ELEMENT, not per character level. Every time you pick an
## element its own level goes up by one, and its 1st, 5th, 10th, 15th... pick
## teaches a song. Investing in one element deeply is what gets you its later
## songs; spreading across all eight gets you eight first songs and no depth.
func is_song_step(elem_level: int) -> bool:
	return elem_level == 1 or elem_level % 5 == 0

## The element level a given song sits at: 1, 5, 10, 15, ...
func song_step_for(index: int) -> int:
	return 1 if index == 0 else index * 5

## The next element level that will teach a song, given where you are now.
func next_song_step(elem_level: int) -> int:
	if elem_level < 1:
		return 1
	return (int(elem_level / 5) + 1) * 5

func xp_to_next(lv: int) -> int:
	return int(floor(10.0 * pow(float(lv), 1.7) + 15.0 * float(lv)))

func describe_song(s: Dictionary) -> String:
	match s.get("kind", ""):
		"heal":
			return "Restores health." if s.get("target", "") != "party" else "Restores health to everyone."
		"revive":
			return "Calls you back when you have fallen."
		"buff":
			return "Strengthens you."
		"debuff":
			return "Weakens the enemy."
	var d := "Damages " + ("all enemies" if s.get("target", "") == "all" else "one enemy")
	if s.has("hits"):
		d += " %d times" % s.hits
	if s.has("status"):
		d += ", may cause " + STATUS[s.status].name
	if s.has("drain"):
		d += ", and heals you"
	return d + "."

# ------------------------------------------------------------------ enemies --

func make_enemy(id: String, tier: float) -> Dictionary:
	var b: Dictionary = BESTIARY[id]
	var is_boss: bool = b.get("boss", false)
	# HP scales faster than tier because player damage grows faster than level.
	# HP scales faster than tier, and faster still since the soak: fights that
	# end in two turns are swingy rather than tense.
	var hp_mul := 1.0 if is_boss else pow(tier, 1.85)
	var xp_mul := 1.0 if is_boss else pow(tier, 1.5)
	var t := 1.0 if is_boss else tier
	var hp := roundi(float(b.hp) * hp_mul)
	return {
		"id": id, "name": b.name, "art": b.art, "elem": b.get("elem", ""), "boss": is_boss,
		"skills": b.skills,
		"maxhp": hp, "hp": hp,
		# Attack scales sub-linearly with tier while HP scales super-linearly.
		# Late fights last longer, so linear attack growth compounds into a
		# region the player cannot survive however well they play.
		"atk": roundi(float(b.atk) * pow(t, 0.78)), "def": roundi(float(b.def) * t),
		"spd": roundi(float(b.spd) * (1.0 if is_boss else 0.85 + t * 0.12)),
		"xp": roundi(float(b.xp) * xp_mul), "gold": roundi(float(b.gold) * t),
		"st": {}, "dead": false,
	}
