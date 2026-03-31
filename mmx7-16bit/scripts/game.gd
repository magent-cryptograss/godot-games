extends Node2D

# ================================================================
# MEGA MAN X7 — 16-BIT SNES DEMAKE
# Full remake with Axl, Zero (start), X (unlock after 64 reploids)
# Tag system, 8 maverick stages, copy shot, Z-saber
# ================================================================

# --- CONSTANTS ---
const SW = 400       # SNES-ish width
const SH = 224       # SNES-ish height
const TILE = 16
const GRAVITY = 680.0
const MAX_FALL = 350.0

# --- ENUMS ---
enum State { TITLE, SELECT, PLAYING, BOSS_INTRO, BOSS, PAUSE, WEAPON_GET, GAME_OVER }
enum PState { IDLE, WALK, JUMP, FALL, DASH, WALL_SLIDE, WALL_JUMP, HURT, DEAD, LADDER }

# --- GAME STATE ---
var state = State.TITLE
var frame = 0
var title_timer = 0.0

# --- CHARACTERS ---
# 0=Axl, 1=Zero, 2=X
var active_char = 0     # who's playing
var tag_char = 1        # who's on standby
var x_unlocked = false
var reploids_rescued = 0
const REPLOIDS_TO_UNLOCK = 64

# Per-character data: [hp, max_hp, weapon_energy]
var char_hp = [28, 28, 28]
var char_max_hp = [28, 28, 28]
var char_alive = [true, true, true]
var char_names = ["AXL", "ZERO", "X"]

# --- PLAYER PHYSICS ---
var p_pos = Vector2(40, 160)
var p_vel = Vector2.ZERO
var p_state = PState.IDLE
var p_facing = 1        # 1=right, -1=left
var p_on_ground = true
var p_on_wall = 0       # -1=left wall, 0=none, 1=right wall
var p_dash_timer = 0.0
var p_invuln = 0.0
var p_anim = 0.0
var p_shoot_timer = 0.0
var p_charge = 0.0
var p_wall_jump_lock = 0.0  # brief lock after wall jump
var p_coyote = 0.0      # coyote time for jumping
var p_jump_buffer = 0.0  # input buffer for jump

const P_SPEED = 110.0
const P_DASH_SPEED = 200.0
const P_JUMP = -280.0
const P_WALL_JUMP_X = 160.0
const P_WALL_SLIDE_SPEED = 60.0
const P_DASH_TIME = 0.35
const P_COYOTE_TIME = 0.08
const P_JUMP_BUFFER = 0.1

# --- CAMERA ---
var cam_x = 0.0
var cam_target_x = 0.0
var level_width = 4800.0

# --- LEVEL DATA ---
var platforms = []       # Vector4(x, y, w, h)
var enemies = []
var projectiles = []
var effects = []
var items = []
var boss_data = null
var checkpoint = Vector2(40, 160)

# --- STAGE SELECT ---
var stage_cursor = 0
var stages_clear = [false,false,false,false,false,false,false,false]
var stage_names = ["Flame Hyenard","Ride Boarski","Vanishing Gungaroo","Tornado Tonion",
	"Splash Warfly","Wind Crowrang","Snipe Anteator","Soldier Stonekong"]
var stage_colors = [Color(0.95,0.35,0.1),Color(0.6,0.4,0.25),Color(0.85,0.75,0.2),Color(0.3,0.85,0.35),
	Color(0.2,0.5,0.95),Color(0.55,0.3,0.75),Color(0.45,0.55,0.4),Color(0.65,0.5,0.3)]
var current_stage = -1

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	frame += 1
	match state:
		State.TITLE: _tick_title(delta)
		State.SELECT: _tick_select(delta)
		State.PLAYING: _tick_play(delta)
		State.GAME_OVER: _tick_gameover(delta)
	queue_redraw()

# ================================================================
# TITLE
# ================================================================
func _tick_title(delta: float) -> void:
	title_timer += delta
	if Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("shoot"):
		state = State.SELECT

# ================================================================
# STAGE SELECT
# ================================================================
func _tick_select(delta: float) -> void:
	if Input.is_action_just_pressed("move_left"): stage_cursor = (stage_cursor - 1 + 8) % 8
	if Input.is_action_just_pressed("move_right"): stage_cursor = (stage_cursor + 1) % 8
	if Input.is_action_just_pressed("move_up"): stage_cursor = (stage_cursor - 4 + 8) % 8
	if Input.is_action_just_pressed("move_down"): stage_cursor = (stage_cursor + 4) % 8
	if Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("shoot"):
		current_stage = stage_cursor
		_build_stage(current_stage)
		state = State.PLAYING

# ================================================================
# GAMEPLAY
# ================================================================
func _tick_play(delta: float) -> void:
	if not char_alive[active_char]:
		p_vel.y += GRAVITY * delta
		p_pos += p_vel * delta
		p_anim += delta
		if p_anim > 2.0: state = State.GAME_OVER
		return

	_input_player(delta)
	_physics_player(delta)
	_update_enemies(delta)
	_update_projectiles(delta)
	_update_effects(delta)
	_collisions_player()
	_update_camera(delta)

	p_anim += delta
	if p_invuln > 0: p_invuln -= delta
	if p_shoot_timer > 0: p_shoot_timer -= delta
	if p_wall_jump_lock > 0: p_wall_jump_lock -= delta
	if p_coyote > 0: p_coyote -= delta
	if p_jump_buffer > 0: p_jump_buffer -= delta

func _input_player(delta: float) -> void:
	var mx = Input.get_axis("move_left", "move_right")

	# Facing
	if mx > 0: p_facing = 1
	elif mx < 0: p_facing = -1

	# Jump buffering
	if Input.is_action_just_pressed("jump"):
		p_jump_buffer = P_JUMP_BUFFER

	# --- DASH ---
	if Input.is_action_just_pressed("dash") and p_dash_timer <= 0:
		p_dash_timer = P_DASH_TIME
		p_state = PState.DASH

	# --- MOVEMENT ---
	if p_dash_timer > 0:
		p_dash_timer -= delta
		p_vel.x = p_facing * P_DASH_SPEED
		if p_dash_timer <= 0:
			p_state = PState.IDLE if p_on_ground else PState.FALL
	elif p_wall_jump_lock > 0:
		pass  # don't override wall jump velocity
	else:
		p_vel.x = mx * P_SPEED

	# --- JUMP ---
	if p_jump_buffer > 0:
		if p_on_ground or p_coyote > 0:
			p_vel.y = P_JUMP
			p_on_ground = false
			p_coyote = 0
			p_jump_buffer = 0
			p_state = PState.JUMP
		elif p_on_wall != 0:
			# Wall jump
			p_vel.y = P_JUMP * 0.9
			p_vel.x = -p_on_wall * P_WALL_JUMP_X
			p_facing = -p_on_wall
			p_wall_jump_lock = 0.15
			p_on_wall = 0
			p_jump_buffer = 0
			p_state = PState.WALL_JUMP

	# Variable jump height
	if Input.is_action_just_released("jump") and p_vel.y < 0:
		p_vel.y *= 0.45

	# --- SHOOT ---
	if Input.is_action_just_pressed("shoot"):
		_player_shoot()
	if Input.is_action_pressed("shoot"):
		p_charge += delta
	elif p_charge > 0:
		if p_charge > 0.8:
			_player_charge_shot()
		p_charge = 0.0

	# --- TAG SWITCH ---
	if Input.is_action_just_pressed("pause"):
		_tag_switch()

