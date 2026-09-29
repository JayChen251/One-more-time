extends Node2D
## Draws a fixed field of stars inside `area` (local coordinates).

@export var area := Rect2(0, 0, 4000, 3000)
@export var star_count := 400


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	for i in star_count:
		var p := area.position + Vector2(rng.randf() * area.size.x, rng.randf() * area.size.y)
		var size := 4.0 if rng.randf() < 0.8 else 8.0      # one or two screen pixels
		draw_rect(Rect2(p.snapped(Vector2(4, 4)), Vector2(size, size)),
				Color(1, 1, 1, rng.randf_range(0.3, 1.0)))
