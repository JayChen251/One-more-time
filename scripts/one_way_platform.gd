@tool
extends StaticBody2D
## A platform you can jump up through from below and then stand on.
## The node's position is the top-left corner.
## Change `size` in the Inspector and it redraws in the editor.
## Set `rise` to make it a one-way ramp: the right end is `rise` px higher
## than the left (negative = the left end is higher). Keep ramps at 45 degrees
## or flatter so they can be walked up. Ramps are drawn as metal stairs; the
## collision underneath is still a smooth slope.
## Drawn in the Industrial tileset's palette: flat platforms are catwalks with
## a truss hanging underneath.

@export var size := Vector2(192, 12):
	set(value):
		size = value
		if is_node_ready():
			_rebuild()
@export var rise := 0.0:
	set(value):
		rise = value
		if is_node_ready():
			_rebuild()

const PX := 2.0                  # one screen pixel (one tileset texel)
const STEP_HEIGHT := 12.0
const TRUSS_DEPTH := 12.0        # how far the truss hangs below a catwalk
const TRUSS_SPAN := 16.0         # width of one V of the truss (2 x its diagonal)

# The Industrial tileset's metal, light to dark.
const RIM_HI := Color8(215, 226, 230)
const RIM := Color8(182, 200, 204)
const STEEL := Color8(116, 123, 139)
const MID := Color8(75, 72, 91)
const BODY := Color8(45, 41, 55)
const DARK := Color8(23, 20, 29)
const OUTLINE := Color8(0, 0, 0)


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	var rect := PackedVector2Array([Vector2(0, 0), Vector2(size.x, -rise),
			Vector2(size.x, size.y - rise), Vector2(0, size.y)])
	# A polygon instead of a RectangleShape2D, so each platform owns its
	# collision data and resizing one doesn't resize every other instance.
	$CollisionPolygon2D.polygon = rect
	queue_redraw()


func _draw() -> void:
	if is_zero_approx(rise):
		_draw_catwalk()
	else:
		_draw_stairs()


func _draw_catwalk() -> void:
	var w := snappedf(size.x, PX)
	var t := maxf(snappedf(size.y, PX), 4 * PX)
	# Truss: a row of Vs between the deck and a bottom chord.
	var chord_y := t + TRUSS_DEPTH - 2 * PX
	var x := TRUSS_SPAN / 2.0
	while x < w - PX:
		for side in [-1.0, 1.0]:
			_diagonal(Vector2(x, t), Vector2(side, 1.0), (TRUSS_DEPTH - 2 * PX) / PX, STEEL)
		x += TRUSS_SPAN
	draw_rect(Rect2(PX, chord_y, w - 2 * PX, PX), RIM)
	draw_rect(Rect2(PX, chord_y + PX, w - 2 * PX, PX), MID)
	# End brackets tying deck and chord together.
	for bx in [0.0, w - 2 * PX]:
		draw_rect(Rect2(bx, t, 2 * PX, TRUSS_DEPTH), BODY)
		draw_rect(Rect2(bx, t, PX, TRUSS_DEPTH), MID)
	_deck(Rect2(0, 0, w, t))


# A deck plate: bright rim on top, dark body with vents, black underside.
func _deck(r: Rect2) -> void:
	draw_rect(r, BODY)
	draw_rect(Rect2(r.position, Vector2(r.size.x, PX)), RIM_HI)
	draw_rect(Rect2(r.position + Vector2(0, PX), Vector2(r.size.x, PX)), RIM)
	if r.size.y >= 5 * PX:
		draw_rect(Rect2(r.position + Vector2(0, 2 * PX), Vector2(r.size.x, PX)), STEEL)
	draw_rect(Rect2(r.position + Vector2(0, r.size.y - PX), Vector2(r.size.x, PX)), OUTLINE)
	# Vents every 32px and dark end caps.
	var vy := r.position.y + r.size.y - 3 * PX
	var vx := r.position.x + 8 * PX
	while vx < r.end.x - 6 * PX:
		draw_rect(Rect2(vx, vy, 3 * PX, PX), DARK)
		vx += 16 * PX
	draw_rect(Rect2(r.position, Vector2(PX, r.size.y)), DARK)
	draw_rect(Rect2(r.end.x - PX, r.position.y, PX, r.size.y), DARK)


func _draw_stairs() -> void:
	var w := snappedf(size.x, PX)
	var steps := maxi(2, roundi(absf(rise) / STEP_HEIGHT))
	var step_w := snappedf(w / steps, PX)
	# Stringer: a beam under the treads following the slope, drawn in
	# one-pixel columns so its edge is a clean pixel staircase.
	var x := 0.0
	while x < w:
		var y := snappedf(-rise * x / w, PX) + 3 * PX
		draw_rect(Rect2(x, y, PX, PX), STEEL)
		draw_rect(Rect2(x, y + PX, PX, 3 * PX), MID)
		draw_rect(Rect2(x, y + 4 * PX, PX, PX), DARK)
		x += PX
	# Treads, each at the slope's height in the middle of the step.
	for i in steps:
		var ty := snappedf(-rise * (i + 0.5) / steps, PX)
		var tx := i * step_w
		var tw := w - tx if i == steps - 1 else step_w
		# Riser bracket down to the stringer.
		draw_rect(Rect2(tx + PX, ty, 2 * PX, 6 * PX), BODY)
		_deck(Rect2(tx, ty, tw, 4 * PX))


# A 45-degree line of `count` pixels from `from`, going `dir` (+-1, +-1).
func _diagonal(from: Vector2, dir: Vector2, count: float, color: Color) -> void:
	for i in int(count):
		var p := from + dir * PX * i
		if dir.x < 0:
			p.x -= PX
		draw_rect(Rect2(p, Vector2(PX, PX)), color)
