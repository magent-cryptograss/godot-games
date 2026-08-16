class_name World
extends RefCounted
## Builds every map. All story text lives here and in Story.gd -- the engine
## never hard-codes a line, so rewriting the story touches no logic.

static var maps := {}

## Where the world generator put things. Published so the town, the caves and
## the tests do not have to hardcode coordinates that move whenever the world
## is regenerated or resized.
static var town_gate := Vector2i(20, 53)
static var cave_mouth := Vector2i(48, 10)


static func build_all() -> Dictionary:
	if not maps.is_empty():
		return maps
	maps = {}
	_world()
	_town()
	_interiors()
	_caves()
	Places.build_maps(maps)
	for k in maps:
		Maps.prerender(maps[k])
	# Anything saved from the map editor wins over the generated version.
	var overridden := MapIO.apply_overrides(maps)
	if overridden > 0:
		print("[world] %d map(s) loaded from %s" % [overridden, MapIO.dir_path()])
	return maps


# Value noise: a coarse random grid, smoothly interpolated.
static func _noise(w: int, h: int, cells: int, rng: RandomNumberGenerator) -> Callable:
	var gw := cells + 1
	var grid := []
	for i in gw * gw:
		grid.append(rng.randf())
	return func(x: int, y: int) -> float:
		var fx := float(x) / float(w) * cells
		var fy := float(y) / float(h) * cells
		var x0 := int(fx)
		var y0 := int(fy)
		var tx := fx - x0
		var ty := fy - y0
		tx = tx * tx * (3.0 - 2.0 * tx)
		ty = ty * ty * (3.0 - 2.0 * ty)
		var g := func(i: int, j: int) -> float:
			return grid[clampi(j, 0, cells) * gw + clampi(i, 0, cells)]
		var a: float = lerp(g.call(x0, y0), g.call(x0 + 1, y0), tx)
		var b: float = lerp(g.call(x0, y0 + 1), g.call(x0 + 1, y0 + 1), tx)
		return lerp(a, b, ty)


## The overworld. WORLD_W x WORLD_H tiles -- a hundred times the area of the
## first version, which means the landmarks have to scale with it or the whole
## thing is a very long walk between two interesting places.
const WORLD_W := 800
const WORLD_H := 640

