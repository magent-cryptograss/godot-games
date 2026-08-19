extends Node2D
class_name Fighter

# ---------------------------------------------------------------------------
# A FIGHTER
#
# Deliberately NOT a CharacterBody2D. Godot's physics engine is built for
# platformers with slopes and rigid bodies; a platform fighter needs
# frame-exact hand-tuned kinematics -- knockback decay, hitstun counts,
# drop-through platforms, one-frame ledge behaviour. So collision here is
# hand-rolled AABB on a fixed 60Hz tick, and every number is a knob.
#
# position is the fighter's FEET. Up is negative y.
# ---------------------------------------------------------------------------

var ch: Dictionary = {}
var slot: int = 0
var is_cpu: bool = false
var brain = null
var arena = null

# --- kinematics ---
var vel := Vector2.ZERO
var facing: int = 1
var on_ground: bool = false

# --- match state ---
var percent: float = 0.0
var stocks: int = 3

# --- state machine ---
# idle run crouch air attack charging shield roll dodge hitstun broken ko
var state: String = "air"
var st: int = 0
var jumps: int = 2
var helpless: bool = false
var jumpsquat: int = 0
var jump_held: bool = false
var flutter: int = 0
var fastfalling: bool = false

# --- attacking ---
var move_name: String = ""
var move_f: int = 0
var hit_reg: Dictionary = {}
var pending_shot: String = ""
var pending_lift: int = 0
var is_up_special: bool = false
var charge: int = 0

# --- getting hit ---
var hitstun: int = 0
var hitlag: int = 0
var shield_hp: float = 100.0
var invuln: int = 0
var ko_timer: int = 0
var drop_timer: int = 0
var last_hurt_by: int = -1

# --- cosmetic ---
var anim: float = 0.0
var flash: int = 0


func setup(char_index: int, in_slot: int, cpu: bool, stock_count: int) -> void:
	ch = Chars.get_char(char_index)
	slot = in_slot
	is_cpu = cpu
	stocks = stock_count
	jumps = int(ch["jumps"])
	shield_hp = Rules.SHIELD_MAX
	position = Rules.SPAWNS[in_slot % Rules.SPAWNS.size()]
	facing = 1 if position.x < Rules.VW * 0.5 else -1
	state = "air"
	z_index = 10


# ===========================================================================
# MAIN TICK
# ===========================================================================
func tick(inp: Dictionary, foes: Array) -> void:
	anim += 1.0
	if flash > 0:
		flash -= 1

	# Hitlag: both fighters freeze for a few frames on contact. It is a tiny
	# detail that does more for the feel of a hit than anything else.
	if hitlag > 0:
		hitlag -= 1
		queue_redraw()
		return

	if ko_timer > 0:
		ko_timer -= 1
		if ko_timer == 0:
			do_respawn()
		queue_redraw()
		return

	if invuln > 0:
		invuln -= 1
	if drop_timer > 0:
		drop_timer -= 1

	# --- shield broken: you are stunned and helpless for a long time ---
	if state == "broken":
		st -= 1
		_gravity()
		_collide()
		if st <= 0:
			state = "idle" if on_ground else "air"
		queue_redraw()
		return

	# --- flying through the air after a hit, unable to act ---
	if hitstun > 0:
		hitstun -= 1
		vel.x *= Rules.KB_DECAY
		vel.y += Rules.GRAV * float(ch["grav_mul"]) * 0.85
		vel.y = minf(vel.y, Rules.MAXFALL * 1.7)
		_collide()
		if hitstun <= 0:
			state = "idle" if on_ground else "air"
		queue_redraw()
		return

	# --- rolling / dodging: brief invulnerability, no attacking ---
	if state == "roll" or state == "dodge":
		st -= 1
		vel.x = move_toward(vel.x, 0.0, 0.30)
		vel.y = move_toward(vel.y, 0.0, 0.30)
		if not on_ground:
			_gravity()
		_collide()
		if st <= 0:
			state = "idle" if on_ground else "air"
		queue_redraw()
		return

	# --- charging a special in place ---
	if state == "charging":
		var sp: Dictionary = Moves.SPECIALS[ch["special"]]
		charge = mini(charge + 1, int(sp["max_charge"]))
		vel.x = move_toward(vel.x, 0.0, 0.35)
		_gravity()
		_collide()
		if not inp["sp_h"] or charge >= int(sp["max_charge"]):
			_begin_move(String(sp["move"]))
			pending_shot = String(sp["shot"])
		queue_redraw()
		return

	# --- mid-attack ---
	if move_name != "":
		_run_attack(inp, foes)
		queue_redraw()
		return

	# --- jumpsquat: the few frames you crouch before leaving the floor ---
	if jumpsquat > 0:
		jumpsquat -= 1
		if inp["jump_h"]:
			jump_held = true
		vel.x = move_toward(vel.x, 0.0, 0.4)
		if jumpsquat == 0:
			vel.y = float(ch["jump"]) if jump_held else float(ch["hop"])
			on_ground = false
			jumps = int(ch["jumps"]) - 1
			state = "air"
			Sfx.play("jump")
		_collide()
		queue_redraw()
		return

	_free_movement(inp, foes)
	queue_redraw()


