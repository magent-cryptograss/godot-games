extends Node2D
## Frame timing on the big overworld.
##
## Drawing every visible tile each frame replaced a single pre-composed texture,
## which is what lets the world be 800x640 at all. That trade has to be paid for
## in frame time, so measure it rather than assume it is free.

var field: Node2D
var samples: Array[float] = []
var warmup := 20


func _ready() -> void:
	Game.new_game("Perf", "guitar", Sprites.build(Sprites.PRESETS[0].opts), "fire")
	field = preload("res://scenes/Field.tscn").instantiate()
	add_child(field)
	# out in open country, where the most tiles are visible
	field.enter("world", World.town_gate + Vector2i(10, -10))
	field.msg = null


func _process(dt: float) -> void:
	# walk so the camera keeps moving and nothing can be cached by accident
	field.pos.x += 1
	if field.pos.x > World.WORLD_W - 20:
		field.pos.x = 20
	field.queue_redraw()

	if warmup > 0:
		warmup -= 1
		return
	samples.append(dt)
	if samples.size() < 120:
		return

	var total := 0.0
	var worst := 0.0
	for v in samples:
		total += v
		worst = maxf(worst, v)
	var avg := total / samples.size()
	print("")
	print("== field performance, %dx%d world ==" % [World.WORLD_W, World.WORLD_H])
	print("  average frame: %.2f ms  (%.0f fps)" % [avg * 1000.0, 1.0 / avg])
	print("  worst frame:   %.2f ms" % [worst * 1000.0])
	var ok := avg < 0.020        # 50fps or better
	if ok:
		print("PERF PASSED")
	else:
		print("FAIL: average frame over 20ms")
	get_tree().quit(0 if ok else 1)
