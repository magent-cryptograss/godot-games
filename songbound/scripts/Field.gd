extends Node2D
## Walking around: map rendering, grid movement, NPCs, chests, warps, dialogue
## and random encounters.

signal encounter(region: String)
signal boss_encounter(id: String, flag: String)
signal open_shop(list: Array)
signal open_inn(price: int)
signal open_menu

const TS := 48
const MOVE_TIME := 0.15
const MSG_ROWS := 4
const MSG_PX := 280

## Encounter tuning, kept as named constants so tests/TestEncounters.tscn can
## measure the real numbers instead of a copy of them.
const ENCOUNTER_SCALE := 0.38
const ENCOUNTER_GRACE := 14

var map: Maps.GameMap = null
var pos := Vector2i(0, 0)
var target := Vector2i(0, 0)
var offset := Vector2.ZERO
var facing := "down"
var walking := false
var move_t := 0.0
var frame := 0
var steps := 0
var enc_cool := 8
var t := 0.0
var rng := RandomNumberGenerator.new()

var banner := ""                   # place name, shown briefly on arrival
var banner_t := 0.0
var playing := ""                  # tune name, shown briefly when it changes
var playing_t := 0.0

var msg = null                     # {lines, i, tick, npc, on_done}
var repeat_t := {}
var _was_ok := false


func enter(map_id: String, at: Vector2i = Vector2i(-1, -1), dir: String = "down") -> void:
	map = World.build_all()[map_id]
	Game.map_id = map_id
	pos = at if at.x >= 0 else map.start
	target = pos
	offset = Vector2.ZERO
	facing = dir
	walking = false
	# grace after a fight or a doorway, so you are never jumped twice in a row
	enc_cool = ENCOUNTER_GRACE
	Game.tile_pos = pos

	# A place with a name says it once on arrival. In a world this size, "which
	# town is this" is otherwise a question with no way to answer it.
	var pname := Guide.place_name(map_id)
	if pname != "" and pname != banner:
		banner = pname
		banner_t = 2.6
	elif pname == "":
		banner = ""
		banner_t = 0.0

	# what the goal chain reads to know the player has been out of town, and
	# where the map draws "you are here" from
	if map_id == "world":
		Game.world_pos = pos
		if Game.player != null:
			Game.player.flags["seen_world"] = true

	update_music()
	queue_redraw()


## The tune for where the player is standing.
##
## On the overworld this is the region under their feet rather than the map's
## own setting: the overworld is one map with three bands of country in it, and
## the tune should change as you climb out of the meadows into the crags.
## Audio.play_music ignores a request for whatever is already playing, so this is
## safe to call on every step.
func update_music() -> void:
	if map == null:
		return
	var want: String = map.music
	if map.id == "world":
		var rid := map.region_at(pos.x, pos.y)
		if Data.REGIONS.has(rid):
			want = str(Data.REGIONS[rid].get("music", want))
	if want == Audio.current_music():
		return
	Audio.play_music(want)
	var t := Tunes.title_of(want)
	if t != "":
		playing = t
		playing_t = 4.2


func say(lines: Array, on_done = null, npc = null) -> void:
	msg = {
		"lines": PixelFont.paginate(lines, MSG_PX, MSG_ROWS),
		"i": 0, "tick": 0.0, "npc": npc, "on_done": on_done,
	}


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


func _process(dt: float) -> void:
	if banner_t > 0.0:
		banner_t = maxf(0.0, banner_t - dt)
		queue_redraw()
	if playing_t > 0.0:
		playing_t = maxf(0.0, playing_t - dt)
		queue_redraw()
	t += dt
	if map == null:
		return
	if msg != null:
		_update_msg(dt)
		queue_redraw()
		return

	if Input.is_action_just_pressed("ui_menu"):
		open_menu.emit()
		return

	if not walking:
		var nd := ""
		for d in ["up", "down", "left", "right"]:
			if Input.is_action_pressed("move_" + d):
				nd = d
				break
		# A quick tap can have its press and release land between two frames, so
		# fall back to the just_pressed edge and still move one tile.
		if nd == "":
			for d in ["up", "down", "left", "right"]:
				if Input.is_action_just_pressed("move_" + d):
					nd = d
					break
		if nd != "":
			facing = nd
			var f := _facing_tile()
			var wp = map.warp_at(f.x, f.y)
			if map.can_walk(f.x, f.y, Game.player.flags) or wp != null:
				walking = true
				move_t = 0.0
				target = f
		if Input.is_action_just_pressed("ui_ok"):
			if not _interact():
				_try_warp(map.warp_at(pos.x, pos.y))

	if walking:
		move_t += dt
		var f := clampf(move_t / MOVE_TIME, 0.0, 1.0)
		offset = Vector2(target - pos) * f * TS
		frame = int(move_t / (MOVE_TIME / 4.0)) % 4
		if f >= 1.0:
			pos = target
			offset = Vector2.ZERO
			walking = false
			steps += 1
			Game.steps += 1
			Game.tile_pos = pos
			if map.id == "world":
				Game.world_pos = pos
				update_music()
			var wp = map.warp_at(pos.x, pos.y)
			if wp != null:
				_try_warp(wp)
				return
			_check_boss()
			if msg == null:
				_check_encounter()
	else:
		frame = 0

	for n in map.npcs:
		if not n.get("wander", false):
			continue
		n["wt"] = n.get("wt", 0.0) + dt
		if n.wt > 2.2:
			n["wt"] = 0.0
			n["dir"] = ["up", "down", "left", "right"][rng.randi() % 4]
	queue_redraw()


