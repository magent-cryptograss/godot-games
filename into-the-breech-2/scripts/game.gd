extends Node2D

# ================================================================
# INTO THE BREECH 2
# Turn-based tactical mech combat on an 8x8 grid
# Key mechanic: enemy attacks are telegraphed — you see what they'll
# do BEFORE you move, so you can push/block/redirect
# ================================================================

const GRID = 8
const CELL = 64          # pixel size of each cell
const BOARD_X = 80       # board offset X
const BOARD_Y = 40       # board offset Y

enum Phase { PLAYER_SELECT, PLAYER_MOVE, PLAYER_ATTACK, ENEMY_TURN, ANIMATE, GAME_OVER, TITLE, VICTORY }

var phase = Phase.TITLE
var turn = 1
var anim_timer = 0.0
var title_timer = 0.0
var message = ""
var message_timer = 0.0

# --- BOARD ---
# Each cell can have: terrain, building, unit
var terrain = []  # 2D array: "ground", "mountain", "water", "forest", "chasm"
var buildings = []  # 2D array: 0 = no building, 1-4 = building HP
var grid_power = 7  # total grid power (buildings alive)
var max_power = 7

# --- UNITS ---
var mechs = []     # player mechs
var enemies = []   # Vek enemies
var enemy_intents = []  # what enemies plan to do (shown to player)

# --- SELECTION ---
var selected_mech = -1
var hover_cell = Vector2i(-1, -1)
var valid_moves = []
var valid_attacks = []
var attack_mode = false

# --- ANIMATION ---
var animations = []  # queued visual animations

# Mech types
const MECH_TYPES = {
	"artillery": {
		"name": "Artillery Mech",
		"hp": 3, "max_hp": 3,
		"move": 3,
		"damage": 2,
		"range_min": 2, "range_max": 4,
		"attack_type": "artillery",  # hits target + pushes adjacent
		"color": Color(0.3, 0.5, 0.9),
		"desc": "Long range. Pushes adjacent enemies.",
	},
	"combat": {
		"name": "Combat Mech",
		"hp": 3, "max_hp": 3,
		"move": 3,
		"damage": 3,
		"range_min": 1, "range_max": 1,
		"attack_type": "punch",  # melee, pushes target
		"color": Color(0.8, 0.4, 0.2),
		"desc": "Melee. Punches and pushes target.",
	},
	"cannon": {
		"name": "Cannon Mech",
		"hp": 3, "max_hp": 3,
		"move": 2,
		"damage": 1,
		"range_min": 1, "range_max": 5,
		"attack_type": "cannon",  # line attack, pushes target back
		"color": Color(0.2, 0.7, 0.3),
		"desc": "Ranged line. Pushes target backward.",
	},
}

# Enemy types
const ENEMY_TYPES = {
	"hornet": {
		"name": "Hornet",
		"hp": 1,
		"damage": 1,
		"move": 4,
		"attack_type": "sting",  # attacks adjacent
		"color": Color(0.8, 0.7, 0.2),
	},
	"beetle": {
		"name": "Beetle",
		"hp": 3,
		"damage": 2,
		"move": 2,
		"attack_type": "charge",  # charges in a line
		"color": Color(0.6, 0.3, 0.15),
	},
	"scorpion": {
		"name": "Scorpion",
		"hp": 2,
		"damage": 2,
		"move": 2,
		"attack_type": "emerging",  # attacks tile it's on (emerges)
		"color": Color(0.5, 0.2, 0.2),
	},
	"firefly": {
		"name": "Firefly",
		"hp": 2,
		"damage": 1,
		"move": 2,
		"attack_type": "ranged",  # shoots 3 tiles
		"color": Color(0.7, 0.5, 0.1),
	},
}


# Sprite textures
var tex_ground: Texture2D = null
var tex_water: Texture2D = null
var tex_mountain: Texture2D = null
var tex_forest: Texture2D = null
var tex_building: Texture2D = null
var tex_mechs = {}
var tex_enemies = {}

func _load_textures() -> void:
	tex_ground = _try_load("res://sprites/ground.png")
	tex_water = _try_load("res://sprites/water.png")
	tex_mountain = _try_load("res://sprites/mountain.png")
	tex_forest = _try_load("res://sprites/forest.png")
	tex_building = _try_load("res://sprites/building.png")
	tex_mechs["artillery"] = _try_load("res://sprites/mech_artillery.png")
	tex_mechs["combat"] = _try_load("res://sprites/mech_combat.png")
	tex_mechs["cannon"] = _try_load("res://sprites/mech_cannon.png")
	tex_enemies["hornet"] = _try_load("res://sprites/enemy_hornet.png")
	tex_enemies["beetle"] = _try_load("res://sprites/enemy_beetle.png")
	tex_enemies["scorpion"] = _try_load("res://sprites/enemy_scorpion.png")
	tex_enemies["firefly"] = _try_load("res://sprites/enemy_firefly.png")

