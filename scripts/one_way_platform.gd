@tool
extends StaticBody2D
## A platform you can jump up through from below and then stand on.
## The node's position is the top-left corner.
## Change `size` in the Inspector and it redraws in the editor.
## Set `rise` to make it a one-way ramp: the right end is `rise` px higher
## than the left (negative = the left end is higher). Keep ramps at 45 degrees
## or flatter so they can be walked up. Ramps are drawn as metal stairs; the
## collision underneath is still a smooth slope.
## Drawn in the Industrial tileset's palette (see Pal). `style` picks the look;
## `hang` and `wall_left` / `wall_right` add rods up to the ceiling and braces
## into the walls (tools/build_level.py sets them from the level around it).

enum Style { CATWALK, GRATE, GIRDER, PIPE }

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
## Flat platforms: catwalk, grate, girder or pipe. Ramps: catwalk = open
## steps, anything else = closed steps.
@export var style := Style.CATWALK:
	set(value):
		style = value
		queue_redraw()
## Length of the rods holding the platform up from the ceiling (0 = none).
@export var hang := 0.0:
	set(value):
		hang = value
		queue_redraw()
## Brace the platform into a wall at that end.
@export var wall_left := false:
	set(value):
		wall_left = value
		queue_redraw()
@export var wall_right := false:
	set(value):
		wall_right = value
		queue_redraw()

const PX := Pal.PX
const STEP_HEIGHT := 12.0
const TRUSS_DEPTH := 12.0        # how far the truss hangs below a catwalk
const TRUSS_SPAN := 16.0         # width of one V of the truss (2 x its diagonal)


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
	if not is_zero_approx(rise):
		_draw_stairs()
		return
	var w := snappedf(size.x, PX)
	var t := maxf(snappedf(size.y, PX), 4 * PX)
	if hang > 0.0:
		_draw_rods(w)
	var under := t
	match style:
		Style.GRATE:
			under = _draw_grate_brackets(w, t)
		Style.GIRDER:
			under = _draw_girder(w, t)
		Style.PIPE:
			under = _draw_pipe(w, t)
		_:
			under = _draw_truss(w, t)
	if wall_left:
		_draw_brace(0.0, under, 1.0)
	if wall_right:
		_draw_brace(w, under, -1.0)
	_deck(Rect2(0, 0, w, t), style == Style.GRATE)


# A deck plate: bright rim on top, dark body with vents (or a mesh of holes
# for a grate), black underside.
func _deck(r: Rect2, mesh := false) -> void:
	draw_rect(r, Pal.BODY)
	draw_rect(Rect2(r.position, Vector2(r.size.x, PX)), Pal.RIM_HI)
	draw_rect(Rect2(r.position + Vector2(0, PX), Vector2(r.size.x, PX)), Pal.RIM)
	if r.size.y >= 5 * PX:
		draw_rect(Rect2(r.position + Vector2(0, 2 * PX), Vector2(r.size.x, PX)), Pal.STEEL)
	draw_rect(Rect2(r.position + Vector2(0, r.size.y - PX), Vector2(r.size.x, PX)), Pal.OUTLINE)
	var vy := r.position.y + r.size.y - 3 * PX
	if mesh:
		var mx := r.position.x + 2 * PX
		while mx < r.end.x - 2 * PX:
			draw_rect(Rect2(mx, vy, PX, PX), Pal.OUTLINE)
			mx += 2 * PX
	else:
		var vx := r.position.x + 8 * PX
		while vx < r.end.x - 6 * PX:
			draw_rect(Rect2(vx, vy, 3 * PX, PX), Pal.DARK)
			vx += 16 * PX
	draw_rect(Rect2(r.position, Vector2(PX, r.size.y)), Pal.DARK)
	draw_rect(Rect2(r.end.x - PX, r.position.y, PX, r.size.y), Pal.DARK)


