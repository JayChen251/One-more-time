extends Node2D
## Draws a fixed field of stars inside `area` (local coordinates), and a
## distant banded planet, in whole pixels. Sits behind everything, so it only
## shows through open space outside the ship.

@export var area := Rect2(0, 0, 4000, 3000)
@export var star_count := 400
## Centre and radius of the planet (radius 0 = no planet).
@export var planet := Vector2.ZERO
@export var planet_radius := 0.0

const PX := Pal.PX
const BANDS := [Color8(74, 52, 110), Color8(92, 66, 128), Color8(64, 44, 96), Color8(110, 80, 140)]


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	for i in star_count:
		var p := area.position + Vector2(rng.randf() * area.size.x, rng.randf() * area.size.y)
		var size := PX if rng.randf() < 0.8 else 2 * PX      # one or two screen pixels
		draw_rect(Rect2(p.snapped(Vector2(PX, PX)), Vector2(size, size)),
				Color(1, 1, 1, rng.randf_range(0.3, 1.0)))
	if planet_radius > 0.0:
		_draw_planet()


func _draw_planet() -> void:
	var r := planet_radius
	var c := planet.snapped(Vector2(PX, PX))
	Pal.circle(self, c, r + 8 * PX, Color(0.55, 0.45, 0.9, 0.08))
	Pal.circle(self, c, r + 3 * PX, Color(0.6, 0.5, 0.95, 0.15))
	var rows := int(r / PX)
	for i in range(-rows, rows):
		var y := (i + 0.5) * PX
		var half := snappedf(sqrt(maxf(r * r - y * y, 0.0)), PX)
		if half <= 0.0:
			continue
		var band: Color = BANDS[int((i + rows) / (4 + (i + rows) % 3)) % BANDS.size()]
		var row_y := c.y + i * PX
		draw_rect(Rect2(c.x - half, row_y, 2 * half, PX), band)
		# Night side on the left (an elliptical terminator), lit rim on the right.
		draw_rect(Rect2(c.x - half, row_y, snappedf(half * 0.8, PX), PX), Color(0.02, 0.02, 0.06, 0.7))
		if y < 0.0:
			draw_rect(Rect2(c.x + half - 2 * PX, row_y, 2 * PX, PX), Color(0.8, 0.75, 1.0, 0.6))
