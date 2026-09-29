@tool
class_name GravLift
extends Area2D
## An anti-gravity column that slowly floats the player up. This is how the
## player climbs before they can jump. The node's position is the top-left
## corner. Put the top 16px above the floor the player should step off onto.

@export var size := Vector2(128, 256):
	set(value):
		size = value
		if is_node_ready():
			_rebuild()
## Upward speed in px/s. Slower lifts make ability shortcuts worth more.
@export var speed := 160.0

var _scroll := 0.0


func _ready() -> void:
	_rebuild()
	if Engine.is_editor_hint():
		return
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(delta: float) -> void:
	_scroll = fmod(_scroll + delta * speed * 0.5, 48.0)
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("enter_lift"):
		body.enter_lift(self)


func _on_body_exited(body: Node2D) -> void:
	if body.has_method("exit_lift"):
		body.exit_lift(self)


## Should this lift push `body` up right now? Not when the body is standing
## on a floor near the top of the lift, so walking over a lift's exit hatch
## doesn't bounce you.
func should_lift(body: Node2D) -> bool:
	var depth: float = body.call("get_foot_y") - global_position.y
	return not (body.call("is_on_floor") and depth < 32.0)


func _rebuild() -> void:
	$CollisionPolygon2D.polygon = PackedVector2Array(
			[Vector2(0, 0), Vector2(size.x, 0), size, Vector2(0, size.y)])
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.4, 1.0, 0.6, 0.12))
	# Chevrons scrolling upward.
	var y := size.y - _scroll
	while y > 8.0:
		var mid := size.x / 2.0
		draw_polyline(PackedVector2Array([
				Vector2(mid - 16, y + 8), Vector2(mid, y), Vector2(mid + 16, y + 8)]),
				Color(0.5, 1.0, 0.7, 0.5), 3.0)
		y -= 48.0
