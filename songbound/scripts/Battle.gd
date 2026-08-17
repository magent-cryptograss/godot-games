extends Node2D
## One player against up to three creatures. Turn order by speed.

signal finished(result: String)          # "win" | "lose" | "fled"

const CMDS := ["Strike", "Sing", "Item", "Flee"]

var enemies: Array = []
var region := "meadow"
var bg := "meadow"
var boss_id := ""
var boss_flag := ""

var phase := "intro"
var t := 0.0
var phase_t := 0.0
var wait_t := 0.0
var after_wait: Callable = Callable()

var cmd := 0
var sel := 0
var scroll := 0
var target := 0
var pending := {}

var order: Array = []
var turn := 0

var msg := ""
var pops: Array = []
var shake := 0.0
var p_status := {}

## Elements the player is charged with, from having been hit. Cleared once they
## have taken their next action -- being hit twice before acting stacks up the
## charges rather than replacing them.
var charged := {}

## How far through the drawn swing we are, or below zero for not swinging.
var atk_t := -1.0
const ATK_FRAME_TIME := 0.085
var p_flash := 0.0
var p_shake := 0.0
var fx := {}
var reward := {}

var rng := RandomNumberGenerator.new()
var repeat_t := {}
var _was_click := false


func begin(region_id: String, boss: String = "", flag: String = "") -> void:
	region = region_id
	var r: Dictionary = Data.REGIONS.get(region_id, Data.REGIONS.meadow)
	bg = r.bg
	boss_id = boss
	boss_flag = flag
	enemies.clear()
	if boss != "":
		enemies.append(Data.make_enemy(boss, 1.0))
	else:
		# The group grows with the player. Three enemies at level 1, against 55
		# health and a single song, is not a fight -- it is a coin toss, and it
		# was landing badly one time in twelve.
		var lv: int = Game.player.lv
		var p_two := 0.55 if lv >= 3 else 0.30
		var p_three := 0.20 if lv >= 5 else (0.06 if lv >= 3 else 0.0)
		var n := 1 + (1 if rng.randf() < p_two else 0) + (1 if rng.randf() < p_three else 0)
		for i in n:
			var id: String = r.mobs[rng.randi() % r.mobs.size()]
			enemies.append(Data.make_enemy(id, r.tier * (0.9 + rng.randf() * 0.25)))
	_layout()
	phase = "intro"
	t = 0.0
	phase_t = 0.0
	cmd = 0
	sel = 0
	scroll = 0
	target = 0
	pending = {}
	pops.clear()
	charged.clear()
	p_status.clear()
	shake = 0.0
	p_flash = 0.0
	p_shake = 0.0
	fx = {}
	reward = {}
	msg = ""
	Audio.play_music("boss" if boss != "" else "battle")
	Audio.sfx("encounter")


## The horizon, and the panel that carries the song and item lists. Written once
## here and referred to everywhere else, so the screen can be resized without
## hunting through eighty numbers again.
const HORIZON := 132
const LIST_X := 150.0
const LIST_Y := 214.0


func _layout() -> void:
	var n := enemies.size()
	for i in n:
		var e: Dictionary = enemies[i]
		# spread across the right of the field, staggered in depth so a row of
		# three does not read as a wall
		var w := float(UI.SCREEN_W)
		if n == 1:
			e["x"] = w * 0.56
			e["y"] = 88.0
		elif n == 2:
			e["x"] = w * 0.47 + i * 92
			e["y"] = 78.0 + i * 34
		else:
			e["x"] = w * 0.41 + i * 74
			e["y"] = 66.0 + (i % 2) * 44
		e["ax"] = 0.0
		e["flash"] = 0.0
		e["shk"] = 0.0
		e["fade"] = 1.0


func alive() -> Array:
	var out := []
	for e in enemies:
		if not e.dead:
			out.append(e)
	return out


# --------------------------------------------------------------- stat mods --

func _mod(bag: Dictionary, key: String) -> float:
	var m := 0.0
	for k in bag:
		var s: Dictionary = Data.STATUS.get(k, {})
		if s.has("mod") and s.mod.has(key):
			m += s.mod[key]
	return m

func p_atk() -> int: return roundi(Game.player.stat_atk() * (1.0 + _mod(p_status, "atk")))
func p_def() -> int: return roundi(Game.player.stat_def() * (1.0 + _mod(p_status, "def")))
func p_mus() -> int: return roundi(Game.player.stat_mus() * (1.0 + _mod(p_status, "mus")))
func p_spd() -> int: return roundi(Game.player.stat_spd() * (1.0 + _mod(p_status, "spd")))
func e_atk(e: Dictionary) -> int: return roundi(e.atk * (1.0 + _mod(e.st, "atk")))
func e_def(e: Dictionary) -> int: return roundi(e.def * (1.0 + _mod(e.st, "def")))
func e_spd(e: Dictionary) -> int: return roundi(e.spd * (1.0 + _mod(e.st, "spd")))


func pop(x: float, y: float, text: String, col: Color) -> void:
	pops.append({"x": x, "y": y, "text": text, "col": col, "t": 0.0, "vy": -0.6})


