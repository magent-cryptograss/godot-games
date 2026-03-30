extends Node2D

# Joe the Crab: Shell Quest
# Overhead adventure - Joe wants to upgrade his shell to a turtle shell
# Explore the beach, tide pools, and reef to find shell pieces

const WORLD_W = 3000.0
const WORLD_H = 3000.0

# Joe state
var joe_pos = Vector2(400, 400)
var joe_vel = Vector2.ZERO
var joe_speed = 180.0
var joe_facing = Vector2(1, 0)
var joe_anim_time = 0.0
var joe_alive = true
var joe_pinching = false
var joe_pinch_timer = 0.0
var joe_shell_level = 0  # 0=crab shell, 1=conch, 2=snail, 3=turtle shell!
var joe_hp = 3
var joe_max_hp = 3
var joe_invuln = 0.0
var joe_has_key = false

# Camera
var camera_pos = Vector2(400, 400)

# World objects
var shells = []       # collectible shell upgrades
var seagulls = []     # enemies
var crabs = []        # friendly NPCs
var rocks = []        # obstacles
var tide_pools = []   # healing
var seaweed_patches = []
var sand_dollars = []  # collectibles
var sand_dollar_count = 0
var message = ""
var message_timer = 0.0
var npc_dialog = ""
var npc_dialog_timer = 0.0
var game_won = false
var win_timer = 0.0

# Zones
var zones = {
	"beach": Rect2(0, 0, 1200, 1200),
	"tidepool": Rect2(1200, 0, 900, 1200),
	"reef": Rect2(2100, 0, 900, 1200),
	"deepwater": Rect2(0, 1200, 3000, 800),
	"cave": Rect2(1200, 1200, 600, 600),
}

func _ready() -> void:
	_generate_world()

func _generate_world() -> void:
	# Shell upgrades (must collect in order)
	shells.append({"pos": Vector2(800, 900), "type": 1, "name": "Conch Shell", "collected": false, "req": 0})
	shells.append({"pos": Vector2(1500, 500), "type": 2, "name": "Spiral Snail Shell", "collected": false, "req": 1})
	shells.append({"pos": Vector2(2500, 800), "type": 3, "name": "TURTLE SHELL", "collected": false, "req": 2})

	# Seagulls (enemies that swoop)
	for i in range(12):
		seagulls.append({
			"pos": Vector2(randf_range(100, 2800), randf_range(100, 1800)),
			"vel": Vector2(randf_range(-60, 60), randf_range(-60, 60)),
			"anim": randf() * TAU,
			"swooping": false,
			"swoop_timer": 0.0,
			"alive": true,
			"home": Vector2(randf_range(100, 2800), randf_range(100, 1800)),
		})

	# Friendly crabs (NPCs with hints)
	crabs.append({"pos": Vector2(300, 300), "msg": "Hey Joe! I heard there's a\nconch shell down by the\ntide pools to the south.", "name": "Carl"})
	crabs.append({"pos": Vector2(1400, 300), "msg": "Watch out for seagulls!\nYou can pinch them with F\nif they get too close.", "name": "Betty"})
	crabs.append({"pos": Vector2(1800, 900), "msg": "The legendary turtle shell\nis deep in the coral reef\nto the east. Good luck!", "name": "Old Clawson"})

	# Rocks
	for i in range(40):
		rocks.append({
			"pos": Vector2(randf_range(50, 2950), randf_range(50, 1950)),
			"size": randf_range(15, 40),
		})

	# Tide pools (healing)
	for i in range(5):
		tide_pools.append({
			"pos": Vector2(1300 + randf_range(0, 700), randf_range(200, 1000)),
			"radius": randf_range(30, 60),
			"anim": randf() * TAU,
		})

	# Seaweed patches (decoration)
	for i in range(30):
		seaweed_patches.append({
			"pos": Vector2(randf_range(50, 2950), randf_range(50, 1950)),
			"size": randf_range(10, 25),
			"anim": randf() * TAU,
		})

	# Sand dollars
	for i in range(15):
		sand_dollars.append({
			"pos": Vector2(randf_range(100, 2800), randf_range(100, 1800)),
			"collected": false,
			"anim": randf() * TAU,
		})

