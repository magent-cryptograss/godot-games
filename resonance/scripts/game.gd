extends Node2D

# ================================================================
# RESONANCE — A Music Puzzle Game
# Place notes on a grid to create harmonies that match the target.
# Notes interact: consonant intervals glow, dissonant ones clash.
# Match the target pattern to complete each level.
# ================================================================

const SW = 800
const SH = 600

# Grid: 8 columns (time steps) x 7 rows (notes: C D E F G A B)
const COLS = 8
const ROWS = 7
const CELL_W = 70
const CELL_H = 55
const GRID_X = 100
const GRID_Y = 120

enum State { TITLE, PLAYING, PLAYING_BACK, LEVEL_COMPLETE, GAME_COMPLETE }

var state = State.TITLE
var timer = 0.0
var level = 0
var max_levels = 8

# Note names and frequencies
const NOTE_NAMES = ["C", "D", "E", "F", "G", "A", "B"]
const NOTE_FREQS = [261.63, 293.66, 329.63, 349.23, 392.00, 440.00, 493.88]
const NOTE_COLORS = [
	Color(0.9, 0.3, 0.3),   # C - red
	Color(0.9, 0.6, 0.2),   # D - orange
	Color(0.9, 0.9, 0.2),   # E - yellow
	Color(0.3, 0.8, 0.3),   # F - green
	Color(0.3, 0.6, 0.9),   # G - blue
	Color(0.5, 0.3, 0.9),   # A - indigo
	Color(0.8, 0.3, 0.8),   # B - violet
]

# Player's placed notes: 2D array [col][row] = true/false
var grid = []
# Target pattern to match
var target = []
# Current playback state
var play_col = -1
var play_timer = 0.0
var play_speed = 0.4  # seconds per column
# Selected note for palette
var selected_note = -1
# Harmony score per column
var harmony_scores = []
# Particle effects
var particles = []
# Audio context
var audio_ctx_ready = false

# Consonant intervals (in semitones) — these sound good together
# Unison=0, m3=3, M3=4, P4=5, P5=7, m6=8, M6=9, Octave=12
const CONSONANT_INTERVALS = [0, 3, 4, 5, 7]

# Level definitions: each is a target pattern
var LEVELS = []

func _ready() -> void:
	_generate_levels()
	_init_grid()

func _generate_levels() -> void:
	LEVELS.clear()
	# Level 1: Simple — just two notes
	LEVELS.append({"name": "First Steps", "desc": "Place two notes to create a harmony",
		"target": [[0,4], [2,4], [4,2], [6,2]],
		"hint": "Click grid cells to place notes. Match the gold pattern above."})

	# Level 2: Scale ascending
	LEVELS.append({"name": "Rising", "desc": "Build an ascending scale",
		"target": [[0,6], [1,5], [2,4], [3,3], [4,2], [5,1], [6,0]],
		"hint": "Notes go from low (bottom) to high (top)"})

	# Level 3: Chord
	LEVELS.append({"name": "Triad", "desc": "Create a C major chord",
		"target": [[0,6], [0,4], [0,2], [4,6], [4,4], [4,2]],
		"hint": "Stack C, E, and G together"})

	# Level 4: Melody + harmony
	LEVELS.append({"name": "Duet", "desc": "Two voices moving together",
		"target": [[0,6], [0,2], [1,5], [1,1], [2,4], [2,0], [3,5], [3,1], [4,6], [4,2]],
		"hint": "Parallel motion — two lines moving in sync"})

	# Level 5: Rhythm pattern
	LEVELS.append({"name": "Pulse", "desc": "Create a rhythmic pattern",
		"target": [[0,4], [1,4], [3,4], [4,4], [6,4], [7,4], [0,2], [4,2]],
		"hint": "Some beats are silent — that's the rhythm"})

	# Level 6: Resolution
	LEVELS.append({"name": "Tension", "desc": "Build tension and resolve it",
		"target": [[0,6], [1,5], [2,3], [3,2], [4,1], [5,1], [6,2], [7,6]],
		"hint": "Go up to create tension, come back down to resolve"})

	# Level 7: Complex harmony
	LEVELS.append({"name": "Cathedral", "desc": "Rich harmonies filling the space",
		"target": [[0,6],[0,4],[0,2],[1,5],[1,3],[2,6],[2,4],[2,2],[2,0],
			[4,6],[4,4],[4,2],[5,5],[5,3],[6,6],[6,4],[6,2],[6,0],[7,6],[7,2]],
		"hint": "Fill columns with stacked thirds"})

	# Level 8: Free composition
	LEVELS.append({"name": "Your Song", "desc": "Create something beautiful — any 12+ notes that harmonize",
		"target": [],  # No specific target — just need high harmony score
		"hint": "Place at least 12 notes. Consonant intervals glow bright.",
		"free": true, "min_notes": 12, "min_harmony": 60})

