extends RefCounted
## The things you come across between one place and the next.
##
## The overworld measures 822 screenfuls of walkable ground and, before this,
## held 54 things worth stopping for -- one every fifteen screens. Big and empty
## are easy to confuse while you are building a world and impossible to confuse
## while you are walking it.
##
## So: small scenes, stamped across the map wherever there is room for them. A
## well. A row of headstones behind a rail. Somebody sat by a fire who will tell
## you what the road ahead is like. None of them are puzzles and most of them
## give you nothing; that is deliberate. A world where every object is a reward
## is a checklist. What makes somewhere feel inhabited is the things that are
## simply there.
##
## Two rules everything here obeys:
##
##   Nothing is placed where you cannot go. Two thirds of the overworld is
##   walled off behind mountains and rivers and always has been, so scattering
##   at random would put two of every three scenes somewhere nobody will ever
##   stand. Placement runs off a flood fill from the town gate.
##
##   Nothing encloses anything. Fences have gateways, walls have gaps, and a
##   chest is never inside a ring of boulders. The audit checks this, but it is
##   cheaper to build things that cannot fail than to detect the failures.

const TREE_KINDS := ["T", "P"]

## Where each scene ended up: [{kind, at}]. Kept because a generator that places
## three hundred things nobody has coordinates for cannot be photographed, and a
## scene nobody has looked at is a scene nobody knows is broken. Hunting for a
## scene by its tiles does not work -- the world was already full of boulders
## long before anything put a ring of them anywhere on purpose.
static var placed_at: Array = []


# ---------------------------------------------------------------- placement --

## Scatter the wayside across a finished map.
##
## Runs last, after roads and plateaus: roads have right of way and a plateau
## needs a large clear site, so both would lose a coin toss against a well.
static func scatter(m: Maps.GameMap, avoid: Array) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 84109

	var reach := _reachable(m)

	# Ground already spoken for. Checking the tile characters is not enough:
	# several scenes leave soft ground inside them on purpose -- the grazing
	# inside a paddock, the floor of a stone ring -- and soft ground is exactly
	# what the next scene goes looking for. That is how a boulder ended up on top
	# of the chest inside a cairn.
	# While the flood fill is here: a handful of the chests scattered before this
	# ran landed in country nobody can walk to. They were placed on any square
	# that was not solid, and two thirds of the overworld is not solid and not
	# reachable either. A chest nobody can open is not content.
	var stranded := 0
	var keep: Array = []
	for c in m.chests:
		if reach[int(c.y) * m.w + int(c.x)] == 1:
			keep.append(c)
		else:
			stranded += 1
	if stranded > 0:
		m.chests = keep
		print("[wayside] dropped %d chest(s) nobody could reach" % stranded)

	var claimed := PackedByteArray()
	claimed.resize(m.w * m.h)
	for c in m.chests:
		_claim(claimed, m, Vector2i(int(c.x), int(c.y)), 1)
	for n in m.npcs:
		_claim(claimed, m, Vector2i(int(n.x), int(n.y)), 1)

	placed_at.clear()
	var counts := {}
	var placed := 0
	var tries := 0

	# One scene every two or three screens. A screen is about 17x13 tiles, so at
	# 300 scenes over 822 reachable screens you meet something roughly as often
	# as you would meet a fence walking across country -- often enough that the
	# walk has a rhythm, rare enough that it is still a walk.
	var want := 300
	while placed < want and tries < 60000:
		tries += 1
		var x := rng.randi_range(8, m.w - 9)
		var y := rng.randi_range(8, m.h - 9)
		if reach[y * m.w + x] == 0:
			continue
		if _too_near(x, y, avoid, 14):
			continue
		var kind: String = KINDS[rng.randi() % KINDS.size()]
		var foot: Rect2i = _stamp(m, kind, x, y, rng, reach, claimed)
		if foot.size.x == 0:
			continue
		for cy in range(foot.position.y, foot.end.y):
			for cx in range(foot.position.x, foot.end.x):
				_claim(claimed, m, Vector2i(cx, cy), 0)
				# An object tile bakes grass into its own background, so a
				# headstone standing on dry ground is a green square with a stone
				# in it. Green the whole footprint and the seam disappears --
				# ground tiles blend into their neighbours by rank, so the patch
				# feathers out into whatever the country was doing.
				if m.get_tile(cx, cy) == "\"":
					m.set_tile(cx, cy, ".")
		counts[kind] = int(counts.get(kind, 0)) + 1
		placed_at.append({"kind": kind, "at": Vector2i(x, y)})
		placed += 1

	var walkers := _travellers(m, rng, reach, avoid)
	print("[wayside] %d scenes, %d people on the roads" % [placed, walkers])
	return counts