func _process(delta: float) -> void:
	if game_won:
		win_timer += delta
		queue_redraw()
		return

	if not joe_alive:
		if Input.is_action_just_pressed("interact"):
			_restart()
		queue_redraw()
		return

	_handle_input(delta)
	_update_joe(delta)
	_update_enemies(delta)
	_check_collisions(delta)
	_update_camera(delta)

	joe_anim_time += delta
	if message_timer > 0:
		message_timer -= delta
	if npc_dialog_timer > 0:
		npc_dialog_timer -= delta
	if joe_invuln > 0:
		joe_invuln -= delta
	if joe_pinch_timer > 0:
		joe_pinch_timer -= delta
	else:
		joe_pinching = false

	queue_redraw()

func _handle_input(delta: float) -> void:
	var input = Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)

	if input.length() > 0:
		input = input.normalized()
		joe_facing = input

	joe_vel = input * joe_speed

	if Input.is_action_just_pressed("pinch"):
		joe_pinching = true
		joe_pinch_timer = 0.3

	if Input.is_action_just_pressed("interact"):
		_try_interact()

func _update_joe(delta: float) -> void:
	joe_pos += joe_vel * delta
	joe_pos.x = clampf(joe_pos.x, 20, WORLD_W - 20)
	joe_pos.y = clampf(joe_pos.y, 20, WORLD_H - 20)

	# Rock collision
	for r in rocks:
		var dist = joe_pos.distance_to(r["pos"])
		if dist < r["size"] + 12:
			var push = (joe_pos - r["pos"]).normalized()
			joe_pos = r["pos"] + push * (r["size"] + 12)

	# Tide pool healing
	for tp in tide_pools:
		if joe_pos.distance_to(tp["pos"]) < tp["radius"]:
			if joe_hp < joe_max_hp:
				joe_hp = joe_max_hp
				_show_message("Ahhh... refreshing tide pool!")

func _update_enemies(delta: float) -> void:
	for s in seagulls:
		if not s["alive"]:
			continue
		s["anim"] += delta * 2.0

		# Patrol behavior
		var to_home = s["home"] - s["pos"]
		if to_home.length() > 150:
			s["vel"] = to_home.normalized() * 50
		elif not s["swooping"]:
			# Wander
			s["vel"] += Vector2(randf_range(-20, 20), randf_range(-20, 20)) * delta * 10
			s["vel"] = s["vel"].limit_length(40)

		# Swoop at Joe if close
		var to_joe = joe_pos - s["pos"]
		if to_joe.length() < 200 and not s["swooping"] and randf() < 0.01:
			s["swooping"] = true
			s["swoop_timer"] = 1.5

		if s["swooping"]:
			s["vel"] = to_joe.normalized() * 120
			s["swoop_timer"] -= delta
			if s["swoop_timer"] <= 0:
				s["swooping"] = false
				s["vel"] = -to_joe.normalized() * 60

		s["pos"] += s["vel"] * delta
		s["pos"].x = clampf(s["pos"].x, 10, WORLD_W - 10)
		s["pos"].y = clampf(s["pos"].y, 10, WORLD_H - 10)

func _check_collisions(delta: float) -> void:
	# Seagull collision
	for s in seagulls:
		if not s["alive"]:
			continue
		if joe_pos.distance_to(s["pos"]) < 25:
			if joe_pinching:
				s["alive"] = false
				_show_message("PINCH! Seagull defeated!")
			elif joe_invuln <= 0:
				joe_hp -= 1
				joe_invuln = 1.5
				joe_vel = (joe_pos - s["pos"]).normalized() * 200
				_show_message("Ouch! Seagull attack!")
				if joe_hp <= 0:
					joe_alive = false

	# Sand dollar collection
	for sd in sand_dollars:
		if sd["collected"]:
			continue
		if joe_pos.distance_to(sd["pos"]) < 20:
			sd["collected"] = true
			sand_dollar_count += 1
			_show_message("Found a sand dollar! (%d)" % sand_dollar_count)