# ===========================================================================
# FREE MOVEMENT -- you are in control
# ===========================================================================
func _free_movement(inp: Dictionary, foes: Array) -> void:
	# ---- shield / roll / spot dodge / air dodge ----
	if inp["shield_h"] and not helpless:
		if on_ground and shield_hp > 0.0:
			if inp["lx"] != 0 and inp["shield_p"]:
				_start_roll(int(inp["lx"]))
				return
			if inp["down"] and inp["shield_p"]:
				_start_spot_dodge()
				return
			state = "shield"
			shield_hp -= Rules.SHIELD_DRAIN
			vel.x = move_toward(vel.x, 0.0, 0.6)
			if shield_hp <= 0.0:
				_break_shield()
			_gravity()
			_collide()
			return
		elif not on_ground and inp["shield_p"]:
			_start_air_dodge(inp)
			return
	else:
		if state == "shield":
			state = "idle"
		shield_hp = minf(Rules.SHIELD_MAX, shield_hp + Rules.SHIELD_REGEN)

	# ---- attacks ----
	if not helpless:
		if inp["atk_p"]:
			_start_normal(inp)
			return
		if inp["sp_p"]:
			_start_special(inp)
			return

	# ---- jumping ----
	if inp["jump_p"] and not helpless:
		if on_ground:
			jumpsquat = Rules.JUMPSQUAT
			jump_held = false
			state = "crouch"
			_collide()
			return
		elif jumps > 0:
			jumps -= 1
			vel.y = float(ch["jump"]) * 0.94
			fastfalling = false
			# Yoshi's flutter: his air jump keeps lifting while held
			if ch.get("flutter", false):
				flutter = 26
			Sfx.play("jump")

	# ---- horizontal control ----
	var lx: int = int(inp["lx"])
	if on_ground:
		if lx != 0:
			vel.x = move_toward(vel.x, float(ch["speed"]) * lx, float(ch["accel"]))
			facing = lx
			state = "run"
		else:
			vel.x = move_toward(vel.x, 0.0, 0.45)
			state = "crouch" if inp["down"] else "idle"
		# drop through a soft platform
		if inp["down"] and drop_timer <= 0 and _on_soft_platform():
			drop_timer = 9
			position.y += 2.0
			on_ground = false
			state = "air"
	else:
		if lx != 0:
			vel.x = move_toward(vel.x, float(ch["air_max"]) * lx, float(ch["air_acc"]))
			if not helpless:
				facing = lx
		state = "helpless" if helpless else "air"
		# fast fall
		if inp["down"] and vel.y > 0.5 and not fastfalling:
			fastfalling = true
			vel.y = Rules.FASTFALL
		if flutter > 0 and not inp["jump_h"]:
			flutter = 0

	_gravity()
	_collide()