func _facing_tile() -> Vector2i:
	match facing:
		"left": return pos + Vector2i(-1, 0)
		"right": return pos + Vector2i(1, 0)
		"up": return pos + Vector2i(0, -1)
		_: return pos + Vector2i(0, 1)


func _opposite(d: String) -> String:
	match d:
		"up": return "down"
		"down": return "up"
		"left": return "right"
		_: return "left"


func _interact() -> bool:
	var f := _facing_tile()
	for n in map.npcs:
		if n.x == f.x and n.y == f.y:
			if not n.get("sign", false) and n.has("dir"):
				n["dir"] = _opposite(facing)
			# NPCs placed in the map editor carry a key, not the words themselves
			var lines: Array = n.get("lines", [])
			if lines.is_empty() and n.has("lines_key"):
				lines = Story.lines_for(str(n.lines_key))
			say(lines, null, n)
			return true
	for c in map.chests:
		if c.x == f.x and c.y == f.y and not Game.player.flags.get("chest_" + c.id, false):
			Game.player.flags["chest_" + c.id] = true
			Game.player.items[c.item] = Game.player.items.get(c.item, 0) + 1
			say(["You found " + Data.item_name(c.item) + "."])
			return true
	match map.get_tile(f.x, f.y):
		"w": say(Story.WELL); return true
		"g": say(Story.GRAVE); return true
		"b": say(Story.BED); return true
	return false


func _try_warp(wp) -> bool:
	if wp == null:
		return false
	if wp.has("need_flag") and not Game.player.flags.get(wp.need_flag, false):
		say([wp.blocked])
		return true
	enter(wp.to, Vector2i(wp.tx, wp.ty), facing)
	return true


func _check_boss() -> void:
	if map.boss == null:
		return
	if Game.player.flags.get("boss_" + map.boss.flag, false):
		return
	var d := absi(map.boss.x - pos.x) + absi(map.boss.y - pos.y)
	if d <= 1:
		var b = map.boss
		say(b.intro, func() -> void: boss_encounter.emit(b.id, b.flag))


func _check_encounter() -> void:
	var rid := map.region_at(pos.x, pos.y)
	if rid == "" or not Data.REGIONS.has(rid):
		return
	if enc_cool > 0:
		enc_cool -= 1
		return
	var wgt := Maps.enc_weight(map.get_tile(pos.x, pos.y))
	if wgt == 0:
		return
	if rng.randf() < Data.REGIONS[rid].rate * wgt * ENCOUNTER_SCALE:
		encounter.emit(rid)


# ---------------------------------------------------------------- message --

func _update_msg(dt: float) -> void:
	msg.tick += dt
	var full: String = msg.lines[msg.i]
	var shown := int(msg.tick / 0.014)
	var ok := Input.is_action_just_pressed("ui_ok")
	if ok:
		if shown < full.length():
			msg.tick = full.length() * 0.014 + 0.01
		else:
			msg.i += 1
			msg.tick = 0.0
			if msg.i >= msg.lines.size():
				var m = msg
				msg = null
				if m.on_done != null:
					m.on_done.call()
				elif m.npc != null and m.npc.has("shop"):
					open_shop.emit(m.npc.shop)
				elif m.npc != null and m.npc.has("inn"):
					open_inn.emit(m.npc.inn)


# ------------------------------------------------------------------- draw --

func camera() -> Vector2:
	var p := Vector2(pos) * TS + offset
	var cx := p.x + TS / 2.0 - UI.SCREEN_W / 2.0
	var cy := p.y + TS / 2.0 - UI.SCREEN_H / 2.0
	if map.w * TS <= UI.SCREEN_W:
		cx = (map.w * TS - UI.SCREEN_W) / 2.0
	else:
		cx = clampf(cx, 0, map.w * TS - UI.SCREEN_W)
	if map.h * TS <= UI.SCREEN_H:
		cy = (map.h * TS - UI.SCREEN_H) / 2.0
	else:
		cy = clampf(cy, 0, map.h * TS - UI.SCREEN_H)
	return Vector2(round(cx), round(cy))


