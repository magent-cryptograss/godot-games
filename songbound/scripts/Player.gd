class_name Player
extends RefCounted
## The one character. Stats, the song book, and the level-up choice.

var name: String = "Nameless"
var inst: String = "guitar"
# Four drawings, one per facing. The player draws as many of them as they feel
# like and the rest are generated from the front one.
var spr: PackedByteArray          # facing down; also the portrait everywhere else
var back: PackedByteArray         # facing up
var side_l: PackedByteArray       # facing left
var side_r: PackedByteArray       # facing right

## Every hand-drawn animation frame: the walk, keyed "down1" through "right3";
## the battle stance, keyed "battle"; and the swing, keyed "attack1" through
## "attack10". Only what somebody actually drew is in here -- an absent walk
## frame is animated the old way by shifting the standing drawing, and an absent
## attack frame is simply not played.
var frames := {}

## How many attack frames may be drawn. One is enough to have a swing; the rest
## are there for anybody who wants to animate it properly.
const MAX_ATTACK := 10

var lv: int = 1
var xp: int = 0
# 55 starting health meant the opening fight cost more than half of it, which
# reads as the game being unfair rather than as the game being hard. The gain
# per level is unchanged, so this flattens the first few levels rather than
# shifting the whole curve up.
var base := {"hp": 68, "br": 18, "atk": 9, "def": 8, "mus": 9, "spd": 9}
var grow := {"hp": 0, "br": 0, "atk": 0, "def": 0, "mus": 0, "spd": 0}
var hp: int = 0
var br: int = 0

var songs: Array[Dictionary] = []     # [{elem, idx}]
var affinity := {}                    # elem -> times chosen
var upgrades := {}                    # elem -> ladder completions
var items := {"tonic": 3, "rosin": 2}
var gold: int = 60
var flags := {}

var rng := RandomNumberGenerator.new()


func _init(p_name: String = "Nameless", p_inst: String = "guitar", p_spr: PackedByteArray = PackedByteArray()) -> void:
	name = p_name
	inst = p_inst
	spr = p_spr
	for e in Data.ELEMENTS:
		affinity[e.id] = 0
		upgrades[e.id] = 0
	hp = max_hp()
	br = max_br()


## The drawing for a facing, falling back to the front one if a view is missing
## -- an old save from before there were four of them, for instance.
func view(facing: String) -> PackedByteArray:
	match facing:
		"up":
			return back if back.size() > 0 else spr
		"left":
			return side_l if side_l.size() > 0 else spr
		"right":
			return side_r if side_r.size() > 0 else spr
	return spr


## The drawing for one step of a walk, or nothing if that frame was never drawn.
func walk_grid(facing: String, frame: int) -> PackedByteArray:
	if frame <= 0:
		return PackedByteArray()
	var g: PackedByteArray = frames.get("%s%d" % [facing, frame], PackedByteArray())
	return g if g.size() == Sprites.W * Sprites.H else PackedByteArray()


## How the character stands in a fight, or the front view if nobody drew one.
func battle_grid() -> PackedByteArray:
	var g: PackedByteArray = frames.get("battle", PackedByteArray())
	return g if g.size() == Sprites.W * Sprites.H else spr


## One frame of the swing, or nothing if it was never drawn.
func attack_grid(i: int) -> PackedByteArray:
	var g: PackedByteArray = frames.get("attack%d" % i, PackedByteArray())
	return g if g.size() == Sprites.W * Sprites.H else PackedByteArray()


## How long the swing runs for. Counted from the first frame and stopping at the
## first gap, so drawing frames 1, 2 and 7 gives a two-frame swing rather than
## five frames of nothing followed by a twitch.
func attack_count() -> int:
	var n := 0
	for i in range(1, MAX_ATTACK + 1):
		if attack_grid(i).is_empty():
			break
		n += 1
	return n


## Fill in whichever views were not drawn by hand.
func derive_views() -> void:
	if back.size() == 0:
		back = Sprites.back_view(spr)
	if side_r.size() == 0:
		side_r = Sprites.side_view(spr)
	if side_l.size() == 0:
		side_l = Sprites.mirrored(side_r)


func _frames_to_dict() -> Dictionary:
	var out := {}
	for key in frames:
		out[key] = Array(frames[key])
	return out


func mods() -> Dictionary:
	return Data.instrument(inst).mods

## Instrument mods are a flat offset plus a gentle per-level lean. The bulk of
## progression lives in grow.*, so the instrument colours the curve without the
## level term compounding into a runaway.
func max_hp() -> int:
	return maxi(1, base.hp + grow.hp + mods().hp * 4)

func max_br() -> int:
	return maxi(1, base.br + grow.br + mods().br * 3)

func stat_atk() -> int:
	return base.atk + grow.atk + mods().atk * 2 + int(floor(lv * mods().atk * 0.06))

func stat_def() -> int:
	return base.def + grow.def + mods().def * 2 + int(floor(lv * mods().def * 0.06))

func stat_mus() -> int:
	return base.mus + grow.mus + mods().mus * 2 + int(floor(lv * mods().mus * 0.06))

func stat_spd() -> int:
	return base.spd + grow.spd + mods().spd * 2 + int(floor(lv * mods().spd * 0.05))


# ------------------------------------------------------------- the song book --

func songs_of(elem: String) -> int:
	var n := 0
	for s in songs:
		if s.elem == elem:
			n += 1
	return n

## -1 once the ladder is finished; further picks upgrade instead.
func next_song_index(elem: String) -> int:
	var n := songs_of(elem)
	return n if n < Data.SONGS[elem].size() else -1

