class_name Wreckage
extends Node2D
## What's left of the ship after the ending's final blast: hull plates
## tumbling away from where the ship was and embers fading out, in the
## Industrial tileset's palette (see Pal).
## Use Wreckage.spawn(parent, area, amount).

var _pieces: Array = []          # [position, velocity, size, angle, spin, is_ember]
var _t := 0.0


static func spawn(parent: Node, area: Rect2, amount := 60) -> Wreckage:
	var w := Wreckage.new()
	w.z_index = 12
	var centre := area.get_center()
	for i in amount:
		var at := area.position + Vector2(randf() * area.size.x, randf() * area.size.y)
		var away := (at - centre).normalized() if at != centre else Vector2.UP
		var ember := i % 3 == 0
		w._pieces.append([at, away.rotated(randf_range(-0.6, 0.6)) * randf_range(40.0, 220.0),
				Vector2(randf_range(8, 16), randf_range(6, 12)) * (0.5 if ember else Pal.PX * 2.0),
				randf() * TAU, randf_range(-2.0, 2.0), ember])
	parent.add_child(w)
	return w


func _process(delta: float) -> void:
	_t += delta
	for p in _pieces:
		p[0] = p[0] + p[1] * delta
		p[3] = p[3] + p[4] * delta
	queue_redraw()


func _draw() -> void:
	for p in _pieces:
		var size: Vector2 = p[2]
		draw_set_transform(p[0], p[3])
		if p[5]:
			var a := clampf(1.0 - _t / 4.0, 0.0, 1.0)
			if a > 0.0:
				draw_rect(Rect2(-size / 2.0, size), Color(Pal.AMBER, a))
		else:
			var r := Rect2(-size / 2.0, size)
			draw_rect(r, Pal.OUTLINE)
			draw_rect(r.grow(-Pal.PX), Pal.BODY)
			draw_rect(Rect2(r.position + Vector2(Pal.PX, Pal.PX), Vector2(r.size.x - 2 * Pal.PX, Pal.PX)), Pal.STEEL)
	draw_set_transform(Vector2.ZERO)
