extends Node2D

# Mega Man X7 16-bit — Link to the Past style!
# Top-down overhead action like Zelda ALTTP
# SNES resolution: 400x224
# Axl starts playable, X unlocks after rescuing reploids

enum GameState { TITLE, STAGE_SELECT, PLAYING, TRANSITION, BOSS, GAME_OVER }

const SCREEN_W = 400
const SCREEN_H = 224
const TILE = 16
const ROOM_W = 400  # one screen width per room
const ROOM_H = 224  # one screen height per room

var state = GameState.TITLE

# Player
var player_pos = Vector2(200, 160)
var player_vel = Vector2.ZERO
var player_speed = 110.0
var player_dash_speed = 220.0
var player_facing = Vector2(0, 1)  # 4-directional facing
var player_hp = 28
var player_max_hp = 28
var player_alive = true
var player_invuln = 0.0
var player_anim_time = 0.0
var player_shooting = false
var player_shoot_timer = 0.0
var player_dashing = false
var player_dash_timer = 0.0
var player_charge = 0.0
var playing_as_x = false
var reploids_rescued = 0
var x_unlocked = false

# Room system (LTTP style — screen-by-screen transitions)
var current_room = Vector2i(0, 0)
var room_transition = false
var transition_dir = Vector2.ZERO
var transition_progress = 0.0
var rooms = {}  # Dictionary of Vector2i -> room data

# Game objects (per room)
var walls = []
var enemies = []
var projectiles = []
var effects = []
var items = []
var doors = []  # connections between rooms

# Stage
var current_stage = -1
var stage_names = [
	"Flame Hyenard", "Ride Boarski", "Vanishing Gungaroo", "Tornado Tonion",
	"Splash Warfly", "Wind Crowrang", "Snipe Anteator", "Soldier Stonekong"
]
var stage_colors = [
	Color(0.9, 0.3, 0.1), Color(0.6, 0.4, 0.2), Color(0.8, 0.7, 0.2), Color(0.3, 0.8, 0.3),
	Color(0.2, 0.5, 0.9), Color(0.5, 0.3, 0.7), Color(0.4, 0.5, 0.4), Color(0.6, 0.5, 0.3)
]
var stages_completed = []
var stage_cursor = 0
var title_blink = 0.0

func _ready() -> void:
	for i in range(8):
		stages_completed.append(false)

func _process(delta: float) -> void:
	match state:
		GameState.TITLE:
			_update_title(delta)
		GameState.STAGE_SELECT:
			_update_stage_select(delta)
		GameState.PLAYING:
			_update_playing(delta)
		GameState.TRANSITION:
			_update_transition(delta)
		GameState.GAME_OVER:
			if Input.is_action_just_pressed("jump"):
				state = GameState.TITLE
	queue_redraw()

func _update_title(delta: float) -> void:
	title_blink += delta
	if Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("shoot"):
		state = GameState.STAGE_SELECT

func _update_stage_select(delta: float) -> void:
	if Input.is_action_just_pressed("move_left"):
		stage_cursor = (stage_cursor - 1 + 8) % 8
	if Input.is_action_just_pressed("move_right"):
		stage_cursor = (stage_cursor + 1) % 8
	if Input.is_action_just_pressed("move_up"):
		stage_cursor = (stage_cursor - 4 + 8) % 8
	if Input.is_action_just_pressed("move_down"):
		stage_cursor = (stage_cursor + 4) % 8
	if Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("shoot"):
		current_stage = stage_cursor
		_load_stage(current_stage)
		state = GameState.PLAYING

func _update_playing(delta: float) -> void:
	if not player_alive:
		player_anim_time += delta
		if player_anim_time > 2.0:
			state = GameState.GAME_OVER
		return

	_handle_input(delta)
	_update_physics(delta)
	_update_enemies(delta)
	_update_projectiles(delta)
	_update_effects(delta)
	_check_collisions()
	_check_room_transition()

	player_anim_time += delta
	if player_invuln > 0:
		player_invuln -= delta
	if player_shoot_timer > 0:
		player_shoot_timer -= delta
	else:
		player_shooting = false
	if player_dash_timer > 0:
		player_dash_timer -= delta
	else:
		player_dashing = false