func apply_status(target_e, key: String, is_player: bool) -> void:
	var s: Dictionary = Data.STATUS.get(key, {})
	if s.is_empty():
		return
	if is_player:
		p_status[key] = s.turns
		pop(68, 128, s.name + "!", Color(s.col))
	else:
		target_e.st[key] = s.turns
		pop(target_e.x + 18, target_e.y, s.name + "!", Color(s.col))


func hurt_enemy(e: Dictionary, amount: int, col: Color) -> void:
	e.hp -= amount
	e["flash"] = 0.2
	e["shk"] = 0.26
	pop(e.x + 18, e.y + 8, str(amount), col)
	if e.hp <= 0:
		e.hp = 0
		e["dead"] = true


func hurt_player(amount: int) -> void:
	Game.player.hp = maxi(0, Game.player.hp - amount)
	p_flash = 0.22
	p_shake = 0.3
	shake = 8.0
	pop(68, 130, str(amount), Color("#ff8080"))


func heal_player(amount: int) -> void:
	var before := Game.player.hp
	Game.player.hp = mini(Game.player.max_hp(), Game.player.hp + amount)
	pop(68, 130, "+%d" % (Game.player.hp - before), UI.COL_GREEN)


## Begin the drawn swing, if there is one to play.
func _start_swing() -> void:
	if Game.player != null and Game.player.attack_count() > 0:
		atk_t = 0.0


## The picture to draw the player with right now.
func _player_grid() -> PackedByteArray:
	var p := Game.player
	if atk_t >= 0.0:
		var n := p.attack_count()
		if n > 0:
			var i := clampi(int(atk_t / ATK_FRAME_TIME), 0, n - 1)
			var a := p.attack_grid(i + 1)
			if a.size() > 0:
				return a
	return p.battle_grid()


func _keep_good(bag: Dictionary) -> Dictionary:
	var out := {}
	for k in bag:
		if Data.STATUS.get(k, {}).get("good", false):
			out[k] = bag[k]
	return out


# ------------------------------------------------------------------- turns --

func begin_round() -> void:
	order.clear()
	# is_p rather than comparing who against "p": who holds either a String or a
	# Dictionary, and Godot 4 refuses to compare those with != at all.
	order.append({"who": null, "is_p": true, "spd": p_spd() + rng.randf() * 3.0})
	for e in alive():
		order.append({"who": e, "is_p": false, "spd": e_spd(e) + rng.randf() * 3.0})
	order.sort_custom(func(a, b): return a.spd > b.spd)
	turn = 0
	next_turn()


func next_turn() -> void:
	if Game.player.hp <= 0:
		_end(false)
		return
	if alive().is_empty():
		_end(true)
		return
	while turn < order.size():
		var slot: Dictionary = order[turn]
		if not slot.is_p and slot.who.dead:
			turn += 1
			continue
		break
	if turn >= order.size():
		end_of_round()
		return
	var slot: Dictionary = order[turn]
	if slot.is_p:
		if p_status.has("stun"):
			set_msg("You cannot find the beat.")
			p_status.stun -= 1
			if p_status.stun <= 0:
				p_status.erase("stun")
			advance(0.7)
			return
		phase = "command"
		cmd = 0
	else:
		var e: Dictionary = slot.who
		if e.st.has("stun"):
			set_msg("%s is stunned." % e.name)
			e.st.stun -= 1
			if e.st.stun <= 0:
				e.st.erase("stun")
			advance(0.7)
			return
		enemy_act(e)


func advance(secs: float) -> void:
	phase = "wait"
	wait_t = secs
	after_wait = Callable()


func set_msg(s: String) -> void:
	msg = s


func end_of_round() -> void:
	for k in p_status.keys():
		var s: Dictionary = Data.STATUS[k]
		if s.has("dot"):
			hurt_player(maxi(1, roundi(Game.player.max_hp() * s.dot)))
		if s.has("regen"):
			heal_player(maxi(1, roundi(Game.player.max_hp() * s.regen)))
		p_status[k] -= 1
		if p_status[k] <= 0:
			p_status.erase(k)
	for e in alive():
		for k in e.st.keys():
			var s: Dictionary = Data.STATUS[k]
			if s.has("dot"):
				hurt_enemy(e, maxi(1, roundi(e.maxhp * s.dot)), Color(s.col))
			e.st[k] -= 1
			if e.st[k] <= 0:
				e.st.erase(k)
	if Game.player.hp <= 0:
		_end(false)
		return
	if alive().is_empty():
		_end(true)
		return
	phase = "wait"
	wait_t = 0.26
	after_wait = begin_round


# ------------------------------------------------------------ player moves --

func do_strike(e: Dictionary) -> void:
	charged.clear()
	var crit := rng.randf() < 0.08
	var d := Data.phys_damage(p_atk(), e_def(e), rng)
	if crit:
		d = roundi(d * 1.8)
	hurt_enemy(e, d, UI.COL_GOLD if crit else Color.WHITE)
	set_msg("A clean hit!" if crit else "You strike %s." % e.name)
	Audio.sfx("crit" if crit else "hit")
	fx = {"kind": "strike", "t": 0.0, "x": e.x + 18, "y": e.y + 16}
	_start_swing()
	advance(0.65)


