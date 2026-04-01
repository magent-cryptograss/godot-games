extends Node2D

# ================================================================
# PICKIN' DEFENSE
# Tower defense where evil instruments attack the bluegrass stage!
# Place good instruments to blast the rogue ones with music.
# ================================================================

const SW = 900
const SH = 600
const CELL = 60
const GRID_COLS = 12
const GRID_ROWS = 8
const GRID_X = 30
const GRID_Y = 70

enum State { TITLE, PLAYING, WAVE_ACTIVE, GAME_OVER, VICTORY }

var state = State.TITLE
var timer = 0.0
var frame = 0

# Resources
var money = 200
var lives = 20
var wave = 0
var max_waves = 15
var wave_active = false
var wave_timer = 0.0
var enemies_spawned = 0
var enemies_to_spawn = 0
var spawn_timer = 0.0

# Placed towers (good instruments)
var towers = []

# Enemies (evil instruments on the march)
var enemies = []

# Projectiles (music notes flying!)
var projectiles = []

# Particles
var particles = []

# Selected tower type for placement
var selected_tower = -1

# Path: enemies walk from right to left along these waypoints
var path = []

# === TOWER TYPES (Good Instruments) ===
var TOWERS = [
	{"name": "Fiddle", "cost": 50, "damage": 8, "range": 120, "rate": 1.2,
	 "color": Color(0.7, 0.4, 0.15), "proj_color": Color(1, 0.8, 0.3),
	 "desc": "Fast attack, medium damage", "proj_type": "note"},

	{"name": "Guitar", "cost": 75, "damage": 12, "range": 140, "rate": 0.9,
	 "color": Color(0.6, 0.3, 0.1), "proj_color": Color(0.9, 0.6, 0.2),
	 "desc": "Strong strums, good range", "proj_type": "chord"},

	{"name": "Mandolin", "cost": 100, "damage": 5, "range": 160, "rate": 2.0,
	 "color": Color(0.8, 0.6, 0.2), "proj_color": Color(1, 1, 0.4),
	 "desc": "Very fast tremolo attack!", "proj_type": "note"},

	{"name": "Dobro", "cost": 125, "damage": 20, "range": 180, "rate": 0.6,
	 "color": Color(0.5, 0.5, 0.55), "proj_color": Color(0.7, 0.8, 1.0),
	 "desc": "Slow but powerful slide", "proj_type": "wave"},

	{"name": "Upright Bass", "cost": 150, "damage": 15, "range": 100, "rate": 0.8,
	 "color": Color(0.45, 0.25, 0.1), "proj_color": Color(0.6, 0.3, 0.1),
	 "desc": "Splash damage! Hits all nearby", "proj_type": "bass", "splash": 50},

	{"name": "Harmonica", "cost": 60, "damage": 4, "range": 200, "rate": 1.5,
	 "color": Color(0.6, 0.6, 0.7), "proj_color": Color(0.5, 0.7, 1.0),
	 "desc": "Long range, slows enemies", "proj_type": "note", "slow": 0.5},

	{"name": "Washboard", "cost": 80, "damage": 6, "range": 90, "rate": 2.5,
	 "color": Color(0.55, 0.55, 0.5), "proj_color": Color(0.8, 0.8, 0.6),
	 "desc": "Rapid percussion attack", "proj_type": "beat"},

	{"name": "Dulcimer", "cost": 200, "damage": 30, "range": 250, "rate": 0.4,
	 "color": Color(0.7, 0.5, 0.3), "proj_color": Color(1, 0.9, 0.5),
	 "desc": "Devastating but slow", "proj_type": "wave"},
]