## What can be stamped. Weighted by repetition rather than by a weight field --
## the list is short enough to read, and reading it is how you notice that half
## the world is graveyards.
const KINDS := [
	"well", "well",
	"graves", "graves",
	"cairn",
	"stones",
	"camp", "camp",
	"orchard",
	"ruin", "ruin",
	"paddock",
	"fenceline", "fenceline",
	"shrine",
	"copse", "copse",
	"boulders", "boulders",
	"flowers", "flowers",
	"picker",
	"pond",
]


## Is every square in this box open, soft ground we are allowed to build on?
##
## Roads are not soft, which is what keeps the wayside off them without a single
## special case: the check that finds somewhere to build is the same check that
## refuses to build across the only way through.
static func _clear(m: Maps.GameMap, x: int, y: int, w: int, h: int,
		reach: PackedByteArray, claimed: PackedByteArray) -> bool:
	if x < 2 or y < 2 or x + w >= m.w - 2 or y + h >= m.h - 2:
		return false
	for dy in h:
		for dx in w:
			var i := (y + dy) * m.w + x + dx
			var ch := m.get_tile(x + dx, y + dy)
			if ch != "." and ch != "f" and ch != "\"" and ch != ",":
				return false
			# and it has to be ground somebody can actually get to, or the scene
			# is built for nobody
			if reach[i] == 0:
				return false
			if claimed[i] == 1:
				return false
	return true


## Mark a square, and optionally a border around it, as spoken for.
static func _claim(claimed: PackedByteArray, m: Maps.GameMap, p: Vector2i, pad: int) -> void:
	for dy in range(-pad, pad + 1):
		for dx in range(-pad, pad + 1):
			var x := p.x + dx
			var y := p.y + dy
			if x < 0 or y < 0 or x >= m.w or y >= m.h:
				continue
			claimed[y * m.w + x] = 1


static func _too_near(x: int, y: int, avoid: Array, d: int) -> bool:
	for p in avoid:
		var v: Vector2i = p
		if absi(v.x - x) + absi(v.y - y) < d:
			return true
	return false


