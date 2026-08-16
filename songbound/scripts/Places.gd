class_name Places
extends RefCounted
## Every town and dungeon past the first of each.
##
## An 800x640 world with one town and one cave in it is a rumour of a game. This
## adds five more towns and five more dungeons, generated from a spec rather than
## drawn by hand -- ten places drawn by hand is ten chances to put a door inside
## a wall, and the map editor exists for the ones that deserve the attention.
##
## Everything here is deterministic. Same seed, same town, every run, so a save
## file still means something and the map editor's overrides still line up.

## Where the world generator put each site's front door. Filled in by stamp()
## during the overworld build, read by build_maps() when the interiors are made,
## so no map has to hardcode a coordinate that moves when the world is resized.
static var sites := {}

## Floor 1 of every dungeon is this size with its entry chamber here, so the
## overworld warp can be written before the dungeon itself is generated.
const F1_W := 44
const F1_H := 34
const F1_ENTRY := Vector2i(6, 28)

## Every town is this size with its gate here, for the same reason.
const TOWN_W := 30
const TOWN_H := 26
const TOWN_GATE := Vector2i(14, 25)


static func towns() -> Array:
	return [
		{
			"id": "millbrook", "music": "town_millbrook", "name": "Millbrook", "at": Vector2(0.34, 0.72), "seed": 3101,
			"ground": ".", "tuft": "f", "wall": "T", "inn": 60,
			"stock": ["tonic", "rosin", "salve", "bread"],
			"sign": Story.MILLBROOK_SIGN, "innkeep": Story.MILLBROOK_INN, "shopkeep": Story.MILLBROOK_SHOP,
			"folk": [
				{"look": "miller", "dir": "down", "lines": Story.MILLBROOK_A},
				{"look": "kid", "dir": "left", "wander": true, "lines": Story.MILLBROOK_B},
				{"look": "widow", "dir": "down", "lines": Story.MILLBROOK_C},
			],
			"decor": "well", "chest": "rosin",
		},
		{
			"id": "longferry", "music": "town_longferry", "name": "Longferry", "at": Vector2(0.46, 0.58), "seed": 3102,
			"ground": ".", "tuft": "f", "wall": "%", "inn": 60,
			"stock": ["tonic", "tonic2", "rosin", "salve", "charm"],
			"sign": Story.LONGFERRY_SIGN, "innkeep": Story.LONGFERRY_INN, "shopkeep": Story.LONGFERRY_SHOP,
			"folk": [
				{"look": "ferry", "dir": "down", "lines": Story.LONGFERRY_A},
				{"look": "woman", "dir": "right", "lines": Story.LONGFERRY_B},
				{"look": "preacher", "dir": "down", "lines": Story.LONGFERRY_C},
			],
			"decor": "water", "chest": "tonic2",
		},
		{
			"id": "highwater", "music": "town_highwater", "name": "Highwater", "at": Vector2(0.24, 0.44), "seed": 3103,
			"ground": ",", "tuft": "f", "wall": "P", "inn": 100,
			"stock": ["tonic", "tonic2", "rosin", "rosin2", "salve", "strings"],
			"sign": Story.HIGHWATER_SIGN, "innkeep": Story.HIGHWATER_INN, "shopkeep": Story.HIGHWATER_SHOP,
			"folk": [
				{"look": "oldman", "dir": "down", "lines": Story.HIGHWATER_A},
				{"look": "smith", "dir": "left", "lines": Story.HIGHWATER_B},
				{"look": "girl", "dir": "down", "wander": true, "lines": Story.HIGHWATER_C},
			],
			"decor": "graves", "chest": "strings",
		},
		{
			"id": "ashfall", "music": "town_ashfall", "name": "Ashfall", "at": Vector2(0.50, 0.30), "seed": 3104,
			"ground": "q", "tuft": "\"", "wall": "^", "inn": 160,
			"stock": ["tonic", "tonic2", "rosin", "rosin2", "salve", "bread", "strings", "charm"],
			"sign": Story.ASHFALL_SIGN, "innkeep": Story.ASHFALL_INN, "shopkeep": Story.ASHFALL_SHOP,
			"folk": [
				{"look": "miner", "dir": "down", "lines": Story.ASHFALL_A},
				{"look": "smith", "dir": "down", "lines": Story.ASHFALL_B},
				{"look": "oldman", "dir": "right", "lines": Story.ASHFALL_C},
			],
			"decor": "well", "chest": "rosin2",
		},
		{
			"id": "lastchord", "music": "town_lastchord", "name": "Last Chord", "at": Vector2(0.40, 0.13), "seed": 3105,
			"ground": ",", "tuft": "\"", "wall": "^", "inn": 240,
			"stock": ["tonic", "tonic2", "rosin", "rosin2", "salve", "bread", "strings", "charm"],
			"sign": Story.LASTCHORD_SIGN, "innkeep": Story.LASTCHORD_INN, "shopkeep": Story.LASTCHORD_SHOP,
			"folk": [
				{"look": "widow", "dir": "down", "lines": Story.LASTCHORD_A},
				{"look": "drifter", "dir": "left", "lines": Story.LASTCHORD_B},
				{"look": "preacher", "dir": "down", "lines": Story.LASTCHORD_C},
			],
			"decor": "graves", "chest": "bread",
		},
	]