static func _world() -> void:
	var w := WORLD_W
	var h := WORLD_H
	var m := Maps.GameMap.new("world", w, h, ".")
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260815

	# Noise cell counts scale with the map, so forests and ranges stay the same
	# size on screen instead of stretching into continents.
	# Feature size, not cell count, is what the eye reads. At w/11 the whole map
	# came out speckled -- a hundred small blobs rather than ranges and forests
	# you can navigate by.
	var cells_e := maxi(5, int(w / 30))
	var cells_m := maxi(5, int(w / 24))
	var cells_d := maxi(6, int(w / 7))
	var elev := _noise(w, h, cells_e, rng)
	var moist := _noise(w, h, cells_m, rng)
	var detail := _noise(w, h, cells_d, rng)

	for y in h:
		for x in w:
			var northness := 1.0 - float(y) / float(h)
			var e: float = elev.call(x, y) * 0.62 + northness * 0.55 + detail.call(x, y) * 0.1
			var mo: float = moist.call(x, y)
			var c := "."
			if e > 0.82: c = "^"
			elif e > 0.76: c = "r"
			elif mo < 0.22 and e < 0.42: c = "~"
			elif mo > 0.66: c = "T" if detail.call(x, y) > 0.5 else "P"
			elif mo > 0.55: c = ","
			elif mo < 0.34: c = "\""
			else: c = "f" if detail.call(x, y) > 0.86 else "."
			m.set_tile(x, y, c)

	# a hard border of peaks, so you cannot walk off the edge
	for x in w:
		for k in 2:
			m.set_tile(x, k, "^")
			m.set_tile(x, h - 1 - k, "^")
	for y in h:
		for k in 2:
			m.set_tile(k, y, "^")
			m.set_tile(w - 1 - k, y, "^")

	# several rivers rather than one, spaced down the map
	for river in 4:
		var ry := int(h * (0.24 + river * 0.17))
		for x in range(2, w - 2):
			ry += 1 if rng.randf() > 0.5 else -1
			ry = clampi(ry, int(h * (0.18 + river * 0.17)), int(h * (0.30 + river * 0.17)))
			m.set_tile(x, ry, "~")
			m.set_tile(x, ry + 1, "~")
			if rng.randf() > 0.6:
				m.set_tile(x, ry + 2, "~")

	var town := Vector2i(int(w * 0.14), int(h * 0.86))
	var cave := Vector2i(int(w * 0.62), int(h * 0.09))

	# Waypoints strung between town and the cave mouth, so the road is a journey
	# with things on it rather than a straight line across half a million tiles.
	var waypoints: Array = []
	var steps := 9
	for i in range(1, steps):
		var t := float(i) / float(steps)
		var wx := int(lerp(float(town.x), float(cave.x), t) + sin(t * 6.0) * w * 0.12)
		var wy := int(lerp(float(town.y), float(cave.y), t))
		waypoints.append(Vector2i(clampi(wx, 6, w - 7), clampi(wy, 6, h - 7)))

	# stamp the solid landmarks first, then carve roads through them
	m.rect(town.x - 4, town.y - 3, 9, 7, ".")
	m.building(town.x - 2, town.y - 3, 5, 4, 2)
	m.rect(cave.x - 2, cave.y - 1, 5, 2, "^")

	# The five other towns and five other dungeons go down here, while the map is
	# still all landmarks and no roads, and hand back the points the roads have
	# to reach.
	var anchors := Places.stamp(m)

	var prev := Vector2i(town.x, town.y + 1)
	for wp in waypoints:
		m.road(prev.x, prev.y, wp.x, wp.y)
		prev = wp
	m.road(prev.x, prev.y, cave.x, cave.y + 1)

	# A spur from the nearest point on the main road to every site. Roads cut
	# through anything, so this is also what guarantees each place is reachable
	# -- the audit checks it rather than trusting it.
	for a in anchors:
		var ap: Vector2i = a.p
		var best: Vector2i = waypoints[0]
		var best_d := 1 << 30
		for wp in waypoints:
			var wpv: Vector2i = wp
			var dd: int = absi(wpv.x - ap.x) + absi(wpv.y - ap.y)
			if dd < best_d:
				best_d = dd
				best = wpv
		m.road(best.x, best.y, ap.x, ap.y)

	m.set_tile(town.x, town.y, "o")
	m.warps.append({"x": town.x, "y": town.y, "to": "town", "tx": 15, "ty": 24})
	m.set_tile(cave.x, cave.y, "C")
	m.warps.append({"x": cave.x, "y": cave.y, "to": "cave1", "tx": 8, "ty": 24})
	town_gate = Vector2i(town.x, town.y + 1)
	cave_mouth = Vector2i(cave.x, cave.y + 1)

	# A clearing at every waypoint: a signpost, and often something in a chest.
	# These are what stop the road being empty.
	var chest_items := ["tonic", "tonic2", "rosin", "rosin2", "salve", "bread", "strings", "charm"]
	for i in waypoints.size():
		var wp: Vector2i = waypoints[i]
		m.rect(wp.x - 2, wp.y - 2, 5, 5, "o")
		m.set_tile(wp.x, wp.y - 2, "S")
		m.npcs.append({"x": wp.x, "y": wp.y - 2, "sign": true,
			"lines": _signpost(wp, town, cave)})
		if i % 2 == 0:
			m.chests.append({"x": wp.x + 1, "y": wp.y + 1,
				"item": chest_items[i % chest_items.size()], "id": "wp%d" % i})

	# and chests scattered off the road, for anyone who wanders
	var cr := RandomNumberGenerator.new()
	cr.seed = 99001
	var placed := 0
	var tries := 0
	while placed < 24 and tries < 4000:
		tries += 1
		var cx := cr.randi_range(6, w - 7)
		var cy := cr.randi_range(6, h - 7)
		if Maps.is_solid(m.get_tile(cx, cy)):
			continue
		var too_close := false
		for k in Places.sites:
			var g: Vector2i = Places.sites[k].gate
			if absi(g.x - cx) + absi(g.y - cy) < 14:
				too_close = true
				break
		if too_close:
			continue
		m.rect(cx - 1, cy - 1, 3, 3, "f")
		m.chests.append({"x": cx, "y": cy,
			"item": chest_items[placed % chest_items.size()], "id": "wild%d" % placed})
		placed += 1

	m.region = "meadow"
	m.start = Vector2i(town.x, town.y + 3)
	maps["world"] = m


