extends Control
## HUD row showing the player's abilities as their unlock icons. Unlocked
## ones are drawn in colour; ones still to find are faint empty boxes.

const BOX := 14.0
const GAP := 3.0
const ICON_SCALE := 0.36         # icons are drawn ~30px across; shrink to fit


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	for i in GameState.ABILITY_ORDER.size():
		var ability: String = GameState.ABILITY_ORDER[i]
		var rect := Rect2(Vector2(i * (BOX + GAP), 0), Vector2(BOX, BOX))
		if GameState.has_ability(ability):
			var color: Color = AbilityIcons.COLORS[ability]
			draw_rect(rect, Color(color, 0.15))
			draw_rect(rect, color, false, 1.0)
			draw_set_transform(rect.get_center(), 0.0, Vector2.ONE * ICON_SCALE)
			AbilityIcons.draw(self, ability, Vector2.ZERO, color, 3.0)
			draw_set_transform(Vector2.ZERO)
		else:
			draw_rect(rect, Color(1, 1, 1, 0.2), false, 1.0)
