extends Node2D

# ================================================================
# MAGENT METROID — Full Metroidvania
# 7 zones, custom suits, custom beams, bosses, exploration
# ================================================================

const SW = 400
const SH = 224
const TILE = 16
const GRAVITY = 520.0
const MAX_FALL = 300.0

enum GState { TITLE, PLAYING, PAUSE, MAP, GAMEOVER }

# --- GAME STATE ---
var state = GState.TITLE
var frame = 0
var title_timer = 0.0

# --- PLAYER ---
var p = {
	"pos": Vector2(80, 160),
	"vel": Vector2.ZERO,
	"facing": 1,
	"on_ground": true,
	"on_wall": 0,
	"hp": 99,
	"max_hp": 99,
	"missiles": 0,
	"max_missiles": 0,
	"supers": 0,
	"max_supers": 0,
	"pbombs": 0,
	"max_pbombs": 0,
	"anim": 0.0,
	"invuln": 0.0,
	"alive": true,
	"shooting": false,
	"shoot_timer": 0.0,
	"charge": 0.0,
	"dashing": false,
	"dash_timer": 0.0,
	"morphed": false,
	"morph_anim": 0.0,
	"speed_boost": 0.0,
	"aim_up": false,
}

# --- ITEMS COLLECTED ---
var items = {
	"morph_ball": false, "bombs": false, "spring_ball": false,
	"varia_suit": false, "gravity_suit": false, "cold_suit": false, "lava_suit": false,
	"hi_jump": false, "space_jump": false, "speed_booster": false, "screw_attack": false,
	"charge_beam": false, "ice_beam": false, "wave_beam": false,
	"spazer": false, "plasma_beam": false,
	"vertical_beam": false, "back_beam": false, "laser_beam": false,
	"grapple": false, "xray": false,
}

# --- CAMERA ---
var cam = Vector2.ZERO

# --- CURRENT ROOM ---
var current_zone = "surface"
var current_room = 0
var room_w = 400
var room_h = 224
var tiles = []  # 2D array of tile types
var enemies = []
var projectiles = []
var effects = []
var room_items = []  # uncollected items in current room
var doors = []

# --- WORLD MAP ---
var rooms_visited = {}
var items_collected = {}

# --- ZONE COLORS ---
var zone_bg = {
	"surface": Color(0.06, 0.06, 0.12),
	"jungle": Color(0.04, 0.08, 0.04),
	"tech": Color(0.06, 0.06, 0.08),
	"ice": Color(0.08, 0.10, 0.14),
	"lava": Color(0.10, 0.04, 0.02),
	"water": Color(0.04, 0.06, 0.12),
	"final": Color(0.08, 0.04, 0.08),
}

var zone_solid = {
	"surface": Color(0.30, 0.28, 0.38),
	"jungle": Color(0.20, 0.35, 0.18),
	"tech": Color(0.32, 0.32, 0.38),
	"ice": Color(0.55, 0.60, 0.70),
	"lava": Color(0.45, 0.22, 0.10),
	"water": Color(0.20, 0.30, 0.45),
	"final": Color(0.35, 0.18, 0.35),
}

var zone_detail = {
	"surface": Color(0.22, 0.20, 0.30),
	"jungle": Color(0.15, 0.28, 0.12),
	"tech": Color(0.25, 0.25, 0.30),
	"ice": Color(0.45, 0.50, 0.60),
	"lava": Color(0.35, 0.15, 0.06),
	"water": Color(0.15, 0.22, 0.35),
	"final": Color(0.28, 0.12, 0.28),
}

func _ready() -> void:
	_load_room_from_json(0)

func _process(delta: float) -> void:
	frame += 1
	match state:
		GState.TITLE: _tick_title(delta)
		GState.PLAYING: _tick_play(delta)
		GState.GAMEOVER:
			title_timer += delta
			if Input.is_action_just_pressed("jump"):
				state = GState.TITLE
	queue_redraw()

# ================================================================
# TITLE
# ================================================================
func _tick_title(delta: float) -> void:
	title_timer += delta
	if Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("shoot"):
		state = GState.PLAYING
		_load_room_from_json(0)