func _physics_player(delta: float) -> void:
	# Gravity
	if not p_on_ground:
		var grav_scale = 0.4 if p_on_wall != 0 and p_vel.y > 0 else 1.0
		p_vel.y += GRAVITY * grav_scale * delta
		p_vel.y = minf(p_vel.y, MAX_FALL if p_on_wall == 0 else P_WALL_SLIDE_SPEED)

	# Move X
	var new_x = p_pos.x + p_vel.x * delta
	var blocked_x = false
	for plat in platforms:
		if _box_overlap(new_x - 5, p_pos.y - 24, 10, 22, plat.x, plat.y, plat.z, plat.w):
			blocked_x = true
			if p_vel.x > 0: new_x = plat.x - 5
			else: new_x = plat.x + plat.z + 5
			p_vel.x = 0
			break
	p_pos.x = new_x

	# Move Y
	var old_y = p_pos.y
	var new_y = p_pos.y + p_vel.y * delta
	var was_on_ground = p_on_ground
	p_on_ground = false

	for plat in platforms:
		# Landing on top
		if p_vel.y >= 0 and _box_overlap(p_pos.x - 5, new_y - 2, 10, 4, plat.x, plat.y, plat.z, plat.w):
			if old_y <= plat.y + 2:
				new_y = plat.y
				p_vel.y = 0
				p_on_ground = true
				break
		# Head bump
		if p_vel.y < 0 and _box_overlap(p_pos.x - 4, new_y - 26, 8, 4, plat.x, plat.y, plat.z, plat.w):
			new_y = plat.y + plat.w + 26
			p_vel.y = 0

	p_pos.y = new_y

	# Coyote time
	if was_on_ground and not p_on_ground and p_vel.y >= 0:
		p_coyote = P_COYOTE_TIME

	# Wall detection
	p_on_wall = 0
	if not p_on_ground and p_vel.y > 0:
		for plat in platforms:
			# Right wall
			if _box_overlap(p_pos.x + 5, p_pos.y - 20, 3, 16, plat.x, plat.y, plat.z, plat.w):
				if Input.get_axis("move_left", "move_right") > 0.5:
					p_on_wall = 1
					p_facing = -1
					break
			# Left wall
			if _box_overlap(p_pos.x - 8, p_pos.y - 20, 3, 16, plat.x, plat.y, plat.z, plat.w):
				if Input.get_axis("move_left", "move_right") < -0.5:
					p_on_wall = -1
					p_facing = 1
					break

	# Update state
	if p_on_ground:
		p_on_wall = 0
		if p_dash_timer > 0: p_state = PState.DASH
		elif absf(p_vel.x) > 10: p_state = PState.WALK
		else: p_state = PState.IDLE
	elif p_on_wall != 0:
		p_state = PState.WALL_SLIDE
	elif p_vel.y < 0:
		p_state = PState.JUMP
	else:
		p_state = PState.FALL

	# Pit death
	if p_pos.y > SH + 40: _player_die()
	# Level bounds
	p_pos.x = clampf(p_pos.x, 6, level_width - 6)

func _player_shoot() -> void:
	if p_shoot_timer > 0: return
	p_shoot_timer = 0.18
	var dir = p_facing
	match active_char:
		0:  # Axl — rapid fire pistol
			projectiles.append({"pos":Vector2(p_pos.x+dir*10,p_pos.y-14),"vel":Vector2(dir*320,0),"friendly":true,"dmg":1,"life":0.6,"size":2,"color":Color(1,0.9,0.3)})
		1:  # Zero — Z-saber slash (melee arc)
			p_shoot_timer = 0.3
			# Saber is a short-range wide hitbox
			projectiles.append({"pos":Vector2(p_pos.x+dir*14,p_pos.y-14),"vel":Vector2(dir*80,0),"friendly":true,"dmg":3,"life":0.15,"size":10,"color":Color(0.3,1.0,0.4)})
			effects.append({"pos":Vector2(p_pos.x+dir*14,p_pos.y-14),"type":"saber","timer":0.2,"dir":dir})
		2:  # X — buster lemon
			projectiles.append({"pos":Vector2(p_pos.x+dir*10,p_pos.y-14),"vel":Vector2(dir*280,0),"friendly":true,"dmg":1,"life":0.8,"size":3,"color":Color(0.4,0.7,1.0)})

func _player_charge_shot() -> void:
	p_shoot_timer = 0.25
	var dir = p_facing
	match active_char:
		0:  # Axl — copy shot (bigger blast)
			projectiles.append({"pos":Vector2(p_pos.x+dir*10,p_pos.y-14),"vel":Vector2(dir*250,0),"friendly":true,"dmg":3,"life":0.8,"size":7,"color":Color(1,0.8,0.2)})
		1:  # Zero — double saber
			projectiles.append({"pos":Vector2(p_pos.x+dir*16,p_pos.y-18),"vel":Vector2(dir*60,0),"friendly":true,"dmg":4,"life":0.2,"size":14,"color":Color(0.5,1.0,0.5)})
			projectiles.append({"pos":Vector2(p_pos.x+dir*16,p_pos.y-8),"vel":Vector2(dir*60,0),"friendly":true,"dmg":4,"life":0.2,"size":14,"color":Color(0.3,0.9,0.4)})
			effects.append({"pos":Vector2(p_pos.x+dir*14,p_pos.y-14),"type":"saber_big","timer":0.25,"dir":dir})
		2:  # X — charge shot
			projectiles.append({"pos":Vector2(p_pos.x+dir*10,p_pos.y-14),"vel":Vector2(dir*220,0),"friendly":true,"dmg":4,"life":1.0,"size":10,"color":Color(0.5,0.85,1.0)})
	effects.append({"pos":Vector2(p_pos.x+dir*8,p_pos.y-14),"type":"charge_flash","timer":0.15})

func _player_die() -> void:
	char_alive[active_char] = false
	char_hp[active_char] = 0
	p_vel = Vector2(0, -200)
	p_anim = 0.0
	# Try to switch to tag partner
	if char_alive[tag_char]:
		# Partner takes over after death animation
		pass  # handled in game over check