## Every object tile draws its own background, and outdoor objects draw grass.
## So laying a patch of dry ground and then standing headstones on it gives you
## green squares under every stone -- the scene has to keep plain grass under
## anything that brings its own. Table and barrel are indoor tiles with a
## floorboard background and have no business outdoors at all.
##
## Build one scene, and hand back the ground it takes up so the next one can be
## kept off it. An empty rect means it would not fit; the map is left alone.
static func _stamp(m: Maps.GameMap, kind: String, x: int, y: int,
		rng: RandomNumberGenerator, reach: PackedByteArray,
		claimed: PackedByteArray) -> Rect2i:
	match kind:
		"well":
			if not _clear(m, x - 1, y - 1, 3, 3, reach, claimed):
				return Rect2i()
			m.rect(x - 1, y - 1, 3, 3, "o")
			m.set_tile(x, y, "w")
			return Rect2i(x - 1, y - 1, 3, 3)

		"graves":
			# a burying ground: stones in rows, on ground gone dry, and a rail
			# along the north side only -- a fence you can walk round
			var w := rng.randi_range(4, 6)
			var h := rng.randi_range(3, 4)
			if not _clear(m, x, y, w, h + 1, reach, claimed):
				return Rect2i()
			for gy in h:
				for gx in w:
					if gx % 2 == 0 and gy % 2 == 0:
						m.set_tile(x + gx, y + 1 + gy, "g")
			for gx in w:
				m.set_tile(x + gx, y, "F")
			return Rect2i(x, y, w, h + 1)

		"cairn":
			# a ring of stones with a gap in the south side, and something left
			# in the middle of it. The gap is the whole point: a chest inside a
			# closed ring is a promise the world cannot keep.
			if not _clear(m, x - 2, y - 2, 5, 5, reach, claimed):
				return Rect2i()
			for k in 5:
				m.set_tile(x - 2 + k, y - 2, "r")
				m.set_tile(x - 2, y - 2 + k, "r")
				m.set_tile(x + 2, y - 2 + k, "r")
			m.chests.append({"x": x, "y": y, "item": _prize(rng),
				"id": "cairn%d_%d" % [x, y]})
			return Rect2i(x - 2, y - 2, 5, 5)

		"stones":
			# standing stones in a line, on ground that has gone thin round them
			if not _clear(m, x - 3, y - 1, 7, 3, reach, claimed):
				return Rect2i()
			for k in 4:
				m.set_tile(x - 3 + k * 2, y, "r")
			return Rect2i(x - 3, y - 1, 7, 3)

		"camp":
			# somebody stopped for the night, with a fire ring and their gear
			if not _clear(m, x - 2, y - 1, 5, 4, reach, claimed):
				return Rect2i()
			# a fire, somebody sat at it, and a stone to sit on
			m.set_tile(x, y, "e")
			if rng.randf() < 0.6:
				m.set_tile(x - 2, y + 1, "r")
			m.npcs.append(_voice(rng, x + 1, y, "left"))
			return Rect2i(x - 2, y - 1, 5, 4)

		"orchard":
			# planted rows, wide enough to walk between, and windfalls at the end
			var ow := rng.randi_range(5, 8)
			var oh := rng.randi_range(4, 6)
			if not _clear(m, x, y, ow + 1, oh + 1, reach, claimed):
				return Rect2i()
			for gy in range(0, oh, 2):
				for gx in range(0, ow, 2):
					m.set_tile(x + gx, y + gy, "P")
			m.chests.append({"x": x + ow, "y": y + oh, "item": _prize(rng),
				"id": "orch%d_%d" % [x, y]})
			return Rect2i(x, y, ow + 1, oh + 1)

		"ruin":
			# a cabin nobody has lived in for a long time: two walls standing,
			# the floor still there, the rest gone back to grass
			var rw := rng.randi_range(4, 6)
			var rh := rng.randi_range(3, 4)
			if not _clear(m, x, y, rw + 1, rh + 1, reach, claimed):
				return Rect2i()
			# Walls all the way round, then knocked about. Two clean walls and a
			# solid floor read as a brown rug with a grey corner on it -- the
			# thing that says "ruin" is the gaps, and a floor with grass coming up
			# through it. Whole walls and an unbroken floor say "building site".
			m.rect(x, y, rw, rh, "_")
			for gx in rw:
				m.set_tile(x + gx, y, "#")
				m.set_tile(x + gx, y + rh - 1, "#")
			for gy in rh:
				m.set_tile(x, y + gy, "#")
				m.set_tile(x + rw - 1, y + gy, "#")
			for gy in rh:
				for gx in rw:
					var edge: bool = gx == 0 or gy == 0 or gx == rw - 1 or gy == rh - 1
					if edge and rng.randf() < 0.42:
						m.set_tile(x + gx, y + gy, "\"")     # fallen, gone to grass
					elif not edge and rng.randf() < 0.22:
						m.set_tile(x + gx, y + gy, ".")      # floor rotted through
			# and one certain way in, so the inside is never sealed by chance
			m.set_tile(x + int(rw / 2), y + rh - 1, "_")
			# Inside, on sound floor. This used to sit in the bottom-right corner,
			# which was open ground back when the ruin had only two walls and
			# became masonry the moment it had four.
			if rng.randf() < 0.4:
				var kx := x + rw - 2
				var ky := y + rh - 2
				m.set_tile(kx, ky, "_")
				m.chests.append({"x": kx, "y": ky,
					"item": _prize(rng), "id": "ruin%d_%d" % [x, y]})
			return Rect2i(x, y, rw + 1, rh + 1)

		"paddock":
			# a rail fence round some rough grazing, with a gateway in the near
			# side so it is an enclosure rather than a trap
			var pw := rng.randi_range(6, 9)
			var ph := rng.randi_range(4, 6)
			if not _clear(m, x, y, pw + 1, ph + 1, reach, claimed):
				return Rect2i()
			m.rect(x, y, pw, ph, ",")
			for gx in pw:
				m.set_tile(x + gx, y, "F")
				m.set_tile(x + gx, y + ph - 1, "F")
			for gy in ph:
				m.set_tile(x, y + gy, "F")
				m.set_tile(x + pw - 1, y + gy, "F")
			m.set_tile(x + int(pw / 2), y + ph - 1, ",")
			return Rect2i(x, y, pw + 1, ph + 1)

		"fenceline":
			# A field boundary running across open country, with a gap where the
			# gate used to be. Half of what makes farmland look farmed is the
			# lines somebody drew on it a hundred years ago.
			var fl := rng.randi_range(7, 13)
			var vertical := rng.randf() < 0.4
			var bw: int = 3 if vertical else fl
			var bh: int = fl if vertical else 3
			if not _clear(m, x - 1, y - 1, bw, bh, reach, claimed):
				return Rect2i()
			var gap := rng.randi_range(2, fl - 3)
			for k in fl:
				if k == gap:
					continue
				if vertical:
					m.set_tile(x, y - 1 + k, "F")
				else:
					m.set_tile(x - 1 + k, y, "F")
			return Rect2i(x - 1, y - 1, bw, bh)

		"shrine":
			# a marker at the roadside with a stone beside it
			if not _clear(m, x - 1, y - 1, 3, 3, reach, claimed):
				return Rect2i()
			m.rect(x - 1, y - 1, 3, 3, "o")
			m.set_tile(x, y - 1, "S")
			m.npcs.append({"x": x, "y": y - 1, "sign": true,
				"lines": SHRINE_LINES[rng.randi() % SHRINE_LINES.size()]})
			m.set_tile(x + 1, y, "g")
			return Rect2i(x - 1, y - 1, 3, 3)

		"copse":
			# a stand of trees on its own in open country, which is what makes it
			# a landmark rather than the edge of the forest
			if not _clear(m, x - 2, y - 2, 5, 5, reach, claimed):
				return Rect2i()
			for k in rng.randi_range(4, 9):
				m.set_tile(x + rng.randi_range(-2, 2), y + rng.randi_range(-2, 2),
					TREE_KINDS[rng.randi() % 2])
			return Rect2i(x - 2, y - 2, 5, 5)

		"boulders":
			if not _clear(m, x - 2, y - 2, 5, 5, reach, claimed):
				return Rect2i()
			for k in rng.randi_range(3, 6):
				m.set_tile(x + rng.randi_range(-2, 2), y + rng.randi_range(-2, 2), "r")
			return Rect2i(x - 2, y - 2, 5, 5)

		"flowers":
			# a meadow in bloom. Nothing happens here at all, and a world with
			# nothing in it but consequences is exhausting to walk across.
			var fw := rng.randi_range(4, 8)
			var fh := rng.randi_range(3, 6)
			if not _clear(m, x, y, fw + 1, fh + 1, reach, claimed):
				return Rect2i()
			for gy in fh:
				for gx in fw:
					if rng.randf() < 0.75:
						m.set_tile(x + gx, y + gy, "f")
			return Rect2i(x, y, fw + 1, fh + 1)

		"picker":
			# somebody out on their own with an instrument, which in this world is
			# the most ordinary thing a person can be doing
			if not _clear(m, x - 1, y - 1, 3, 3, reach, claimed):
				return Rect2i()
			m.set_tile(x, y + 1, "r")
			m.npcs.append(_picker(rng, x, y))
			return Rect2i(x - 1, y - 1, 3, 3)

		"pond":
			# a pool with a soft edge. Water is solid, so this is a thing to walk
			# round -- small enough that walking round it is a moment, not a trek.
			if not _clear(m, x - 2, y - 2, 5, 5, reach, claimed):
				return Rect2i()
			m.rect(x - 1, y - 1, 3, 3, "~")
			m.set_tile(x - 1, y - 1, ",")
			m.set_tile(x + 1, y - 1, ",")
			m.set_tile(x - 1, y + 1, ",")
			m.set_tile(x + 1, y + 1, ",")
			return Rect2i(x - 2, y - 2, 5, 5)

	return Rect2i()


