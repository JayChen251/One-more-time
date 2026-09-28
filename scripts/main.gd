extends Node2D
## Runs one attempt: counts down the self-destruct timer, ends the run when the
## player reaches a gate or the ship explodes, then reloads the scene for
## "one more time". Persistent progress lives in the GameState autoload.

## Seconds until the ship explodes. Each gate also seals at its own
## `closes_at` time; this should be a bit longer than the latest of those.
@export var self_destruct_time := 25.0
## Seconds the "unlocked" / "boom" message stays up before the next run.
@export var between_runs_delay := 2.0
## How far (and which way) the player drifts out of the airlock in the ending.
@export var escape_drift := Vector2(900, -300)

## Key shown when an ability is unlocked. Keep in sync with the Input Map.
const ABILITY_KEYS := {"jump": "SPACE / W", "boost": "J", "teleport": "K",
		"grapple": "L"}

@onready var player: CharacterBody2D = $player
@onready var self_destruct: Timer = $SelfDestruct
@onready var timer_label: Label = $HUD/TimerLabel
@onready var run_label: Label = $HUD/RunLabel
@onready var message_label: Label = $HUD/MessageLabel
@onready var flash: ColorRect = $HUD/Flash

var run_over := false
var game_won := false
# True once the ending cutscene has finished and JUMP restarts the game.
var can_restart := false
var gates: Array[Gate] = []
var run_header := ""


func _ready() -> void:
	var spawn := get_tree().get_first_node_in_group("player_spawn") as Node2D
	if spawn:
		player.global_position = spawn.global_position
	for gate: Gate in get_tree().get_nodes_in_group("gates"):
		gates.append(gate)
		gate.reached.connect(_on_gate_reached)
	self_destruct.timeout.connect(_on_self_destruct)
	self_destruct.start(self_destruct_time)

	run_header = "RUN #%d\n%s" % [GameState.run_count, _ability_summary()]
	run_label.text = run_header
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
	if run_over:
		return
	var elapsed := self_destruct_time - t
	var target: Gate = null
	for gate in gates:
		gate.set_clock(elapsed)
		if gate.is_target():
			target = gate
	run_label.text = run_header
	if target:
		if target.is_open() and target.closes_at > 0.0:
			run_label.text += "\n%s gate seals in %.1f" % [target.display_name(), target.time_left()]
		elif not target.is_open():
			run_label.text += "\n%s gate SEALED" % target.display_name()


func _unhandled_input(event: InputEvent) -> void:
	if can_restart and event.is_action_pressed("jump"):
		GameState.reset()
		get_tree().reload_current_scene()
	elif not run_over and event.is_action_pressed("restart"):
		_on_self_destruct()
	elif OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo:
		_debug_set_abilities(event.keycode)


# Testing shortcut (editor/debug builds only): keys 1-5 restart the run with
# that many abilities: 1 = none, 2 = jump, 3 = +teleport, 4 = +boost, 5 = all.
func _debug_set_abilities(keycode: Key) -> void:
	var count := keycode - KEY_1
	if count < 0 or count > GameState.ABILITY_ORDER.size():
		return
	GameState.reset()
	for i in count:
		GameState.unlock(GameState.ABILITY_ORDER[i])
	get_tree().reload_current_scene()


func _on_gate_reached(gate: Gate) -> void:
	if run_over:
		return
	var time_used := self_destruct_time - self_destruct.time_left
	_end_run()

	if gate.is_exit:
		game_won = true
		timer_label.text = "ESCAPED WITH %.2fs TO SPARE" % self_destruct.time_left
		await _play_escape_cutscene()
		_show_message("YOU ESCAPED!\nin %d runs\n\npress JUMP to play again" % GameState.run_count)
		can_restart = true
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


# Ending: the airlock opens, the player drifts out into zero gravity, and the
# ship explodes behind them. The player has no control during this.
func _play_escape_cutscene() -> void:
	var sprite: AnimatedSprite2D = player.get_node("AnimatedSprite2D")
	var camera: Camera2D = player.get_node("Camera2D")
	var door := get_tree().get_first_node_in_group("airlock") as CanvasItem

	if door:
		var open := create_tween()
		open.tween_property(door, "modulate:a", 0.0, 0.5)
		await open.finished
	sprite.play("spinning")

	var drift := create_tween().set_parallel()
	drift.tween_property(player, "global_position", player.global_position + escape_drift, 7.0) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	drift.tween_property(player, "rotation", TAU * 1.5, 7.0) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	drift.tween_property(camera, "zoom", Vector2(0.5, 0.5), 3.0)
	await get_tree().create_timer(2.0).timeout

	# The ship blows up behind the player.
	var boom := create_tween()
	boom.tween_property(flash, "color:a", 1.0, 0.1)
	boom.tween_property(flash, "color:a", 0.0, 1.2)
	var ship := get_tree().get_first_node_in_group("tilemap") as CanvasItem
	if ship:
		ship.modulate = Color(0.35, 0.15, 0.1)
	await boom.finished


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
