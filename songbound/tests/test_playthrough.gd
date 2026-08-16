extends Node
## Plays real battles to completion, many of them, at speed.
##
## Everything up to now has checked pieces in isolation or poked the state
## machine directly. This lets the whole turn engine actually run -- turn order,
## enemy AI, statuses ticking, deaths, rewards -- and watches for the failure
## no unit test would catch: a fight that never ends.
##
## Engine.time_scale is cranked up so a hundred battles take seconds rather than
## the several minutes they would at the pace a human plays them.

const BATTLE := preload("res://scenes/Battle.tscn")
const MAX_TURNS := 80          # a real fight is 3-12; 80 means something hung
# 12 samples swung the win rate by 30 points between runs, which reads as a
# regression when it is only variance. 40 was steadier and still swung crag by
# 17 points, so the fights are seeded now (see _next_battle) and the count is up
# again -- with a fixed seed a move in these numbers is a real move.
const PER_REGION := 60
const SOAK_SEED := 20260816

var plan := [
	{"region": "meadow", "lv": 3},
	{"region": "wood", "lv": 10},
	{"region": "crag", "lv": 20},
	{"region": "cave", "lv": 30},
	{"region": "deep", "lv": 42},
	# the side dungeons, at the level a player who found them when they were
	# signposted would plausibly be
	{"region": "hollow", "lv": 6},
	{"region": "chapel", "lv": 14},
	{"region": "kennel", "lv": 24},
	{"region": "spire", "lv": 44},
	{"region": "thicket", "lv": 52},
]
var plan_i := 0
var fought := 0
var battle: Node2D = null
var failures := 0
var turns := 0
var stats := []
var region_wins := 0
var region_losses := 0
var region_turns := 0
var region_hp_lost := 0
var hp_at_start := 0
var watchdog := 0.0


func _ready() -> void:
	Engine.time_scale = 30.0
	print("")
	print("== playthrough soak ==")
	print("region    lv   fights  win/loss   avg turns   avg HP lost   worst")
	_begin_region()


func _expect(cond: bool, what: String) -> void:
	if cond:
		print("  ok   %s" % what)
	else:
		print("  FAIL %s" % what)
		failures += 1


func _build_player(lv: int) -> void:
	var p := Player.new("Soak", "guitar", Sprites.build(Sprites.PRESETS[0].opts))
	p.apply_level_choice("fire", 1)
	for l in range(2, lv + 1):
		p.lv = l
		# a plausible mixed build: half general, half into one element
		p.apply_level_choice("general" if l % 2 == 1 else "fire", l)
	p.items = {"tonic": 99, "rosin": 99}
	Game.player = p


func _begin_region() -> void:
	if plan_i >= plan.size():
		_finish()
		return
	_build_player(plan[plan_i].lv)
	fought = 0
	region_wins = 0
	region_losses = 0
	region_turns = 0
	region_hp_lost = 0
	stats.append({"worst": 0})
	_next_battle()


func _next_battle() -> void:
	if battle != null:
		battle.queue_free()
		battle = null
	var p := Game.player
	p.hp = p.max_hp()
	p.br = p.max_br()
	hp_at_start = p.hp
	turns = 0
	watchdog = 0.0
	battle = BATTLE.instantiate()
	add_child(battle)
	# every fight gets its own seed, derived from the region and the fight number,
	# so the same fight is the same fight on every run
	battle.rng.seed = SOAK_SEED + plan_i * 10007 + fought
	Game.player.rng.seed = SOAK_SEED + plan_i * 7919 + fought
	battle.finished.connect(_on_finished)
	battle.begin(plan[plan_i].region, "", "")


func _on_finished(result: String) -> void:
	if result == "win":
		region_wins += 1
	else:
		region_losses += 1
	region_turns += turns
	region_hp_lost += maxi(0, hp_at_start - Game.player.hp)
	if turns > stats[plan_i].worst:
		stats[plan_i].worst = turns
	Game.level_queue.clear()
	fought += 1
	if fought >= PER_REGION:
		_report_region()
		plan_i += 1
		_begin_region()
	else:
		call_deferred("_next_battle")


func _report_region() -> void:
	var r: Dictionary = plan[plan_i]
	var avg_turns := float(region_turns) / float(maxi(1, fought))
	var avg_hp := float(region_hp_lost) / float(maxi(1, fought))
	print("%-9s %-4d %-7d %d/%-8d %-11.1f %-13.0f %d" % [
		r.region, r.lv, fought, region_wins, region_losses,
		avg_turns, avg_hp, stats[plan_i].worst])
	# A region you are the right level for should be winnable most of the time.
	# Note the soak player never drinks a tonic, so these are pessimistic.
	var win_rate := float(region_wins) / float(maxi(1, fought))
	_expect(win_rate >= 0.7,
		"%s at Lv%d is winnable (%d/%d)" % [r.region, r.lv, region_wins, fought])
	_expect(stats[plan_i].worst < MAX_TURNS,
		"%s: longest fight was %d turns" % [r.region, stats[plan_i].worst])

	# ...and it should still cost something. A region that takes 5% of your
	# health is not an encounter, it is a speed bump, and nothing else in the
	# suite would ever notice it had quietly become one.
	var hp_frac := avg_hp / float(maxi(1, Game.player.max_hp()))
	_expect(hp_frac > 0.12,
		"%s costs real health (%.0f%% of max per fight)" % [r.region, hp_frac * 100.0])
	_expect(avg_turns >= 1.6,
		"%s fights last more than a swing (%.1f turns)" % [r.region, avg_turns])


## Stand in for a player: cast the best damage song affordable, else swing.
func _decide() -> void:
	var p := Game.player
	var best := {}
	for s in p.song_book():
		if s.get("kind", "") != "dmg":
			continue
		if p.br < s.cost:
			continue
		if best.is_empty() or float(s.get("pow", 0)) > float(best.get("pow", 0)):
			best = s
	if not best.is_empty() and battle.alive().size() > 0:
		battle.do_song(best, 0)
	else:
		var a: Array = battle.alive()
		if a.size() > 0:
			battle.do_strike(a[0])


func _process(dt: float) -> void:
	if battle == null:
		return
	watchdog += dt
	if watchdog > 60.0:
		print("  FAIL watchdog: %s fight stuck in phase '%s' after %d turns (alive %d, hp %d, wait %.2f)"
			% [plan[plan_i].region, battle.phase, turns, battle.alive().size(),
			   Game.player.hp, battle.wait_t])
		failures += 1
		watchdog = 0.0
		_on_finished("hung")
		return
	if battle.phase == "command":
		turns += 1
		if turns > MAX_TURNS:
			print("  FAIL %s fight exceeded %d turns" % [plan[plan_i].region, MAX_TURNS])
			failures += 1
			_on_finished("hung")
			return
		_decide()
	elif battle.phase == "victory" or battle.phase == "defeat":
		# Skip the reward screen the way a player pressing Z would. Mark this
		# battle done BEFORE emitting: the handler starts the next fight
		# synchronously, so after the emit `battle` is a different object and
		# writing to it stamps "done" on a fight that has not begun.
		var b: Node2D = battle
		var res := "win" if b.phase == "victory" else "lose"
		b.phase_t = 99.0
		b.phase = "done"
		b.finished.emit(res)


func _finish() -> void:
	Engine.time_scale = 1.0
	print("")
	print("FAILURES: %d" % failures if failures > 0 else "PLAYTHROUGH SOAK PASSED")
	get_tree().quit(1 if failures > 0 else 0)