func _handle_input(delta: float) -> void:
	var input = Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)

	if input.length() > 0:
		input = input.normalized()
		# Snap to 4 directions for facing (LTTP style)
		if absf(input.x) > absf(input.y):
			player_facing = Vector2(signf(input.x), 0)
		else:
			player_facing = Vector2(0, signf(input.y))

	# Dash
	if Input.is_action_just_pressed("dash") and not player_dashing:
		player_dashing = true
		player_dash_timer = 0.25

	var speed = player_dash_speed if player_dashing else player_speed
	player_vel = input * speed

	# Shoot
	if Input.is_action_just_pressed("shoot"):
		_shoot()

	# Charge
	if Input.is_action_pressed("shoot"):
		player_charge += delta
	else:
		if player_charge > 0.8:
			_charge_shot()
		player_charge = 0.0

func _update_physics(delta: float) -> void:
	var new_pos = player_pos + player_vel * delta

	# Wall collision (per-axis for sliding)
	var test_x = Vector2(new_pos.x, player_pos.y)
	var blocked_x = false
	for w in walls:
		if _point_in_rect(test_x, w):
			blocked_x = true
			break
	if not blocked_x:
		player_pos.x = new_pos.x

	var test_y = Vector2(player_pos.x, new_pos.y)
	var blocked_y = false
	for w in walls:
		if _point_in_rect(test_y, w):
			blocked_y = true
			break
	if not blocked_y:
		player_pos.y = new_pos.y

	# Room bounds
	player_pos.x = clampf(player_pos.x, 8, ROOM_W - 8)
	player_pos.y = clampf(player_pos.y, 8, ROOM_H - 8)

func _shoot() -> void:
	player_shooting = true
	player_shoot_timer = 0.2
	var color = Color(1, 0.9, 0.3) if not playing_as_x else Color(0.4, 0.7, 1.0)
	projectiles.append({
		"pos": player_pos + player_facing * 10,
		"vel": player_facing * 250,
		"friendly": true,
		"damage": 1,
		"life": 0.8,
		"size": 3,
		"color": color,
	})

func _charge_shot() -> void:
	player_shooting = true
	player_shoot_timer = 0.3
	projectiles.append({
		"pos": player_pos + player_facing * 10,
		"vel": player_facing * 200,
		"friendly": true,
		"damage": 4,
		"life": 1.0,
		"size": 7,
		"color": Color(0.3, 1, 0.5) if not playing_as_x else Color(0.5, 0.8, 1.0),
	})
	effects.append({"pos": player_pos + player_facing * 8, "type": "flash", "timer": 0.15})

func _update_enemies(delta: float) -> void:
	for e in enemies:
		if not e["alive"]:
			continue
		e["anim"] += delta

		match e["type"]:
			"patrol":
				# Walk back and forth
				var move_dir = e["patrol_dir"]
				e["pos"] += move_dir * e["speed"] * delta
				e["patrol_timer"] -= delta
				if e["patrol_timer"] <= 0:
					e["patrol_dir"] = -e["patrol_dir"]
					e["patrol_timer"] = e["patrol_time"]
			"chaser":
				# Chase player when close
				var to_player = player_pos - e["pos"]
				if to_player.length() < 120:
					e["pos"] += to_player.normalized() * e["speed"] * delta
			"shooter":
				# Stand and shoot periodically
				if fmod(e["anim"], 2.5) < delta:
					var dir = (player_pos - e["pos"]).normalized()
					projectiles.append({
						"pos": e["pos"],
						"vel": dir * 120,
						"friendly": false,
						"damage": 2,
						"life": 2.0,
						"size": 3,
						"color": Color(1, 0.3, 0.3),
					})

func _update_projectiles(delta: float) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var p = projectiles[i]
		p["pos"] += p["vel"] * delta
		p["life"] -= delta
		# Check wall collision
		var hit_wall = false
		for w in walls:
			if _point_in_rect(p["pos"], w):
				hit_wall = true
				break
		if p["life"] <= 0 or hit_wall or p["pos"].x < -10 or p["pos"].x > ROOM_W + 10 or p["pos"].y < -10 or p["pos"].y > ROOM_H + 10:
			if hit_wall and p["friendly"]:
				effects.append({"pos": p["pos"], "type": "spark", "timer": 0.15})
			projectiles.remove_at(i)

func _update_effects(delta: float) -> void:
	for i in range(effects.size() - 1, -1, -1):
		effects[i]["timer"] -= delta
		if effects[i]["timer"] <= 0:
			effects.remove_at(i)

