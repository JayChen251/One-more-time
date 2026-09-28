@tool
class_name GrapplePoint
extends Node2D
## A spot the player can grapple to once "grapple" is unlocked.
## The nearest point in range (with a clear line to it) is auto-aimed,
## preferring points in the direction last pressed; pressing L zooms to it.
## In the editor the faint circle shows the grapple range.

## How close the player must be to use a point.
const RANGE := 440.0

enum State { LOCKED, OUT_OF_RANGE, IN_RANGE, AIMED }

var state := State.LOCKED:
	set(value):
		if value != state:
			state = value
			queue_redraw()


func _ready() -> void:
	add_to_group("grapple_points")


func _draw() -> void:
	if Engine.is_editor_hint():
		draw_arc(Vector2.ZERO, RANGE, 0.0, TAU, 64, Color(1, 0.6, 0.2, 0.25), 2.0)
	var color: Color
	match state:
		State.LOCKED:
			color = Color(0.5, 0.5, 0.5, 0.5)
		State.OUT_OF_RANGE:
			color = Color(1.0, 0.6, 0.2, 0.5)
		State.IN_RANGE:
			color = Color(1.0, 0.6, 0.2, 1.0)
		State.AIMED:
			color = Color(1.0, 1.0, 0.4, 1.0)
	draw_arc(Vector2.ZERO, 14.0, 0.0, TAU, 24, color, 3.0)
	draw_circle(Vector2.ZERO, 5.0, color)
	if state == State.AIMED:
		draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 24, color, 2.0)