static func dungeons() -> Array:
	return [
		{
			"id": "barrow", "name": "The Barrow", "at": Vector2(0.22, 0.66), "seed": 4101,
			"floors": 2, "region": "hollow", "boss": "hollowbell", "flag": "hollowbell",
			"intro": Story.BOSS_HOLLOWBELL, "sign": Story.SIGN_BARROW,
			"prize": "r_bell", "loot": ["tonic", "rosin"],
		},
		{
			"id": "chapel", "name": "The Drowned Chapel", "at": Vector2(0.58, 0.52), "seed": 4102,
			"floors": 2, "region": "chapel", "boss": "choirmaster", "flag": "choirmaster",
			"intro": Story.BOSS_CHOIRMASTER, "sign": Story.SIGN_CHAPEL,
			"prize": "r_baton", "loot": ["tonic2", "salve"],
		},
		{
			"id": "kennel", "name": "The Kennels", "at": Vector2(0.12, 0.38), "seed": 4103,
			"floors": 3, "region": "kennel", "boss": "kennelking", "flag": "kennelking",
			"intro": Story.BOSS_KENNELKING, "sign": Story.SIGN_KENNEL,
			"prize": "r_collar", "loot": ["rosin2", "bread", "tonic2"],
		},
		{
			"id": "spire", "name": "The Storm Spire", "at": Vector2(0.72, 0.24), "seed": 4104,
			"floors": 3, "region": "spire", "boss": "stormfather", "flag": "stormfather",
			"intro": Story.BOSS_STORMFATHER, "sign": Story.SIGN_SPIRE,
			"prize": "r_rod", "loot": ["tonic2", "strings", "rosin2"],
		},
		{
			"id": "thicket", "name": "The Mother Thicket", "at": Vector2(0.80, 0.10), "seed": 4105,
			"floors": 3, "region": "thicket", "boss": "mothertree", "flag": "mothertree",
			"intro": Story.BOSS_MOTHERTREE, "sign": Story.SIGN_THICKET,
			"prize": "r_seed", "loot": ["strings", "bread", "tonic2"],
		},
	]


# ------------------------------------------------------------- the overworld --

