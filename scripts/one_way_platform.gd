@tool
extends StaticBody2D
## A platform you can jump up through from below and then stand on.
## The node's position is the top-left corner.
## Change `size` in the Inspector and it redraws in the editor.
## Set `rise` to make it a one-way ramp: the right end is `rise` px higher
## than the left (negative = the left end is higher). Keep ramps at 45 degrees
## or flatter so they can be walked up. Ramps are drawn as stairs; the
## collision underneath is still a smooth slope.

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
@export var fill_color := Color(0.42, 0.46, 0.55):
	set(value):
		fill_color = value
		if is_node_ready():
			_rebuild()
@export var edge_color := Color(0.92, 0.95, 1.0):
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
	var top := _top_outline()
	var outline := top.duplicate()
	outline.append(Vector2(size.x, size.y - rise))
	outline.append(Vector2(0, size.y))
	$Fill.polygon = outline
	$Fill.color = fill_color
	$Edge.points = top
	$Edge.default_color = edge_color


const STEP_HEIGHT := 12.0


# The visible top edge: a straight line, or stairs for a ramp.
func _top_outline() -> PackedVector2Array:
	if is_zero_approx(rise):
		return PackedVector2Array([Vector2(0, 0), Vector2(size.x, 0)])
	var steps := maxi(2, roundi(absf(rise) / STEP_HEIGHT))
	var step_w := size.x / steps
	var points := PackedVector2Array()
	for i in steps:
		# Each step sits at the slope's height in the middle of the step.
		var y := -rise * (i + 0.5) / steps
		points.append(Vector2(i * step_w, y))
		points.append(Vector2((i + 1) * step_w, y))
	return points
