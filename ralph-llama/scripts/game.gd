extends Node2D

# Ralph the Wonder Llama - Side-Scroller
# Avoid dragons and forks, reach the cigar box, tap it with a hammer!

const GRAVITY := 1200.0
const LEVEL_LENGTH := 8000.0
const GROUND_Y := 580.0

var ralph_pos := Vector2(100, GROUND_Y)
var ralph_vel := Vector2.ZERO
var ralph_on_ground := true
var ralph_facing_right := true
var ralph_alive := true
var ralph_speed := 350.0
var ralph_jump := -550.0
var ralph_anim_time := 0.0

var camera_x := 0.0
var level_complete := false
var tapping := false
var tap_timer := 0.0
var tap_count := 0
var show_win := false
var win_timer := 0.0

# Obstacles
var dragons := []
var forks := []
var platforms := []
var cigar_box_x := LEVEL_LENGTH - 200.0

# Parallax clouds
var clouds := []

func _ready() -> void:
	_generate_level()
	_generate_clouds()

func _generate_clouds() -> void:
	for i in range(20):
		clouds.append({
			"x": randf() * LEVEL_LENGTH * 1.5,
			"y": randf_range(30, 200),
			"w": randf_range(60, 150),
			"speed": randf_range(0.1, 0.3)
		})

func _generate_level() -> void:
	# Create platforms at intervals
	var x := 400.0
	while x < LEVEL_LENGTH - 400:
		# Ground gap with platform above
		if randf() < 0.3:
			platforms.append({"x": x, "y": GROUND_Y - randf_range(100, 200), "w": randf_range(120, 250)})

		# Dragon placement
		if randf() < 0.15 and x > 600:
			dragons.append({
				"x": x + randf_range(0, 200),
				"y": GROUND_Y - 40,
				"dir": -1.0 if randf() < 0.5 else 1.0,
				"speed": randf_range(80, 160),
				"range": randf_range(100, 250),
				"start_x": x + randf_range(0, 200),
				"anim": randf() * TAU,
				"alive": true
			})

		# Fork placement (falling from above or stuck in ground)
		if randf() < 0.2 and x > 400:
			var fork_y := GROUND_Y - randf_range(0, 20) if randf() < 0.5 else randf_range(200, 400)
			forks.append({
				"x": x + randf_range(0, 150),
				"y": fork_y,
				"stuck": fork_y > GROUND_Y - 50,
				"falling": fork_y < 300,
				"fall_speed": randf_range(100, 200),
				"rot": randf_range(-0.5, 0.5),
				"active": true
			})

		x += randf_range(200, 500)

func _process(delta: float) -> void:
	if show_win:
		win_timer += delta
		queue_redraw()
		if win_timer > 5.0 and Input.is_action_just_pressed("jump"):
			_restart()
		return

	if not ralph_alive:
		if Input.is_action_just_pressed("jump"):
			_restart()
		queue_redraw()
		return

	if level_complete:
		_handle_tapping(delta)
		queue_redraw()
		return

	_handle_input(delta)
	_update_physics(delta)
	_update_enemies(delta)
	_check_collisions()
	_update_camera()

	ralph_anim_time += delta
	queue_redraw()

func _handle_input(delta: float) -> void:
	var move_dir := Input.get_axis("move_left", "move_right")

	ralph_vel.x = move_dir * ralph_speed

	if move_dir > 0:
		ralph_facing_right = true
	elif move_dir < 0:
		ralph_facing_right = false

	if Input.is_action_just_pressed("jump") and ralph_on_ground:
		ralph_vel.y = ralph_jump
		ralph_on_ground = false