# === ENEMY TYPES (Evil Instruments) ===
var ENEMIES = [
	{"name": "Evil Banjo", "hp": 30, "speed": 40, "reward": 15,
	 "color": Color(0.4, 0.7, 0.2), "size": 10, "desc": "Basic evil twanger"},

	{"name": "Angry Drum", "hp": 60, "speed": 30, "reward": 20,
	 "color": Color(0.6, 0.2, 0.2), "size": 14, "desc": "Tough, slow beater"},

	{"name": "Possessed Tuba", "hp": 100, "speed": 20, "reward": 35,
	 "color": Color(0.7, 0.6, 0.1), "size": 18, "desc": "Big and bassy"},

	{"name": "Rogue Trumpet", "hp": 25, "speed": 60, "reward": 20,
	 "color": Color(0.8, 0.7, 0.2), "size": 9, "desc": "Fast and annoying"},

	{"name": "Dark Accordion", "hp": 80, "speed": 35, "reward": 30,
	 "color": Color(0.3, 0.2, 0.4), "size": 16, "desc": "Squeezes through defenses"},

	{"name": "Haunted Piano", "hp": 200, "speed": 15, "reward": 60,
	 "color": Color(0.15, 0.15, 0.2), "size": 22, "desc": "BOSS — massive and terrifying"},

	{"name": "Cursed Saxophone", "hp": 40, "speed": 50, "reward": 25,
	 "color": Color(0.8, 0.5, 0.1), "size": 11, "desc": "Smooth but deadly"},

	{"name": "Wicked Bagpipe", "hp": 70, "speed": 25, "reward": 30,
	 "color": Color(0.3, 0.5, 0.2), "size": 15, "desc": "Nobody likes bagpipes"},
]

func _ready() -> void:
	_generate_path()

func _generate_path() -> void:
	# Zigzag path from right to left
	path.clear()
	path.append(Vector2(GRID_X + GRID_COLS * CELL + 30, GRID_Y + 2 * CELL))
	path.append(Vector2(GRID_X + 9 * CELL, GRID_Y + 2 * CELL))
	path.append(Vector2(GRID_X + 9 * CELL, GRID_Y + 5 * CELL))
	path.append(Vector2(GRID_X + 5 * CELL, GRID_Y + 5 * CELL))
	path.append(Vector2(GRID_X + 5 * CELL, GRID_Y + 1 * CELL))
	path.append(Vector2(GRID_X + 2 * CELL, GRID_Y + 1 * CELL))
	path.append(Vector2(GRID_X + 2 * CELL, GRID_Y + 6 * CELL))
	path.append(Vector2(GRID_X - 30, GRID_Y + 6 * CELL))  # exit = stage!

func _process(delta: float) -> void:
	frame += 1
	timer += delta

	match state:
		State.TITLE:
			if Input.is_action_just_pressed("click"):
				_start_game()
		State.PLAYING:
			if Input.is_action_just_pressed("click"):
				_handle_click()
			if Input.is_action_just_pressed("start_wave"):
				_start_wave()
		State.WAVE_ACTIVE:
			if Input.is_action_just_pressed("click"):
				_handle_click()
			_update_wave(delta)
			_update_enemies(delta)
			_update_towers(delta)
			_update_projectiles(delta)
		State.GAME_OVER, State.VICTORY:
			if Input.is_action_just_pressed("click"):
				state = State.TITLE

	_update_particles(delta)
	queue_redraw()

func _start_game() -> void:
	money = 200
	lives = 20
	wave = 0
	towers.clear()
	enemies.clear()
	projectiles.clear()
	particles.clear()
	selected_tower = -1
	state = State.PLAYING

func _start_wave() -> void:
	wave += 1
	if wave > max_waves:
		state = State.VICTORY
		return
	enemies_spawned = 0
	enemies_to_spawn = 5 + wave * 2
	spawn_timer = 0.0
	wave_active = true
	state = State.WAVE_ACTIVE

func _handle_click() -> void:
	var mouse = get_global_mouse_position()

	# Check tower shop buttons
	for i in range(TOWERS.size()):
		var bx = GRID_X + GRID_COLS * CELL + 20
		var by = GRID_Y + i * 56
		if mouse.x > bx and mouse.x < bx + 150 and mouse.y > by and mouse.y < by + 50:
			if selected_tower == i:
				selected_tower = -1  # deselect
			else:
				selected_tower = i
			return

	# Place tower on grid
	if selected_tower >= 0:
		var gx = int((mouse.x - GRID_X) / CELL)
		var gy = int((mouse.y - GRID_Y) / CELL)
		if gx >= 0 and gx < GRID_COLS and gy >= 0 and gy < GRID_ROWS:
			var tower_def = TOWERS[selected_tower]
			if money >= tower_def.cost and not _tower_at(gx, gy) and not _on_path(gx, gy):
				money -= tower_def.cost
				towers.append({
					"type": selected_tower,
					"gx": gx, "gy": gy,
					"x": GRID_X + gx * CELL + CELL / 2,
					"y": GRID_Y + gy * CELL + CELL / 2,
					"cooldown": 0.0,
					"kills": 0,
				})
				# Placement particle burst
				for p in range(8):
					particles.append({"x": GRID_X + gx * CELL + CELL/2, "y": GRID_Y + gy * CELL + CELL/2,
						"vx": randf() * 60 - 30, "vy": randf() * -40 - 10,
						"life": 0.6, "color": tower_def.color, "size": 3})

