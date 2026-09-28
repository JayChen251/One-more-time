class_name DustPuff
extends Node2D
## A few pale squares kicked up from the floor (footsteps and landings).
## Use DustPuff.spawn(parent, global_position, direction, amount).

const DURATION := 0.4

var _t := 0.0
var _bits: Array = []            # [position, velocity, size]


## `direction` biases the puff sideways (-1 left, 1 right, 0 both ways).
static func spawn(parent: Node, at: Vector2, direction := 0.0, amount := 4) -> DustPuff:
	var puff := DustPuff.new()
	puff.z_index = 4
	for i in amount:
		var side := direction if direction != 0.0 else (1.0 if i % 2 == 0 else -1.0)
		puff._bits.append([Vector2(randf_range(-4, 4), 0),
				Vector2(side * randf_range(30, 110), randf_range(-70, -20)),
				randf_range(2.0, 4.0)])
	parent.add_child(puff)
	puff.global_position = at
	return puff


func _process(delta: float) -> void:
	_t += delta
	for b in _bits:
		var v: Vector2 = b[1]
		v *= 0.9
		v.y += 60.0 * delta
		b[1] = v
		b[0] = b[0] + v * delta
	if _t >= DURATION:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var fade := 1.0 - _t / DURATION
	for b in _bits:
		var size: float = b[2] * (0.6 + 0.4 * fade)
		draw_rect(Rect2(b[0] - Vector2.ONE * size / 2.0, Vector2(size, size)),
				Color(0.85, 0.87, 0.92, 0.7 * fade))
