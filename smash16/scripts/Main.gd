extends Node2D

# ---------------------------------------------------------------------------
# SMASH 16 -- main loop and screens
#
# Everything runs on _physics_process at a fixed 60Hz (set in project.godot).
# A fighting game must never tie its logic to frame rate: startup and recovery
# are counted in FRAMES, and if those frames get longer on a slow machine the
# whole game changes speed.
# ---------------------------------------------------------------------------

enum Screen { TITLE, SELECT, COUNT, FIGHT, RESULT }

var screen: int = Screen.TITLE
var t: float = 0.0

var world: Node2D
var stage: Stage
var fx: Fx
var hud: Hud
var ui: Node2D
var fighters_root: Node2D
var shots_root: Node2D
var preview_root: Node2D

var fighters: Array = []
var shots: Array = []
var previews: Array = []

# --- selection ---
var sel: Array = [0, 5]                 # Mega Man X and Mario to start
var locked: Array = [false, false]
var p2_cpu: bool = true
var cpu_level: int = 1
var stock_count: int = 3

var count_t: int = 0
var result_t: int = 0
var winner = null

# ---------------------------------------------------------------------------
# CONTROLS
# Jump gets its own key rather than being "tap up". Tap-jump makes grounded
# up-attacks essentially unreachable, and up-attacks are half your combo game.
#
#   P1   A/D move   W aim up   S aim down/drop   SPACE jump   F attack  G special  C shield
#   P2   arrows     RSHIFT jump   . attack   / special   , shield   (numpad alts)
# ---------------------------------------------------------------------------
const KEYS := [
	{
		"left": [KEY_A], "right": [KEY_D], "up": [KEY_W], "down": [KEY_S],
		"jump": [KEY_SPACE], "attack": [KEY_F], "special": [KEY_G], "shield": [KEY_C],
	},
	{
		"left": [KEY_LEFT], "right": [KEY_RIGHT], "up": [KEY_UP], "down": [KEY_DOWN],
		"jump": [KEY_SHIFT, KEY_KP_0], "attack": [KEY_PERIOD, KEY_KP_1],
		"special": [KEY_SLASH, KEY_KP_2], "shield": [KEY_COMMA, KEY_KP_3],
	},
]
const ACTS := ["left", "right", "up", "down", "jump", "attack", "special", "shield"]

var cur_in: Array = [{}, {}]
var prev_in: Array = [{}, {}]


func _ready() -> void:
	world = Node2D.new()
	add_child(world)

	stage = Stage.new()
	world.add_child(stage)

	shots_root = Node2D.new()
	world.add_child(shots_root)

	fighters_root = Node2D.new()
	world.add_child(fighters_root)

	preview_root = Node2D.new()
	world.add_child(preview_root)

	fx = Fx.new()
	world.add_child(fx)

	hud = Hud.new()
	add_child(hud)

	ui = Node2D.new()
	ui.set_script(load("res://scripts/Ui.gd"))
	ui.set("main", self)
	add_child(ui)

	for p in 2:
		var d := {}
		for a in ACTS:
			d[a] = false
		cur_in[p] = d.duplicate()
		prev_in[p] = d.duplicate()

	_build_previews()
	preview_root.visible = false

	for a in OS.get_cmdline_user_args():
		if a == "--autotest":
			_auto = true
		if a == "--portrait":
			_auto = true
			_portrait_only = true
	if _auto:
		stock_count = 3
		cpu_level = 2
		p2_cpu = true


# ===========================================================================
# INPUT
# ===========================================================================
func _sample_inputs() -> void:
	for p in 2:
		prev_in[p] = cur_in[p].duplicate()
		var d := {}
		for a in ACTS:
			var on := false
			for k in KEYS[p][a]:
				if Input.is_physical_key_pressed(k):
					on = true
					break
			d[a] = on
		cur_in[p] = d