func _update_physics(delta: float) -> void:
	# Gravity
	ralph_vel.y += GRAVITY * delta

	# Move
	ralph_pos += ralph_vel * delta

	# Ground collision
	if ralph_pos.y >= GROUND_Y:
		ralph_pos.y = GROUND_Y
		ralph_vel.y = 0
		ralph_on_ground = true

	# Platform collision
	for p in platforms:
		if ralph_vel.y > 0:
			if ralph_pos.x > p["x"] - 20 and ralph_pos.x < p["x"] + p["w"] + 20:
				if ralph_pos.y >= p["y"] and ralph_pos.y - ralph_vel.y * delta <= p["y"] + 10:
					ralph_pos.y = p["y"]
					ralph_vel.y = 0
					ralph_on_ground = true

	# Level bounds
	ralph_pos.x = clampf(ralph_pos.x, 20, LEVEL_LENGTH)

	# Check if reached cigar box
	if ralph_pos.x > cigar_box_x - 60 and ralph_pos.x < cigar_box_x + 60 and ralph_on_ground:
		level_complete = true

func _update_enemies(delta: float) -> void:
	for d in dragons:
		if not d["alive"]:
			continue
		d["anim"] += delta * 3.0
		d["x"] += d["dir"] * d["speed"] * delta
		if absf(d["x"] - d["start_x"]) > d["range"]:
			d["dir"] *= -1.0

	for f in forks:
		if not f["active"]:
			continue
		if f["falling"]:
			f["y"] += f["fall_speed"] * delta
			if f["y"] >= GROUND_Y - 10:
				f["y"] = GROUND_Y - 10
				f["falling"] = false
				f["stuck"] = true

func _check_collisions() -> void:
	var ralph_rect := Rect2(ralph_pos.x - 15, ralph_pos.y - 60, 30, 60)

	for d in dragons:
		if not d["alive"]:
			continue
		var dragon_rect := Rect2(d["x"] - 25, d["y"] - 35, 50, 35)
		if ralph_rect.intersects(dragon_rect):
			# Check if stomping
			if ralph_vel.y > 0 and ralph_pos.y < d["y"] - 10:
				d["alive"] = false
				ralph_vel.y = ralph_jump * 0.6
			else:
				_die()
				return

	for f in forks:
		if not f["active"]:
			continue
		var fork_rect := Rect2(f["x"] - 8, f["y"] - 25, 16, 25)
		if ralph_rect.intersects(fork_rect):
			_die()
			return

func _die() -> void:
	ralph_alive = false
	ralph_vel = Vector2(0, -300)

func _restart() -> void:
	ralph_pos = Vector2(100, GROUND_Y)
	ralph_vel = Vector2.ZERO
	ralph_on_ground = true
	ralph_alive = true
	level_complete = false
	tapping = false
	tap_timer = 0.0
	tap_count = 0
	show_win = false
	win_timer = 0.0
	camera_x = 0.0
	dragons.clear()
	forks.clear()
	platforms.clear()
	clouds.clear()
	_generate_level()
	_generate_clouds()

func _handle_tapping(delta: float) -> void:
	# Ralph needs to LIGHTLY tap the cigar box with a hammer
	if Input.is_action_just_pressed("tap"):
		tap_count += 1
		tap_timer = 0.3
		if tap_count >= 3:
			show_win = true
			win_timer = 0.0
	if tap_timer > 0:
		tap_timer -= delta

func _update_camera() -> void:
	camera_x = lerpf(camera_x, ralph_pos.x - 300, 0.08)
	camera_x = clampf(camera_x, 0, LEVEL_LENGTH - 1280)

