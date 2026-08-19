extends RefCounted
class_name Moves

# ---------------------------------------------------------------------------
# THE MOVE TABLE
#
# Every attack is three chunks of frames:
#
#   startup   winding up. You are committed, but the hitbox is not out yet.
#   active    the hitbox exists. This is the ONLY window that can hit.
#   rec       recovery. Hitbox is gone, you still cannot act.
#
# That split is what makes a fighting game a fighting game. Strong moves get
# long startup and long recovery, so throwing them out at random gets you
# punished. Weak moves come out in three frames and are safe.
#
#   dmg     percent added to whoever you hit
#   bkb     base knockback -- how far it sends them at 0%
#   kbg     knockback growth -- how much their percent multiplies it
#   ang     launch angle, degrees. 0 = straight forward, 90 = up,
#           270 = straight down (a spike -- the best hit in the game)
#   w,h     hitbox size in pixels
#   oy      hitbox offset from the feet (negative = above the feet)
#   center  hitbox wraps the body instead of poking out front
#   multi   this hitbox can hit the same target again every N frames
# ---------------------------------------------------------------------------

static var TABLE: Dictionary = {
	# ---- grounded ----
	"jab":  {"startup": 3, "active": 3, "rec": 8,  "dmg": 3.0,  "bkb": 1.2, "kbg": 0.30, "ang": 45.0,  "w": 15.0, "h": 9.0,  "oy": -16.0},
	"side": {"startup": 6, "active": 4, "rec": 15, "dmg": 9.0,  "bkb": 2.3, "kbg": 0.55, "ang": 22.0,  "w": 21.0, "h": 11.0, "oy": -17.0},
	"up":   {"startup": 5, "active": 4, "rec": 13, "dmg": 8.0,  "bkb": 2.1, "kbg": 0.62, "ang": 82.0,  "w": 22.0, "h": 17.0, "oy": -35.0, "center": true},
	"down": {"startup": 5, "active": 3, "rec": 11, "dmg": 6.0,  "bkb": 1.5, "kbg": 0.36, "ang": 14.0,  "w": 19.0, "h": 8.0,  "oy": -8.0},

	# ---- aerials ----
	"nair": {"startup": 4, "active": 8, "rec": 10, "dmg": 7.0,  "bkb": 1.8, "kbg": 0.45, "ang": 45.0,  "w": 29.0, "h": 21.0, "oy": -23.0, "center": true, "air": true},
	"fair": {"startup": 7, "active": 4, "rec": 14, "dmg": 11.0, "bkb": 2.2, "kbg": 0.60, "ang": 32.0,  "w": 21.0, "h": 13.0, "oy": -21.0, "air": true},
	"uair": {"startup": 5, "active": 4, "rec": 12, "dmg": 9.0,  "bkb": 2.0, "kbg": 0.66, "ang": 88.0,  "w": 23.0, "h": 17.0, "oy": -37.0, "center": true, "air": true},
	"dair": {"startup": 8, "active": 4, "rec": 16, "dmg": 12.0, "bkb": 1.6, "kbg": 0.34, "ang": 272.0, "w": 19.0, "h": 17.0, "oy": -4.0,  "center": true, "air": true, "spike": true},

	# ---- neutral specials that are melee rather than a projectile ----
	# Kirby's hammer: slowest move in the game and the hardest single hit.
	"hammer": {"startup": 14, "active": 5, "rec": 22, "dmg": 18.0, "bkb": 2.6, "kbg": 0.52, "ang": 40.0, "w": 24.0, "h": 20.0, "oy": -24.0},
	# Zero's dash slash: he lunges forward on the first active frame, which is
	# both how he closes distance and how he gets himself killed off the edge.
	"dashslash": {"startup": 8, "active": 6, "rec": 18, "dmg": 13.0, "bkb": 2.2, "kbg": 0.48, "ang": 30.0, "w": 26.0, "h": 13.0, "oy": -17.0, "lunge": 5.2},

	# ---- the shot-firing specials: no body hitbox, they spawn a projectile ----
	"cast": {"startup": 8, "active": 1, "rec": 14, "dmg": 0.0, "bkb": 0.0, "kbg": 0.0, "ang": 0.0, "w": 0.0, "h": 0.0, "oy": 0.0},

	# ---- up-specials ----
	# All of them lift you. What differs is whether they hit once hard or
	# many times weakly, and how long you are stuck in startup first.
	"usp_boost":   {"startup": 3,  "active": 8,  "rec": 0, "dmg": 7.0, "bkb": 1.8, "kbg": 0.45, "ang": 80.0, "w": 20.0, "h": 26.0, "oy": -28.0, "center": true},
	"usp_screw":   {"startup": 2,  "active": 26, "rec": 0, "dmg": 2.2, "bkb": 0.8, "kbg": 0.14, "ang": 70.0, "w": 24.0, "h": 30.0, "oy": -30.0, "center": true, "multi": 5},
	"usp_spin":    {"startup": 3,  "active": 22, "rec": 0, "dmg": 2.6, "bkb": 0.9, "kbg": 0.16, "ang": 60.0, "w": 28.0, "h": 26.0, "oy": -26.0, "center": true, "multi": 5},
	"usp_cutter":  {"startup": 4,  "active": 10, "rec": 0, "dmg": 6.0, "bkb": 1.6, "kbg": 0.40, "ang": 85.0, "w": 18.0, "h": 28.0, "oy": -30.0, "center": true},
	# Fox stands still and charges for 12 frames before he goes. Very true to
	# the original, and it is a real weakness -- you can be hit out of it.
	"usp_firefox": {"startup": 12, "active": 16, "rec": 0, "dmg": 9.0, "bkb": 1.9, "kbg": 0.42, "ang": 75.0, "w": 20.0, "h": 30.0, "oy": -30.0, "center": true},
	"usp_punch":   {"startup": 2,  "active": 10, "rec": 0, "dmg": 10.0,"bkb": 2.0, "kbg": 0.50, "ang": 84.0, "w": 18.0, "h": 26.0, "oy": -30.0, "center": true},
	"usp_pkt":     {"startup": 4,  "active": 12, "rec": 0, "dmg": 8.0, "bkb": 1.9, "kbg": 0.46, "ang": 80.0, "w": 22.0, "h": 28.0, "oy": -30.0, "center": true},
	"usp_egg":     {"startup": 6,  "active": 1,  "rec": 12,"dmg": 0.0, "bkb": 0.0, "kbg": 0.0,  "ang": 0.0,  "w": 0.0,  "h": 0.0,  "oy": 0.0},
	"usp_saber":   {"startup": 3,  "active": 14, "rec": 0, "dmg": 9.0, "bkb": 1.9, "kbg": 0.44, "ang": 80.0, "w": 20.0, "h": 32.0, "oy": -34.0, "center": true},
}