## Put every site on the overworld and record where its door ended up. Called
## while the world is still being built, before the roads are carved, because a
## road carved first and then built over is a road into a wall.
static func stamp(m: Maps.GameMap) -> Array:
	sites = {}
	var anchors: Array = []
	for t in towns():
		var p := Vector2i(int(m.w * t.at.x), int(m.h * t.at.y))
		p = _clear_of_edges(m, p)
		# a cluster of roofs, so a town reads as a town from across the valley
		m.rect(p.x - 6, p.y - 5, 13, 10, ".")
		m.building(p.x - 5, p.y - 4, 5, 4, 2)
		m.building(p.x + 2, p.y - 4, 4, 4, 1)
		m.building(p.x - 4, p.y + 1, 4, 3, 1)
		m.set_tile(p.x, p.y, "o")
		m.warps.append({"x": p.x, "y": p.y, "to": t.id, "tx": TOWN_GATE.x, "ty": TOWN_GATE.y - 1})
		sites[t.id] = {"gate": p, "kind": "town", "name": t.name}
		anchors.append({"p": Vector2i(p.x, p.y + 1), "id": t.id})

	for d in dungeons():
		var p := Vector2i(int(m.w * d.at.x), int(m.h * d.at.y))
		p = _clear_of_edges(m, p)
		m.rect(p.x - 3, p.y - 2, 7, 4, "^")
		m.rect(p.x - 2, p.y + 2, 5, 3, ".")
		m.set_tile(p.x, p.y, "C")
		m.warps.append({"x": p.x, "y": p.y, "to": d.id + "1", "tx": F1_ENTRY.x, "ty": F1_ENTRY.y})
		m.set_tile(p.x - 2, p.y + 2, "S")
		m.npcs.append({"x": p.x - 2, "y": p.y + 2, "sign": true, "lines": d.sign})
		sites[d.id] = {"gate": p, "kind": "dungeon", "name": d.name}
		anchors.append({"p": Vector2i(p.x, p.y + 1), "id": d.id})
	return anchors


static func _clear_of_edges(m: Maps.GameMap, p: Vector2i) -> Vector2i:
	return Vector2i(clampi(p.x, 8, m.w - 9), clampi(p.y, 8, m.h - 9))


# ------------------------------------------------------------------- towns --

static func build_maps(maps: Dictionary) -> void:
	for t in towns():
		_make_town(maps, t)
	for d in dungeons():
		_make_dungeon(maps, d)


