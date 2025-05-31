extends AnimatedSprite2D

# Enum for squash and stretch states
enum SnsState {
	IDLE,
	STRETCH_UP,
	SQUASH_APEX,
	STRETCH_FALL,
	SQUASH_LAND
}

@export_category("Scales")
## Scale to use when stretching up (ascending fast)
@export var stretch_up := Vector2(0.8, 1.2)
## Scale to use when stretching down (descending fast)
@export var stretch_down := Vector2(0.8, 1.2)
## Scale to use when squashing at apex (vertical velocity ~ 0)
@export var squash_apex := Vector2(1.2, 0.8)
## Scale to use when squashing on landing
@export var squash_land := Vector2(1.3, 0.7)

@export_category("Thresholds")
## Vertical velocity above this is considered "fast" (for stretch)
@export var velocity_threshold := 20.0
## Vertical velocity below this is considered "apex" (for squash)
@export var apex_threshold := 15.0

@export_category("Timers")
## Minimum time to hold apex squash, in seconds
@export var apex_min_time := 0.07
## Minimum time to hold land squash, in seconds
@export var land_min_time := 0.08

@export_category("Skew")
## Amount of sprite skew per horizontal velocity unit
@export var skew_factor := 0.002
## Maximum allowed skew
@export var max_skew := 0.3

@export_category("Lerp")
## How quickly the scale transitions to its target (0-1, higher = faster)
@export var lerp_factor := 0.25

@export_category("Flip Tuning")
## Velocity needed to resist input flip
@export var flip_velocity_threshold: float = 20.0
## Minimum velocity to consider for auto-flip
@export var min_velocity_for_flip: float = 5.0

@export_category("Debug")
## Print squash & stretch state to the output
@export var debug_state := false
## Print vertical & horizontal velocity to the output
@export var debug_velocity := false

@export_category("State Toggles")
@export var use_stretch_up := true
@export var use_stretch_fall := true
@export var use_squash_apex := true
@export var use_squash_land := true

var state: SnsState = SnsState.IDLE
var apex_timer = 0.0
var land_timer = 0.0
var last_v_vel = 0.0
var was_on_floor = true

func _physics_process(delta: float) -> void:
	var parent = get_parent()
	var v_vel = parent.velocity.y
	var h_vel = parent.velocity.x
	var on_floor = parent.is_on_floor()
	var target_scale = Vector2(1, 1)

	# State logic
	if on_floor:
		if not was_on_floor and abs(last_v_vel) > velocity_threshold and use_squash_land:
			state = SnsState.SQUASH_LAND
			land_timer = land_min_time
		elif state == SnsState.SQUASH_LAND and land_timer > 0.0:
			land_timer -= delta
		else:
			state = SnsState.IDLE
		apex_timer = 0.0
	elif abs(v_vel) <= apex_threshold and use_squash_apex:
		if state != SnsState.SQUASH_APEX:
			apex_timer = 0.0
		state = SnsState.SQUASH_APEX
		target_scale = squash_apex
		apex_timer += delta
	elif v_vel < -velocity_threshold and use_stretch_up:
		state = SnsState.STRETCH_UP
		target_scale = stretch_up
		apex_timer = 0.0
		land_timer = 0.0
	elif v_vel > velocity_threshold and use_stretch_fall:
		state = SnsState.STRETCH_FALL
		target_scale = stretch_down
		apex_timer = 0.0
		land_timer = 0.0

	# Handle squash visuals for land and apex
	if state == SnsState.SQUASH_APEX and apex_timer < apex_min_time and use_squash_apex:
		target_scale = squash_apex
	elif state == SnsState.SQUASH_APEX and apex_timer >= apex_min_time:
		if v_vel < -velocity_threshold and use_stretch_up:
			state = SnsState.STRETCH_UP
			target_scale = stretch_up
		elif v_vel > velocity_threshold and use_stretch_fall:
			state = SnsState.STRETCH_FALL
			target_scale = stretch_down
	elif state == SnsState.SQUASH_LAND and land_timer > 0.0 and use_squash_land:
		target_scale = squash_land
	elif state == SnsState.SQUASH_LAND and land_timer <= 0.0:
		state = SnsState.IDLE
		target_scale = Vector2(1, 1)

	scale = scale.lerp(target_scale, lerp_factor)

	skew = clamp(h_vel * skew_factor, -max_skew, max_skew)

	# --- Sprite flipping logic based on velocity and input ---
	var input_left = Input.is_action_pressed("move_left")
	var input_right = Input.is_action_pressed("move_right")

	if input_left and not input_right:
		if h_vel > flip_velocity_threshold:
			# Moving right fast, don't flip yet
			flip_h = false
		else:
			# Moving left or slow, flip left
			flip_h = true
	elif input_right and not input_left:
		if h_vel < -flip_velocity_threshold:
			# Moving left fast, don't flip yet
			flip_h = true
		else:
			# Moving right or slow, flip right
			flip_h = false
	elif abs(h_vel) > min_velocity_for_flip:
		# No input, but moving: use velocity to flip
		flip_h = h_vel < 0
	# else: keep current flip_h (idle)

	if debug_state:
		print("[Squash&Stretch] State:", state)
	if debug_velocity:
		print("[Squash&Stretch] v_vel:", v_vel, "h_vel:", h_vel)

	last_v_vel = v_vel
	was_on_floor = on_floor
