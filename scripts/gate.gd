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
	var color: Color = EXIT_COLOR if is_exit else AbilityIcons.COLORS.get(unlocks, Color.WHITE)
	if not active:
		color = IDLE_COLOR
	var bob := snappedf(sin(_time * 2.5) * 6.0, Pal.PX) if active else 0.0
	var c := Vector2(0, ICON_Y + bob)
	if active:
		# Soft glow and a pulsing ring, in whole pixels.
		Pal.circle(self, c, 30.0, Color(color, 0.1))
		Pal.circle(self, c, 22.0, Color(color, 0.1))
		Pal.ring(self, c, 24.0 + snappedf(sin(_time * 4.0) * 4.0, Pal.PX), Color(color, 0.5))
		# Motes drifting up from the pedestal.
		for i in 6:
			var life := fmod(_time * 0.6 + i / 6.0, 1.0)
			var mx := snappedf(sin(i * 2.3 + _time) * 14.0, Pal.PX)
			draw_rect(Rect2(Vector2(mx, snappedf(34.0 - life * 90.0, Pal.PX)), Vector2(2, 2)), Color(color, 1.0 - life))
	# Pedestal: a metal plinth with a light strip in the ability's colour.
	Pal.plate(self, Rect2(-20, 36, 40, 12))
	draw_rect(Rect2(-16, 40, 32, 2), Color(color, 1.0 if active else 0.5))
	draw_rect(Rect2(-12, 32, 24, 4), Pal.OUTLINE)
	draw_rect(Rect2(-10, 32, 20, 2), Pal.STEEL)
	AbilityIcons.draw(self, "exit" if is_exit else unlocks, c, color)