func _tower_at(gx: int, gy: int) -> bool:
	for t in towers:
		if t.gx == gx and t.gy == gy:
			return true
	return false

func _on_path(gx: int, gy: int) -> bool:
	var cell_center = Vector2(GRID_X + gx * CELL + CELL/2, GRID_Y + gy * CELL + CELL/2)
	for i in range(path.size() - 1):
		var a = path[i]
		var b = path[i + 1]
		# Check if cell is near the path segment
		var closest = _closest_point_on_segment(cell_center, a, b)
		if cell_center.distance_to(closest) < CELL * 0.6:
			return true
	return false

func _closest_point_on_segment(p: Vector2, a: Vector2, b: Vector2) -> Vector2:
	var ab = b - a
	var ap = p - a
	var t = clampf(ap.dot(ab) / ab.dot(ab), 0.0, 1.0)
	return a + ab * t

# === WAVE & SPAWNING ===
func _update_wave(delta: float) -> void:
	spawn_timer -= delta
	if spawn_timer <= 0 and enemies_spawned < enemies_to_spawn:
		_spawn_enemy()
		spawn_timer = 1.0 - wave * 0.03  # faster spawns in later waves
		enemies_spawned += 1

	# Check if wave is over
	if enemies_spawned >= enemies_to_spawn:
		var alive = false
		for e in enemies:
			if e.alive:
				alive = true
				break
		if not alive:
			wave_active = false
			state = State.PLAYING
			money += 20 + wave * 5  # wave bonus

func _spawn_enemy() -> void:
	# Pick enemy type based on wave
	var type_idx = 0
	var r = randf()
	if wave >= 12 and r < 0.1:
		type_idx = 5  # Haunted Piano boss
	elif wave >= 8 and r < 0.2:
		type_idx = randi_range(3, 7)
	elif wave >= 4 and r < 0.3:
		type_idx = randi_range(1, 4)
	else:
		type_idx = randi_range(0, mini(2, ENEMIES.size() - 1))

	var et = ENEMIES[type_idx]
	var hp_scale = 1.0 + wave * 0.15
	enemies.append({
		"type": type_idx,
		"hp": int(et.hp * hp_scale),
		"max_hp": int(et.hp * hp_scale),
		"speed": et.speed,
		"base_speed": et.speed,
		"alive": true,
		"path_idx": 0,
		"path_progress": 0.0,
		"x": path[0].x,
		"y": path[0].y,
		"slow_timer": 0.0,
	})

# === ENEMY MOVEMENT ===
func _update_enemies(delta: float) -> void:
	for e in enemies:
		if not e.alive:
			continue

		# Slow effect
		if e.slow_timer > 0:
			e.slow_timer -= delta
			e.speed = e.base_speed * 0.4
		else:
			e.speed = e.base_speed

		# Move along path
		if e.path_idx >= path.size() - 1:
			# Reached the stage!
			e.alive = false
			lives -= 1
			if lives <= 0:
				state = State.GAME_OVER
			continue

		var target = path[e.path_idx + 1]
		var dir = (target - Vector2(e.x, e.y)).normalized()
		e.x += dir.x * e.speed * delta
		e.y += dir.y * e.speed * delta

		if Vector2(e.x, e.y).distance_to(target) < 5:
			e.path_idx += 1
			if e.path_idx < path.size():
				e.x = path[e.path_idx].x
				e.y = path[e.path_idx].y

# === TOWER ATTACKS ===
func _update_towers(delta: float) -> void:
	for t in towers:
		t.cooldown -= delta
		if t.cooldown > 0:
			continue

		var td = TOWERS[t.type]
		# Find nearest enemy in range
		var best_enemy = null
		var best_dist = td.range + 1

		for e in enemies:
			if not e.alive:
				continue
			var dist = Vector2(t.x, t.y).distance_to(Vector2(e.x, e.y))
			if dist < td.range and dist < best_dist:
				best_dist = dist
				best_enemy = e

		if best_enemy != null:
			t.cooldown = 1.0 / td.rate
			# Fire!
			var dir = (Vector2(best_enemy.x, best_enemy.y) - Vector2(t.x, t.y)).normalized()
			projectiles.append({
				"x": t.x, "y": t.y,
				"vx": dir.x * 300, "vy": dir.y * 300,
				"damage": td.damage,
				"color": td.proj_color,
				"type": td.proj_type,
				"splash": td.get("splash", 0),
				"slow": td.get("slow", 0.0),
				"life": 1.5,
				"tower_idx": towers.find(t),
			})
			# Firing particles
			particles.append({"x": t.x + dir.x * 15, "y": t.y + dir.y * 15,
				"vx": dir.x * 20, "vy": dir.y * 20,
				"life": 0.3, "color": td.proj_color, "size": 4})