func _draw() -> void:
	if map == null:
		return
	var cam := camera()
	draw_rect(Rect2(0, 0, UI.SCREEN_W, UI.SCREEN_H), Color.BLACK, true)
	_draw_tiles(cam)
	_draw_water(cam)

	for c in map.chests:
		var sx: float = c.x * TS - cam.x
		var sy: float = c.y * TS - cam.y
		if sx < -TS or sy < -TS or sx > UI.SCREEN_W or sy > UI.SCREEN_H:
			continue
		_draw_chest(sx, sy, Game.player.flags.get("chest_" + c.id, false))

	# depth-sort everything that stands up, so sprites overlap correctly
	var list := []
	for n in map.npcs:
		if n.get("sign", false):
			continue
		list.append({"y": float(n.y), "kind": "npc", "ref": n})
	if map.boss != null and not Game.player.flags.get("boss_" + map.boss.flag, false):
		list.append({"y": float(map.boss.y), "kind": "boss", "ref": map.boss})
	list.append({"y": float(pos.y), "kind": "player", "ref": null})

	# Everything that stands up joins the sort. It has already been drawn once
	# in the tile pass, so the ground under it is right; drawing it again here
	# is what puts it in front of anybody standing further from the camera.
	# Only rows at or below the highest character can ever occlude one, so the
	# rest are not worth queueing.
	var top_row: int = pos.y
	for item in list:
		top_row = mini(top_row, int(item.y))
	var tex := Maps.textures()
	var x0 := int(floor(cam.x / TS))
	var y0 := int(floor(cam.y / TS))
	for ty in range(y0, y0 + int(UI.SCREEN_H / TS) + 2):
		for tx in range(x0, x0 + int(UI.SCREEN_W / TS) + 2):
			var tch := map.get_tile(tx, ty)
			# An overhanging tile is drawn here and nowhere else, so it is always
			# queued. The rest only matter where they could cover somebody, which
			# is at or below the highest character on screen.
			if Maps.overhang(tch) > 0 or (Maps.is_tall(tch) and ty >= top_row):
				# half a row back, so a tile on the same row as you is behind you
				# rather than painted over your face. Something only occludes you
				# if its base is nearer the camera than yours, not level with it.
				list.append({"y": float(ty) - 0.5, "kind": "tile", "tx": tx, "ty": ty})
	list.sort_custom(func(a, b): return a.y < b.y)
	for item in list:
		match item.kind:
			"tile":
				var ch2 := map.get_tile(item.tx, item.ty)
				# A door you are standing at stands open: the panel goes dark and
				# a little of the light inside falls out across the step. A door
				# that never opens is a picture of a door painted on a wall.
				if ch2 == "d":
					var near: int = absi(item.tx - pos.x) + absi(item.ty - pos.y)
					if near <= 1:
						var dx0: float = float(item.tx) * TS - cam.x
						var dy0: float = float(item.ty) * TS - cam.y
						UI.rect(self, dx0 + 9, dy0 + 15, 30, 33, Color("#160f14"))
						UI.rect(self, dx0 + 9, dy0 + 15, 30, 3, Color("#0b0709"))
						UI.rect(self, dx0 + 11, dy0 + 40, 26, 8, Color("#3a2a1c"))
						for gi in 5:
							UI.rect(self, dx0 + 12 + gi * 5, dy0 + 44 - gi, 4, 4,
								Color(0.98, 0.86, 0.55, 0.16 - gi * 0.02))
				var over := Maps.overhang(ch2)
				if over > 0:
					var tall: Array = Maps.tall_textures().get(ch2, [])
					if not tall.is_empty():
						draw_texture_rect(tall[Maps.variant_of(item.tx, item.ty, tall.size())],
							Rect2(item.tx * TS - cam.x, item.ty * TS - cam.y - over,
								TS, TS + over), false)
				else:
					var arr2: Array = tex.get(ch2, [])
					if not arr2.is_empty():
						draw_texture_rect(arr2[Maps.variant_of(item.tx, item.ty, arr2.size())],
							Rect2(item.tx * TS - cam.x, item.ty * TS - cam.y, TS, TS), false)
			"npc":
				var n = item.ref
				var g := Sprites.build(Sprites.NPC_LOOKS.get(n.get("look", "woman"), Sprites.NPC_LOOKS.woman))
				var d: String = n.get("dir", "down")
				var gd: PackedByteArray = g
				if d == "up":
					gd = Sprites.back_view(g)
				elif d == "left":
					gd = Sprites.mirrored(Sprites.side_view(g))
				elif d == "right":
					gd = Sprites.side_view(g)
				var nlook := UI.FACE_FRONT
				if d == "left":
					nlook = UI.FACE_LEFT
				elif d == "right":
					nlook = UI.FACE_RIGHT
				# gd is already the correct-facing drawing, so it must not be
				# flipped again on top of that
				UI.sprite(self, gd,
					n.x * TS - cam.x, n.y * TS - cam.y - 24, 1, false,
					false, 0, null, nlook, _light_at(n.x, n.y))
			"boss":
				var b = item.ref
				Bestiary.draw_art(self, Data.BESTIARY[b.id].art,
					b.x * TS - cam.x - 14, b.y * TS - cam.y - 22, t)
			"player":
				var p := Game.player
				# a 48x72 sprite is exactly a tile wide and half a tile taller,
				# so it hangs above the tile and the feet still sit on it
				var px := pos.x * TS + offset.x - cam.x
				var py := pos.y * TS + offset.y - cam.y - 24
				UI.shadow(self, px + 12, py + 31, 7, 2)
				# each facing is its own drawing now, so nothing is flipped here
				var look := UI.FACE_FRONT
				if facing == "left":
					look = UI.FACE_LEFT
				elif facing == "right":
					look = UI.FACE_RIGHT
				# A frame the player drew is used exactly as drawn; one they did
				# not falls back to shifting the standing picture, which is how
				# every walk worked before there were frames to draw.
				var drawn: PackedByteArray = p.walk_grid(facing, frame) if walking \
					else PackedByteArray()
				if drawn.size() > 0:
					UI.sprite(self, drawn, px, py, 1, false, false, 0, null, look,
						_light_at(pos.x, pos.y))
					_draw_grass_over(px, py, cam)
				else:
					UI.sprite(self, p.view(facing), px, py, 1, false, walking, frame,
						null, look, _light_at(pos.x, pos.y))
				_draw_grass_over(px, py, cam)

	if _is_cave():
		_draw_cave_light(cam)
	elif map.indoor:
		for i in 26:
			var a := (1.0 - float(i) / 26.0) * 0.5
			UI.rect(self, 0, i, UI.SCREEN_W, 1, Color(0, 0, 0, a))
			UI.rect(self, 0, UI.SCREEN_H - 1 - i, UI.SCREEN_W, 1, Color(0, 0, 0, a))

	_draw_hud()
	if msg != null:
		_draw_msg()


