extends Node
## Headless parity check: re-runs the balance probe that tuned the HTML build
## against the ported Godot data, so any drift in the numbers shows up loudly.
##
## Runs as a scene rather than --script, because autoloads (Data, Game) are not
## loaded in --script mode.
##
##   godot --headless --path . res://tests/TestBalance.tscn

var failures := 0


func _ready() -> void:
	print("")
	print("== SONGBOUND data parity ==")
	check_tables()
	print("")
	print("Lv   HP    BR    ATK  DEF  MUS  sng  enemy            eHP    phys  song   taken   turns")
	for plan in [
		[1, "guitar", "fire", "meadow"], [5, "guitar", "fire", "meadow"],
		[10, "guitar", "fire", "wood"], [15, "banjo", "electric", "wood"],
		[20, "banjo", "electric", "crag"], [25, "dulcimer", "water", "crag"],
		[30, "dulcimer", "water", "cave"], [40, "fiddle", "wind", "cave"],
		[50, "fiddle", "wind", "deep"],
	]:
		row(plan[0], plan[1], plan[2], plan[3])

	print("")
	print("Boss check (casts to kill / hits survived)")
	for plan in [
		["gravebell", 14, "earth", "mixed"], ["gravebell", 14, "earth", "pure"],
		["conductor", 26, "dark", "mixed"], ["conductor", 26, "dark", "pure"],
		["quiet", 40, "fire", "mixed"], ["quiet", 40, "fire", "pure"],
	]:
		boss_row(plan[0], plan[1], plan[2], plan[3])

	print("")
	check_progression()
	check_sprites()
	check_save()

	print("")
	if failures == 0:
		print("ALL CHECKS PASSED")
	else:
		print("FAILURES: %d" % failures)
	get_tree().quit(1 if failures > 0 else 0)


func expect(cond: bool, what: String) -> void:
	if cond:
		print("  ok   %s" % what)
	else:
		print("  FAIL %s" % what)
		failures += 1


func check_tables() -> void:
	expect(Data.ELEMENTS.size() == 8, "8 elements")
	var total := 0
	for e in Data.ELEMENTS:
		var ladder = Data.SONGS.get(e.id, [])
		if ladder.size() != 8:
			expect(false, "%s ladder is %d, expected 8" % [e.id, ladder.size()])
		total += ladder.size()
	expect(total == 64, "64 songs total (got %d)" % total)
	expect(Data.INSTRUMENTS.size() == 8, "8 instruments")
	# every song must name a status that exists, or the battle code will crash
	var bad := 0
	for eid in Data.SONGS:
		for s in Data.SONGS[eid]:
			for key in ["status", "extra"]:
				if s.has(key) and not Data.STATUS.has(s[key]):
					print("    bad status %s in %s" % [s[key], s.name])
					bad += 1
	expect(bad == 0, "all song statuses resolve")
	# every enemy art name and element must resolve
	var bad_e := 0
	for id in Data.BESTIARY:
		var b = Data.BESTIARY[id]
		if b.elem != "" and Data.element(b.elem).id != b.elem:
			bad_e += 1
	expect(bad_e == 0, "all bestiary elements resolve")
	for rid in Data.REGIONS:
		for m in Data.REGIONS[rid].mobs:
			if not Data.BESTIARY.has(m):
				expect(false, "region %s references missing mob %s" % [rid, m])


func build_player(lv: int, inst: String, elem: String, mode: String) -> Player:
	var p := Player.new("Sim", inst, Sprites.build(Sprites.PRESETS[0].opts))
	p.rng.seed = 12345
	p.apply_level_choice(elem, 1)
	for l in range(2, lv + 1):
		p.lv = l
		var kind := elem if mode == "pure" else ("general" if l % 2 == 1 else elem)
		p.apply_level_choice(kind, l)
	return p


func best_damage_song(p: Player) -> Dictionary:
	var best := {}
	for s in p.song_book():
		if s.get("kind", "") != "dmg":
			continue
		if best.is_empty() or float(s.get("pow", 0)) > float(best.get("pow", 0)):
			best = s
	return best


func row(lv: int, inst: String, elem: String, region: String) -> void:
	var p := build_player(lv, inst, elem, "mixed")
	var r: Dictionary = Data.REGIONS[region]
	var e := Data.make_enemy(r.mobs[0], r.tier)
	var best := best_damage_song(p)
	var aff: int = p.affinity.get(best.get("elem", elem), 0)
	var phys := Data.phys_damage(p.stat_atk(), e.def)
	var song := 0
	if not best.is_empty():
		song = Data.song_damage(p.stat_mus(), best.pow, e.def, aff)
	var taken := Data.enemy_damage(e.atk, p.stat_def())
	var to_kill := int(ceil(float(e.maxhp) / float(maxi(1, maxi(song, phys)))))
	var to_die := int(ceil(float(p.max_hp()) / float(maxi(1, taken))))
	print("%-4d %-5d %-5d %-4d %-4d %-4d %-4d %-16s %-6d %-5d %-6d %-7d %d/%d" % [
		lv, p.max_hp(), p.max_br(), p.stat_atk(), p.stat_def(), p.stat_mus(),
		p.songs.size(), e.name, e.maxhp, phys, song, taken, to_kill, to_die])
	# a fight should never be over in one turn, nor take more than about fifteen
	if to_kill < 1 or to_kill > 20:
		expect(false, "Lv%d turns-to-kill %d is out of band" % [lv, to_kill])
	if to_die < 3:
		expect(false, "Lv%d dies in %d hits, too lethal" % [lv, to_die])