# ================================================================
# ROOM LOADING
# ================================================================
func _load_room_from_json(room_idx: int) -> void:
	# Load room data from the preloaded JSON
	var json_text = FileAccess.get_file_as_string("res://rooms.json")
	if json_text.is_empty():
		_generate_default_room()
		return

	var json = JSON.new()
	var err = json.parse(json_text)
	if err != OK:
		_generate_default_room()
		return

	var data = json.data
	var rooms_data = data.get("rooms", [])
	if room_idx >= rooms_data.size():
		_generate_default_room()
		return

	var rd = rooms_data[room_idx]
	current_zone = rd.get("zone", "surface")
	current_room = room_idx
	var ws = rd.get("widthScreens", 1)
	var hs = rd.get("heightScreens", 1)
	room_w = ws * TILE * 16
	room_h = hs * TILE * 16

	tiles = rd.get("tiles", [])
	enemies.clear()
	projectiles.clear()
	effects.clear()
	room_items.clear()
	doors.clear()

	# Load enemies
	for e in rd.get("enemies", []):
		enemies.append({
			"pos": Vector2(e.get("x", 8) * TILE, e.get("y", 8) * TILE),
			"type": e.get("type", "zoomer"),
			"hp": 10,
			"alive": true,
			"anim": randf() * 10,
			"dir": 1.0 if randf() > 0.5 else -1.0,
			"home_x": e.get("x", 8) * TILE,
		})

	# Load items
	for it in rd.get("items", []):
		var key = str(room_idx) + "_" + str(it.get("x", 0)) + "_" + str(it.get("y", 0))
		if not items_collected.has(key):
			room_items.append({
				"pos": Vector2(it.get("x", 8) * TILE, it.get("y", 8) * TILE),
				"type": it.get("type", "missile"),
				"key": key,
				"anim": 0.0,
			})

	# Load doors
	for d in rd.get("doors", []):
		doors.append({
			"pos": Vector2(d.get("x", 0) * TILE, d.get("y", 0) * TILE),
			"direction": d.get("direction", "right"),
			"target": d.get("target_room", ""),
		})

	# Set player position
	p.pos = Vector2(80, room_h - 48)
	p.vel = Vector2.ZERO
	p.on_ground = true

	rooms_visited[room_idx] = true

func _generate_default_room() -> void:
	# Fallback: generate a simple room
	var ws = 3
	var hs = 2
	room_w = ws * 16 * TILE
	room_h = hs * 16 * TILE
	tiles = []
	for y in range(hs * 16):
		var row = []
		for x in range(ws * 16):
			if y == 0 or y == hs * 16 - 1 or x == 0 or x == ws * 16 - 1:
				row.append("solid")
			elif y >= hs * 16 - 3:
				row.append("solid")
			else:
				row.append("air")
		tiles.append(row)

# ================================================================
# GAMEPLAY
# ================================================================
func _tick_play(delta: float) -> void:
	if not p.alive:
		p.anim += delta
		if p.anim > 2.0:
			state = GState.GAMEOVER
		return

	_input_player(delta)
	_physics_player(delta)
	_update_enemies(delta)
	_update_projectiles(delta)
	_update_effects(delta)
	_check_collisions()
	_update_camera(delta)

	p.anim += delta
	if p.invuln > 0: p.invuln -= delta
	if p.shoot_timer > 0: p.shoot_timer -= delta
	else: p.shooting = false
	if p.dash_timer > 0: p.dash_timer -= delta
	else: p.dashing = false

func _input_player(delta: float) -> void:
	if p.morphed:
		_input_morph(delta)
		return

	var mx = Input.get_axis("move_left", "move_right")
	if mx > 0: p.facing = 1
	elif mx < 0: p.facing = -1

	# Aim up
	p.aim_up = Input.is_action_pressed("aim_up")

	# Morph ball
	if Input.is_action_just_pressed("move_down") and p.on_ground and items.morph_ball:
		p.morphed = true
		p.morph_anim = 0.0
		return

	# Dash
	if Input.is_action_just_pressed("dash") and not p.dashing:
		p.dashing = true
		p.dash_timer = 0.35

	# Movement
	var speed = 110.0
	if items.speed_booster and absf(p.vel.x) > 100:
		p.speed_boost += delta
		if p.speed_boost > 1.0:
			speed = 220.0
	else:
		p.speed_boost = 0.0

	if p.dashing:
		p.vel.x = p.facing * 180.0
	else:
		p.vel.x = mx * speed

	# Jump
	if Input.is_action_just_pressed("jump"):
		if p.on_ground:
			var jump_force = -240.0
			if items.hi_jump: jump_force = -300.0
			p.vel.y = jump_force
			p.on_ground = false
		elif p.on_wall != 0:
			p.vel.y = -220.0
			p.vel.x = -p.on_wall * 140.0
			p.facing = -p.on_wall
			p.on_wall = 0
		elif items.space_jump and p.vel.y > 0:
			# Space jump: hold jump to keep bouncing
			if Input.is_action_pressed("jump"):
				p.vel.y = -220.0

	# Variable jump
	if Input.is_action_just_released("jump") and p.vel.y < 0:
		p.vel.y *= 0.45

	# Space jump hold-to-bounce
	if items.space_jump and not p.on_ground and p.vel.y > 20:
		if Input.is_action_pressed("jump"):
			p.vel.y = -200.0

	# Shoot
	if Input.is_action_just_pressed("shoot"):
		_player_shoot()
	if Input.is_action_pressed("shoot"):
		p.charge += delta
		# Laser beam: continuous fire while held
		if items.laser_beam and p.charge > 0.3:
			_laser_damage(delta)
	else:
		if p.charge > 0.8 and items.charge_beam:
			_player_charge_shot()
		p.charge = 0.0