func _tag_switch() -> void:
	if not char_alive[tag_char]: return
	var temp = active_char
	active_char = tag_char
	tag_char = temp
	# Tag flash effect
	effects.append({"pos":p_pos + Vector2(0,-12),"type":"tag_flash","timer":0.3})

func _collisions_player() -> void:
	if p_invuln > 0: return

	# Enemy projectiles + contact
	for i in range(projectiles.size()-1,-1,-1):
		var p = projectiles[i]
		if p["friendly"]:
			# vs enemies
			for e in enemies:
				if not e["alive"]: continue
				if p["pos"].distance_to(e["pos"]) < e.get("radius", 10):
					e["hp"] -= p["dmg"]
					effects.append({"pos":e["pos"],"type":"hit","timer":0.12})
					if e["hp"] <= 0:
						e["alive"] = false
						effects.append({"pos":e["pos"],"type":"explode","timer":0.4})
						if randf() < 0.25:
							items.append({"pos":e["pos"],"type":"hp_sm"})
					projectiles.remove_at(i)
					break
		else:
			if p["pos"].distance_to(p_pos+Vector2(0,-12)) < 10:
				_take_damage(p["dmg"])
				projectiles.remove_at(i)

	for e in enemies:
		if not e["alive"]: continue
		if p_pos.distance_to(e["pos"]+Vector2(0,4)) < 14:
			_take_damage(e.get("contact_dmg", 3))

	# Items
	for i in range(items.size()-1,-1,-1):
		var it = items[i]
		if p_pos.distance_to(it["pos"]) < 14:
			match it["type"]:
				"hp_sm": char_hp[active_char] = mini(char_hp[active_char]+4, char_max_hp[active_char])
				"hp_lg": char_hp[active_char] = mini(char_hp[active_char]+8, char_max_hp[active_char])
				"reploid":
					reploids_rescued += 1
					if reploids_rescued >= REPLOIDS_TO_UNLOCK and not x_unlocked:
						x_unlocked = true
						effects.append({"pos":p_pos,"type":"unlock_x","timer":2.0})
				"life": pass
			items.remove_at(i)

func _take_damage(dmg: int) -> void:
	if p_invuln > 0: return
	char_hp[active_char] -= dmg
	p_invuln = 1.2
	p_vel.x = -p_facing * 80
	p_vel.y = -100
	effects.append({"pos":p_pos+Vector2(0,-12),"type":"hit","timer":0.15})
	if char_hp[active_char] <= 0:
		_player_die()

func _update_enemies(delta: float) -> void:
	for e in enemies:
		if not e["alive"]: continue
		e["anim"] += delta
		var sx = e["pos"].x - cam_x
		if sx < -100 or sx > SW + 100: continue  # skip offscreen

		match e["ai"]:
			"walk":
				e["pos"].x += e["dir"] * e["spd"] * delta
				# Simple ground check: keep on platforms
				var on_floor = false
				for plat in platforms:
					if _box_overlap(e["pos"].x-4, e["pos"].y, 8, 4, plat.x, plat.y, plat.z, plat.w):
						e["pos"].y = plat.y
						on_floor = true
						break
				if not on_floor:
					e["pos"].y += 200 * delta
				# Turn at edges/walls
				if absf(e["pos"].x - e["home"]) > e["range"]:
					e["dir"] *= -1
			"fly":
				e["pos"].x += e["dir"] * e["spd"] * delta
				e["pos"].y = e["base_y"] + sin(e["anim"]*2.5) * 20
				if absf(e["pos"].x - e["home"]) > e["range"]:
					e["dir"] *= -1
			"turret":
				if fmod(e["anim"], 2.0) < delta:
					var d = (p_pos+Vector2(0,-12) - e["pos"]).normalized()
					projectiles.append({"pos":e["pos"],"vel":d*140,"friendly":false,"dmg":2,"life":2.0,"size":3,"color":Color(1,0.3,0.3)})

func _update_projectiles(delta: float) -> void:
	for i in range(projectiles.size()-1,-1,-1):
		var p = projectiles[i]
		p["pos"] += p["vel"] * delta
		p["life"] -= delta
		var hit_wall = false
		if p["friendly"]:
			for plat in platforms:
				if _box_overlap(p["pos"].x-2,p["pos"].y-2,4,4,plat.x,plat.y,plat.z,plat.w):
					hit_wall = true
					break
		if p["life"] <= 0 or hit_wall or p["pos"].x < cam_x-20 or p["pos"].x > cam_x+SW+20 or p["pos"].y < -20 or p["pos"].y > SH+20:
			if hit_wall: effects.append({"pos":p["pos"],"type":"spark","timer":0.1})
			projectiles.remove_at(i)

func _update_effects(delta: float) -> void:
	for i in range(effects.size()-1,-1,-1):
		effects[i]["timer"] -= delta
		if effects[i]["timer"] <= 0: effects.remove_at(i)

func _update_camera(delta: float) -> void:
	cam_target_x = p_pos.x - SW * 0.35
	cam_x = lerpf(cam_x, cam_target_x, 5.0 * delta)
	cam_x = clampf(cam_x, 0, maxf(0, level_width - SW))

func _tick_gameover(delta: float) -> void:
	title_timer += delta
	if Input.is_action_just_pressed("jump"):
		# Revive at checkpoint
		_build_stage(current_stage)
		state = State.PLAYING

func _box_overlap(ax:float,ay:float,aw:float,ah:float,bx:float,by:float,bw:float,bh:float) -> bool:
	return ax<bx+bw and ax+aw>bx and ay<by+bh and ay+ah>by

# ================================================================
# STAGE BUILDER
# ================================================================
func _build_stage(idx: int) -> void:
	platforms.clear(); enemies.clear(); projectiles.clear(); effects.clear(); items.clear()
	var seed_v = idx * 9973 + 42

	level_width = 4800 + idx * 400
	# Ground
	var gx = 0.0
	while gx < level_width:
		# Create gaps
		var gap = false
		for g in range(3 + idx):
			var gap_start = 800.0 + g * (level_width / (4+idx))
			if gx >= gap_start and gx < gap_start + 64 + idx * 8:
				gap = true
		if not gap:
			platforms.append(Vector4(gx, 192, TILE, 32))
		gx += TILE

	# Platforms
	var num_plats = 15 + idx * 3
	for i in range(num_plats):
		var px = 200.0 + float(i) * (level_width - 400) / num_plats + float((seed_v+i*137)%80) - 40
		var py = 100.0 + float((seed_v+i*91)%80)
		var pw = 48.0 + float((seed_v+i*53)%64)
		platforms.append(Vector4(px, py, pw, 12))

	# Walls
	for i in range(5 + idx):
		var wx = 600.0 + float(i) * (level_width - 800) / (5+idx)
		platforms.append(Vector4(wx, 80, 16, 112))

	# Enemies
	var num_en = 12 + idx * 4
	for i in range(num_en):
		var ex = 300.0 + float(i) * (level_width - 600) / num_en
		var etype = ["walk","walk","walk","fly","fly","turret"][(seed_v+i*7)%6]
		var ey = 180.0 if etype == "walk" else (100.0 + float((seed_v+i*41)%60)) if etype == "fly" else 170.0
		enemies.append({
			"pos":Vector2(ex,ey),"ai":etype,"hp":2+idx/3,"alive":true,
			"dir": 1.0 if (seed_v+i)%2==0 else -1.0,
			"spd": 35.0+float(idx)*5, "home":ex, "range": 60.0+float((seed_v+i*23)%60),
			"anim":0.0, "base_y":ey, "radius": 10, "contact_dmg": 3
		})

	# Reploids to rescue (scattered)
	for i in range(4 + idx):
		var rx = 400.0 + float(i) * (level_width - 800) / (4+idx)
		items.append({"pos":Vector2(rx, 176), "type":"reploid"})

	# Health pickups
	for i in range(3):
		var hx = 500.0 + float(i) * level_width / 4
		items.append({"pos":Vector2(hx, 120), "type":"hp_lg"})

	# Reset player
	p_pos = Vector2(40, 160); p_vel = Vector2.ZERO; p_on_ground = true
	p_state = PState.IDLE; p_invuln = 0; p_charge = 0; p_anim = 0
	char_hp[active_char] = char_max_hp[active_char]
	char_alive = [true, true, true]
	cam_x = 0

