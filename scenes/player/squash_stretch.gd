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
## Vertical velocity above this is considered "fast" (for stretch). Increase to require faster movement for stretch, decrease to trigger stretch at lower speeds.
@export var velocity_threshold := 20.0
## Vertical velocity below this is considered "apex" (for squash). Increase to make apex squash trigger at higher speeds, decrease for a tighter apex window.
@export var apex_threshold := 15.0

@export_category("Timers")
## Minimum time to hold apex squash, in seconds. Increase for a longer apex squash effect, decrease for a snappier transition.
@export var apex_min_time := 0.07
## Minimum time to hold land squash, in seconds. Increase for a longer squash on landing, decrease for a quicker recovery.
@export var land_min_time := 0.08

@export_category("Skew")
## Amount of sprite skew per horizontal velocity unit. Increase for more dramatic skew, decrease for subtler effect.
@export var skew_factor := 0.002
## Maximum allowed skew. Increase for more extreme skew, decrease to limit the effect.
@export var max_skew := 0.3

@export_category("Lerp")
## How quickly the scale transitions to its target (0-1, higher = faster). Increase for snappier squash/stretch, decrease for smoother, slower transitions.
@export var lerp_factor := 0.25

@export_category("Flip Tuning")
## Velocity needed to resist input flip. Increase to require more momentum to resist flipping, decrease to allow easier flipping against momentum.
@export var flip_velocity_threshold: float = 80.0
## Minimum velocity to consider for auto-flip. Increase to require more movement before auto-flipping, decrease to allow flipping at lower speeds.
@export var min_velocity_for_flip: float = 50.0
## Cooldown time (seconds) between allowed flips. Increase to prevent rapid flipping, decrease for more responsive flipping.
@export var flip_cooldown_time: float = 0.5
## Time window (seconds) to count input taps for forced flip. Increase to allow more time for taps, decrease to a stricter tap window.
@export var flip_tap_window: float = 0.5
## Number of taps needed within the window to force a flip against momentum. Increase to require more taps, decrease for easier forced flipping.
@export var flip_tap_count_required: int = 3

@export_category("Debug")
## Print squash & stretch state to the output. Enable for debugging state transitions.
@export var debug_state := false
## Print vertical & horizontal velocity to the output. Enable for debugging velocity values.
@export var debug_velocity := false
##Print if flipping is happening. Enable to see flip state changes.
@export var debug_flips := false

@export_category("State Toggles")
## Enable or disable stretch up effect.
@export var use_stretch_up := true
## Enable or disable stretch fall effect.
@export var use_stretch_fall := true
## Enable or disable squash apex effect.
@export var use_squash_apex := true
## Enable or disable squash land effect.
@export var use_squash_land := true

var state: SnsState = SnsState.IDLE
var last_v_vel = 0.0
var was_on_floor = true
var flip_cooldown_timer: Timer
var apex_timer_node: Timer
var land_timer_node: Timer
var flip_back_timer: Timer

var left_tap_times: Array = []
var right_tap_times: Array = []

var last_flip_input_dir: int = 0 # -1 for left, 1 for right, 0 for none

# Seconds to wait before allowing flip back to momentum
var flip_back_grace_time: float = 0.5
func _ready() -> void:
	flip_cooldown_timer = Timer.new()
	flip_cooldown_timer.one_shot = true
	flip_cooldown_timer.wait_time = flip_cooldown_time
	add_child(flip_cooldown_timer)

	apex_timer_node = Timer.new()
	apex_timer_node.one_shot = true
	apex_timer_node.wait_time = apex_min_time
	add_child(apex_timer_node)

	land_timer_node = Timer.new()
	land_timer_node.one_shot = true
	land_timer_node.wait_time = land_min_time
	add_child(land_timer_node)

	flip_back_timer = Timer.new()
	flip_back_timer.one_shot = true
	flip_back_timer.wait_time = flip_back_grace_time
	add_child(flip_back_timer)