## What a roadside post says: the three nearest places by name, which way, and
## how far. Written at generation time from where things actually ended up, so
## a sign cannot end up pointing at a town that moved.
static func _signpost(at: Vector2i, town: Vector2i, cave: Vector2i) -> Array:
	var all: Array = [
		{"name": "Cane Ridge", "at": town},
		{"name": "the cave", "at": cave},
	]
	for id in Places.sites:
		var site: Dictionary = Places.sites[id]
		all.append({"name": site.name, "at": site.gate})
	for e in all:
		var d: Vector2i = e.at - at
		e["dist"] = absi(d.x) + absi(d.y)
	all.sort_custom(func(a, b): return a.dist < b.dist)

	var lines: Array = ["A post at the roadside, with boards nailed across it."]
	var body := ""
	for i in mini(3, all.size()):
		var e: Dictionary = all[i]
		body += "%s -- %s, %d\n" % [
			str(e.name).to_upper(), Guide.compass(at, e.at).to_upper(), int(e.dist)]
	lines.append(body.strip_edges())
	return lines


static func _town() -> void:
	var w := 30
	var h := 26
	var m := Maps.GameMap.new("town", w, h, ".")
	m.music = "town"
	m.region = ""
	for y in h:
		for x in w:
			m.set_tile(x, y, "f" if Maps.hash2(x + 900, y + 900) > 0.93 else ".")
	m.rect(0, 0, w, 2, "T"); m.rect(0, h - 2, w, 2, "T")
	m.rect(0, 0, 2, h, "T"); m.rect(w - 2, 0, 2, h, "T")
	m.vline(3, h - 3, 15, "o"); m.vline(3, h - 3, 16, "o")
	m.hline(4, w - 4, 12, "o")

	var inn := m.building(5, 5, 7, 5, 3)
	var shop := m.building(19, 5, 7, 5, 3)
	var h1 := m.building(5, 16, 6, 5, 2)
	var h2 := m.building(20, 16, 6, 5, 3)
	m.warps.append({"x": inn.x, "y": inn.y, "to": "inn", "tx": 6, "ty": 8})
	m.warps.append({"x": shop.x, "y": shop.y, "to": "shop", "tx": 6, "ty": 8})
	m.warps.append({"x": h1.x, "y": h1.y, "to": "house1", "tx": 5, "ty": 8})
	m.warps.append({"x": h2.x, "y": h2.y, "to": "house2", "tx": 5, "ty": 8})
	m.set_tile(13, 14, "w")
	m.set_tile(9, 12, "S")
	m.rect(24, 21, 3, 3, "g")
	m.set_tile(15, h - 3, "o"); m.set_tile(15, h - 2, "o"); m.set_tile(15, h - 1, "o")
	m.warps.append({"x": 15, "y": h - 1, "to": "world", "tx": town_gate.x, "ty": town_gate.y})

	m.npcs.append({"x": 9, "y": 12, "sign": true, "lines": Story.SIGN_TOWN})
	m.npcs.append({"x": 12, "y": 15, "look": "oldman", "dir": "down", "lines": Story.OLDMAN})
	m.npcs.append({"x": 20, "y": 13, "look": "kid", "dir": "left", "wander": true, "lines": Story.KID})
	m.npcs.append({"x": 6, "y": 23, "look": "woman", "dir": "right", "lines": Story.WOMAN})
	m.npcs.append({"x": 24, "y": 12, "look": "drifter", "dir": "down", "lines": Story.DRIFTER})
	m.start = Vector2i(15, 22)
	maps["town"] = m