func _check_collisions() -> void:
	if player_invuln > 0:
		return

	# Friendly projectiles vs enemies
	for i in range(projectiles.size() - 1, -1, -1):
		var p = projectiles[i]
		if p["friendly"]:
			for e in enemies:
				if not e["alive"]:
					continue
				if p["pos"].distance_to(e["pos"]) < 12:
					e["hp"] -= p["damage"]
					effects.append({"pos": e["pos"], "type": "hit", "timer": 0.1})
					if e["hp"] <= 0:
						e["alive"] = false
						effects.append({"pos": e["pos"], "type": "explosion", "timer": 0.4})
						# Drop item chance
						if randf() < 0.3:
							items.append({"pos": e["pos"], "type": "health_small"})
					projectiles.remove_at(i)
					break
		else:
			# Enemy projectiles vs player
			if p["pos"].distance_to(player_pos) < 8:
				_take_damage(p["damage"])
				projectiles.remove_at(i)

	# Contact damage
	for e in enemies:
		if not e["alive"]:
			continue
		if player_pos.distance_to(e["pos"]) < 12:
			_take_damage(2)
			var knockback = (player_pos - e["pos"]).normalized() * 80
			player_pos += knockback * 0.1

	# Item pickup
	for i in range(items.size() - 1, -1, -1):
		if player_pos.distance_to(items[i]["pos"]) < 12:
			match items[i]["type"]:
				"health_small":
					player_hp = mini(player_hp + 4, player_max_hp)
				"health_large":
					player_hp = mini(player_hp + 8, player_max_hp)
				"reploid":
					reploids_rescued += 1
					if reploids_rescued >= 30 and not x_unlocked:
						x_unlocked = true
			items.remove_at(i)

func _take_damage(amount: int) -> void:
	if player_invuln > 0:
		return
	player_hp -= amount
	player_invuln = 1.0
	if player_hp <= 0:
		player_alive = false
		player_anim_time = 0.0

func _check_room_transition() -> void:
	# LTTP-style: walk off screen edge -> transition to next room
	if player_pos.x <= 2:
		_start_transition(Vector2(-1, 0))
	elif player_pos.x >= ROOM_W - 2:
		_start_transition(Vector2(1, 0))
	elif player_pos.y <= 2:
		_start_transition(Vector2(0, -1))
	elif player_pos.y >= ROOM_H - 2:
		_start_transition(Vector2(0, 1))

func _start_transition(dir: Vector2) -> void:
	var next_room = current_room + Vector2i(int(dir.x), int(dir.y))
	if not rooms.has(next_room):
		# No room there, block player
		player_pos -= dir * 4
		return
	transition_dir = dir
	transition_progress = 0.0
	state = GameState.TRANSITION

func _update_transition(delta: float) -> void:
	transition_progress += delta * 2.0  # takes 0.5 seconds
	if transition_progress >= 1.0:
		current_room += Vector2i(int(transition_dir.x), int(transition_dir.y))
		_load_room(current_room)
		# Place player at opposite edge
		if transition_dir.x > 0:
			player_pos.x = 12
		elif transition_dir.x < 0:
			player_pos.x = ROOM_W - 12
		elif transition_dir.y > 0:
			player_pos.y = 12
		elif transition_dir.y < 0:
			player_pos.y = ROOM_H - 12
		state = GameState.PLAYING

func _point_in_rect(point: Vector2, rect: Rect2) -> bool:
	return point.x >= rect.position.x and point.x <= rect.end.x and point.y >= rect.position.y and point.y <= rect.end.y

# ==================== LEVEL GENERATION ====================
func _load_stage(idx: int) -> void:
	rooms.clear()
	# Generate a 4x3 grid of rooms
	for rx in range(4):
		for ry in range(3):
			rooms[Vector2i(rx, ry)] = _generate_room(rx, ry, idx)
	current_room = Vector2i(0, 1)
	_load_room(current_room)
	player_pos = Vector2(40, ROOM_H / 2)
	player_hp = player_max_hp
	player_alive = true
	player_vel = Vector2.ZERO

func _load_room(room_id: Vector2i) -> void:
	if not rooms.has(room_id):
		return
	var data = rooms[room_id]
	walls = data["walls"].duplicate(true)
	enemies = data["enemies"].duplicate(true)
	items = data["items"].duplicate(true)
	projectiles.clear()
	effects.clear()