func do_song(sd: Dictionary, idx: int) -> void:
	var p := Game.player
	if p.br < sd.cost:
		Audio.sfx("error")
		set_msg("Not enough breath.")
		phase = "command"
		return
	p.br -= sd.cost
	var el: Dictionary = Data.element(sd.elem)
	var aff: int = p.affinity.get(sd.elem, 0)
	# charged by having been hit: the song comes out stronger this once
	var boost := Data.CHARGE_MUL if charged.has(sd.elem) else 1.0
	if boost > 1.0:
		set_msg("%s plays %s, charged!" % [p.name, sd.name])
	Audio.play_song(sd.elem, Data.instrument(p.inst), str(sd.get("tune", "")))
	fx = {"kind": "song", "elem": sd.elem, "t": 0.0, "target": sd.target, "idx": idx}
	_start_swing()
	set_msg("%s plays %s!" % [p.name, sd.name])

	charged.clear()
	var hits: int = sd.get("hits", 1)
	match sd.kind:
		"dmg":
			var targets := alive() if sd.target == "all" else [_pick_target(idx)]
			var total := 0
			for e in targets:
				if e == null:
					continue
				var eff := Data.elem_effect(str(sd.elem), str(e.get("elem", "")))
				if eff != 1.0:
					Game.player.learn(str(e.get("id", "")), str(sd.elem), eff > 1.0)
				for i in hits:
					var d := Data.song_damage(p_mus(), sd.pow, e_def(e), aff, rng)
					d = maxi(1, roundi(float(d) * eff * boost))
					hurt_enemy(e, d, Color(el.col))
					total += d
				# say so, or a number quietly changing by a factor of two and a
				# half between fights reads as the game being unreliable
				if eff > 1.0:
					pop(e.x + 18, e.y - 4, "weak!", UI.COL_GOLD)
				elif eff < 1.0:
					pop(e.x + 18, e.y - 4, "resists", Color("#8880a0"))
				if sd.has("status") and rng.randf() < sd.get("schance", 0.5):
					apply_status(e, sd.status, false)
			if sd.has("drain"):
				heal_player(roundi(total * sd.drain))
		"heal":
			heal_player(roundi(Data.song_heal(p_mus(), sd.pow, aff) * boost))
			if sd.get("cure", false):
				p_status = _keep_good(p_status)
			if sd.has("status"):
				apply_status(null, sd.status, true)
			Audio.sfx("heal")
		"revive":
			heal_player(roundi(Game.player.max_hp() * sd.get("pow", 0.5)))
			Audio.sfx("heal")
		"buff":
			if sd.has("status"):
				apply_status(null, sd.status, true)
			if sd.has("extra"):
				apply_status(null, sd.extra, true)
			if sd.get("cure", false):
				p_status = _keep_good(p_status)
			Audio.sfx("buff")
		"debuff":
			var targets2 := alive() if sd.target == "all" else [_pick_target(idx)]
			for e in targets2:
				if e == null:
					continue
				apply_status(e, sd.status, false)
				if sd.has("extra"):
					apply_status(e, sd.extra, false)
			Audio.sfx("debuff")
	advance(0.88)


func _pick_target(idx: int):
	var a := alive()
	if a.is_empty():
		return null
	return a[clampi(idx, 0, a.size() - 1)]


func do_item(id: String) -> void:
	charged.clear()
	var p := Game.player
	if p.items.get(id, 0) <= 0:
		Audio.sfx("error")
		return
	var it: Dictionary = Data.ITEMS[id]
	p.items[id] -= 1
	if p.items[id] <= 0:
		p.items.erase(id)
	match it.kind:
		"heal", "healall":
			heal_player(it.pow)
			Audio.sfx("heal")
			set_msg("You use the %s." % it.name)
		"breath":
			p.br = mini(p.max_br(), p.br + it.pow)
			pop(68, 122, "+%d" % it.pow, UI.COL_BLUE)
			Audio.sfx("heal")
			set_msg("Breath returns.")
		"relic":
			p.grow[it.stat] += it.pow
			if it.stat == "hp":
				p.hp = mini(p.max_hp(), p.hp + it.pow)
			Audio.sfx("buff")
			set_msg("%s is yours for good." % it.name)
		"cure":
			p_status = _keep_good(p_status)
			Audio.sfx("buff")
			set_msg("You feel clearer.")
		"revive":
			heal_player(roundi(p.max_hp() * 0.5))
			Audio.sfx("heal")
			set_msg("New strings. New wind.")
		"escape":
			if boss_id != "":
				set_msg("Not from this one.")
			else:
				Audio.sfx("flee")
				set_msg("You slip away.")
				phase = "wait"
				wait_t = 0.7
				after_wait = func() -> void: _end("fled")
				return
	advance(0.65)