# ---------------------------------------------------------------------------
# NEUTRAL SPECIALS -- one per fighter, and this is mostly what makes them
# feel like themselves rather than a recolour.
#   chargeable: hold the special button to build it up, release to fire.
#   rapid:      you can fire again almost immediately.
# ---------------------------------------------------------------------------
static var SPECIALS: Dictionary = {
	"buster":    {"kind": "shot",  "move": "cast", "shot": "buster",    "chargeable": true,  "max_charge": 60},
	"charge":    {"kind": "shot",  "move": "cast", "shot": "charge",    "chargeable": true,  "max_charge": 90},
	"boomerang": {"kind": "shot",  "move": "cast", "shot": "boomerang"},
	"hammer":    {"kind": "melee", "move": "hammer"},
	"blaster":   {"kind": "shot",  "move": "cast", "shot": "blaster",   "rapid": true},
	"fireball":  {"kind": "shot",  "move": "cast", "shot": "fireball"},
	"pkfire":    {"kind": "shot",  "move": "cast", "shot": "pkfire"},
	"egg":       {"kind": "shot",  "move": "cast", "shot": "egg"},
	"dashslash": {"kind": "melee", "move": "dashslash"},
}

# ---------------------------------------------------------------------------
# UP-SPECIALS -- your recovery. Every one of these puts you in HELPLESS
# afterwards: you fall with no jumps and no attacks until you touch ground.
# That is the rule that makes getting knocked off genuinely frightening.
# ---------------------------------------------------------------------------
static var UP_SPECIALS: Dictionary = {
	"boost":   {"move": "usp_boost",   "lift_on": 3},
	"screw":   {"move": "usp_screw",   "lift_on": 2},
	"spinatk": {"move": "usp_spin",    "lift_on": 3},
	"cutter":  {"move": "usp_cutter",  "lift_on": 4},
	"firefox": {"move": "usp_firefox", "lift_on": 12},
	"punch":   {"move": "usp_punch",   "lift_on": 2},
	"pkt":     {"move": "usp_pkt",     "lift_on": 4},
	"eggtoss": {"move": "usp_egg",     "lift_on": 6, "shot": "egg"},
	"risingsaber": {"move": "usp_saber", "lift_on": 3},
}

