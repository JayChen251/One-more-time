@tool
extends StaticBody2D
## The airlock at the top of the ship: a heavy blast door across the exit
## channel, in the Industrial tileset's palette (see Pal). main.gd fades it
## out when the player escapes. The node's position is its top-left corner.

@export var width := 384.0:
	set(value):
		width = value
		if is_node_ready():
			_rebuild()

const THICKNESS := 64.0
const PX := Pal.PX


func _ready() -> void:
	add_to_group("airlock")
	_rebuild()


func _rebuild() -> void:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(width, THICKNESS)
	$CollisionShape2D.shape = shape
	$CollisionShape2D.position = Vector2(width, THICKNESS) / 2.0
	queue_redraw()


func _draw() -> void:
	Pal.plate(self, Rect2(0, 0, width, THICKNESS))
	# Hazard band along the middle, split where the two halves meet.
	Pal.hazard(self, Rect2(2 * PX, 12 * PX, width - 4 * PX, 8 * PX))
	var mid := snappedf(width / 2.0, PX)
	draw_rect(Rect2(mid - PX, 0, 2 * PX, THICKNESS), Pal.OUTLINE)
	# Bolts and panel seams.
	var x := 32.0
	while x < width - 16.0:
		draw_rect(Rect2(x, 4 * PX, PX, PX), Pal.STEEL)
		draw_rect(Rect2(x, THICKNESS - 5 * PX, PX, PX), Pal.STEEL)
		x += 32.0
	# "EXIT" stencil on each half.
	for half_x in [mid / 2.0, mid + mid / 2.0]:
		var tx := snappedf(half_x - 12 * PX, PX)
		for ch in "EXIT":
			var rows: Array = PixelText.GLYPHS[ch]
			for gy in rows.size():
				var row: String = rows[gy]
				for gx in row.length():
					if row[gx] == "1":
						draw_rect(Rect2(tx + gx * PX, 3 * PX + gy * PX, PX, PX), Pal.RIM)
			tx += 6 * PX
	# Green status lights: this door is the way out.
	for lx in [8.0, width - 12.0]:
		draw_rect(Rect2(lx, THICKNESS - 10 * PX, 2 * PX, 4 * PX), Pal.GREEN)
