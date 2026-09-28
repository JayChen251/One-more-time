extends CharacterBody2D

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

const ACCELERATION = 5000.0
const JUMP_VELOCITY = -650.0
const DECELERATION = 2000.0
const BOOSTX = 1000.0
const BOOSTY = -1000.0
const MAX_SPEED = 400.0
const TELEPORT_DISTANCE = 160.0
const TELEPORT_COOLDOWN = 0.4
# Physics layer 1 = solid walls/floors. Layer 2 = force fields, which the
# player bumps into but can teleport through.
const SOLID_LAYER = 1
const FORCE_FIELD_LAYER = 2

var has_boost: bool = true
# Last horizontal direction the player pressed (-1 left, 1 right). Boost uses it.
var facing_direction := 1.0
var teleport_cooldown := 0.0

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
	var direction := Input.get_axis("left", "right")
	if direction != 0.0:
		facing_direction = signf(direction)
	if Input.is_action_just_pressed("boost") and has_boost and GameState.has_ability("boost"):
		velocity.y = BOOSTY
		velocity.x = BOOSTX * facing_direction
		has_boost = false

	# 3b. Handle Teleport
	teleport_cooldown = maxf(teleport_cooldown - delta, 0.0)
	if Input.is_action_just_pressed("teleport") and teleport_cooldown == 0.0 and GameState.has_ability("teleport"):
		_teleport()

	# 4. Horizontal Movement
	if direction != 0.0:
		velocity.x = move_toward(velocity.x, direction * MAX_SPEED, ACCELERATION * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, DECELERATION * delta)

	# 5. Execute Movement
	move_and_slide()

	# 6. Update Animations
	_update_animations()

func _teleport() -> void:
	var shape_node: CollisionShape2D = $CollisionShape2D
	var space := get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape_node.shape
	# Test from slightly above where we stand, so touching the floor
	# doesn't count as being stuck in it.
	var start := shape_node.global_transform.translated(Vector2(0, -2))
	query.transform = start
	query.exclude = [get_rid()]

	# How far can we go before hitting a solid wall? Force fields are ignored.
	query.collision_mask = SOLID_LAYER
	query.motion = Vector2(facing_direction * TELEPORT_DISTANCE, 0)
	var safe_fraction: float = space.cast_motion(query)[0]
	var offset := query.motion * safe_fraction

	# Don't land inside a force field: back up until the spot is clear.
	query.motion = Vector2.ZERO
	query.collision_mask = SOLID_LAYER | FORCE_FIELD_LAYER
	while absf(offset.x) > 1.0:
		query.transform = start.translated(offset)
		if space.intersect_shape(query, 1).is_empty():
			break
		offset.x -= facing_direction * 4.0
	if absf(offset.x) <= 1.0:
		return

	_spawn_afterimage()
	global_position += offset + Vector2(0, -2)
	velocity.y = 0.0
	teleport_cooldown = TELEPORT_COOLDOWN


func _spawn_afterimage() -> void:
	var ghost := Sprite2D.new()
	ghost.texture = animated_sprite_2d.sprite_frames.get_frame_texture(
			animated_sprite_2d.animation, animated_sprite_2d.frame)
	ghost.flip_h = animated_sprite_2d.flip_h
	ghost.scale = animated_sprite_2d.scale
	ghost.global_position = animated_sprite_2d.global_position
	ghost.modulate = Color(0.4, 0.9, 1.0, 0.8)
	get_parent().add_child(ghost)
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.3)
	tween.tween_callback(ghost.queue_free)


func _update_animations() -> void:
	animated_sprite_2d.flip_h = facing_direction < 0
	if not is_on_floor():
		if velocity.y < -100:
			animated_sprite_2d.animation = "rising"
		elif velocity.y > 100:
			animated_sprite_2d.animation = "falling"
		else:
			animated_sprite_2d.animation = "peaking"
	else:
		if velocity.x != 0:
			animated_sprite_2d.animation = "run"
		else:
			animated_sprite_2d.animation = "idle"