## Draw only the tiles the camera can see, plus the terrain edges. This is a
## few hundred draws a frame and, unlike a composed texture, does not care how
## big the world is.
func _draw_tiles(cam: Vector2) -> void:
	var tex := Maps.textures()
	var x0 := int(floor(cam.x / TS))
	var y0 := int(floor(cam.y / TS))
	var cols := int(UI.SCREEN_W / TS) + 2
	var rows := int(UI.SCREEN_H / TS) + 2
	for ty in range(y0, y0 + rows):
		for tx in range(x0, x0 + cols):
			var ch := map.get_tile(tx, ty)
			# a tree's square is ground; the tree itself is drawn later, taller,
			# so that anything walking the row above passes behind its crown
			if Maps.overhang(ch) > 0:
				ch = "."
			var arr: Array = tex.get(ch, tex.get(".", []))
			if arr.is_empty():
				continue
			var sx := tx * TS - cam.x
			var sy := ty * TS - cam.y
			draw_texture_rect(arr[Maps.variant_of(tx, ty, arr.size())],
				Rect2(sx, sy, TS, TS), false)
			_blend_edges(tx, ty, sx, sy, ch)
			# only real high ground: a lone boulder standing on grass has no
			# cliff face, and giving it one cuts a grey wall across the lawn
			if ch == "^":
				_draw_cliff(tx, ty, sx, sy, ch)
			_tile_edges(tx, ty, sx, sy, ch)


