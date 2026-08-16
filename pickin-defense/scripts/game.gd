extends Node2D

# ================================================================
# PICKIN' DEFENSE
# Tower defense where evil instruments attack the bluegrass stage!
# Place good instruments to blast the rogue ones with music.
# ================================================================

const SW = 1800
const SH = 1200
const CELL = 60
const GRID_COLS = 24
const GRID_ROWS = 16
const GRID_X = 60
const GRID_Y = 140

enum State { TITLE, PLAYING, WAVE_ACTIVE, GAME_OVER, VICTORY }

var state = State.TITLE
var timer = 0.0
var frame = 0

# Resources
var money = 5000
var lives = 20
var wave = 0
var max_waves = 100
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

	{"name": "Good Banjo", "cost": 5000, "damage": 100, "range": 600, "rate": 10.0,
	 "color": Color(1.0, 0.85, 0.3), "proj_color": Color(1, 0.9, 0.4),
	 "desc": "UNLOCKS WAVE 20! THE good banjo!", "proj_type": "note", "unlock_wave": 20},
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
	{"name": "Master Banjo", "hp": 500, "speed": 18, "reward": 200,
	 "color": Color(0.9, 0.75, 0.2), "size": 26, "desc": "BOSS — a legendary banjo virtuoso!"},

]

func _ready() -> void:
	_generate_path()

func _generate_path() -> void:
	# Generate a unique path for each wave/level
	path.clear()
	var seed_val = wave * 7919 + 42

	# Start from right side
	var start_y = 1 + (seed_val % (GRID_ROWS - 2))
	path.append(Vector2(GRID_X + GRID_COLS * CELL + 30, GRID_Y + start_y * CELL + CELL/2))

	# Generate zigzag waypoints
	var num_turns = 2 + (wave % 5)  # 2-6 turns
	var current_x = GRID_COLS - 1
	var current_y = start_y
	var going_down = true

	for i in range(num_turns):
		# Move horizontally
		var next_x = current_x - (2 + (seed_val + i * 137) % 3)
		next_x = maxi(next_x, 1)
		path.append(Vector2(GRID_X + next_x * CELL + CELL/2, GRID_Y + current_y * CELL + CELL/2))

		# Move vertically
		if going_down:
			current_y = mini(current_y + 2 + (seed_val + i * 91) % 3, GRID_ROWS - 2)
		else:
			current_y = maxi(current_y - 2 - (seed_val + i * 91) % 3, 1)
		going_down = not going_down

		path.append(Vector2(GRID_X + next_x * CELL + CELL/2, GRID_Y + current_y * CELL + CELL/2))
		current_x = next_x

		if current_x <= 2:
			break

	# End at the stage (left side)
	var end_y = 1 + (seed_val * 3) % (GRID_ROWS - 2)
	path.append(Vector2(GRID_X + 1 * CELL + CELL/2, GRID_Y + end_y * CELL + CELL/2))
	path.append(Vector2(GRID_X - 30, GRID_Y + end_y * CELL + CELL/2))


# === AUDIO ===
var audio_initialized = false

func _init_audio() -> void:
	if audio_initialized: return
	# Initialize Web Audio via JavaScript
	if OS.has_feature("web"):
		JavaScriptBridge.eval("""
			window._audioCtx = new (window.AudioContext || window.webkitAudioContext)();
			window._playNote = function(freq, duration, type, volume) {
				var ctx = window._audioCtx;
				if (ctx.state === 'suspended') ctx.resume();
				var osc = ctx.createOscillator();
				var gain = ctx.createGain();
				osc.type = type || 'sine';
				osc.frequency.setValueAtTime(freq, ctx.currentTime);
				gain.gain.setValueAtTime(volume || 0.1, ctx.currentTime);
				gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + duration);
				osc.connect(gain);
				gain.connect(ctx.destination);
				osc.start(ctx.currentTime);
				osc.stop(ctx.currentTime + duration);
			};
		""")
	audio_initialized = true