func _try_interact() -> void:
	# Check shells
	for s in shells:
		if s["collected"]:
			continue
		if joe_pos.distance_to(s["pos"]) < 40:
			if joe_shell_level >= s["req"]:
				s["collected"] = true
				joe_shell_level = s["type"]
				joe_max_hp += 1
				joe_hp = joe_max_hp
				if s["type"] == 3:
					game_won = true
					win_timer = 0.0
					_show_message("JOE GOT THE TURTLE SHELL!")
				else:
					_show_message("Upgraded to %s! +1 HP" % s["name"])
			else:
				_show_message("Need a better shell first...")
			return

	# Check NPCs
	for c in crabs:
		if joe_pos.distance_to(c["pos"]) < 50:
			npc_dialog = "%s says:\n%s" % [c["name"], c["msg"]]
			npc_dialog_timer = 4.0
			return

func _update_camera(delta: float) -> void:
	camera_pos = camera_pos.lerp(joe_pos, 4.0 * delta)

func _show_message(text: String) -> void:
	message = text
	message_timer = 3.0

func _restart() -> void:
	joe_pos = Vector2(400, 400)
	joe_vel = Vector2.ZERO
	joe_alive = true
	joe_hp = 3
	joe_max_hp = 3
	joe_shell_level = 0
	joe_invuln = 0.0
	sand_dollar_count = 0
	game_won = false
	shells.clear()
	seagulls.clear()
	crabs.clear()
	rocks.clear()
	tide_pools.clear()
	seaweed_patches.clear()
	sand_dollars.clear()
	_generate_world()

func _draw() -> void:
	var cx = camera_pos.x - 640
	var cy = camera_pos.y - 360

	# Background - sand color varies by zone
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.93, 0.87, 0.70))

	# Zone backgrounds
	_draw_zone_bg(cx, cy)

	# Seaweed
	for sw in seaweed_patches:
		var sx: float = sw["pos"].x - cx
		var sy: float = sw["pos"].y - cy
		if sx < -50 or sx > 1330 or sy < -50 or sy > 770:
			continue
		sw["anim"] += 0.02
		_draw_seaweed(sx, sy, sw["size"], sw["anim"])

	# Tide pools
	for tp in tide_pools:
		var tx: float = tp["pos"].x - cx
		var ty: float = tp["pos"].y - cy
		if tx < -80 or tx > 1360 or ty < -80 or ty > 800:
			continue
		tp["anim"] += 0.03
		_draw_tide_pool(tx, ty, tp["radius"], tp["anim"])

	# Rocks
	for r in rocks:
		var rx: float = r["pos"].x - cx
		var ry: float = r["pos"].y - cy
		if rx < -50 or rx > 1330 or ry < -50 or ry > 770:
			continue
		_draw_rock(rx, ry, r["size"])

	# Sand dollars
	for sd in sand_dollars:
		if sd["collected"]:
			continue
		var sdx: float = sd["pos"].x - cx
		var sdy: float = sd["pos"].y - cy
		if sdx < -20 or sdx > 1300 or sdy < -20 or sdy > 740:
			continue
		sd["anim"] += 0.02
		_draw_sand_dollar(sdx, sdy, sd["anim"])

	# Shells
	for s in shells:
		if s["collected"]:
			continue
		var sx: float = s["pos"].x - cx
		var sy: float = s["pos"].y - cy
		if sx < -30 or sx > 1310 or sy < -30 or sy > 750:
			continue
		_draw_shell_pickup(sx, sy, s["type"])

	# Friendly crabs
	for c in crabs:
		var ncx: float = c["pos"].x - cx
		var ncy: float = c["pos"].y - cy
		if ncx < -30 or ncx > 1310 or ncy < -30 or ncy > 750:
			continue
		_draw_npc_crab(ncx, ncy, c["name"])

	# Seagulls
	for s in seagulls:
		if not s["alive"]:
			continue
		var sx: float = s["pos"].x - cx
		var sy: float = s["pos"].y - cy
		if sx < -30 or sx > 1310 or sy < -30 or sy > 750:
			continue
		_draw_seagull(sx, sy, s["anim"], s["swooping"])

	# Joe
	if joe_alive:
		var jx: float = joe_pos.x - cx
		var jy: float = joe_pos.y - cy
		if joe_invuln > 0 and fmod(joe_invuln, 0.2) > 0.1:
			pass  # blink
		else:
			_draw_joe(jx, jy, joe_facing, joe_vel.length() > 10, joe_shell_level)

	# HUD
	_draw_hud()

	# NPC dialog
	if npc_dialog_timer > 0:
		_draw_dialog_box(npc_dialog)

	# Message
	if message_timer > 0:
		var alpha = minf(message_timer, 1.0)
		draw_rect(Rect2(340, 620, 600, 35), Color(0, 0, 0, 0.5 * alpha))
		draw_string(ThemeDB.fallback_font, Vector2(360, 645), message, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, alpha))

	# Death
	if not joe_alive:
		draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, 0.6))
		draw_string(ThemeDB.fallback_font, Vector2(470, 330), "Joe got eaten!", HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color(1, 0.3, 0.2))
		draw_string(ThemeDB.fallback_font, Vector2(460, 380), "Press E to try again", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)

	# Win
	if game_won:
		draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, 0.5))
		var bounce = sin(win_timer * 3.0) * 8
		draw_string(ThemeDB.fallback_font, Vector2(300, 280 + bounce), "JOE GOT THE TURTLE SHELL!", HORIZONTAL_ALIGNMENT_LEFT, -1, 42, Color(0.3, 1.0, 0.4))
		draw_string(ThemeDB.fallback_font, Vector2(350, 340), "No more worrying about predators!", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.9, 0.95, 0.8))
		draw_string(ThemeDB.fallback_font, Vector2(380, 380), "Joe is now basically invincible.", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.9, 0.95, 0.8))
		_draw_joe(640, 480, Vector2(1, 0), false, 3)

