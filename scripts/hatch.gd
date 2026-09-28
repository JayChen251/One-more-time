@tool
class_name Hatch
extends Node2D
## A horizontal bulkhead door across an opening in the ship. Two panels slide
## in from the sides during the last `close_duration` seconds before
## `closes_at` (seconds into the run); after that the opening is sealed.
## There is no countdown on screen: the panels sliding in are the warning.
## The node's position is the top-left of the opening. main.gd feeds the
## clock via set_clock().

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
const PANEL_COLOR := Color(1.0, 0.85, 0.3)
const SEALED_COLOR := Color(0.95, 0.3, 0.3)

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
	# Clank when the panels start moving, and a deeper one when they seal.
	if p > 0.0 and not _was_closing:
		_was_closing = true
		Sfx.play(self, "hatch", 1.2, -4.0)
	if p >= 1.0 and not _was_sealed:
		_was_sealed = true
		Sfx.play(self, "hatch", 0.8)
	_apply(p)


func _apply(p: float) -> void:
	var half := width / 2.0 * p
	_set_panel($Left, 0.0, half)
	_set_panel($Right, width - half, half)
	$Track.points = PackedVector2Array([Vector2(0, THICKNESS / 2), Vector2(width, THICKNESS / 2)])
	var color := SEALED_COLOR if p >= 1.0 else PANEL_COLOR
	$Left/Body.color = color
	$Right/Body.color = color


func _set_panel(panel: StaticBody2D, x: float, w: float) -> void:
	var collision: CollisionShape2D = panel.get_node("CollisionShape2D")
	var body: ColorRect = panel.get_node("Body")
	panel.visible = w > 0.5
	collision.disabled = w < 0.5
	if collision.shape:
		(collision.shape as RectangleShape2D).size = Vector2(maxf(w, 1.0), THICKNESS)
	collision.position = Vector2(x + w / 2.0, THICKNESS / 2.0)
	body.position = Vector2(x, 0.0)
	body.size = Vector2(w, THICKNESS)