# ===========================================================================
# ATTACKS
# ===========================================================================
func _start_normal(inp: Dictionary) -> void:
	var n := ""
	if on_ground:
		if inp["up"]:
			n = "up"
		elif inp["down"]:
			n = "down"
		elif inp["lx"] != 0:
			facing = int(inp["lx"])
			n = "side"
		else:
			n = "jab"
	else:
		if inp["up"]:
			n = "uair"
		elif inp["down"]:
			n = "dair"
		elif inp["lx"] != 0 and int(inp["lx"]) == facing:
			n = "fair"
		else:
			n = "nair"
	_begin_move(n)


func _start_special(inp: Dictionary) -> void:
	# Up + special is always your recovery.
	if inp["up"]:
		_start_up_special(inp)
		return
	var sp: Dictionary = Moves.SPECIALS[ch["special"]]
	if int(inp["lx"]) != 0:
		facing = int(inp["lx"])
	if sp.get("chargeable", false):
		state = "charging"
		charge = 0
		return
	_begin_move(String(sp["move"]))
	if sp["kind"] == "shot":
		pending_shot = String(sp["shot"])


func _start_up_special(_inp: Dictionary) -> void:
	if helpless:
		return
	var us: Dictionary = Moves.UP_SPECIALS[ch["up_special"]]
	_begin_move(String(us["move"]))
	is_up_special = true
	pending_lift = int(us["lift_on"])
	pending_shot = String(us.get("shot", ""))
	Sfx.play("special")


func _begin_move(n: String) -> void:
	move_name = n
	move_f = 0
	hit_reg.clear()
	pending_shot = ""
	pending_lift = 0
	is_up_special = false
	state = "attack"
	fastfalling = false


func _run_attack(inp: Dictionary, foes: Array) -> void:
	var m: Dictionary = Moves.TABLE[move_name]
	move_f += 1
	var s := int(m["startup"])
	var a := int(m["active"])

	# up-special lift
	if pending_lift > 0 and move_f == pending_lift:
		vel.y = float(ch["rise"])
		vel.x = vel.x * 0.4 + float(inp["lx"]) * 1.3
		on_ground = false

	# lunging moves throw you forward as the hitbox comes out
	if move_f == s + 1 and m.has("lunge"):
		vel.x = float(m["lunge"]) * facing
		if not on_ground:
			vel.y = minf(vel.y, 0.6)

	# fire the projectile on the first active frame
	if move_f == s + 1 and pending_shot != "":
		if arena:
			arena.spawn_shot(self, pending_shot, charge)
		charge = 0
		pending_shot = ""

	# hitbox live?
	if move_f > s and move_f <= s + a and float(m["w"]) > 0.0:
		_check_hits(m, foes)

	# movement while attacking
	if on_ground:
		vel.x = move_toward(vel.x, 0.0, 0.5)
	elif int(inp["lx"]) != 0:
		vel.x = move_toward(vel.x, float(ch["air_max"]) * int(inp["lx"]) * 0.85,
			float(ch["air_acc"]) * 0.7)

	# up-specials float a little during their active frames
	if is_up_special and move_f > s and move_f <= s + a:
		if not on_ground:
			vel.y += Rules.GRAV * float(ch["grav_mul"]) * 0.35
			vel.y = minf(vel.y, Rules.MAXFALL)
	else:
		_gravity()
	_collide()

	if move_f >= s + a + int(m["rec"]):
		_end_move()


func _end_move() -> void:
	var was_up := is_up_special
	move_name = ""
	move_f = 0
	is_up_special = false
	hit_reg.clear()
	if was_up and not on_ground:
		# HELPLESS: no jumps, no attacks, no control but drift, until you land.
		# This one rule is what makes being knocked off the stage frightening.
		helpless = true
		state = "helpless"
	else:
		state = "idle" if on_ground else "air"


