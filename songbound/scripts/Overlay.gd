extends Node2D
## A pane that draws on top of whatever scene is running.
##
## Main is the parent of the running scene, and in Godot a child draws over its
## parent. So anything Main paints itself while a scene is up -- the shop was the
## one that mattered -- is painted underneath it and cannot be seen at all. The
## title screen and the ending got away with it only because they clear the scene
## out first and have nothing in front of them.
##
## The menu already solved this by being a child node. This is the same solution
## for screens that are drawn rather than instantiated: hand it a painter, add it
## as a child, and it lands on top where it belongs.

var painter: Callable


func _ready() -> void:
	# Being the last child is not enough on its own: swap a new scene in while
	# this is up and the newcomer is added after it and lands on top again. An
	# explicit layer says "above the game" once, and keeps saying it.
	z_index = 100
	z_as_relative = false


func _process(_dt: float) -> void:
	queue_redraw()


func _draw() -> void:
	if painter.is_valid():
		painter.call(self)
