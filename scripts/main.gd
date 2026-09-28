extends Node2D
## Runs one attempt: counts down the self-destruct timer, ends the run when the
## player reaches a gate or the ship explodes, then reloads the scene for
## "one more time". Persistent progress lives in the GameState autoload.

## Seconds until the ship explodes. This is the whole difficulty knob:
## gates further away need better abilities to reach in time.
@export var self_destruct_time := 20.0
## Seconds the "unlocked" / "boom" message stays up before the next run.
@export var between_runs_delay := 2.0

## Key shown when an ability is unlocked. Keep in sync with the Input Map.
const ABILITY_KEYS := {"jump": "SPACE / W", "boost": "J", "teleport": "K",
		"grapple": "LEFT MOUSE (aim with the cursor)"}

@onready var player: CharacterBody2D = $player
@onready var self_destruct: Timer = $SelfDestruct
@onready var timer_label: Label = $HUD/TimerLabel
@onready var run_label: Label = $HUD/RunLabel
@onready var message_label: Label = $HUD/MessageLabel
@onready var flash: ColorRect = $HUD/Flash

var run_over := false
var game_won := false


func _ready() -> void:
	for gate in get_tree().get_nodes_in_group("gates"):
		gate.reached.connect(_on_gate_reached)
	self_destruct.timeout.connect(_on_self_destruct)
	self_destruct.start(self_destruct_time)

	run_label.text = "RUN #%d\n%s" % [GameState.run_count, _ability_summary()]
	_show_message("RUN #%d" % GameState.run_count)
	await get_tree().create_timer(1.5).timeout
	if not run_over:
		_show_message("")


func _process(_delta: float) -> void:
	if game_won:
		return
	var t := self_destruct.time_left
	timer_label.text = "SELF-DESTRUCT  %05.2f" % t
	timer_label.modulate = Color.RED if t < 5.0 else Color.WHITE


func _unhandled_input(event: InputEvent) -> void:
	if game_won and event.is_action_pressed("jump"):
		GameState.reset()
		get_tree().reload_current_scene()
	elif not run_over and event.is_action_pressed("restart"):
		_on_self_destruct()


func _on_gate_reached(gate: Gate) -> void:
	if run_over:
		return
	var time_used := self_destruct_time - self_destruct.time_left
	_end_run()

	if gate.is_exit:
		game_won = true
		timer_label.text = "ESCAPED WITH %.2fs TO SPARE" % self_destruct.time_left
		_show_message("YOU ESCAPED!\nin %d runs\n\npress JUMP to play again" % GameState.run_count)
		return

	GameState.unlock(gate.unlocks)
	_show_message("%s UNLOCKED  (%.2fs)\npress %s\n\none more time..." % [
			gate.unlocks.to_upper(), time_used, ABILITY_KEYS.get(gate.unlocks, "?")])
	await get_tree().create_timer(between_runs_delay).timeout
	_next_run()


func _on_self_destruct() -> void:
	if run_over:
		return
	_end_run()
	_show_message("BOOM\none more time...")
	var tween := create_tween()
	tween.tween_property(flash, "color:a", 1.0, 0.15)
	tween.tween_property(flash, "color:a", 0.0, between_runs_delay - 0.15)
	await tween.finished
	_next_run()


func _end_run() -> void:
	run_over = true
	self_destruct.paused = true
	player.set_physics_process(false)


func _next_run() -> void:
	GameState.run_count += 1
	get_tree().reload_current_scene()


func _show_message(text: String) -> void:
	message_label.text = text


func _ability_summary() -> String:
	var owned: Array[String] = []
	for ability in GameState.ABILITY_ORDER:
		if GameState.has_ability(ability):
			owned.append(ability.to_upper())
	return "abilities: " + ("none" if owned.is_empty() else ", ".join(owned))