static func _make_town(maps: Dictionary, t: Dictionary) -> void:
	var w := TOWN_W
	var h := TOWN_H
	var m := Maps.GameMap.new(t.id, w, h, t.ground)
	m.music = str(t.get("music", "town"))
	m.region = ""
	var rng := RandomNumberGenerator.new()
	rng.seed = t.seed

	for y in h:
		for x in w:
			m.set_tile(x, y, t.tuft if rng.randf() > 0.94 else t.ground)
	m.rect(0, 0, w, 2, t.wall); m.rect(0, h - 2, w, 2, t.wall)
	m.rect(0, 0, 2, h, t.wall); m.rect(w - 2, 0, 2, h, t.wall)

	# one spine and one cross street -- enough to read as laid out rather than
	# scattered, without the buildings ever landing on the road
	m.vline(3, h - 3, TOWN_GATE.x, "o")
	m.vline(3, h - 3, TOWN_GATE.x + 1, "o")
	m.hline(3, w - 4, 11, "o")

	var inn := m.building(4, 5, 7, 5, 3)
	var shop := m.building(19, 5, 7, 5, 3)
	var house := m.building(5, 17, 6, 5, 2)
	m.warps.append({"x": inn.x, "y": inn.y, "to": t.id + "_inn", "tx": 6, "ty": 8})
	m.warps.append({"x": shop.x, "y": shop.y, "to": t.id + "_shop", "tx": 6, "ty": 8})
	m.warps.append({"x": house.x, "y": house.y, "to": t.id + "_house", "tx": 5, "ty": 8})

	match t.decor:
		"well":
			m.set_tile(21, 15, "w")
		"water":
			m.rect(19, 15, 6, 4, "~")
			m.rect(19, 14, 6, 1, "B")
		"graves":
			m.rect(20, 15, 4, 3, "g")

	# Something in all that empty ground: without it a town is four buildings
	# standing in a field, which is what the first pass looked like. The fence
	# and bush tiles are painted on grass and tiles are opaque, so a dirt town
	# gets rock and spoil heaps instead of green stripes laid over the dirt.
	var grassy: bool = t.ground == "." or t.ground == ","
	if grassy:
		m.hline(4, 9, 15, "F")
		m.hline(19, 24, 20, "F")
		m.set_tile(4, 20, "%"); m.set_tile(25, 13, "%"); m.set_tile(6, 13, "%")
		if rng.randf() > 0.4:
			m.set_tile(18, 22, "%")
			m.set_tile(19, 22, "%")
	else:
		m.rect(4, 15, 3, 2, "r")
		m.rect(22, 19, 3, 2, "r")
		m.set_tile(6, 20, "r"); m.set_tile(25, 13, "r")

	m.set_tile(10, 13, "S")
	m.npcs.append({"x": 10, "y": 13, "sign": true, "lines": t.sign})
	# two of the three folk stand outside; the third keeps house
	# (9, 21) put them inside the house's bottom wall in all five towns -- the
	# audit caught it, which is exactly what the audit is for.
	var outside: Array = [Vector2i(17, 13), Vector2i(12, 20)]
	for i in mini(2, t.folk.size()):
		var f: Dictionary = t.folk[i]
		var n := {"x": outside[i].x, "y": outside[i].y, "look": f.look, "dir": f.dir, "lines": f.lines}
		if f.get("wander", false):
			n["wander"] = true
		m.npcs.append(n)

	var g: Vector2i = TOWN_GATE
	for y in range(h - 3, h):
		m.set_tile(g.x, y, "o")
	var site: Dictionary = sites.get(t.id, {"gate": Vector2i(20, 20)})
	var gate: Vector2i = site.gate
	m.warps.append({"x": g.x, "y": g.y, "to": "world", "tx": gate.x, "ty": gate.y + 1})
	m.start = Vector2i(g.x, g.y - 2)
	maps[t.id] = m

	_make_town_interiors(maps, t)


static func _make_town_interiors(maps: Dictionary, t: Dictionary) -> void:
	var tune := str(t.get("music", "town"))
	var inn := World.room(t.id + "_inn", 13, 10, t.id, 7, 11)
	inn.music = tune
	inn.rect(2, 3, 2, 2, "b"); inn.rect(5, 3, 2, 2, "b"); inn.rect(8, 3, 2, 2, "b")
	inn.set_tile(10, 6, "c"); inn.set_tile(11, 6, "c")
	inn.npcs.append({"x": 10, "y": 5, "look": "shopkeep", "dir": "down",
		"inn": t.inn, "lines": t.innkeep})
	maps[t.id + "_inn"] = inn

	var shop := World.room(t.id + "_shop", 13, 10, t.id, 22, 11)
	shop.music = tune
	shop.rect(3, 5, 7, 1, "c")
	shop.rect(2, 3, 1, 2, "p"); shop.rect(10, 3, 1, 2, "p")
	shop.npcs.append({"x": 6, "y": 4, "look": "shopkeep", "dir": "down",
		"shop": t.stock, "lines": t.shopkeep})
	maps[t.id + "_shop"] = shop

	var house := World.room(t.id + "_house", 11, 10, t.id, 7, 22)
	house.music = tune
	house.rect(2, 3, 2, 2, "b"); house.set_tile(6, 4, "t"); house.set_tile(8, 6, "p")
	if t.folk.size() >= 3:
		var f: Dictionary = t.folk[2]
		house.npcs.append({"x": 6, "y": 5, "look": f.look, "dir": "down", "lines": f.lines})
	house.chests.append({"x": 2, "y": 6, "item": t.chest, "id": t.id + "_h"})
	maps[t.id + "_house"] = house


