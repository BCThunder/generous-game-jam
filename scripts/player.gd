extends CharacterBody2D

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

const DECELERATION = 400.0 # Rate at which the character slows down when not moving
const SPEED = 100.0 # Normal movement speed
const SPRINT_SPEED = 215.0 # Maximum sprinting speed
const SPRINT_ACCELERATION = 2.25 # How fast the speed ramps up when sprinting

const JUMP_START_VELOCITY = -150.0 # Initial jump velocity
const SPRINT_JUMP_VELOCITY = -200 # Additional upward velocity when sprinting

const JUMP_SUSTAIN_FORCE = -750.0 # Upward force while holding the jump button
const SPRINT_SUSTAIN_FORCE = -850

const MAX_JUMP_TIME = 0.3 # Max duration the jump can be held

const COYOTE_TIME = 0.2

var jump_time = 0.0 # Track how long the jump button is held
var current_speed = 0.0 # Tracks the current movement speed
var coyote_time_remaining = 0.0

var is_dead = false
var is_jumping = false
var is_sprinting = false

var _valid_direction = Vector2(0, 0) # Direction the player can move in


func _physics_process(delta: float) -> void:
	if !is_dead:
		handle_movement(delta)
	else:
		velocity += get_gravity() * delta
		# if is_on_floor():
		# 	animated_sprite_2d.play("death")
		
		
	move_and_slide()
	#print(velocity)
	

func handle_movement(delta: float) -> void:
	# Apply gravity when not on the floor
	if not is_on_floor():
		if coyote_time_remaining > 0.0:
			coyote_time_remaining = max(0.0, coyote_time_remaining - delta) # Countdown when in air
		velocity += get_gravity() * delta
	else:
		coyote_time_remaining = COYOTE_TIME

	# Handle jumping
	if Input.is_action_just_pressed("jump") and (is_on_floor() or coyote_time_remaining > 0):
		is_jumping = true
		jump_time = 0.0
		coyote_time_remaining = 0.0
		if is_sprinting:
			velocity.y = SPRINT_JUMP_VELOCITY * ((current_speed - SPEED) / (SPRINT_SPEED - SPEED))
		else:
			velocity.y = JUMP_START_VELOCITY # Start the jump

	if Input.is_action_pressed("jump") and is_jumping:
		jump_time += delta
		if jump_time <= MAX_JUMP_TIME:
			#velocity.y += (JUMP_SUSTAIN_FORCE + (SPRINT_JUMP_VELOCITY * (SPRINT_SPEED - SPEED) * 0.01)) * delta
			if is_sprinting:
				velocity.y += SPRINT_SUSTAIN_FORCE * ((current_speed - SPEED) / (SPRINT_SPEED - SPEED)) * delta
			else:
				velocity.y += JUMP_SUSTAIN_FORCE * delta

		else:
			is_jumping = false # Stop sustaining the jump after max time

	if Input.is_action_just_released("jump") or velocity.y > 0:
		is_jumping = false # Stop jumping when the button is released or falling

	# Get movement input and handle animations
	var direction = Input.get_axis("move_left", "move_right") # Using 'move left' and 'move right'

	# Sprinting logic
	if Input.is_action_pressed("sprint") and direction != 0: # Only sprint when moving
		if is_on_floor():
			current_speed = lerp(current_speed, SPRINT_SPEED, SPRINT_ACCELERATION * delta)
			is_sprinting = true
			# if !animation_player.is_playing() and current_speed >= SPEED + 50:
			# 	animation_player.play("Sprint")
			# 	animation_player.speed_scale = (4 - 0) * ((current_speed - SPEED) / (SPRINT_SPEED - SPEED))
	else:
		current_speed = lerp(current_speed, SPEED, SPRINT_ACCELERATION * delta)
		if !is_jumping:
			is_sprinting = false
			# animation_player.stop()
	# Flip character sprite based on direction
	if direction > 0:
		animated_sprite_2d.flip_h = false
	elif direction < 0:
		animated_sprite_2d.flip_h = true

	# Update animations based on state
	# if is_on_floor():
	# 	if direction == 0:
	# 		animated_sprite_2d.play("idle")
	# 	else:
	# 		animated_sprite_2d.play("run") # Use "run" for both running and sprinting
	# else:
	# 	animated_sprite_2d.play("jump")

	# Move the character
	if direction != 0:
		velocity.x = direction * current_speed
	else:
		# Apply faster deceleration when no direction is pressed
		velocity.x = move_toward(velocity.x, 0.0, DECELERATION * delta)


func on_death() -> void:
	print("on_death received")
	# animation_player.play("death")
	is_dead = true
	velocity = Vector2(0, JUMP_START_VELOCITY * 2)


func restrict_movement(valid_direction: Vector2) -> void:
	# Restrict movement that moves further away from the valid direction
	pass
