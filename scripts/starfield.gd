extends Node2D
## Draws a fixed field of stars inside `area` (local coordinates).

@export var area := Rect2(0, 0, 4000, 3000)
@export var star_count := 400


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	for i in star_count:
		var p := area.position + Vector2(rng.randf() * area.size.x, rng.randf() * area.size.y)
		var r := rng.randf_range(1.0, 2.5)
		draw_circle(p, r, Color(1, 1, 1, rng.randf_range(0.3, 1.0)))