func _input_morph(delta: float) -> void:
	var mx = Input.get_axis("move_left", "move_right")
	p.vel.x = mx * 70.0
	p.morph_anim += delta

	# Unmorph
	if Input.is_action_just_pressed("move_up") or Input.is_action_just_pressed("jump"):
		p.morphed = false
		p.pos.y -= 8

	# Bombs
	if Input.is_action_just_pressed("shoot") and items.bombs:
		projectiles.append({
			"pos": p.pos + Vector2(0, 4),
			"vel": Vector2.ZERO,
			"friendly": true,
			"type": "bomb",
			"dmg": 10,
			"life": 1.0,
			"size": 4,
		})

func _physics_player(delta: float) -> void:
	# Gravity
	if not p.on_ground:
		var grav_scale = 1.0
		if p.on_wall != 0 and p.vel.y > 0:
			grav_scale = 0.4  # wall slide
		p.vel.y += GRAVITY * grav_scale * delta
		p.vel.y = minf(p.vel.y, MAX_FALL if p.on_wall == 0 else 60.0)

	# Move X with collision
	var new_x = p.pos.x + p.vel.x * delta
	if not _tile_solid_at(new_x - 5, p.pos.y - 20) and not _tile_solid_at(new_x + 5, p.pos.y - 20) and not _tile_solid_at(new_x - 5, p.pos.y - 2) and not _tile_solid_at(new_x + 5, p.pos.y - 2):
		p.pos.x = new_x
	else:
		p.vel.x = 0

	# Move Y with collision
	var old_y = p.pos.y
	var new_y = p.pos.y + p.vel.y * delta
	var was_grounded = p.on_ground
	p.on_ground = false

	if p.vel.y >= 0:
		# Falling — check floor
		if _tile_solid_at(p.pos.x - 4, new_y) or _tile_solid_at(p.pos.x + 4, new_y):
			# Snap to tile top
			var ty = int(new_y / TILE) * TILE
			p.pos.y = ty
			p.vel.y = 0
			p.on_ground = true
		else:
			p.pos.y = new_y
	else:
		# Rising — check ceiling
		if _tile_solid_at(p.pos.x - 4, new_y - 24) or _tile_solid_at(p.pos.x + 4, new_y - 24):
			p.vel.y = 0
			p.pos.y = old_y
		else:
			p.pos.y = new_y

	# Wall detection
	p.on_wall = 0
	if not p.on_ground and p.vel.y > 0:
		if _tile_solid_at(p.pos.x + 7, p.pos.y - 12) and Input.get_axis("move_left", "move_right") > 0.5:
			p.on_wall = 1
			p.facing = -1
		elif _tile_solid_at(p.pos.x - 7, p.pos.y - 12) and Input.get_axis("move_left", "move_right") < -0.5:
			p.on_wall = -1
			p.facing = 1

	# Bounds
	p.pos.x = clampf(p.pos.x, 6, room_w - 6)
	if p.pos.y > room_h + 40:
		_player_die()

	# Door transitions
	if p.pos.x <= 2:
		_transition_room(-1)
	elif p.pos.x >= room_w - 2:
		_transition_room(1)

func _tile_solid_at(x: float, y: float) -> bool:
	var tx = int(x / TILE)
	var ty = int(y / TILE)
	if ty < 0 or ty >= tiles.size(): return false
	if tx < 0 or tx >= tiles[0].size(): return false
	var t = tiles[ty][tx]
	return t == "solid" or t == "solid_top" or t == "spike"

func _tile_at(x: float, y: float) -> String:
	var tx = int(x / TILE)
	var ty = int(y / TILE)
	if ty < 0 or ty >= tiles.size(): return "air"
	if tx < 0 or tx >= tiles[0].size(): return "air"
	return tiles[ty][tx]

func _transition_room(dir: int) -> void:
	var next = current_room + dir
	if next < 0: next = 0
	_load_room_from_json(next)
	if dir > 0:
		p.pos.x = 20
	else:
		p.pos.x = room_w - 20

