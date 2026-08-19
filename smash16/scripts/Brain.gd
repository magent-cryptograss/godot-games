extends RefCounted
class_name Brain

# ---------------------------------------------------------------------------
# THE CPU
#
# It produces exactly the same input dictionary a human keyboard produces,
# so it plays the game through the identical code path you do. No cheating,
# no special access -- if the CPU can do it, you can do it.
#
# Priorities, in order:
#   1. If I am off the stage, GET HOME. Nothing else matters.
#   2. If they are above me, hit up.
#   3. If they are close, attack.
#   4. If they are far, throw something or close the gap.
#
# It is deliberately imperfect: reaction cooldowns and a bit of randomness,
# because a CPU with frame-perfect responses is miserable to play against.
# ---------------------------------------------------------------------------

var me = null
var level: int = 1          # 0 easy, 1 normal, 2 hard
var rng := RandomNumberGenerator.new()

var atk_cd: int = 0
var sp_cd: int = 0
var jump_cd: int = 0
var shield_cd: int = 0
var wander: int = 0


static func blank() -> Dictionary:
	return {
		"lx": 0, "up": false, "down": false,
		"jump_p": false, "jump_h": false,
		"atk_p": false, "sp_p": false, "sp_h": false,
		"shield_p": false, "shield_h": false,
	}


func _init(fighter, lvl: int = 1) -> void:
	me = fighter
	level = lvl
	rng.randomize()
	sp_cd = rng.randi_range(30, 90)


func think(foes: Array) -> Dictionary:
	var inp := blank()
	if atk_cd > 0: atk_cd -= 1
	if sp_cd > 0: sp_cd -= 1
	if jump_cd > 0: jump_cd -= 1
	if shield_cd > 0: shield_cd -= 1
	if wander > 0: wander -= 1

	var t = _nearest(foes)
	if t == null:
		return inp

	var s: Rect2 = Rules.SOLID
	var left := s.position.x
	var right := s.position.x + s.size.x
	var deck := s.position.y
	var mid := Rules.VW * 0.5

	# ---------------- 1. recovery beats everything ----------------
	var off_side: bool = me.position.x < left + 3.0 or me.position.x > right - 3.0
	var below: bool = me.position.y > deck + 5.0
	if (off_side and not me.on_ground) or below:
		inp["lx"] = 1 if me.position.x < mid else -1
		inp["jump_h"] = true
		if me.helpless:
			return inp                       # nothing left to do but drift
		if me.vel.y > 0.5 and me.jumps > 0:
			inp["jump_p"] = true
		elif me.jumps <= 0 and me.vel.y > 1.0:
			inp["up"] = true                 # up + special = recovery
			inp["sp_p"] = true
		return inp

	# ---------------- read the situation ----------------
	var dx: float = t.position.x - me.position.x
	var dy: float = t.position.y - me.position.y
	var adx := absf(dx)
	var ady := absf(dy)
	var face := 1 if dx > 0.0 else -1
	var reach := 19.0 * float(me.ch["size"]) * float(me.ch["reach"])

	# ---------------- 2. shield if they are winding up nearby ----------------
	if me.on_ground and shield_cd == 0 and adx < reach + 6.0 and ady < 18.0:
		if t.state == "attack" and rng.randf() < 0.05 + 0.05 * float(level):
			inp["shield_h"] = true
			inp["shield_p"] = true
			shield_cd = 40
			return inp

	# ---------------- 3. attack if they are in range ----------------
	if atk_cd == 0 and adx < reach and ady < 22.0:
		if not me.on_ground and dy > 7.0 and rng.randf() < 0.5:
			inp["down"] = true               # down-air spike
		elif dy < -13.0:
			inp["up"] = true                 # they are above
		elif rng.randf() < 0.55:
			inp["lx"] = face                 # side attack, the kill move
		inp["atk_p"] = true
		atk_cd = maxi(8, rng.randi_range(16, 36) - level * 6)
		return inp

	# ---------------- 4. throw something from range ----------------
	if sp_cd == 0 and adx > 48.0 and ady < 28.0 and me.on_ground:
		inp["lx"] = face
		inp["sp_p"] = true
		sp_cd = maxi(24, rng.randi_range(60, 130) - level * 20)
		return inp

	# ---------------- otherwise: position ----------------
	if adx > reach * 0.8:
		inp["lx"] = face
	elif adx < reach * 0.45 and wander == 0:
		inp["lx"] = -face
		wander = rng.randi_range(8, 20)

	# Do not chase them off the edge -- that is how a CPU kills itself.
	if me.on_ground:
		var nx: float = me.position.x + float(inp["lx"]) * 3.0
		if nx < left + 5.0 or nx > right - 5.0:
			if t.position.y > deck - 2.0 or absf(t.position.x - mid) > s.size.x * 0.5:
				inp["lx"] = 0

	# ---------------- jumping ----------------
	inp["jump_h"] = true
	if me.on_ground and jump_cd == 0:
		if dy < -20.0 and adx < 44.0:
			inp["jump_p"] = true             # chase them onto a platform
			jump_cd = 28
		elif rng.randf() < 0.012:
			inp["jump_p"] = true
			jump_cd = 45
	elif not me.on_ground:
		# drift back toward the stage while airborne
		if me.position.x < left + 8.0:
			inp["lx"] = 1
		elif me.position.x > right - 8.0:
			inp["lx"] = -1
		# fast fall back down if they are below us and we are safe
		if dy > 24.0 and me.vel.y > 0.0 and rng.randf() < 0.08:
			inp["down"] = true

	return inp


func _nearest(foes: Array):
	var best = null
	var bd := 1e9
	for f in foes:
		if f == me or f.stocks <= 0 or f.ko_timer > 0:
			continue
		var d: float = me.position.distance_squared_to(f.position)
		if d < bd:
			bd = d
			best = f
	return best