func _human_input(p: int) -> Dictionary:
	var c: Dictionary = cur_in[p]
	var q: Dictionary = prev_in[p]
	var lx := 0
	if c["left"]:
		lx -= 1
	if c["right"]:
		lx += 1
	return {
		"lx": lx,
		"up": c["up"], "down": c["down"],
		"jump_p": c["jump"] and not q["jump"], "jump_h": c["jump"],
		"atk_p": c["attack"] and not q["attack"], "sp_p": c["special"] and not q["special"],
		"sp_h": c["special"],
		"shield_p": c["shield"] and not q["shield"], "shield_h": c["shield"],
	}


func _tapped(p: int, a: String) -> bool:
	return cur_in[p][a] and not prev_in[p][a]


func _any_tapped(a: String) -> bool:
	return _tapped(0, a) or _tapped(1, a)


# ===========================================================================
# MAIN TICK
# ===========================================================================
func _physics_process(_dt: float) -> void:
	t += 1.0
	_sample_inputs()
	stage.show_platforms = screen in [Screen.COUNT, Screen.FIGHT, Screen.RESULT]
	stage.tick()

	match screen:
		Screen.TITLE:   _title_tick()
		Screen.SELECT:  _select_tick()
		Screen.COUNT:   _count_tick()
		Screen.FIGHT:   _fight_tick()
		Screen.RESULT:  _result_tick()

	fx.tick()
	world.position = fx.shake_offset()
	hud.queue_redraw()
	ui.queue_redraw()


func _title_tick() -> void:
	for f in previews:
		f.anim += 1.0
		f.queue_redraw()
	if _any_tapped("attack") or _any_tapped("jump"):
		Sfx.play("confirm")
		_goto_select()


# ---------------------------------------------------------------------------
func _goto_select() -> void:
	screen = Screen.SELECT
	locked = [false, false]
	_clear_fight()
	preview_root.visible = true
	hud.fighters = []


func _build_previews() -> void:
	for i in Chars.count():
		var f := Fighter.new()
		f.setup(i, 0, false, 1)
		f.state = "idle"
		f.on_ground = true
		f.facing = 1
		f.position = _cell_center(i) + Vector2(0, 17)
		preview_root.add_child(f)
		previews.append(f)


const SEL_COLS := 5
const CELL_W := 72.0
const CELL_H := 44.0
const CELL_TOP := 24.0   # cell spans c.y-CELL_TOP .. c.y-CELL_TOP+CELL_H

func _cell_center(i: int) -> Vector2:
	var col := i % SEL_COLS
	var row := i / SEL_COLS
	var x0 := (float(Rules.VW) - float(SEL_COLS) * CELL_W) * 0.5
	return Vector2(x0 + float(col) * CELL_W + CELL_W * 0.5, 74.0 + float(row) * 62.0)


func _select_tick() -> void:
	for f in previews:
		f.anim += 1.0
		f.queue_redraw()

	for p in 2:
		if p == 1 and p2_cpu:
			continue
		if locked[p]:
			if _tapped(p, "shield"):
				locked[p] = false
				Sfx.play("back")
			continue
		var moved := false
		if _tapped(p, "left"):
			sel[p] = (sel[p] + Chars.count() - 1) % Chars.count()
			moved = true
		if _tapped(p, "right"):
			sel[p] = (sel[p] + 1) % Chars.count()
			moved = true
		if _tapped(p, "up") or _tapped(p, "down"):
			sel[p] = (sel[p] + SEL_COLS) % Chars.count()
			moved = true
		if moved:
			Sfx.play("select")
		if _tapped(p, "attack") or _tapped(p, "jump"):
			locked[p] = true
			Sfx.play("confirm")

	# P2 side: let player 1 flip between CPU and a second human, and pick
	# the CPU's character too.
	if p2_cpu:
		if _tapped(0, "special"):
			cpu_level = (cpu_level + 1) % 3
			Sfx.play("select")
	if Input.is_physical_key_pressed(KEY_TAB) and not _tab_prev:
		p2_cpu = not p2_cpu
		locked[1] = false
		Sfx.play("select")
	_tab_prev = Input.is_physical_key_pressed(KEY_TAB)

	for k in range(1, 6):
		if Input.is_physical_key_pressed(KEY_1 + k - 1):
			stock_count = k

	if _tapped(0, "shield") and not locked[0]:
		screen = Screen.TITLE

	var p2_ready: bool = locked[1] or p2_cpu
	if locked[0] and p2_ready:
		_start_match()


