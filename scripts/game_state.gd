extends Node
## Autoload (registered as "GameState"). Survives scene reloads, so it holds
## everything that carries over from one run to the next.

## Abilities in the order they are unlocked. Add new ones (e.g. "grapple") here.
const ABILITY_ORDER := ["jump", "boost", "teleport", "grapple"]

var run_count := 1
var abilities := {}


func _ready() -> void:
	reset()


func reset() -> void:
	run_count = 1
	abilities.clear()
	for ability in ABILITY_ORDER:
		abilities[ability] = false


func has_ability(ability: String) -> bool:
	return abilities.get(ability, false)


func unlock(ability: String) -> void:
	abilities[ability] = true


## The next ability to unlock, or "" once everything is unlocked.
func next_ability() -> String:
	for ability in ABILITY_ORDER:
		if not has_ability(ability):
			return ability
	return ""
