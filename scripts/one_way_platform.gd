@tool
extends StaticBody2D
## A platform you can jump up through from below and then stand on.
## The node's position is the top-left corner.
## Change `size` in the Inspector and it redraws in the editor.
## Set `rise` to make it a one-way ramp: the right end is `rise` px higher
## than the left (negative = the left end is higher). Keep ramps at 45 degrees
## or flatter so they can be walked up.

@export var size := Vector2(192, 12):
	set(value):
		size = value
		if is_node_ready():
			_rebuild()
@export var rise := 0.0:
	set(value):
		rise = value
		if is_node_ready():
			_rebuild()
@export var fill_color := Color(0.2, 0.22, 0.28):
	set(value):
		fill_color = value
		if is_node_ready():
			_rebuild()
@export var edge_color := Color(0.55, 0.6, 0.7):
	set(value):
		edge_color = value
		if is_node_ready():
			_rebuild()


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	var rect := PackedVector2Array([Vector2(0, 0), Vector2(size.x, -rise),
			Vector2(size.x, size.y - rise), Vector2(0, size.y)])
	# A polygon instead of a RectangleShape2D, so each platform owns its
	# collision data and resizing one doesn't resize every other instance.
	$CollisionPolygon2D.polygon = rect
	$Fill.polygon = rect
	$Fill.color = fill_color
	$Edge.points = PackedVector2Array([Vector2(0, 0), Vector2(size.x, -rise)])
	$Edge.default_color = edge_color