func _player_shoot() -> void:
	if p.shoot_timer > 0: return
	p.shooting = true
	p.shoot_timer = 0.15

	var dir_x = p.facing
	var dir_y = 0
	if p.aim_up:
		dir_x = 0
		dir_y = -1

	var speed = 300.0
	var dmg = 5
	var color = Color(1, 0.9, 0.3)
	var sz = 3

	if items.wave_beam: color = Color(0.5, 0.3, 1.0)
	if items.ice_beam: color = Color(0.5, 0.9, 1.0)
	if items.plasma_beam:
		color = Color(0.3, 1.0, 0.5)
		dmg = 15
		sz = 5

	projectiles.append({
		"pos": p.pos + Vector2(dir_x * 12, -12 + dir_y * 8),
		"vel": Vector2(dir_x * speed, dir_y * speed),
		"friendly": true,
		"type": "beam",
		"dmg": dmg,
		"life": 0.6,
		"size": sz,
		"color": color,
	})

	# Vertical beam: also shoot up and down
	if items.vertical_beam and not p.aim_up:
		projectiles.append({"pos": p.pos + Vector2(0, -20), "vel": Vector2(0, -speed), "friendly": true, "type": "beam", "dmg": dmg, "life": 0.5, "size": sz, "color": color})
		projectiles.append({"pos": p.pos + Vector2(0, 4), "vel": Vector2(0, speed), "friendly": true, "type": "beam", "dmg": dmg, "life": 0.5, "size": sz, "color": color})

	# Back beam: also shoot backwards
	if items.back_beam:
		projectiles.append({"pos": p.pos + Vector2(-dir_x * 12, -12), "vel": Vector2(-dir_x * speed, 0), "friendly": true, "type": "beam", "dmg": dmg, "life": 0.5, "size": sz, "color": color})

func _player_charge_shot() -> void:
	p.shooting = true
	p.shoot_timer = 0.25
	var dir_x = p.facing
	var dmg = 20
	if items.plasma_beam: dmg = 40
	# Spazer + Plasma: 10% less damage
	if items.spazer and items.plasma_beam:
		dmg = int(dmg * 0.88)

	projectiles.append({
		"pos": p.pos + Vector2(dir_x * 12, -12),
		"vel": Vector2(dir_x * 220, 0),
		"friendly": true,
		"type": "charge",
		"dmg": dmg,
		"life": 1.0,
		"size": 10,
		"color": Color(0.5, 0.9, 1.0),
	})
	effects.append({"pos": p.pos + Vector2(dir_x * 8, -12), "type": "flash", "timer": 0.15})

func _laser_damage(delta: float) -> void:
	# Continuous laser — damage nearby enemies every frame
	for e in enemies:
		if not e.alive: continue
		var dx = e.pos.x - p.pos.x
		var dy = e.pos.y - (p.pos.y - 12)
		if p.aim_up:
			if absf(dx) < 12 and dy < 0 and dy > -120:
				e.hp -= 1
				if e.hp <= 0: _kill_enemy(e)
		else:
			if dx * p.facing > 0 and absf(dx) < 120 and absf(dy) < 16:
				e.hp -= 1
				if e.hp <= 0: _kill_enemy(e)

func _player_die() -> void:
	p.alive = false
	p.anim = 0.0
	p.vel = Vector2(0, -200)

func _take_damage(dmg: int) -> void:
	if p.invuln > 0: return
	p.hp -= dmg
	p.invuln = 1.0
	if p.hp <= 0:
		_player_die()

# ================================================================
# ENEMIES
# ================================================================
func _update_enemies(delta: float) -> void:
	for e in enemies:
		if not e.alive: continue
		e.anim += delta
		match e.type:
			"zoomer":
				e.pos.x += e.dir * 30 * delta
				if absf(e.pos.x - e.home_x) > 60:
					e.dir *= -1
			"ripper":
				e.pos.x += e.dir * 50 * delta
				if absf(e.pos.x - e.home_x) > 100:
					e.dir *= -1
			"sidehopper":
				e.pos.x += e.dir * 40 * delta
				if absf(e.pos.x - e.home_x) > 80:
					e.dir *= -1
				# Jump periodically
				if fmod(e.anim, 2.0) < delta:
					e.pos.y -= 2
			"skree":
				# Dive at player when close
				if absf(e.pos.x - p.pos.x) < 80:
					var d = (p.pos - e.pos).normalized()
					e.pos += d * 80 * delta
			"kihunter":
				e.pos.x += e.dir * 60 * delta
				e.pos.y += sin(e.anim * 3) * 30 * delta
				if absf(e.pos.x - e.home_x) > 120:
					e.dir *= -1
			"metroid":
				var d = (p.pos - e.pos).normalized()
				e.pos += d * 35 * delta

func _kill_enemy(e: Dictionary) -> void:
	e.alive = false
	effects.append({"pos": e.pos, "type": "explode", "timer": 0.4})
	# Drop item chance
	if randf() < 0.2:
		room_items.append({"pos": e.pos, "type": "energy_small", "key": "", "anim": 0.0})

