@tool
extends Node2D
## A red alarm beacon mounted on a wall. main.gd sets `pulse` with every
## alarm beep; the light sweeps round and flares with it.

## Which way the beacon faces out of the wall (1 = right, -1 = left).
@export var facing := 1.0
var pulse := 0.0
var _t := 0.0


func _ready() -> void:
	add_to_group("beacons")
	_t = randf() * TAU


func _process(delta: float) -> void:
	_t += delta * 3.0
	pulse = maxf(pulse - delta * 2.5, 0.0)
	queue_redraw()


func _draw() -> void:
	# Housing and lamp.
	draw_rect(Rect2(Vector2(0 if facing > 0 else -8, -8), Vector2(8, 16)), Color(0.25, 0.25, 0.32))
	var lamp := Color(1.0, 0.2, 0.2, 0.5 + 0.5 * pulse)
	draw_rect(Rect2(Vector2(8 if facing > 0 else -16, -8), Vector2(8, 16)), lamp)
	if pulse <= 0.01:
		return
	# Sweeping cone of light.
	var origin := Vector2(12 * facing, 0)
	var angle := sin(_t) * 0.9
	var dir := Vector2(facing, 0).rotated(angle)
	var spread := 0.35
	var reach := 260.0
	var cone := PackedVector2Array([origin, origin + dir.rotated(-spread) * reach,
			origin + dir.rotated(spread) * reach])
	draw_colored_polygon(cone, Color(1.0, 0.15, 0.15, 0.18 * pulse))
	draw_circle(origin, 20.0, Color(1.0, 0.2, 0.2, 0.25 * pulse))