func _init_grid() -> void:
	grid.clear()
	for x in range(COLS):
		var col = []
		for y in range(ROWS):
			col.append(false)
		grid.append(col)
	harmony_scores.clear()
	for x in range(COLS):
		harmony_scores.append(0.0)
	play_col = -1

func _process(delta: float) -> void:
	timer += delta
	match state:
		State.TITLE:
			if Input.is_action_just_pressed("click"):
				level = 0
				_load_level(0)
				state = State.PLAYING
		State.PLAYING:
			if Input.is_action_just_pressed("click"):
				_handle_grid_click()
			if Input.is_action_just_pressed("right_click"):
				_handle_grid_right_click()
			if Input.is_action_just_pressed("play"):
				_start_playback()
			if Input.is_action_just_pressed("clear"):
				_init_grid()
		State.PLAYING_BACK:
			_update_playback(delta)
		State.LEVEL_COMPLETE:
			if Input.is_action_just_pressed("click") or Input.is_action_just_pressed("play"):
				level += 1
				if level >= max_levels:
					state = State.GAME_COMPLETE
				else:
					_load_level(level)
					state = State.PLAYING
		State.GAME_COMPLETE:
			if Input.is_action_just_pressed("click"):
				state = State.TITLE

	_update_particles(delta)
	_calc_harmony()
	queue_redraw()

func _load_level(idx: int) -> void:
	_init_grid()
	# Don't pre-fill — player needs to match the target

func _handle_grid_click() -> void:
	var mouse = get_global_mouse_position()
	var gx = int((mouse.x - GRID_X) / CELL_W)
	var gy = int((mouse.y - GRID_Y) / CELL_H)
	if gx >= 0 and gx < COLS and gy >= 0 and gy < ROWS:
		grid[gx][gy] = not grid[gx][gy]
		if grid[gx][gy]:
			_spawn_note_particle(gx, gy)
			_play_note(gy)
		_check_completion()

func _handle_grid_right_click() -> void:
	var mouse = get_global_mouse_position()
	var gx = int((mouse.x - GRID_X) / CELL_W)
	var gy = int((mouse.y - GRID_Y) / CELL_H)
	if gx >= 0 and gx < COLS and gy >= 0 and gy < ROWS:
		grid[gx][gy] = false

func _play_note(note_idx: int) -> void:
	# Web Audio API via JavaScript eval would go here
	# For now we just show visual feedback
	pass

func _start_playback() -> void:
	play_col = 0
	play_timer = 0.0
	state = State.PLAYING_BACK

func _update_playback(delta: float) -> void:
	play_timer += delta
	if play_timer >= play_speed:
		play_timer -= play_speed
		# Play all notes in current column
		for y in range(ROWS):
			if grid[play_col][y]:
				_play_note(y)
				_spawn_note_particle(play_col, y)

		play_col += 1
		if play_col >= COLS:
			play_col = -1
			state = State.PLAYING

func _calc_harmony() -> void:
	# Calculate harmony score for each column
	# Consonant intervals between simultaneous notes = good
	# Dissonant intervals = bad
	for x in range(COLS):
		var notes_in_col = []
		for y in range(ROWS):
			if grid[x][y]:
				notes_in_col.append(y)

		if notes_in_col.size() <= 1:
			harmony_scores[x] = 1.0 if notes_in_col.size() == 1 else 0.0
			continue

		var total_pairs = 0
		var consonant_pairs = 0
		for i in range(notes_in_col.size()):
			for j in range(i + 1, notes_in_col.size()):
				var interval = absi(notes_in_col[i] - notes_in_col[j])
				total_pairs += 1
				# Map our 7-note scale intervals to semitones approximately
				# In a major scale: C-D=2, C-E=4, C-F=5, C-G=7, C-A=9, C-B=11
				var semitones = [0, 2, 4, 5, 7, 9, 11][interval % 7]
				if semitones in CONSONANT_INTERVALS:
					consonant_pairs += 1

		harmony_scores[x] = float(consonant_pairs) / float(total_pairs) if total_pairs > 0 else 0.0