# ================================================================
# DRAWING
# ================================================================
func _draw() -> void:
	match state:
		State.TITLE: _draw_title()
		State.SELECT: _draw_select()
		State.PLAYING: _draw_stage()
		State.GAME_OVER: _draw_gameover()

# --- TITLE ---
func _draw_title() -> void:
	draw_rect(Rect2(0,0,SW,SH), Color(0.02,0.02,0.06))
	# Stars
	for i in range(60):
		var sx = fmod(i*137.5+title_timer*3,float(SW))
		var sy = fmod(i*91.3,float(SH))
		draw_rect(Rect2(sx,sy,1,1), Color(1,1,1,0.3+sin(title_timer*2+i)*0.2))
	# Logo
	_draw_text(100, 50, "MEGA MAN X7", 20, Color(0.3,0.6,1))
	_draw_text(150, 75, "16-BIT", 13, Color(0.7,0.7,0.8))
	# Characters
	_draw_axl_sprite(130, 155, 1, false)
	_draw_zero_sprite(185, 155, 1, false)
	_draw_x_sprite(240, 155, 1, false)
	# Labels
	_draw_text(120, 172, "AXL", 7, Color(0.8,0.5,0.2))
	_draw_text(175, 172, "ZERO", 7, Color(0.9,0.2,0.2))
	_draw_text(235, 172, "X", 7, Color(0.3,0.6,1) if x_unlocked else Color(0.3,0.3,0.3))
	if not x_unlocked:
		_draw_text(225, 182, "LOCKED", 6, Color(0.4,0.4,0.4))
	if fmod(title_timer,1.0) < 0.6:
		_draw_text(140, 205, "PRESS START", 11, Color.WHITE)

# --- STAGE SELECT ---
func _draw_select() -> void:
	draw_rect(Rect2(0,0,SW,SH), Color(0.04,0.04,0.12))
	_draw_text(130,18, "STAGE SELECT", 12, Color(0.8,0.8,0.8))
	for i in range(8):
		var gx = 25+(i%4)*95
		var gy = 35+(i/4)*85
		var sel = i == stage_cursor
		draw_rect(Rect2(gx,gy,78,68), Color(0.07,0.07,0.10))
		draw_rect(Rect2(gx,gy,78,68), Color(1,1,0) if sel else Color(0.25,0.25,0.3), false, 2 if sel else 1)
		if not stages_clear[i]:
			# Maverick portrait (colored face)
			var cx = gx+39; var cy = gy+28
			draw_circle(Vector2(cx,cy),14, stage_colors[i])
			draw_circle(Vector2(cx,cy-1),12, Color(stage_colors[i].r*1.2,stage_colors[i].g*1.2,stage_colors[i].b*1.2).clamp())
			# Eyes
			draw_rect(Rect2(cx-5,cy-4,3,3),Color.WHITE); draw_rect(Rect2(cx+2,cy-4,3,3),Color.WHITE)
			draw_rect(Rect2(cx-4,cy-3,2,2),Color.BLACK); draw_rect(Rect2(cx+3,cy-3,2,2),Color.BLACK)
			# Mouth
			draw_rect(Rect2(cx-3,cy+3,6,2), Color(stage_colors[i].r*0.6,stage_colors[i].g*0.6,stage_colors[i].b*0.6))
		else:
			_draw_text(gx+22,gy+34, "CLEAR", 9, Color(0.4,0.4,0.4))
		_draw_text(gx+3,gy+62, stage_names[i], 6, Color(0.65,0.65,0.75))
	_draw_text(15,210, "TAG: %s + %s" % [char_names[active_char],char_names[tag_char]], 8, Color(0.6,0.6,0.7))
	_draw_text(250,210, "REPLOIDS: %d/%d" % [reploids_rescued,REPLOIDS_TO_UNLOCK], 8, Color(0.6,0.8,0.6))

