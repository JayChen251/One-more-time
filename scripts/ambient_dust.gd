extends Node2D
## Small white specks drifting through the air. They live around whatever
## the camera shows (wrapping at the edges), and draw behind the tiles so
## they only appear in open space.

@export var count := 70

var _specks: Array = []          # [position, velocity, size, phase]


func _ready() -> void:
	z_index = -1
	var view := _view()
	for i in count:
		_specks.append([view.position + Vector2(randf() * view.size.x, randf() * view.size.y),
				Vector2(randf_range(-12, 12), randf_range(-28, -8)),
				2.0 if randf() < 0.75 else 3.0, randf() * TAU])


func _process(delta: float) -> void:
	var view := _view().grow(40)
	for s in _specks:
		var p: Vector2 = s[0] + s[1] * delta
		p.x += sin(Time.get_ticks_msec() * 0.001 + s[3]) * 6.0 * delta
		# Wrap around the visible area.
		p.x = view.position.x + fposmod(p.x - view.position.x, view.size.x)
		p.y = view.position.y + fposmod(p.y - view.position.y, view.size.y)
		s[0] = p
	queue_redraw()


func _draw() -> void:
	var t := Time.get_ticks_msec() * 0.001
	for s in _specks:
		var alpha := 0.25 + 0.3 * (0.5 + 0.5 * sin(t * 2.0 + s[3]))
		var size: float = s[2]
		draw_rect(Rect2(to_local(s[0]), Vector2(size, size)), Color(1, 1, 1, alpha))


func _view() -> Rect2:
	var camera := get_viewport().get_camera_2d()
	var size := get_viewport_rect().size
	if not camera:
		return Rect2(Vector2.ZERO, size)
	size /= camera.zoom
	return Rect2(camera.get_screen_center_position() - size / 2.0, size)
