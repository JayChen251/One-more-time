@tool
extends StaticBody2D
## A walkable ramp. The node's position is the bottom-left corner.
## Change `size` / `rises_right` in the Inspector and it redraws in the editor.
## Keep it at 45 degrees or flatter (height <= width): steeper slopes act like
## walls for the player.

@export var size := Vector2(256, 128):
	set(value):
		size = value
		if is_node_ready():
			_rebuild()
@export var rises_right := true:
	set(value):
		rises_right = value
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
	var low := Vector2(0, 0) if rises_right else Vector2(size.x, 0)
	var high := Vector2(size.x, -size.y) if rises_right else Vector2(0, -size.y)
	var points := PackedVector2Array([Vector2(0, 0), Vector2(size.x, 0), high])
	$CollisionPolygon2D.polygon = points
	$Fill.polygon = points
	$Fill.color = fill_color
	$Edge.points = PackedVector2Array([low, high])
	$Edge.default_color = edge_color
	update_configuration_warnings()


func _get_configuration_warnings() -> PackedStringArray:
	if size.y > size.x:
		return ["Steeper than 45 degrees: the player can't walk up this. Make height <= width."]
	return []