func do_flee() -> void:
	if boss_id != "":
		set_msg("There is no leaving this.")
		advance(0.7)
		return
	if rng.randf() < 0.35 + p_spd() * 0.012:
		Audio.sfx("flee")
		set_msg("You get clear.")
		phase = "wait"
		wait_t = 0.65
		after_wait = func() -> void: _end("fled")
	else:
		set_msg("You cannot break away!")
		advance(0.7)


# ---------------------------------------------------------------- enemy AI --

func enemy_act(e: Dictionary) -> void:
	phase = "enemyturn"
	var skills: Array = e.skills
	var sk: Dictionary = skills[rng.randi() % skills.size()]
	if sk.has("heal") and e.hp > e.maxhp * 0.5:
		sk = skills[0]
	if sk.has("heal"):
		var amt := roundi(e.maxhp * sk.heal)
		e.hp = mini(e.maxhp, e.hp + amt)
		pop(e.x + 18, e.y + 8, "+%d" % amt, UI.COL_GREEN)
		set_msg("%s mends itself." % e.name)
		Audio.sfx("heal")
		advance(0.7)
		return
	set_msg("%s uses %s." % [e.name, sk.name])
	e["ax"] = -10.0
	var total := 0
	for i in sk.get("hits", 1):
		var d := Data.enemy_damage(e_atk(e) * sk.get("pow", 1.0), p_def(), rng)
		hurt_player(d)
		total += d
	if sk.has("drain"):
		var h := roundi(total * sk.drain)
		e.hp = mini(e.maxhp, e.hp + h)
		pop(e.x + 18, e.y + 8, "+%d" % h, UI.COL_GREEN)
	if sk.has("status") and rng.randf() < sk.get("chance", 0.4):
		apply_status(null, sk.status, true)
	# what you get for having taken it. The damage above landed in full.
	for elem in Data.charges_from(str(e.get("elem", ""))):
		charged[elem] = true
	Audio.sfx("hit")
	advance(0.76)


# ------------------------------------------------------------------- ending --

func _end(result) -> void:
	if typeof(result) == TYPE_STRING and result == "fled":
		phase = "done"
		finished.emit("fled")
		return
	if not result:
		phase = "defeat"
		phase_t = 0.0
		Audio.stop_music()
		Audio.sfx("down")
		return
	var xp := 0
	var gold := 0
	for e in enemies:
		xp += e.xp
		gold += e.gold
	Game.player.gold += gold
	var levels := Game.award_xp(xp)
	if boss_flag != "":
		Game.player.flags["boss_" + boss_flag] = true
		if boss_flag == "quiet":
			Game.pending_ending = true
	reward = {"xp": xp, "gold": gold, "levels": levels}
	phase = "victory"
	phase_t = 0.0
	Audio.play_music("victory")


# ------------------------------------------------------------------ update --

func repeated(action: String, dt: float) -> bool:
	if Input.is_action_just_pressed(action):
		repeat_t[action] = 0.0
		return true
	if Input.is_action_pressed(action):
		repeat_t[action] = repeat_t.get(action, 0.0) + dt
		if repeat_t[action] > 0.28:
			repeat_t[action] -= 0.11
			return true
	else:
		repeat_t[action] = 0.0
	return false


func _click() -> bool:
	var down := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var fired := down and not _was_click
	_was_click = down
	return fired


func hit_rect(x: float, y: float, w: float, h: float) -> bool:
	var m := get_local_mouse_position()
	return m.x >= x and m.y >= y and m.x < x + w and m.y < y + h


func _process(dt: float) -> void:
	t += dt
	phase_t += dt
	shake = maxf(0.0, shake - dt * 30.0)
	p_flash = maxf(0.0, p_flash - dt)
	p_shake = maxf(0.0, p_shake - dt)
	if atk_t >= 0.0:
		atk_t += dt
		if atk_t > Game.player.attack_count() * ATK_FRAME_TIME:
			atk_t = -1.0
	for e in enemies:
		e["flash"] = maxf(0.0, e.flash - dt)
		e["shk"] = maxf(0.0, e.shk - dt)
		if e.dead and e.fade > 0.0:
			e["fade"] = maxf(0.0, e.fade - dt * 2.0)
		e["ax"] = lerpf(e.ax, 0.0, minf(1.0, dt * 8.0))
	for p in pops:
		p.t += dt
		p.y += p.vy
		p.vy += dt * 9.0
	pops = pops.filter(func(p): return p.t < 0.9)
	if not fx.is_empty():
		fx.t += dt
		if fx.t > 0.7:
			fx = {}

	match phase:
		"intro":
			if phase_t > 0.62:
				phase = "wait"
				wait_t = 0.01
				after_wait = begin_round
		"wait":
			wait_t -= dt
			if wait_t <= 0.0:
				if after_wait.is_valid():
					var cb := after_wait
					after_wait = Callable()
					cb.call()
				else:
					turn += 1
					next_turn()
		"command": _up_command(dt)
		"songmenu": _up_songs(dt)
		"itemmenu": _up_items(dt)
		"target": _up_target(dt)
		"victory":
			if phase_t > 0.4 and (Input.is_action_just_pressed("ui_ok") or _click()):
				finished.emit("win")
		"defeat":
			if phase_t > 0.9 and (Input.is_action_just_pressed("ui_ok") or _click()):
				finished.emit("lose")
	queue_redraw()