func _physics_process(_delta: float) -> void:
	var parent = get_parent()
	var v_vel = parent.velocity.y
	var h_vel = parent.velocity.x
	var on_floor = parent.is_on_floor()
	var target_scale = Vector2(1, 1)

	# State logic
	if on_floor:
		if not was_on_floor and abs(last_v_vel) > velocity_threshold and use_squash_land:
			state = SnsState.SQUASH_LAND
			land_timer_node.start(land_min_time)
		elif state == SnsState.SQUASH_LAND and not land_timer_node.is_stopped():
			pass # Stay in squash land state
		else:
			state = SnsState.IDLE
		apex_timer_node.stop()
	elif abs(v_vel) <= apex_threshold and use_squash_apex:
		if state != SnsState.SQUASH_APEX:
			apex_timer_node.start(apex_min_time)
		state = SnsState.SQUASH_APEX
		target_scale = squash_apex
		land_timer_node.stop()
	elif v_vel < -velocity_threshold and use_stretch_up:
		state = SnsState.STRETCH_UP
		target_scale = stretch_up
		apex_timer_node.stop()
		land_timer_node.stop()
	elif v_vel > velocity_threshold and use_stretch_fall:
		state = SnsState.STRETCH_FALL
		target_scale = stretch_down
		apex_timer_node.stop()
		land_timer_node.stop()

	# Handle squash visuals for land and apex
	if state == SnsState.SQUASH_APEX and not apex_timer_node.is_stopped() and use_squash_apex:
		target_scale = squash_apex
	elif state == SnsState.SQUASH_APEX and apex_timer_node.is_stopped():
		if v_vel < -velocity_threshold and use_stretch_up:
			state = SnsState.STRETCH_UP
			target_scale = stretch_up
		elif v_vel > velocity_threshold and use_stretch_fall:
			state = SnsState.STRETCH_FALL
			target_scale = stretch_down
	elif state == SnsState.SQUASH_LAND and not land_timer_node.is_stopped() and use_squash_land:
		target_scale = squash_land
	elif state == SnsState.SQUASH_LAND and land_timer_node.is_stopped():
		state = SnsState.IDLE
		target_scale = Vector2(1, 1)

	scale = scale.lerp(target_scale, lerp_factor)

	skew = clamp(h_vel * skew_factor, -max_skew, max_skew)

	# Track tap times
	var now = Time.get_ticks_msec() / 1000.0 # seconds

	if Input.is_action_just_pressed("move_left"):
		left_tap_times.append(now)
	if Input.is_action_just_pressed("move_right"):
		right_tap_times.append(now)

	# Remove old taps outside the window
	while left_tap_times and now - left_tap_times[0] > flip_tap_window:
		left_tap_times.pop_front()
	while right_tap_times and now - right_tap_times[0] > flip_tap_window:
		right_tap_times.pop_front()

	# --- Sprite flipping logic based on velocity and input ---
	var input_left = Input.is_action_pressed("move_left")
	var input_right = Input.is_action_pressed("move_right")
	var input_dir = int(input_right) - int(input_left) # 1 for right, -1 for left, 0 for none
	var desired_flip_h = flip_h # default to current
	var fighting_momentum = false
	var can_flip_back = flip_back_timer.is_stopped()

	if input_left and not input_right:
		if h_vel > flip_velocity_threshold:
			fighting_momentum = true
			if left_tap_times.size() >= flip_tap_count_required and last_flip_input_dir != -1:
				desired_flip_h = true
				if flip_back_timer.is_stopped():
					flip_back_timer.start(flip_back_grace_time)
		elif abs(h_vel) <= flip_velocity_threshold:
			if last_flip_input_dir != -1:
				desired_flip_h = true
	elif input_right and not input_left:
		if h_vel < -flip_velocity_threshold:
			fighting_momentum = true
			if right_tap_times.size() >= flip_tap_count_required and last_flip_input_dir != 1:
				desired_flip_h = false
				if flip_back_timer.is_stopped():
					flip_back_timer.start(flip_back_grace_time)
		elif abs(h_vel) <= flip_velocity_threshold:
			if last_flip_input_dir != 1:
				desired_flip_h = false
	elif abs(h_vel) > min_velocity_for_flip:
		# Only allow flipping back to momentum direction if timer expired or no input
		if (can_flip_back or input_dir == 0):
			desired_flip_h = h_vel < 0

	# Only apply cooldown if fighting momentum; otherwise, allow instant flip
	if desired_flip_h != flip_h:
		if fighting_momentum:
			if flip_cooldown_timer.is_stopped():
				flip_h = desired_flip_h
				flip_cooldown_timer.start(flip_cooldown_time)
				last_flip_input_dir = input_dir
		else:
			flip_h = desired_flip_h
			last_flip_input_dir = input_dir
	# If no input, reset last_flip_input_dir so next tap/hold can flip again
	if input_dir == 0:
		last_flip_input_dir = 0
		if not flip_back_timer.is_stopped():
			flip_back_timer.stop()

	if debug_state:
		print("[Squash&Stretch] State:", state)
	if debug_velocity:
		print("[Squash&Stretch] v_vel:", v_vel, "h_vel:", h_vel)

	last_v_vel = v_vel
	was_on_floor = on_floor
