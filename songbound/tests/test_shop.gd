extends Node2D
## Buys something from every shop in the game, the way a player would.
##
## There was already a shop test. It called Main._on_shop() directly and checked
## the screen appeared -- which tested the one link in the chain nobody doubted,
## and left the actual question, "can you walk up to a shopkeeper and press the
## button", untested in a game with six shops in it.
##
## So this one starts on the shop floor, walks to the keeper, presses the button,
## reads the dialogue to the end and buys the first thing on the list. Anything
## that breaks that chain -- an unreachable keeper, a counter in the way, a
## signal not connected, an empty stock -- fails here.

const OUT_DIR := "user://shots/"

var main: Node2D
var failures := 0
var shots := 0
var t := 0.0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	main = preload("res://scenes/Main.tscn").instantiate()
	add_child(main)
	main.set_process(false)
	Game.new_game("Wren", "fiddle", Sprites.build(Sprites.PRESETS[3].opts), "plant")


func _expect(cond: bool, what: String) -> void:
	if cond:
		print("  ok   %s" % what)
	else:
		print("  FAIL %s" % what)
		failures += 1


## Every map with a shopkeeper standing in it.
func _shop_maps() -> Array:
	var out: Array = []
	for id in World.build_all():
		var m: Maps.GameMap = World.build_all()[id]
		for n in m.npcs:
			if n.has("shop"):
				out.append([id, m, n])
				break
	return out


func _process(_dt: float) -> void:
	set_process(false)
	print("")
	print("== shops ==")

	var shops := _shop_maps()
	_expect(shops.size() >= 6, "every town has a shop (%d found)" % shops.size())

	for i in shops.size():
		var entry: Array = shops[i]
		var id: String = entry[0]
		var m: Maps.GameMap = entry[1]
		var keeper: Dictionary = entry[2]
		_try_shop(id, m, keeper)
		# leave the way a player leaves, except the last -- that one stays open
		# to be photographed
		if i < shops.size() - 1:
			main._close_shop()
			_expect(main.state == main.S.FIELD, "%s: X puts you back on the floor" % id)

	# a picture of the last one, left open, so the screen itself can be looked at
	if main.state == main.S.SHOP:
		main.set_process(true)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png(OUT_DIR + "shop-open.png")
		print("  (shot saved to %s)" % OUT_DIR)

	print("")
	if failures == 0:
		print("SHOPS PASSED")
	else:
		print("SHOPS FAILED: %d" % failures)
	get_tree().quit(0 if failures == 0 else 1)


## Stand where a player could stand, face the keeper, and buy something.
func _try_shop(id: String, m: Maps.GameMap, keeper: Dictionary) -> void:
	var stock: Array = keeper.get("shop", [])
	if stock.is_empty():
		_expect(false, "%s: the shopkeeper has nothing to sell" % id)
		return

	var spot := _spot_facing(m, Vector2i(int(keeper.x), int(keeper.y)))
	if spot.x < 0:
		_expect(false, "%s: nowhere a player can stand and face the shopkeeper" % id)
		return

	main._enter_field(id, spot)
	var field: Node2D = main.current
	field.set_process(false)
	field.facing = _dir_from(spot, Vector2i(int(keeper.x), int(keeper.y)))

	var talked: bool = field._interact()
	_expect(talked, "%s: pressing the button at the shopkeeper says something" % id)
	if not talked:
		return

	# read the dialogue through to the end, the way holding the button does
	var guard := 0
	while field.msg != null and guard < 400:
		field.advance()
		guard += 1
	_expect(main.state == main.S.SHOP,
		"%s: the shop opens when the shopkeeper finishes talking" % id)
	if main.state != main.S.SHOP:
		return

	_expect(main.shop_list.size() > 0, "%s: the shop has stock on the shelves" % id)

	# and buying works: coin goes down, the item goes in the bag
	var want: String = main.shop_list[0]
	var price: int = int(Data.ITEMS[want].price)
	Game.player.gold = price + 5
	var had: int = Game.player.items.get(want, 0)
	main.shop_sel = 0
	main._buy()
	_expect(Game.player.items.get(want, 0) == had + 1,
		"%s: buying puts the item in your bag" % id)
	_expect(Game.player.gold == 5, "%s: buying takes the coin" % id)

	shots += 1


## Somewhere the player can stand, from which the keeper is what they are facing.
## Beside them, or across the counter -- the same two ways the game allows.
func _spot_facing(m: Maps.GameMap, keeper: Vector2i) -> Vector2i:
	var r := _reachable(m)
	for step in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
		var beside: Vector2i = keeper + step
		if r.has(beside):
			return beside
		if m.get_tile(beside.x, beside.y) == "c" and r.has(beside + step):
			return beside + step
	return Vector2i(-1, -1)


func _dir_from(from: Vector2i, to: Vector2i) -> String:
	var d: Vector2i = to - from
	if absi(d.x) > absi(d.y):
		return "right" if d.x > 0 else "left"
	return "down" if d.y > 0 else "up"


## Where the player can actually walk, starting from where they come in.
func _reachable(m: Maps.GameMap) -> Dictionary:
	var seen := {}
	var stack: Array[Vector2i] = [m.start]
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		if p.x < 0 or p.y < 0 or p.x >= m.w or p.y >= m.h or seen.has(p):
			continue
		if Maps.is_solid(m.get_tile(p.x, p.y)):
			continue
		var blocked := false
		for n in m.npcs:
			if int(n.x) == p.x and int(n.y) == p.y:
				blocked = true
		if blocked:
			continue
		seen[p] = true
		for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			stack.append(p + step)
	return seen