# ================================================================
# PROJECTILES
# ================================================================
func _update_projectiles(delta: float) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var proj = projectiles[i]
		proj.pos += proj.vel * delta
		proj.life -= delta
		if proj.type == "bomb" and proj.life <= 0:
			effects.append({"pos": proj.pos, "type": "bomb_explode", "timer": 0.3})
			# Bomb jump
			if p.morphed and p.pos.distance_to(proj.pos) < 30:
				p.vel.y = -180
		var hit_wall = _tile_solid_at(proj.pos.x, proj.pos.y)
		if proj.life <= 0 or hit_wall or proj.pos.x < cam.x - 20 or proj.pos.x > cam.x + SW + 20:
			if hit_wall and proj.friendly:
				effects.append({"pos": proj.pos, "type": "spark", "timer": 0.1})
			projectiles.remove_at(i)

func _update_effects(delta: float) -> void:
	for i in range(effects.size() - 1, -1, -1):
		effects[i].timer -= delta
		if effects[i].timer <= 0:
			effects.remove_at(i)

# ================================================================
# COLLISIONS
# ================================================================
func _check_collisions() -> void:
	if p.invuln > 0: return

	# Projectiles vs enemies
	for i in range(projectiles.size() - 1, -1, -1):
		var proj = projectiles[i]
		if proj.friendly:
			for e in enemies:
				if not e.alive: continue
				if proj.pos.distance_to(e.pos) < 14:
					e.hp -= proj.dmg
					effects.append({"pos": e.pos, "type": "hit", "timer": 0.1})
					if e.hp <= 0:
						_kill_enemy(e)
					projectiles.remove_at(i)
					break

	# Contact damage
	for e in enemies:
		if not e.alive: continue
		if p.pos.distance_to(e.pos) < 14:
			# Screw attack kills on contact
			if items.screw_attack and not p.on_ground and not p.morphed:
				_kill_enemy(e)
			else:
				_take_damage(8)

	# Item pickups
	for i in range(room_items.size() - 1, -1, -1):
		var it = room_items[i]
		if p.pos.distance_to(it.pos) < 16:
			_collect_item(it)
			room_items.remove_at(i)

	# Hazard tiles
	var standing_tile = _tile_at(p.pos.x, p.pos.y + 2)
	if standing_tile == "spike":
		_take_damage(15)
	if standing_tile == "lava":
		if not items.lava_suit:
			_take_damage(5)

func _collect_item(it: Dictionary) -> void:
	var t = it.type
	match t:
		"energy_small": p.hp = mini(p.hp + 5, p.max_hp)
		"energy_tank":
			p.max_hp += 100
			p.hp = p.max_hp
		"missile":
			p.max_missiles += 5
			p.missiles = p.max_missiles
		"super_missile":
			p.max_supers += 5
			p.supers = p.max_supers
		"power_bomb":
			p.max_pbombs += 5
			p.pbombs = p.max_pbombs
		_:
			if items.has(t):
				items[t] = true

	if it.key != "":
		items_collected[it.key] = true

	effects.append({"pos": it.pos, "type": "item_get", "timer": 1.0})

# ================================================================
# CAMERA
# ================================================================
func _update_camera(delta: float) -> void:
	var target = Vector2(p.pos.x - SW * 0.4, p.pos.y - SH * 0.5)
	cam = cam.lerp(target, 5.0 * delta)
	cam.x = clampf(cam.x, 0, maxf(0, room_w - SW))
	cam.y = clampf(cam.y, 0, maxf(0, room_h - SH))

# ================================================================
# DRAWING
# ================================================================
func _draw() -> void:
	match state:
		GState.TITLE: _draw_title()
		GState.PLAYING: _draw_play()
		GState.GAMEOVER: _draw_gameover()

func _draw_title() -> void:
	draw_rect(Rect2(0, 0, SW, SH), Color(0.02, 0.02, 0.06))
	for i in range(60):
		var sx = fmod(i * 137.5 + title_timer * 3, float(SW))
		var sy = fmod(i * 91.3, float(SH))
		draw_rect(Rect2(sx, sy, 1, 1), Color(1, 1, 1, 0.3 + sin(title_timer * 2 + i) * 0.2))
	_text(100, 60, "MAGENT METROID", 20, Color(0.3, 0.7, 0.4))
	_text(130, 90, "A New Adventure", 10, Color(0.6, 0.6, 0.7))
	if fmod(title_timer, 1.0) < 0.6:
		_text(140, 180, "PRESS START", 11, Color.WHITE)