## The front of a tall-grass square, drawn over whoever is standing in it, so
## they are in the grass rather than on top of it. Only the near blades: the
## whole tile drawn over a figure would bury them.
func _draw_grass_over(px: float, py: float, cam: Vector2) -> void:
	# the square the soles are in, and any the figure straddles mid-step
	var foot_y: float = py + float(Sprites.H) - 5.0
	var ty := int(floor((foot_y + cam.y) / float(TS)))
	var first := int(floor((px + cam.x) / float(TS)))
	var last := int(floor((px + float(Sprites.W) - 1.0 + cam.x) / float(TS)))
	for tx in range(first, last + 1):
		if map.get_tile(tx, ty) != ",":
			continue
		var bx0: float = float(tx * TS) - cam.x
		var by0: float = float(ty * TS) - cam.y
		for i in 24:
			var h := Maps.hash2(tx * 7 + i, ty * 3 + i)
			var bh: float = 18.0 + Maps.hash2(tx + i, ty * 9 + i) * 13.0
			var sway := sin(t * 1.6 + h * 8.0) * 1.3
			var bx: float = bx0 + 1.0 + h * float(TS - 3) + sway
			var top: float = by0 + float(TS) - bh
			UI.rect(self, bx, top, 2, bh, Color("#2a4f2e"))
			UI.rect(self, bx, top, 2, 6, Color("#46764a"))
			UI.rect(self, bx, top, 2, 3, Color("#5f9663"))
			UI.rect(self, bx, top, 1, 2, Color("#74ad75"))


## The light where somebody is standing: cool and a little darker if something
## tall is throwing a shadow across that square. The same rule the ground uses,
## so a figure and the ground they stand on agree about where the shade is.
func _light_at(tx: int, ty: int) -> Color:
	if Maps.is_tall(map.get_tile(tx, ty - 1)) or Maps.is_tall(map.get_tile(tx - 1, ty)):
		return Color(0.74, 0.78, 0.92)
	return Color(1, 1, 1)


## Contact shadow under anything solid, bright rim where water meets land. The
## same two effects that used to be baked into the composed image.
## Let the neighbouring ground reach over the edge into this tile, so terrains
## meet on a ragged line rather than on the tile boundary. Depth comes from the
## position hash, so it is irregular but never changes between frames.
func _blend_edges(tx: int, ty: int, sx: float, sy: float, ch: String) -> void:
	var mine: int = Maps.BLEND_RANK.get(ch, -1)
	if mine < 0:
		return
	for side in 4:
		var nx := tx + (1 if side == 0 else (-1 if side == 1 else 0))
		var ny := ty + (1 if side == 2 else (-1 if side == 3 else 0))
		var nch := map.get_tile(nx, ny)
		if nch == ch:
			continue
		var theirs: int = Maps.BLEND_RANK.get(nch, -1)
		if theirs <= mine:
			continue
		var col := Color(str(Maps.BLEND_COL.get(nch, "#4a7a44")))
		for i in TS:
			# 0 to 3 pixels deep, and a quarter of the run left untouched so the
			# edge breaks up rather than becoming a neat second border
			var h := Maps.hash2(tx * 41 + i + side * 7, ty * 17 + side)
			if h < 0.26:
				continue
			var d := 1 + int(h * 3.0)
			match side:
				0: UI.rect(self, sx + TS - d, sy + i, d, 1, col)
				1: UI.rect(self, sx, sy + i, d, 1, col)
				2: UI.rect(self, sx + i, sy + TS - d, 1, d, col)
				3: UI.rect(self, sx + i, sy, 1, d, col)


## The vertical face on the lower edge of high ground. A mountain seen from
## straight above is a grey shape; the face is the part you would walk into, and
## it is what puts height into the country. Drawn only where the ground below is
## not also high, which is exactly where a cliff has one.
func _draw_cliff(tx: int, ty: int, sx: float, sy: float, ch: String) -> void:
	var below := map.get_tile(tx, ty + 1)
	if below == ch or Maps.is_tall(below):
		return
	var face := 18
	var top := sy + TS - face
	var rock := Color("#6b645a") if ch == "^" else Color("#5f5852")
	UI.rect(self, sx, top, TS, 2, rock.lightened(0.32))       # the lip catches light
	UI.rect(self, sx, top + 2, TS, face - 2, rock.darkened(0.18))
	# striations down the face, so it reads as rock rather than as a band
	for i in 7:
		var gx := sx + 2 + int(Maps.hash2(tx * 7 + i, ty) * float(TS - 6))
		var gh := 5 + int(Maps.hash2(tx, ty * 5 + i) * float(face - 7))
		UI.rect(self, gx, top + 3, 2, gh, rock.darkened(0.36))
		UI.rect(self, gx + 2, top + 3, 1, gh, rock.lightened(0.12))
	UI.rect(self, sx, sy + TS - 4, TS, 4, rock.darkened(0.5))  # dark at the foot
	UI.rect(self, sx, sy + TS - 1, TS, 1, Color(0, 0, 0, 0.45))


