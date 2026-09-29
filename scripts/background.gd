extends Node2D
## Parallax ship interior behind the level: two layers of dark pipes,
## girders and blinking lights that move slower than the camera. Drawn behind
## the tiles, so it only shows through open space.

# (parallax factor, pipe spacing, pipe colour, girder colour)
const LAYERS := [
	[0.3, 384.0, Color(0.07, 0.08, 0.15), Color(0.06, 0.07, 0.13)],
	[0.6, 256.0, Color(0.1, 0.11, 0.21), Color(0.09, 0.1, 0.19)],
]
const PX := 4.0                  # one screen pixel in world units


func _ready() -> void:
	z_index = -20


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var camera := get_viewport().get_camera_2d()
	if not camera:
		return
	var view_size := get_viewport_rect().size / camera.zoom
	var centre := camera.get_screen_center_position()
	var view := Rect2(centre - view_size / 2.0, view_size)
	var t := Time.get_ticks_msec() * 0.001
	for layer in LAYERS:
		var factor: float = layer[0]
		var spacing: float = layer[1]
		var pipe_color: Color = layer[2]
		var girder_color: Color = layer[3]
		# Positions in this layer, shifted so the layer moves at `factor` speed.
		var shift := centre * (1.0 - factor)
		var start_x := floorf((view.position.x - shift.x) / spacing) * spacing
		var x := start_x
		while x + shift.x < view.end.x + spacing:
			var wx := snappedf(x + shift.x, PX)
			draw_rect(Rect2(wx, view.position.y, 6 * PX, view.size.y), pipe_color)
			draw_rect(Rect2(wx + PX, view.position.y, PX, view.size.y), pipe_color.lightened(0.08))
			x += spacing
		var girder := spacing * 2.0
		var y := floorf((view.position.y - shift.y) / girder) * girder
		while y + shift.y < view.end.y + girder:
			var wy := snappedf(y + shift.y, PX)
			draw_rect(Rect2(view.position.x, wy, view.size.x, 3 * PX), girder_color)
			# A few status lights along each girder, blinking out of step.
			var lx := floorf((view.position.x - shift.x) / spacing) * spacing
			while lx + shift.x < view.end.x:
				var on := fmod(t * 0.7 + lx * 0.013 + y * 0.007, 2.0) < 1.2
				if on:
					draw_rect(Rect2(snappedf(lx + shift.x + spacing * 0.5, PX), wy + PX, PX, PX),
							Color(0.3, 0.6, 1.0, 0.5))
				lx += spacing
			y += girder