# --- GAMEPLAY ---
func _draw_stage() -> void:
	var cx = cam_x
	# BG
	draw_rect(Rect2(0,0,SW,SH), Color(0.08,0.06,0.18))
	# Parallax city
	for i in range(20):
		var bx = fmod(i*280-cx*0.2+5600,5600.0)-280
		if bx < -100 or bx > SW+100: continue
		var bh = 30+((i*37)%50)
		draw_rect(Rect2(bx,192-bh,50,bh), Color(0.05,0.04,0.14))
		for wy in range(0,int(bh)-8,10):
			for wx in [8,20,32]:
				draw_rect(Rect2(bx+wx,192-bh+wy+4,5,4), Color(0.6,0.5,0.2,0.3) if (i+wy+wx)%3!=0 else Color(0.03,0.02,0.08))

	# Platforms
	for plat in platforms:
		var px = plat.x - cx
		if px < -20 or px > SW+20: continue
		if plat.w > 20:
			# Wall
			draw_rect(Rect2(px,plat.y,plat.z,plat.w), Color(0.22,0.20,0.32))
			draw_rect(Rect2(px+1,plat.y,plat.z-2,2), Color(0.35,0.30,0.45))
		elif plat.y >= 180:
			# Ground
			draw_rect(Rect2(px,plat.y,plat.z,plat.w), Color(0.20,0.18,0.28))
			draw_rect(Rect2(px,plat.y,plat.z,2), Color(0.32,0.28,0.42))
		else:
			# Platform
			draw_rect(Rect2(px,plat.y,plat.z,plat.w), Color(0.28,0.24,0.38))
			draw_rect(Rect2(px,plat.y,plat.z,2), Color(0.42,0.36,0.52))

	# Items
	for it in items:
		var ix = it["pos"].x - cx
		if ix < -10 or ix > SW+10: continue
		_draw_item_sprite(ix, it["pos"].y, it["type"])

	# Enemies
	for e in enemies:
		if not e["alive"]: continue
		var ex = e["pos"].x - cx
		if ex < -20 or ex > SW+20: continue
		_draw_enemy_sprite(ex, e["pos"].y, e["ai"], e["anim"], e["dir"])

	# Projectiles
	for p in projectiles:
		var px = p["pos"].x - cx
		if px < -10 or px > SW+10: continue
		draw_circle(Vector2(px,p["pos"].y), p["size"], p["color"])
		draw_circle(Vector2(px,p["pos"].y), p["size"]+1, Color(p["color"].r,p["color"].g,p["color"].b,0.25))

	# Effects
	for e in effects:
		var ex = e["pos"].x - cx
		match e["type"]:
			"explode":
				var r = (0.4-e["timer"])*28
				draw_circle(Vector2(ex,e["pos"].y),r,Color(1,0.6,0.1,e["timer"]*2.5))
				draw_circle(Vector2(ex,e["pos"].y),r*0.5,Color(1,1,0.8,e["timer"]*2.5))
			"hit","spark":
				draw_circle(Vector2(ex,e["pos"].y),4,Color(1,1,1,e["timer"]*8))
			"charge_flash":
				draw_circle(Vector2(ex,e["pos"].y),12,Color(0.5,1,0.8,e["timer"]*5))
			"saber":
				var d = e.get("dir",1)
				var t = 1.0 - e["timer"]/0.2
				draw_arc(Vector2(ex+d*4,e["pos"].y), 16, -PI*0.4+t*PI*0.4, PI*0.4+t*PI*0.4, 8, Color(0.3,1,0.4,e["timer"]*4), 3)
			"saber_big":
				var d = e.get("dir",1)
				var t = 1.0 - e["timer"]/0.25
				draw_arc(Vector2(ex+d*4,e["pos"].y), 20, -PI*0.5+t*PI*0.3, PI*0.5+t*PI*0.3, 10, Color(0.4,1,0.5,e["timer"]*3), 4)
			"tag_flash":
				draw_circle(Vector2(ex,e["pos"].y),20*e["timer"],Color(1,1,1,e["timer"]*2))

	# Player
	if char_alive[active_char]:
		var px = p_pos.x - cx
		if p_invuln > 0 and fmod(p_invuln,0.14) > 0.07:
			pass  # blink
		else:
			var is_moving = absf(p_vel.x) > 10
			match active_char:
				0: _draw_axl_sprite(px, p_pos.y, p_facing, is_moving)
				1: _draw_zero_sprite(px, p_pos.y, p_facing, is_moving)
				2: _draw_x_sprite(px, p_pos.y, p_facing, is_moving)
			# Charge glow
			if p_charge > 0.3:
				var a = minf(p_charge,1.0)*0.35
				var cc = Color(1,0.8,0.2,a) if active_char==0 else Color(0.3,1,0.4,a) if active_char==1 else Color(0.4,0.7,1,a)
				draw_circle(Vector2(px,p_pos.y-12),14,cc)
			# Wall slide dust
			if p_on_wall != 0:
				for i in range(3):
					var dy = sin(p_anim*8+i*2)*4
					draw_rect(Rect2(px+p_on_wall*6,p_pos.y-20+i*6+dy,2,2),Color(0.7,0.7,0.7,0.4))
			# Dash afterimage
			if p_dash_timer > 0:
				draw_circle(Vector2(px-p_facing*8,p_pos.y-12),6,Color(1,1,1,p_dash_timer*0.5))
	else:
		# Death explosion
		var px = p_pos.x - cx
		if p_anim < 1.5:
			for i in range(8):
				var a = i*TAU/8 + p_anim*3
				var r = p_anim * 30
				draw_circle(Vector2(px+cos(a)*r, p_pos.y-12+sin(a)*r), 3-p_anim, Color(1,0.5+sin(a)*0.3,0.1,1.5-p_anim))

	# HUD
	_draw_hud()

# --- ANIMATION STATE HELPER ---
func _get_anim_name(moving: bool) -> String:
	var shooting = p_shoot_timer > 0
	match p_state:
		PState.IDLE:
			return "idle_shoot" if shooting else "idle"
		PState.WALK:
			return "walk_shoot" if shooting else "walk"
		PState.DASH:
			return "dash_shoot" if shooting else "dash"
		PState.JUMP:
			return "jump_shoot" if shooting else "jump"
		PState.FALL:
			return "jump_shoot" if shooting else "fall"
		PState.WALL_SLIDE:
			return "wall_slide"
		PState.WALL_JUMP:
			return "wall_jump"
		PState.HURT:
			return "hurt"
		PState.DEAD:
			return "death"
		PState.LADDER:
			return "ladder_shoot" if shooting else "ladder"
	return "idle"

# --- CHARACTER SPRITES ---
func _draw_axl_sprite(x:float, y:float, dir:int, moving:bool) -> void:
	var flip = dir < 0
	var anim_name = _get_anim_name(moving)
	SpriteRenderer.draw_character(self, 0, x, y + 6, anim_name, p_anim, flip)
	return