func boss_row(boss_id: String, lv: int, elem: String, mode: String) -> void:
	var p := build_player(lv, "guitar", elem, mode)
	var e := Data.make_enemy(boss_id, 1.0)
	var best := best_damage_song(p)
	var aff: int = p.affinity.get(best.get("elem", elem), 0)
	var hit := 0
	if not best.is_empty():
		hit = Data.song_damage(p.stat_mus(), best.pow, e.def, aff)
	else:
		hit = Data.phys_damage(p.stat_atk(), e.def)
	var taken := Data.enemy_damage(e.atk, p.stat_def())
	var casts := int(ceil(float(e.maxhp) / float(maxi(1, hit))))
	var survives := int(ceil(float(p.max_hp()) / float(maxi(1, taken))))
	print("  %-16s Lv%-4d %-6s songs %-3d hit %-6d taken %-5d %d / %d   %s" % [
		e.name, lv, mode, p.songs.size(), hit, taken, casts, survives, best.get("name", "-")])
	if casts > 30:
		expect(false, "%s takes %d casts, too spongy" % [boss_id, casts])


func check_progression() -> void:
	# the specialist must actually beat the generalist on their own element
	var pure := build_player(40, "guitar", "fire", "pure")
	var mixed := build_player(40, "guitar", "fire", "mixed")
	var e := Data.make_enemy("quiet", 1.0)
	var pb := best_damage_song(pure)
	var mb := best_damage_song(mixed)
	var ph := Data.song_damage(pure.stat_mus(), pb.pow, e.def, pure.affinity.fire)
	var mh := Data.song_damage(mixed.stat_mus(), mb.pow, e.def, mixed.affinity.fire)
	expect(pure.songs.size() == 8, "pure fire finishes the ladder by 40 (got %d)" % pure.songs.size())
	expect(ph > mh, "specialist out-damages generalist on their element (%d vs %d)" % [ph, mh])

	# songs are earned on the ELEMENT's level, not the character's
	var steps := []
	for l in range(1, 101):
		if Data.is_song_step(l):
			steps.append(l)
	expect(steps[0] == 1 and steps[1] == 5 and steps[2] == 10, "song steps start 1, 5, 10")
	expect(not Data.is_song_step(7) and not Data.is_song_step(99), "non-multiples teach nothing")
	expect(Data.next_song_step(1) == 5 and Data.next_song_step(6) == 10,
		"next song step is reported correctly")
	# all eight songs of one element take 35 picks of it
	expect(Data.song_step_for(7) == 35, "the eighth song sits at element level 35")

	# a character who never touches an element must never learn its songs
	var narrow := build_player(40, "guitar", "fire", "pure")
	expect(narrow.songs_of("water") == 0, "an untouched element teaches nothing")
	# one pick at level 1, then one per level from 2 to 40
	expect(narrow.affinity.fire == 40, "fire rose once per pick (got %d)" % narrow.affinity.fire)

	# a ladder that is finished starts upgrading instead of erroring
	var over := build_player(60, "guitar", "fire", "pure")
	expect(over.songs.size() == 8, "ladder caps at 8 songs")
	expect(over.upgrades.fire > 0, "further picks upgrade (got +%d)" % over.upgrades.fire)


func check_sprites() -> void:
	var s := Sprites.build(Sprites.PRESETS[1].opts)
	var lit := 0
	for i in s.size():
		if s[i] != 0:
			lit += 1
	expect(s.size() == Sprites.W * Sprites.H, "sprite grid is 16x24")
	expect(lit > 100, "preset sprite has %d filled pixels" % lit)
	var b := Sprites.back_view(s)
	expect(b.size() == s.size(), "back view same size")
	var diff := 0
	for i in s.size():
		if s[i] != b[i]:
			diff += 1
	expect(diff > 0, "back view differs from front (%d px)" % diff)
	var img := Sprites.to_image(s)
	expect(img != null and img.get_width() == 16, "sprite renders to an image")
	var outline := Sprites.build({"outlineOnly": true})
	var o_lit := 0
	for i in outline.size():
		if outline[i] != 0:
			o_lit += 1
	expect(o_lit > 20 and o_lit < lit, "outline template is a hollow guide (%d px)" % o_lit)


func check_save() -> void:
	var spr := Sprites.build(Sprites.PRESETS[3].opts)
	var p := Game.new_game("Rosalie", "dulcimer", spr, "water")
	p.apply_level_choice("water", 5)
	p.gold = 777
	p.items["tonic2"] = 4
	Game.map_id = "cave2"
	Game.tile_pos = Vector2i(6, 22)
	expect(Game.save_game(), "save writes")
	var before_lv := p.lv
	var before_songs := p.songs.size()
	var before_mus := p.stat_mus()
	Game.player = null
	expect(Game.load_game(), "save loads")
	expect(Game.player != null, "player restored")
	expect(Game.player.name == "Rosalie", "name survives round trip")
	expect(Game.player.gold == 777, "gold survives")
	expect(Game.player.lv == before_lv, "level survives")
	expect(Game.player.songs.size() == before_songs, "song book survives (%d)" % Game.player.songs.size())
	expect(Game.player.stat_mus() == before_mus, "stats recompute identically")
	expect(Game.player.spr == spr, "the drawn sprite survives the round trip")
	expect(Game.map_id == "cave2", "position survives")
	Game.erase_save()