# === PROJECTILES ===
func _update_projectiles(delta: float) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var p = projectiles[i]
		p.x += p.vx * delta
		p.y += p.vy * delta
		p.life -= delta

		if p.life <= 0:
			projectiles.remove_at(i)
			continue

		# Hit detection
		for e in enemies:
			if not e.alive:
				continue
			var et = ENEMIES[e.type]
			if Vector2(p.x, p.y).distance_to(Vector2(e.x, e.y)) < et.size + 5:
				e.hp -= p.damage

				# Slow effect
				if p.slow > 0:
					e.slow_timer = 2.0

				# Splash damage
				if p.splash > 0:
					for e2 in enemies:
						if e2 != e and e2.alive:
							if Vector2(e.x, e.y).distance_to(Vector2(e2.x, e2.y)) < p.splash:
								e2.hp -= p.damage / 2

				# Hit particles
				for pi in range(4):
					particles.append({"x": p.x, "y": p.y,
						"vx": randf() * 80 - 40, "vy": randf() * 80 - 40,
						"life": 0.4, "color": p.color, "size": 2})

				# Kill check
				if e.hp <= 0:
					e.alive = false
					money += ENEMIES[e.type].reward
					if p.tower_idx >= 0 and p.tower_idx < towers.size():
						towers[p.tower_idx].kills += 1
					# Death explosion
					for pi in range(12):
						particles.append({"x": e.x, "y": e.y,
							"vx": randf() * 120 - 60, "vy": randf() * 120 - 60,
							"life": 0.7, "color": ENEMIES[e.type].color, "size": randf() * 4 + 2})

				projectiles.remove_at(i)
				break

func _update_particles(delta: float) -> void:
	for i in range(particles.size() - 1, -1, -1):
		var p = particles[i]
		p.x += p.vx * delta
		p.y += p.vy * delta
		p.life -= delta
		if p.life <= 0:
			particles.remove_at(i)

# ================================================================
# DRAWING
# ================================================================
func _draw() -> void:
	match state:
		State.TITLE: _draw_title()
		State.PLAYING, State.WAVE_ACTIVE: _draw_game()
		State.GAME_OVER: _draw_game(); _draw_overlay("THE SHOW IS OVER!", "The evil instruments destroyed the stage.", Color(0.8, 0.2, 0.2))
		State.VICTORY: _draw_game(); _draw_overlay("ENCORE! ENCORE!", "You saved the bluegrass festival!", Color(0.3, 0.8, 0.3))

	# Particles
	for p in particles:
		draw_circle(Vector2(p.x, p.y), p.size, Color(p.color.r, p.color.g, p.color.b, p.life))

func _draw_title() -> void:
	draw_rect(Rect2(0, 0, SW, SH), Color(0.15, 0.1, 0.05))

	# Barn/stage background
	draw_rect(Rect2(200, 150, 500, 300), Color(0.4, 0.2, 0.08))
	draw_rect(Rect2(210, 160, 480, 280), Color(0.5, 0.28, 0.12))
	# Barn roof
	var roof = PackedVector2Array([Vector2(180, 150), Vector2(450, 80), Vector2(720, 150)])
	draw_colored_polygon(roof, Color(0.35, 0.15, 0.06))
	# Stage
	draw_rect(Rect2(250, 350, 400, 30), Color(0.45, 0.3, 0.15))
	draw_rect(Rect2(250, 350, 400, 5), Color(0.55, 0.38, 0.2))

	# Evil instruments approaching
	for i in range(5):
		var ex = 100 + i * 150 + sin(timer * 2 + i) * 20
		var ey = 420 + sin(timer * 1.5 + i * 0.7) * 10
		var ec = ENEMIES[i % ENEMIES.size()].color
		draw_circle(Vector2(ex, ey), 12, ec)
		draw_circle(Vector2(ex - 3, ey - 3), 3, Color(1, 0.2, 0.1))
		draw_circle(Vector2(ex + 3, ey - 3), 3, Color(1, 0.2, 0.1))

	_text(250, 230, "PICKIN'", 42, Color(0.95, 0.85, 0.5))
	_text(260, 280, "DEFENSE", 38, Color(0.9, 0.75, 0.4))
	_text(260, 320, "Where the music fights back!", 12, Color(0.7, 0.6, 0.4))
	if fmod(timer, 1.0) < 0.6:
		_text(350, 500, "CLICK TO START", 16, Color(0.9, 0.8, 0.5))