func _draw_axl_sprite_OLD(x:float, y:float, dir:int, moving:bool) -> void:
	var bob = sin(p_anim*8)*1 if moving else 0
	var step = sin(p_anim*10)*2 if moving else 0
	var d = float(dir)
	# Shadow
	draw_circle(Vector2(x,y+6),5,Color(0,0,0,0.2))
	# Boots (dark with white side boosters)
	draw_rect(Rect2(x-4+step,y+1,3,5), Color(0.12,0.12,0.22))
	draw_rect(Rect2(x+1-step,y+1,3,5), Color(0.12,0.12,0.22))
	draw_rect(Rect2(x-5+step,y+2,1,3), Color(0.85,0.85,0.9))
	draw_rect(Rect2(x+4-step,y+2,1,3), Color(0.85,0.85,0.9))
	# Legs (dark with red stripe)
	draw_rect(Rect2(x-3+step*0.5,y-3+bob,2,5), Color(0.12,0.12,0.22))
	draw_rect(Rect2(x+1-step*0.5,y-3+bob,2,5), Color(0.12,0.12,0.22))
	draw_rect(Rect2(x-3+step*0.5,y-3+bob,1,5), Color(0.8,0.2,0.15))
	# Body (dark blue-black, red accents)
	draw_rect(Rect2(x-5,y-10+bob,10,8), Color(0.15,0.15,0.25))
	draw_rect(Rect2(x-4,y-9+bob,8,6), Color(0.20,0.20,0.30))
	draw_rect(Rect2(x-4,y-10+bob,8,1), Color(0.8,0.2,0.15))  # red line
	# Blue chest crystal
	draw_rect(Rect2(x-1,y-7+bob,2,2), Color(0.3,0.55,0.9))
	# Pointed shoulder pads
	draw_rect(Rect2(x-7,y-9+bob,3,4), Color(0.12,0.12,0.22))
	draw_rect(Rect2(x+4,y-9+bob,3,4), Color(0.12,0.12,0.22))
	draw_rect(Rect2(x-7,y-10+bob,1,1), Color(0.9,0.8,0.25))  # yellow tip
	draw_rect(Rect2(x+6,y-10+bob,1,1), Color(0.9,0.8,0.25))
	# Buster arm when shooting
	if p_shoot_timer > 0 and active_char == 0:
		draw_rect(Rect2(x+d*6,y-8+bob,d*6,3), Color(0.15,0.15,0.25))
		draw_rect(Rect2(x+d*10,y-9+bob,d*4,4), Color(0.45,0.45,0.5))
	# Neck
	draw_rect(Rect2(x-1,y-12+bob,3,2), Color(0.95,0.82,0.7))
	# Helmet (dark, red A-decal)
	draw_rect(Rect2(x-5,y-18+bob,10,6), Color(0.15,0.15,0.25))
	draw_rect(Rect2(x-4,y-19+bob,8,2), Color(0.20,0.20,0.30))
	# Red A-decal
	draw_rect(Rect2(x-3,y-19+bob,1,1), Color(0.8,0.2,0.15))
	draw_rect(Rect2(x+2,y-19+bob,1,1), Color(0.8,0.2,0.15))
	# Head crystal (blue)
	draw_rect(Rect2(x-1,y-19+bob,2,2), Color(0.3,0.55,0.9))
	# Auburn hair spikes (back of helmet)
	draw_rect(Rect2(x-d*4,y-17+bob,2,3), Color(0.7,0.35,0.15))
	draw_rect(Rect2(x-d*5,y-18+bob,2,2), Color(0.7,0.35,0.15))
	draw_rect(Rect2(x-d*6,y-16+bob,1,2), Color(0.6,0.30,0.12))
	# Face (youthful, green eyes)
	draw_rect(Rect2(x-3+d,y-15+bob,5,3), Color(0.95,0.82,0.7))
	draw_rect(Rect2(x-2+d,y-15+bob,2,2), Color.WHITE)
	draw_rect(Rect2(x+1+d,y-15+bob,2,2), Color.WHITE)
	draw_rect(Rect2(x-1+d,y-14+bob,1,1), Color(0.15,0.65,0.25))  # green eye
	draw_rect(Rect2(x+2+d,y-14+bob,1,1), Color(0.15,0.65,0.25))
	draw_rect(Rect2(x-1+d,y-13+bob,3,1), Color(0.85,0.70,0.60))  # mouth

func _draw_zero_sprite(x:float, y:float, dir:int, moving:bool) -> void:
	var flip = dir < 0
	var anim_name = _get_anim_name(moving)
	SpriteRenderer.draw_character(self, 1, x, y + 6, anim_name, p_anim, flip)
	# Saber effect when slashing
	if p_shoot_timer > 0 and active_char == 1:
		var d = float(dir)
		var t = p_shoot_timer / 0.3
		draw_arc(Vector2(x+d*6, y-12), 18, -0.5+t*0.5, 0.5+t*0.5, 8, Color(0.3,1,0.4, t), 3)
		draw_arc(Vector2(x+d*6, y-12), 20, -0.4+t*0.4, 0.4+t*0.4, 6, Color(0.7,1,0.8, t*0.4), 5)
	return

func _draw_zero_sprite_OLD(x:float, y:float, dir:int, moving:bool) -> void:
	var bob = sin(p_anim*8)*1 if moving else 0
	var step = sin(p_anim*10)*2 if moving else 0
	var d = float(dir)
	# Shadow
	draw_circle(Vector2(x,y+6),5,Color(0,0,0,0.2))
	# Boots (red with white trim)
	draw_rect(Rect2(x-4+step,y+1,3,5), Color(0.8,0.15,0.1))
	draw_rect(Rect2(x+1-step,y+1,3,5), Color(0.8,0.15,0.1))
	draw_rect(Rect2(x-4+step,y+1,3,1), Color(0.95,0.3,0.2))
	draw_rect(Rect2(x+1-step,y+1,3,1), Color(0.95,0.3,0.2))
	# Legs (red)
	draw_rect(Rect2(x-3+step*0.5,y-3+bob,2,5), Color(0.75,0.12,0.08))
	draw_rect(Rect2(x+1-step*0.5,y-3+bob,2,5), Color(0.75,0.12,0.08))
	# Body (red armor)
	draw_rect(Rect2(x-5,y-10+bob,10,8), Color(0.85,0.15,0.1))
	draw_rect(Rect2(x-4,y-9+bob,8,6), Color(0.95,0.25,0.15))
	# Blue chest crystal
	draw_rect(Rect2(x-1,y-7+bob,2,2), Color(0.3,0.5,0.9))
	# Z on chest
	draw_rect(Rect2(x-2,y-9+bob,4,1), Color(0.7,0.1,0.05))
	# Shoulder pads (big, red)
	draw_rect(Rect2(x-8,y-9+bob,4,5), Color(0.85,0.15,0.1))
	draw_rect(Rect2(x+4,y-9+bob,4,5), Color(0.85,0.15,0.1))
	draw_rect(Rect2(x-8,y-9+bob,4,1), Color(0.95,0.3,0.2))
	draw_rect(Rect2(x+4,y-9+bob,4,1), Color(0.95,0.3,0.2))
	# Saber arm when slashing
	if p_shoot_timer > 0 and active_char == 1:
		# Z-saber blade
		var saber_len = 14
		draw_line(Vector2(x+d*6,y-10+bob),Vector2(x+d*(6+saber_len),y-14+bob), Color(0.3,1,0.4), 3)
		draw_line(Vector2(x+d*6,y-10+bob),Vector2(x+d*(6+saber_len),y-14+bob), Color(0.7,1,0.8,0.5), 5)
	# Neck
	draw_rect(Rect2(x-1,y-12+bob,3,2), Color(0.95,0.82,0.7))
	# Helmet (red, blue gem, with fin shapes)
	draw_rect(Rect2(x-5,y-18+bob,10,6), Color(0.85,0.15,0.1))
	draw_rect(Rect2(x-4,y-19+bob,8,2), Color(0.95,0.25,0.15))
	# Helmet fins (triangular ear things)
	draw_rect(Rect2(x-6,y-17+bob,2,4), Color(0.85,0.15,0.1))
	draw_rect(Rect2(x+4,y-17+bob,2,4), Color(0.85,0.15,0.1))
	# Blue gem
	draw_rect(Rect2(x-1,y-19+bob,2,2), Color(0.3,0.5,0.9))
	draw_rect(Rect2(x,y-18+bob,1,1), Color(0.5,0.7,1))  # gem highlight
	# LONG BLONDE HAIR (Zero's signature — flows behind him)
	var hair_wave = sin(p_anim*3)*2
	for i in range(6):
		var hx = x - d*(3+i*2)
		var hy = y - 16 + i*3 + sin(p_anim*4+i*0.8)*2 + bob
		draw_rect(Rect2(hx,hy,3,3), Color(0.95,0.85,0.3))
	for i in range(4):
		var hx = x - d*(5+i*2)
		var hy = y - 10 + i*3 + sin(p_anim*4+i*0.8+1)*2 + bob
		draw_rect(Rect2(hx,hy,2,3), Color(0.90,0.78,0.25))
	# Face
	draw_rect(Rect2(x-3+d,y-15+bob,5,3), Color(0.95,0.82,0.7))
	draw_rect(Rect2(x-2+d,y-15+bob,2,2), Color.WHITE)
	draw_rect(Rect2(x+1+d,y-15+bob,2,2), Color.WHITE)
	draw_rect(Rect2(x-1+d,y-14+bob,1,1), Color(0.2,0.4,0.9))  # blue eyes
	draw_rect(Rect2(x+2+d,y-14+bob,1,1), Color(0.2,0.4,0.9))

