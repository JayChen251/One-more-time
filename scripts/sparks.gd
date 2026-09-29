class_name Sparks
extends Node2D
## A quick burst of square sparks (double jump, teleport, grapple, unlocks,
## hatches). Use Sparks.spawn(parent, global_position, color, ...).

const DURATION := 0.45

var color := Color.WHITE
var _t := 0.0
var _sparks: Array = []          # [position, velocity, white?]


## `all_directions` sprays a full circle; otherwise downward and outward
## (like pushing off the air). `speed` scales how far they fly.
static func spawn(parent: Node, at: Vector2, spark_color: Color, amount := 16,
		all_directions := false, speed := 1.0) -> Sparks:
	var s := Sparks.new()
	s.color = spark_color
	s.z_index = 5
	for i in amount:
		var angle := randf() * TAU if all_directions else randf_range(0.15, PI - 0.15)
		s._sparks.append([Vector2.ZERO, Vector2.RIGHT.rotated(angle) * randf_range(120, 320) * speed,
				randf() < 0.4])
	parent.add_child(s)
	s.global_position = at
	return s


func _process(delta: float) -> void:
	_t += delta
	for s in _sparks:
		var v: Vector2 = s[1]
		v.y += 500.0 * delta
		v *= 0.92
		s[1] = v
		s[0] = s[0] + v * delta
	if _t >= DURATION:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var fade := 1.0 - _t / DURATION
	for s in _sparks:
		var c: Color = Color.WHITE if s[2] else color
		var size := 4.0 if fade < 0.5 else 8.0
		draw_rect(Rect2(s[0] - Vector2.ONE * size / 2.0, Vector2(size, size)), Color(c, fade))
