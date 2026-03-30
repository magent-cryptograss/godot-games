extends SceneTree

func _initialize() -> void:
	print("Building Ralph the Wonder Llama...")

	var root := Node2D.new()
	root.name = "Main"
	root.set_script(load("res://scripts/game.gd"))

	set_owner_on_new_nodes(root, root)

	var count := count_nodes(root)
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err != OK:
		push_error("Pack failed")
		quit(1)
		return

	err = ResourceSaver.save(packed, "res://scenes/main.tscn")
	if err != OK:
		push_error("Save failed")
		quit(1)
		return

	print("BUILT: %d nodes" % count)
	quit(0)

func set_owner_on_new_nodes(node: Node, scene_owner: Node) -> void:
	for child in node.get_children():
		child.owner = scene_owner
		if child.scene_file_path.is_empty():
			set_owner_on_new_nodes(child, scene_owner)

func count_nodes(node: Node) -> int:
	var total := 1
	for child in node.get_children():
		total += count_nodes(child)
	return total