func _tile_edges(tx: int, ty: int, sx: float, sy: float, ch: String) -> void:
	if ch == "~":
		if map.get_tile(tx, ty - 1) != "~":
			UI.rect(self, sx, sy, TS, 1, Color(1, 1, 1, 0.30))
			UI.rect(self, sx, sy + 1, TS, 1, Color(1, 1, 1, 0.14))
		if map.get_tile(tx, ty + 1) != "~":
			UI.rect(self, sx, sy + TS - 1, TS, 1, Color(1, 1, 1, 0.16))
		if map.get_tile(tx - 1, ty) != "~":
			UI.rect(self, sx, sy, 1, TS, Color(1, 1, 1, 0.16))
		if map.get_tile(tx + 1, ty) != "~":
			UI.rect(self, sx + TS - 1, sy, 1, TS, Color(1, 1, 1, 0.16))
		return
	if Maps.is_solid(ch):
		return
	# A cast shadow rather than a contact line: the light is at the top left of
	# every tile, so what stands above and to the left of this ground throws
	# across it. This is most of what fixes an object to the floor instead of
	# leaving it sitting on top of a pattern.
	var above: bool = Maps.is_tall(map.get_tile(tx, ty - 1))
	var left: bool = Maps.is_tall(map.get_tile(tx - 1, ty))
	if above:
		for i in 10:
			UI.rect(self, sx + 3, sy + i, TS - 3, 1, Color(0, 0, 0, 0.34 - i * 0.032))
	if left:
		for i in 8:
			UI.rect(self, sx + i, sy + 3, 1, TS - 3, Color(0, 0, 0, 0.26 - i * 0.03))
	if above and left:
		# the corner takes both, and needs the darkest patch or the two shadows
		# meet in a suspiciously pale square
		UI.rect(self, sx, sy, 6, 6, Color(0, 0, 0, 0.18))
	if Maps.is_solid(map.get_tile(tx + 1, ty)):
		UI.rect(self, sx + TS - 2, sy, 2, TS, Color(0, 0, 0, 0.12))


## Water is baked into the map texture along with its shoreline, so this draws
## movement over the top rather than replacing the tile -- that keeps the rim
## where water meets land.
func _draw_water(cam: Vector2) -> void:
	var x0 := int(cam.x / TS) - 1
	var y0 := int(cam.y / TS) - 1
	var x1 := x0 + int(UI.SCREEN_W / TS) + 3
	var y1 := y0 + int(UI.SCREEN_H / TS) + 3
	for ty in range(maxi(0, y0), mini(map.h, y1)):
		for tx in range(maxi(0, x0), mini(map.w, x1)):
			if map.get_tile(tx, ty) != "~":
				continue
			var sx := tx * TS - cam.x
			var sy := ty * TS - cam.y

			# What stands on the bank, upside down in the water. Drawn in
			# horizontal slices so each one can be pushed sideways a little,
			# which is what makes it read as a reflection on moving water
			# rather than a second object hanging underneath the first.
			var above := map.get_tile(tx, ty - 1)
			if Maps.is_tall(above):
				var src: Array = Maps.tall_textures().get(above, Maps.textures().get(above, []))
				if not src.is_empty():
					var rt: Texture2D = src[Maps.variant_of(tx, ty - 1, src.size())]
					var sh := rt.get_height()
					for i in range(0, TS, 2):
						var wob := sin(t * 1.8 + float(i) * 0.22 + float(tx)) * 1.6
						var fade := 0.42 - float(i) / float(TS) * 0.3
						draw_texture_rect_region(rt,
							Rect2(sx + wob, sy + i, TS, 2),
							Rect2(0, sh - 2 - i, TS, 2),
							Color(0.55, 0.72, 0.95, fade))

			# two highlight bands drifting down the tile at different speeds,
			# offset per tile so the surface does not pulse as one sheet
			var off := Maps.hash2(tx, ty) * 16.0
			for k in 2:
				var speed := 5.0 + k * 3.0
				var band := fmod(t * speed + off + k * 9.0, 16.0)
				var col := Color(0.55, 0.78, 0.95, 0.16 if k == 0 else 0.10)
				UI.rect(self, sx, sy + band, TS, 1, col)

			# caustic glints, stepped so they twinkle rather than slide
			var step := int(t * 3.0)
			for i in 2:
				var h1 := Maps.hash2(tx * 7 + i, ty * 13 + step)
				if h1 < 0.55:
					continue
				var h2 := Maps.hash2(tx * 3 + step, ty * 5 + i)
				UI.rect(self, sx + int(h1 * 13.0), sy + int(h2 * 13.0), 2, 1,
					Color(0.85, 0.95, 1.0, 0.5))

			# foam breathing along the shore where water meets land above
			if map.get_tile(tx, ty - 1) != "~":
				var pulse: float = 0.25 + 0.2 * sin(t * 2.2 + tx * 0.7)
				UI.rect(self, sx, sy, TS, 1, Color(1, 1, 1, pulse))


