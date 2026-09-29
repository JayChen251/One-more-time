@tool
class_name GrapplePoint
extends Node2D
## A spot the player can grapple to once "grapple" is unlocked.
## Among points in range (with a clear line to it), only those on the held
## sides (left/right, up/down) count and the farthest that way is auto-aimed
## (the nearest if nothing is held); pressing L zooms to it.
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


func _process(_delta: float) -> void:
	if state == State.AIMED:
		queue_redraw()


func _draw() -> void:
	if Engine.is_editor_hint():
		draw_arc(Vector2.ZERO, RANGE, 0.0, TAU, 64, Color(1, 0.6, 0.2, 0.25), 4.0)
	# A bolted anchor ring with a status light in the middle (see Pal).
	var light: Color
	match state:
		State.LOCKED:
			light = Pal.MID
		State.OUT_OF_RANGE:
			light = Pal.RED_DARK
		State.IN_RANGE:
			light = Pal.AMBER
		State.AIMED:
			light = Pal.HAZARD
	Pal.circle(self, Vector2.ZERO, 16.0, Pal.OUTLINE)
	Pal.circle(self, Vector2.ZERO, 14.0, Pal.STEEL)
	Pal.circle(self, Vector2.ZERO, 11.0, Pal.BODY)
	Pal.circle(self, Vector2.ZERO, 7.0, Pal.OUTLINE)
	Pal.circle(self, Vector2.ZERO, 5.0, light)
	draw_rect(Rect2(-4, -6, 2, 2), Color(1, 1, 1, 0.6 if state >= State.IN_RANGE else 0.2))
	for p in [Vector2(-12, -2), Vector2(10, -2), Vector2(-2, -12), Vector2(-2, 10)]:
		draw_rect(Rect2(p, Vector2(4, 4)), Pal.MID)
	if state >= State.IN_RANGE:
		Pal.circle(self, Vector2.ZERO, 22.0, Color(light, 0.12))
	if state == State.AIMED:
		# Target brackets closing in and out.
		var d := 24.0 + snappedf(sin(Time.get_ticks_msec() * 0.012) * 3.0, 2.0)
		for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			var at: Vector2 = corner * d
			var x0 := at.x if corner.x < 0 else at.x - 8.0
			var y0 := at.y if corner.y < 0 else at.y - 8.0
			draw_rect(Rect2(x0, at.y if corner.y < 0 else at.y - 2.0, 8, 2), Pal.HAZARD)
			draw_rect(Rect2(at.x if corner.x < 0 else at.x - 2.0, y0, 2, 8), Pal.HAZARD)