func _draw_game() -> void:
	# Grass background
	draw_rect(Rect2(0, 0, SW, SH), Color(0.15, 0.25, 0.1))

	# Grid
	for gy in range(GRID_ROWS):
		for gx in range(GRID_COLS):
			var px = GRID_X + gx * CELL
			var py = GRID_Y + gy * CELL
			var on_path = _on_path(gx, gy)
			# Ground tile
			var noise = sin(gx * 3.7 + gy * 5.3) * 0.02
			if on_path:
				draw_rect(Rect2(px, py, CELL, CELL), Color(0.35 + noise, 0.28 + noise, 0.18 + noise))
				draw_rect(Rect2(px + 1, py + 1, CELL - 2, CELL - 2), Color(0.38 + noise, 0.30 + noise, 0.20 + noise))
			else:
				draw_rect(Rect2(px, py, CELL, CELL), Color(0.18 + noise, 0.30 + noise, 0.12 + noise))
				# Grass detail
				if (gx + gy) % 3 == 0:
					draw_rect(Rect2(px + 10, py + 8, 2, 6), Color(0.22, 0.38, 0.15))
				if (gx * 7 + gy * 3) % 5 == 0:
					draw_rect(Rect2(px + 35, py + 25, 2, 5), Color(0.20, 0.35, 0.13))
			# Grid lines
			draw_rect(Rect2(px, py, CELL, CELL), Color(0.25, 0.35, 0.18, 0.2), false, 1)

	# Draw path
	for i in range(path.size() - 1):
		draw_line(path[i], path[i + 1], Color(0.45, 0.35, 0.22, 0.4), 3)

	# Stage at the left end
	draw_rect(Rect2(GRID_X - 40, GRID_Y + 5 * CELL - 20, 50, CELL * 2 + 40), Color(0.5, 0.3, 0.15))
	draw_rect(Rect2(GRID_X - 38, GRID_Y + 5 * CELL - 18, 46, CELL * 2 + 36), Color(0.6, 0.38, 0.2))
	_text(GRID_X - 35, GRID_Y + 5 * CELL + 15, "STAGE", 8, Color(0.9, 0.8, 0.5))
	# Microphone
	draw_line(Vector2(GRID_X - 20, GRID_Y + 5 * CELL + 20), Vector2(GRID_X - 20, GRID_Y + 5 * CELL - 10), Color(0.4, 0.4, 0.45), 2)
	draw_circle(Vector2(GRID_X - 20, GRID_Y + 5 * CELL - 12), 5, Color(0.5, 0.5, 0.55))

	# Tower range indicator for selected
	if selected_tower >= 0:
		var mouse = get_global_mouse_position()
		var gx = int((mouse.x - GRID_X) / CELL)
		var gy = int((mouse.y - GRID_Y) / CELL)
		if gx >= 0 and gx < GRID_COLS and gy >= 0 and gy < GRID_ROWS:
			var td = TOWERS[selected_tower]
			var cx = GRID_X + gx * CELL + CELL / 2
			var cy = GRID_Y + gy * CELL + CELL / 2
			draw_circle(Vector2(cx, cy), td.range, Color(0.3, 0.7, 0.3, 0.1))
			draw_arc(Vector2(cx, cy), td.range, 0, TAU, 32, Color(0.3, 0.7, 0.3, 0.25), 1)
			# Preview tower
			draw_circle(Vector2(cx, cy), 14, Color(td.color.r, td.color.g, td.color.b, 0.5))

	# Draw towers
	for t in towers:
		var td = TOWERS[t.type]
		var tx = t.x
		var ty = t.y

		# Base
		draw_rect(Rect2(tx - 16, ty - 16, 32, 32), Color(0.3, 0.25, 0.15))
		draw_rect(Rect2(tx - 14, ty - 14, 28, 28), Color(0.4, 0.32, 0.2))

		# Instrument body
		draw_circle(Vector2(tx, ty), 12, td.color * 0.7)
		draw_circle(Vector2(tx, ty - 2), 10, td.color)
		draw_circle(Vector2(tx, ty - 3), 7, td.color * 1.2)

		# Instrument-specific details
		match td.name:
			"Fiddle":
				draw_line(Vector2(tx - 8, ty - 10), Vector2(tx + 8, ty + 6), td.color * 0.5, 2)
				draw_line(Vector2(tx + 6, ty - 8), Vector2(tx + 14, ty - 14), Color(0.6, 0.5, 0.3), 1)
			"Guitar":
				draw_rect(Rect2(tx - 2, ty - 18, 4, 14), td.color * 0.6)
				draw_line(Vector2(tx, ty - 6), Vector2(tx, ty + 8), Color(0.8, 0.7, 0.5), 1)
			"Mandolin":
				draw_rect(Rect2(tx - 1, ty - 16, 3, 12), td.color * 0.7)
			"Upright Bass":
				draw_rect(Rect2(tx - 2, ty - 22, 4, 18), td.color * 0.6)
			"Harmonica":
				draw_rect(Rect2(tx - 8, ty - 2, 16, 4), td.color * 1.1)
			"Dobro":
				draw_circle(Vector2(tx, ty), 8, Color(0.6, 0.6, 0.65))

		# Kill count
		if t.kills > 0:
			_text(tx + 12, ty + 18, str(t.kills), 6, Color(0.9, 0.8, 0.3))

	# Draw enemies
	for e in enemies:
		if not e.alive:
			continue
		var et = ENEMIES[e.type]

		# Shadow
		draw_circle(Vector2(e.x, e.y + et.size * 0.8), et.size * 0.7, Color(0, 0, 0, 0.15))

		# Body
		draw_circle(Vector2(e.x, e.y), et.size, et.color * 0.6)
		draw_circle(Vector2(e.x, e.y - 2), et.size - 2, et.color)

		# Evil eyes
		draw_circle(Vector2(e.x - et.size * 0.3, e.y - et.size * 0.2), 3, Color(1, 0.9, 0.8))
		draw_circle(Vector2(e.x + et.size * 0.3, e.y - et.size * 0.2), 3, Color(1, 0.9, 0.8))
		draw_circle(Vector2(e.x - et.size * 0.3, e.y - et.size * 0.2), 1.5, Color(0.9, 0.1, 0.1))
		draw_circle(Vector2(e.x + et.size * 0.3, e.y - et.size * 0.2), 1.5, Color(0.9, 0.1, 0.1))

		# Angry eyebrows
		draw_line(Vector2(e.x - et.size * 0.5, e.y - et.size * 0.5),
			Vector2(e.x - et.size * 0.1, e.y - et.size * 0.35), Color(0.2, 0.1, 0.05), 2)
		draw_line(Vector2(e.x + et.size * 0.5, e.y - et.size * 0.5),
			Vector2(e.x + et.size * 0.1, e.y - et.size * 0.35), Color(0.2, 0.1, 0.05), 2)

		# HP bar
		var hp_w = et.size * 2
		draw_rect(Rect2(e.x - hp_w/2, e.y - et.size - 6, hp_w, 3), Color(0.15, 0.15, 0.15))
		var hp_frac = float(e.hp) / e.max_hp
		draw_rect(Rect2(e.x - hp_w/2, e.y - et.size - 6, hp_w * hp_frac, 3),
			Color(0.2, 0.8, 0.2) if hp_frac > 0.5 else Color(0.9, 0.7, 0.1) if hp_frac > 0.25 else Color(0.9, 0.2, 0.1))

		# Slow indicator
		if e.slow_timer > 0:
			draw_circle(Vector2(e.x, e.y + et.size + 4), 3, Color(0.3, 0.5, 0.9, 0.5))

	# Draw projectiles
	for p in projectiles:
		match p.type:
			"note":
				draw_circle(Vector2(p.x, p.y), 4, p.color)
				draw_circle(Vector2(p.x, p.y), 2, Color(1, 1, 1, 0.5))
			"chord":
				draw_circle(Vector2(p.x, p.y), 5, p.color)
				draw_circle(Vector2(p.x - 3, p.y - 2), 2, p.color * 1.3)
				draw_circle(Vector2(p.x + 3, p.y + 2), 2, p.color * 1.3)
			"wave":
				draw_arc(Vector2(p.x, p.y), 6, 0, PI, 8, p.color, 3)
				draw_arc(Vector2(p.x, p.y), 3, PI, TAU, 6, p.color * 0.7, 2)
			"bass":
				draw_circle(Vector2(p.x, p.y), 7, Color(p.color.r, p.color.g, p.color.b, 0.5))
				draw_circle(Vector2(p.x, p.y), 4, p.color)
			"beat":
				draw_rect(Rect2(p.x - 3, p.y - 3, 6, 6), p.color)

	# HUD
	_draw_hud()

