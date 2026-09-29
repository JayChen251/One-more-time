@tool
extends StaticBody2D
## A barrier that blocks walking, jumping and boosting, but can be teleported
## through. Lives on physics layer 2 ("force_field").
## The collision is a vertical line with no width, so there is nothing to
## stand on; the glowing band drawn around it is only visual.
## The node's position is the top end. Change `height` in the Inspector.

@export var height := 128.0:
	set(value):
		height = value
		if is_node_ready():
			_rebuild()
@export var color := Color(0.35, 0.9, 1.0):
	set(value):
		color = value
		queue_redraw()

const BAND := 24.0              # visual width of the field

var _time := 0.0


func _ready() -> void:
	_rebuild()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _rebuild() -> void:
	# A fresh shape per field, so resizing one doesn't resize the others.
	var segment := SegmentShape2D.new()
	segment.a = Vector2.ZERO
	segment.b = Vector2(0, height)
	$CollisionShape2D.shape = segment
	queue_redraw()


func _draw() -> void:
	var half := BAND / 2.0
	var shimmer := 0.85 + 0.15 * sin(_time * 7.0)
	# Soft band.
	draw_rect(Rect2(-half, 0, BAND, height), Color(color, 0.14 * shimmer))
	draw_rect(Rect2(-half / 2.0, 0, half, height), Color(color, 0.12 * shimmer))
	# Scanlines drifting upward.
	var spacing := 16.0
	var offset := fmod(_time * 40.0, spacing)
	var y := height - offset
	while y > 0.0:
		var wobble := sin(y * 0.15 + _time * 5.0) * 3.0
		draw_line(Vector2(-half + 4 + wobble, y), Vector2(half - 4 + wobble, y), Color(color, 0.3), 4.0)
		y -= spacing
	# Sparks travelling along the field.
	for i in 5:
		var t := fmod(_time * (0.5 + i * 0.13) + i * 0.37, 1.0)
		var sx := sin(_time * 3.0 + i * 1.7) * (half - 3)
		draw_rect(Rect2(sx - 2, t * height - 2, 4, 4), Color(color, 0.9))
	# Edges and bright core (the core is where the collision is).
	draw_line(Vector2(-half, 0), Vector2(-half, height), Color(color, 0.45 * shimmer), 4.0)
	draw_line(Vector2(half, 0), Vector2(half, height), Color(color, 0.45 * shimmer), 4.0)
	draw_line(Vector2(0, 0), Vector2(0, height), Color(color.lightened(0.5), shimmer), 4.0)