func _draw() -> void:
	var cx := camera_x

	# Sky gradient
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.45, 0.72, 0.92))
	draw_rect(Rect2(0, 400, 1280, 320), Color(0.55, 0.80, 0.55))

	# Clouds (parallax)
	for c in clouds:
		var cloud_x: float = fmod(c["x"] - cx * c["speed"] + 2000.0, 1600.0) - 160.0
		_draw_cloud(cloud_x, c["y"], c["w"])

	# Mountains (background)
	for i in range(20):
		var mx: float = i * 500 - fmod(cx * 0.3, 500.0)
		var mh: float = 100 + sin(i * 1.7) * 60
		var points := PackedVector2Array([
			Vector2(mx - 120, 400),
			Vector2(mx, 400 - mh),
			Vector2(mx + 120, 400)
		])
		draw_colored_polygon(points, Color(0.35, 0.55, 0.35, 0.5))

	# Ground
	draw_rect(Rect2(0, GROUND_Y, 1280, 140), Color(0.45, 0.68, 0.30))
	draw_rect(Rect2(0, GROUND_Y, 1280, 4), Color(0.35, 0.55, 0.20))

	# Grass tufts
	for i in range(65):
		var gx: float = fmod(i * 100 - cx, 6500)
		if gx < -50 or gx > 1330:
			continue
		_draw_grass(gx, GROUND_Y)

	# Platforms
	for p in platforms:
		var px: float = p["x"] - cx
		if px < -300 or px > 1580:
			continue
		draw_rect(Rect2(px, p["y"], p["w"], 16), Color(0.55, 0.40, 0.25))
		draw_rect(Rect2(px, p["y"], p["w"], 4), Color(0.65, 0.50, 0.30))
		# Wood grain
		for j in range(int(p["w"]) / 20):
			draw_line(Vector2(px + j * 20 + 10, p["y"] + 4), Vector2(px + j * 20 + 10, p["y"] + 14), Color(0.50, 0.35, 0.20), 1)

	# Forks
	for f in forks:
		if not f["active"]:
			continue
		var fx: float = f["x"] - cx
		if fx < -50 or fx > 1330:
			continue
		_draw_fork(fx, f["y"], f["rot"])

	# Dragons
	for d in dragons:
		if not d["alive"]:
			continue
		var dx: float = d["x"] - cx
		if dx < -100 or dx > 1380:
			continue
		_draw_dragon(dx, d["y"], d["anim"], d["dir"])

	# Cigar box at end of level
	var cbx: float = cigar_box_x - cx
	if cbx > -100 and cbx < 1380:
		_draw_cigar_box(cbx, GROUND_Y)
		if level_complete and not show_win:
			_draw_hammer(cbx, GROUND_Y, tap_timer > 0)

	# Ralph
	var rx: float = ralph_pos.x - cx
	if ralph_alive:
		_draw_ralph(rx, ralph_pos.y, ralph_facing_right, ralph_vel.x != 0, ralph_on_ground)
	else:
		# Death animation - ralph falls off screen
		ralph_pos.y += 3
		_draw_ralph(rx, ralph_pos.y, ralph_facing_right, false, false)

	# HUD
	_draw_hud()

	# Win screen
	if show_win:
		_draw_win_screen()

	# Death message
	if not ralph_alive:
		_draw_death_screen()

	# Tap instruction
	if level_complete and not show_win:
		var pulse := 0.7 + sin(Time.get_ticks_msec() * 0.005) * 0.3
		draw_string(ThemeDB.fallback_font, Vector2(640 - 180, 200), "Press E to lightly tap the cigar box!", HORIZONTAL_ALIGNMENT_LEFT, -1,20, Color(1, 1, 1, pulse))
		draw_string(ThemeDB.fallback_font, Vector2(640 - 60, 230), "Taps: %d / 3" % tap_count, HORIZONTAL_ALIGNMENT_LEFT, -1,18, Color(1, 1, 0.5))

