extends CanvasLayer
## Title screen, shown once when the game starts. Pauses the game until the
## player presses jump.

var _t := 0.0
var _overlay: ColorRect
var _prompt: PixelText
var _warning: PixelText


func _ready() -> void:
	if GameState.started:
		queue_free()
		return
	layer = 10
	# Laid out on a 480x270 canvas and drawn at 2x, like the HUD.
	scale = Vector2(2, 2)
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	_overlay = ColorRect.new()
	_overlay.color = Color(0.01, 0.01, 0.04, 0.88)
	_overlay.position = Vector2.ZERO
	_overlay.size = Vector2(480, 270)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	_add_text("ONE MORE TIME", 4, 70, Color(1, 0.96, 0.91))
	_warning = _add_text("SELF-DESTRUCT SEQUENCE INITIATED", 1, 112, Color(1, 0.3, 0.3))
	_prompt = _add_text("PRESS SPACE TO START", 1, 170, Color(1, 0.96, 0.91))
	_add_text("A/D MOVE     R RESTART RUN", 1, 240, Color(0.6, 0.62, 0.72))


func _add_text(text: String, pixel_scale: int, y: float, color: Color) -> PixelText:
	var t := PixelText.new()
	t.text = text
	t.pixel_scale = pixel_scale
	t.align = 1
	t.color = color
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.position = Vector2(0, y)
	t.size = Vector2(480, 40)
	_overlay.add_child(t)
	return t


func _process(delta: float) -> void:
	_t += delta
	_prompt.visible = fmod(_t, 1.0) < 0.65
	_warning.modulate.a = 0.6 + 0.4 * sin(_t * 6.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		GameState.started = true
		get_tree().paused = false
		Sfx.play(self, "unlock", 1.5, -6.0)
		var fade := create_tween()
		fade.tween_property(_overlay, "modulate:a", 0.0, 0.3)
		fade.tween_callback(queue_free)
		set_process_unhandled_input(false)