func _try_load(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	return null

func _ready() -> void:
	_load_textures()

func _process(delta: float) -> void:
	match phase:
		Phase.TITLE:
			title_timer += delta
			if Input.is_action_just_pressed("click"):
				_start_game()
		Phase.PLAYER_SELECT, Phase.PLAYER_MOVE, Phase.PLAYER_ATTACK:
			_update_hover()
			if Input.is_action_just_pressed("click"):
				_handle_click()
			if Input.is_action_just_pressed("end_turn"):
				_end_player_turn()
			if Input.is_action_just_pressed("undo") and selected_mech >= 0:
				_deselect()
		Phase.ANIMATE:
			anim_timer -= delta
			if anim_timer <= 0:
				phase = Phase.PLAYER_SELECT
		Phase.ENEMY_TURN:
			_execute_enemy_turn()
		Phase.GAME_OVER, Phase.VICTORY:
			if Input.is_action_just_pressed("click"):
				_start_game()

	if message_timer > 0:
		message_timer -= delta

	queue_redraw()

# ================================================================
# GAME SETUP
# ================================================================
func _start_game() -> void:
	turn = 1
	grid_power = max_power
	_generate_map()
	_spawn_mechs()
	_spawn_enemies()
	_calculate_enemy_intents()
	phase = Phase.PLAYER_SELECT
	message = "Turn 1 — Move your mechs!"
	message_timer = 3.0

func _generate_map() -> void:
	terrain = []
	buildings = []
	for y in range(GRID):
		var t_row = []
		var b_row = []
		for x in range(GRID):
			var r = randf()
			if r < 0.08:
				t_row.append("mountain")
			elif r < 0.14:
				t_row.append("water")
			elif r < 0.18:
				t_row.append("forest")
			else:
				t_row.append("ground")
			# Buildings on some ground tiles
			if t_row[x] == "ground" and randf() < 0.15 and x > 0 and y > 0 and x < GRID-1 and y < GRID-1:
				b_row.append(1)  # building with 1 HP
			else:
				b_row.append(0)
		terrain.append(t_row)
		buildings.append(b_row)

	# Count buildings for grid power
	grid_power = 0
	for y in range(GRID):
		for x in range(GRID):
			if buildings[y][x] > 0:
				grid_power += 1
	max_power = grid_power

func _spawn_mechs() -> void:
	mechs.clear()
	var types = ["artillery", "combat", "cannon"]
	var positions = [Vector2i(1, 6), Vector2i(3, 6), Vector2i(5, 6)]
	for i in range(3):
		# Make sure position is valid
		var pos = positions[i]
		terrain[pos.y][pos.x] = "ground"
		buildings[pos.y][pos.x] = 0
		var mt = MECH_TYPES[types[i]]
		mechs.append({
			"type": types[i],
			"pos": pos,
			"hp": mt.hp,
			"max_hp": mt.max_hp,
			"moved": false,
			"attacked": false,
			"alive": true,
		})

func _spawn_enemies() -> void:
	enemies.clear()
	var count = 3 + turn
	var etypes = ENEMY_TYPES.keys()
	for i in range(mini(count, 8)):
		var pos = Vector2i(randi_range(0, GRID-1), randi_range(0, 2))
		# Don't spawn on mountains/water/other units
		while terrain[pos.y][pos.x] in ["mountain", "water"] or _unit_at(pos) != null:
			pos = Vector2i(randi_range(0, GRID-1), randi_range(0, 3))
		var etype = etypes[i % etypes.size()]
		var et = ENEMY_TYPES[etype]
		enemies.append({
			"type": etype,
			"pos": pos,
			"hp": et.hp,
			"alive": true,
			"intent": null,
		})

# ================================================================
# ENEMY INTENTS (the key mechanic!)
# ================================================================
func _calculate_enemy_intents() -> void:
	enemy_intents.clear()
	for e in enemies:
		if not e.alive:
			continue
		var et = ENEMY_TYPES[e.type]
		var intent = {"source": e.pos, "targets": [], "type": et.attack_type, "damage": et.damage, "direction": Vector2i.ZERO}

		match et.attack_type:
			"sting":
				# Attack an adjacent tile toward nearest mech/building
				var best_target = _find_nearest_target(e.pos)
				if best_target != Vector2i(-1, -1):
					var dir = _direction_toward(e.pos, best_target)
					var attack_pos = e.pos + dir
					if _in_bounds(attack_pos):
						intent.targets = [attack_pos]
						intent.direction = dir
			"charge":
				# Charge in a line toward nearest mech
				var best = _find_nearest_mech(e.pos)
				if best != Vector2i(-1, -1):
					var dir = _cardinal_direction(e.pos, best)
					intent.direction = dir
					var pos = e.pos + dir
					while _in_bounds(pos):
						intent.targets.append(pos)
						pos += dir
			"ranged":
				# Shoot 3 tiles in direction of nearest mech
				var best = _find_nearest_mech(e.pos)
				if best != Vector2i(-1, -1):
					var dir = _cardinal_direction(e.pos, best)
					intent.direction = dir
					var pos = e.pos + dir
					for j in range(3):
						if _in_bounds(pos):
							intent.targets.append(pos)
						pos += dir
			"emerging":
				# Damages the tile it's standing on
				intent.targets = [e.pos]

		e.intent = intent
		enemy_intents.append(intent)

# ================================================================
# PLAYER INPUT
# ================================================================
func _update_hover() -> void:
	var mouse = get_global_mouse_position()
	var gx = int((mouse.x - BOARD_X) / CELL)
	var gy = int((mouse.y - BOARD_Y) / CELL)
	if gx >= 0 and gx < GRID and gy >= 0 and gy < GRID:
		hover_cell = Vector2i(gx, gy)
	else:
		hover_cell = Vector2i(-1, -1)

func _handle_click() -> void:
	if hover_cell == Vector2i(-1, -1):
		return

	match phase:
		Phase.PLAYER_SELECT:
			# Click on a mech to select it
			for i in range(mechs.size()):
				if mechs[i].pos == hover_cell and mechs[i].alive and not mechs[i].moved:
					selected_mech = i
					_calc_valid_moves(i)
					phase = Phase.PLAYER_MOVE
					return
		Phase.PLAYER_MOVE:
			if hover_cell in valid_moves:
				# Move mech to this cell
				mechs[selected_mech].pos = hover_cell
				mechs[selected_mech].moved = true
				_calc_valid_attacks(selected_mech)
				if valid_attacks.size() > 0:
					phase = Phase.PLAYER_ATTACK
				else:
					_deselect()
			elif hover_cell == mechs[selected_mech].pos:
				# Click on self — skip move, go to attack
				_calc_valid_attacks(selected_mech)
				mechs[selected_mech].moved = true
				if valid_attacks.size() > 0:
					phase = Phase.PLAYER_ATTACK
				else:
					_deselect()
			else:
				_deselect()
		Phase.PLAYER_ATTACK:
			if hover_cell in valid_attacks:
				_execute_mech_attack(selected_mech, hover_cell)
				mechs[selected_mech].attacked = true
				_deselect()
			else:
				# Skip attack
				_deselect()

func _deselect() -> void:
	selected_mech = -1
	valid_moves.clear()
	valid_attacks.clear()
	attack_mode = false
	phase = Phase.PLAYER_SELECT

func _calc_valid_moves(mech_idx: int) -> void:
	valid_moves.clear()
	var m = mechs[mech_idx]
	var mt = MECH_TYPES[m.type]
	var move_range = mt.move

	# BFS for reachable tiles
	var visited = {}
	var queue = [{"pos": m.pos, "dist": 0}]
	visited[m.pos] = true

	while queue.size() > 0:
		var current = queue.pop_front()
		if current.dist <= move_range:
			if current.pos != m.pos and _unit_at(current.pos) == null:
				if terrain[current.pos.y][current.pos.x] not in ["mountain", "water", "chasm"]:
					valid_moves.append(current.pos)
			for dir in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
				var next = current.pos + dir
				if _in_bounds(next) and not visited.has(next):
					if terrain[next.y][next.x] not in ["mountain", "water", "chasm"]:
						visited[next] = true
						queue.append({"pos": next, "dist": current.dist + 1})

func _calc_valid_attacks(mech_idx: int) -> void:
	valid_attacks.clear()
	var m = mechs[mech_idx]
	var mt = MECH_TYPES[m.type]

	match mt.attack_type:
		"punch":
			# Adjacent cells
			for dir in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
				var target = m.pos + dir
				if _in_bounds(target):
					valid_attacks.append(target)
		"artillery":
			# Range 2-4, any cell
			for y in range(GRID):
				for x in range(GRID):
					var dist = absi(x - m.pos.x) + absi(y - m.pos.y)
					if dist >= mt.range_min and dist <= mt.range_max:
						valid_attacks.append(Vector2i(x, y))
		"cannon":
			# Cardinal lines
			for dir in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
				var pos = m.pos + dir
				while _in_bounds(pos):
					valid_attacks.append(pos)
					pos += dir

# ================================================================
# ATTACK EXECUTION
# ================================================================
func _execute_mech_attack(mech_idx: int, target: Vector2i) -> void:
	var m = mechs[mech_idx]
	var mt = MECH_TYPES[m.type]

	match mt.attack_type:
		"punch":
			# Damage target + push it away
			var dir = target - m.pos
			_damage_at(target, mt.damage)
			_push_unit_at(target, dir)
		"artillery":
			# Damage target + push all adjacent units away from impact
			_damage_at(target, mt.damage)
			for adj_dir in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
				var adj = target + adj_dir
				if _in_bounds(adj):
					_push_unit_at(adj, adj_dir)
		"cannon":
			# Find first unit in line and push it
			var dir = _cardinal_direction(m.pos, target)
			var pos = m.pos + dir
			while _in_bounds(pos):
				if _unit_at(pos) != null or (buildings[pos.y][pos.x] > 0):
					_damage_at(pos, mt.damage)
					_push_unit_at(pos, dir)
					break
				if terrain[pos.y][pos.x] == "mountain":
					break
				pos += dir

	_calculate_enemy_intents()

func _damage_at(pos: Vector2i, dmg: int) -> void:
	# Damage enemy at position
	for e in enemies:
		if e.pos == pos and e.alive:
			e.hp -= dmg
			if e.hp <= 0:
				e.alive = false
				message = e.type.capitalize() + " destroyed!"
				message_timer = 2.0
			return
	# Damage mech at position
	for m in mechs:
		if m.pos == pos and m.alive:
			m.hp -= dmg
			if m.hp <= 0:
				m.alive = false
				message = MECH_TYPES[m.type].name + " destroyed!"
				message_timer = 2.0
			return
	# Damage building
	if buildings[pos.y][pos.x] > 0:
		buildings[pos.y][pos.x] = 0
		grid_power -= 1
		message = "Building destroyed! Power: " + str(grid_power)
		message_timer = 2.0
		if grid_power <= 0:
			phase = Phase.GAME_OVER

func _push_unit_at(pos: Vector2i, dir: Vector2i) -> void:
	if dir == Vector2i.ZERO:
		return
	var new_pos = pos + dir
	# Push enemy
	for e in enemies:
		if e.pos == pos and e.alive:
			if _in_bounds(new_pos) and terrain[new_pos.y][new_pos.x] not in ["mountain"]:
				if _unit_at(new_pos) != null:
					# Collision! Damage both
					_damage_at(new_pos, 1)
					e.hp -= 1
					if e.hp <= 0: e.alive = false
				elif terrain[new_pos.y][new_pos.x] == "water" or terrain[new_pos.y][new_pos.x] == "chasm":
					e.alive = false  # killed by water/chasm
					message = e.type.capitalize() + " drowned!"
					message_timer = 2.0
				else:
					e.pos = new_pos
			return
	# Push mech
	for m in mechs:
		if m.pos == pos and m.alive:
			if _in_bounds(new_pos) and terrain[new_pos.y][new_pos.x] not in ["mountain"]:
				if _unit_at(new_pos) == null:
					m.pos = new_pos
			return

# ================================================================
# ENEMY TURN
# ================================================================
func _end_player_turn() -> void:
	# Reset all mech states
	for m in mechs:
		m.moved = false
		m.attacked = false
	selected_mech = -1
	phase = Phase.ENEMY_TURN

func _execute_enemy_turn() -> void:
	# Execute all enemy intents
	for e in enemies:
		if not e.alive or e.intent == null:
			continue
		var intent = e.intent
		var et = ENEMY_TYPES[e.type]

		match et.attack_type:
			"sting":
				for t in intent.targets:
					_damage_at(t, et.damage)
			"charge":
				# Move along the charge line until hitting something
				if intent.direction != Vector2i.ZERO:
					var pos = e.pos + intent.direction
					var moved_to = e.pos
					while _in_bounds(pos):
						if _unit_at(pos) != null or terrain[pos.y][pos.x] == "mountain" or buildings[pos.y][pos.x] > 0:
							_damage_at(pos, et.damage)
							_push_unit_at(pos, intent.direction)
							break
						moved_to = pos
						pos += intent.direction
					e.pos = moved_to
			"ranged":
				for t in intent.targets:
					if _unit_at(t) != null or buildings[t.y][t.x] > 0:
						_damage_at(t, et.damage)
						break
			"emerging":
				for t in intent.targets:
					_damage_at(t, et.damage)

	# Check victory
	var enemies_alive = 0
	for e in enemies:
		if e.alive: enemies_alive += 1

	if enemies_alive == 0:
		turn += 1
		if turn > 5:
			phase = Phase.VICTORY
			message = "VICTORY!"
			message_timer = 99.0
		else:
			_spawn_enemies()
			_calculate_enemy_intents()
			phase = Phase.PLAYER_SELECT
			message = "Turn " + str(turn) + " — New Vek incoming!"
			message_timer = 3.0
	else:
		_calculate_enemy_intents()
		phase = Phase.PLAYER_SELECT
		message = "Turn " + str(turn) + " — Your move!"
		message_timer = 2.0

# ================================================================
# HELPERS
# ================================================================
func _in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < GRID and pos.y >= 0 and pos.y < GRID

func _unit_at(pos: Vector2i):
	for m in mechs:
		if m.pos == pos and m.alive: return m
	for e in enemies:
		if e.pos == pos and e.alive: return e
	return null

func _find_nearest_mech(from: Vector2i) -> Vector2i:
	var best = Vector2i(-1, -1)
	var best_dist = 999
	for m in mechs:
		if not m.alive: continue
		var d = absi(m.pos.x - from.x) + absi(m.pos.y - from.y)
		if d < best_dist:
			best_dist = d
			best = m.pos
	return best

func _find_nearest_target(from: Vector2i) -> Vector2i:
	# Nearest mech or building
	var best = _find_nearest_mech(from)
	var best_dist = 999
	if best != Vector2i(-1, -1):
		best_dist = absi(best.x - from.x) + absi(best.y - from.y)
	for y in range(GRID):
		for x in range(GRID):
			if buildings[y][x] > 0:
				var d = absi(x - from.x) + absi(y - from.y)
				if d < best_dist:
					best_dist = d
					best = Vector2i(x, y)
	return best

func _direction_toward(from: Vector2i, to: Vector2i) -> Vector2i:
	var dx = to.x - from.x
	var dy = to.y - from.y
	if absi(dx) >= absi(dy):
		return Vector2i(signi(dx), 0)
	else:
		return Vector2i(0, signi(dy))

func _cardinal_direction(from: Vector2i, to: Vector2i) -> Vector2i:
	return _direction_toward(from, to)

# ================================================================
# DRAWING
# ================================================================
func _draw() -> void:
	match phase:
		Phase.TITLE:
			_draw_title()
		Phase.GAME_OVER:
			_draw_game()
			_draw_overlay("GRID POWER LOST", "The Vek have won.", Color(0.8, 0.2, 0.2))
		Phase.VICTORY:
			_draw_game()
			_draw_overlay("VICTORY!", "All Vek eliminated.", Color(0.2, 0.8, 0.3))
		_:
			_draw_game()

func _draw_title() -> void:
	# Dark atmospheric background
	draw_rect(Rect2(0, 0, 800, 600), Color(0.03, 0.04, 0.08))
	# Animated star field with parallax
	for i in range(100):
		var layer = i % 3
		var speed = [1.0, 2.0, 4.0][layer]
		var brightness = [0.2, 0.4, 0.7][layer]
		var sz = [1, 1, 2][layer]
		var sx = fmod(i * 137.5 + title_timer * speed, 800.0)
		var sy = fmod(i * 91.3 + i * 47.7, 600.0)
		var twinkle = 0.5 + sin(title_timer * 3 + i) * 0.5
		draw_rect(Rect2(sx, sy, sz, sz), Color(0.6, 0.7, 1.0, brightness * twinkle))
	# Ground silhouette
	for x in range(0, 800, 4):
		var ground_y = 420 + sin(x * 0.01) * 20 + sin(x * 0.03) * 10
		draw_rect(Rect2(x, ground_y, 4, 600 - ground_y), Color(0.05, 0.06, 0.04))
	# City silhouette in background
	for i in range(15):
		var bx = i * 55 + 20
		var bh = 60 + (i * 37) % 80
		var by = 420 - bh + sin(i * 1.3) * 15
		draw_rect(Rect2(bx, by, 35, bh), Color(0.06, 0.07, 0.05))
		# Lit windows
		for wy in range(0, int(bh) - 10, 12):
			for wx in [6, 16, 26]:
				if (i + wy + wx) % 4 != 0:
					draw_rect(Rect2(bx + wx, by + wy + 5, 4, 5), Color(0.7, 0.6, 0.3, 0.4 + sin(title_timer + i + wy) * 0.2))
	# Mech silhouettes
	for mx in [250, 400, 530]:
		var my = 380
		var mh = 60 + (mx % 20)
		draw_rect(Rect2(mx - 12, my - mh, 24, mh), Color(0.08, 0.10, 0.06))
		draw_rect(Rect2(mx - 16, my - mh - 8, 32, 12), Color(0.08, 0.10, 0.06))
		draw_rect(Rect2(mx - 8, my, 6, 15), Color(0.06, 0.08, 0.04))
		draw_rect(Rect2(mx + 2, my, 6, 15), Color(0.06, 0.08, 0.04))
	# Title with glow
	var glow = 0.5 + sin(title_timer * 2) * 0.15
	_text(218, 198, "INTO THE BREECH 2", 28, Color(0.2, 0.4, 0.6, 0.3))
	_text(220, 200, "INTO THE BREECH 2", 28, Color(0.7 * glow + 0.3, 0.85 * glow + 0.15, 1.0 * glow))
	_text(280, 240, "Tactical Mech Combat", 14, Color(0.5, 0.6, 0.7))
	_text(270, 270, "Defend the city. Push back the Vek.", 10, Color(0.4, 0.45, 0.55))
	# Animated button
	if fmod(title_timer, 1.0) < 0.65:
		draw_rect(Rect2(295, 385, 210, 35), Color(0.15, 0.25, 0.12, 0.8))
		draw_rect(Rect2(295, 385, 210, 35), Color(0.3, 0.6, 0.3, 0.6), false, 2)
		_text(335, 408, "CLICK TO START", 14, Color(0.7, 1.0, 0.7))

func _draw_game() -> void:
	# Gradient sky background
	for sy in range(0, 600, 4):
		var t = float(sy) / 600.0
		var sky = Color(0.06 + t * 0.04, 0.07 + t * 0.03, 0.14 - t * 0.06)
		draw_rect(Rect2(0, sy, 800, 4), sky)

	# Distant mountains
	for i in range(12):
		var mx = i * 70 - 20
		var mh = 30 + sin(i * 1.7) * 15
		var pts = PackedVector2Array([Vector2(mx, BOARD_Y), Vector2(mx + 35, BOARD_Y - mh), Vector2(mx + 70, BOARD_Y)])
		draw_colored_polygon(pts, Color(0.08, 0.09, 0.12))

	# Draw grid with depth effect (tiles have 3D look)
	for y in range(GRID):
		for x in range(GRID):
			var px = BOARD_X + x * CELL
			var py = BOARD_Y + y * CELL
			var t = terrain[y][x]

			# Tile base colors with variation per cell
			var noise = sin(x * 3.7 + y * 5.3) * 0.03
			var base = Color(0.22 + noise, 0.26 + noise, 0.18 + noise)
			var light = base * 1.15
			var dark = base * 0.75
			var edge = base * 0.55

			match t:
				"mountain":
					base = Color(0.38 + noise, 0.32 + noise, 0.28 + noise)
					light = base * 1.15; dark = base * 0.7; edge = base * 0.5
				"water":
					var wave = sin(x * 0.8 + y * 0.5 + title_timer * 2) * 0.03
					base = Color(0.15 + wave, 0.25 + wave, 0.42 + wave)
					light = base * 1.2; dark = base * 0.8; edge = base * 0.6
				"forest":
					base = Color(0.15 + noise, 0.28 + noise, 0.14 + noise)
					light = base * 1.2; dark = base * 0.7; edge = base * 0.5
				"chasm":
					base = Color(0.04, 0.04, 0.06); light = base; dark = base; edge = base

			# 3D tile: top face
			draw_rect(Rect2(px + 1, py + 1, CELL - 2, CELL - 2), base)
			# Top highlight edge
			draw_rect(Rect2(px + 1, py + 1, CELL - 2, 2), light)
			draw_rect(Rect2(px + 1, py + 1, 2, CELL - 2), light * 0.9)
			# Bottom shadow edge
			draw_rect(Rect2(px + 1, py + CELL - 3, CELL - 2, 2), dark)
			draw_rect(Rect2(px + CELL - 3, py + 1, 2, CELL - 2), dark * 0.9)
			# Inner texture — subtle noise pattern
			for tx2 in range(0, CELL, 8):
				for ty2 in range(0, CELL, 8):
					if (tx2 + ty2 + x * 3 + y * 7) % 16 < 3:
						draw_rect(Rect2(px + tx2 + 2, py + ty2 + 2, 3, 3), dark * 0.95)

			# Detailed terrain features
			if t == "mountain":
				# Layered mountain with snow cap
				var mpts1 = PackedVector2Array([
					Vector2(px + 10, py + 58), Vector2(px + 32, py + 8),
					Vector2(px + 54, py + 58)])
				draw_colored_polygon(mpts1, Color(0.48, 0.40, 0.36))
				var mpts2 = PackedVector2Array([
					Vector2(px + 14, py + 52), Vector2(px + 32, py + 14),
					Vector2(px + 50, py + 52)])
				draw_colored_polygon(mpts2, Color(0.52, 0.44, 0.40))
				# Snow
				var snow = PackedVector2Array([
					Vector2(px + 25, py + 20), Vector2(px + 32, py + 8),
					Vector2(px + 39, py + 20)])
				draw_colored_polygon(snow, Color(0.85, 0.88, 0.95))
				# Rock detail
				draw_line(Vector2(px + 20, py + 40), Vector2(px + 28, py + 25), Color(0.35, 0.28, 0.25), 1)
				draw_line(Vector2(px + 36, py + 45), Vector2(px + 40, py + 30), Color(0.35, 0.28, 0.25), 1)

			elif t == "water":
				# Animated water with reflections
				for w in range(5):
					var wave_x = sin(title_timer * 1.5 + w * 1.2 + x) * 6
					var wy = py + 10 + w * 10
					draw_line(Vector2(px + 6 + wave_x, wy), Vector2(px + 58 + wave_x, wy),
						Color(0.25, 0.40, 0.65, 0.35 - w * 0.05), 1)
				# Shimmer
				var shimmer_x = px + 20 + sin(title_timer * 3 + x + y) * 10
				draw_rect(Rect2(shimmer_x, py + 15, 3, 2), Color(0.5, 0.7, 0.9, 0.3))

			elif t == "forest":
				# Detailed trees with trunks and layered canopy
				for tree_data in [[14, 0.0], [40, 0.5], [28, 0.25]]:
					var tree_x = tree_data[0]
					var tree_phase = tree_data[1]
					# Trunk
					draw_rect(Rect2(px + tree_x - 2, py + 30, 5, 22), Color(0.30, 0.18, 0.10))
					draw_rect(Rect2(px + tree_x - 1, py + 30, 3, 22), Color(0.38, 0.24, 0.14))
					# Canopy layers (back to front)
					draw_circle(Vector2(px + tree_x, py + 28), 11, Color(0.12, 0.28, 0.10))
					draw_circle(Vector2(px + tree_x + 2, py + 24), 10, Color(0.16, 0.35, 0.13))
					draw_circle(Vector2(px + tree_x - 1, py + 20), 9, Color(0.20, 0.42, 0.16))
					# Highlight on top
					draw_circle(Vector2(px + tree_x, py + 18), 5, Color(0.28, 0.50, 0.22))

			# Building — detailed with floors, windows, roof
			if buildings[y][x] > 0:
				# Building shadow
				draw_rect(Rect2(px + 16, py + 56, 38, 4), Color(0, 0, 0, 0.2))
				# Main structure
				draw_rect(Rect2(px + 10, py + 6, 44, 52), Color(0.45, 0.48, 0.52))
				draw_rect(Rect2(px + 12, py + 8, 40, 48), Color(0.55, 0.58, 0.62))
				# Left wall shading
				draw_rect(Rect2(px + 10, py + 6, 3, 52), Color(0.40, 0.43, 0.47))
				# Floor lines
				for fl in [20, 34, 48]:
					draw_rect(Rect2(px + 12, py + fl, 40, 1), Color(0.42, 0.45, 0.48))
				# Windows with glow
				for wy in [12, 24, 38]:
					for wx in [16, 28, 40]:
						draw_rect(Rect2(px + wx, py + wy, 7, 8), Color(0.15, 0.18, 0.22))
						var lit = ((x + y + wx + wy) % 3) != 0
						if lit:
							var glow = 0.6 + sin(title_timer * 0.5 + x + wy) * 0.15
							draw_rect(Rect2(px + wx + 1, py + wy + 1, 5, 6), Color(0.85 * glow, 0.78 * glow, 0.45 * glow))
				# Roof
				var roof = PackedVector2Array([
					Vector2(px + 6, py + 6), Vector2(px + 32, py - 2),
					Vector2(px + 58, py + 6)])
				draw_colored_polygon(roof, Color(0.35, 0.30, 0.28))
				draw_colored_polygon(PackedVector2Array([
					Vector2(px + 8, py + 6), Vector2(px + 32, py),
					Vector2(px + 56, py + 6)]), Color(0.40, 0.35, 0.32))
				# Antenna
				draw_line(Vector2(px + 45, py + 2), Vector2(px + 45, py - 8), Color(0.5, 0.5, 0.55), 1)
				draw_rect(Rect2(px + 43, py - 10, 4, 3), Color(0.8, 0.2, 0.1))

			# Draw terrain texture overlay
			var _ttex: Texture2D = null
			match t:
				"ground": _ttex = tex_ground
				"mountain": _ttex = tex_mountain
				"water": _ttex = tex_water
				"forest": _ttex = tex_forest
			if _ttex != null:
				draw_texture(_ttex, Vector2(px, py))
			# Building texture
			if buildings[y][x] > 0 and tex_building != null:
				draw_texture(tex_building, Vector2(px, py))
			# Subtle grid lines
			draw_rect(Rect2(px, py, CELL, CELL), Color(0.20, 0.24, 0.16, 0.4), false, 1)

	# Highlight valid moves
	for vm in valid_moves:
		var px = BOARD_X + vm.x * CELL
		var py = BOARD_Y + vm.y * CELL
		draw_rect(Rect2(px + 2, py + 2, CELL - 4, CELL - 4), Color(0.2, 0.5, 0.9, 0.25))
		draw_rect(Rect2(px + 2, py + 2, CELL - 4, CELL - 4), Color(0.3, 0.6, 1.0, 0.5), false, 2)

	# Highlight valid attacks
	for va in valid_attacks:
		var px = BOARD_X + va.x * CELL
		var py = BOARD_Y + va.y * CELL
		draw_rect(Rect2(px + 2, py + 2, CELL - 4, CELL - 4), Color(0.9, 0.3, 0.1, 0.2))
		draw_rect(Rect2(px + 2, py + 2, CELL - 4, CELL - 4), Color(1.0, 0.4, 0.2, 0.5), false, 2)

	# Draw enemy intents (THE KEY VISUAL — shows what enemies will do)
	for intent in enemy_intents:
		for t in intent.targets:
			var px = BOARD_X + t.x * CELL
			var py = BOARD_Y + t.y * CELL
			# Red warning overlay
			draw_rect(Rect2(px + 4, py + 4, CELL - 8, CELL - 8), Color(1.0, 0.15, 0.05, 0.2))
			# Arrow showing attack direction
			if intent.direction != Vector2i.ZERO:
				var cx = px + CELL / 2
				var cy = py + CELL / 2
				var ax = cx + intent.direction.x * 16
				var ay = cy + intent.direction.y * 16
				draw_line(Vector2(cx, cy), Vector2(ax, ay), Color(1, 0.3, 0.1, 0.6), 2)
			# Warning icon
			_text(px + CELL/2 - 4, py + CELL/2 + 4, "!", 12, Color(1, 0.3, 0.1, 0.7))

	# Draw enemies (sorted by Y for depth)
	var sorted_enemies = enemies.filter(func(e): return e.alive)
	sorted_enemies.sort_custom(func(a, b): return a.pos.y < b.pos.y)
	for e in sorted_enemies:
		var et = ENEMY_TYPES[e.type]
		var px = BOARD_X + e.pos.x * CELL + CELL / 2
		var py = BOARD_Y + e.pos.y * CELL + CELL / 2
		var bob = sin(title_timer * 3 + e.pos.x * 2) * 2

		# Ground shadow (ellipse)
		for sr in range(3):
			draw_circle(Vector2(px, py + 22 - sr), 14 - sr * 2, Color(0, 0, 0, 0.08))

		match e.type:
			"hornet":
				# Wings (animated flapping)
				var wing = sin(title_timer * 12 + e.pos.x) * 6
				draw_line(Vector2(px - 8, py - 6 + bob), Vector2(px - 18, py - 16 + wing + bob), Color(0.9, 0.8, 0.4, 0.5), 2)
				draw_line(Vector2(px + 8, py - 6 + bob), Vector2(px + 18, py - 16 - wing + bob), Color(0.9, 0.8, 0.4, 0.5), 2)
				# Body segments
				draw_circle(Vector2(px, py + 4 + bob), 8, Color(0.6, 0.5, 0.1))
				draw_circle(Vector2(px, py - 2 + bob), 7, Color(0.8, 0.7, 0.15))
				draw_circle(Vector2(px, py - 8 + bob), 6, Color(0.75, 0.65, 0.12))
				# Stripes
				draw_rect(Rect2(px - 5, py + 1 + bob, 10, 2), Color(0.2, 0.15, 0.05))
				draw_rect(Rect2(px - 4, py - 5 + bob, 8, 2), Color(0.2, 0.15, 0.05))
				# Stinger
				draw_line(Vector2(px, py + 12 + bob), Vector2(px, py + 18 + bob), Color(0.3, 0.2, 0.05), 2)
				# Eyes
				draw_rect(Rect2(px - 4, py - 10 + bob, 3, 3), Color(1, 0.3, 0.1))
				draw_rect(Rect2(px + 1, py - 10 + bob, 3, 3), Color(1, 0.3, 0.1))
			"beetle":
				# Heavy armored body
				draw_rect(Rect2(px - 14, py - 4 + bob, 28, 18), Color(0.4, 0.2, 0.08))
				draw_rect(Rect2(px - 12, py - 6 + bob, 24, 16), Color(0.55, 0.28, 0.12))
				draw_rect(Rect2(px - 10, py - 8 + bob, 20, 6), Color(0.6, 0.32, 0.15))
				# Shell line
				draw_line(Vector2(px, py - 8 + bob), Vector2(px, py + 12 + bob), Color(0.35, 0.18, 0.06), 1)
				# Mandibles
				draw_line(Vector2(px - 6, py - 8 + bob), Vector2(px - 10, py - 14 + bob), Color(0.45, 0.25, 0.1), 2)
				draw_line(Vector2(px + 6, py - 8 + bob), Vector2(px + 10, py - 14 + bob), Color(0.45, 0.25, 0.1), 2)
				# Legs
				for lx in [-12, -8, 8, 12]:
					draw_line(Vector2(px + lx, py + 8 + bob), Vector2(px + lx + (3 if lx > 0 else -3), py + 18), Color(0.35, 0.18, 0.08), 2)
				# Eyes
				draw_rect(Rect2(px - 5, py - 7 + bob, 3, 3), Color(1, 0.15, 0.0))
				draw_rect(Rect2(px + 2, py - 7 + bob, 3, 3), Color(1, 0.15, 0.0))
			"scorpion":
				# Body
				draw_circle(Vector2(px, py + 2 + bob), 10, Color(0.4, 0.15, 0.12))
				draw_circle(Vector2(px, py - 2 + bob), 9, Color(0.5, 0.2, 0.15))
				# Tail curving up
				draw_line(Vector2(px, py + 10 + bob), Vector2(px + 4, py + 4 + bob), Color(0.45, 0.18, 0.12), 3)
				draw_line(Vector2(px + 4, py + 4 + bob), Vector2(px + 8, py - 6 + bob), Color(0.45, 0.18, 0.12), 3)
				draw_line(Vector2(px + 8, py - 6 + bob), Vector2(px + 6, py - 12 + bob), Color(0.45, 0.18, 0.12), 2)
				# Stinger
				draw_circle(Vector2(px + 6, py - 13 + bob), 3, Color(0.7, 0.2, 0.1))
				# Claws
				draw_line(Vector2(px - 6, py - 4 + bob), Vector2(px - 14, py - 10 + bob), Color(0.45, 0.18, 0.12), 2)
				draw_line(Vector2(px + 6, py - 4 + bob), Vector2(px + 14, py - 10 + bob), Color(0.45, 0.18, 0.12), 2)
				# Eyes
				draw_rect(Rect2(px - 4, py - 5 + bob, 2, 2), Color(1, 0.2, 0.1))
				draw_rect(Rect2(px + 2, py - 5 + bob, 2, 2), Color(1, 0.2, 0.1))
			"firefly":
				# Glowing body
				var glow = 0.6 + sin(title_timer * 4 + e.pos.x * 3) * 0.3
				draw_circle(Vector2(px, py + bob), 12, Color(0.7 * glow, 0.5 * glow, 0.1 * glow, 0.3))
				draw_circle(Vector2(px, py - 2 + bob), 8, Color(0.5, 0.35, 0.08))
				draw_circle(Vector2(px, py - 2 + bob), 6, Color(0.7, 0.5, 0.12))
				# Light abdomen
				draw_circle(Vector2(px, py + 6 + bob), 6, Color(0.9 * glow, 0.7 * glow, 0.1, 0.7))
				# Wings
				var wing2 = sin(title_timer * 10 + e.pos.y) * 4
				draw_line(Vector2(px - 4, py - 4 + bob), Vector2(px - 12, py - 12 + wing2 + bob), Color(0.6, 0.5, 0.3, 0.4), 1)
				draw_line(Vector2(px + 4, py - 4 + bob), Vector2(px + 12, py - 12 - wing2 + bob), Color(0.6, 0.5, 0.3, 0.4), 1)
				# Eyes
				draw_rect(Rect2(px - 3, py - 5 + bob, 2, 2), Color(1, 0.6, 0.1))
				draw_rect(Rect2(px + 1, py - 5 + bob, 2, 2), Color(1, 0.6, 0.1))

		# HP pips with background
		var hp_total = et.hp
		draw_rect(Rect2(px - hp_total * 4, py + 20, hp_total * 8, 5), Color(0, 0, 0, 0.4))
		for h in range(hp_total):
			var filled = h < e.hp
			draw_rect(Rect2(px - hp_total * 4 + 1 + h * 8, py + 21, 6, 3),
				Color(0.9, 0.15, 0.05) if filled else Color(0.25, 0.1, 0.08))

	# Draw mechs (sorted by Y)
	var sorted_mechs = []
	for i in range(mechs.size()):
		if mechs[i].alive:
			sorted_mechs.append(i)
	sorted_mechs.sort_custom(func(a, b): return mechs[a].pos.y < mechs[b].pos.y)

	for i in sorted_mechs:
		var m = mechs[i]
		var mt = MECH_TYPES[m.type]
		var px = BOARD_X + m.pos.x * CELL + CELL / 2
		var py = BOARD_Y + m.pos.y * CELL + CELL / 2

		var sel = i == selected_mech
		var dimmed = m.moved and not sel and phase == Phase.PLAYER_SELECT
		var mc = mt.color if not dimmed else mt.color * 0.45
		var mc_lt = mc * 1.25
		var mc_dk = mc * 0.6
		var mc_edge = mc * 0.4

		# Selection glow ring
		if sel:
			for sr in range(3):
				draw_circle(Vector2(px, py + 16), 22 - sr * 2, Color(0.3, 0.7, 1.0, 0.1 + sr * 0.05))
			draw_circle(Vector2(px, py + 16), 18, Color(0.3, 0.7, 1.0, 0.15))

		# Ground shadow
		for sr in range(3):
			draw_circle(Vector2(px, py + 24 - sr), 16 - sr * 3, Color(0, 0, 0, 0.06))

		# === DETAILED MECH DRAWING ===
		match m.type:
			"artillery":
				# Legs — thick armored legs
				draw_rect(Rect2(px - 11, py + 10, 7, 14), mc_dk)
				draw_rect(Rect2(px - 10, py + 10, 5, 14), mc * 0.7)
				draw_rect(Rect2(px + 4, py + 10, 7, 14), mc_dk)
				draw_rect(Rect2(px + 5, py + 10, 5, 14), mc * 0.7)
				# Feet
				draw_rect(Rect2(px - 13, py + 22, 10, 4), mc_dk)
				draw_rect(Rect2(px + 3, py + 22, 10, 4), mc_dk)
				# Torso — wide and heavy
				draw_rect(Rect2(px - 14, py - 6, 28, 18), mc_dk)
				draw_rect(Rect2(px - 12, py - 4, 24, 14), mc)
				draw_rect(Rect2(px - 10, py - 2, 20, 10), mc_lt)
				# Armor plates
				draw_rect(Rect2(px - 14, py - 6, 28, 2), mc_lt)
				draw_rect(Rect2(px - 14, py + 10, 28, 2), mc_edge)
				# Cockpit
				draw_rect(Rect2(px - 5, py - 10, 10, 8), Color(0.15, 0.2, 0.25))
				draw_rect(Rect2(px - 4, py - 9, 8, 5), Color(0.2, 0.6, 0.8, 0.8 if not dimmed else 0.3))
				draw_rect(Rect2(px - 3, py - 8, 4, 3), Color(0.4, 0.85, 1.0, 0.6 if not dimmed else 0.2))
				# Artillery cannon (long barrel on top)
				draw_rect(Rect2(px - 3, py - 24, 6, 16), mc * 0.7)
				draw_rect(Rect2(px - 2, py - 22, 4, 14), mc * 0.8)
				draw_rect(Rect2(px - 5, py - 26, 10, 4), mc_lt)
				# Muzzle
				draw_rect(Rect2(px - 3, py - 28, 6, 3), mc_edge)
				# Shoulder plates
				draw_rect(Rect2(px - 16, py - 4, 5, 10), mc * 0.75)
				draw_rect(Rect2(px + 11, py - 4, 5, 10), mc * 0.75)

			"combat":
				# Legs — sturdy, wide stance
				draw_rect(Rect2(px - 12, py + 8, 8, 16), mc_dk)
				draw_rect(Rect2(px - 11, py + 8, 6, 16), mc * 0.65)
				draw_rect(Rect2(px + 4, py + 8, 8, 16), mc_dk)
				draw_rect(Rect2(px + 5, py + 8, 6, 16), mc * 0.65)
				# Knee guards
				draw_rect(Rect2(px - 13, py + 14, 10, 4), mc_lt)
				draw_rect(Rect2(px + 3, py + 14, 10, 4), mc_lt)
				# Feet
				draw_rect(Rect2(px - 14, py + 22, 11, 4), mc_dk)
				draw_rect(Rect2(px + 3, py + 22, 11, 4), mc_dk)
				# Torso — compact, armored
				draw_rect(Rect2(px - 12, py - 8, 24, 18), mc_dk)
				draw_rect(Rect2(px - 10, py - 6, 20, 14), mc)
				draw_rect(Rect2(px - 8, py - 4, 16, 10), mc_lt)
				# Chest detail
				draw_rect(Rect2(px - 2, py - 4, 4, 4), Color(0.8, 0.4, 0.1))
				# Cockpit
				draw_rect(Rect2(px - 5, py - 14, 10, 8), Color(0.15, 0.18, 0.22))
				draw_rect(Rect2(px - 4, py - 13, 8, 5), Color(0.2, 0.65, 0.85, 0.8 if not dimmed else 0.3))
				# Fist weapon (right arm extended)
				draw_rect(Rect2(px + 10, py - 6, 8, 6), mc * 0.8)
				draw_rect(Rect2(px + 16, py - 8, 8, 10), mc)
				draw_rect(Rect2(px + 18, py - 6, 6, 6), mc_lt)
				# Left arm
				draw_rect(Rect2(px - 18, py - 4, 6, 8), mc * 0.7)
				# Shoulder armor
				draw_rect(Rect2(px - 14, py - 8, 6, 6), mc_lt)
				draw_rect(Rect2(px + 8, py - 8, 6, 6), mc_lt)

			"cannon":
				# Legs — lighter build
				draw_rect(Rect2(px - 8, py + 10, 6, 14), mc_dk)
				draw_rect(Rect2(px - 7, py + 10, 4, 14), mc * 0.65)
				draw_rect(Rect2(px + 2, py + 10, 6, 14), mc_dk)
				draw_rect(Rect2(px + 3, py + 10, 4, 14), mc * 0.65)
				# Feet
				draw_rect(Rect2(px - 10, py + 22, 8, 4), mc_dk)
				draw_rect(Rect2(px + 2, py + 22, 8, 4), mc_dk)
				# Torso
				draw_rect(Rect2(px - 10, py - 4, 20, 16), mc_dk)
				draw_rect(Rect2(px - 8, py - 2, 16, 12), mc)
				# Cockpit
				draw_rect(Rect2(px - 4, py - 10, 8, 8), Color(0.15, 0.2, 0.22))
				draw_rect(Rect2(px - 3, py - 9, 6, 5), Color(0.2, 0.7, 0.5, 0.8 if not dimmed else 0.3))
				# Long cannon barrel (right side)
				draw_rect(Rect2(px + 6, py - 4, 18, 4), mc * 0.6)
				draw_rect(Rect2(px + 8, py - 3, 16, 2), mc * 0.8)
				draw_rect(Rect2(px + 22, py - 6, 6, 8), mc)
				draw_rect(Rect2(px + 24, py - 4, 4, 4), mc_lt)
				# Stabilizers
				draw_rect(Rect2(px - 12, py, 4, 8), mc * 0.6)
				draw_rect(Rect2(px - 12, py - 2, 4, 3), mc_lt)

		# HP bar with border
		var hp_w = 28
		draw_rect(Rect2(px - hp_w/2 - 1, py - 18, hp_w + 2, 5), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(px - hp_w/2, py - 17, hp_w, 3), Color(0.15, 0.15, 0.18))
		var hp_frac = float(m.hp) / float(m.max_hp)
		var hp_color = Color(0.2, 0.8, 0.3) if hp_frac > 0.5 else Color(0.9, 0.7, 0.1) if hp_frac > 0.25 else Color(0.9, 0.2, 0.1)
		draw_rect(Rect2(px - hp_w/2, py - 17, hp_w * hp_frac, 3), hp_color)

	# Hover highlight
	if hover_cell != Vector2i(-1, -1):
		var hx = BOARD_X + hover_cell.x * CELL
		var hy = BOARD_Y + hover_cell.y * CELL
		draw_rect(Rect2(hx, hy, CELL, CELL), Color(1, 1, 1, 0.08))
		draw_rect(Rect2(hx, hy, CELL, CELL), Color(1, 1, 1, 0.2), false, 1)

	# HUD
	_draw_hud()

func _draw_hud() -> void:
	# Top bar
	draw_rect(Rect2(0, 0, 800, 32), Color(0.05, 0.06, 0.1, 0.9))

	# Grid Power
	_text(10, 22, "GRID POWER:", 10, Color(0.6, 0.7, 0.8))
	for i in range(max_power):
		var color = Color(0.3, 0.7, 1.0) if i < grid_power else Color(0.2, 0.2, 0.25)
		draw_rect(Rect2(110 + i * 14, 10, 10, 12), color)

	# Turn
	_text(300, 22, "TURN " + str(turn) + "/5", 10, Color(0.7, 0.8, 0.7))

	# Phase
	var phase_text = ""
	match phase:
		Phase.PLAYER_SELECT: phase_text = "SELECT MECH"
		Phase.PLAYER_MOVE: phase_text = "MOVE MECH"
		Phase.PLAYER_ATTACK: phase_text = "CHOOSE TARGET"
		Phase.ENEMY_TURN: phase_text = "ENEMY TURN"
	_text(450, 22, phase_text, 10, Color(0.9, 0.8, 0.3))

	# End turn button
	draw_rect(Rect2(640, 4, 80, 24), Color(0.2, 0.3, 0.15))
	draw_rect(Rect2(640, 4, 80, 24), Color(0.4, 0.6, 0.3), false, 1)
	_text(648, 20, "END TURN (E)", 8, Color(0.7, 0.9, 0.6))

	# Right panel — mech info
	draw_rect(Rect2(BOARD_X + GRID * CELL + 10, BOARD_Y, 180, GRID * CELL), Color(0.06, 0.07, 0.12, 0.8))

	var panel_x = BOARD_X + GRID * CELL + 20
	_text(panel_x, BOARD_Y + 20, "YOUR MECHS", 10, Color(0.6, 0.7, 0.8))

	for i in range(mechs.size()):
		var m = mechs[i]
		var mt = MECH_TYPES[m.type]
		var yy = BOARD_Y + 40 + i * 80
		var alive_text = "" if m.alive else " [DEAD]"
		draw_rect(Rect2(panel_x - 4, yy - 10, 160, 70), Color(mt.color.r * 0.15, mt.color.g * 0.15, mt.color.b * 0.15))
		_text(panel_x, yy + 4, mt.name + alive_text, 8, mt.color if m.alive else Color(0.4, 0.4, 0.4))
		_text(panel_x, yy + 18, "HP: " + str(m.hp) + "/" + str(m.max_hp), 7, Color(0.7, 0.8, 0.7))
		_text(panel_x, yy + 30, "Move: " + str(mt.move), 7, Color(0.6, 0.7, 0.8))
		_text(panel_x, yy + 42, "Dmg: " + str(mt.damage), 7, Color(0.8, 0.6, 0.5))
		_text(panel_x, yy + 54, mt.desc, 6, Color(0.5, 0.5, 0.6))

	# Hover info
	if hover_cell != Vector2i(-1, -1):
		var yy = BOARD_Y + 300
		var hx = hover_cell.x
		var hy = hover_cell.y
		_text(panel_x, yy, "TILE " + str(hx) + "," + str(hy), 8, Color(0.6, 0.6, 0.7))
		_text(panel_x, yy + 14, terrain[hy][hx].to_upper(), 7, Color(0.5, 0.6, 0.5))
		var unit = _unit_at(hover_cell)
		if unit != null:
			var unit_name = ""
			if unit.has("type"):
				if MECH_TYPES.has(unit.type):
					unit_name = MECH_TYPES[unit.type].name
				elif ENEMY_TYPES.has(unit.type):
					unit_name = ENEMY_TYPES[unit.type].name
			_text(panel_x, yy + 28, unit_name, 8, Color(0.8, 0.7, 0.5))
			_text(panel_x, yy + 42, "HP: " + str(unit.hp), 7, Color(0.7, 0.8, 0.7))

	# Message
	if message_timer > 0:
		var alpha = minf(message_timer, 1.0)
		draw_rect(Rect2(200, 560, 400, 30), Color(0, 0, 0, 0.6 * alpha))
		_text(220, 580, message, 12, Color(1, 1, 1, alpha))

func _draw_overlay(title: String, subtitle: String, color: Color) -> void:
	draw_rect(Rect2(0, 0, 800, 600), Color(0, 0, 0, 0.6))
	_text(260, 260, title, 28, color)
	_text(290, 300, subtitle, 14, Color(0.7, 0.7, 0.8))
	if fmod(title_timer, 1.0) < 0.6:
		_text(310, 400, "CLICK TO RESTART", 12, Color.WHITE)

func _text(x: float, y: float, text: String, size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
