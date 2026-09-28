extends Control
## HUD row showing the player's abilities as their unlock icons. Unlocked
## ones are drawn in colour; ones still to find are faint empty boxes.

const BOX := 40.0
const GAP := 6.0


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	for i in GameState.ABILITY_ORDER.size():
		var ability: String = GameState.ABILITY_ORDER[i]
		var rect := Rect2(Vector2(i * (BOX + GAP), 0), Vector2(BOX, BOX))
		if GameState.has_ability(ability):
			var color: Color = AbilityIcons.COLORS[ability]
			draw_rect(rect, Color(color, 0.15))
			draw_rect(rect, color, false, 2.0)
			AbilityIcons.draw(self, ability, rect.get_center(), color, 3.0)
		else:
			draw_rect(rect, Color(1, 1, 1, 0.15), false, 2.0)