func _is_cave() -> bool:
	return map != null and (map.region == "cave" or map.region == "deep")


## Darkness with holes cut in it. Light comes from whatever you are carrying and
## from the lit patches the map places, so a cave is a series of pools with dark
## between them rather than a uniformly dim room.
const LIGHT_CELL := 8

func _draw_cave_light(cam: Vector2) -> void:
	# gather what is giving off light: the player, plus any lit floor in view
	var lights: Array = []
	var flicker: float = 1.0 + sin(t * 7.3) * 0.035 + sin(t * 3.1) * 0.02
	lights.append({
		"x": pos.x * TS + offset.x - cam.x + TS * 0.5,
		"y": pos.y * TS + offset.y - cam.y + TS * 0.5,
		"r": 92.0 * flicker,
	})
	var x0 := int(cam.x / TS) - 1
	var y0 := int(cam.y / TS) - 1
	for ty in range(maxi(0, y0), mini(map.h, y0 + int(UI.SCREEN_H / TS) + 3)):
		for tx in range(maxi(0, x0), mini(map.w, x0 + int(UI.SCREEN_W / TS) + 3)):
			if map.get_tile(tx, ty) != "*":
				continue
			lights.append({
				"x": tx * TS - cam.x + TS * 0.5,
				"y": ty * TS - cam.y + TS * 0.5,
				"r": 58.0 + sin(t * 2.0 + tx) * 4.0,
			})
	# the boss is worth seeing coming
	if map.boss != null and not Game.player.flags.get("boss_" + map.boss.flag, false):
		lights.append({
			"x": map.boss.x * TS - cam.x + TS * 0.5,
			"y": map.boss.y * TS - cam.y + TS * 0.5,
			"r": 60.0 + sin(t * 1.4) * 6.0,
		})

	# 0.88 was atmospheric and unplayable -- you could not see far enough to
	# navigate. Enough ambient light to read the walls, dark enough to feel it.
	var dark := 0.66
	var cells_x := int(UI.SCREEN_W / LIGHT_CELL) + 1
	var cells_y := int(UI.SCREEN_H / LIGHT_CELL) + 1
	for cy in cells_y:
		for cx in cells_x:
			var px := cx * LIGHT_CELL + LIGHT_CELL * 0.5
			var py := cy * LIGHT_CELL + LIGHT_CELL * 0.5
			var best := 1.0
			for l in lights:
				var dx: float = px - l.x
				var dy: float = py - l.y
				# squashed vertically: the pool reads as light on a floor
				var d := sqrt(dx * dx + dy * dy * 1.7)
				var inner: float = l.r * 0.5
				var f: float = clampf((d - inner) / maxf(1.0, l.r - inner), 0.0, 1.0)
				if f < best:
					best = f
			if best <= 0.0:
				continue
			# quantise so the falloff steps rather than smears
			var a: float = round(best * 6.0) / 6.0 * dark
			UI.rect(self, cx * LIGHT_CELL, cy * LIGHT_CELL, LIGHT_CELL, LIGHT_CELL,
				Color(0.02, 0.01, 0.05, a))


func _draw_chest(x: float, y: float, opened: bool) -> void:
	if opened:
		UI.rect(self, x + 3, y + 9, 10, 5, Color("#5a3a1e"))
		UI.rect(self, x + 3, y + 9, 10, 1, Color("#8a6440"))
		UI.rect(self, x + 2, y + 4, 12, 4, Color("#7a5228"))
		UI.rect(self, x + 2, y + 4, 12, 1, Color("#a87a48"))
	else:
		UI.rect(self, x + 2, y + 6, 12, 8, Color("#7a5228"))
		UI.rect(self, x + 2, y + 6, 12, 3, Color("#a87a48"))
		UI.rect(self, x + 2, y + 9, 12, 1, Color("#5a3a1e"))
		UI.rect(self, x + 7, y + 9, 2, 3, Color("#f0d040"))


func _draw_hud() -> void:
	var p := Game.player
	UI.window(self, 4, 4, 96, 30, {"alpha": 0.8})
	PixelFont.draw(self, p.name, Vector2(10, 8))
	PixelFont.draw_right(self, "Lv%d" % p.lv, 96, 8, UI.COL_GOLD)
	UI.bar(self, 10, 18, 50, 4, float(p.hp) / float(p.max_hp()))
	PixelFont.draw(self, "%d/%d" % [p.hp, p.max_hp()], Vector2(64, 16), Color("#c8c0dc"))
	UI.bar(self, 10, 25, 50, 3, float(p.br) / float(p.max_br()), Color("#78b8f0"), Color("#2a5a9c"))

	if map.id == "world":
		_draw_compass()
	if banner_t > 0.0:
		_draw_banner()
	if playing_t > 0.0 and msg == null:
		_draw_now_playing()