func song_data(s: Dictionary) -> Dictionary:
	var b: Dictionary = Data.SONGS[s.elem][s.idx]
	var up: int = upgrades.get(s.elem, 0)
	var d := b.duplicate(true)
	d["elem"] = s.elem
	d["idx"] = s.idx
	d["upgraded"] = up
	d["pow"] = float(b.get("pow", 0.0)) * (1.0 + up * 0.15)
	return d

func song_book() -> Array:
	var out := []
	for s in songs:
		out.append(song_data(s))
	return out


# ------------------------------------------------------------- the level-up --

## kind is "general" or an element id. at_lv is the level being awarded, which
## matters when several levels are gained from one fight.
func apply_level_choice(kind: String, _at_lv: int = -1) -> Array[String]:
	var lines: Array[String] = []
	var m := mods()

	# automatic growth every level, so the numbers keep pace with the bestiary
	var hp_g := 8 + roundi(m.hp * 0.35) + rng.randi_range(0, 2)
	var br_g := 5 + roundi(m.br * 0.4)
	grow.hp += hp_g
	grow.br += br_g
	lines.append("HP +%d   Breath +%d" % [hp_g, br_g])

	if kind == "general":
		grow.atk += 3
		grow.def += 3
		grow.mus += 3
		lines.append("ATK +3   DEF +3   MUSIC +3")
	else:
		# the element's own level goes up, and ITS milestones teach the songs
		var alv: int = affinity.get(kind, 0) + 1
		affinity[kind] = alv
		var ename: String = Data.element(kind).name
		if Data.is_song_step(alv):
			var idx := next_song_index(kind)
			grow.atk += 1
			grow.def += 1
			lines.append("ATK +1   DEF +1")
			lines.append("%s reached %d" % [ename, alv])
			if idx >= 0:
				songs.append({"elem": kind, "idx": idx})
				lines.append("LEARNED: " + Data.SONGS[kind][idx].name)
			else:
				upgrades[kind] = upgrades.get(kind, 0) + 1
				lines.append("All %s songs grew stronger!" % ename)
		else:
			grow.atk += 2
			grow.def += 2
			lines.append("ATK +2   DEF +2")
			lines.append("%s reached %d  (song at %d)" % [ename, alv, Data.next_song_step(alv)])

	hp = max_hp()
	br = max_br()
	return lines


func grant_xp(amount: int) -> Array[int]:
	var gained: Array[int] = []
	if lv >= Data.MAX_LEVEL:
		return gained
	xp += amount
	while lv < Data.MAX_LEVEL and xp >= Data.xp_to_next(lv):
		xp -= Data.xp_to_next(lv)
		lv += 1
		gained.append(lv)
	return gained


# -------------------------------------------------------------- save / load --

func to_dict() -> Dictionary:
	return {
		"v": 2, "name": name, "inst": inst, "spr": Array(spr),
		"back": Array(back), "side_l": Array(side_l), "side_r": Array(side_r),
		"frames": _frames_to_dict(),
		"lv": lv, "xp": xp, "base": base, "grow": grow, "hp": hp, "br": br,
		"songs": songs, "affinity": affinity, "upgrades": upgrades,
		"items": items, "gold": gold, "flags": flags,
	}

static func from_dict(d: Dictionary) -> Player:
	var spr_bytes := PackedByteArray()
	for v in d.get("spr", []):
		spr_bytes.append(int(v))
	var p := Player.new(d.get("name", "Nameless"), d.get("inst", "guitar"), spr_bytes)
	for key in [["back", "back"], ["side_l", "side_l"], ["side_r", "side_r"]]:
		var bytes := PackedByteArray()
		for v in d.get(key[0], []):
			bytes.append(int(v))
		p.set(key[1], bytes)
	# A save from before the figures grew holds a 24x32 drawing. It cannot be
	# stretched into a 32x48 one without looking like a smear, so it is dropped
	# and the character comes back as a preset rather than as nothing at all.
	if p.spr.size() != Sprites.W * Sprites.H:
		p.spr = Sprites.build(Sprites.PRESETS[0].opts)
		p.back = PackedByteArray()
		p.side_l = PackedByteArray()
		p.side_r = PackedByteArray()
	for key in ["back", "side_l", "side_r"]:
		if p.get(key).size() != Sprites.W * Sprites.H:
			p.set(key, PackedByteArray())
	for key in d.get("frames", {}):
		var fb := PackedByteArray()
		for val in d.frames[key]:
			fb.append(int(val))
		if fb.size() == Sprites.W * Sprites.H:
			p.frames[key] = fb
	p.derive_views()
	p.lv = int(d.get("lv", 1))
	p.xp = int(d.get("xp", 0))
	for k in d.get("base", {}):
		p.base[k] = int(d.base[k])
	for k in d.get("grow", {}):
		p.grow[k] = int(d.grow[k])
	var raw_songs: Array[Dictionary] = []
	for s in d.get("songs", []):
		raw_songs.append({"elem": str(s.elem), "idx": int(s.idx)})
	p.songs = raw_songs
	for e in Data.ELEMENTS:
		p.affinity[e.id] = int(d.get("affinity", {}).get(e.id, 0))
		p.upgrades[e.id] = int(d.get("upgrades", {}).get(e.id, 0))
	p.items = d.get("items", {}).duplicate()
	p.gold = int(d.get("gold", 0))
	p.flags = d.get("flags", {}).duplicate()
	p.hp = clampi(int(d.get("hp", p.max_hp())), 1, p.max_hp())
	p.br = clampi(int(d.get("br", p.max_br())), 0, p.max_br())
	return p