func _check_completion() -> void:
	if level >= LEVELS.size():
		return
	var lv = LEVELS[level]

	if lv.get("free", false):
		# Free composition: check note count and harmony
		var note_count = 0
		var total_harmony = 0.0
		for x in range(COLS):
			for y in range(ROWS):
				if grid[x][y]:
					note_count += 1
			total_harmony += harmony_scores[x]
		if note_count >= lv.get("min_notes", 12) and total_harmony >= lv.get("min_harmony", 60) * 0.01 * COLS:
			state = State.LEVEL_COMPLETE
		return

	# Check if player's grid matches the target
	var target_cells = {}
	for t in lv.target:
		target_cells[Vector2i(t[0], t[1])] = true

	var match_count = 0
	var total_target = target_cells.size()
	var extra_notes = 0

	for x in range(COLS):
		for y in range(ROWS):
			var key = Vector2i(x, y)
			if grid[x][y]:
				if target_cells.has(key):
					match_count += 1
				else:
					extra_notes += 1

	if match_count >= total_target and extra_notes == 0:
		state = State.LEVEL_COMPLETE
		# Celebration particles
		for i in range(30):
			particles.append({
				"x": randf() * SW, "y": randf() * SH,
				"vx": randf() * 200 - 100, "vy": randf() * -200 - 50,
				"life": 2.0, "color": NOTE_COLORS[randi() % NOTE_COLORS.size()],
				"size": randf() * 4 + 2
			})

func _spawn_note_particle(gx: int, gy: int) -> void:
	var px = GRID_X + gx * CELL_W + CELL_W / 2
	var py = GRID_Y + gy * CELL_H + CELL_H / 2
	for i in range(5):
		particles.append({
			"x": px, "y": py,
			"vx": randf() * 60 - 30, "vy": randf() * -40 - 10,
			"life": 0.8, "color": NOTE_COLORS[gy],
			"size": randf() * 3 + 1
		})

func _update_particles(delta: float) -> void:
	for i in range(particles.size() - 1, -1, -1):
		var p = particles[i]
		p.x += p.vx * delta
		p.y += p.vy * delta
		p.vy += 80 * delta  # gravity
		p.life -= delta
		if p.life <= 0:
			particles.remove_at(i)

# ================================================================
# DRAWING
# ================================================================
func _draw() -> void:
	match state:
		State.TITLE: _draw_title()
		State.PLAYING, State.PLAYING_BACK: _draw_game()
		State.LEVEL_COMPLETE: _draw_game(); _draw_level_complete()
		State.GAME_COMPLETE: _draw_game_complete()

	# Always draw particles
	for p in particles:
		draw_circle(Vector2(p.x, p.y), p.size, Color(p.color.r, p.color.g, p.color.b, p.life))