func _draw_joe(x: float, y: float, facing: Vector2, moving: bool, shell: int) -> void:
	var bob = sin(joe_anim_time * 6.0) * 2 if moving else 0
	var leg_phase = joe_anim_time * 8.0 if moving else 0.0

	# Shadow
	draw_ellipse_shape(Vector2(x, y + 12), Vector2(16, 6), Color(0, 0, 0, 0.2))

	# Legs (6 legs for a crab)
	var leg_color = Color(0.90, 0.45, 0.25)
	for i in range(3):
		var side = [-1.0, 1.0]
		for s in side:
			var angle = (i - 1) * 0.4 + sin(leg_phase + i * 1.2 + s) * 0.3
			var lx = x + cos(angle) * 14 * s
			var ly = y + 4 + sin(leg_phase + i + s * PI) * 3 + i * 2
			draw_line(Vector2(x + s * 6, y + 2 + i * 2), Vector2(lx, ly), leg_color, 2)

	# Shell (changes based on upgrades)
	match shell:
		0:
			# Basic crab shell
			draw_circle(Vector2(x, y + bob), 14, Color(0.85, 0.35, 0.15))
			draw_circle(Vector2(x, y - 2 + bob), 12, Color(0.92, 0.42, 0.20))
			# Shell pattern
			draw_arc(Vector2(x, y + bob), 8, 0, PI, 10, Color(0.80, 0.30, 0.12), 1.5)
		1:
			# Conch shell
			draw_circle(Vector2(x, y + bob), 15, Color(0.95, 0.80, 0.65))
			draw_circle(Vector2(x - 2, y - 1 + bob), 12, Color(0.90, 0.72, 0.55))
			# Spiral
			draw_arc(Vector2(x, y + bob), 10, 0, TAU * 0.75, 12, Color(0.85, 0.65, 0.45), 2)
			draw_arc(Vector2(x, y + bob), 6, PI, TAU + PI * 0.5, 8, Color(0.80, 0.60, 0.40), 1.5)
		2:
			# Snail shell (bigger, spiral)
			draw_circle(Vector2(x, y + bob), 16, Color(0.75, 0.65, 0.50))
			draw_circle(Vector2(x, y - 2 + bob), 14, Color(0.80, 0.70, 0.55))
			for i in range(3):
				draw_arc(Vector2(x, y + bob), 12 - i * 3, i * 0.5, i * 0.5 + TAU * 0.8, 10, Color(0.65, 0.55, 0.40), 2)
		3:
			# TURTLE SHELL (the goal!)
			# Hexagonal pattern
			draw_circle(Vector2(x, y + bob), 18, Color(0.25, 0.55, 0.20))
			draw_circle(Vector2(x, y - 2 + bob), 16, Color(0.30, 0.62, 0.25))
			# Shell segments
			for i in range(6):
				var a = i * TAU / 6
				draw_line(Vector2(x, y + bob), Vector2(x + cos(a) * 14, y + sin(a) * 14 + bob), Color(0.20, 0.45, 0.15), 1.5)
			draw_circle(Vector2(x, y + bob), 5, Color(0.35, 0.68, 0.30))

	# Eyes (on stalks!)
	var eye_dir = facing.normalized() * 6
	for s in [-1.0, 1.0]:
		var stalk_end = Vector2(x + eye_dir.x + s * 5, y - 10 + bob + eye_dir.y * 0.3)
		draw_line(Vector2(x + s * 4, y - 6 + bob), stalk_end, Color(0.90, 0.45, 0.25), 2)
		draw_circle(stalk_end, 3, Color.WHITE)
		draw_circle(stalk_end + facing.normalized() * 1, 1.5, Color(0.1, 0.1, 0.1))

	# Claws
	var claw_color = Color(0.92, 0.48, 0.28)
	for s in [-1.0, 1.0]:
		var claw_x = x + facing.x * 10 + s * 10
		var claw_y = y + facing.y * 8 + bob
		if joe_pinching and joe_pinch_timer > 0:
			# Pinching animation - claws snap shut
			draw_circle(Vector2(claw_x, claw_y), 5, claw_color)
			draw_line(Vector2(claw_x - 3, claw_y - 2), Vector2(claw_x + 2, claw_y - 5), claw_color, 3)
			draw_line(Vector2(claw_x - 3, claw_y + 2), Vector2(claw_x + 2, claw_y + 5), claw_color, 3)
		else:
			# Open claws
			draw_circle(Vector2(claw_x, claw_y), 5, claw_color)
			draw_line(Vector2(claw_x, claw_y - 2), Vector2(claw_x + s * 4, claw_y - 7), claw_color, 2.5)
			draw_line(Vector2(claw_x, claw_y + 2), Vector2(claw_x + s * 4, claw_y + 7), claw_color, 2.5)

