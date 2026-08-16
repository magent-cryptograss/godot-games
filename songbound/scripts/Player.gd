class_name Player
extends RefCounted
## The one character. Stats, the song book, and the level-up choice.

var name: String = "Nameless"
var inst: String = "guitar"
var spr: PackedByteArray          # 16x24 palette indices, index 0 transparent
var back: PackedByteArray         # derived back view

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
		"v": 1, "name": name, "inst": inst, "spr": Array(spr),
		"lv": lv, "xp": xp, "base": base, "grow": grow, "hp": hp, "br": br,
		"songs": songs, "affinity": affinity, "upgrades": upgrades,
		"items": items, "gold": gold, "flags": flags,
	}

static func from_dict(d: Dictionary) -> Player:
	var spr_bytes := PackedByteArray()
	for v in d.get("spr", []):
		spr_bytes.append(int(v))
	var p := Player.new(d.get("name", "Nameless"), d.get("inst", "guitar"), spr_bytes)
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