func _draw_title() -> void:
	# Dark background with color wave
	draw_rect(Rect2(0, 0, SW, SH), Color(0.04, 0.03, 0.08))

	# Animated color waves
	for i in range(7):
		var wave_y = 200 + sin(timer * 0.8 + i * 0.9) * 80
		var wave_alpha = 0.08 + sin(timer + i * 0.5) * 0.03
		for x in range(0, SW, 4):
			var y = wave_y + sin(x * 0.015 + timer + i) * 30
			draw_rect(Rect2(x, y, 4, 3), Color(NOTE_COLORS[i].r, NOTE_COLORS[i].g, NOTE_COLORS[i].b, wave_alpha))

	# Stars
	for i in range(60):
		var sx = fmod(i * 137.5, float(SW))
		var sy = fmod(i * 91.3, float(SH))
		var twinkle = 0.2 + sin(timer * 2 + i) * 0.15
		draw_rect(Rect2(sx, sy, 1, 1), Color(0.6, 0.6, 0.8, twinkle))

	# Title
	var glow = 0.7 + sin(timer * 1.5) * 0.15
	_text(250, 200, "RESONANCE", 36, Color(0.8 * glow, 0.7 * glow, 1.0 * glow))
	_text(260, 240, "A Music Puzzle Game", 14, Color(0.5, 0.45, 0.65))
	_text(230, 280, "Place notes to create harmonies.", 11, Color(0.4, 0.38, 0.55))
	_text(230, 300, "Match the target pattern to advance.", 11, Color(0.4, 0.38, 0.55))

	# Note preview — animated rainbow bar
	for i in range(7):
		var bx = 240 + i * 46
		var by = 350 + sin(timer * 2 + i * 0.8) * 10
		draw_rect(Rect2(bx, by, 36, 20), NOTE_COLORS[i] * 0.7)
		draw_rect(Rect2(bx + 2, by + 2, 32, 16), NOTE_COLORS[i])
		_text(bx + 12, by + 15, NOTE_NAMES[i], 10, Color.WHITE)

	if fmod(timer, 1.2) < 0.8:
		_text(310, 450, "CLICK TO START", 16, Color(0.8, 0.75, 1.0))

	_text(250, 540, "Controls: Click=place  Right-click=remove", 9, Color(0.35, 0.33, 0.48))
	_text(250, 558, "Space=play  C=clear grid", 9, Color(0.35, 0.33, 0.48))