func _draw_ralph(x: float, y: float, facing_right: bool, moving: bool, on_ground: bool) -> void:
	var dir := 1.0 if facing_right else -1.0
	var bob := sin(ralph_anim_time * 8.0) * 3.0 if moving and on_ground else 0.0
	var leg_phase := ralph_anim_time * 10.0 if moving else 0.0

	# Body (llama shaped - horizontal oval)
	draw_circle(Vector2(x, y - 30 + bob), 18, Color(0.95, 0.90, 0.80))  # body
	draw_circle(Vector2(x - 8 * dir, y - 28 + bob), 14, Color(0.92, 0.87, 0.77))  # body back

	# Fluffy wool texture
	for i in range(5):
		var wx := x + sin(i * 1.5) * 10
		var wy := y - 30 + cos(i * 1.8) * 8 + bob
		draw_circle(Vector2(wx, wy), 6, Color(0.98, 0.95, 0.88))

	# Neck (long, llama-like)
	var neck_points := PackedVector2Array([
		Vector2(x + 10 * dir, y - 38 + bob),
		Vector2(x + 14 * dir, y - 65 + bob),
		Vector2(x + 20 * dir, y - 65 + bob),
		Vector2(x + 16 * dir, y - 35 + bob),
	])
	draw_colored_polygon(neck_points, Color(0.92, 0.87, 0.77))

	# Head
	draw_circle(Vector2(x + 18 * dir, y - 70 + bob), 10, Color(0.93, 0.88, 0.78))

	# Snout
	draw_circle(Vector2(x + 26 * dir, y - 68 + bob), 6, Color(0.90, 0.85, 0.75))

	# Eye
	draw_circle(Vector2(x + 20 * dir, y - 73 + bob), 3, Color.WHITE)
	draw_circle(Vector2(x + 21 * dir, y - 73 + bob), 1.5, Color(0.15, 0.1, 0.05))

	# Ears
	var ear_points := PackedVector2Array([
		Vector2(x + 14 * dir, y - 78 + bob),
		Vector2(x + 10 * dir, y - 90 + bob),
		Vector2(x + 18 * dir, y - 80 + bob),
	])
	draw_colored_polygon(ear_points, Color(0.90, 0.85, 0.75))
	var ear2_points := PackedVector2Array([
		Vector2(x + 20 * dir, y - 78 + bob),
		Vector2(x + 22 * dir, y - 90 + bob),
		Vector2(x + 24 * dir, y - 80 + bob),
	])
	draw_colored_polygon(ear2_points, Color(0.90, 0.85, 0.75))

	# Mouth (slight smile)
	draw_arc(Vector2(x + 26 * dir, y - 66 + bob), 3, 0.2, PI - 0.2, 8, Color(0.3, 0.2, 0.1), 1.5)

	# Legs (4 legs, animated)
	var leg_color := Color(0.85, 0.78, 0.65)
	# Front legs
	var fl1_offset := sin(leg_phase) * 8
	var fl2_offset := sin(leg_phase + PI) * 8
	draw_line(Vector2(x + 8 * dir, y - 18 + bob), Vector2(x + 8 * dir + fl1_offset, y), leg_color, 4)
	draw_line(Vector2(x + 12 * dir, y - 18 + bob), Vector2(x + 12 * dir + fl2_offset, y), leg_color, 4)
	# Back legs
	draw_line(Vector2(x - 10 * dir, y - 18 + bob), Vector2(x - 10 * dir + fl2_offset, y), leg_color, 4)
	draw_line(Vector2(x - 6 * dir, y - 18 + bob), Vector2(x - 6 * dir + fl1_offset, y), leg_color, 4)

	# Hooves
	for lx in [x + 8 * dir + fl1_offset, x + 12 * dir + fl2_offset, x - 10 * dir + fl2_offset, x - 6 * dir + fl1_offset]:
		draw_circle(Vector2(lx, y - 2), 3, Color(0.3, 0.25, 0.15))

	# Tail (fluffy)
	var tail_wave := sin(ralph_anim_time * 4.0) * 5
	draw_line(Vector2(x - 18 * dir, y - 35 + bob), Vector2(x - 28 * dir + tail_wave, y - 45 + bob), Color(0.92, 0.87, 0.77), 4)
	draw_circle(Vector2(x - 28 * dir + tail_wave, y - 45 + bob), 5, Color(0.95, 0.92, 0.85))