func _up_command(dt: float) -> void:
	if repeated("move_up", dt): cmd = wrapi(cmd - 1, 0, 4)
	if repeated("move_down", dt): cmd = wrapi(cmd + 1, 0, 4)
	for i in 4:
		var x := 12 + (i % 2) * 40
		var y := 168 + int(i / 2) * 12
		if hit_rect(x - 4, y - 2, 40, 12):
			cmd = i
			if _click():
				_choose_cmd()
				return
	if Input.is_action_just_pressed("ui_ok"):
		_choose_cmd()


func _choose_cmd() -> void:
	Audio.sfx("confirm")
	match cmd:
		0:
			pending = {"kind": "strike"}
			_enter_target()
		1:
			if Game.player.songs.is_empty():
				Audio.sfx("error")
				set_msg("You know no songs yet.")
				return
			phase = "songmenu"
			sel = 0
			scroll = 0
		2:
			if Game.player.items.is_empty():
				Audio.sfx("error")
				set_msg("Your pack is empty.")
				return
			phase = "itemmenu"
			sel = 0
		3:
			do_flee()


func _enter_target() -> void:
	if alive().size() == 1:
		_resolve(0)
		return
	phase = "target"
	target = 0


func _resolve(idx: int) -> void:
	var p := pending
	pending = {}
	if p.is_empty():
		return
	if p.kind == "strike":
		var e = _pick_target(idx)
		if e != null:
			do_strike(e)
	elif p.kind == "song":
		do_song(p.song, idx)


func _up_target(dt: float) -> void:
	var a := alive()
	if repeated("move_left", dt) or repeated("move_up", dt):
		target = wrapi(target - 1, 0, a.size())
	if repeated("move_right", dt) or repeated("move_down", dt):
		target = wrapi(target + 1, 0, a.size())
	for i in a.size():
		if hit_rect(a[i].x, a[i].y, 44, 44):
			target = i
			if _click():
				_resolve(i)
				return
	if Input.is_action_just_pressed("ui_ok"):
		_resolve(target)
	elif Input.is_action_just_pressed("ui_back"):
		Audio.sfx("cancel")
		pending = {}
		phase = "command"


func _up_songs(dt: float) -> void:
	var songs := Game.player.song_book()
	if repeated("move_up", dt): sel = wrapi(sel - 1, 0, songs.size())
	if repeated("move_down", dt): sel = wrapi(sel + 1, 0, songs.size())
	scroll = clampi(scroll, maxi(0, sel - 5), sel)
	for i in mini(6, songs.size()):
		if hit_rect(94, 152 + i * 13, 150, 12):
			sel = scroll + i
			if _click():
				_pick_song(songs)
				return
	if Input.is_action_just_pressed("ui_ok"):
		_pick_song(songs)
	elif Input.is_action_just_pressed("ui_back"):
		Audio.sfx("cancel")
		phase = "command"


func _pick_song(songs: Array) -> void:
	var sd: Dictionary = songs[sel]
	if Game.player.br < sd.cost:
		Audio.sfx("error")
		set_msg("Not enough breath for that.")
		return
	Audio.sfx("confirm")
	var single: bool = sd.target == "one" and (sd.kind == "dmg" or sd.kind == "debuff")
	if single:
		pending = {"kind": "song", "song": sd}
		_enter_target()
	else:
		do_song(sd, 0)


func _up_items(dt: float) -> void:
	var ids := Game.player.items.keys()
	if ids.is_empty():
		phase = "command"
		return
	if repeated("move_up", dt): sel = wrapi(sel - 1, 0, ids.size())
	if repeated("move_down", dt): sel = wrapi(sel + 1, 0, ids.size())
	sel = clampi(sel, 0, ids.size() - 1)
	for i in mini(6, ids.size()):
		if hit_rect(94, 152 + i * 13, 150, 12):
			sel = i
			if _click():
				Audio.sfx("confirm")
				do_item(ids[sel])
				return
	if Input.is_action_just_pressed("ui_ok"):
		Audio.sfx("confirm")
		do_item(ids[sel])
	elif Input.is_action_just_pressed("ui_back"):
		Audio.sfx("cancel")
		phase = "command"


# -------------------------------------------------------------------- draw --

const BG_PALETTES := {
	"meadow": ["#7ab8e0", "#a8d8f0", "#4a8a5a", "#2e6a3e", "#1e4a2a"],
	"wood":   ["#3a5a7a", "#5a7a9a", "#2e5a3a", "#1e4028", "#14301c"],
	"crag":   ["#8a9ab8", "#b8c8dc", "#6a6a72", "#4a4a52", "#32323a"],
	"cave":   ["#241c2e", "#342a40", "#3a2e44", "#2c2234", "#1e1626"],
	"deep":   ["#1e1430", "#2c1e44", "#342448", "#241a36", "#181026"],
}


