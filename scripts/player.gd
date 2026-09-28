extends CharacterBody2D

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

const ACCELERATION = 5000.0
const JUMP_VELOCITY = -1140.0
const DECELERATION = 2000.0
const BOOSTX = 1000.0
const BOOSTY = -1000.0
const MAX_SPEED = 400.0

# Jump feel: coyote time lets you still jump shortly after walking off a ledge,
# the jump buffer remembers a jump pressed shortly before landing, and letting
# go of jump early multiplies the upward speed by JUMP_CUT (shorter hop).
const COYOTE_TIME = 0.1
const JUMP_BUFFER_TIME = 0.12
const JUMP_CUT = 0.5

# Teleport: blinks sideways through force fields, stopped by solid walls.
const TELEPORT_DISTANCE = 160.0
const TELEPORT_COOLDOWN = 0.4
# Grapple: zoom to a GrapplePoint, then fly on with this speed.
const GRAPPLE_SPEED = 1400.0
const GRAPPLE_EXIT_SPEED = 750.0
# After a grapple, horizontal input is ignored this long so the momentum carries.
const GRAPPLE_MOMENTUM_TIME = 0.3
# Grav lifts: how fast the player's vertical speed turns into the lift's speed.
const LIFT_ACCELERATION = 3000.0
# Physics layer 1 = solid walls/floors. Layer 2 = force fields, which the
# player bumps into but can teleport through.
const SOLID_LAYER = 1
const FORCE_FIELD_LAYER = 2

var has_boost: bool = true
# Last horizontal direction the player pressed (-1 left, 1 right). Teleport
# and grapple aiming use it.
var last_input_direction := 1.0
var coyote_time_left := 0.0
var jump_buffer_left := 0.0
# True while rising from a real jump (not a boost or grapple), so only jumps get cut.
var is_jumping := false
var teleport_cooldown := 0.0
var aimed_point: GrapplePoint = null
var grapple_target: GrapplePoint = null
# The point last grappled to is skipped by auto-aim until you land or grapple
# elsewhere, so you don't re-target the point you're already at.
var last_grapple_point: GrapplePoint = null
var grapple_time_left := 0.0
var momentum_time_left := 0.0
var rope: Line2D
# Grav lifts the player is currently inside (see GravLift).
var lifts: Array[GravLift] = []

# Reference tilemap dynamically at runtime if needed
var tilemap: TileMapLayer

func _ready() -> void:
	print("player ready: ", get_path())
	# Safely fetch tilemap after level is instantiated into the tree
	tilemap = get_tree().get_first_node_in_group("tilemap")

	rope = Line2D.new()
	rope.top_level = true
	rope.width = 3.0
	rope.default_color = Color(1.0, 0.8, 0.4)
	rope.visible = false
	add_child(rope)

func _physics_process(delta: float) -> void:
	var input_direction := Input.get_axis("left", "right")
	if input_direction != 0.0:
		last_input_direction = signf(input_direction)
	jump_buffer_left = maxf(jump_buffer_left - delta, 0.0)
	if Input.is_action_just_pressed("jump"):
		jump_buffer_left = JUMP_BUFFER_TIME

	# 0. Grapple: while zooming to a point, nothing else applies
	_update_grapple_aim()
	if grapple_target:
		_process_grapple(delta)
		_update_animations()
		return
	if Input.is_action_just_pressed("grapple") and aimed_point and GameState.has_ability("grapple"):
		_start_grapple(aimed_point)
		return

	# 1. Apply Gravity (or a grav lift's pull)
	var lift := _active_lift()
	if lift:
		velocity.y = move_toward(velocity.y, -lift.speed, LIFT_ACCELERATION * delta)
	elif not is_on_floor():
		velocity += get_gravity() * delta
	if not is_on_floor():
		coyote_time_left = maxf(coyote_time_left - delta, 0.0)
	else:
		has_boost = true
		coyote_time_left = COYOTE_TIME
		last_grapple_point = null

	# 2. Handle Jump (buffered, with coyote time)
	if jump_buffer_left > 0.0 and coyote_time_left > 0.0 and GameState.has_ability("jump"):
		velocity.y = JUMP_VELOCITY
		jump_buffer_left = 0.0
		coyote_time_left = 0.0
		is_jumping = true
	if velocity.y >= 0.0:
		is_jumping = false
	# Variable height: releasing jump while rising cuts the jump short.
	if Input.is_action_just_released("jump") and is_jumping:
		velocity.y *= JUMP_CUT
		is_jumping = false

	# 3. Handle Boost
	if Input.is_action_just_pressed("boost") and has_boost and GameState.has_ability("boost"):
		velocity.y = BOOSTY
		# Straight up unless a direction is held.
		velocity.x = BOOSTX * signf(input_direction)
		has_boost = false
		is_jumping = false

	# 3b. Handle Teleport
	teleport_cooldown = maxf(teleport_cooldown - delta, 0.0)
	if Input.is_action_just_pressed("teleport") and teleport_cooldown == 0.0 and GameState.has_ability("teleport"):
		_teleport()

	# 4. Horizontal Movement (skipped briefly after a grapple to keep its momentum)
	momentum_time_left = maxf(momentum_time_left - delta, 0.0)
	if is_on_floor():
		momentum_time_left = 0.0
	var direction := Input.get_axis("left", "right")
	if momentum_time_left > 0.0:
		pass
	elif direction != 0.0:
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