func _draw_seagull(x: float, y: float, anim: float, swooping: bool) -> void:
	var wing_y = sin(anim) * 10
	# Shadow
	draw_ellipse_shape(Vector2(x, y + 20), Vector2(12, 4), Color(0, 0, 0, 0.15))
	# Body
	draw_circle(Vector2(x, y), 8, Color(0.95, 0.95, 0.93))
	# Wings
	draw_line(Vector2(x - 5, y), Vector2(x - 22, y - 8 + wing_y), Color(0.90, 0.90, 0.88), 3)
	draw_line(Vector2(x + 5, y), Vector2(x + 22, y - 8 - wing_y), Color(0.90, 0.90, 0.88), 3)
	# Wing tips
	draw_line(Vector2(x - 22, y - 8 + wing_y), Vector2(x - 28, y - 4 + wing_y), Color(0.3, 0.3, 0.3), 2)
	draw_line(Vector2(x + 22, y - 8 - wing_y), Vector2(x + 28, y - 4 - wing_y), Color(0.3, 0.3, 0.3), 2)
	# Head
	draw_circle(Vector2(x + 6, y - 5), 5, Color(0.96, 0.96, 0.94))
	# Beak
	var beak_color = Color(1.0, 0.7, 0.2) if not swooping else Color(1.0, 0.3, 0.1)
	draw_line(Vector2(x + 10, y - 5), Vector2(x + 16, y - 3), beak_color, 2)
	# Eye (angry when swooping)
	draw_circle(Vector2(x + 8, y - 7), 2, Color.WHITE)
	draw_circle(Vector2(x + 9, y - 7), 1, Color.BLACK)
	if swooping:
		draw_line(Vector2(x + 6, y - 9), Vector2(x + 10, y - 8), Color(0.3, 0.3, 0.3), 1.5)