# Truss: a row of Vs between the deck and a bottom chord. Returns its bottom.
func _draw_truss(w: float, t: float) -> float:
	var chord_y := t + TRUSS_DEPTH - 2 * PX
	var x := TRUSS_SPAN / 2.0
	while x < w - PX:
		for side in [-1.0, 1.0]:
			_diagonal(Vector2(x, t), Vector2(side, 1.0), (TRUSS_DEPTH - 2 * PX) / PX, Pal.STEEL)
		x += TRUSS_SPAN
	draw_rect(Rect2(PX, chord_y, w - 2 * PX, PX), Pal.RIM)
	draw_rect(Rect2(PX, chord_y + PX, w - 2 * PX, PX), Pal.MID)
	for bx in [0.0, w - 2 * PX]:
		draw_rect(Rect2(bx, t, 2 * PX, TRUSS_DEPTH), Pal.BODY)
		draw_rect(Rect2(bx, t, PX, TRUSS_DEPTH), Pal.MID)
	return t + TRUSS_DEPTH


# Grate: small triangular brackets under a mesh deck, with amber lights.
func _draw_grate_brackets(w: float, t: float) -> float:
	var x := 16.0
	while x < w - 8.0:
		for i in 4:
			draw_rect(Rect2(x - (4 - i) * PX, t + i * PX, (4 - i) * 2 * PX, PX), Pal.MID if i else Pal.STEEL)
		draw_rect(Rect2(x - PX, t + 4 * PX, 2 * PX, PX), Pal.DARK)
		x += 64.0
	# Running lights along the underside edge.
	x = 8.0
	while x < w - 4.0:
		draw_rect(Rect2(x, t, PX, PX), Pal.AMBER)
		x += 32.0
	return t + 4 * PX


# Girder: an I-beam with lightening holes and hazard-striped ends.
func _draw_girder(w: float, t: float) -> float:
	var web := 12.0
	draw_rect(Rect2(2 * PX, t, w - 4 * PX, web), Pal.BODY)
	draw_rect(Rect2(2 * PX, t, w - 4 * PX, PX), Pal.DARK)
	var x := 20.0
	while x < w - 20.0:
		draw_rect(Rect2(x - 2 * PX, t + 2 * PX, 4 * PX, 2 * PX), Pal.OUTLINE)
		draw_rect(Rect2(x - PX, t + PX, 2 * PX, 4 * PX), Pal.OUTLINE)
		draw_rect(Rect2(x - 2 * PX, t + 4 * PX, 4 * PX, PX), Pal.MID)
		x += 24.0
	draw_rect(Rect2(0, t + web, w, PX), Pal.STEEL)
	draw_rect(Rect2(0, t + web + PX, w, PX), Pal.OUTLINE)
	for hx in [2 * PX, w - 8 * PX]:
		Pal.hazard(self, Rect2(hx, t, 6 * PX, web))
	return t + web + 2 * PX


# Pipe: the deck sits on a big coolant pipe with flanges and a valve.
func _draw_pipe(w: float, t: float) -> float:
	var top := t + PX
	var shades := [Pal.OUTLINE, Pal.TEAL_LIGHT, Pal.TEAL, Pal.TEAL, Pal.TEAL_DARK, Pal.OUTLINE]
	for i in shades.size():
		draw_rect(Rect2(PX, top + i * PX, w - 2 * PX, PX), shades[i])
	# Saddles between deck and pipe.
	var x := 12.0
	while x < w - 8.0:
		draw_rect(Rect2(x, t, 3 * PX, PX), Pal.MID)
		x += 40.0
	# Flanges.
	x = 24.0
	while x < w - 16.0:
		draw_rect(Rect2(x, top - PX, 2 * PX, 8 * PX), Pal.OUTLINE)
		draw_rect(Rect2(x, top, PX, 6 * PX), Pal.STEEL)
		x += 48.0
	# A red valve wheel near the middle.
	var vx := snappedf(w / 2.0, PX)
	draw_rect(Rect2(vx - 3 * PX, top + 6 * PX, 6 * PX, 2 * PX), Pal.RED_DARK)
	draw_rect(Rect2(vx - 3 * PX, top + 6 * PX, 6 * PX, PX), Pal.RED)
	draw_rect(Rect2(vx - PX, top + 5 * PX, 2 * PX, PX), Pal.STEEL)
	return top + 6 * PX