func _draw() -> void:
	var sh := (rng.randf() * 2.0 - 1.0) * shake if shake > 0.0 else 0.0
	draw_set_transform(Vector2(round(sh), 0), 0.0, Vector2.ONE)
	_draw_bg()
	_draw_enemies()
	_draw_player()
	if fx.get("kind", "") == "song":
		_draw_song_fx()
	elif fx.get("kind", "") == "strike":
		var k := clampf(fx.t / 0.22, 0.0, 1.0)
		if k < 1.0:
			for i in 3:
				draw_line(Vector2(fx.x - 16 + i * 4, fx.y - 14 + k * 22),
					Vector2(fx.x + 10 + i * 4, fx.y + 12 + k * 22),
					Color(1, 1, 1, 1.0 - k), 1.0)
	for p in pops:
		var a := clampf(1.0 - (p.t - 0.5) / 0.4, 0.0, 1.0)
		var c: Color = p.col
		c.a = a
		PixelFont.draw_centered(self, p.text, p.x, p.y, c, {"outline": Color(0.05, 0.04, 0.09, a)})
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_ui()


func _draw_bg() -> void:
	var pal: Array = BG_PALETTES.get(bg, BG_PALETTES.meadow)
	UI.vgrad(self, 0, 0, UI.SCREEN_W, HORIZON, Color(pal[1]), Color(pal[0]), 12)
	var drift := t * 11.0
	# two ridges at different speeds: the parallax is most of what reads as depth
	for x in UI.SCREEN_W:
		var hgt := 26.0 + sin((x + drift * 0.25) / 42.0) * 9.0 + sin((x + drift * 0.25) / 17.0) * 4.0
		UI.rect(self, x, 90 - hgt, 1, hgt, Color(pal[4]))
	for x in UI.SCREEN_W:
		var hgt := 16.0 + sin((x + drift * 0.6) / 26.0) * 7.0 + sin((x + drift * 0.6) / 11.0) * 3.0
		UI.rect(self, x, 96 - hgt, 1, hgt + 6, Color(pal[3]))
	UI.vgrad(self, 0, HORIZON + 6, UI.SCREEN_W, UI.SCREEN_H - HORIZON - 6,
		Color(pal[2]), Color(pal[4]), 10)
	for i in 90:
		var gx := Maps.hash2(i, 7) * UI.SCREEN_W
		var gy := 100 + Maps.hash2(i, 9) * (UI.SCREEN_H - 104)
		UI.rect(self, gx, gy, 1 + int(Maps.hash2(i, 11) * 2), 1, Color(pal[3] if i % 3 else pal[4]))
	if bg == "cave" or bg == "deep":
		for i in 14:
			var sx := Maps.hash2(i, 21) * UI.SCREEN_W
			var sl := 10 + int(Maps.hash2(i, 23) * 26)
			for k in sl:
				UI.rect(self, sx - (k >> 3), k, 2 + (k >> 3), 1, Color(0.16, 0.13, 0.21, 0.4))


func _draw_enemies() -> void:
	var intro := 1.0 - clampf(phase_t / 0.62, 0.0, 1.0) if phase == "intro" else 0.0
	for e in enemies:
		if e.dead and e.fade <= 0.0:
			continue
		var ex: float = e.x + e.ax + ((rng.randf() * 2.0 - 1.0) * 3.0 if e.shk > 0.0 else 0.0) + intro * UI.SCREEN_W * 0.4
		var ey: float = e.y
		if e.dead:
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		UI.shadow(self, ex + 18, ey + 34, 13, 3)
		Bestiary.draw_art(self, e.art, ex, ey, t)
		if e.flash > 0.0:
			# a white wash over the creature to read as a hit
			var a := clampf(e.flash / 0.2, 0.0, 1.0) * 0.7
			for yy in range(0, 40, 2):
				UI.rect(self, ex - 4, ey + yy, 48, 2, Color(1, 1, 1, a * 0.5))
		var sxp := ex
		for k in e.st:
			UI.rect(self, sxp, ey - 6, 4, 4, Color(Data.STATUS[k].col))
			sxp += 5
		if not e.dead:
			_draw_known(e, ex, ey)

	if phase == "target":
		var a := alive()
		if target < a.size():
			var e: Dictionary = a[target]
			var bob := sin(t * 6.0) * 2.0
			var cx0: float = e.x + 18
			var cy0: float = e.y - 14 + bob
			UI.rect(self, cx0 - 4, cy0, 9, 3, UI.COL_GOLD)
			UI.rect(self, cx0 - 3, cy0 + 3, 7, 2, UI.COL_GOLD)
			UI.rect(self, cx0 - 1, cy0 + 5, 3, 2, UI.COL_GOLD)
			PixelFont.draw_centered(self, e.name, e.x + 18, e.y - 26, UI.COL_GOLD, {"outline": UI.COL_INK})
			UI.bar(self, e.x - 2, e.y - 18, 40, 3, float(e.hp) / float(e.maxhp),
				Color("#f06848"), Color("#a01818"))