var _tab_prev := false


# ---------------------------------------------------------------------------
func _start_match() -> void:
	_clear_fight()
	preview_root.visible = false
	if p2_cpu:
		# CPU picks whatever P2's cursor was parked on
		pass
	for p in 2:
		var f := Fighter.new()
		f.arena = self
		var cpu: bool = (p == 1 and p2_cpu) or force_both_cpu
		f.setup(int(sel[p]), p, cpu, stock_count)
		if cpu:
			f.brain = Brain.new(f, cpu_level)
		fighters_root.add_child(f)
		fighters.append(f)
	hud.fighters = fighters
	screen = Screen.COUNT
	count_t = 186
	winner = null


func _clear_fight() -> void:
	for f in fighters:
		f.queue_free()
	fighters.clear()
	for s in shots:
		s.queue_free()
	shots.clear()
	hud.fighters = []


func _count_tick() -> void:
	count_t -= 1
	# fighters fall into place during the countdown
	for f in fighters:
		f.tick(Brain.blank(), fighters)
	if count_t % 45 == 0 and count_t > 45:
		Sfx.play("count")
	if count_t <= 0:
		Sfx.play("go")
		screen = Screen.FIGHT


# ---------------------------------------------------------------------------
func _fight_tick() -> void:
	var inputs: Array = []
	for f in fighters:
		if f.is_cpu and f.brain:
			inputs.append(f.brain.think(fighters))
		else:
			inputs.append(_human_input(f.slot))

	for i in fighters.size():
		if fighters[i].stocks > 0:
			fighters[i].tick(inputs[i], fighters)

	# projectiles
	var live: Array = []
	for s in shots:
		s.tick(fighters)
		if s.dead:
			s.queue_free()
		else:
			live.append(s)
	shots = live

	# blast zones
	for f in fighters:
		if f.ko_timer > 0 or f.stocks <= 0:
			continue
		if Rules.out_of_bounds(f.position):
			var at := Vector2(
				clampf(f.position.x, 10.0, float(Rules.VW) - 10.0),
				clampf(f.position.y, 12.0, float(Rules.VH) - 40.0))
			fx.ko_burst(at, f.ch["pal"]["main"])
			Sfx.play("ko")
			f.kill()

	# is it over?
	var alive: Array = []
	for f in fighters:
		if f.stocks > 0:
			alive.append(f)
	if alive.size() <= 1:
		winner = alive[0] if alive.size() == 1 else null
		screen = Screen.RESULT
		result_t = 0


func _result_tick() -> void:
	result_t += 1
	for f in fighters:
		if f.stocks > 0:
			f.tick(Brain.blank(), fighters)
	if result_t > 60 and (_any_tapped("attack") or _any_tapped("jump")):
		Sfx.play("confirm")
		_goto_select()
	if result_t > 60 and (_tapped(0, "shield") or _tapped(1, "shield")):
		Sfx.play("back")
		_goto_select()


# ===========================================================================
# CALLBACKS FROM FIGHTERS AND PROJECTILES
# ===========================================================================
func resolve_hit(att, vic, m: Dictionary, pos: Vector2) -> void:
	var res: String = vic.apply_hit(att, m, pos)
	match res:
		"hit":
			# The launch speed we just gave them IS the strength of the hit,
			# so the spark and the sound scale straight off it.
			var kb: float = vic.vel.length() / Rules.KB_SCALE
			var col: Color = Color("fff3c4")
			if att != null:
				col = att.ch["pal"]["accent"]
			fx.spark(pos, kb, col)
			if m.get("spike", false):
				fx.spark(pos + Vector2(0, 4), kb * 0.6, Color("ff7a3a"))
			Sfx.play("bighit" if kb > 4.6 else "hit", 1.0 + randf_range(-0.06, 0.06))
		"shield":
			fx.spark(pos, 1.2, Color("6cc8ff"))
			Sfx.play("shield")
		"break":
			fx.spark(pos, 6.0, Color("f2e14a"))
			Sfx.play("break")


