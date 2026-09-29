extends Node2D
## The ship seen from outside: its hull tiles (the Tiles child) with lit
## windows. Hidden during play; the ending fades it in over the cutaway view
## as the camera pulls back, so you watch the whole ship from space.
## tools/build_level.py fills in the tiles and `windows` ([x, y, w, h]).

@export var windows: Array = []

const WARM := Color8(249, 198, 120)
const COLD := Color8(169, 215, 255)

var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	if visible:
		queue_redraw()


func _draw() -> void:
	for i in windows.size():
		var w: Array = windows[i]
		# Most windows glow steadily; a few flicker as power fails.
		var flicker := i % 7 == 0 and sin(_t * 17.0 + i) > 0.3
		if flicker:
			continue
		var color := COLD if i % 3 == 0 else WARM
		draw_rect(Rect2(w[0], w[1], w[2], w[3]), Pal.OUTLINE)
		draw_rect(Rect2(w[0] + Pal.PX, w[1] + Pal.PX, w[2] - 2 * Pal.PX, w[3] - 2 * Pal.PX), color)