func _draw_x_sprite(x:float, y:float, dir:int, moving:bool) -> void:
	var flip = dir < 0
	var anim_name = _get_anim_name(moving)
	SpriteRenderer.draw_character(self, 2, x, y + 6, anim_name, p_anim, flip)
	return

func _draw_x_sprite_OLD(x:float, y:float, dir:int, moving:bool) -> void:
	var bob = sin(p_anim*8)*1 if moving else 0
	var step = sin(p_anim*10)*2 if moving else 0
	var d = float(dir)
	# Shadow
	draw_circle(Vector2(x,y+6),5,Color(0,0,0,0.2))
	# Boots (blue with highlight)
	draw_rect(Rect2(x-4+step,y+1,3,5), Color(0.12,0.3,0.7))
	draw_rect(Rect2(x+1-step,y+1,3,5), Color(0.12,0.3,0.7))
	draw_rect(Rect2(x-4+step,y+1,3,1), Color(0.4,0.6,1))
	draw_rect(Rect2(x+1-step,y+1,3,1), Color(0.4,0.6,1))
	# Legs
	draw_rect(Rect2(x-3+step*0.5,y-3+bob,2,5), Color(0.15,0.35,0.8))
	draw_rect(Rect2(x+1-step*0.5,y-3+bob,2,5), Color(0.15,0.35,0.8))
	# Body
	draw_rect(Rect2(x-5,y-10+bob,10,8), Color(0.2,0.45,0.9))
	draw_rect(Rect2(x-4,y-9+bob,8,6), Color(0.3,0.55,0.95))
	# Red chest gem
	draw_rect(Rect2(x-1,y-7+bob,2,2), Color(0.9,0.15,0.15))
	# Shoulder pads
	draw_rect(Rect2(x-7,y-9+bob,3,4), Color(0.15,0.35,0.8))
	draw_rect(Rect2(x+4,y-9+bob,3,4), Color(0.15,0.35,0.8))
	draw_rect(Rect2(x-7,y-9+bob,3,1), Color(0.4,0.65,1))
	draw_rect(Rect2(x+4,y-9+bob,3,1), Color(0.4,0.65,1))
	# Buster
	if p_shoot_timer > 0 and active_char == 2:
		draw_rect(Rect2(x+d*6,y-9+bob,d*5,3), Color(0.2,0.45,0.9))
		draw_rect(Rect2(x+d*10,y-10+bob,d*4,5), Color(0.35,0.6,1))
		draw_rect(Rect2(x+d*11,y-9+bob,d*2,3), Color(0.5,0.75,1))
	# Neck
	draw_rect(Rect2(x-1,y-12+bob,3,2), Color(0.95,0.82,0.7))
	# Helmet
	draw_rect(Rect2(x-5,y-18+bob,10,6), Color(0.2,0.45,0.9))
	draw_rect(Rect2(x-4,y-19+bob,8,2), Color(0.35,0.6,1))
	# Helmet crest
	draw_rect(Rect2(x-2,y-20+bob,4,2), Color(0.35,0.6,1))
	draw_rect(Rect2(x-1,y-21+bob,2,1), Color(0.2,0.45,0.9))
	# Red gem
	draw_rect(Rect2(x-1,y-18+bob,2,2), Color(0.9,0.15,0.15))
	draw_rect(Rect2(x,y-17+bob,1,1), Color(1,0.4,0.4))  # highlight
	# Ear guards
	draw_rect(Rect2(x-6,y-16+bob,2,3), Color(0.15,0.35,0.8))
	draw_rect(Rect2(x+4,y-16+bob,2,3), Color(0.15,0.35,0.8))
	# Face
	draw_rect(Rect2(x-3+d,y-15+bob,5,3), Color(0.95,0.82,0.7))
	draw_rect(Rect2(x-2+d,y-15+bob,2,2), Color.WHITE)
	draw_rect(Rect2(x+1+d,y-15+bob,2,2), Color.WHITE)
	draw_rect(Rect2(x-1+d,y-14+bob,1,1), Color(0.1,0.5,0.15))  # green eyes
	draw_rect(Rect2(x+2+d,y-14+bob,1,1), Color(0.1,0.5,0.15))