static func room(id: String, w: int, h: int, back: String, bx: int, by: int, door_x: int = -1) -> Maps.GameMap:
	var m := Maps.GameMap.new(id, w, h, "_")
	m.indoor = true
	m.music = "town"
	m.region = ""
	m.rect(0, 0, w, 1, "#"); m.rect(0, h - 1, w, 1, "#")
	m.rect(0, 0, 1, h, "#"); m.rect(w - 1, 0, 1, h, "#")
	m.rect(0, 1, w, 1, "#")
	var dx := door_x if door_x >= 0 else (w >> 1)
	m.set_tile(dx, h - 1, "d")
	m.warps.append({"x": dx, "y": h - 1, "to": back, "tx": bx, "ty": by})
	m.start = Vector2i(dx, h - 2)
	return m


static func _interiors() -> void:
	var inn := World.room("inn", 13, 10, "town", 8, 10)
	inn.rect(2, 3, 2, 2, "b"); inn.rect(5, 3, 2, 2, "b"); inn.rect(8, 3, 2, 2, "b")
	inn.set_tile(10, 6, "c"); inn.set_tile(11, 6, "c")
	inn.npcs.append({"x": 10, "y": 5, "look": "shopkeep", "dir": "down", "inn": 30, "lines": Story.INNKEEP})
	maps["inn"] = inn

	var shop := World.room("shop", 13, 10, "town", 22, 10)
	shop.rect(3, 5, 7, 1, "c")
	shop.rect(2, 3, 1, 2, "p"); shop.rect(10, 3, 1, 2, "p")
	shop.npcs.append({"x": 6, "y": 4, "look": "shopkeep", "dir": "down",
		"shop": ["tonic", "tonic2", "rosin", "rosin2", "salve", "bread", "strings", "charm"],
		"lines": Story.SHOPKEEP})
	maps["shop"] = shop

	var h1 := World.room("house1", 11, 10, "town", 7, 21)
	h1.rect(2, 3, 2, 2, "b"); h1.set_tile(6, 4, "t"); h1.set_tile(8, 6, "p")
	h1.npcs.append({"x": 6, "y": 5, "look": "preacher", "dir": "down", "lines": Story.PREACHER})
	h1.chests.append({"x": 2, "y": 6, "item": "tonic", "id": "h1a"})
	maps["house1"] = h1

	var h2 := World.room("house2", 11, 10, "town", 23, 21)
	h2.set_tile(3, 4, "t"); h2.set_tile(7, 4, "t"); h2.rect(2, 6, 1, 2, "p")
	h2.npcs.append({"x": 5, "y": 5, "look": "miner", "dir": "down", "lines": Story.MINER})
	h2.chests.append({"x": 8, "y": 6, "item": "charm", "id": "h2a"})
	maps["house2"] = h2