## The row of marks under a creature: one square per element the player has
## tried and got a reaction from, chevron up for weak and down for resisted.
func _draw_known(e: Dictionary, ex: float, ey: float) -> void:
	var known: Dictionary = Game.player.known_of(str(e.get("id", "")))
	if known.is_empty():
		return
	var n := known.size()
	var x := ex + 18.0 - (n * 9 - 2) / 2.0
	var y := ey + 40.0
	for elem in known:
		var weak: bool = bool(known[elem])
		var col := Color(Data.element(elem).col)
		UI.rect(self, x - 1, y - 1, 9, 9, Color(0.05, 0.04, 0.09, 0.75))
		UI.rect(self, x, y, 7, 7, col)
		UI.rect(self, x, y, 7, 2, col.lightened(0.35))
		# a chevron above for weak, below for resisted, so the two are told
		# apart by shape and not only by which way a colour leans
		var mark := UI.COL_GOLD if weak else Color("#8c96b4")
		if weak:
			UI.rect(self, x + 2, y - 4, 3, 1, mark)
			UI.rect(self, x + 1, y - 3, 5, 1, mark)
		else:
			UI.rect(self, x + 1, y + 8, 5, 1, mark)
			UI.rect(self, x + 2, y + 9, 3, 1, mark)
		x += 9


func _draw_player() -> void:
	var pxo := (rng.randf() * 2.0 - 1.0) * 2.0 if p_shake > 0.0 else 0.0
	# clear of the command window at y162 -- a 16x24 sprite at 2x is 48 tall,
	# so anything below about y110 ends up behind the menu
	var psx := UI.SCREEN_W * 0.14 + pxo
	var psy := UI.SCREEN_H * 0.42 + sin(t * 2.4) * 1.0
	UI.shadow(self, psx + 24, psy + 64, 18, 4)
	# a drawn attack frame is a pose in its own right, so it is not bobbed
	var pg := _player_grid()
	var swinging: bool = atk_t >= 0.0
	UI.sprite(self, pg, psx, psy, 2, false, not swinging, int(t * 5.0))
	if p_flash > 0.0:
		UI.sprite(self, pg, psx, psy, 2, false, false, 0,
			Color(1, 0.38, 0.38, clampf(p_flash / 0.22, 0.0, 1.0) * 0.6))


func _draw_song_fx() -> void:
	var el: Dictionary = Data.element(fx.elem)
	var k := clampf(fx.t / 0.7, 0.0, 1.0)
	var targets := alive() if fx.target == "all" else [_pick_target(fx.idx)]
	for i in 14:
		var d := k * 1.5 - i * 0.06
		if d < 0.0 or d > 1.0:
			continue
		for e in targets:
			if e == null:
				continue
			var xx: float = lerpf(84.0, e.x + 18, d)
			var yy: float = lerpf(128.0, e.y + 18, d) - sin(d * PI) * 34.0 + sin(i + t * 10.0) * 3.0
			UI.rect(self, xx, yy, 3, 3, Color(el.col) if i % 2 else Color(el.col2))
			UI.rect(self, xx + 2, yy - 4, 1, 5, Color(el.col))
	if k > 0.55:
		for e in targets:
			if e == null:
				continue
			var r := (k - 0.55) / 0.45
			var c := Color(el.col)
			c.a = 1.0 - r
			UI.pring(self, e.x + 18, e.y + 18, 6 + r * 26, c, 2)


