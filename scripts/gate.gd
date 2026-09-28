@tool
class_name Gate
extends Area2D
## An ability unlock: a colour-coded icon floating in an alcove. Touching it
## (when it's the next ability in GameState.ABILITY_ORDER) ends the run and
## unlocks the ability. `is_exit` / `closes_at` are kept for older levels.
## main.gd listens for the `reached` signal and feeds the clock via set_clock().

signal reached(gate: Gate)

## Ability this unlocks. Must match a name in GameState.ABILITY_ORDER.
@export var unlocks := "jump":
	set(value):
		unlocks = value
		queue_redraw()
## Tick this for an exit gate (the current level uses an escape line instead).
@export var is_exit := false
## Seconds after the run starts when this closes. 0 = never.
@export var closes_at := 0.0

## Icon colour per ability: jump green, teleport cyan (like force fields),
## double jump purple, grapple orange (like grapple points).
const ABILITY_COLORS := {
	"jump": Color(0.45, 1.0, 0.55),
	"teleport": Color(0.35, 0.9, 1.0),
	"boost": Color(0.8, 0.5, 1.0),
	"grapple": Color(1.0, 0.65, 0.2),
}
const EXIT_COLOR := Color(1.0, 0.85, 0.3)
const IDLE_COLOR := Color(0.45, 0.45, 0.5, 0.5)
const ICON_Y := -40.0            # icon centre, above the floor at y = +48

var elapsed := 0.0
var _time := 0.0


func _ready() -> void:
	add_to_group("gates")
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func display_name() -> String:
	return "EXIT" if is_exit else unlocks.to_upper()


func is_open() -> bool:
	return closes_at <= 0.0 or elapsed < closes_at


func time_left() -> float:
	return maxf(closes_at - elapsed, 0.0)


## True if this is the unlock the current run is going for.
func is_target() -> bool:
	if Engine.is_editor_hint():
		return true
	var next := GameState.next_ability()
	return next == "" if is_exit else next == unlocks


func is_active() -> bool:
	return is_target() and is_open()


func set_clock(seconds_since_start: float) -> void:
	elapsed = seconds_since_start


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and is_active():
		reached.emit(self)


func _draw() -> void:
	var active := is_active()
	var color: Color = EXIT_COLOR if is_exit else ABILITY_COLORS.get(unlocks, Color.WHITE)
	if not active:
		color = IDLE_COLOR
	var bob := sin(_time * 2.5) * 6.0 if active else 0.0
	var c := Vector2(0, ICON_Y + bob)
	if active:
		# Soft glow and a pulsing ring.
		draw_circle(c, 30.0, Color(color, 0.12))
		draw_arc(c, 24.0 + sin(_time * 4.0) * 2.0, 0.0, TAU, 32, Color(color, 0.5), 2.0)
	# Little pedestal on the floor.
	draw_rect(Rect2(-18, 40, 36, 8), Color(color, 0.6))
	_draw_icon(c, color)


func _draw_icon(c: Vector2, color: Color) -> void:
	var w := 4.0
	match "exit" if is_exit else unlocks:
		"jump":         # up arrow
			draw_line(c + Vector2(0, 14), c + Vector2(0, -12), color, w)
			draw_polyline(PackedVector2Array([c + Vector2(-10, -2), c + Vector2(0, -13),
					c + Vector2(10, -2)]), color, w)
		"teleport":     # dotted trail into an arrow
			for i in 3:
				draw_rect(Rect2(c + Vector2(-16 + i * 7, -2), Vector2(4, 4)), color)
			draw_polyline(PackedVector2Array([c + Vector2(4, -10), c + Vector2(14, 0),
					c + Vector2(4, 10)]), color, w)
		"boost":        # double chevron (double jump)
			for dy in [-8.0, 4.0]:
				draw_polyline(PackedVector2Array([c + Vector2(-11, dy + 8), c + Vector2(0, dy - 2),
						c + Vector2(11, dy + 8)]), color, w)
		"grapple":      # ring on a line
			draw_arc(c + Vector2(0, -6), 7.0, 0.0, TAU, 20, color, w)
			draw_line(c + Vector2(0, 1), c + Vector2(0, 14), color, w)
			draw_line(c + Vector2(-8, 14), c + Vector2(8, 14), color, w)
		_:              # exit: a door
			draw_rect(Rect2(c + Vector2(-10, -14), Vector2(20, 28)), color, false, w)