func _draw_npc_crab(x: float, y: float, crab_name: String) -> void:
	# Same as Joe but different color and stationary
	draw_ellipse_shape(Vector2(x, y + 10), Vector2(14, 5), Color(0, 0, 0, 0.15))
	draw_circle(Vector2(x, y), 12, Color(0.30, 0.60, 0.85))
	draw_circle(Vector2(x, y - 2), 10, Color(0.35, 0.68, 0.90))
	# Eyes
	for s in [-1.0, 1.0]:
		draw_line(Vector2(x + s * 4, y - 8), Vector2(x + s * 6, y - 14), Color(0.30, 0.60, 0.85), 2)
		draw_circle(Vector2(x + s * 6, y - 14), 3, Color.WHITE)
		draw_circle(Vector2(x + s * 6, y - 14), 1.5, Color(0.1, 0.1, 0.1))
	# Name tag
	draw_string(ThemeDB.fallback_font, Vector2(x - 15, y - 22), crab_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.2, 0.5, 0.8))
	# Interact prompt
	if joe_pos.distance_to(Vector2(x + camera_pos.x - 640, y + camera_pos.y - 360)) < 50:
		var pulse = 0.6 + sin(joe_anim_time * 4) * 0.4
		draw_string(ThemeDB.fallback_font, Vector2(x - 10, y + 22), "[E]", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, pulse))

func _draw_shell_pickup(x: float, y: float, shell_type: int) -> void:
	# Glow
	var pulse = 0.5 + sin(joe_anim_time * 3.0) * 0.3
	draw_circle(Vector2(x, y), 25, Color(1, 1, 0.5, pulse * 0.2))

	match shell_type:
		1:
			draw_circle(Vector2(x, y), 12, Color(0.95, 0.80, 0.65))
			draw_arc(Vector2(x, y), 8, 0, TAU * 0.75, 10, Color(0.85, 0.65, 0.45), 2)
			draw_string(ThemeDB.fallback_font, Vector2(x - 25, y + 22), "Conch", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.7, 0.5, 0.3))
		2:
			draw_circle(Vector2(x, y), 14, Color(0.75, 0.65, 0.50))
			for i in range(3):
				draw_arc(Vector2(x, y), 10 - i * 3, i * 0.5, i * 0.5 + TAU * 0.8, 10, Color(0.65, 0.55, 0.40), 2)
			draw_string(ThemeDB.fallback_font, Vector2(x - 30, y + 22), "Snail Shell", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.6, 0.5, 0.35))
		3:
			draw_circle(Vector2(x, y), 16, Color(0.25, 0.55, 0.20))
			for i in range(6):
				var a = i * TAU / 6
				draw_line(Vector2(x, y), Vector2(x + cos(a) * 12, y + sin(a) * 12), Color(0.20, 0.45, 0.15), 1.5)
			draw_string(ThemeDB.fallback_font, Vector2(x - 35, y + 24), "TURTLE SHELL", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.2, 0.6, 0.2))

func _draw_rock(x: float, y: float, sz: float) -> void:
	draw_circle(Vector2(x, y), sz, Color(0.55, 0.52, 0.48))
	draw_circle(Vector2(x - sz * 0.15, y - sz * 0.15), sz * 0.85, Color(0.60, 0.57, 0.52))
	draw_circle(Vector2(x - sz * 0.2, y - sz * 0.25), sz * 0.3, Color(0.65, 0.62, 0.56))

func _draw_tide_pool(x: float, y: float, radius: float, anim: float) -> void:
	draw_circle(Vector2(x, y), radius + 3, Color(0.35, 0.55, 0.45))
	draw_circle(Vector2(x, y), radius, Color(0.30, 0.65, 0.75, 0.8))
	# Ripples
	for i in range(3):
		var r = radius * 0.3 + fmod(anim + i * 2.0, radius * 0.7)
		draw_arc(Vector2(x, y), r, 0, TAU, 20, Color(0.5, 0.8, 0.9, 0.3 * (1.0 - r / radius)), 1)

func _draw_seaweed(x: float, y: float, sz: float, anim: float) -> void:
	var sway = sin(anim) * 4
	draw_line(Vector2(x, y), Vector2(x + sway, y - sz), Color(0.20, 0.55, 0.25), 2)
	draw_line(Vector2(x + 3, y), Vector2(x + 3 - sway, y - sz * 0.8), Color(0.25, 0.60, 0.30), 2)
	draw_circle(Vector2(x + sway, y - sz), 3, Color(0.22, 0.58, 0.28))