func _generate_room(rx: int, ry: int, stage_idx: int) -> Dictionary:
	var room_walls = []
	var room_enemies = []
	var room_items = []
	var seed_val = rx * 1000 + ry * 100 + stage_idx * 10

	# Border walls with openings
	# Top wall
	if ry > 0:
		room_walls.append(Rect2(0, 0, 180, 12))
		room_walls.append(Rect2(220, 0, 180, 12))
	else:
		room_walls.append(Rect2(0, 0, ROOM_W, 12))
	# Bottom wall
	if ry < 2:
		room_walls.append(Rect2(0, ROOM_H - 12, 180, 12))
		room_walls.append(Rect2(220, ROOM_H - 12, 180, 12))
	else:
		room_walls.append(Rect2(0, ROOM_H - 12, ROOM_W, 12))
	# Left wall
	if rx > 0:
		room_walls.append(Rect2(0, 0, 12, 90))
		room_walls.append(Rect2(0, 134, 12, 90))
	else:
		room_walls.append(Rect2(0, 0, 12, ROOM_H))
	# Right wall
	if rx < 3:
		room_walls.append(Rect2(ROOM_W - 12, 0, 12, 90))
		room_walls.append(Rect2(ROOM_W - 12, 134, 12, 90))
	else:
		room_walls.append(Rect2(ROOM_W - 12, 0, 12, ROOM_H))

	# Interior obstacles
	var rng_val = (seed_val * 7919) % 1000
	for i in range(3 + rng_val % 4):
		var wx = 40 + ((rng_val + i * 137) % int(ROOM_W - 80))
		var wy = 40 + ((rng_val + i * 91) % int(ROOM_H - 80))
		var ww = 16 + (rng_val + i * 53) % 48
		var wh = 16 + (rng_val + i * 67) % 48
		room_walls.append(Rect2(wx, wy, ww, wh))

	# Enemies
	var num_enemies = 2 + (rng_val % 3) + stage_idx / 2
	for i in range(num_enemies):
		var ex = 50.0 + float((rng_val + i * 200) % int(ROOM_W - 100))
		var ey = 40.0 + float((rng_val + i * 150) % int(ROOM_H - 80))
		var types = ["patrol", "chaser", "shooter"]
		var etype = types[(rng_val + i) % 3]
		room_enemies.append({
			"pos": Vector2(ex, ey),
			"type": etype,
			"hp": 2 + stage_idx / 3,
			"alive": true,
			"speed": 40.0 + float(stage_idx) * 5.0,
			"anim": 0.0,
			"patrol_dir": Vector2(1, 0) if (rng_val + i) % 2 == 0 else Vector2(0, 1),
			"patrol_timer": 2.0,
			"patrol_time": 2.0,
		})

	# Items
	if (rng_val % 5) == 0:
		room_items.append({"pos": Vector2(ROOM_W / 2, ROOM_H / 2), "type": "health_large"})
	if rx == 3 and ry == 0:
		# Reploid in far corner room
		room_items.append({"pos": Vector2(ROOM_W / 2, ROOM_H / 2), "type": "reploid"})

	return {"walls": room_walls, "enemies": room_enemies, "items": room_items}

# ==================== DRAWING ====================
func _draw() -> void:
	match state:
		GameState.TITLE:
			_draw_title()
		GameState.STAGE_SELECT:
			_draw_stage_select()
		GameState.PLAYING:
			_draw_room()
		GameState.TRANSITION:
			_draw_transition()
		GameState.GAME_OVER:
			_draw_game_over()

func _draw_title() -> void:
	draw_rect(Rect2(0, 0, SCREEN_W, SCREEN_H), Color(0.02, 0.02, 0.08))
	for i in range(50):
		var sx = fmod(i * 137.5, float(SCREEN_W))
		var sy = fmod(i * 91.3, float(SCREEN_H))
		draw_rect(Rect2(sx, sy, 1, 1), Color(1, 1, 1, 0.3 + sin(title_blink + i) * 0.2))
	draw_string(ThemeDB.fallback_font, Vector2(70, 55), "MEGA MAN X7", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.3, 0.6, 1.0))
	draw_string(ThemeDB.fallback_font, Vector2(130, 78), "16-BIT", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.7, 0.7, 0.8))
	draw_string(ThemeDB.fallback_font, Vector2(90, 100), "LINK TO THE PAST STYLE", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.5, 0.8, 0.4))
	# Mini X sprite
	_draw_player_sprite(200, 155, Vector2(0, 1), false, true)
	# Mini Axl sprite
	_draw_player_sprite(170, 155, Vector2(0, 1), false, false)
	if fmod(title_blink, 1.0) < 0.6:
		draw_string(ThemeDB.fallback_font, Vector2(130, 200), "PRESS START", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)

