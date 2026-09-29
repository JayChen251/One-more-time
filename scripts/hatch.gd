@tool
class_name Hatch
extends Node2D
## A horizontal bulkhead door across an opening in the ship. Two panels slide
## in from the sides during the last `close_duration` seconds before
## `closes_at` (seconds into the run); after that the opening is sealed.
## There is no countdown on screen: the panels sliding in are the warning.
## The node's position is the top-left of the opening. main.gd feeds the
## clock via set_clock().
## Drawn in the Industrial tileset's palette: blast-door panels with hazard
## stripes on their leading edges, over a rail with status lights (amber,
## blinking while closing, red once sealed).

@export var width := 256.0:
	set(value):
		width = value
		if is_node_ready():
			_apply(0.0)
## Seconds after the run starts when the hatch is fully shut.
@export var closes_at := 10.0
## How long the panels take to slide shut.
@export var close_duration := 3.0

const THICKNESS := 16.0
const PANEL_COLOR := Color(1.0, 0.85, 0.3)        # sparks
const PX := 2.0                                    # one screen pixel
const STRIPE_WIDTH := 24.0

const RIM_HI := Color8(215, 226, 230)
const RIM := Color8(182, 200, 204)
const STEEL := Color8(116, 123, 139)
const BODY := Color8(45, 41, 55)
const DARK := Color8(23, 20, 29)
const OUTLINE := Color8(0, 0, 0)
const HAZARD := Color8(249, 198, 32)
const AMBER := Color8(249, 110, 32)
const RED := Color8(249, 32, 32)

var elapsed := 0.0
var _was_closing := false
var _was_sealed := false


func _ready() -> void:
	add_to_group("hatches")
	# Fresh shapes per hatch, so resizing one panel doesn't resize the others.
	for panel in [$Left, $Right]:
		panel.get_node("CollisionShape2D").shape = RectangleShape2D.new()
	_apply(0.0)


func progress() -> float:
	return clampf((elapsed - (closes_at - close_duration)) / close_duration, 0.0, 1.0)


func is_sealed() -> bool:
	return progress() >= 1.0


func time_left() -> float:
	return maxf(closes_at - elapsed, 0.0)


func set_clock(seconds_since_start: float) -> void:
	elapsed = seconds_since_start
	var p := progress()
	# Clank when the panels start moving, and a deeper one when they seal;
	# only heard if the hatch is on screen.
	if p > 0.0 and not _was_closing:
		_was_closing = true
		if _on_screen():
			Sfx.play(self, "hatch", 1.2, -4.0)
	if p >= 1.0 and not _was_sealed:
		_was_sealed = true
		if _on_screen():
			Sfx.play(self, "hatch", 0.8)
		for i in 5:
			Sparks.spawn(get_parent(), global_position + Vector2(width * (i + 0.5) / 5.0, THICKNESS),
					PANEL_COLOR, 6, true, 0.6)
	elif p > 0.0 and p < 1.0 and Engine.get_process_frames() % 4 == 0:
		var half := width / 2.0 * p
		for x in [half, width - half]:
			Sparks.spawn(get_parent(), global_position + Vector2(x, THICKNESS), PANEL_COLOR, 2, false, 0.5)
	_apply(p)


func _apply(p: float) -> void:
	var half := snappedf(width / 2.0 * p, PX)
	_set_panel($Left, 0.0, half)
	_set_panel($Right, width - half, half)
	queue_redraw()


func _draw() -> void:
	var p := progress()
	var half := snappedf(width / 2.0 * p, PX)
	# Rail across the opening, with status lights.
	draw_rect(Rect2(0, 3 * PX, width, 2 * PX), DARK)
	var blink := fmod(elapsed * 4.0, 1.0) < 0.5
	var light: Color = RED if p >= 1.0 else (AMBER if blink else DARK) if p > 0.0 else Color(AMBER, 0.45)
	var x := 16.0
	while x < width - 8.0:
		draw_rect(Rect2(x, 3 * PX, 2 * PX, 2 * PX), light)
		x += 32.0
	if half > 0.5:
		_draw_panel(0.0, half, true)
		_draw_panel(width - half, half, false)
	# Door pockets on the walls the panels slide out of.
	for px in [-4 * PX, width]:
		draw_rect(Rect2(px, -2 * PX, 4 * PX, THICKNESS + 4 * PX), OUTLINE)
		draw_rect(Rect2(px + PX, -PX, 2 * PX, THICKNESS + 2 * PX), STEEL)
		draw_rect(Rect2(px + PX, -PX, 2 * PX, PX), RIM_HI)
		draw_rect(Rect2(px + PX, 3 * PX, 2 * PX, 2 * PX), light)


# One blast-door panel from x to x + w; `leading_right` = its moving edge is
# on the right.
func _draw_panel(x: float, w: float, leading_right: bool) -> void:
	var t := THICKNESS
	draw_rect(Rect2(x, 0, w, t), BODY)
	draw_rect(Rect2(x, 0, w, PX), RIM_HI)
	draw_rect(Rect2(x, PX, w, PX), RIM)
	draw_rect(Rect2(x, t - PX, w, PX), OUTLINE)
	# Seams and rivets every 32px, counted from the leading edge so they slide
	# with the panel.
	var i := 32.0
	while i < w - STRIPE_WIDTH:
		var sx := x + w - i if leading_right else x + i
		draw_rect(Rect2(sx, 2 * PX, PX, t - 3 * PX), DARK)
		draw_rect(Rect2(sx - 3 * PX, 3 * PX, PX, PX), STEEL)
		draw_rect(Rect2(sx + 3 * PX, 3 * PX, PX, PX), STEEL)
		i += 32.0
	# Hazard stripes on the leading edge.
	var sw := minf(STRIPE_WIDTH, w)
	var x0 := x + w - sw if leading_right else x
	for col in int(sw / PX):
		for row in range(2, int(t / PX) - 1):
			if (col + row) / 2 % 2 == 0:
				draw_rect(Rect2(x0 + col * PX, row * PX, PX, PX), HAZARD)
	var edge := x + w - PX if leading_right else x
	draw_rect(Rect2(edge, 0, PX, t), OUTLINE)


func _on_screen() -> bool:
	var camera := get_viewport().get_camera_2d()
	if not camera:
		return true
	var view_size := get_viewport_rect().size / camera.zoom
	var view := Rect2(camera.get_screen_center_position() - view_size / 2.0, view_size)
	return view.intersects(Rect2(global_position, Vector2(width, THICKNESS)))


func _set_panel(panel: StaticBody2D, x: float, w: float) -> void:
	var collision: CollisionShape2D = panel.get_node("CollisionShape2D")
	collision.disabled = w < 0.5
	if collision.shape:
		(collision.shape as RectangleShape2D).size = Vector2(maxf(w, 1.0), THICKNESS)
	collision.position = Vector2(x + w / 2.0, THICKNESS / 2.0)
