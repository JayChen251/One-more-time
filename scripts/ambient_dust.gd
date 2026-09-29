extends Node2D
## Small white specks drifting through the air. Each one fades in, drifts
## for a few seconds, fades out and reappears somewhere else on screen.
## They live around whatever the camera shows, and draw behind the tiles so
## they only appear in open space.

@export var count := 160

var _specks: Array = []          # [position, velocity, size, phase, age, life]


func _ready() -> void:
	z_index = -1
	for i in count:
		var speck := _new_speck(_view())
		speck[4] = randf() * speck[5]        # start at a random point in its life
		_specks.append(speck)


func _new_speck(view: Rect2) -> Array:
	return [view.position + Vector2(randf() * view.size.x, randf() * view.size.y),
			Vector2(randf_range(-12, 12), randf_range(-30, -6)),
			4.0 if randf() < 0.75 else 8.0, randf() * TAU, 0.0, randf_range(2.0, 5.0)]


func _process(delta: float) -> void:
	var view := _view().grow(40)
	var t := Time.get_ticks_msec() * 0.001
	for i in _specks.size():
		var s: Array = _specks[i]
		s[4] += delta
		if s[4] >= s[5]:
			_specks[i] = _new_speck(view)
			continue
		var p: Vector2 = s[0] + s[1] * delta
		p.x += sin(t + s[3]) * 6.0 * delta
		# Wrap around the visible area.
		p.x = view.position.x + fposmod(p.x - view.position.x, view.size.x)
		p.y = view.position.y + fposmod(p.y - view.position.y, view.size.y)
		s[0] = p
	queue_redraw()


func _draw() -> void:
	for s in _specks:
		var fade := sin(PI * s[4] / s[5])        # 0 -> 1 -> 0 over its life
		var size: float = s[2]
		draw_rect(Rect2(to_local(s[0]), Vector2(size, size)), Color(1, 1, 1, 0.55 * fade))


func _view() -> Rect2:
	var camera := get_viewport().get_camera_2d()
	var size := get_viewport_rect().size
	if not camera:
		return Rect2(Vector2.ZERO, size)
	size /= camera.zoom
	return Rect2(camera.get_screen_center_position() - size / 2.0, size)