func _draw_dragon(x: float, y: float, anim: float, dir: float) -> void:
	var wing_y := sin(anim) * 12
	var d := -1.0 if dir < 0 else 1.0

	# Body
	draw_circle(Vector2(x, y - 15), 16, Color(0.20, 0.65, 0.15))
	draw_circle(Vector2(x - 10 * d, y - 12), 12, Color(0.22, 0.60, 0.18))

	# Head
	draw_circle(Vector2(x + 18 * d, y - 18), 10, Color(0.25, 0.70, 0.15))

	# Snout
	var snout := PackedVector2Array([
		Vector2(x + 25 * d, y - 22),
		Vector2(x + 35 * d, y - 18),
		Vector2(x + 25 * d, y - 14),
	])
	draw_colored_polygon(snout, Color(0.28, 0.72, 0.18))

	# Fire breath
	if fmod(anim, TAU) < PI:
		for i in range(3):
			var fx := x + (38 + i * 8) * d
			var fy := y - 18 + sin(anim * 3 + i) * 4
			var fr := 5 - i
			draw_circle(Vector2(fx, fy), fr, Color(1.0, 0.5 - i * 0.15, 0.0, 0.8 - i * 0.2))

	# Evil eye
	draw_circle(Vector2(x + 20 * d, y - 21), 4, Color(1, 0.9, 0))
	draw_circle(Vector2(x + 21 * d, y - 21), 2, Color(0.8, 0, 0))

	# Wings
	var wing := PackedVector2Array([
		Vector2(x - 5, y - 20),
		Vector2(x - 15, y - 40 + wing_y),
		Vector2(x + 5, y - 35 + wing_y),
		Vector2(x + 10, y - 22),
	])
	draw_colored_polygon(wing, Color(0.18, 0.55, 0.12, 0.7))

	# Horns
	draw_line(Vector2(x + 15 * d, y - 26), Vector2(x + 12 * d, y - 36), Color(0.5, 0.45, 0.3), 2)
	draw_line(Vector2(x + 20 * d, y - 26), Vector2(x + 22 * d, y - 35), Color(0.5, 0.45, 0.3), 2)

	# Tail
	var tail_x := x - 25 * d
	draw_line(Vector2(x - 15 * d, y - 10), Vector2(tail_x, y - 15), Color(0.20, 0.60, 0.15), 4)
	# Tail spike
	var spike := PackedVector2Array([
		Vector2(tail_x, y - 20),
		Vector2(tail_x - 6 * d, y - 15),
		Vector2(tail_x, y - 10),
	])
	draw_colored_polygon(spike, Color(0.25, 0.65, 0.15))

func _draw_fork(x: float, y: float, rot: float) -> void:
	# Fork handle
	var handle_color := Color(0.65, 0.62, 0.58)
	var tine_color := Color(0.75, 0.72, 0.68)

	draw_set_transform(Vector2(x, y), rot)

	# Handle
	draw_line(Vector2(0, 0), Vector2(0, -30), handle_color, 3)

	# Tines (3 prongs)
	for i in [-4, 0, 4]:
		draw_line(Vector2(i, -30), Vector2(i, -45), tine_color, 2)

	# Cross piece
	draw_line(Vector2(-5, -30), Vector2(5, -30), handle_color, 2)

	draw_set_transform(Vector2.ZERO, 0)

func _draw_cigar_box(x: float, y: float) -> void:
	# Box body
	draw_rect(Rect2(x - 40, y - 30, 80, 30), Color(0.55, 0.30, 0.12))
	# Lid
	draw_rect(Rect2(x - 42, y - 35, 84, 8), Color(0.60, 0.35, 0.15))
	# Label
	draw_rect(Rect2(x - 25, y - 26, 50, 18), Color(0.85, 0.78, 0.55))
	# Text on label
	draw_string(ThemeDB.fallback_font, Vector2(x - 22, y - 12), "CIGARS", HORIZONTAL_ALIGNMENT_LEFT, -1,11, Color(0.35, 0.20, 0.08))
	# Gold trim
	draw_rect(Rect2(x - 40, y - 30, 80, 2), Color(0.85, 0.70, 0.25))
	draw_rect(Rect2(x - 40, y - 2, 80, 2), Color(0.85, 0.70, 0.25))

func _draw_hammer(x: float, y: float, tapping_now: bool) -> void:
	var hammer_angle := -0.3 if not tapping_now else 0.5
	var hx := x + 50
	var hy := y - 50

	draw_set_transform(Vector2(hx, hy), hammer_angle)

	# Handle
	draw_line(Vector2(0, 0), Vector2(0, 35), Color(0.55, 0.40, 0.20), 4)

	# Head
	draw_rect(Rect2(-10, -5, 20, 10), Color(0.5, 0.5, 0.5))

	draw_set_transform(Vector2.ZERO, 0)

	if tapping_now:
		# Impact star
		_draw_impact_star(x, y - 25)