func _draw_game() -> void:
	# Background gradient
	for y in range(0, SH, 4):
		var t = float(y) / SH
		draw_rect(Rect2(0, y, SW, 4), Color(0.04 + t * 0.02, 0.03 + t * 0.01, 0.08 - t * 0.03))

	# Level info
	if level < LEVELS.size():
		var lv = LEVELS[level]
		_text(30, 25, "Level " + str(level + 1) + ": " + lv.name, 14, Color(0.7, 0.65, 0.85))
		_text(30, 45, lv.desc, 10, Color(0.5, 0.48, 0.62))
		_text(30, 65, lv.hint, 8, Color(0.4, 0.38, 0.52))

	# Target pattern preview (small, above the grid)
	if level < LEVELS.size():
		var lv = LEVELS[level]
		_text(GRID_X, GRID_Y - 20, "TARGET:", 8, Color(0.7, 0.6, 0.4))
		for t in lv.target:
			var tx = GRID_X + t[0] * CELL_W / 2 + 50
			var ty = GRID_Y - 45 + t[1] * 4
			draw_rect(Rect2(tx, ty, CELL_W / 2 - 2, 3), Color(0.9, 0.75, 0.3, 0.7))

	# Note labels (left side)
	for y in range(ROWS):
		var py = GRID_Y + y * CELL_H + CELL_H / 2
		_text(GRID_X - 30, py + 4, NOTE_NAMES[ROWS - 1 - y], 12, NOTE_COLORS[ROWS - 1 - y] * 0.8)

	# Column numbers (top)
	for x in range(COLS):
		var px = GRID_X + x * CELL_W + CELL_W / 2
		_text(px - 4, GRID_Y - 5, str(x + 1), 9, Color(0.4, 0.4, 0.5))

	# Grid cells
	for x in range(COLS):
		for y in range(ROWS):
			var px = GRID_X + x * CELL_W
			var py = GRID_Y + y * CELL_H
			var note_idx = ROWS - 1 - y  # bottom = C, top = B

			# Cell background
			var bg = Color(0.08, 0.07, 0.12)
			if (x + y) % 2 == 0:
				bg = Color(0.09, 0.08, 0.13)

			# Highlight during playback
			if x == play_col:
				bg = Color(0.15, 0.12, 0.22)

			draw_rect(Rect2(px + 1, py + 1, CELL_W - 2, CELL_H - 2), bg)

			# Target cell indicator
			if level < LEVELS.size():
				var lv = LEVELS[level]
				for t in lv.target:
					if t[0] == x and t[1] == y:
						# Gold dotted outline for target
						draw_rect(Rect2(px + 3, py + 3, CELL_W - 6, CELL_H - 6),
							Color(0.9, 0.75, 0.3, 0.15))
						draw_rect(Rect2(px + 3, py + 3, CELL_W - 6, CELL_H - 6),
							Color(0.9, 0.75, 0.3, 0.3), false, 1)

			# Placed note
			if grid[x][y]:
				var col = NOTE_COLORS[note_idx]
				# Glow based on harmony
				var harmony = harmony_scores[x]
				var glow_alpha = 0.1 + harmony * 0.15

				# Glow ring
				draw_circle(Vector2(px + CELL_W/2, py + CELL_H/2), CELL_H * 0.4,
					Color(col.r, col.g, col.b, glow_alpha))

				# Note body — rounded rectangle feel
				draw_rect(Rect2(px + 6, py + 6, CELL_W - 12, CELL_H - 12), col * 0.6)
				draw_rect(Rect2(px + 8, py + 8, CELL_W - 16, CELL_H - 16), col)
				# Highlight
				draw_rect(Rect2(px + 8, py + 8, CELL_W - 16, 4), col * 1.3)
				# Note name
				_text(px + CELL_W/2 - 4, py + CELL_H/2 + 4, NOTE_NAMES[note_idx], 10, Color.WHITE)

				# Playback flash
				if x == play_col:
					draw_rect(Rect2(px + 4, py + 4, CELL_W - 8, CELL_H - 8),
						Color(1, 1, 1, 0.3))

			# Grid lines
			draw_rect(Rect2(px, py, CELL_W, CELL_H), Color(0.2, 0.18, 0.28, 0.3), false, 1)

	# Harmony bars below grid
	_text(GRID_X, GRID_Y + ROWS * CELL_H + 15, "HARMONY:", 8, Color(0.5, 0.48, 0.62))
	for x in range(COLS):
		var bx = GRID_X + x * CELL_W + 5
		var by = GRID_Y + ROWS * CELL_H + 25
		var bw = CELL_W - 10
		var bh = 12
		draw_rect(Rect2(bx, by, bw, bh), Color(0.1, 0.1, 0.15))
		var h = harmony_scores[x]
		var bar_color = Color(0.2, 0.7, 0.3) if h > 0.7 else Color(0.8, 0.7, 0.2) if h > 0.3 else Color(0.7, 0.2, 0.2) if h > 0 else Color(0.15, 0.15, 0.2)
		draw_rect(Rect2(bx, by, bw * h, bh), bar_color)

	# Playback indicator line
	if play_col >= 0:
		var lx = GRID_X + play_col * CELL_W + CELL_W / 2
		draw_line(Vector2(lx, GRID_Y - 5), Vector2(lx, GRID_Y + ROWS * CELL_H + 5),
			Color(1, 1, 1, 0.3), 2)

	# Connection lines between notes in same column (showing intervals)
	for x in range(COLS):
		var notes = []
		for y in range(ROWS):
			if grid[x][y]:
				notes.append(y)
		if notes.size() >= 2:
			for i in range(notes.size() - 1):
				var y1 = notes[i]
				var y2 = notes[i + 1]
				var px1 = GRID_X + x * CELL_W + CELL_W / 2
				var py1 = GRID_Y + y1 * CELL_H + CELL_H / 2
				var py2 = GRID_Y + y2 * CELL_H + CELL_H / 2
				var interval = absi(y1 - y2)
				var semitones = [0, 2, 4, 5, 7, 9, 11][interval % 7]
				var is_consonant = semitones in CONSONANT_INTERVALS
				var line_color = Color(0.3, 0.8, 0.4, 0.3) if is_consonant else Color(0.8, 0.3, 0.2, 0.2)
				draw_line(Vector2(px1, py1), Vector2(px1, py2), line_color, 2)

	# Connection lines between adjacent columns (melodic movement)
	for x in range(COLS - 1):
		for y1 in range(ROWS):
			if not grid[x][y1]: continue
			for y2 in range(ROWS):
				if not grid[x + 1][y2]: continue
				var px1 = GRID_X + x * CELL_W + CELL_W - 6
				var py1 = GRID_Y + y1 * CELL_H + CELL_H / 2
				var px2 = GRID_X + (x + 1) * CELL_W + 6
				var py2 = GRID_Y + y2 * CELL_H + CELL_H / 2
				var step = absi(y1 - y2)
				var alpha = 0.15 if step <= 2 else 0.05  # stepwise motion is more visible
				draw_line(Vector2(px1, py1), Vector2(px2, py2),
					Color(0.6, 0.5, 0.8, alpha), 1)

	# Right panel — info
	var panel_x = GRID_X + COLS * CELL_W + 30
	draw_rect(Rect2(panel_x, GRID_Y, 160, 300), Color(0.06, 0.05, 0.10, 0.7))
	_text(panel_x + 10, GRID_Y + 20, "NOTES", 10, Color(0.6, 0.55, 0.75))

	# Note count
	var note_count = 0
	for x in range(COLS):
		for y in range(ROWS):
			if grid[x][y]: note_count += 1
	_text(panel_x + 10, GRID_Y + 40, "Placed: " + str(note_count), 9, Color(0.5, 0.5, 0.6))

	# Average harmony
	var avg_harmony = 0.0
	var cols_with_notes = 0
	for x in range(COLS):
		if harmony_scores[x] > 0:
			avg_harmony += harmony_scores[x]
			cols_with_notes += 1
	if cols_with_notes > 0:
		avg_harmony /= cols_with_notes
	_text(panel_x + 10, GRID_Y + 60, "Harmony: " + str(int(avg_harmony * 100)) + "%", 9,
		Color(0.3, 0.8, 0.4) if avg_harmony > 0.7 else Color(0.8, 0.7, 0.2) if avg_harmony > 0.3 else Color(0.6, 0.5, 0.5))

	# Scale reference
	_text(panel_x + 10, GRID_Y + 100, "SCALE", 9, Color(0.5, 0.48, 0.62))
	for i in range(ROWS):
		var ni = ROWS - 1 - i
		draw_rect(Rect2(panel_x + 10, GRID_Y + 118 + i * 18, 12, 14), NOTE_COLORS[ni])
		_text(panel_x + 28, GRID_Y + 130 + i * 18, NOTE_NAMES[ni], 8, NOTE_COLORS[ni])

	# Consonant intervals guide
	_text(panel_x + 10, GRID_Y + 260, "CONSONANT", 8, Color(0.4, 0.6, 0.4))
	_text(panel_x + 10, GRID_Y + 275, "3rd, 4th, 5th", 7, Color(0.35, 0.5, 0.35))
	_text(panel_x + 10, GRID_Y + 290, "= green lines", 7, Color(0.3, 0.7, 0.3))

	# Controls
	_text(30, SH - 30, "SPACE: Play  |  C: Clear  |  Click: Place note  |  Right-click: Remove", 8, Color(0.35, 0.33, 0.48))

