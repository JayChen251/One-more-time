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
@export var escape_drift := Vector2(300, -900)

## Key shown when an ability is unlocked. Keep in sync with the Input Map.
const ABILITY_KEYS := {"jump": "SPACE", "boost": "JUMP again in the air", "teleport": "K",
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
# Alarm: the whole level pulses red with a beep, faster as time runs out.
var alarm: CanvasModulate
var beep: AudioStreamPlayer
var beep_timer := 0.0
var alarm_pulse := 0.0
# Screen shake (seconds left, strength in px).
var shake_time := 0.0
var shake_strength := 0.0


func _ready() -> void:
	var spawn := get_tree().get_first_node_in_group("player_spawn") as Node2D
	if spawn:
		player.global_position = spawn.global_position
	_limit_camera_to_level()
	for gate: Gate in get_tree().get_nodes_in_group("gates"):
		gates.append(gate)
		gate.reached.connect(_on_gate_reached)
	self_destruct.timeout.connect(_on_self_destruct)
	self_destruct.start(self_destruct_time)
	timer_label.visible = false
	alarm = CanvasModulate.new()
	add_child(alarm)
	beep = AudioStreamPlayer.new()
	beep.stream = _make_beep()
	beep.volume_db = -28.0
	add_child(beep)

	GameState.fade_music(GameState.MUSIC_VOLUME_DB, 1.0)   # back up after an ending
	run_header = "RUN #%d" % GameState.run_count
	run_label.text = run_header
	_show_message("RUN #%d" % GameState.run_count)
	await get_tree().create_timer(1.5).timeout
	if not run_over:
		_show_message("")


func _process(delta: float) -> void:
	_update_shake(delta)
	if game_won:
		alarm.color = Color.WHITE
		return
	var t := self_destruct.time_left
	if run_over:
		return
	_update_alarm(delta, t)
	var escape_line := get_tree().get_first_node_in_group("escape_line") as Node2D
	if escape_line and GameState.next_ability() == "" \
			and player.global_position.y < escape_line.global_position.y:
		_escape()
		return
	var elapsed := self_destruct_time - t
	for gate in gates:
		gate.set_clock(elapsed)
	for hatch: Hatch in get_tree().get_nodes_in_group("hatches"):
		hatch.set_clock(elapsed)


# Beeps get faster (every 1.6s down to every 0.15s) and the red flash
# stronger as the self-destruct counts down.
func _update_alarm(delta: float, time_left: float) -> void:
	var urgency := 1.0 - clampf(time_left / self_destruct_time, 0.0, 1.0)
	beep_timer -= delta
	if beep_timer <= 0.0:
		beep_timer = lerpf(1.6, 0.15, urgency * urgency)
		alarm_pulse = 1.0
		beep.pitch_scale = lerpf(1.0, 1.6, urgency)
		beep.play()
	alarm_pulse = maxf(alarm_pulse - delta * 5.0, 0.0)
	var strength := lerpf(0.25, 0.7, urgency)
	alarm.color = Color.WHITE.lerp(Color(1.0, 0.3, 0.3), alarm_pulse * strength)


# A short square-ish beep, generated so there's no sound file to import.
func _make_beep() -> AudioStreamWAV:
	var rate := 22050
	var length := int(rate * 0.09)
	var data := PackedByteArray()
	data.resize(length * 2)
	for i in length:
		var envelope := 1.0 - float(i) / length
		var sample := signf(sin(TAU * 880.0 * i / rate)) * 0.35 * envelope
		data.encode_s16(i * 2, int(sample * 32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	return wav

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
	if gate.is_exit:
		_escape()
		return
	var time_used := self_destruct_time - self_destruct.time_left
	_end_run()

	GameState.unlock(gate.unlocks)
	Sfx.play(self, "unlock")
	var color: Color = AbilityIcons.COLORS.get(gate.unlocks, Color.WHITE)
	Sparks.spawn(self, gate.global_position + Vector2(0, -40), color, 40, true, 1.3)
	Sparks.spawn(self, gate.global_position + Vector2(0, -40), Color.WHITE, 16, true, 0.8)
	_show_message("%s UNLOCKED  (%.2fs)\npress %s\n\none more time..." % [
			gate.unlocks.to_upper(), time_used, ABILITY_KEYS.get(gate.unlocks, "?")])
	await get_tree().create_timer(between_runs_delay).timeout
	_next_run()


# The player made it out: crossed the escape line with every ability.
func _escape() -> void:
	if run_over:
		return
	_end_run()
	game_won = true
	GameState.fade_music(-60.0, 4.0)
	timer_label.text = "ESCAPED WITH %.2fs TO SPARE" % self_destruct.time_left
	await _play_escape_cutscene()
	_show_message("YOU ESCAPED!\nin %d runs\n\npress JUMP to play again" % GameState.run_count)
	can_restart = true


func _on_self_destruct() -> void:
	if run_over:
		return
	_end_run()
	# The ship blows up around the player, like in the ending.
	await _explode_ship(18, 0.06)
	_show_message("one more time...")
	await get_tree().create_timer(between_runs_delay - 0.9).timeout
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
	# Let the camera follow the player out past the hull.
	camera.limit_left = -10000000
	camera.limit_top = -10000000
	camera.limit_right = 10000000
	camera.limit_bottom = 10000000

	var drift := create_tween().set_parallel()
	drift.tween_property(player, "global_position", player.global_position + escape_drift, 7.0) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	drift.tween_property(player, "rotation", TAU * 1.5, 7.0) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	drift.tween_property(camera, "zoom", camera.zoom * 0.6, 3.0)
	await get_tree().create_timer(1.2).timeout

	# The ship blows up behind the player while the camera pulls back.
	await _explode_ship(36, 0.09)


# Blasts all over the part of the ship that's on screen, the ship going dark,
# then a final flash and shake. Used both when you lose and in the ending.
func _explode_ship(blasts: int, interval: float) -> void:
	var camera: Camera2D = player.get_node("Camera2D")
	var ship_rect := _ship_rect()
	var level_parts: Array[CanvasItem] = []
	var level := get_tree().get_first_node_in_group("level")
	if level:
		for child in level.get_children():
			if child is CanvasItem and child.name != "Starfield":
				level_parts.append(child)
	for i in blasts:
		var area := _camera_view(camera).intersection(ship_rect)
		if area.has_area():
			var at := area.position + Vector2(randf() * area.size.x, randf() * area.size.y)
			Explosion.spawn(self, at, randf_range(1.2, 2.6), -16.0)
		_shake(0.4, 10.0 + 10.0 * i / blasts)
		var dim := lerpf(1.0, 0.3, float(i) / blasts)
		for part in level_parts:
			part.modulate = Color(dim, dim * 0.6, dim * 0.55)
		await get_tree().create_timer(interval).timeout
	var boom := create_tween()
	boom.tween_property(flash, "color:a", 1.0, 0.1)
	boom.tween_property(flash, "color:a", 0.0, 1.2)
	_shake(1.0, 26.0)
	await boom.finished


# The world-space rectangle the tilemap covers (the whole ship).
func _ship_rect() -> Rect2:
	var tilemap := get_tree().get_first_node_in_group("tilemap") as TileMapLayer
	if not tilemap:
		return Rect2()
	var used := tilemap.get_used_rect()
	var cell := Vector2(tilemap.tile_set.tile_size) * tilemap.global_scale
	return Rect2(tilemap.global_position + Vector2(used.position) * cell, Vector2(used.size) * cell)


# The world-space rectangle the camera currently shows.
func _camera_view(camera: Camera2D) -> Rect2:
	var size := get_viewport_rect().size / camera.zoom
	return Rect2(camera.get_screen_center_position() - size / 2.0, size)


func _shake(duration: float, strength: float) -> void:
	shake_time = maxf(shake_time, duration)
	shake_strength = maxf(shake_strength if shake_time > 0.0 else 0.0, strength)


func _update_shake(delta: float) -> void:
	var camera: Camera2D = player.get_node("Camera2D")
	if shake_time <= 0.0:
		camera.offset = Vector2.ZERO
		shake_strength = 0.0
		return
	shake_time -= delta
	var amount := shake_strength * clampf(shake_time, 0.0, 1.0)
	camera.offset = Vector2(randf_range(-amount, amount), randf_range(-amount, amount))


# Keep the camera inside the level's tiles so it never shows the void
# outside the ship's walls.
func _limit_camera_to_level() -> void:
	var rect := _ship_rect()
	if not rect.has_area():
		return
	var camera: Camera2D = player.get_node("Camera2D")
	camera.limit_left = int(rect.position.x)
	camera.limit_top = int(rect.position.y)
	camera.limit_right = int(rect.end.x)
	camera.limit_bottom = int(rect.end.y)
	camera.reset_smoothing()


func _end_run() -> void:
	run_over = true
	self_destruct.paused = true
	player.set_physics_process(false)


func _next_run() -> void:
	GameState.run_count += 1
	get_tree().reload_current_scene()


func _show_message(text: String) -> void:
	message_label.text = text