func _play_instrument_sound(instrument_name: String) -> void:
	if not OS.has_feature("web"): return
	_init_audio()
	match instrument_name:
		"Fiddle":
			# High pitched, sawtooth — like a bowed string
			JavaScriptBridge.eval("window._playNote(660, 0.15, 'sawtooth', 0.06)")
		"Guitar":
			# Mid range, triangle — warm strum
			JavaScriptBridge.eval("window._playNote(330, 0.2, 'triangle', 0.08)")
		"Mandolin":
			# High, quick tremolo — two rapid notes
			JavaScriptBridge.eval("window._playNote(880, 0.08, 'triangle', 0.05)")
			JavaScriptBridge.eval("setTimeout(function(){window._playNote(880, 0.08, 'triangle', 0.05)}, 50)")
		"Dobro":
			# Slide sound — frequency sweep
			JavaScriptBridge.eval("""
				var ctx = window._audioCtx;
				var osc = ctx.createOscillator();
				var gain = ctx.createGain();
				osc.type = 'sawtooth';
				osc.frequency.setValueAtTime(220, ctx.currentTime);
				osc.frequency.linearRampToValueAtTime(440, ctx.currentTime + 0.2);
				gain.gain.setValueAtTime(0.07, ctx.currentTime);
				gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.3);
				osc.connect(gain); gain.connect(ctx.destination);
				osc.start(); osc.stop(ctx.currentTime + 0.3);
			""")
		"Upright Bass":
			# Deep, thumpy — low sine
			JavaScriptBridge.eval("window._playNote(110, 0.25, 'sine', 0.12)")
		"Harmonica":
			# Breathy, square wave — organ-like
			JavaScriptBridge.eval("window._playNote(523, 0.18, 'square', 0.04)")
		"Washboard":
			# Percussive scratch — noise burst
			JavaScriptBridge.eval("""
				var ctx = window._audioCtx;
				var buf = ctx.createBuffer(1, ctx.sampleRate * 0.05, ctx.sampleRate);
				var data = buf.getChannelData(0);
				for (var i = 0; i < data.length; i++) data[i] = Math.random() * 2 - 1;
				var src = ctx.createBufferSource();
				var gain = ctx.createGain();
				src.buffer = buf;
				gain.gain.setValueAtTime(0.08, ctx.currentTime);
				gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.05);
				src.connect(gain); gain.connect(ctx.destination);
				src.start();
			""")
		"Dulcimer":
			# Rich harmonic — multiple frequencies
			JavaScriptBridge.eval("window._playNote(392, 0.3, 'triangle', 0.06)")
			JavaScriptBridge.eval("setTimeout(function(){window._playNote(494, 0.25, 'triangle', 0.04)}, 20)")

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
			elif Input.is_action_pressed("click") and selected_tower >= 0:
				_try_place_tower()
			if Input.is_action_just_pressed("start_wave"):
				_start_wave()
		State.WAVE_ACTIVE:
			if Input.is_action_just_pressed("click"):
				_handle_click()
			elif Input.is_action_pressed("click") and selected_tower >= 0:
				_try_place_tower()
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
	money = 5000
	lives = 20
	wave = 0
	towers.clear()
	enemies.clear()
	projectiles.clear()
	particles.clear()
	selected_tower = -1
	_generate_path()
	state = State.PLAYING

func _start_wave() -> void:
	wave += 1
	# Path already generated at end of previous wave (or at game start)
	if wave > max_waves:
		state = State.VICTORY
		return
	enemies_spawned = 0
	enemies_to_spawn = 5 + wave * 2
	if wave % 10 == 0 and wave > 0:
		enemies_to_spawn = 8 + wave  # boss wave has more enemies
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
			var locked = TOWERS[i].get("unlock_wave", 0) > wave
			if locked:
				return
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

func _try_place_tower() -> void:
	var mouse = get_global_mouse_position()
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
			boss_active = false
			state = State.PLAYING
			money += 20 + wave * 5  # wave bonus
			# Refund all towers and clear them for next wave
			for t in towers:
				money += TOWERS[t.type].cost
			towers.clear()
			selected_tower = -1
			# Generate next path so player can see it before starting
			_generate_path()

var boss_active = false
var boss_name = ""