static func _prize(rng: RandomNumberGenerator) -> String:
	var items := ["tonic", "tonic2", "rosin", "rosin2", "salve", "bread",
		"strings", "charm"]
	return items[rng.randi() % items.size()]


# ------------------------------------------------------------------- people --

## Somebody walking the roads. They stand just off the stone rather than on it,
## so a line of travellers never becomes a roadblock.
static func _travellers(m: Maps.GameMap, rng: RandomNumberGenerator,
		reach: PackedByteArray, avoid: Array) -> int:
	var road: Array[Vector2i] = []
	for y in range(4, m.h - 4):
		for x in range(4, m.w - 4):
			# "=" is the road. "o" is laid stone, which the world only uses for
			# the clearings at the waypoints -- lining those with travellers put
			# everybody in eight small crowds and left the roads deserted.
			if m.get_tile(x, y) == "=" and reach[y * m.w + x] == 1:
				road.append(Vector2i(x, y))
	if road.is_empty():
		return 0

	# Walk the road once rather than throwing darts at it. Drawing at random with
	# replacement and rejecting anything too near an earlier walker gets slower
	# and slower as the road fills, and gives up at about half the number asked
	# for -- not because the room ran out, but because the dice did.
	road.shuffle()
	var placed := 0
	var want := 90
	var put: Array[Vector2i] = []
	for p in road:
		if placed >= want:
			break
		var here: Vector2i = p
		if _too_near(here.x, here.y, avoid, 10):
			continue
		# not on top of one another: three people bunched round one signpost
		# reads as a bug, not as a crowd
		var crowded := false
		for q in put:
			var v: Vector2i = q
			if absi(v.x - here.x) + absi(v.y - here.y) < 9:
				crowded = true
				break
		if crowded:
			continue
		# beside the road, on ground, with nobody already standing there
		var spot := Vector2i(-1, -1)
		for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q2: Vector2i = here + step
			var ch := m.get_tile(q2.x, q2.y)
			if ch != "." and ch != "f" and ch != "\"" and ch != ",":
				continue
			if _occupied(m, q2):
				continue
			spot = q2
			break
		if spot.x < 0:
			continue
		put.append(here)
		m.npcs.append(_voice(rng, spot.x, spot.y, "down"))
		placed += 1
	return placed