# ---------------------------------------------------------------------------
# PROJECTILES
#   vx,vy  launch velocity, flipped by facing
#   grav   downward accel. 0 = flies dead straight.
#   life   frames before it fizzles
#   r      radius, for both drawing and collision
#   bounces  times it can bounce off the stage before dying
#   returns  boomerang: reverses direction partway out
#   burst    on impact, spawn this other projectile in place
# ---------------------------------------------------------------------------
static var SHOTS: Dictionary = {
	# Mega Man X -- fast, weak uncharged, genuinely scary fully charged.
	"buster":    {"vx": 4.6, "vy": 0.0,  "grav": 0.0,   "life": 50,  "r": 2.5, "kind": "energy",
				  "dmg": 4.0, "bkb": 1.2, "kbg": 0.22, "ang": 25.0, "bounces": 0},
	# Samus -- slower but the biggest single projectile here when charged.
	"charge":    {"vx": 4.2, "vy": 0.0,  "grav": 0.0,   "life": 70,  "r": 4.0, "kind": "energy",
				  "dmg": 6.0, "bkb": 1.4, "kbg": 0.30, "ang": 38.0, "bounces": 0},
	# Link -- goes out, comes back. Can catch you on the way home.
	"boomerang": {"vx": 4.2, "vy": 0.0,  "grav": 0.0,   "life": 84,  "r": 3.0, "kind": "boomerang",
				  "dmg": 5.0, "bkb": 1.3, "kbg": 0.25, "ang": 35.0, "bounces": 0, "returns": 34},
	# Fox -- almost no knockback on purpose. It racks up percent without
	# ever sending anyone anywhere, which is exactly what the blaster does.
	"blaster":   {"vx": 6.2, "vy": 0.0,  "grav": 0.0,   "life": 40,  "r": 1.5, "kind": "energy",
				  "dmg": 2.0, "bkb": 0.4, "kbg": 0.02, "ang": 30.0, "bounces": 0},
	# Mario -- arcs and bounces along the floor.
	"fireball":  {"vx": 3.1, "vy": -1.3, "grav": 0.115, "life": 110, "r": 3.0, "kind": "fire",
				  "dmg": 5.0, "bkb": 1.4, "kbg": 0.34, "ang": 42.0, "bounces": 2},
	# Ness -- the shot is weak, but it bursts into a pillar that racks up hits.
	"pkfire":    {"vx": 4.0, "vy": 0.5,  "grav": 0.05,  "life": 55,  "r": 3.0, "kind": "fire",
				  "dmg": 4.0, "bkb": 0.9, "kbg": 0.12, "ang": 88.0, "bounces": 0, "burst": "pkpillar"},
	"pkpillar":  {"vx": 0.0, "vy": 0.0,  "grav": 0.0,   "life": 40,  "r": 9.0, "kind": "pillar",
				  "dmg": 2.0, "bkb": 0.5, "kbg": 0.10, "ang": 88.0, "bounces": 0, "multi": 6, "still": true},
	# Yoshi -- a high lob. Hard to aim, hurts when it lands.
	"egg":       {"vx": 3.0, "vy": -3.4, "grav": 0.20,  "life": 90,  "r": 4.0, "kind": "egg",
				  "dmg": 7.0, "bkb": 1.6, "kbg": 0.36, "ang": 45.0, "bounces": 1},
}

static func get_move(n: String) -> Dictionary:
	return TABLE[n]

static func total_frames(n: String) -> int:
	var m: Dictionary = TABLE[n]
	return int(m["startup"]) + int(m["active"]) + int(m["rec"])
