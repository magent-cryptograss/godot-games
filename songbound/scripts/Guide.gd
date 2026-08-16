class_name Guide
extends RefCounted
## Knowing where you are and what you are meant to be doing.
##
## The world got a hundred times bigger and nothing was added to steer by, so it
## stopped being clear what to do -- which is a fair complaint about a road that
## is now six hundred tiles long. Everything here exists to answer three
## questions: where am I, where are the other places, and what am I doing next.

# --------------------------------------------------------------- place names --

const HOME_TOWN := "Cane Ridge"

## What to call a map. The generated places know their own names; these are the
## hand-built ones.
static func place_name(map_id: String) -> String:
	match map_id:
		"world": return ""
		"town": return HOME_TOWN
		"inn": return "The Inn"
		"shop": return "The Shop"
		"house1", "house2": return ""
		"cave1": return "The Cave"
		"cave2": return "The Cave, Deeper"
		"cave3": return "The Cave, Deepest"
		"final": return "The Quiet"
	if Places.sites.has(map_id):
		return Places.sites[map_id].name
	for d in Places.dungeons():
		var n: int = d.floors
		for i in n:
			if map_id == "%s%d" % [d.id, i + 1]:
				if n == 1 or i == 0:
					return d.name
				return "%s, %s" % [d.name, ["", "deeper", "deepest", "the bottom"][mini(i, 3)]]
	for t in Places.towns():
		if map_id == t.id + "_inn": return "%s Inn" % t.name
		if map_id == t.id + "_shop": return "%s Shop" % t.name
	return ""


# ------------------------------------------------------------- what to do next --

## The main line of the story, as one step at a time. Everything is keyed off
## flags the game already sets, so there is no quest state to keep in sync.
static func objective() -> Dictionary:
	var f: Dictionary = Game.player.flags if Game.player != null else {}
	if not f.get("seen_world", false):
		return {
			"title": "Leave town",
			"detail": "Out through the gap in the trees at the bottom of town.",
			"map": "town", "at": Vector2i(Places.TOWN_GATE.x, Places.TOWN_GATE.y),
		}
	if not f.get("boss_gravebell", false):
		return {
			"title": "North to the cave",
			"detail": "Follow the road. It is a long walk and there are towns on it.",
			"map": "world", "at": World.cave_mouth,
		}
	if not f.get("boss_conductor", false):
		return {
			"title": "Deeper in the cave",
			"detail": "Past where the bell was hanging.",
			"map": "cave2", "at": Vector2i(17, 2),
		}
	if not f.get("boss_quiet", false):
		return {
			"title": "The bottom of the cave",
			"detail": "The last of it is down there.",
			"map": "cave3", "at": Vector2i(16, 1),
		}
	return {"title": "It is done", "detail": "Go home the long way.", "map": "", "at": Vector2i.ZERO}


## The optional dungeons, and whether they have been dealt with. Shown as a list
## rather than a single next step, because they are meant to be taken in any
## order or not at all.
static func side_quests() -> Array:
	var f: Dictionary = Game.player.flags if Game.player != null else {}
	var out: Array = []
	for d in Places.dungeons():
		var gate: Vector2i = Places.sites.get(d.id, {}).get("gate", Vector2i.ZERO)
		out.append({
			"name": d.name,
			"done": f.get("boss_" + str(d.flag), false),
			"at": gate,
			"prize": Data.ITEMS[d.prize].name,
		})
	return out


## Every place worth walking to, nearest first, with which way it lies.
static func places_from(here: Vector2i) -> Array:
	var out: Array = []
	var f: Dictionary = Game.player.flags if Game.player != null else {}
	out.append({"name": HOME_TOWN, "kind": "town", "at": World.town_gate, "done": false})
	out.append({"name": "The Cave", "kind": "dungeon", "at": World.cave_mouth,
		"done": f.get("boss_quiet", false)})
	for id in Places.sites:
		var s: Dictionary = Places.sites[id]
		var done := false
		for d in Places.dungeons():
			if d.id == id:
				done = f.get("boss_" + str(d.flag), false)
		out.append({"name": s.name, "kind": s.kind, "at": s.gate, "done": done})
	for pl in out:
		var d2: Vector2i = pl.at - here
		pl["dist"] = absi(d2.x) + absi(d2.y)
		pl["way"] = compass(here, pl.at)
	out.sort_custom(func(a, b): return a.dist < b.dist)
	return out


## Which way to walk, in words. Eight points is enough to set off on and vague
## enough to stay true for the whole walk.
static func compass(from: Vector2i, to: Vector2i) -> String:
	var dx := to.x - from.x
	var dy := to.y - from.y
	if absi(dx) + absi(dy) < 6:
		return "here"
	var ns := ""
	var ew := ""
	if dy < -absi(dx) / 2: ns = "north"
	elif dy > absi(dx) / 2: ns = "south"
	if dx > absi(dy) / 2: ew = "east"
	elif dx < -absi(dy) / 2: ew = "west"
	if ns != "" and ew != "":
		return ns + "-" + ew
	return ns if ns != "" else ew


# ------------------------------------------------------------------ the map --

## One colour per tile for the overview. Roads and water win over the ground
## they cross, or the only thing you can actually navigate by disappears.
const MAP_COLS := {
	".": "#4d8f4f", "f": "#5c9a5c", ",": "#3d7a42", "\"": "#7f8a4e",
	"=": "#c9a05e", "q": "#9a7c50", "o": "#a8a8a2", "B": "#d8b070",
	"~": "#2f6099", "T": "#245a28", "P": "#1c4a24", "^": "#8d8578",
	"r": "#6b645a", "%": "#2f6c34", "F": "#8a6a40", "#": "#7b736c",
	"W": "#8a6440", "R": "#a04438", "V": "#8a3830", "d": "#71482a",
	"C": "#241a2a", "S": "#70d0ff", "g": "#7f7a76", "w": "#8d8578",
}

## What survives when several tiles share one pixel. A one-tile-wide road is
## invisible under any sane averaging, and the road is the whole point.
const MAP_RANK := {
	"=": 9, "B": 9, "o": 8, "C": 8, "S": 7, "~": 6, "R": 5, "V": 5, "W": 5,
	"^": 4, "r": 3, "T": 2, "P": 2, "%": 2, "F": 2,
}

static var _map_tex: ImageTexture = null
static var _map_scale := 1

## The overworld, small enough to look at. Built once and kept -- it is half a
## million tiles and there is no reason to look at them twice.
static func world_texture(max_w: int, max_h: int) -> ImageTexture:
	if _map_tex != null:
		return _map_tex
	var m: Maps.GameMap = World.build_all()["world"]
	var step := maxi(1, ceili(maxf(float(m.w) / float(max_w), float(m.h) / float(max_h))))
	_map_scale = step
	var iw := int(m.w / step)
	var ih := int(m.h / step)
	var img := Image.create(iw, ih, false, Image.FORMAT_RGBA8)
	for y in ih:
		for x in iw:
			var best := "."
			var best_rank := -1
			for dy in step:
				for dx in step:
					var ch := m.get_tile(x * step + dx, y * step + dy)
					var rank: int = MAP_RANK.get(ch, 1)
					if rank > best_rank:
						best_rank = rank
						best = ch
			img.set_pixel(x, y, Color(MAP_COLS.get(best, "#4d8f4f")))
	_map_tex = ImageTexture.create_from_image(img)
	return _map_tex


static func map_scale() -> int:
	return _map_scale


## Forget the cached picture. Only the map editor needs this, after a save has
## changed what the world looks like.
static func invalidate() -> void:
	_map_tex = null
