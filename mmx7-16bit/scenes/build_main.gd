extends SceneTree
func _initialize() -> void:
	print("Building MMX7 16-bit...")
	var root = Node2D.new()
	root.name = "Main"
	root.set_script(load("res://scripts/game.gd"))
	var packed = PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, "res://scenes/main.tscn")
	print("BUILT")
	quit(0)