func _draw_play() -> void:
	var cx = cam.x
	var cy = cam.y

	# Background
	draw_rect(Rect2(0, 0, SW, SH), zone_bg.get(current_zone, Color(0.05, 0.05, 0.1)))

	# Tiles
	var tx_start = int(cx / TILE)
	var ty_start = int(cy / TILE)
	var tx_end = tx_start + SW / TILE + 2
	var ty_end = ty_start + SH / TILE + 2

	var sol_color = zone_solid.get(current_zone, Color(0.3, 0.3, 0.4))
	var det_color = zone_detail.get(current_zone, Color(0.2, 0.2, 0.3))

	for ty in range(maxi(0, ty_start), mini(tiles.size(), ty_end)):
		for tx in range(maxi(0, tx_start), mini(tiles[ty].size() if ty < tiles.size() else 0, tx_end)):
			var tile = tiles[ty][tx]
			var px = tx * TILE - cx
			var py = ty * TILE - cy

			match tile:
				"solid":
					draw_rect(Rect2(px, py, TILE, TILE), sol_color)
					draw_rect(Rect2(px, py, TILE, 2), sol_color * 1.2)
					draw_rect(Rect2(px, py + TILE - 1, TILE, 1), sol_color * 0.7)
					if (tx + ty) % 3 == 0:
						draw_rect(Rect2(px + 4, py + 4, 2, 2), det_color)
				"solid_top":
					draw_rect(Rect2(px, py, TILE, TILE), sol_color * 0.8)
					draw_rect(Rect2(px, py, TILE, 3), sol_color * 1.3)
				"spike":
					draw_rect(Rect2(px, py, TILE, TILE), Color(0.15, 0.05, 0.05))
					for s in range(3):
						var sx2 = px + 2 + s * 5
						draw_line(Vector2(sx2, py + TILE), Vector2(sx2 + 2, py + 4), Color(0.7, 0.2, 0.1), 1)
				"lava":
					draw_rect(Rect2(px, py, TILE, TILE), Color(0.8, 0.3, 0.0, 0.8))
					draw_rect(Rect2(px, py, TILE, 2), Color(1.0, 0.6, 0.1))
				"shootable":
					draw_rect(Rect2(px, py, TILE, TILE), Color(0.5, 0.5, 0.2))
					draw_rect(Rect2(px + 4, py + 4, 8, 8), Color(0.4, 0.4, 0.15))
				"crumble":
					draw_rect(Rect2(px, py, TILE, TILE), sol_color * 0.7)
					draw_rect(Rect2(px + 2, py + 6, 6, 1), Color(0.2, 0.15, 0.1))
				"grapple":
					draw_rect(Rect2(px, py, TILE, TILE), Color(0.1, 0.3, 0.2))
					draw_circle(Vector2(px + 8, py + 8), 5, Color(0.2, 0.7, 0.4))
				"speed":
					draw_rect(Rect2(px, py, TILE, TILE), Color(0.15, 0.15, 0.4))
				_:
					if tile.begins_with("bg_"):
						draw_rect(Rect2(px, py, TILE, TILE), det_color * 0.5)

	# Room items
	for it in room_items:
		var ix = it.pos.x - cx
		var iy = it.pos.y - cy + sin(p.anim * 3) * 2
		draw_circle(Vector2(ix, iy), 6, Color(1, 0.8, 0.2))
		draw_circle(Vector2(ix, iy), 4, Color(1, 1, 0.6))

	# Enemies
	for e in enemies:
		if not e.alive: continue
		var ex = e.pos.x - cx
		var ey = e.pos.y - cy
		draw_circle(Vector2(ex, ey + 4), 5, Color(0, 0, 0, 0.15))
		match e.type:
			"zoomer":
				draw_rect(Rect2(ex - 6, ey - 4, 12, 8), Color(0.7, 0.5, 0.1))
				draw_rect(Rect2(ex - 4, ey - 6, 8, 4), Color(0.8, 0.6, 0.2))
			"ripper":
				draw_rect(Rect2(ex - 8, ey - 4, 16, 8), Color(0.5, 0.5, 0.6))
				draw_rect(Rect2(ex - 6, ey - 2, 12, 4), Color(0.6, 0.6, 0.7))
			"sidehopper":
				draw_rect(Rect2(ex - 6, ey - 8, 12, 12), Color(0.3, 0.6, 0.3))
				draw_rect(Rect2(ex - 4, ey - 6, 8, 8), Color(0.4, 0.7, 0.4))
			"metroid":
				draw_circle(Vector2(ex, ey), 10, Color(0.2, 0.6, 0.2, 0.7))
				draw_circle(Vector2(ex, ey), 7, Color(0.3, 0.8, 0.3, 0.5))
				draw_circle(Vector2(ex, ey - 2), 3, Color(0.8, 0.2, 0.2))
			_:
				draw_rect(Rect2(ex - 6, ey - 6, 12, 12), Color(0.6, 0.2, 0.2))

	# Projectiles
	for proj in projectiles:
		var px2 = proj.pos.x - cx
		var py2 = proj.pos.y - cy
		if proj.type == "bomb":
			var pulse = sin(proj.life * 10) * 0.3 + 0.7
			draw_circle(Vector2(px2, py2), 4, Color(0.8, 0.5, 0.1, pulse))
		else:
			var col = proj.get("color", Color(1, 0.9, 0.3))
			draw_circle(Vector2(px2, py2), proj.size, col)
			draw_circle(Vector2(px2, py2), proj.size + 1, Color(col.r, col.g, col.b, 0.3))

	# Laser beam visual
	if items.laser_beam and p.charge > 0.3 and Input.is_action_pressed("shoot"):
		var lx = p.pos.x - cx
		var ly = p.pos.y - 12 - cy
		if p.aim_up:
			draw_line(Vector2(lx, ly), Vector2(lx, ly - 100), Color(1, 0.3, 0.1, 0.6), 2)
			draw_line(Vector2(lx, ly), Vector2(lx, ly - 100), Color(1, 0.7, 0.3, 0.3), 4)
		else:
			draw_line(Vector2(lx, ly), Vector2(lx + p.facing * 100, ly), Color(1, 0.3, 0.1, 0.6), 2)
			draw_line(Vector2(lx, ly), Vector2(lx + p.facing * 100, ly), Color(1, 0.7, 0.3, 0.3), 4)

	# Effects
	for e in effects:
		var ex2 = e.pos.x - cx
		var ey2 = e.pos.y - cy
		match e.type:
			"explode":
				var r = (0.4 - e.timer) * 30
				draw_circle(Vector2(ex2, ey2), r, Color(1, 0.6, 0.1, e.timer * 2.5))
			"bomb_explode":
				var r = (0.3 - e.timer) * 40
				draw_circle(Vector2(ex2, ey2), r, Color(1, 0.8, 0.2, e.timer * 3))
			"hit", "spark":
				draw_circle(Vector2(ex2, ey2), 4, Color(1, 1, 1, e.timer * 8))
			"flash":
				draw_circle(Vector2(ex2, ey2), 12, Color(1, 1, 0.8, e.timer * 5))
			"item_get":
				draw_circle(Vector2(ex2, ey2), 20 * (1.0 - e.timer), Color(1, 1, 1, e.timer))

	# Player
	if p.alive:
		var px3 = p.pos.x - cx
		var py3 = p.pos.y - cy
		if p.invuln > 0 and fmod(p.invuln, 0.14) > 0.07:
			pass
		else:
			_draw_player(px3, py3)

	# HUD
	_draw_hud()