func _check_hits(m: Dictionary, foes: Array) -> void:
	var r := hitbox_rect(m)
	for f in foes:
		if f == self or f.ko_timer > 0 or f.invuln > 0:
			continue
		var mult := int(m.get("multi", 0))
		if mult > 0:
			var last := int(hit_reg.get(f, -999))
			if move_f - last < mult:
				continue
		elif hit_reg.has(f):
			continue
		if r.intersects(f.hurtbox()):
			hit_reg[f] = move_f
			if arena:
				arena.resolve_hit(self, f, m, r.get_center())


# ===========================================================================
# BOXES
# ===========================================================================
func hurtbox() -> Rect2:
	var sc := float(ch["size"])
	var hw := 6.0 * sc
	var hh := 22.0 * sc
	if state == "crouch" or state == "shield":
		hh *= 0.78
	return Rect2(position.x - hw, position.y - hh, hw * 2.0, hh)


func hitbox_rect(m: Dictionary) -> Rect2:
	var sc := float(ch["size"])
	var h := float(m["h"]) * sc
	var oy := float(m["oy"]) * sc
	if m.get("center", false):
		var cw := float(m["w"]) * sc
		return Rect2(position.x - cw * 0.5, position.y + oy, cw, h)
	# Swords and arm cannons reach further than fists.
	var w := float(m["w"]) * sc * float(ch["reach"])
	var x := position.x + 2.0 * sc if facing > 0 else position.x - 2.0 * sc - w
	return Rect2(x, position.y + oy, w, h)


# ===========================================================================
# TAKING A HIT
# ===========================================================================
func apply_hit(att, m: Dictionary, hit_pos: Vector2, dmg_scale: float = 1.0) -> String:
	if invuln > 0 or ko_timer > 0:
		return "none"

	var power := 1.0
	if att != null:
		power = float(att.ch["power"])
	var dmg := float(m["dmg"]) * dmg_scale * power

	# ---- shielded ----
	if state == "shield":
		shield_hp -= dmg * 2.2 + 4.0
		vel.x += signf(position.x - hit_pos.x) * 0.8
		hitlag = 4
		if att != null:
			att.hitlag = 4
		if shield_hp <= 0.0:
			_break_shield()
			return "break"
		return "shield"

	# ---- clean hit ----
	percent += dmg

	# Knockback is computed from the percent AFTER the hit lands, which is
	# why the same move sends you further every single time it connects.
	var kb := Rules.knockback(float(m["bkb"]), float(m["kbg"]), percent, float(ch["weight"]))

	var dir := 1
	if m.get("center", false):
		dir = 1 if position.x >= hit_pos.x else -1
	elif att != null:
		dir = att.facing

	vel = Rules.launch_velocity(kb, float(m["ang"]), dir)
	hitstun = Rules.hitstun_frames(kb)
	state = "hitstun"
	move_name = ""
	move_f = 0
	is_up_special = false
	hit_reg.clear()
	helpless = false
	fastfalling = false
	on_ground = false
	facing = -dir
	flash = 6
	if att != null:
		last_hurt_by = att.slot

	var lag := int(round(3.0 + dmg * 0.55))
	hitlag = lag
	if att != null:
		att.hitlag = lag
	return "hit"


func _break_shield() -> void:
	shield_hp = 0.0
	state = "broken"
	st = Rules.SHIELD_BREAK
	vel = Vector2(0.0, -3.2)
	on_ground = false
	Sfx.play("break")


func _start_roll(dir: int) -> void:
	state = "roll"
	st = 24
	invuln = 17
	vel.x = dir * 4.4
	Sfx.play("dodge")


func _start_spot_dodge() -> void:
	state = "dodge"
	st = 20
	invuln = 15
	vel.x = 0.0
	Sfx.play("dodge")


func _start_air_dodge(inp: Dictionary) -> void:
	var fast: bool = ch.get("air_dash", false)
	state = "dodge"
	st = 26 if fast else 22
	invuln = 17 if fast else 13
	var dy := 0.0
	if inp["down"]:
		dy = 1.0
	elif inp["up"]:
		dy = -1.0
	var d := Vector2(float(inp["lx"]), dy)
	if d.length() > 0.01:
		d = d.normalized()
	vel = d * (7.0 if fast else 5.2)
	Sfx.play("dodge")