func _teleport() -> void:
	var facing_direction := last_input_direction
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

func enter_lift(lift: GravLift) -> void:
	if not lift in lifts:
		lifts.append(lift)

func exit_lift(lift: GravLift) -> void:
	lifts.erase(lift)

func _active_lift() -> GravLift:
	for lift in lifts:
		if lift.should_lift(self):
			return lift
	return null

# World y of the bottom of the player's collision shape.
func get_foot_y() -> float:
	var shape_node: CollisionShape2D = $CollisionShape2D
	var capsule := shape_node.shape as CapsuleShape2D
	return shape_node.global_position.y + capsule.height / 2.0

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

# Auto-aim: pick the nearest usable grapple point, preferring points in the
# direction last pressed, and update every point's highlight.
func _update_grapple_aim() -> void:
	var unlocked := GameState.has_ability("grapple")
	var best: GrapplePoint = null
	var best_distance := INF
	for point: GrapplePoint in get_tree().get_nodes_in_group("grapple_points"):
		if not unlocked:
			point.state = GrapplePoint.State.LOCKED
			continue
		if global_position.distance_to(point.global_position) > GrapplePoint.RANGE \
				or not _has_line_of_sight(point.global_position):
			point.state = GrapplePoint.State.OUT_OF_RANGE
			continue
		point.state = GrapplePoint.State.IN_RANGE
		if point == last_grapple_point:
			continue
		var d := global_position.distance_to(point.global_position)
		# Points behind you only win if nothing is ahead.
		if (point.global_position.x - global_position.x) * last_input_direction < -16.0:
			d += GrapplePoint.RANGE
		if d < best_distance:
			best_distance = d
			best = point
	aimed_point = best
	if best and not grapple_target:
		best.state = GrapplePoint.State.AIMED
	if grapple_target:
		grapple_target.state = GrapplePoint.State.AIMED

func _has_line_of_sight(target: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(
			global_position, target, SOLID_LAYER | FORCE_FIELD_LAYER, [get_rid()])
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _start_grapple(point: GrapplePoint) -> void:
	grapple_target = point
	last_grapple_point = point
	is_jumping = false
	var distance := global_position.distance_to(point.global_position)
	grapple_time_left = distance / GRAPPLE_SPEED + 0.25
	rope.visible = true

func _process_grapple(delta: float) -> void:
	var to_target := grapple_target.global_position - global_position
	var direction := to_target.normalized()
	rope.points = PackedVector2Array([global_position, grapple_target.global_position])
	grapple_time_left -= delta

	if to_target.length() <= GRAPPLE_SPEED * delta:
		# Arrived: launch onward in the same direction.
		move_and_collide(to_target)
		velocity = direction * GRAPPLE_EXIT_SPEED
		momentum_time_left = GRAPPLE_MOMENTUM_TIME
		has_boost = true
		_end_grapple()
		return

	velocity = direction * GRAPPLE_SPEED
	move_and_slide()
	# Blocked by a wall, or taking too long: let go.
	if get_real_velocity().length() < GRAPPLE_SPEED * 0.5 or grapple_time_left <= 0.0:
		_end_grapple()

func _end_grapple() -> void:
	grapple_target = null
	rope.visible = false