func _draw_ui() -> void:
	var p := Game.player
	var bx := 8.0
	var by := float(UI.SCREEN_H) - 76.0
	UI.window(self, bx, by, 132, 68)
	PixelFont.draw(self, p.name, Vector2(bx + 8, by + 6))
	PixelFont.draw_right(self, "Lv%d" % p.lv, bx + 124, by + 6, UI.COL_GOLD)
	PixelFont.draw(self, "HP", Vector2(bx + 8, by + 24), Color("#9890b8"))
	UI.bar(self, bx + 28, by + 25, 60, 6, float(p.hp) / float(p.max_hp()))
	PixelFont.draw_right(self, str(p.hp), bx + 124, by + 22, Color("#d8d0e8"))
	PixelFont.draw(self, "BR", Vector2(bx + 8, by + 42), Color("#9890b8"))
	UI.bar(self, bx + 28, by + 43, 60, 6, float(p.br) / float(p.max_br()),
		Color("#78b8f0"), Color("#2a5a9c"))
	PixelFont.draw_right(self, str(p.br), bx + 124, by + 40, Color("#d8d0e8"))
	var sxp := bx + 8
	for k in p_status:
		UI.rect(self, sxp, by + 58, 5, 5, Color(Data.STATUS[k].col))
		sxp += 7

	if phase == "command" or phase == "target":
		var cy := by - 46.0
		UI.window(self, bx, cy, 132, 40)
		for i in 4:
			var x := bx + 6 + (i % 2) * 62
			var y := cy + 8 + int(i / 2) * 16
			var is_sel := i == cmd and phase == "command"
			PixelFont.draw(self, CMDS[i], Vector2(x + 6, y), UI.COL_GOLD if is_sel else Color("#c0b8d8"))
			if is_sel:
				UI.cursor(self, x - 2, y - 1, t)

	if phase == "songmenu":
		var songs := Game.player.song_book()
		UI.window(self, LIST_X, LIST_Y, UI.SCREEN_W - LIST_X - 8, 132)
		PixelFont.draw(self, "Songs", Vector2(LIST_X + 8, LIST_Y + 6), Color("#9890b8"))
		PixelFont.draw_right(self, "Breath %d" % p.br, UI.SCREEN_W - 16, LIST_Y + 6, UI.COL_BLUE)
		for i in mini(6, songs.size()):
			var idx := scroll + i
			if idx >= songs.size():
				break
			var s: Dictionary = songs[idx]
			var el: Dictionary = Data.element(s.elem)
			var y := LIST_Y + 22 + i * 16
			var is_sel := idx == sel
			if is_sel:
				UI.cursor(self, LIST_X + 6, y - 1, t)
			UI.rect(self, LIST_X + 16, y + 1, 5, 5, Color(el.col))
			if charged.has(s.elem):
				# a ring round the element dot: this one comes out stronger
				UI.pring(self, LIST_X + 18, y + 3, 5.0 + sin(t * 7.0), UI.COL_GOLD)
			var afford: bool = p.br >= s.cost
			var label: String = s.name + (" +%d" % s.upgraded if s.upgraded > 0 else "")
			PixelFont.draw(self, label, Vector2(LIST_X + 26, y),
				UI.COL_GOLD if is_sel else (Color("#d8d0e8") if afford else Color("#6a6480")))
			PixelFont.draw_right(self, str(s.cost), UI.SCREEN_W - 16, y,
				UI.COL_BLUE if afford else Color("#6a6480"))
		if songs.size() > 6:
			PixelFont.draw_right(self, "%d/%d" % [sel + 1, songs.size()],
				UI.SCREEN_W - 16, LIST_Y + 118, Color("#6a6480"))
		if sel < songs.size():
			PixelFont.draw(self, Data.describe_song(songs[sel]),
				Vector2(LIST_X + 8, LIST_Y + 116), Color("#9890b8"))

	if phase == "itemmenu":
		var ids := Game.player.items.keys()
		UI.window(self, LIST_X, LIST_Y, UI.SCREEN_W - LIST_X - 8, 132)
		PixelFont.draw(self, "Items", Vector2(LIST_X + 8, LIST_Y + 6), Color("#9890b8"))
		for i in mini(6, ids.size()):
			var y := LIST_Y + 22 + i * 16
			var is_sel := i == sel
			if is_sel:
				UI.cursor(self, LIST_X + 6, y - 1, t)
			PixelFont.draw(self, Data.item_name(ids[i]), Vector2(LIST_X + 20, y),
				UI.COL_GOLD if is_sel else Color("#d8d0e8"))
			PixelFont.draw_right(self, "x%d" % p.items[ids[i]], UI.SCREEN_W - 16, y,
				Color("#c0b8d8"))
		if sel < ids.size():
			PixelFont.draw(self, Data.ITEMS[ids[sel]].desc,
				Vector2(LIST_X + 8, LIST_Y + 116), Color("#9890b8"))

	if msg != "" and phase != "songmenu" and phase != "itemmenu":
		var mw := UI.SCREEN_W - LIST_X - 8
		UI.window(self, LIST_X, UI.SCREEN_H - 46, mw, 30, {"alpha": 0.85})
		PixelFont.draw(self, msg, Vector2(LIST_X + 10, UI.SCREEN_H - 37))

	if phase == "victory":
		UI.window(self, (UI.SCREEN_W - 260) / 2.0, 96, 260, 140)
		PixelFont.draw_centered(self, Story.VICTORY_LINE, 160, 80, UI.COL_GOLD, {"outline": UI.COL_INK})
		PixelFont.draw(self, "Experience", Vector2(84, 100), Color("#c0b8d8"))
		PixelFont.draw_right(self, str(reward.xp), 236, 100)
		PixelFont.draw(self, "Coin", Vector2(84, 114), Color("#c0b8d8"))
		PixelFont.draw_right(self, str(reward.gold), 236, 114)
		if reward.levels.size() > 0:
			PixelFont.draw_centered(self, "Level %d!" % reward.levels[reward.levels.size() - 1],
				160, 132, UI.COL_GREEN, {"outline": UI.COL_INK})
		PixelFont.draw_centered(self, "Z", 160, 150, UI.COL_FAINT)

	if phase == "defeat":
		UI.rect(self, 0, 0, UI.SCREEN_W, UI.SCREEN_H, Color(0, 0, 0, 0.7))
		PixelFont.draw_centered(self, Story.DEFEAT_LINE, 160, 110, Color("#c0b8d8"), {"outline": UI.COL_INK})
		if phase_t > 0.9:
			PixelFont.draw_centered(self, "Z", 160, 140, UI.COL_FAINT)
