class_name Gate
extends Area2D
## A gate the player runs into. It either unlocks an ability for the next run,
## or (if is_exit) it is the escape pod that wins the game.
## main.gd listens for the `reached` signal.

signal reached(gate: Gate)

## Ability this gate unlocks. Must match a name in GameState.ABILITY_ORDER.
@export var unlocks := "jump"
## Tick this for the final escape gate.
@export var is_exit := false

const ACTIVE_COLOR := Color(0.2, 0.9, 0.5, 0.8)
const EXIT_COLOR := Color(1.0, 0.8, 0.2, 0.9)
const USED_COLOR := Color(0.4, 0.4, 0.4, 0.4)

@onready var body_rect: ColorRect = $Body
@onready var label: Label = $Label


func _ready() -> void:
	add_to_group("gates")
	body_entered.connect(_on_body_entered)
	_refresh_look()


func is_active() -> bool:
	return is_exit or not GameState.has_ability(unlocks)


func _refresh_look() -> void:
	if is_exit:
		body_rect.color = EXIT_COLOR
		label.text = "EXIT"
	elif is_active():
		body_rect.color = ACTIVE_COLOR
		label.text = unlocks.to_upper()
	else:
		body_rect.color = USED_COLOR
		label.text = ""


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and is_active():
		reached.emit(self)
