class_name UnlockCard
extends Control
## The "new ability" card shown when you pick up an unlock: a panel with the
## ability's icon, its name and the key to use it.

var ability := ""
var _t := 0.0
var _title: PixelText
var _hint: PixelText


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title = _make_text(2)
	_hint = _make_text(1)


func _make_text(pixel_scale: int) -> PixelText:
	var t := PixelText.new()
	t.pixel_scale = pixel_scale
	t.align = 1
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(t)
	return t


func show_ability(new_ability: String, title: String, hint: String) -> void:
	ability = new_ability
	_t = 0.0
	_title.text = title
	_hint.text = hint
	visible = true


func _process(delta: float) -> void:
	if not visible or ability == "":
		return
	_t += delta
	var centre := size / 2.0
	_title.position = Vector2(0, centre.y + 4)
	_title.size = Vector2(size.x, 20)
	_hint.position = Vector2(0, centre.y + 26)
	_hint.size = Vector2(size.x, 30)
	queue_redraw()


func _draw() -> void:
	if ability == "":
		return
	var color: Color = AbilityIcons.COLORS.get(ability, Color.WHITE)
	var grow := minf(_t / 0.15, 1.0)          # panel pops open
	var panel := Rect2(size / 2.0 - Vector2(110, 52) * grow, Vector2(220, 104) * grow)
	draw_rect(panel, Color(0.02, 0.02, 0.06, 0.92))
	draw_rect(panel, color, false, 1.0)
	if grow < 1.0:
		return
	var icon_centre := size / 2.0 + Vector2(0, -22 + sin(_t * 4.0) * 2.0)
	draw_circle(icon_centre, 18.0, Color(color, 0.15))
	AbilityIcons.draw(self, ability, icon_centre, color, 3.0)