static func _caves() -> void:
	var c1 := Maps.GameMap.new("cave1", 40, 30, "X")
	c1.music = "cave"; c1.region = "cave"; c1.indoor = true
	Maps.tunnel(c1, [Vector2i(8, 24), Vector2i(8, 18), Vector2i(14, 16), Vector2i(14, 9),
		Vector2i(22, 8), Vector2i(28, 12), Vector2i(30, 20), Vector2i(22, 22),
		Vector2i(16, 24), Vector2i(33, 7)], 2)
	c1.set_tile(8, 25, "C")
	c1.warps.append({"x": 8, "y": 25, "to": "world", "tx": cave_mouth.x, "ty": cave_mouth.y})
	c1.set_tile(33, 7, "*")
	c1.warps.append({"x": 33, "y": 7, "to": "cave2", "tx": 6, "ty": 22})
	c1.chests.append({"x": 22, "y": 8, "item": "rosin2", "id": "c1a"})
	c1.chests.append({"x": 30, "y": 20, "item": "tonic2", "id": "c1b"})
	c1.start = Vector2i(8, 24)
	maps["cave1"] = c1

	var c2 := Maps.GameMap.new("cave2", 34, 26, "X")
	c2.music = "cave"; c2.region = "deep"; c2.indoor = true
	Maps.tunnel(c2, [Vector2i(6, 22), Vector2i(6, 16), Vector2i(12, 13), Vector2i(20, 15),
		Vector2i(24, 9), Vector2i(17, 6)], 2)
	Maps.carve(c2, 17, 6, 5)
	Maps.carve(c2, 17, 3, 2)
	c2.set_tile(6, 23, "*")
	c2.warps.append({"x": 6, "y": 23, "to": "cave1", "tx": 33, "ty": 8})
	c2.chests.append({"x": 24, "y": 9, "item": "strings", "id": "c2a"})
	c2.boss = {"x": 17, "y": 5, "id": "gravebell", "flag": "gravebell", "intro": Story.BOSS_GRAVEBELL}
	c2.set_tile(17, 2, "*")
	c2.warps.append({"x": 17, "y": 2, "to": "cave3", "tx": 5, "ty": 20,
		"need_flag": "boss_gravebell", "blocked": Story.GATE_BELL})
	c2.start = Vector2i(6, 22)
	maps["cave2"] = c2

	var c3 := Maps.GameMap.new("cave3", 32, 24, "X")
	c3.music = "cave"; c3.region = "deep"; c3.indoor = true
	Maps.tunnel(c3, [Vector2i(5, 20), Vector2i(5, 14), Vector2i(11, 11), Vector2i(19, 13),
		Vector2i(25, 8), Vector2i(16, 5)], 2)
	Maps.carve(c3, 16, 5, 5)
	Maps.carve(c3, 16, 2, 2)
	c3.set_tile(5, 21, "*")
	c3.warps.append({"x": 5, "y": 21, "to": "cave2", "tx": 17, "ty": 3})
	c3.chests.append({"x": 25, "y": 8, "item": "tonic2", "id": "c3a"})
	c3.chests.append({"x": 11, "y": 11, "item": "rosin2", "id": "c3b"})
	c3.boss = {"x": 16, "y": 4, "id": "conductor", "flag": "conductor", "intro": Story.BOSS_CONDUCTOR}
	c3.set_tile(16, 1, "*")
	c3.warps.append({"x": 16, "y": 1, "to": "final", "tx": 10, "ty": 17,
		"need_flag": "boss_conductor", "blocked": Story.GATE_CONDUCTOR})
	c3.start = Vector2i(5, 20)
	maps["cave3"] = c3

	var f := Maps.GameMap.new("final", 21, 20, "X")
	f.music = "cave"; f.region = "deep"; f.indoor = true
	for p in [Vector2i(10, 17), Vector2i(10, 15), Vector2i(10, 13)]:
		Maps.carve(f, p.x, p.y, 2)
	Maps.carve(f, 10, 9, 6)
	for y in range(3, 19):
		for x in range(2, 19):
			if f.get_tile(x, y) == "D":
				f.set_tile(x, y, "*")
	f.set_tile(10, 18, "D")
	f.warps.append({"x": 10, "y": 18, "to": "cave3", "tx": 16, "ty": 2})
	f.boss = {"x": 10, "y": 7, "id": "quiet", "flag": "quiet", "intro": Story.BOSS_QUIET}
	f.start = Vector2i(10, 17)
	maps["final"] = f