# ===========================================================================
# DYING AND COMING BACK
# ===========================================================================
func kill() -> void:
	stocks -= 1
	ko_timer = 58
	state = "ko"
	vel = Vector2.ZERO
	move_name = ""
	hitstun = 0
	hitlag = 0
	charge = 0
	helpless = false


func do_respawn() -> void:
	percent = 0.0
	position = Rules.SPAWNS[slot % Rules.SPAWNS.size()]
	vel = Vector2.ZERO
	state = "air"
	invuln = 110
	jumps = int(ch["jumps"])
	helpless = false
	fastfalling = false
	shield_hp = Rules.SHIELD_MAX
	facing = 1 if position.x < Rules.VW * 0.5 else -1


# ===========================================================================
# PHYSICS
# ===========================================================================
func _gravity() -> void:
	if on_ground:
		return
	var g := Rules.GRAV * float(ch["grav_mul"])
	if flutter > 0:
		g *= 0.30
		flutter -= 1
	vel.y += g
	var cap := Rules.FASTFALL if fastfalling else Rules.MAXFALL
	vel.y = minf(vel.y, cap)


func _on_soft_platform() -> bool:
	var hw := 6.0 * float(ch["size"])
	for p in Rules.PLATS:
		var pr: Rect2 = p
		if absf(position.y - pr.position.y) < 1.5 \
		   and position.x + hw > pr.position.x \
		   and position.x - hw < pr.position.x + pr.size.x:
			return true
	return false


func _collide() -> void:
	var sc := float(ch["size"])
	var hw := 6.0 * sc
	var hh := 22.0 * sc
	var s: Rect2 = Rules.SOLID

	# ---- X axis: the main stage is solid from the sides ----
	position.x += vel.x
	if position.x + hw > s.position.x and position.x - hw < s.position.x + s.size.x \
	   and position.y > s.position.y and position.y - hh < s.position.y + s.size.y:
		if vel.x > 0.0:
			position.x = s.position.x - hw
		elif vel.x < 0.0:
			position.x = s.position.x + s.size.x + hw
		vel.x = 0.0

	# ---- Y axis ----
	var prev := position.y
	var was_ground := on_ground
	position.y += vel.y
	on_ground = false

	if vel.y >= 0.0:
		# landing on top of the main stage
		if prev <= s.position.y and position.y >= s.position.y \
		   and position.x + hw > s.position.x and position.x - hw < s.position.x + s.size.x:
			position.y = s.position.y
			_land(was_ground)
		else:
			# landing on a soft platform (only from above, and not while dropping)
			for p in Rules.PLATS:
				var pr: Rect2 = p
				if drop_timer <= 0 and prev <= pr.position.y and position.y >= pr.position.y \
				   and position.x + hw > pr.position.x \
				   and position.x - hw < pr.position.x + pr.size.x:
					position.y = pr.position.y
					_land(was_ground)
					break
	else:
		# bonking your head on the underside of the stage
		var bot := s.position.y + s.size.y
		if prev - hh >= bot and position.y - hh <= bot \
		   and position.x + hw > s.position.x and position.x - hw < s.position.x + s.size.x:
			position.y = bot + hh
			vel.y = 0.0

	if was_ground and not on_ground:
		jumps = mini(jumps, int(ch["jumps"]) - 1)


func _land(was_ground: bool) -> void:
	on_ground = true
	vel.y = 0.0
	jumps = int(ch["jumps"])
	helpless = false
	flutter = 0
	fastfalling = false
	if not was_ground and arena:
		arena.land_puff(position)
		Sfx.play("land")
	if state in ["air", "hitstun", "helpless", "broken"]:
		state = "idle"


func _draw() -> void:
	Art.draw_fighter(self)