func _spawn_enemy() -> void:
	# Boss wave every 10 levels!
	var is_boss_wave = wave % 10 == 0 and wave > 0

	# Pick enemy type based on wave
	var type_idx = 0

	if is_boss_wave and not boss_active and enemies_spawned == 0:
		type_idx = 8  # Master Banjo boss
		boss_active = true
		var boss_titles = ["The Picker", "The Shredder", "The Virtuoso", "The Legend",
			"Claw Hammer King", "Three Finger Terror", "The Roll Master",
			"Scruggs Style Slayer", "The Banjo Baron", "The Final Jam"]
		boss_name = boss_titles[mini((wave / 10) - 1, boss_titles.size() - 1)]
	elif is_boss_wave:
		# Support enemies during boss wave
		type_idx = randi_range(0, mini(wave / 5, ENEMIES.size() - 2))
	else:
		var r = randf()
		if wave >= 80 and r < 0.15:
			type_idx = 5  # Haunted Piano
		elif wave >= 50 and r < 0.2:
			type_idx = randi_range(4, 7)
		elif wave >= 20 and r < 0.25:
			type_idx = randi_range(2, 6)
		elif wave >= 8 and r < 0.3:
			type_idx = randi_range(1, 4)
		else:
			type_idx = randi_range(0, mini(2, ENEMIES.size() - 2))

	var et = ENEMIES[type_idx]
	var hp_scale = 1.0 + wave * 0.20  # 2% HP boost per wave
	if type_idx == 8:  # Master Banjo boss
		hp_scale = 1.0 + wave * 0.3  # boss scales harder
	enemies.append({
		"type": type_idx,
		"hp": int(et.hp * hp_scale),
		"max_hp": int(et.hp * hp_scale),
		"speed": et.speed * (1.0 + wave * 0.20),  # 2% speed boost per wave
		"base_speed": et.speed * (1.0 + wave * 0.20),
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
			# Play instrument sound!
			_play_instrument_sound(td.name)
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
					money += int(ENEMIES[e.type].reward * (1.0 + wave * 0.20))
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
	draw_rect(Rect2(400, 300, 1000, 600), Color(0.4, 0.2, 0.08))
	draw_rect(Rect2(420, 320, 960, 560), Color(0.5, 0.28, 0.12))
	# Barn roof
	var roof = PackedVector2Array([Vector2(360, 300), Vector2(900, 160), Vector2(1440, 300)])
	draw_colored_polygon(roof, Color(0.35, 0.15, 0.06))
	# Stage
	draw_rect(Rect2(500, 700, 800, 60), Color(0.45, 0.3, 0.15))
	draw_rect(Rect2(500, 700, 800, 10), Color(0.55, 0.38, 0.2))

	# Evil instruments approaching
	for i in range(5):
		var ex = 200 + i * 300 + sin(timer * 2 + i) * 40
		var ey = 840 + sin(timer * 1.5 + i * 0.7) * 20
		var ec = ENEMIES[i % ENEMIES.size()].color
		draw_circle(Vector2(ex, ey), 24, ec)
		draw_circle(Vector2(ex - 6, ey - 6), 6, Color(1, 0.2, 0.1))
		draw_circle(Vector2(ex + 6, ey - 6), 6, Color(1, 0.2, 0.1))

	_text(500, 460, "PICKIN'", 84, Color(0.95, 0.85, 0.5))
	_text(520, 560, "DEFENSE", 76, Color(0.9, 0.75, 0.4))
	_text(520, 640, "Where the music fights back!", 24, Color(0.7, 0.6, 0.4))
	if fmod(timer, 1.0) < 0.6:
		_text(700, 1000, "CLICK TO START", 32, Color(0.9, 0.8, 0.5))

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

		# Detailed instrument drawing
		match td.name:
			"Fiddle":
				# Body — figure 8 shape
				draw_circle(Vector2(tx, ty + 4), 9, td.color * 0.6)
				draw_circle(Vector2(tx, ty - 4), 8, td.color * 0.6)
				draw_circle(Vector2(tx, ty + 3), 7, td.color)
				draw_circle(Vector2(tx, ty - 3), 6, td.color * 1.1)
				# Waist
				draw_rect(Rect2(tx - 4, ty - 2, 8, 4), td.color * 0.8)
				# F-holes
				draw_line(Vector2(tx - 3, ty - 4), Vector2(tx - 2, ty + 2), Color(0.2, 0.1, 0.05), 1)
				draw_line(Vector2(tx + 3, ty - 4), Vector2(tx + 2, ty + 2), Color(0.2, 0.1, 0.05), 1)
				# Neck
				draw_rect(Rect2(tx - 1, ty - 14, 3, 12), td.color * 0.7)
				# Scroll
				draw_circle(Vector2(tx, ty - 16), 3, td.color * 0.5)
				# Strings
				for s in range(4):
					draw_line(Vector2(tx - 2 + s, ty - 14), Vector2(tx - 2 + s, ty + 8), Color(0.7, 0.7, 0.7, 0.4), 1)
				# Bow
				draw_line(Vector2(tx + 10, ty - 12), Vector2(tx + 14, ty + 10), Color(0.5, 0.4, 0.2), 2)
				draw_line(Vector2(tx + 11, ty - 11), Vector2(tx + 13, ty + 9), Color(0.8, 0.8, 0.7, 0.3), 1)
			"Guitar":
				# Body — big round bottom, waist, smaller top
				draw_circle(Vector2(tx, ty + 5), 11, td.color * 0.6)
				draw_circle(Vector2(tx, ty + 4), 9, td.color)
				draw_circle(Vector2(tx, ty - 3), 7, td.color * 0.7)
				# Sound hole
				draw_circle(Vector2(tx, ty + 3), 4, Color(0.15, 0.08, 0.03))
				draw_circle(Vector2(tx, ty + 3), 3, Color(0.1, 0.05, 0.02))
				# Neck
				draw_rect(Rect2(tx - 2, ty - 18, 5, 16), td.color * 0.65)
				draw_rect(Rect2(tx - 1, ty - 17, 3, 14), td.color * 0.55)
				# Headstock
				draw_rect(Rect2(tx - 3, ty - 22, 7, 5), td.color * 0.5)
				# Tuning pegs
				for p in range(3):
					draw_rect(Rect2(tx - 4, ty - 21 + p * 2, 2, 1), Color(0.7, 0.7, 0.6))
					draw_rect(Rect2(tx + 3, ty - 21 + p * 2, 2, 1), Color(0.7, 0.7, 0.6))
				# Strings
				for s in range(6):
					draw_line(Vector2(tx - 2 + s, ty - 18), Vector2(tx - 2 + s, ty + 10), Color(0.8, 0.8, 0.7, 0.3), 1)
				# Bridge
				draw_rect(Rect2(tx - 5, ty + 8, 10, 2), Color(0.3, 0.2, 0.1))
			"Mandolin":
				# Teardrop body
				draw_circle(Vector2(tx, ty + 2), 8, td.color * 0.6)
				draw_circle(Vector2(tx, ty + 1), 6, td.color)
				# Sound hole
				draw_circle(Vector2(tx, ty + 2), 3, Color(0.15, 0.1, 0.03))
				# Neck (shorter than guitar)
				draw_rect(Rect2(tx - 1, ty - 12, 3, 10), td.color * 0.7)
				# Scroll
				draw_circle(Vector2(tx, ty - 14), 3, td.color * 0.5)
				# Strings
				for s in range(4):
					draw_line(Vector2(tx - 1 + s, ty - 12), Vector2(tx - 1 + s, ty + 6), Color(0.8, 0.8, 0.7, 0.3), 1)
				# Pick guard
				draw_circle(Vector2(tx + 3, ty + 4), 3, Color(0.2, 0.15, 0.05, 0.5))
			"Dobro":
				# Round body with resonator cone
				draw_circle(Vector2(tx, ty + 2), 12, td.color * 0.7)
				draw_circle(Vector2(tx, ty + 1), 10, td.color)
				# Resonator cone (concentric circles)
				draw_circle(Vector2(tx, ty + 2), 7, Color(0.55, 0.55, 0.6))
				draw_circle(Vector2(tx, ty + 2), 5, Color(0.6, 0.6, 0.65))
				draw_circle(Vector2(tx, ty + 2), 3, Color(0.5, 0.5, 0.55))
				# Neck
				draw_rect(Rect2(tx - 2, ty - 16, 4, 14), td.color * 0.6)
				# Headstock
				draw_rect(Rect2(tx - 3, ty - 20, 6, 5), td.color * 0.5)
			"Upright Bass":
				# Tall body
				draw_circle(Vector2(tx, ty + 4), 10, td.color * 0.6)
				draw_circle(Vector2(tx, ty + 3), 8, td.color)
				draw_circle(Vector2(tx, ty - 4), 7, td.color * 0.7)
				# Waist
				draw_rect(Rect2(tx - 4, ty - 1, 8, 3), td.color * 0.8)
				# F-holes
				draw_line(Vector2(tx - 3, ty - 3), Vector2(tx - 2, ty + 4), Color(0.15, 0.08, 0.03), 1)
				draw_line(Vector2(tx + 3, ty - 3), Vector2(tx + 2, ty + 4), Color(0.15, 0.08, 0.03), 1)
				# Very long neck
				draw_rect(Rect2(tx - 1, ty - 22, 3, 20), td.color * 0.6)
				# Scroll
				draw_circle(Vector2(tx, ty - 24), 3, td.color * 0.4)
				# Endpin
				draw_line(Vector2(tx, ty + 12), Vector2(tx, ty + 18), Color(0.4, 0.4, 0.45), 2)
			"Harmonica":
				# Rectangular body
				draw_rect(Rect2(tx - 12, ty - 4, 24, 8), td.color * 0.6)
				draw_rect(Rect2(tx - 10, ty - 3, 20, 6), td.color)
				# Holes
				for h in range(5):
					draw_rect(Rect2(tx - 8 + h * 4, ty - 2, 3, 4), Color(0.2, 0.2, 0.22))
				# Cover plates
				draw_rect(Rect2(tx - 12, ty - 4, 24, 2), td.color * 1.2)
				draw_rect(Rect2(tx - 12, ty + 2, 24, 2), td.color * 1.2)
			"Washboard":
				# Rectangular board
				draw_rect(Rect2(tx - 8, ty - 12, 16, 24), Color(0.5, 0.5, 0.48))
				draw_rect(Rect2(tx - 6, ty - 10, 12, 20), Color(0.55, 0.55, 0.52))
				# Ridges
				for r in range(8):
					draw_line(Vector2(tx - 5, ty - 8 + r * 3), Vector2(tx + 5, ty - 8 + r * 3), Color(0.45, 0.45, 0.42), 1)
				# Handle at top
				draw_rect(Rect2(tx - 4, ty - 14, 8, 3), Color(0.4, 0.3, 0.15))
			"Dulcimer":
				# Long hourglass body
				draw_circle(Vector2(tx, ty + 6), 8, td.color * 0.6)
				draw_circle(Vector2(tx, ty - 4), 7, td.color * 0.6)
				draw_circle(Vector2(tx, ty + 5), 6, td.color)
				draw_circle(Vector2(tx, ty - 3), 5, td.color * 1.1)
				# Narrow middle
				draw_rect(Rect2(tx - 3, ty - 1, 6, 4), td.color * 0.85)
				# Sound holes (heart shapes approximated)
				draw_circle(Vector2(tx - 2, ty + 3), 2, Color(0.15, 0.1, 0.05))
				draw_circle(Vector2(tx + 2, ty + 3), 2, Color(0.15, 0.1, 0.05))
				# Strings
				for s in range(3):
					draw_line(Vector2(tx - 1 + s, ty - 8), Vector2(tx - 1 + s, ty + 10), Color(0.8, 0.7, 0.5, 0.4), 1)
				# Tuning pegs
				draw_rect(Rect2(tx - 3, ty - 10, 6, 3), td.color * 0.5)

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

		# Instrument body shape based on type
		var ex = e.x
		var ey = e.y
		var es = et.size
		match et.name:
			"Evil Banjo":
				# Detailed banjo — round pot with skin head, neck, frets, pegs
				draw_circle(Vector2(ex, ey + 3), es + 1, Color(0.25, 0.15, 0.05))
				draw_circle(Vector2(ex, ey + 2), es, et.color * 0.6)
				draw_circle(Vector2(ex, ey + 1), es - 2, et.color)
				# Skin head
				draw_circle(Vector2(ex, ey + 1), es - 4, Color(0.85, 0.8, 0.65))
				# Bridge
				draw_rect(Rect2(ex - 3, ey - 1, 6, 2), Color(0.45, 0.3, 0.1))
				# Neck with frets
				draw_rect(Rect2(ex - 2, ey - es - 8, 4, es + 4), et.color * 0.55)
				for f in range(5):
					draw_line(Vector2(ex - 2, ey - es + f * 3), Vector2(ex + 2, ey - es + f * 3), Color(0.7, 0.7, 0.6, 0.4), 1)
				# Peghead
				draw_rect(Rect2(ex - 3, ey - es - 14, 7, 7), et.color * 0.45)
				for p in range(4):
					draw_rect(Rect2(ex - 4, ey - es - 13 + p * 2, 2, 1), Color(0.75, 0.7, 0.5))
					draw_rect(Rect2(ex + 3, ey - es - 13 + p * 2, 2, 1), Color(0.75, 0.7, 0.5))
				# 5th string peg (banjo specific!)
				draw_rect(Rect2(ex + 2, ey - es/2 - 2, 2, 1), Color(0.75, 0.7, 0.5))
				# Strings
				for s in range(5):
					draw_line(Vector2(ex - 2 + s, ey - es - 8), Vector2(ex - 2 + s, ey + es - 4), Color(0.8, 0.8, 0.7, 0.3), 1)
				# Armrest
				draw_arc(Vector2(ex, ey + 1), es - 1, 0.3, 1.2, 8, Color(0.5, 0.4, 0.15), 2)
			"Angry Drum":
				# Snare drum with shell, heads, tension rods, drumsticks
				draw_rect(Rect2(ex - es, ey - es/2 + 2, es * 2, es - 2), et.color * 0.55)
				draw_rect(Rect2(ex - es + 1, ey - es/2 + 3, es * 2 - 2, es - 4), et.color * 0.7)
				# Top head
				draw_circle(Vector2(ex, ey - es/2 + 2), es * 0.85, et.color * 0.9)
				draw_circle(Vector2(ex, ey - es/2 + 2), es * 0.75, Color(0.8, 0.75, 0.65))
				# Rim
				draw_arc(Vector2(ex, ey - es/2 + 2), es * 0.85, 0, TAU, 16, Color(0.7, 0.65, 0.3), 2)
				# Tension rods
				for r in range(8):
					var angle = r * TAU / 8
					var rx = ex + cos(angle) * (es - 1)
					draw_rect(Rect2(rx - 1, ey - 1, 3, 3), Color(0.65, 0.6, 0.35))
				# Drumsticks crossed
				draw_line(Vector2(ex - es + 3, ey - es/2 - 4), Vector2(ex + es/2, ey - es/2 + 6), Color(0.6, 0.45, 0.2), 2)
				draw_line(Vector2(ex + es - 3, ey - es/2 - 4), Vector2(ex - es/2, ey - es/2 + 6), Color(0.6, 0.45, 0.2), 2)
				draw_circle(Vector2(ex + es/2, ey - es/2 + 6), 2, Color(0.65, 0.5, 0.25))
				draw_circle(Vector2(ex - es/2, ey - es/2 + 6), 2, Color(0.65, 0.5, 0.25))
			"Possessed Tuba":
				# Tuba with bell, coils, valves, mouthpiece
				draw_circle(Vector2(ex - 2, ey + 2), es - 2, et.color * 0.5)
				draw_arc(Vector2(ex - 2, ey), es - 6, 0.5, TAU - 0.5, 16, et.color * 0.85, 3)
				# Bell
				draw_circle(Vector2(ex + es/3, ey - es/2), es * 0.65, et.color * 1.1)
				draw_circle(Vector2(ex + es/3, ey - es/2), es * 0.35, Color(0.12, 0.1, 0.04))
				draw_arc(Vector2(ex + es/3, ey - es/2), es * 0.65, 0, TAU, 16, Color(0.65, 0.6, 0.2), 2)
				# Valves
				for v in range(3):
					draw_rect(Rect2(ex - 6 + v * 5, ey + es/3 - 4, 4, 6), Color(0.7, 0.65, 0.3))
					draw_circle(Vector2(ex - 4 + v * 5, ey + es/3 - 5), 2, Color(0.75, 0.7, 0.35))
				# Mouthpiece
				draw_line(Vector2(ex - es/2, ey + 4), Vector2(ex - es, ey - 2), et.color * 0.6, 3)
				draw_circle(Vector2(ex - es, ey - 2), 3, et.color * 0.8)
			"Rogue Trumpet":
				# Trumpet with bell, tube, valves, mouthpiece
				draw_rect(Rect2(ex - es + 2, ey - 2, es * 1.2, 4), et.color * 0.75)
				draw_rect(Rect2(ex - es + 3, ey - 1, es * 1.2 - 2, 2), et.color * 0.9)
				# Bell
				draw_circle(Vector2(ex + es * 0.7, ey), es * 0.5, et.color * 1.15)
				draw_circle(Vector2(ex + es * 0.7, ey), es * 0.3, Color(0.12, 0.1, 0.04))
				draw_arc(Vector2(ex + es * 0.7, ey), es * 0.5, -1.2, 1.2, 10, Color(0.75, 0.7, 0.35), 2)
				# Valves
				for v in range(3):
					var vx = ex - es/3 + 2 + v * 4
					draw_rect(Rect2(vx, ey - 7, 3, 5), Color(0.75, 0.7, 0.35))
					draw_circle(Vector2(vx + 1, ey - 8), 2, Color(0.8, 0.75, 0.4))
				# Slide tubes
				draw_arc(Vector2(ex - es/4, ey + 5), 6, 0, PI, 8, et.color * 0.6, 2)
				# Mouthpiece
				draw_line(Vector2(ex - es + 2, ey), Vector2(ex - es - 3, ey), et.color * 0.7, 3)
				draw_circle(Vector2(ex - es - 4, ey), 3, et.color * 0.85)
			"Dark Accordion":
				# Accordion with bellows, keyboard, buttons
				draw_rect(Rect2(ex - es, ey - es/2, es * 0.6, es), et.color * 0.5)
				# Bass buttons
				for by2 in range(4):
					for bx2 in range(2):
						draw_circle(Vector2(ex - es + 5 + bx2 * 5, ey - es/3 + by2 * 5), 2, Color(0.2, 0.15, 0.25))
				# Bellows
				for fold in range(5):
					var fx = ex - es * 0.2 + fold * (es * 0.1)
					draw_rect(Rect2(fx, ey - es/2, es * 0.1, es), Color(et.color.r * 0.35, et.color.g * 0.25, et.color.b * 0.4, 0.5))
				# Keyboard side
				draw_rect(Rect2(ex + es * 0.3, ey - es/2, es * 0.7, es), et.color * 0.6)
				for k in range(6):
					var ky = ey - es/2 + 4 + k * (es / 7)
					draw_rect(Rect2(ex + es * 0.6, ky, es * 0.25, es/8), Color(0.9, 0.88, 0.82))
					draw_rect(Rect2(ex + es * 0.65, ky, es * 0.12, es/12), Color(0.15, 0.12, 0.1))
			"Haunted Piano":
				# Grand piano with lid, keyboard, legs, ghostly aura
				var ghost_pulse = 0.3 + sin(timer * 4) * 0.15
				draw_circle(Vector2(ex, ey), es + 6, Color(0.3, 0.1, 0.4, ghost_pulse * 0.15))
				draw_circle(Vector2(ex - 2, ey), es, et.color * 0.55)
				draw_rect(Rect2(ex - es + 4, ey - es/2, es * 1.5, es), et.color * 0.8)
				# Lid prop
				draw_line(Vector2(ex + es * 0.3, ey - es/2), Vector2(ex + es * 0.5, ey - es * 0.7), et.color * 0.5, 2)
				# Keyboard
				for k in range(12):
					var kx = ex - es + 6 + k * (es * 1.4 / 12)
					draw_rect(Rect2(kx, ey + es/2 - 4, es/10, 6), Color(0.9, 0.88, 0.82))
					if k % 7 in [1, 2, 4, 5, 6]:
						draw_rect(Rect2(kx + 1, ey + es/2 - 4, es/16, 4), Color(0.1, 0.08, 0.06))
				# Legs
				for lx in [ex - es/2, ex, ex + es/2]:
					draw_line(Vector2(lx, ey + es/2 + 2), Vector2(lx, ey + es/2 + 8), et.color * 0.4, 2)
			"Cursed Saxophone":
				# Saxophone with curved body, bell, keys
				draw_arc(Vector2(ex, ey + 3), es * 0.7, -0.5, PI + 0.5, 12, et.color * 0.7, 4)
				draw_arc(Vector2(ex, ey + 3), es * 0.7, -0.5, PI + 0.5, 12, et.color, 2)
				# Bell
				draw_circle(Vector2(ex + es * 0.5, ey + es * 0.4), es * 0.4, et.color * 1.1)
				draw_circle(Vector2(ex + es * 0.5, ey + es * 0.4), es * 0.25, Color(0.1, 0.08, 0.03))
				# Straight section
				draw_rect(Rect2(ex - 2, ey - es/2, 4, es * 0.8), et.color * 0.8)
				# Keys
				for k in range(6):
					draw_circle(Vector2(ex + 3, ey - es/2 + 3 + k * (es * 0.12)), 2, Color(0.8, 0.75, 0.6))
				# Mouthpiece
				draw_line(Vector2(ex, ey - es/2), Vector2(ex - 4, ey - es/2 - 6), et.color * 0.6, 3)
				draw_rect(Rect2(ex - 6, ey - es/2 - 8, 4, 4), Color(0.2, 0.18, 0.1))
			"Wicked Bagpipe":
				# Bagpipe with bag, drones, chanter, tartan pattern
				draw_circle(Vector2(ex, ey + 2), es * 0.8, et.color * 0.5)
				draw_circle(Vector2(ex, ey), es * 0.7, et.color)
				draw_circle(Vector2(ex + 1, ey - 1), es * 0.55, et.color * 1.15)
				# Tartan pattern
				for stripe in range(3):
					draw_line(Vector2(ex - es * 0.5, ey - es * 0.3 + stripe * 5), Vector2(ex + es * 0.5, ey - es * 0.3 + stripe * 5), Color(0.2, 0.35, 0.15, 0.3), 1)
					draw_line(Vector2(ex - es * 0.3 + stripe * 5, ey - es * 0.5), Vector2(ex - es * 0.3 + stripe * 5, ey + es * 0.5), Color(0.2, 0.35, 0.15, 0.3), 1)
				# Drones (3 tall pipes)
				for d in range(3):
					var dx2 = ex - 4 + d * 4
					draw_rect(Rect2(dx2, ey - es - 10, 3, es + 6), et.color * 0.4)
					draw_rect(Rect2(dx2 - 1, ey - es - 15, 5, 4), et.color * 0.5)
				# Chanter
				draw_rect(Rect2(ex + es/3, ey + 2, 3, es * 0.7), et.color * 0.4)
				for h in range(4):
					draw_circle(Vector2(ex + es/3 + 1, ey + 6 + h * 4), 1, Color(0.1, 0.08, 0.04))
				# Blowpipe
				draw_line(Vector2(ex - es * 0.4, ey - 2), Vector2(ex - es * 0.7, ey - es * 0.5), et.color * 0.45, 2)
			"Master Banjo":
				# BOSS — giant glowing banjo player
				# Glow aura
				var boss_pulse = 0.5 + sin(timer * 3) * 0.2
				draw_circle(Vector2(ex, ey), es + 8, Color(0.9, 0.7, 0.1, 0.1 * boss_pulse))
				draw_circle(Vector2(ex, ey), es + 4, Color(0.9, 0.7, 0.1, 0.15 * boss_pulse))
				# Body — big round banjo body
				draw_circle(Vector2(ex, ey + 4), es, et.color * 0.5)
				draw_circle(Vector2(ex, ey + 2), es - 3, et.color)
				draw_circle(Vector2(ex, ey + 2), es - 6, et.color * 1.2)
				# Banjo skin
				draw_circle(Vector2(ex, ey + 2), es - 8, Color(0.9, 0.85, 0.7))
				draw_circle(Vector2(ex, ey + 2), es - 12, Color(0.85, 0.8, 0.65))
				# Bridge
				draw_rect(Rect2(ex - 4, ey, 8, 2), Color(0.5, 0.35, 0.15))
				# Long neck
				draw_rect(Rect2(ex - 2, ey - es - 10, 5, es + 6), et.color * 0.6)
				draw_rect(Rect2(ex - 1, ey - es - 8, 3, es + 4), et.color * 0.5)
				# Headstock with tuning pegs
				draw_rect(Rect2(ex - 4, ey - es - 16, 9, 7), et.color * 0.4)
				for p in range(4):
					draw_rect(Rect2(ex - 5, ey - es - 15 + p * 2, 2, 1), Color(0.8, 0.8, 0.7))
					draw_rect(Rect2(ex + 4, ey - es - 15 + p * 2, 2, 1), Color(0.8, 0.8, 0.7))
				# Strings — vibrating!
				for s in range(5):
					var vibrate = sin(timer * 20 + s * 2) * 1.5
					draw_line(Vector2(ex - 2 + s + vibrate, ey - es - 8), Vector2(ex - 2 + s, ey + 6), Color(0.9, 0.85, 0.7, 0.5), 1)
				# Crown / hat (the boss is special!)
				draw_rect(Rect2(ex - 8, ey - es - 22, 17, 4), Color(0.8, 0.6, 0.1))
				draw_rect(Rect2(ex - 5, ey - es - 28, 11, 7), Color(0.9, 0.7, 0.15))
				draw_rect(Rect2(ex - 2, ey - es - 30, 5, 3), Color(1.0, 0.85, 0.3))
				# Musical notes floating around the boss
				for n in range(4):
					var nx = ex + cos(timer * 2 + n * TAU/4) * (es + 12)
					var ny = ey + sin(timer * 2 + n * TAU/4) * (es + 8) - 5
					_text(nx - 3, ny + 3, "♪", 10, Color(1, 0.9, 0.3, 0.6))
			_:
				# Default round body
				draw_circle(Vector2(ex, ey), es, et.color * 0.6)
				draw_circle(Vector2(ex, ey - 2), es - 2, et.color)

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
	draw_rect(Rect2(0, 0, SW, 130), Color(0.12, 0.08, 0.04, 0.9))

	_text(40, 44, "PICKIN' DEFENSE", 28, Color(0.9, 0.8, 0.5))
	_text(40, 84, "Wave: " + str(wave) + "/" + str(max_waves), 20, Color(0.7, 0.6, 0.4))
	_text(40, 116, "Lives: " + str(lives), 20, Color(0.8, 0.3, 0.3) if lives <= 5 else Color(0.5, 0.8, 0.3))

	# Money
	_text(400, 44, "Scrap: $" + str(money), 24, Color(0.9, 0.85, 0.3))

	# Wave start button
	if state == State.PLAYING:
		draw_rect(Rect2(800, 20, 280, 80), Color(0.2, 0.35, 0.15))
		draw_rect(Rect2(800, 20, 280, 80), Color(0.3, 0.6, 0.2), false, 2)
		_text(830, 72, "START WAVE (Space)", 18, Color(0.6, 0.9, 0.4))
	elif state == State.WAVE_ACTIVE:
		if wave % 10 == 0 and wave > 0:
			_text(700, 72, "BOSS WAVE! " + boss_name, 24, Color(1.0, 0.8, 0.2))
		else:
			_text(800, 72, "WAVE IN PROGRESS...", 20, Color(0.9, 0.5, 0.2))
		_text(800, 104, "Enemies: " + str(enemies_to_spawn - enemies_spawned) + " remaining", 16, Color(0.6, 0.5, 0.4))

	# Tower shop (right panel)
	var shop_x = GRID_X + GRID_COLS * CELL + 20
	draw_rect(Rect2(shop_x - 5, GRID_Y - 5, 165, TOWERS.size() * 56 + 30), Color(0.1, 0.08, 0.04, 0.7))
	_text(shop_x + 20, GRID_Y + 12, "INSTRUMENTS", 9, Color(0.8, 0.7, 0.5))

	for i in range(TOWERS.size()):
		var td = TOWERS[i]
		var by = GRID_Y + 20 + i * 56
		var locked = td.get("unlock_wave", 0) > wave
		var selected = i == selected_tower
		var can_afford = money >= td.cost and not locked

		var bg = Color(0.15, 0.12, 0.06) if not selected else Color(0.25, 0.2, 0.1)
		if locked:
			bg = Color(0.06, 0.05, 0.03)
		elif not can_afford:
			bg = Color(0.1, 0.08, 0.05)
		draw_rect(Rect2(shop_x, by, 150, 50), bg)
		if selected and not locked:
			draw_rect(Rect2(shop_x, by, 150, 50), Color(0.6, 0.5, 0.2), false, 2)
		if locked:
			draw_rect(Rect2(shop_x, by, 150, 50), Color(0.3, 0.1, 0.3), false, 1)

		# Icon
		draw_circle(Vector2(shop_x + 18, by + 20), 10, td.color if can_afford else td.color * 0.3)

		# Info
		if locked:
			_text(shop_x + 34, by + 16, td.name, 8, Color(0.4, 0.2, 0.4))
			_text(shop_x + 34, by + 30, "LOCKED", 8, Color(0.5, 0.2, 0.4))
			_text(shop_x + 34, by + 44, "Unlocks at wave " + str(td.unlock_wave), 6, Color(0.4, 0.2, 0.35))
		else:
			var text_color = Color(0.8, 0.75, 0.6) if can_afford else Color(0.4, 0.35, 0.3)
			_text(shop_x + 34, by + 16, td.name, 8, text_color)
			_text(shop_x + 34, by + 30, "$" + str(td.cost), 8, Color(0.9, 0.8, 0.3) if can_afford else Color(0.5, 0.4, 0.3))
			_text(shop_x + 80, by + 30, "DMG:" + str(td.damage), 7, Color(0.7, 0.5, 0.4))
			_text(shop_x + 34, by + 44, td.desc, 6, Color(0.5, 0.45, 0.35))

func _draw_overlay(title: String, subtitle: String, color: Color) -> void:
	draw_rect(Rect2(0, 0, SW, SH), Color(0, 0, 0, 0.5))
	_text(500, 500, title, 64, color)
	_text(500, 600, subtitle, 24, Color(0.7, 0.65, 0.55))
	if fmod(timer, 1.0) < 0.6:
		_text(700, 800, "Click to restart", 28, Color(0.8, 0.75, 0.6))

func _text(x: float, y: float, text: String, size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