func _draw_stage_select() -> void:
	draw_rect(Rect2(0, 0, SCREEN_W, SCREEN_H), Color(0.05, 0.05, 0.15))
	draw_string(ThemeDB.fallback_font, Vector2(120, 22), "SELECT STAGE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.8, 0.8, 0.8))
	for i in range(8):
		var gx = 30 + (i % 4) * 90
		var gy = 40 + (i / 4) * 80
		var selected = i == stage_cursor
		var border = Color(1, 1, 0) if selected else Color(0.3, 0.3, 0.4)
		draw_rect(Rect2(gx, gy, 72, 60), Color(0.08, 0.08, 0.12))
		draw_rect(Rect2(gx, gy, 72, 60), border, false, 2 if selected else 1)
		if not stages_completed[i]:
			draw_circle(Vector2(gx + 36, gy + 25), 15, stage_colors[i])
			draw_circle(Vector2(gx + 31, gy + 22), 3, Color.WHITE)
			draw_circle(Vector2(gx + 41, gy + 22), 3, Color.WHITE)
			draw_circle(Vector2(gx + 32, gy + 22), 1.5, Color.BLACK)
			draw_circle(Vector2(gx + 42, gy + 22), 1.5, Color.BLACK)
		else:
			draw_string(ThemeDB.fallback_font, Vector2(gx + 18, gy + 30), "CLEAR", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.5, 0.5, 0.5))
		draw_string(ThemeDB.fallback_font, Vector2(gx + 2, gy + 55), stage_names[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(0.7, 0.7, 0.8))

func _draw_room() -> void:
	# Floor (stage-colored tint)
	var floor_color = Color(0.14, 0.12, 0.22)
	if current_stage >= 0:
		floor_color = Color(stage_colors[current_stage].r * 0.15, stage_colors[current_stage].g * 0.15, stage_colors[current_stage].b * 0.15)
	draw_rect(Rect2(0, 0, SCREEN_W, SCREEN_H), floor_color)

	# Floor tiles (LTTP style grid)
	for tx in range(0, SCREEN_W, TILE):
		for ty in range(0, SCREEN_H, TILE):
			var checker = ((tx / TILE + ty / TILE) % 2) == 0
			if checker:
				draw_rect(Rect2(tx, ty, TILE, TILE), Color(floor_color.r + 0.02, floor_color.g + 0.02, floor_color.b + 0.02))

	# Walls
	for w in walls:
		# LTTP-style walls: dark with lighter top edge
		draw_rect(w, Color(0.25, 0.22, 0.35))
		draw_rect(Rect2(w.position.x + 1, w.position.y + 1, w.size.x - 2, w.size.y - 2), Color(0.30, 0.27, 0.42))
		# Top highlight
		draw_rect(Rect2(w.position.x, w.position.y, w.size.x, 2), Color(0.40, 0.35, 0.52))

	# Items
	for item in items:
		_draw_item(item["pos"], item["type"])

	# Enemies
	for e in enemies:
		if e["alive"]:
			_draw_enemy_overhead(e)

	# Projectiles
	for p in projectiles:
		draw_circle(p["pos"], p["size"], p["color"])
		draw_circle(p["pos"], p["size"] + 1, Color(p["color"].r, p["color"].g, p["color"].b, 0.3))

	# Effects
	for e in effects:
		match e["type"]:
			"explosion":
				var r = (0.4 - e["timer"]) * 25
				draw_circle(e["pos"], r, Color(1, 0.6, 0.1, e["timer"] * 2))
			"flash":
				draw_circle(e["pos"], 10, Color(1, 1, 0.8, e["timer"] * 5))
			"hit":
				draw_circle(e["pos"], 5, Color(1, 1, 1, e["timer"] * 8))
			"spark":
				for j in range(4):
					var a = j * TAU / 4 + e["timer"] * 10
					draw_circle(e["pos"] + Vector2(cos(a), sin(a)) * 5, 1, Color(1, 0.8, 0.3, e["timer"] * 5))

	# Player
	if player_alive:
		if player_invuln > 0 and fmod(player_invuln, 0.15) > 0.075:
			pass
		else:
			_draw_player_sprite(player_pos.x, player_pos.y, player_facing, player_vel.length() > 10, playing_as_x)
			# Charge glow
			if player_charge > 0.3:
				var a = minf(player_charge, 1.0) * 0.3
				draw_circle(player_pos, 14, Color(0.3, 0.8, 1.0, a))
	else:
		# Death flash
		if fmod(player_anim_time, 0.3) < 0.15:
			draw_circle(player_pos, 10 + player_anim_time * 5, Color(1, 1, 1, 1.0 - player_anim_time * 0.4))

	# HUD
	_draw_hud()

	# Room coordinates (debug)
	draw_string(ThemeDB.fallback_font, Vector2(SCREEN_W - 40, SCREEN_H - 6), "%d,%d" % [current_room.x, current_room.y], HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(0.4, 0.4, 0.4))

func _draw_transition() -> void:
	# Draw current room sliding out, next room sliding in (LTTP style)
	var offset = transition_dir * transition_progress
	# Current room slides away
	draw_set_transform(Vector2(-offset.x * SCREEN_W, -offset.y * SCREEN_H))
	_draw_room()
	draw_set_transform(Vector2.ZERO)
	# Black overlay during transition
	draw_rect(Rect2(0, 0, SCREEN_W, SCREEN_H), Color(0, 0, 0, 0.3))

func _draw_player_sprite(x: float, y: float, facing: Vector2, moving: bool, is_x: bool) -> void:
	var bob = sin(player_anim_time * 8) * 1 if moving else 0

	# Shadow
	draw_circle(Vector2(x, y + 6), 5, Color(0, 0, 0, 0.2))

	if is_x:
		# X - blue armor, overhead view
		# Body
		draw_rect(Rect2(x - 5, y - 6 + bob, 10, 10), Color(0.25, 0.5, 0.95))
		# Helmet (varies by facing direction)
		draw_rect(Rect2(x - 4, y - 10 + bob, 8, 5), Color(0.3, 0.55, 1.0))
		# Gem
		draw_rect(Rect2(x - 1, y - 9 + bob, 2, 2), Color(0.9, 0.2, 0.2))
		# Face (toward facing direction)
		var face_off = facing * 2
		draw_rect(Rect2(x - 2 + face_off.x, y - 5 + face_off.y + bob, 4, 3), Color(0.95, 0.82, 0.7))
		# Buster arm
		if player_shooting:
			draw_rect(Rect2(x + facing.x * 6, y + facing.y * 6 - 3 + bob, facing.x * 6 if facing.x != 0 else 4, facing.y * 6 if facing.y != 0 else 4), Color(0.3, 0.6, 1.0))
	else:
		# Axl - orange armor
		draw_rect(Rect2(x - 5, y - 6 + bob, 10, 10), Color(0.65, 0.35, 0.2))
		draw_rect(Rect2(x - 4, y - 10 + bob, 8, 5), Color(0.7, 0.4, 0.25))
		# Visor
		draw_rect(Rect2(x - 3, y - 9 + bob, 6, 2), Color(0.3, 0.8, 0.3))
		# Face
		var face_off = facing * 2
		draw_rect(Rect2(x - 2 + face_off.x, y - 5 + face_off.y + bob, 4, 3), Color(0.95, 0.82, 0.7))
		# Gun arm
		if player_shooting:
			draw_rect(Rect2(x + facing.x * 6, y + facing.y * 6 - 2 + bob, absf(facing.x) * 8 + absf(facing.y) * 3, absf(facing.y) * 8 + absf(facing.x) * 3), Color(0.5, 0.5, 0.55))

	# Feet (animated when moving)
	if moving:
		var step = sin(player_anim_time * 10) * 2
		draw_rect(Rect2(x - 3 + step, y + 4, 2, 3), Color(0.2, 0.2, 0.3))
		draw_rect(Rect2(x + 1 - step, y + 4, 2, 3), Color(0.2, 0.2, 0.3))
	else:
		draw_rect(Rect2(x - 3, y + 4, 2, 3), Color(0.2, 0.2, 0.3))
		draw_rect(Rect2(x + 1, y + 4, 2, 3), Color(0.2, 0.2, 0.3))

func _draw_enemy_overhead(e: Dictionary) -> void:
	var pos = e["pos"]
	# Shadow
	draw_circle(Vector2(pos.x, pos.y + 5), 4, Color(0, 0, 0, 0.15))

	match e["type"]:
		"patrol":
			draw_rect(Rect2(pos.x - 5, pos.y - 6, 10, 10), Color(0.7, 0.25, 0.2))
			draw_rect(Rect2(pos.x - 3, pos.y - 8, 6, 4), Color(0.6, 0.2, 0.18))
			draw_rect(Rect2(pos.x - 1, pos.y - 7, 2, 2), Color(1, 0, 0))
		"chaser":
			draw_circle(pos, 6, Color(0.6, 0.2, 0.5))
			draw_circle(pos, 4, Color(0.7, 0.3, 0.6))
			draw_rect(Rect2(pos.x - 1, pos.y - 2, 2, 2), Color(1, 0.8, 0))
		"shooter":
			draw_rect(Rect2(pos.x - 6, pos.y - 4, 12, 8), Color(0.4, 0.4, 0.5))
			draw_rect(Rect2(pos.x - 4, pos.y - 6, 8, 4), Color(0.5, 0.5, 0.6))
			# Turret barrel toward player
			var aim = (player_pos - pos).normalized() * 8
			draw_line(pos, pos + aim, Color(0.6, 0.6, 0.65), 2)
			draw_rect(Rect2(pos.x - 1, pos.y - 2, 2, 2), Color(1, 0.3, 0) if fmod(e["anim"], 1.0) < 0.5 else Color(0.3, 0.1, 0))

func _draw_item(pos: Vector2, type: String) -> void:
	var bob = sin(player_anim_time * 3) * 2
	match type:
		"health_small":
			draw_rect(Rect2(pos.x - 3, pos.y - 3 + bob, 6, 6), Color(0.9, 0.9, 0.1))
		"health_large":
			draw_rect(Rect2(pos.x - 4, pos.y - 4 + bob, 8, 8), Color(0.9, 0.2, 0.2))
			draw_rect(Rect2(pos.x - 1, pos.y - 3 + bob, 2, 4), Color.WHITE)
			draw_rect(Rect2(pos.x - 2, pos.y - 2 + bob, 4, 2), Color.WHITE)
		"reploid":
			draw_rect(Rect2(pos.x - 3, pos.y - 6 + bob, 6, 10), Color(0.3, 0.7, 0.3))
			draw_rect(Rect2(pos.x - 2, pos.y - 8 + bob, 4, 3), Color(0.9, 0.8, 0.7))
			if fmod(player_anim_time, 0.8) < 0.5:
				draw_string(ThemeDB.fallback_font, Vector2(pos.x - 3, pos.y - 12 + bob), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 0))