static func _occupied(m: Maps.GameMap, p: Vector2i) -> bool:
	for n in m.npcs:
		if int(n.x) == p.x and int(n.y) == p.y:
			return true
	for c in m.chests:
		if int(c.x) == p.x and int(c.y) == p.y:
			return true
	return false


static func _voice(rng: RandomNumberGenerator, x: int, y: int, dir: String) -> Dictionary:
	var v: Dictionary = VOICES[rng.randi() % VOICES.size()]
	return {"x": x, "y": y, "look": v.look, "dir": dir,
		"wander": rng.randf() < 0.3, "lines": v.lines}


## A picker names a tune, and the tune is one the game actually plays. Naming a
## piece nobody will ever hear is worldbuilding; naming one you will walk into an
## hour later is a world.
static func _picker(rng: RandomNumberGenerator, x: int, y: int) -> Dictionary:
	var titles: Array = Tunes.TITLES.values()
	var tune: String = titles[rng.randi() % titles.size()]
	var line: String = PICKER_LINES[rng.randi() % PICKER_LINES.size()]
	var looks := ["oldman", "drifter", "woman", "girl", "miner", "smith", "kid"]
	return {"x": x, "y": y, "look": looks[rng.randi() % looks.size()], "dir": "down",
		"lines": [line % tune, PICKER_TAILS[rng.randi() % PICKER_TAILS.size()]]}


# -------------------------------------------------------------------- reach --

## Everywhere you can walk to from the town gate, by the same rules you walk by.
##
## A flat byte buffer rather than a dictionary of Vector2i: half a million tiles
## is a lot of objects to allocate for a question this simple.
static func _reachable(m: Maps.GameMap) -> PackedByteArray:
	var seen := PackedByteArray()
	seen.resize(m.w * m.h)
	var stack: Array[Vector2i] = [World.town_gate]
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		if p.x < 1 or p.y < 1 or p.x >= m.w - 1 or p.y >= m.h - 1:
			continue
		var i := p.y * m.w + p.x
		if seen[i] == 1:
			continue
		if Maps.is_solid(m.get_tile(p.x, p.y)):
			continue
		seen[i] = 1
		var here := m.get_tile(p.x, p.y)
		for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = p + step
			if Maps.levels_connect(here, m.get_tile(n.x, n.y)):
				stack.append(n)
	return seen


# -------------------------------------------------------------------- words --
#
# People say ordinary things. Nobody out here is a quest, and none of them have
# been waiting for you -- that is what makes the road feel like somewhere other
# people live rather than a corridor with attendants in it.

