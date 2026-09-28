@tool
extends StaticBody2D
## A barrier that blocks walking, jumping and boosting, but can be teleported
## through. Lives on physics layer 2 ("force_field").
## It is a vertical line with no width, so there is nothing to stand on.
## The node's position is the top end. Change `height` in the Inspector.

@export var height := 128.0:
	set(value):
		height = value
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
	$Glow.modulate.a = 0.6 + 0.25 * sin(_time * 9.0) + randf() * 0.15


func _rebuild() -> void:
	# A fresh shape per field, so resizing one doesn't resize the others.
	var segment := SegmentShape2D.new()
	segment.a = Vector2.ZERO
	segment.b = Vector2(0, height)
	$CollisionShape2D.shape = segment
	var line := PackedVector2Array([Vector2.ZERO, Vector2(0, height)])
	$Glow.points = line
	$Glow.default_color = Color(color, 0.35)
	$Core.points = line
	$Core.default_color = color