func _draw_player(x: float, y: float) -> void:
	var d = float(p.facing)
	var bob = sin(p.anim * 8) * 1.0 if absf(p.vel.x) > 10 and p.on_ground else 0.0

	# Shadow
	draw_circle(Vector2(x, y + 4), 5, Color(0, 0, 0, 0.2))

	if p.morphed:
		# Morph ball
		var roll = p.morph_anim * 8
		draw_circle(Vector2(x, y - 4), 6, Color(0.8, 0.6, 0.1))
		draw_circle(Vector2(x, y - 4), 4, Color(0.9, 0.7, 0.2))
		draw_rect(Rect2(x - 1 + cos(roll) * 2, y - 5 + sin(roll) * 2, 2, 2), Color(0.5, 0.3, 0.05))
		return

	# Suit color
	var suit_main = Color(0.8, 0.5, 0.1)   # power suit orange
	var suit_dark = Color(0.6, 0.3, 0.05)
	var suit_light = Color(0.9, 0.65, 0.25)
	if items.varia_suit:
		suit_main = Color(0.8, 0.3, 0.3)   # varia red/pink
		suit_dark = Color(0.6, 0.2, 0.15)
		suit_light = Color(0.95, 0.45, 0.35)
	if items.gravity_suit:
		suit_main = Color(0.5, 0.3, 0.7)   # gravity purple
		suit_dark = Color(0.35, 0.2, 0.5)
		suit_light = Color(0.65, 0.45, 0.85)
	if items.cold_suit:
		suit_main = Color(0.85, 0.88, 0.92) # cold white
		suit_dark = Color(0.65, 0.70, 0.75)
		suit_light = Color(0.95, 0.97, 1.0)
	if items.lava_suit:
		suit_main = Color(0.2, 0.65, 0.25)  # lava green
		suit_dark = Color(0.12, 0.45, 0.15)
		suit_light = Color(0.35, 0.8, 0.4)

	var step = sin(p.anim * 10) * 2 if absf(p.vel.x) > 10 and p.on_ground else 0

	# Boots
	draw_rect(Rect2(x - 4 + step, y - 2, 3, 4), suit_dark)
	draw_rect(Rect2(x + 1 - step, y - 2, 3, 4), suit_dark)
	# Legs
	draw_rect(Rect2(x - 3, y - 6 + bob, 2, 5), suit_main)
	draw_rect(Rect2(x + 1, y - 6 + bob, 2, 5), suit_main)
	# Body
	draw_rect(Rect2(x - 5, y - 14 + bob, 10, 9), suit_main)
	draw_rect(Rect2(x - 4, y - 13 + bob, 8, 7), suit_light)
	# Chest detail
	draw_rect(Rect2(x - 1, y - 12 + bob, 2, 2), Color(0.2, 0.6, 0.2))
	# Shoulders
	draw_rect(Rect2(x - 7, y - 13 + bob, 3, 5), suit_dark)
	draw_rect(Rect2(x + 4, y - 13 + bob, 3, 5), suit_dark)
	# Arm cannon
	if p.shooting:
		draw_rect(Rect2(x + d * 6, y - 12 + bob, d * 8, 3), suit_main)
		draw_rect(Rect2(x + d * 12, y - 13 + bob, d * 4, 5), suit_light)
	# Helmet
	draw_rect(Rect2(x - 5, y - 20 + bob, 10, 7), suit_main)
	draw_rect(Rect2(x - 4, y - 21 + bob, 8, 3), suit_light)
	# Visor
	draw_rect(Rect2(x - 3 + d, y - 18 + bob, 5, 2), Color(0.2, 0.8, 0.3))
	draw_rect(Rect2(x - 2 + d, y - 18 + bob, 3, 1), Color(0.4, 1.0, 0.5))
	# Charge glow
	if p.charge > 0.3:
		var a = minf(p.charge, 1.0) * 0.3
		draw_circle(Vector2(x, y - 12), 14, Color(0.5, 0.8, 1.0, a))
	# Wall slide dust
	if p.on_wall != 0:
		for i in range(3):
			draw_rect(Rect2(x + p.on_wall * 6, y - 18 + i * 5 + sin(p.anim * 6 + i) * 2, 2, 2), Color(0.6, 0.6, 0.6, 0.4))
	# Screw attack glow
	if items.screw_attack and not p.on_ground and not p.morphed:
		draw_circle(Vector2(x, y - 10), 12, Color(0.3, 0.8, 1.0, 0.2 + sin(p.anim * 10) * 0.1))