func _draw_level_complete() -> void:
	draw_rect(Rect2(0, 0, SW, SH), Color(0, 0, 0, 0.4))
	var bounce = sin(timer * 3) * 5
	_text(260, 250 + bounce, "PERFECT HARMONY!", 28, Color(0.9, 0.85, 0.4))
	_text(280, 300, "Level " + str(level + 1) + " complete!", 14, Color(0.7, 0.65, 0.85))
	if fmod(timer, 1.0) < 0.6:
		_text(310, 380, "Click to continue", 12, Color(0.7, 0.7, 0.8))

func _draw_game_complete() -> void:
	draw_rect(Rect2(0, 0, SW, SH), Color(0.04, 0.03, 0.08))
	# Rainbow celebration
	for i in range(7):
		var wave_y = 200 + sin(timer * 1.5 + i * 0.9) * 100
		for x in range(0, SW, 3):
			var y = wave_y + sin(x * 0.02 + timer * 2 + i) * 40
			draw_rect(Rect2(x, y, 3, 4), Color(NOTE_COLORS[i].r, NOTE_COLORS[i].g, NOTE_COLORS[i].b, 0.15))

	_text(220, 230, "RESONANCE ACHIEVED", 32, Color(0.9, 0.85, 1.0))
	_text(250, 280, "You've mastered the art of harmony.", 14, Color(0.6, 0.58, 0.75))
	_text(280, 310, "All " + str(max_levels) + " levels complete!", 12, Color(0.5, 0.7, 0.5))
	if fmod(timer, 1.0) < 0.6:
		_text(330, 420, "Click to restart", 12, Color(0.6, 0.6, 0.7))

func _text(x: float, y: float, text: String, size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