# ---------------------------------------------------------------- dungeons --

static func _make_dungeon(maps: Dictionary, d: Dictionary) -> void:
	var floors: int = d.floors
	var rng := RandomNumberGenerator.new()
	rng.seed = d.seed
	var prev_exit := Vector2i.ZERO

	for i in floors:
		var last: bool = i == floors - 1
		var id := "%s%d" % [d.id, i + 1]
		var fw: int = F1_W - i * 4
		var fh: int = F1_H - i * 4
		var m := Maps.GameMap.new(id, fw, fh, "X")
		m.music = "cave" if i == 0 else "deep"
		m.region = d.region
		m.indoor = true

		# A chain of chambers from the bottom-left up to the far end, tunnelled
		# in order. Connectivity is guaranteed by construction, which is the
		# whole reason for generating caves this way rather than by noise.
		var pts: Array[Vector2i] = []
		var entry := F1_ENTRY if i == 0 else Vector2i(6, fh - 6)
		pts.append(entry)
		var n := 6 + i
		for k in range(1, n):
			var s := float(k) / float(n - 1)
			var px := int(lerp(float(entry.x), float(fw - 8), s) + sin(s * TAU + float(d.seed)) * fw * 0.16)
			var py := int(lerp(float(entry.y), 10.0, s) + cos(s * PI * 3.0 + float(i)) * fh * 0.10)
			pts.append(Vector2i(clampi(px, 5, fw - 6), clampi(py, 9, fh - 5)))
		var goal := Vector2i(fw / 2, 8)
		pts.append(goal)
		Maps.tunnel(m, pts, 2)

		# stairs up, or the mouth back onto the overworld
		if i == 0:
			var site: Dictionary = sites.get(d.id, {"gate": Vector2i(20, 20)})
			var gate: Vector2i = site.gate
			m.set_tile(entry.x, entry.y + 1, "C")
			m.warps.append({"x": entry.x, "y": entry.y + 1, "to": "world",
				"tx": gate.x, "ty": gate.y + 1})
		else:
			m.set_tile(entry.x, entry.y + 1, "*")
			m.warps.append({"x": entry.x, "y": entry.y + 1, "to": "%s%d" % [d.id, i],
				"tx": prev_exit.x, "ty": prev_exit.y + 1})

		# dead ends with something in them, hung off the middle of the chain
		var loot: Array = d.loot
		for k in mini(2, loot.size()):
			var from: Vector2i = pts[1 + ((k * 3) % maxi(1, pts.size() - 2))]
			var away := Vector2i(from.x + (7 if k % 2 == 0 else -7), from.y + (5 if k % 2 == 0 else -5))
			away = Vector2i(clampi(away.x, 4, fw - 5), clampi(away.y, 4, fh - 5))
			Maps.tunnel(m, [from, away], 1)
			m.chests.append({"x": away.x, "y": away.y,
				"item": loot[(i + k) % loot.size()], "id": "%s_%d%d" % [d.id, i, k]})

		if last:
			# The boss sits in a one-tile neck between the last chamber and the
			# alcove with the prize, so there is no walking round it.
			Maps.carve(m, goal.x, goal.y, 4)
			var bx := goal.x
			var by := goal.y - 5
			m.set_tile(bx, by, "D")
			m.set_tile(bx, by - 1, "D")
			Maps.carve(m, bx, by - 3, 1)
			m.boss = {"x": bx, "y": by, "id": d.boss, "flag": d.flag, "intro": d.intro}
			m.chests.append({"x": bx, "y": by - 3, "item": d.prize, "id": d.id + "_prize"})
		else:
			m.set_tile(goal.x, goal.y, "*")
			m.warps.append({"x": goal.x, "y": goal.y, "to": "%s%d" % [d.id, i + 2],
				"tx": 6, "ty": (F1_H - (i + 1) * 4) - 6})
			prev_exit = goal

		m.start = entry
		maps[id] = m