func _draw_hud() -> void:
	# Energy
	draw_rect(Rect2(4, 4, 60, 16), Color(0, 0, 0, 0.6))
	_text(6, 14, "EN", 7, Color(0.7, 0.7, 0.7))
	var hp_frac = float(p.hp) / float(p.max_hp)
	var hp_color = Color(0.2, 0.7, 1.0) if hp_frac > 0.3 else Color(1, 0.3, 0.2)
	draw_rect(Rect2(18, 7, 42 * hp_frac, 8), hp_color)
	_text(20, 14, str(p.hp), 7, Color.WHITE)

	# Missiles
	if p.max_missiles > 0:
		draw_rect(Rect2(4, 22, 50, 10), Color(0, 0, 0, 0.5))
		_text(6, 30, "M:" + str(p.missiles), 6, Color(0.9, 0.6, 0.2))

	# Supers
	if p.max_supers > 0:
		draw_rect(Rect2(4, 34, 50, 10), Color(0, 0, 0, 0.5))
		_text(6, 42, "S:" + str(p.supers), 6, Color(0.2, 0.8, 0.2))

	# PBombs
	if p.max_pbombs > 0:
		draw_rect(Rect2(4, 46, 50, 10), Color(0, 0, 0, 0.5))
		_text(6, 54, "PB:" + str(p.pbombs), 6, Color(0.7, 0.3, 0.7))

	# Zone name
	_text(SW - 60, 14, current_zone.to_upper(), 7, Color(0.5, 0.5, 0.6))

	# Controls hint
	_text(SW - 130, SH - 6, "Z:jump X:shoot C:dash Down:morph", 5, Color(0.3, 0.3, 0.4))

func _draw_gameover() -> void:
	draw_rect(Rect2(0, 0, SW, SH), Color(0, 0, 0))
	_text(150, 100, "GAME OVER", 18, Color(0.8, 0.2, 0.2))
	if fmod(title_timer, 1.0) < 0.6:
		_text(140, 140, "PRESS START", 11, Color(0.7, 0.7, 0.7))

func _text(x: float, y: float, text: String, size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