func _draw_sand_dollar(x: float, y: float, anim: float) -> void:
	var pulse = 0.8 + sin(anim * 2) * 0.2
	draw_circle(Vector2(x, y), 8, Color(0.92, 0.88, 0.78, pulse))
	# Star pattern
	for i in range(5):
		var a = i * TAU / 5 - PI / 2
		draw_line(Vector2(x, y), Vector2(x + cos(a) * 6, y + sin(a) * 6), Color(0.82, 0.76, 0.65), 1)

func _draw_zone_bg(cx: float, cy: float) -> void:
	# Beach (sand)
	var bx: float = -cx
	var by: float = -cy
	# Tidepool zone (darker, wetter sand)
	draw_rect(Rect2(1200 - cx, -cy, 900, 1200), Color(0.70, 0.75, 0.65, 0.5))
	# Reef zone (bluish)
	draw_rect(Rect2(2100 - cx, -cy, 900, 1200), Color(0.45, 0.65, 0.70, 0.5))
	# Deep water
	draw_rect(Rect2(-cx, 1200 - cy, 3000, 800), Color(0.25, 0.45, 0.65, 0.6))
	# Cave
	draw_rect(Rect2(1200 - cx, 1200 - cy, 600, 600), Color(0.25, 0.22, 0.20, 0.7))

	# Zone labels
	_draw_zone_label("THE BEACH", 600 - cx, 100 - cy, Color(0.7, 0.6, 0.35))
	_draw_zone_label("TIDE POOLS", 1650 - cx, 100 - cy, Color(0.3, 0.55, 0.5))
	_draw_zone_label("CORAL REEF", 2550 - cx, 100 - cy, Color(0.2, 0.5, 0.6))
	_draw_zone_label("DEEP WATER", 1500 - cx, 1300 - cy, Color(0.2, 0.35, 0.55))

func _draw_zone_label(text: String, x: float, y: float, color: Color) -> void:
	if x < -200 or x > 1480 or y < -50 or y > 770:
		return
	draw_string(ThemeDB.fallback_font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(color.r, color.g, color.b, 0.4))

func _draw_hud() -> void:
	# HP
	draw_rect(Rect2(0, 0, 250, 40), Color(0, 0, 0, 0.4))
	draw_string(ThemeDB.fallback_font, Vector2(10, 25), "JOE THE CRAB", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.9, 0.5, 0.3))
	for i in range(joe_max_hp):
		var hx = 140 + i * 22
		var color = Color(0.9, 0.2, 0.2) if i < joe_hp else Color(0.3, 0.1, 0.1)
		draw_circle(Vector2(hx, 20), 8, color)

	# Shell status
	var shell_names = ["Crab Shell", "Conch Shell", "Snail Shell", "TURTLE SHELL!"]
	draw_rect(Rect2(0, 42, 200, 22), Color(0, 0, 0, 0.3))
	draw_string(ThemeDB.fallback_font, Vector2(10, 58), "Shell: %s" % shell_names[joe_shell_level], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.9, 0.85, 0.7))

	# Sand dollars
	draw_rect(Rect2(1100, 0, 180, 30), Color(0, 0, 0, 0.3))
	draw_string(ThemeDB.fallback_font, Vector2(1110, 22), "Sand Dollars: %d" % sand_dollar_count, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.92, 0.88, 0.70))

	# Controls
	draw_rect(Rect2(1000, 690, 280, 30), Color(0, 0, 0, 0.3))
	draw_string(ThemeDB.fallback_font, Vector2(1010, 712), "WASD:Move  F:Pinch  E:Interact", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.5))

func _draw_dialog_box(text: String) -> void:
	draw_rect(Rect2(240, 480, 800, 120), Color(0, 0, 0, 0.8))
	draw_rect(Rect2(242, 482, 796, 116), Color(0.15, 0.25, 0.35))
	draw_rect(Rect2(240, 480, 800, 120), Color(0.4, 0.6, 0.8), false, 2)
	var lines = text.split("\n")
	for i in range(lines.size()):
		draw_string(ThemeDB.fallback_font, Vector2(260, 510 + i * 22), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.9, 0.92, 0.95))

func draw_ellipse_shape(center: Vector2, sz: Vector2, color: Color) -> void:
	var points = PackedVector2Array()
	for i in range(20):
		var a = i * TAU / 20
		points.append(Vector2(center.x + cos(a) * sz.x, center.y + sin(a) * sz.y))
	draw_colored_polygon(points, color)