func spawn_shot(from, shot_name: String, charge_frames: int) -> void:
	if not Moves.SHOTS.has(shot_name):
		return
	var ratio := 0.0
	var sp: Dictionary = Moves.SPECIALS.get(from.ch["special"], {})
	if sp.get("chargeable", false):
		ratio = clampf(float(charge_frames) / float(sp["max_charge"]), 0.0, 1.0)
	var s := Shot.new()
	s.arena = self
	s.setup(from, shot_name, ratio)
	shots_root.add_child(s)
	shots.append(s)
	Sfx.play("charged" if ratio > 0.85 else "shot", 1.0 - ratio * 0.35)


func spawn_burst(from, shot_name: String, pos: Vector2) -> void:
	if not Moves.SHOTS.has(shot_name):
		return
	var s := Shot.new()
	s.arena = self
	s.setup(from, shot_name, 0.0)
	s.position = pos
	shots_root.add_child(s)
	shots.append(s)


func land_puff(pos: Vector2) -> void:
	fx.puff(pos)


# ===========================================================================
# AUTOTEST
# Drives the whole game with no human attached so the art and the fighting
# can be screenshotted and looked at. Run with:
#     godot --path smash16 -- --autotest
# ===========================================================================
var _auto := false
var _portrait_only := false
var _fc := 0
var force_both_cpu := false

const _PLAN := {
	20:   "shot_10_title",
	26:   "go_select",
	70:   "shot_20_select",
	80:   "portrait_on",
	120:  "shot_15_portrait",
	126:  "portrait_off",
	140:  "go_fight",
	330:  "shot_30_countdown",
	560:  "shot_40_fight",
	960:  "shot_50_fight",
	1460: "shot_60_fight",
	2060: "shot_70_fight",
	2760: "shot_80_fight",
	4200: "quit",
}

# Which fighters to blow up for the portrait shot, and where to stand them.
const _PORTRAIT := [3, 5]

var _got_result := false


func _portrait_on() -> void:
	# Blow a few fighters up so their art can actually be judged -- at 15
	# pixels tall you cannot tell a good sprite from a bad one.
	ui.visible = false
	var n := _PORTRAIT.size()
	for i in previews.size():
		previews[i].visible = _PORTRAIT.has(i)
	for k in n:
		var pv = previews[_PORTRAIT[k]]
		pv.scale = Vector2(5.0, 5.0)
		pv.position = Vector2(float(Rules.VW) * (float(k) + 0.5) / float(n), 195.0)


func _portrait_off() -> void:
	ui.visible = true
	for i in previews.size():
		previews[i].visible = true
		previews[i].scale = Vector2.ONE
		previews[i].position = _cell_center(i) + Vector2(0, 17)


func _process(_d: float) -> void:
	if not _auto:
		return
	_fc += 1

	# Portrait-only mode renders ~35 frames instead of 4200, which matters a
	# lot when something else on the box is hogging the CPU.
	if _portrait_only:
		if _fc == 4:
			_goto_select()
		elif _fc == 10:
			_portrait_on()
		elif _fc == 30:
			_capture("shot_15_portrait")
		elif _fc == 45:
			get_tree().quit()
		else:
			for f in previews:
				f.anim += 1.0
				f.queue_redraw()
		return

	if screen == Screen.RESULT and not _got_result and result_t > 40:
		_got_result = true
		_capture("shot_90_result")

	if _fc % 300 == 0:
		var line := "f%d  " % _fc
		for f in fighters:
			line += "%s %d%% x%d   " % [f.ch["name"], int(f.percent), f.stocks]
		print(line)

	if not _PLAN.has(_fc):
		return
	var act: String = _PLAN[_fc]
	if act == "go_select":
		_goto_select()
	elif act == "portrait_on":
		_portrait_on()
	elif act == "portrait_off":
		_portrait_off()
	elif act == "go_fight":
		force_both_cpu = true
		sel = [3, 5]           # Kirby vs Mario
		stock_count = 2
		_start_match()
	elif act == "quit":
		get_tree().quit()
	else:
		_capture(act)


func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
	img.save_png("user://%s.png" % name)
	print("captured ", name)
