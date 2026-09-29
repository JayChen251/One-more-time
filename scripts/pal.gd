@tool
class_name Pal
## The game's shared palette and pixel grid, taken from the Industrial tileset
## pack, so everything drawn in code matches the tiles.
## One screen pixel (one tileset texel) is PX world units.

const PX := 2.0

# Metal, light to dark.
const RIM_HI := Color8(215, 226, 230)
const RIM := Color8(182, 200, 204)
const STEEL := Color8(116, 123, 139)
const MID := Color8(75, 72, 91)
const BODY := Color8(45, 41, 55)
const DARK := Color8(23, 20, 29)
const OUTLINE := Color8(0, 0, 0)

# Accents (the pack's teal and its orange/red variant).
const TEAL_DARK := Color8(20, 49, 74)
const TEAL := Color8(39, 91, 137)
const TEAL_LIGHT := Color8(87, 150, 206)
const TEAL_GLOW := Color8(169, 215, 255)
const HAZARD := Color8(249, 198, 32)
const AMBER := Color8(249, 110, 32)
const RED := Color8(249, 32, 32)
const RED_DARK := Color8(140, 12, 12)
const GREEN := Color8(90, 230, 120)


## A filled circle drawn as rows of whole pixels (no smooth edges).
static func circle(canvas: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	var rows := int(ceilf(r / PX))
	for i in range(-rows, rows):
		var y := (i + 0.5) * PX
		var half := snappedf(sqrt(maxf(r * r - y * y, 0.0)), PX)
		if half > 0.0:
			canvas.draw_rect(Rect2(snappedf(c.x, PX) - half, snappedf(c.y, PX) + i * PX, 2 * half, PX), color)


## A ring `thickness` pixels thick, drawn as whole pixels.
static func ring(canvas: CanvasItem, c: Vector2, r: float, color: Color, thickness := 1) -> void:
	var cx := snappedf(c.x, PX)
	var cy := snappedf(c.y, PX)
	var inner_r := maxf(r - thickness * PX, 0.0)
	var rows := int(ceilf(r / PX))
	for i in range(-rows, rows):
		var y := (i + 0.5) * PX
		var outer := snappedf(sqrt(maxf(r * r - y * y, 0.0)), PX)
		if outer <= 0.0:
			continue
		var inner := snappedf(sqrt(maxf(inner_r * inner_r - y * y, 0.0)), PX)
		inner = minf(inner, outer - PX)
		var row_y := cy + i * PX
		canvas.draw_rect(Rect2(cx - outer, row_y, outer - inner, PX), color)
		canvas.draw_rect(Rect2(cx + inner, row_y, outer - inner, PX), color)


## A metal plate: bright rim on top, dark body, black outline.
static func plate(canvas: CanvasItem, r: Rect2, body := BODY) -> void:
	canvas.draw_rect(r, OUTLINE)
	var inner := r.grow(-PX)
	canvas.draw_rect(inner, body)
	canvas.draw_rect(Rect2(inner.position, Vector2(inner.size.x, PX)), RIM)
	canvas.draw_rect(Rect2(inner.position + Vector2(0, inner.size.y - PX), Vector2(inner.size.x, PX)), DARK)


## Diagonal yellow/black hazard stripes filling `r`.
static func hazard(canvas: CanvasItem, r: Rect2) -> void:
	canvas.draw_rect(r, OUTLINE)
	for col in int(r.size.x / PX):
		for row in int(r.size.y / PX):
			if (col + row) / 2 % 2 == 0:
				canvas.draw_rect(Rect2(r.position + Vector2(col, row) * PX, Vector2(PX, PX)), HAZARD)