const VOICES := [
	{"look": "drifter", "lines": [
		"Long way between anywhere out here.",
		"Suits me most days."]},
	{"look": "oldman", "lines": [
		"Rain coming. My knee has been right about it since before you were born."]},
	{"look": "woman", "lines": [
		"Mind the low ground past the second river. It takes your boots."]},
	{"look": "kid", "lines": [
		"I walked all the way to the top of that rock once.",
		"There was nothing up there. It was great."]},
	{"look": "miner", "lines": [
		"Every hole in this country has something in it. Not always something you want."]},
	{"look": "smith", "lines": [
		"Bring me anything with a crack in it and I will tell you if it is worth mending.",
		"Usually it is not."]},
	{"look": "preacher", "lines": [
		"Walk in daylight where you can.",
		"That is not scripture. That is just sense."]},
	{"look": "girl", "lines": [
		"My sister says there is nothing to the west. My sister has never been west."]},
	{"look": "ferry", "lines": [
		"Water is up. Water is always up now."]},
	{"look": "miller", "lines": [
		"Wheel turns, flour comes out, and I stand here. It is a life."]},
	{"look": "widow", "lines": [
		"I know that face. Halloway's, about the eyes.",
		"She would be pleased and she would never have said so."]},
	{"look": "shopkeep", "lines": [
		"Buy before the hills, not after. Prices climb faster than the road does."]},
	{"look": "drifter", "lines": [
		"You hear it too, then. Everybody says they do not and then they stop and listen."]},
	{"look": "oldman", "lines": [
		"There were more of us on this road once.",
		"Same road. Fewer of us."]},
	{"look": "kid", "lines": [
		"Are you going somewhere? Can I come? No? All right."]},
	{"look": "woman", "lines": [
		"If a thing on the road will not look at you, do not make it."]},
	{"look": "miner", "lines": [
		"Deep places are colder than they ought to be. Not damp. Cold."]},
	{"look": "drifter", "lines": [
		"Ate the last of my bread this morning and have been cheerful ever since. Cannot explain it."]},
	{"look": "smith", "lines": [
		"Strings go dead in wet weather. Everything goes dead in wet weather."]},
	{"look": "girl", "lines": [
		"There is a stone circle out east. We are not supposed to go.",
		"We go."]},
	{"look": "preacher", "lines": [
		"Something is out of tune in the world and everybody has decided it is the weather."]},
	{"look": "widow", "lines": [
		"Do not sleep in the burying grounds. It is not the dead. It is the damp."]},
	{"look": "oldman", "lines": [
		"That plateau yonder -- steps cut into the side, north face.",
		"Somebody cut them. Nobody remembers who."]},
	{"look": "ferry", "lines": [
		"You want across, you walk to a bridge like everybody else."]},
	{"look": "miller", "lines": [
		"Orchards out this way are nobody's now. Take what you like."]},
	{"look": "kid", "lines": [
		"I am not lost. I am waiting."]},
	{"look": "woman", "lines": [
		"Careful in the tall grass. Things live in it and they are not shy."]},
	{"look": "shopkeep", "lines": [
		"Everything I have is on my back and half of it is other people's."]},
	{"look": "drifter", "lines": [
		"Been walking since the spring. Have not decided where to yet."]},
	{"look": "miner", "lines": [
		"Take a light. Take two. The second one is for when you drop the first."]},
	{"look": "preacher", "lines": [
		"I have buried four this season and not one of them was old."]},
	{"look": "smith", "lines": [
		"You play? Then you will know -- it is not the loud parts that are hard."]},
	{"look": "girl", "lines": [
		"Mama says do not talk to strangers.",
		"You do not look strange. You look tired."]},
	{"look": "oldman", "lines": [
		"Sit a while. No? Nobody sits any more."]},
	{"look": "widow", "lines": [
		"There is a well down the way with good water. There is another with bad.",
		"You will know which is which about a minute too late."]},
	{"look": "ferry", "lines": [
		"Whole valley used to sing at harvest. Whole valley.",
		"Now it is me and the water."]},
]

const PICKER_LINES := [
	"Working on %s. Have been for eleven years.",
	"Know %s? Everybody plays it wrong and everybody is sure they do not.",
	"My grandfather played %s at every wedding in this county.",
	"%s. That is the one that goes strange in the third part.",
	"I only know the one tune worth knowing and it is %s.",
	"Was taught %s by a man who could not read a note and never needed to.",
	"Play %s slow enough and it turns into something else entirely.",
]

const PICKER_TAILS := [
	"Anyway. Go on.",
	"You are welcome to sit if you are not in a hurry.",
	"Do not let me keep you.",
	"It will be better tomorrow. It always is, and then it is not.",
	"Mind how you go.",
]

const SHRINE_LINES := [
	["A stone with a name worn off it. Somebody keeps the grass down."],
	["FOR THOSE WHO DID NOT COME BACK UP, it says. There is no date."],
	["A marker at the roadside. The carving is a set of five lines and no notes on them."],
	["Somebody has left an apple here. It is fresh."],
]