# Rods up to the ceiling with clamps at both ends.
func _draw_rods(w: float) -> void:
	var xs := [12.0, w - 14.0]
	if w > 256.0:
		xs.append(snappedf(w / 2.0, PX))
	for x in xs:
		draw_rect(Rect2(x, -hang, PX, hang), Pal.MID)
		draw_rect(Rect2(x + PX, -hang, PX, hang), Pal.DARK)
		draw_rect(Rect2(x - PX, -hang, 4 * PX, 2 * PX), Pal.MID)
		draw_rect(Rect2(x - PX, -2 * PX, 4 * PX, 2 * PX), Pal.MID)


# A knee brace from the underside into a wall; `dir` points away from it.
func _draw_brace(x: float, under: float, dir: float) -> void:
	var n := 8
	var from := Vector2(x, under + (n - 1) * PX)
	_diagonal(from, Vector2(dir, -1.0), n, Pal.STEEL)
	_diagonal(from + Vector2(0, PX), Vector2(dir, -1.0), n, Pal.DARK)
	# Wall plate.
	var px := x - 2 * PX if dir > 0 else x
	draw_rect(Rect2(px, 0, 2 * PX, under + n * PX + PX), Pal.OUTLINE)
	draw_rect(Rect2(px + (PX if dir > 0 else 0.0), PX, PX, under + n * PX - PX), Pal.STEEL)


func _draw_stairs() -> void:
	var w := snappedf(size.x, PX)
	var steps := maxi(2, roundi(absf(rise) / STEP_HEIGHT))
	var step_w := snappedf(w / steps, PX)
	# Stringer: a beam under the treads following the slope, drawn in
	# one-pixel columns so its edge is a clean pixel staircase.
	var x := 0.0
	while x < w:
		var y := snappedf(-rise * x / w, PX) + 3 * PX
		draw_rect(Rect2(x, y, PX, PX), Pal.STEEL)
		draw_rect(Rect2(x, y + PX, PX, 3 * PX), Pal.MID)
		draw_rect(Rect2(x, y + 4 * PX, PX, PX), Pal.DARK)
		x += PX
	# Treads, each at the slope's height in the middle of the step.
	for i in steps:
		var ty := snappedf(-rise * (i + 0.5) / steps, PX)
		var tx := i * step_w
		var tw := w - tx if i == steps - 1 else step_w
		if style == Style.CATWALK:
			# Open steps: a bracket down to the stringer.
			draw_rect(Rect2(tx + PX, ty, 2 * PX, 6 * PX), Pal.BODY)
		else:
			# Closed steps: a riser plate filling down to the stringer.
			var low := snappedf(maxf(-rise * tx / w, -rise * (tx + tw) / w), PX) + 5 * PX
			draw_rect(Rect2(tx, ty, tw, low - ty), Pal.DARK)
			draw_rect(Rect2(tx + PX, ty + 4 * PX, tw - 2 * PX, maxf(low - ty - 5 * PX, 0.0)), Pal.BODY)
		_deck(Rect2(tx, ty, tw, 4 * PX))


# A 45-degree line of `count` pixels from `from`, going `dir` (+-1, +-1).
func _diagonal(from: Vector2, dir: Vector2, count: float, color: Color) -> void:
	for i in int(count):
		var p := from + dir * PX * i
		if dir.x < 0:
			p.x -= PX
		draw_rect(Rect2(p, Vector2(PX, PX)), color)