# --- ENEMIES ---
func _draw_enemy_sprite(x:float, y:float, ai:String, anim:float, dir:float) -> void:
	draw_circle(Vector2(x,y+5),5,Color(0,0,0,0.15))
	match ai:
		"walk":
			# Metool — pixel art sprite
			var flip = dir < 0
			Sprites.draw_sprite(self, Sprites.METOOL_SPRITE, Sprites.MET_PAL, x, y + 2, flip)
		"fly":
			# Bat Bone — detailed with wing animation
			var wing = sin(anim*8)*4
			var bat_dk = Color(0.35,0.15,0.45)
			var bat_md = Color(0.50,0.25,0.60)
			var bat_lt = Color(0.65,0.38,0.75)
			# Wing membranes (left)
			for i in range(3):
				var wx = x - 4 - i*3
				var wy = y - 2 + wing + i*0.5
				draw_rect(Rect2(wx, wy, 3, 2), bat_md)
				draw_rect(Rect2(wx, wy-1, 1, 1), bat_lt)
			# Wing membranes (right)
			for i in range(3):
				var wx = x + 4 + i*3
				var wy = y - 2 - wing + i*0.5
				draw_rect(Rect2(wx, wy, 3, 2), bat_md)
				draw_rect(Rect2(wx+2, wy-1, 1, 1), bat_lt)
			# Wing tips (dark points)
			draw_rect(Rect2(x-13, y-2+wing, 2, 1), bat_dk)
			draw_rect(Rect2(x+11, y-2-wing, 2, 1), bat_dk)
			# Body
			draw_rect(Rect2(x-4, y-4, 8, 7), bat_dk)
			draw_rect(Rect2(x-3, y-3, 6, 5), bat_md)
			draw_rect(Rect2(x-2, y-3, 4, 3), bat_lt)
			# Ears (pointed)
			draw_rect(Rect2(x-3, y-6, 2, 3), bat_md)
			draw_rect(Rect2(x+1, y-6, 2, 3), bat_md)
			draw_rect(Rect2(x-3, y-7, 1, 1), bat_dk)
			draw_rect(Rect2(x+2, y-7, 1, 1), bat_dk)
			# Red eyes (glowing)
			draw_rect(Rect2(x-2, y-3, 2, 2), Color(1,0.15,0.15))
			draw_rect(Rect2(x+1, y-3, 2, 2), Color(1,0.15,0.15))
			draw_rect(Rect2(x-1, y-2, 1, 1), Color(1,0.5,0.5))  # eye highlight
			draw_rect(Rect2(x+2, y-2, 1, 1), Color(1,0.5,0.5))
			# Fangs
			draw_rect(Rect2(x-1, y+2, 1, 2), Color(0.95,0.95,0.95))
			draw_rect(Rect2(x+1, y+2, 1, 2), Color(0.95,0.95,0.95))
		"turret":
			# Cannon Mechaniloid — detailed turret
			var base_dk = Color(0.28,0.28,0.35)
			var base_md = Color(0.42,0.42,0.50)
			var base_lt = Color(0.55,0.55,0.62)
			var barrel = Color(0.50,0.50,0.58)
			# Base (with rivets and armor plates)
			draw_rect(Rect2(x-7, y-2, 14, 6), base_dk)
			draw_rect(Rect2(x-6, y-1, 12, 4), base_md)
			# Top dome
			draw_rect(Rect2(x-5, y-6, 10, 5), base_md)
			draw_rect(Rect2(x-4, y-7, 8, 2), base_lt)
			draw_rect(Rect2(x-3, y-8, 6, 1), base_md)
			# Armor plate lines
			draw_rect(Rect2(x-6, y-2, 12, 1), base_dk)
			draw_rect(Rect2(x-1, y-6, 2, 5), base_dk)
			# Rivets
			draw_rect(Rect2(x-5, y+1, 1, 1), base_lt)
			draw_rect(Rect2(x+4, y+1, 1, 1), base_lt)
			# Barrel (aims at player)
			var aim = (p_pos+Vector2(0,-12)-Vector2(x+cam_x,y)).normalized()
			var bx = aim.x * 10
			var by = aim.y * 10
			draw_line(Vector2(x, y-3), Vector2(x+bx, y-3+by), barrel, 3)
			draw_line(Vector2(x, y-3), Vector2(x+bx, y-3+by), base_lt, 1)
			# Muzzle
			draw_rect(Rect2(x+bx-1, y-4+by, 3, 3), base_lt)
			# Central eye (pulsing red)
			var eye_bright = 0.5 + sin(anim*4)*0.5
			draw_rect(Rect2(x-1, y-4, 2, 2), Color(1,0.2*eye_bright,0,eye_bright))
			draw_rect(Rect2(x, y-3, 1, 1), Color(1,0.6,0.3,eye_bright*0.5))

func _draw_item_sprite(x:float, y:float, type:String) -> void:
	var bob = sin(p_anim*3)*2
	match type:
		"hp_sm":
			draw_rect(Rect2(x-3,y-3+bob,6,6),Color(0.9,0.9,0.1))
			draw_rect(Rect2(x-1,y-2+bob,2,3),Color(0.1,0.1,0.1))
			draw_rect(Rect2(x-2,y-1+bob,4,1),Color(0.1,0.1,0.1))
		"hp_lg":
			draw_rect(Rect2(x-4,y-4+bob,8,8),Color(0.9,0.15,0.15))
			draw_rect(Rect2(x-1,y-3+bob,2,5),Color.WHITE)
			draw_rect(Rect2(x-3,y-1+bob,6,1),Color.WHITE)
		"reploid":
			draw_rect(Rect2(x-3,y-10+bob,6,10),Color(0.3,0.7,0.3))
			draw_rect(Rect2(x-2,y-13+bob,4,4),Color(0.9,0.8,0.7))
			draw_rect(Rect2(x-3,y-14+bob,6,2),Color(0.3,0.6,0.8))
			if fmod(p_anim,0.8)<0.5:
				_draw_text(x-3,y-18+bob,"HELP",6,Color(1,1,0))

# --- HUD ---
func _draw_hud() -> void:
	# Active char HP (MMX style vertical bar)
	draw_rect(Rect2(6,10,12,char_max_hp[active_char]*3+8),Color(0,0,0,0.65))
	_draw_text(7,18,char_names[active_char],6,Color.WHITE)
	for i in range(char_max_hp[active_char]):
		var hy = 22+(char_max_hp[active_char]-1-i)*3
		var filled = i < char_hp[active_char]
		var col = Color(0.2,0.7,1) if active_char!=1 else Color(0.9,0.3,0.2) if filled else Color(0.12,0.12,0.18)
		if active_char == 0 and filled: col = Color(0.8,0.5,0.2)
		if not filled: col = Color(0.12,0.12,0.18)
		draw_rect(Rect2(8,hy,8,2),col)

	# Tag partner HP
	draw_rect(Rect2(22,10,10,char_max_hp[tag_char]*3+8),Color(0,0,0,0.4))
	_draw_text(23,18,char_names[tag_char],5,Color(0.6,0.6,0.6))
	for i in range(char_max_hp[tag_char]):
		var hy = 22+(char_max_hp[tag_char]-1-i)*3
		var filled = i < char_hp[tag_char]
		draw_rect(Rect2(24,hy,6,2), Color(0.5,0.5,0.5) if filled else Color(0.1,0.1,0.15))

	# Reploid counter
	_draw_text(SW-85,16, "RESCUE:%d/%d"%[reploids_rescued,REPLOIDS_TO_UNLOCK], 6, Color(0.6,0.8,0.6))

	# Controls hint
	_draw_text(SW-120,SH-6, "X:shoot C:dash Z:jump ESC:tag", 5, Color(0.4,0.4,0.5))

func _draw_gameover() -> void:
	draw_rect(Rect2(0,0,SW,SH),Color(0,0,0))
	_draw_text(150,90,"GAME OVER",18,Color(0.8,0.2,0.2))
	if fmod(title_timer,1.0)<0.6:
		_draw_text(140,130,"PRESS START",11,Color(0.7,0.7,0.7))

func _draw_text(x:float,y:float,text:String,size:int,color:Color) -> void:
	draw_string(ThemeDB.fallback_font,Vector2(x,y),text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)
