@tool
class_name AbilityIcons
## Shared drawing for ability icons, used by the unlock stations (Gate) and
## the HUD's ability bar so they always match.

## Icon colour per ability: jump green, teleport cyan (like force fields),
## double jump purple, grapple orange (like grapple points).
const COLORS := {
	"jump": Color(0.45, 1.0, 0.55),
	"teleport": Color(0.35, 0.9, 1.0),
	"boost": Color(0.8, 0.5, 1.0),
	"grapple": Color(1.0, 0.65, 0.2),
}


## Draws `ability`'s icon (about 30px across) centred on `c`.
static func draw(canvas: CanvasItem, ability: String, c: Vector2, color: Color, w := 4.0) -> void:
	match ability:
		"jump":         # up arrow
			canvas.draw_line(c + Vector2(0, 14), c + Vector2(0, -12), color, w)
			canvas.draw_polyline(PackedVector2Array([c + Vector2(-10, -2), c + Vector2(0, -13),
					c + Vector2(10, -2)]), color, w)
		"teleport":     # dotted trail into an arrow
			for i in 3:
				canvas.draw_rect(Rect2(c + Vector2(-16 + i * 7, -2), Vector2(4, 4)), color)
			canvas.draw_polyline(PackedVector2Array([c + Vector2(4, -10), c + Vector2(14, 0),
					c + Vector2(4, 10)]), color, w)
		"boost":        # double chevron (double jump)
			for dy in [-8.0, 4.0]:
				canvas.draw_polyline(PackedVector2Array([c + Vector2(-11, dy + 8), c + Vector2(0, dy - 2),
						c + Vector2(11, dy + 8)]), color, w)
		"grapple":      # ring on a line
			canvas.draw_arc(c + Vector2(0, -6), 7.0, 0.0, TAU, 20, color, w)
			canvas.draw_line(c + Vector2(0, 1), c + Vector2(0, 14), color, w)
			canvas.draw_line(c + Vector2(-8, 14), c + Vector2(8, 14), color, w)
		_:              # exit: a door
			canvas.draw_rect(Rect2(c + Vector2(-10, -14), Vector2(20, 28)), color, false, w)
