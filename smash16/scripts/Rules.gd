extends RefCounted
class_name Rules

# ---------------------------------------------------------------------------
# THE ARENA AND THE MATH
# Everything here is a knob. If the game feels wrong, it is almost always
# one of these numbers and not the code.
# ---------------------------------------------------------------------------

const VW := 384
const VH := 224   # SNES height exactly; the extra width is a deliberate choice

# --- physics, all in pixels-per-frame at 60fps ---
const GRAV      := 0.40    # downward accel each frame
const MAXFALL   := 7.2     # normal terminal velocity
const FASTFALL  := 10.5    # hold down while airborne to drop faster
const JUMPSQUAT := 3       # frames crouched before you actually leave the floor

# --- knockback ---
const KB_SCALE       := 2.15   # converts knockback units into px/frame
const KB_DECAY       := 0.935  # horizontal slowdown each frame while flying
const HITSTUN_PER_KB := 4.0    # frames you cannot act, per unit of knockback
const MIN_HITSTUN    := 8

# --- shields ---
const SHIELD_MAX     := 100.0
const SHIELD_DRAIN   := 0.42   # per frame while held
const SHIELD_REGEN   := 0.30   # per frame while not held
const SHIELD_BREAK   := 110    # frames of helplessness if your shield pops

# --- the stage ---
# The main platform is SOLID on every side. You cannot jump up through it.
# That matters: knocked off the side, you have to get around the edge to
# come back, and that scramble is half of what makes Smash exciting.
# It sits high on purpose. The empty space BELOW the stage is not wasted
# screen -- it is where the whole drama of getting knocked off and
# scrambling back happens, and a stage parked on the bottom edge kills it.
static var SOLID := Rect2(84, 124, 216, 36)

# Soft platforms: you pass up through them, and hold down to drop off.
static var PLATS: Array = [
	Rect2(100, 86, 54, 5),
	Rect2(230, 86, 54, 5),
	Rect2(165, 52, 54, 5),
]

# Cross any of these and you are dead. They sit well outside the screen so
# you get a moment of "can I make it back?" before it is decided.
const BLAST_L := -60.0
const BLAST_R := 444.0
const BLAST_T := -115.0
const BLAST_B := 270.0

static var SPAWNS: Array = [
	Vector2(128, 56), Vector2(256, 56), Vector2(165, 26), Vector2(219, 26),
]

# ---------------------------------------------------------------------------
# The single most important function in the game.
#
# Knockback rises with the victim's percent, and falls with their weight.
# A fresh opponent at 0% barely budges; the same move at 140% sends them
# into orbit. That curve is the whole sport.
# ---------------------------------------------------------------------------
static func knockback(bkb: float, kbg: float, percent_after: float, weight: float) -> float:
	return (bkb + percent_after * kbg * 0.055) * (110.0 / weight)

static func launch_velocity(kb: float, angle_deg: float, dir: int) -> Vector2:
	var speed := kb * KB_SCALE
	var r := deg_to_rad(angle_deg)
	# Screen y grows downward, so an upward launch is negative y.
	return Vector2(cos(r) * speed * dir, -sin(r) * speed)

static func hitstun_frames(kb: float) -> int:
	return maxi(MIN_HITSTUN, int(round(kb * HITSTUN_PER_KB)))

static func out_of_bounds(p: Vector2) -> bool:
	return p.x < BLAST_L or p.x > BLAST_R or p.y < BLAST_T or p.y > BLAST_B

# Which edge someone died through -- used to place the KO flash.
static func blast_side(p: Vector2) -> String:
	if p.x < BLAST_L: return "left"
	if p.x > BLAST_R: return "right"
	if p.y < BLAST_T: return "top"
	return "bottom"
