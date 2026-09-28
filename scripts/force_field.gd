@tool
extends StaticBody2D
## A barrier that blocks walking, jumping and boosting, but can be teleported
## through. Lives on physics layer 2 ("force_field").
## The node's position is the top-left corner. Resize with `size`.

@export var size := Vector2(32, 128):
	set(value):
		size = value
		if is_node_ready():
			_rebuild()
@export var color := Color(0.3, 0.85, 1.0):
	set(value):
		color = value
		if is_node_ready():
			_rebuild()

var _time := 0.0


func _ready() -> void:
	_rebuild()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	$Fill.color.a = 0.3 + 0.12 * sin(_time * 9.0) + randf() * 0.06


func _rebuild() -> void:
	var rect := PackedVector2Array([Vector2(0, 0), Vector2(size.x, 0), size, Vector2(0, size.y)])
	$CollisionPolygon2D.polygon = rect
	$Fill.polygon = rect
	$Fill.color = Color(color, 0.35)
	$Edge.points = PackedVector2Array([Vector2(0, 0), Vector2(0, size.y), size, Vector2(size.x, 0), Vector2(0, 0)])
	$Edge.default_color = color