func _draw_hud() -> void:
	# HP bar (LTTP style - vertical on left)
	draw_rect(Rect2(4, 4, 12, player_max_hp * 3 + 8), Color(0, 0, 0, 0.6))
	var name_txt = "AXL" if not playing_as_x else "X"
	draw_string(ThemeDB.fallback_font, Vector2(5, 14), name_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color.WHITE)
	for i in range(player_max_hp):
		var hy = 18 + (player_max_hp - 1 - i) * 3
		var filled = i < player_hp
		draw_rect(Rect2(6, hy, 8, 2), Color(0.2, 0.7, 1.0) if filled else Color(0.15, 0.15, 0.2))

	# Reploid count
	draw_string(ThemeDB.fallback_font, Vector2(SCREEN_W - 70, 12), "RESCUE:%d" % reploids_rescued, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(0.7, 0.8, 0.7))

func _draw_game_over() -> void:
	draw_rect(Rect2(0, 0, SCREEN_W, SCREEN_H), Color(0, 0, 0))
	draw_string(ThemeDB.fallback_font, Vector2(140, 100), "GAME OVER", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.8, 0.2, 0.2))
	if fmod(title_blink, 1.0) < 0.6:
		draw_string(ThemeDB.fallback_font, Vector2(130, 140), "PRESS START", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.7, 0.7, 0.7))
