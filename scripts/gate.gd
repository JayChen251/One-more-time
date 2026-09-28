class_name Gate
extends Area2D
## A bulkhead gate at the end of the level. Each one unlocks an ability (or,
## if is_exit, leads out of the ship). A gate only counts if it is for the
## next ability in GameState.ABILITY_ORDER, and it seals `closes_at` seconds
## into the run, so each new ability has to be used to get there in time.
## main.gd listens for the `reached` signal and feeds the clock via set_clock().

signal reached(gate: Gate)

## Ability this gate unlocks. Must match a name in GameState.ABILITY_ORDER.
@export var unlocks := "jump"
## Tick this for the final escape gate.
@export var is_exit := false
## Seconds after the run starts when this gate seals. 0 = never seals.
@export var closes_at := 0.0

const ACTIVE_COLOR := Color(0.2, 0.9, 0.5, 0.8)
const EXIT_COLOR := Color(1.0, 0.8, 0.2, 0.9)
const IDLE_COLOR := Color(0.4, 0.4, 0.4, 0.4)
const SEALED_COLOR := Color(0.8, 0.15, 0.15, 0.8)

var elapsed := 0.0

@onready var body_rect: ColorRect = $Body
@onready var label: Label = $Label


func _ready() -> void:
	add_to_group("gates")
	body_entered.connect(_on_body_entered)
	_refresh_look()


func display_name() -> String:
	return "EXIT" if is_exit else unlocks.to_upper()


func is_open() -> bool:
	return closes_at <= 0.0 or elapsed < closes_at


func time_left() -> float:
	return maxf(closes_at - elapsed, 0.0)


## True if this is the gate the current run is going for.
func is_target() -> bool:
	var next := GameState.next_ability()
	return next == "" if is_exit else next == unlocks


func is_active() -> bool:
	return is_target() and is_open()


func set_clock(seconds_since_start: float) -> void:
	elapsed = seconds_since_start
	_refresh_look()


func _refresh_look() -> void:
	if not is_open():
		body_rect.color = SEALED_COLOR
		label.text = display_name() + "\nSEALED"
	elif is_target():
		body_rect.color = EXIT_COLOR if is_exit else ACTIVE_COLOR
		label.text = display_name()
		if closes_at > 0.0:
			label.text += "\n%.1f" % time_left()
	else:
		body_rect.color = IDLE_COLOR
		label.text = display_name()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and is_active():
		reached.emit(self)