## The name of the tune, bottom left, for a few seconds after it changes. These
## are real tunes that people still play, and a player who likes one should be
## able to find out what it is called.
func _draw_now_playing() -> void:
	var a: float = clampf(playing_t / 0.8, 0.0, 1.0)
	var label := "Now playing:  " + playing
	var w := PixelFont.width(label) + 16
	var y := UI.SCREEN_H - 20.0
	UI.rect(self, 6, y, w, 14, Color(0.05, 0.04, 0.09, 0.68 * a))
	UI.rect(self, 6, y, w, 1, Color(1, 1, 1, 0.13 * a))
	UI.rect(self, 6, y + 13, w, 1, Color(1, 1, 1, 0.13 * a))
	# a little note head, since there is no such glyph in the font
	UI.rect(self, 12, y + 8, 3, 2, Color(UI.COL_GOLD.r, UI.COL_GOLD.g, UI.COL_GOLD.b, a))
	UI.rect(self, 14, y + 3, 1, 6, Color(UI.COL_GOLD.r, UI.COL_GOLD.g, UI.COL_GOLD.b, a))
	PixelFont.draw(self, label, Vector2(20, y + 4),
		Color(0.85, 0.82, 0.92, a))


## A pointer to wherever the story is asking you to go, only on the overworld,
## where it is possible to be genuinely lost. It shows the direction rather than
## a route: there is a road, and following it is the game.
func _draw_compass() -> void:
	var goal := Guide.objective()
	if goal.map != "world":
		return
	var to: Vector2i = goal.at
	var d := Vector2(to.x - pos.x, to.y - pos.y)
	if d.length() < 4.0:
		return
	var cx := UI.SCREEN_W - 26.0
	var cy := 18.0
	UI.window(self, UI.SCREEN_W - 46, 4, 42, 30, {"alpha": 0.8})
	var a := d.normalized()
	var tip := Vector2(cx, cy) + a * 8.0
	var lft := Vector2(cx, cy) + a.rotated(2.5) * 6.0
	var rgt := Vector2(cx, cy) + a.rotated(-2.5) * 6.0
	draw_colored_polygon(PackedVector2Array([tip, lft, Vector2(cx, cy), rgt]), UI.COL_GOLD)
	var steps := absi(to.x - pos.x) + absi(to.y - pos.y)
	PixelFont.draw_centered(self, str(steps), int(cx), 26, Color("#c8c0dc"))


## The name of the place, fading out. Drawn at the top rather than the middle so
## it never sits over the character.
func _draw_banner() -> void:
	var a: float = clampf(banner_t / 0.6, 0.0, 1.0)
	var w := PixelFont.width(banner) + 20
	var x := (UI.SCREEN_W - w) / 2.0
	UI.rect(self, x, 40, w, 16, Color(0.05, 0.04, 0.09, 0.72 * a))
	UI.rect(self, x, 40, w, 1, Color(1, 1, 1, 0.16 * a))
	UI.rect(self, x, 55, w, 1, Color(1, 1, 1, 0.16 * a))
	PixelFont.draw_centered(self, banner, int(UI.SCREEN_W / 2), 44,
		Color(UI.COL_GOLD.r, UI.COL_GOLD.g, UI.COL_GOLD.b, a))


func _draw_msg() -> void:
	var bx := 8.0
	var by := UI.SCREEN_H - 66.0
	var bw := UI.SCREEN_W - 16.0
	var bh := 58.0
	UI.window(self, bx, by, bw, bh)
	var full: String = msg.lines[msg.i]
	var shown := full.substr(0, int(msg.tick / 0.014))
	var lines := PixelFont.wrap_text(shown, MSG_PX)
	for i in mini(lines.size(), MSG_ROWS):
		PixelFont.draw(self, lines[i], Vector2(bx + 12, by + 12 + i * 12))
	if int(msg.tick / 0.014) >= full.length():
		var bob := 0 if sin(t * 8.0) > 0.0 else 1
		UI.rect(self, bx + bw - 16, by + bh - 12 + bob, 5, 3, UI.COL_GOLD)
		UI.rect(self, bx + bw - 15, by + bh - 9 + bob, 3, 2, UI.COL_GOLD)
		UI.rect(self, bx + bw - 14, by + bh - 7 + bob, 1, 1, UI.COL_GOLD)
