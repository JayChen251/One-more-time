extends CharacterBody2D

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

const ACCELERATION = 5000.0
const JUMP_VELOCITY = -650.0
const DECELERATION = 2000.0
const BOOSTX = 1000.0
const BOOSTY = -1000.0
const MAX_SPEED = 400.0

var has_boost: bool = true

# Reference tilemap dynamically at runtime if needed
var tilemap: TileMapLayer

func _ready() -> void:
	print("player ready: ", get_path())
	# Safely fetch tilemap after level is instantiated into the tree
	tilemap = get_tree().get_first_node_in_group("tilemap")

func _physics_process(delta: float) -> void:
	# 1. Apply Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		has_boost = true

	# 2. Handle Jump
	if Input.is_action_just_pressed("jump") and is_on_floor() and GameState.has_ability("jump"):
		velocity.y = JUMP_VELOCITY

	# 3. Handle Boost
	if Input.is_action_just_pressed("boost") and has_boost and GameState.has_ability("boost"):
		var facing_direction = -1.0 if animated_sprite_2d.flip_h else 1.0
		velocity.y = BOOSTY
		velocity.x = BOOSTX * facing_direction
		has_boost = false

	# 4. Horizontal Movement
	var direction := Input.get_axis("left", "right")
	if direction != 0.0:
		velocity.x = move_toward(velocity.x, direction * MAX_SPEED, ACCELERATION * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, DECELERATION * delta)

	# 5. Execute Movement
	move_and_slide()

	# 6. Update Animations
	_update_animations()

func _update_animations() -> void:
	if not is_on_floor():
		if velocity.y < -100:
			animated_sprite_2d.animation = "rising"
		elif velocity.y > 100:
			animated_sprite_2d.animation = "falling"
		else:
			animated_sprite_2d.animation = "peaking"
	else:
		if velocity.x != 0:
			animated_sprite_2d.flip_h = velocity.x < 0
			animated_sprite_2d.animation = "run"
		else:
			animated_sprite_2d.animation = "idle"