func _draw_impact_star(x: float, y: float) -> void:
	for i in range(8):
		var angle := i * TAU / 8
		var inner := 3.0
		var outer := 10.0
		draw_line(
			Vector2(x + cos(angle) * inner, y + sin(angle) * inner),
			Vector2(x + cos(angle) * outer, y + sin(angle) * outer),
			Color(1, 1, 0.3), 2
		)

func _draw_cloud(x: float, y: float, w: float) -> void:
	var color := Color(1, 1, 1, 0.7)
	draw_circle(Vector2(x, y), w * 0.25, color)
	draw_circle(Vector2(x + w * 0.2, y - 5), w * 0.3, color)
	draw_circle(Vector2(x + w * 0.45, y), w * 0.22, color)
	draw_circle(Vector2(x - w * 0.15, y + 3), w * 0.2, color)

func _draw_grass(x: float, y: float) -> void:
	var grass_color := Color(0.30, 0.60, 0.18)
	for i in range(3):
		var gx := x + i * 6 - 6
		draw_line(Vector2(gx, y), Vector2(gx + randf_range(-3, 3), y - randf_range(6, 14)), grass_color, 1.5)

func _draw_hud() -> void:
	# Background bar
	draw_rect(Rect2(0, 0, 1280, 30), Color(0, 0, 0, 0.3))
	draw_string(ThemeDB.fallback_font, Vector2(15, 20), "RALPH THE WONDER LLAMA", HORIZONTAL_ALIGNMENT_LEFT, -1,16, Color.WHITE)

	# Progress bar
	var progress := ralph_pos.x / LEVEL_LENGTH
	draw_rect(Rect2(400, 8, 400, 14), Color(0, 0, 0, 0.4))
	draw_rect(Rect2(401, 9, 398 * progress, 12), Color(0.4, 0.9, 0.3))
	draw_string(ThemeDB.fallback_font, Vector2(810, 20), "%.0f%%" % (progress * 100), HORIZONTAL_ALIGNMENT_LEFT, -1,14, Color.WHITE)

	# Controls
	draw_string(ThemeDB.fallback_font, Vector2(1020, 20), "A/D:Move  Space:Jump  E:Tap", HORIZONTAL_ALIGNMENT_LEFT, -1,12, Color(1, 1, 1, 0.6))

func _draw_win_screen() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, 0.6))

	var bounce := sin(win_timer * 3.0) * 10
	draw_string(ThemeDB.fallback_font, Vector2(380, 280 + bounce), "RALPH DID IT!", HORIZONTAL_ALIGNMENT_LEFT, -1,48, Color(1, 0.9, 0.3))
	draw_string(ThemeDB.fallback_font, Vector2(340, 340), "The cigar box has been lightly tapped.", HORIZONTAL_ALIGNMENT_LEFT, -1,22, Color(0.9, 0.85, 0.7))
	draw_string(ThemeDB.fallback_font, Vector2(380, 380), "The world is at peace once more.", HORIZONTAL_ALIGNMENT_LEFT, -1,22, Color(0.9, 0.85, 0.7))

	if win_timer > 2.0:
		var pulse := 0.5 + sin(win_timer * 4.0) * 0.5
		draw_string(ThemeDB.fallback_font, Vector2(460, 460), "Press SPACE to play again", HORIZONTAL_ALIGNMENT_LEFT, -1,18, Color(1, 1, 1, pulse))

func _draw_death_screen() -> void:
	draw_rect(Rect2(300, 280, 680, 120), Color(0, 0, 0, 0.7))
	draw_string(ThemeDB.fallback_font, Vector2(430, 330), "Ralph has fallen!", HORIZONTAL_ALIGNMENT_LEFT, -1,32, Color(1, 0.3, 0.2))
	draw_string(ThemeDB.fallback_font, Vector2(430, 370), "Press SPACE to try again", HORIZONTAL_ALIGNMENT_LEFT, -1,18, Color(0.8, 0.8, 0.8))
