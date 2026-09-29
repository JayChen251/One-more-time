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
	# Wall mount and a red dome lamp, in whole pixels (see Pal).
	var f := 1.0 if facing > 0 else -1.0
	Pal.plate(self, Rect2(Vector2(0.0 if f > 0 else -8.0, -12), Vector2(8, 24)))
	var dome := Vector2(12 * f, 0)
	Pal.circle(self, dome, 8.0, Pal.OUTLINE)
	Pal.circle(self, dome, 6.0, Pal.RED_DARK.lerp(Pal.RED, 0.4 + 0.6 * pulse))
	draw_rect(Rect2(dome + Vector2(-2 if f > 0 else 0, -4), Vector2(2, 2)), Color(1, 0.8, 0.8, 0.5 + 0.5 * pulse))
	if pulse <= 0.01:
		return
	# Sweeping cone of light.
	var origin := dome
	var angle := sin(_t) * 0.9
	var dir := Vector2(f, 0).rotated(angle)
	var spread := 0.35
	var reach := 260.0
	var cone := PackedVector2Array([origin, origin + dir.rotated(-spread) * reach,
			origin + dir.rotated(spread) * reach])
	draw_colored_polygon(cone, Color(1.0, 0.15, 0.15, 0.18 * pulse))
	Pal.circle(self, origin, 20.0, Color(1.0, 0.2, 0.2, 0.25 * pulse))
