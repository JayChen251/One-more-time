@tool
extends StaticBody2D
## The airlock at the top of the escape tube: a heavy blast door, in the
## Industrial tileset's palette (see Pal). In the ending main.gd calls open():
## the two halves slide back into the tube's walls and the air rushes out
## into space. The node's position is its top-left corner.

@export var width := 384.0:
	set(value):
		width = value
		if is_node_ready():
			_rebuild()

const THICKNESS := 64.0
const PX := Pal.PX
const OPEN_TIME := 0.7
const RUSH_TIME := 1.6

## 0 = shut, 1 = fully open.
var opening := 0.0
var _rush := -1.0                # seconds since the air started rushing out


func _ready() -> void:
	add_to_group("airlock")
	_rebuild()


func _rebuild() -> void:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(width, THICKNESS)
	$CollisionShape2D.shape = shape
	$CollisionShape2D.position = Vector2(width, THICKNESS) / 2.0
	queue_redraw()


## Slides the door open; await the returned tween to wait for it.
func open() -> Tween:
	$CollisionShape2D.set_deferred("disabled", true)
	_rush = 0.0
	var tween := create_tween()
	tween.tween_property(self, "opening", 1.0, OPEN_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	return tween


func _process(delta: float) -> void:
	if _rush >= 0.0:
		_rush += delta
		queue_redraw()
		if _rush > RUSH_TIME:
			_rush = -1.0


func _draw() -> void:
	var mid := snappedf(width / 2.0, PX)
	var half := snappedf(mid * (1.0 - opening), PX)
	if half > 0.0:
		_half(0.0, half, true)
		_half(width - half, half, false)
	if _rush >= 0.0:
		_draw_rush()


# One door half from x to x + w; its leading (moving) edge is on the right
# for the left half.
func _half(x: float, w: float, leading_right: bool) -> void:
	Pal.plate(self, Rect2(x, 0, w, THICKNESS))
	Pal.hazard(self, Rect2(x + PX, 12 * PX, w - 2 * PX, 8 * PX))
	var edge := x + w - 2 * PX if leading_right else x
	draw_rect(Rect2(edge, 0, 2 * PX, THICKNESS), Pal.OUTLINE)
	# Bolts, kept relative to the leading edge so they slide with the door.
	var i := 32.0
	while i < w - 8.0:
		var bx := x + w - i if leading_right else x + i
		draw_rect(Rect2(bx, 4 * PX, PX, PX), Pal.STEEL)
		draw_rect(Rect2(bx, THICKNESS - 5 * PX, PX, PX), Pal.STEEL)
		i += 32.0
	# "EXIT" stencil, centred on the half while the door is shut.
	if opening < 0.05:
		var tx := snappedf(x + w / 2.0 - 12 * PX, PX)
		for ch in "EXIT":
			var rows: Array = PixelText.GLYPHS[ch]
			for gy in rows.size():
				var row: String = rows[gy]
				for gx in row.length():
					if row[gx] == "1":
						draw_rect(Rect2(tx + gx * PX, 3 * PX + gy * PX, PX, PX), Pal.RIM)
			tx += 6 * PX
	# Status light: green, the way out.
	var lx := x + 4.0 if leading_right else x + w - 8.0
	draw_rect(Rect2(lx, THICKNESS - 10 * PX, 2 * PX, 4 * PX), Pal.GREEN)


# The air blasting out of the open airlock: pale streaks racing upward.
func _draw_rush() -> void:
	var fade := 1.0 - _rush / RUSH_TIME
	for i in 40:
		var fx := fposmod(sin(i * 12.9898) * 43758.5453, 1.0)
		var speed := 500.0 + 700.0 * fposmod(sin(i * 78.233) * 12345.678, 1.0)
		var y := snappedf(THICKNESS - fposmod(_rush * speed + i * 37.0, 900.0), PX)
		var x := snappedf(width * (0.1 + 0.8 * fx) + (fx - 0.5) * (THICKNESS - y) * 0.4, PX)
		draw_rect(Rect2(x, y, PX, 6 * PX), Color(0.85, 0.92, 1.0, 0.6 * fade))
