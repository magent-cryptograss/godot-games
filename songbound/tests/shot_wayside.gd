extends Node2D
## Photograph the wayside: one picture per kind of scene scattered across the
## overworld, taken where that scene actually ended up.
##
## The scenes are placed by a generator against a set of rules, which means
## nobody has ever seen most of them. Rules can be satisfied perfectly and still
## produce something that looks like a mistake -- an elliptical plateau passed
## every check it had and rendered as a scatter of grey slabs. So each kind gets
## its own frame, and the scene hunts for it rather than being pointed at a
## coordinate that will move the next time the seed changes.

const OUT_DIR := "user://shots/"

## One picture of each kind. Read off the register the generator keeps rather
## than hunted for by tile: the world had boulders in it long before anything
## arranged five of them in a ring, so "find an r" photographs a hillside.
const WANTED := ["well", "graves", "ruin", "paddock", "cairn", "camp",
	"orchard", "shrine", "picker", "pond", "fenceline", "stones", "flowers"]

const WAYSIDE := preload("res://scripts/Wayside.gd")

var field: Node2D
var shots := 0
var idx := 0
var frames := 0
var spots: Array = []


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	Game.new_game("Look", "fiddle", Sprites.build(Sprites.PRESETS[3].opts), "plant")
	World.build_all()
	field = preload("res://scenes/Field.tscn").instantiate()
	add_child(field)

	var m: Maps.GameMap = World.build_all()["world"]
	for want in WANTED:
		var at := _first(m, want)
		if at.x < 0:
			print("  NO %s PLACED" % want)
			continue
		spots.append([want, at])
	print("  %d of %d kinds to photograph" % [spots.size(), WANTED.size()])
	_go(0)


## Somewhere to stand to see one of these: a little south of the first one that
## was put down well away from any town.
func _first(m: Maps.GameMap, kind: String) -> Vector2i:
	for e in WAYSIDE.placed_at:
		if str(e.kind) != kind:
			continue
		var p: Vector2i = e.at
		var near := false
		for k in Places.sites:
			var g: Vector2i = Places.sites[k].gate
			if absi(g.x - p.x) + absi(g.y - p.y) < 30:
				near = true
				break
		if near:
			continue
		for dy in [4, 5, 3, 6]:
			var at := Vector2i(p.x, p.y + int(dy))
			if not Maps.is_solid(m.get_tile(at.x, at.y)):
				return at
	return Vector2i(-1, -1)


func _go(i: int) -> void:
	idx = i
	if i >= spots.size():
		print("SHOTS SAVED: %d" % shots)
		get_tree().quit()
		return
	var entry: Array = spots[i]
	field.enter("world", entry[1])
	field.msg = null
	frames = 0


func _process(_d: float) -> void:
	if idx >= spots.size():
		return
	frames += 1
	# a couple of frames to settle before the shutter, or the picture is of the
	# screen before this one
	if frames < 4:
		return
	var entry: Array = spots[idx]
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT_DIR + "wayside-%s.png" % entry[0])
	shots += 1
	_go(idx + 1)