func _draw_hud() -> void:
	draw_rect(Rect2(0, 0, SW, 65), Color(0.12, 0.08, 0.04, 0.9))

	_text(20, 22, "PICKIN' DEFENSE", 14, Color(0.9, 0.8, 0.5))
	_text(20, 42, "Wave: " + str(wave) + "/" + str(max_waves), 10, Color(0.7, 0.6, 0.4))
	_text(20, 58, "Lives: " + str(lives), 10, Color(0.8, 0.3, 0.3) if lives <= 5 else Color(0.5, 0.8, 0.3))

	# Money
	_text(200, 22, "Scrap: $" + str(money), 12, Color(0.9, 0.85, 0.3))

	# Wave start button
	if state == State.PLAYING:
		draw_rect(Rect2(400, 10, 140, 40), Color(0.2, 0.35, 0.15))
		draw_rect(Rect2(400, 10, 140, 40), Color(0.3, 0.6, 0.2), false, 2)
		_text(415, 36, "START WAVE (Space)", 9, Color(0.6, 0.9, 0.4))
	elif state == State.WAVE_ACTIVE:
		_text(400, 36, "WAVE IN PROGRESS...", 10, Color(0.9, 0.5, 0.2))
		_text(400, 52, "Enemies: " + str(enemies_to_spawn - enemies_spawned) + " remaining", 8, Color(0.6, 0.5, 0.4))

	# Tower shop (right panel)
	var shop_x = GRID_X + GRID_COLS * CELL + 20
	draw_rect(Rect2(shop_x - 5, GRID_Y - 5, 165, GRID_ROWS * CELL + 10), Color(0.1, 0.08, 0.04, 0.7))
	_text(shop_x + 20, GRID_Y + 12, "INSTRUMENTS", 9, Color(0.8, 0.7, 0.5))

	for i in range(TOWERS.size()):
		var td = TOWERS[i]
		var by = GRID_Y + 20 + i * 56
		var selected = i == selected_tower
		var can_afford = money >= td.cost

		var bg = Color(0.15, 0.12, 0.06) if not selected else Color(0.25, 0.2, 0.1)
		if not can_afford:
			bg = Color(0.1, 0.08, 0.05)
		draw_rect(Rect2(shop_x, by, 150, 50), bg)
		if selected:
			draw_rect(Rect2(shop_x, by, 150, 50), Color(0.6, 0.5, 0.2), false, 2)

		# Icon
		draw_circle(Vector2(shop_x + 18, by + 20), 10, td.color if can_afford else td.color * 0.4)

		# Info
		var text_color = Color(0.8, 0.75, 0.6) if can_afford else Color(0.4, 0.35, 0.3)
		_text(shop_x + 34, by + 16, td.name, 8, text_color)
		_text(shop_x + 34, by + 30, "$" + str(td.cost), 8, Color(0.9, 0.8, 0.3) if can_afford else Color(0.5, 0.4, 0.3))
		_text(shop_x + 80, by + 30, "DMG:" + str(td.damage), 7, Color(0.7, 0.5, 0.4))
		_text(shop_x + 34, by + 44, td.desc, 6, Color(0.5, 0.45, 0.35))

func _draw_overlay(title: String, subtitle: String, color: Color) -> void:
	draw_rect(Rect2(0, 0, SW, SH), Color(0, 0, 0, 0.5))
	_text(250, 250, title, 32, color)
	_text(250, 300, subtitle, 12, Color(0.7, 0.65, 0.55))
	if fmod(timer, 1.0) < 0.6:
		_text(350, 400, "Click to restart", 14, Color(0.8, 0.75, 0.6))

func _text(x: float, y: float, text: String, size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
