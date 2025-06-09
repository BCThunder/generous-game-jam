# Handles player movement states, abilities, and environment interactions.

extends CharacterBody2D
class_name PlayerController

# region PlayerController Vars
# Movement Tuning
@export_category("Movement")
@export var run_speed: float = 200.0
@export var air_accel_multiplier: float = 5.0
@export var air_friction: float = 3.0
@export var tap_speed: float = 30.0
@export var tap_boost_duration: float = 0.05 # Duration in seconds for tap speed boost

# Gravity Tuning
@export_category("Gravity and Jumping")
@export var double_jump_enabled: bool = true
@export var max_jump_velocity: float = 300.0
@export var min_jump_velocity: float = 120.0
@export var jump_gravity_scale: float = 0.6
@export var fall_gravity_scale: float = 1.0
@export var down_hold_gravity_multiplier: float = 3.0
@export var coyote_time_duration: float = 0.2 # seconds of grace time

# Wall Sliding and Jumping
@export_category("Wall Sliding")
@export var wall_slide_enabled: bool = true
@export var wall_slide_speed: float = 100.0 # Speed at which the player slides down walls
@export var wall_jump_velocity: float = 200.0 # Velocity applied when jumping off a wall
@export var wall_jump_angle: float = 45.0 # Angle of the wall jump in degrees
@export var use_wall_jump_time_limit: bool = true # If true, limit wall jumps to a certain duration
@export var wall_slide_max_duration: float = 0.5 # Maximum time to slide on a wall before falling off
@export var can_double_jump_after_wall_jump: bool = true # Allow double jump after wall jump

# Ground & Slippery Tiles
@export_category("Ground & Slippery")
@export var ground_friction: float = 8.0
@export var slippery_acceleration_multiplier: float = 6.0
@export var tap_slippery_acceleration_multiplier: float = 2.0
@export var slippery_friction: float = 0.5


@export_category("Damage and Death")
@export var spike_grace_time: float = 0.08 # seconds (about 5 frames at 60fps)
@export var spike_jump_once: bool = true # If true, only allow one jump off spikes per contact
var spike_grace_timer: float = 0.0
var in_spike_grace: bool = false
var has_jumped_off_spikes: bool = false
@export var death_duration: float = 0.5 # seconds before respawn or death animation

# Environment
@export_category("Environment")
@export var ground_tilemap_layer_path: NodePath

# Abilities
@export_category("Launch Ability")
@export var launch_ability_scene: PackedScene
@export var launch_ability_enabled: bool = true

@export_category("Slam Ability")
@export var slam_abiility_enabled: bool = true
@export var slam_speed: float = 400.0 # Speed of the slam move
@export var slam_move_delay: float = 0.1 # Delay before slam move starts

# --- Destroy Ability ---
@export_category("Destroy Ability")
@export var destroy_ability_enabled: bool = true
@export var destroy_ability_cooldown: float = 0.3 # seconds
@export var destroy_ability_range: float = 32.0 # Raycast distance in pixels
@export_flags_2d_physics var destroy_ability_collision_mask
@export var destroy_ability_hit_from_inside: bool = true # Allow hit from inside
@export var destroy_ability_group: String = "breakable_rock" # Group name for breakable objects
@export var destroy_ability_chain_radius: float = 48.0 # Radius for chain breaking
@export var destroy_ability_chain_delay: float = 0.08 # Delay between chain breaks (seconds)
@export var destroy_ability_chain_depth: int = 2 # How many layers deep to chain break
var destroy_ability_timer: Timer

# Debug Flags
@export_category("Debug")
@export var debug_enabled: bool = false
@export var debug_dont_use_checkpoints: bool = false # Use checkpoint system for debugging
@export var debug_movement: bool = false
@export var debug_input_events: bool = false
@export var debug_jumps: bool = false
@export var debug_state_changes: bool = false
@export var debug_collisions: bool = false
@export var debug_death: bool = false
@export var debug_slam_ability: bool = false # Show slam ability in debug mode
@export var debug_destroy_ability: bool = false
@export var debug_destroy_ray: bool = false # Draw the destroy ray for debugging
@export var debug_wall_jump_direction: bool = false # Show wall jump direction in debug mode

# Sound Effects
@onready var walking_sfx: AudioStreamPlayer2D = $SFX/WalkingSFX
@onready var slam_sfx: AudioStreamPlayer2D = $SFX/SlamSFX
@onready var jump1_sfx: AudioStreamPlayer2D = $SFX/Jump1SFX
@onready var jump2_sfx: AudioStreamPlayer2D = $SFX/Jump2SFX
@onready var death_sfx: AudioStreamPlayer2D = $SFX/DeathSFX


# Animation
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

# Input Tracking
var input_x_direction: float = 0.0 # -1 for left, 1 for right, 0 for none
var previous_input_x_direction: float = 0.0 # Last input input_x_direction
var x_dir_just_pressed: bool = false # True if left/right was just pressed


# Context Flags
var current_state: PlayerState = null
var is_jump_held: bool = false
var has_jumped: bool = false
var can_double_jump: bool = false
var in_slam_zone: bool = false
var in_launch_zone: bool = false
var can_wall_slide: bool = false # Whether wall sliding is enabled

# Ability Reference
var launch_ability: Node2D = null

# Cached References
var ground_tilemap_layer: TileMapLayer

# Timers for duration-based effects
var tap_boost_timer: Timer
var coyote_timer_node: Timer
var spike_grace_timer_node: Timer # Timer node for spike grace
var wall_slide_timer: Timer # Timer for wall slide duration
# endregion

# region State Machine
# --- State Machine Base ---
class PlayerState:
	var player: PlayerController

	func _init(p_player: PlayerController) -> void:
		player = p_player

	func get_name() -> String:
		return "PlayerState"

	func enter() -> void:
		pass

	func exit() -> void:
		pass

	func input(_event: InputEvent) -> void:
		pass

	func physics(_delta: float) -> void:
		pass

# region --- Ground State ---
class GroundState extends PlayerState:
	func get_name() -> String:
		return "GroundState"
	func enter() -> void:
		# Reset jump flags on landing
		player.can_double_jump = false
		player.is_jump_held = false
		player.has_jumped = false
		player.can_wall_slide = player.wall_slide_enabled
		player.wall_slide_timer.stop()

		player.animated_sprite.play("default")

		if player.debug_enabled and player.debug_movement:
			print("Entered GroundState")

		# Stop coyote timer if running
		if not player.coyote_timer_node.is_stopped():
			player.coyote_timer_node.stop()

	func input(event: InputEvent) -> void:
		if event.is_action_pressed("jump"):
			if player.debug_enabled and player.debug_jumps:
				print("Jump pressed (Ground)")
			player._try_jump()
			
		if event.is_action_pressed("context_interact"):
			if GameManager.can_player_interact:
				player.interact()
			elif GameManager.water_threshold_met:
				SaveManager.teleport_to_top()
	
	func physics(delta: float) -> void:
		player._apply_gravity(delta)
		player._handle_ground_moves(delta)
		player.move_and_slide()
		player._collision_checker()
		if not player.is_on_floor():
			# Start coyote timer here!
			player.coyote_timer_node.start(player.coyote_time_duration)
			player._change_state(AirState)

# region --- Air State ---
class AirState extends PlayerState:
	func get_name() -> String:
		return "AirState"
	func enter() -> void:
		if player.debug_enabled and player.debug_movement:
			print("Entered AirState")
		player.can_double_jump = player.double_jump_enabled
		# Start coyote time if not already running

		if not player.wall_slide_timer.is_stopped():
			player.wall_slide_timer.paused = true

	func input(event: InputEvent) -> void:
		if event.is_action_pressed("jump"):
			if player.debug_enabled and player.debug_jumps:
				print("Jump pressed (Ground)")
			player._try_jump()

		# Handle Slam ability
		if player.slam_abiility_enabled and event.is_action_pressed("slam_ability"):
			if player.debug_enabled and player.debug_movement:
				print("Slam pressed (Air)")
			player._change_state(SlamState)
			player.slam_sfx.play()

		# Release jump for variable height
		if event.is_action_released("jump"):
			player.is_jump_held = false
			if player.velocity.y < -player.min_jump_velocity:
				player.velocity.y = - player.min_jump_velocity

	func physics(delta: float) -> void:
		if player.coyote_timer_node.is_stopped() or player.has_jumped:
			# If coyote timer is stopped, we can't jump anymore
			player._apply_gravity(delta)
		player._handle_air_moves(delta)
		player.move_and_slide()
		player._collision_checker()
		if player.is_on_floor():
			player._change_state(GroundState)
		elif player.can_wall_slide and player.is_on_wall_only() and player.input_x_direction != 0 and player.velocity.y > 0:
			# If on wall, switch to WallSlideState
			player._change_state(WallSlideState)

# region --- Wall Slide State ---
class WallSlideState extends PlayerState:
	func get_name() -> String:
		return "WallSlideState"

	var wall_dir = 0.0

	func enter() -> void:
		if player.debug_enabled and player.debug_movement:
			print("Entered WallSlideState")
		player.is_jump_held = false # Reset jump hold
		# Determine which side the wall is on (-1 = left wall, 1 = right wall)
		for i in range(player.get_slide_collision_count()):
			var coll = player.get_slide_collision(i)
			if coll and coll.get_normal().x != 0:
				wall_dir = - coll.get_normal().x
				break

		player.animated_sprite.play("wall_slide") # Play wall slide animation
		player.animated_sprite.flip_h = wall_dir > 0 # Flip sprite based on wall direction
		#player.animated_sprite.position.x = wall_dir * -7.0


		if player.wall_slide_timer:
			if player.wall_slide_timer.is_stopped():
				player.wall_slide_timer.start(player.wall_slide_max_duration)
			elif player.wall_slide_timer.time_left:
				player.wall_slide_timer.paused = false


	func input(event: InputEvent) -> void:
		if event.is_action_pressed("jump"):
			if player.debug_enabled and player.debug_jumps:
				print("Jump pressed (Wall Slide)")
			_try_wall_jump()

	func physics(_delta: float) -> void:
		player._updated_x_input()
		if player.is_on_floor():
			player._change_state(AirState)
			return
		if not player.is_on_wall_only() or (player.use_wall_jump_time_limit and player.wall_slide_timer.is_stopped()):
			player._change_state(AirState)
			return

		_handle_wall_slide()

		if not player.move_and_slide():
			if player.debug_enabled and player.debug_movement:
				print("WallSlideState: Player move_and_slide failed.")
			player._change_state(AirState)
			return
		player._collision_checker()

	func _handle_wall_slide():
		# Handle wall sliding logic
		if player.velocity.y == 0 or not player.is_on_wall_only() or (player.use_wall_jump_time_limit and player.wall_slide_timer.is_stopped()):
			# If wall slide timer is stopped, switch to AirState
			player._change_state(AirState)
			return

		# If still on wall, continue sliding
		# Optionally start sliding at a fixed speed
		if player.velocity.y >= 0:
			player.velocity.y = player.wall_slide_speed
			# if not player.input_x_direction:
			# 	# If no input, continue sliding down
			# 	player.velocity.x = wall_dir
		else:
			# If input is pressed, apply horizontal movement
			player.velocity.x = player.input_x_direction * player.run_speed * player.slippery_acceleration_multiplier
			if player.debug_enabled and player.debug_movement:
				print("Sliding on wall with velocity: ", player.velocity)


	func _try_wall_jump() -> void:
		if player.debug_enabled and player.debug_jumps:
			print("Wall jump attempt - can_double_jump: ", player.can_double_jump, ", wall_slide_timer.is_stopped(): ", player.wall_slide_timer.is_stopped())

		# If wall slide timer is running, allow wall jump
		player.velocity.y = - player.wall_jump_velocity
		player.velocity.x = - (wall_dir * player.wall_jump_velocity * cos(deg_to_rad(player.wall_jump_angle)))
		player.is_jump_held = true
		player.can_double_jump = player.can_double_jump_after_wall_jump
		player.has_jumped = true
		if player.debug_enabled and player.debug_jumps:
			print("Wall jump performed")

		if player.debug_enabled and player.debug_wall_jump_direction:
			# Draw debug line for wall jump direction
			var debug_line := Line2D.new()
			debug_line.width = 2.0
			debug_line.default_color = Color.RED
			# points are local to the player, so subtract global_position
			debug_line.points = [
				player.position - player.global_position,
				player.position + .2 * Vector2(player.velocity.x, player.velocity.y) - player.global_position
			]
			player.add_child(debug_line)
			await player.get_tree().create_timer(0.1).timeout
			debug_line.queue_free()
		if player.debug_enabled and player.debug_wall_jump_direction:
			print_debug("Wall jump performed with velocity: ", player.velocity, " wall_dir: ", wall_dir)

		player.play_jump_sfx()
		#await player.get_tree().create_timer(1).timeout # Small delay to allow jump effects
		player._change_state(AirState)

# region --- Slam State ---
class SlamState extends PlayerState:
	func get_name() -> String:
		return "SlamState"

	func enter() -> void:
		if player.debug_enabled and player.debug_movement:
			print("Entered SlamState")
		# Reset jump flags
		player.is_jump_held = false
		player.can_double_jump = false

	func physics(_delta: float) -> void:
		player.velocity.y = player.slam_speed
		player.velocity.x = 0.0 # Stop horizontal movement during slam

		# var collision: KinematicCollision2D = player.move_and_collide(player.velocity, false, 0.2, true)
		# player._collision_checker()
		# if collision:
		# 	if player.debug_enabled and player.debug_slam_ability:
		# 		print("Slam collided with: ", collision.get_collider().name)
		# 	# Check if we hit the ground
		# 	player.move_and_slide()
		# 	if player.is_on_floor():
		# 		# Small delay to allow landing effects
		# 		await player.get_tree().create_timer(player.slam_move_delay).timeout
		# 		player._change_state(GroundState)

		if player.move_and_slide():
			if player.debug_enabled and player.debug_slam_ability:
				print("SlamState: Player moved and slid successfully.")
			player.velocity.y = 0.0 # Stop vertical movement after sliding
			await player.get_tree().create_timer(player.slam_move_delay).timeout
			
			player._change_state(GroundState)


# region --- Destroy State ---
class DestroyState extends PlayerState:
	func get_name() -> String:
		return "DestroyState"

	func enter() -> void:
		if player.debug_enabled and player.debug_state_changes:
			print("Entered DestroyState")
		player.velocity = Vector2.ZERO
		player.set_process_input(true)
		# Optionally play destroy animation or feedback here
		player._try_destroy_ability()

	func input(event: InputEvent) -> void:
		if event.is_action_pressed("destroy_ability"):
			player._change_state(GroundState)

	func physics(_delta: float) -> void:
		# No movement during destroy
		pass

# region --- Death State ---
class DeathState extends PlayerState:
	func get_name() -> String:
		return "DeathState"

	func enter() -> void:
		if player.debug_enabled and player.debug_state_changes:
			print("Entered DeathState")
		
		
		# Stop all movement and input
		player.velocity = Vector2.ZERO
		player.set_process_input(false)
		# Optionally, play death animation, sound, or respawn logic here
		# Example: player._on_player_death()
		
		# Play Death SFX
		player.play_death_sfx()
		

		var tween = player.create_tween()
		tween.tween_property(player, "modulate:a", 0.0, player.death_duration)
		player.animation_player.play("fade_out") # Play fade out animation
		await tween.finished
		
		player.get_tree().reload_current_scene()

	func input(_event: InputEvent) -> void:
		pass

	func physics(_delta: float) -> void:
		# No movement in death state
		pass
# endregion

# region Ready

func _ready() -> void:
	_get_tilemap_layers()
	animation_player.play("fade_in") # fade in to hide "teleporting" to last save spot
	# Initialize player state
	if not (debug_enabled and debug_dont_use_checkpoints):
		# Use last saved position if available
		if SaveManager.last_location:
			position = SaveManager.last_location
			if debug_enabled:
				print_debug("Using last saved position: ", position)

	_init_launch_ability()

	# Add and configure tap boost timer
	tap_boost_timer = Timer.new()
	tap_boost_timer.one_shot = true
	tap_boost_timer.wait_time = tap_boost_duration
	add_child(tap_boost_timer)

	# Add and configure coyote time timer
	coyote_timer_node = Timer.new()
	coyote_timer_node.one_shot = true
	coyote_timer_node.wait_time = coyote_time_duration
	add_child(coyote_timer_node)

	# Add and configure spike grace timer
	spike_grace_timer_node = Timer.new()
	spike_grace_timer_node.one_shot = true
	spike_grace_timer_node.wait_time = spike_grace_time
	add_child(spike_grace_timer_node)
	spike_grace_timer_node.timeout.connect(_on_spike_grace_timeout)

	# Add and configure destroy ability timer
	destroy_ability_timer = Timer.new()
	destroy_ability_timer.one_shot = true
	destroy_ability_timer.wait_time = destroy_ability_cooldown
	add_child(destroy_ability_timer)

	# Add and configure wall slide timer
	wall_slide_timer = Timer.new()
	wall_slide_timer.one_shot = true
	wall_slide_timer.wait_time = wall_slide_max_duration
	add_child(wall_slide_timer)

	current_state = GroundState.new(self)
	current_state.enter()

	set_process_input(true)
	set_physics_process(true)

	_collision_checker()
	call_deferred("_connect_zone_signals")
# endregion


# region Defult Methods
func _input(event: InputEvent) -> void:
	if launch_ability and launch_ability.get("active"):
		launch_ability.call("input", event)
		return

	if in_launch_zone and launch_ability and event.is_action_pressed("context_interact"):
		launch_ability.call("start")
		return

	# Enter destroy state on input
	if event.is_action_pressed("destroy_ability"):
		_change_state(DestroyState)
		return

	current_state.input(event)

func _physics_process(delta: float) -> void:
	if launch_ability and launch_ability.get("active"):
		launch_ability.call("physics", delta)
	else:
		current_state.physics(delta)

	# Spike grace timer logic
	# No need to manually decrement timer, handled by Timer node
	if not in_spike_grace:
		spike_grace_timer_node.stop()
# endregion

# region State Transition
func _change_state(new_state_class) -> void:
	var prev_state = current_state
	current_state.exit()
	current_state = new_state_class.new(self)
	current_state.enter()

	#animated_sprite.position = Vector2.ZERO # Reset sprite offset on state change


	if debug_enabled and debug_state_changes:
		print_debug("State changed from ", prev_state.get_name(), " to ", current_state.get_name())
# endregion

# region Gravity & Movement Helpers
func _apply_gravity(delta: float) -> void:
	var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
	var grav_scale: float

	# Determine gravity grav_scale
	if velocity.y < 0 and is_jump_held:
		grav_scale = jump_gravity_scale
	else:
		grav_scale = fall_gravity_scale

	if Input.is_action_pressed("move_down"):
		grav_scale *= down_hold_gravity_multiplier

	velocity.y += gravity * grav_scale * delta

func _handle_ground_moves(delta: float) -> void:
	_updated_x_input()
	var is_slippery: bool = _is_on_slippery()

	# Tap boost logic
	if x_dir_just_pressed and input_x_direction != 0:
		tap_boost_timer.start(tap_boost_duration)

	if is_slippery:
		var accel: float = run_speed * slippery_acceleration_multiplier
		if input_x_direction != 0:
			if not tap_boost_timer.is_stopped():
				velocity.x += input_x_direction * tap_speed * delta * tap_slippery_acceleration_multiplier
			else:
				velocity.x += input_x_direction * accel * delta
		else:
			velocity.x = lerp(velocity.x, 0.0, slippery_friction * delta)
	else:
		if input_x_direction != 0:
			if not tap_boost_timer.is_stopped():
				velocity.x = input_x_direction * tap_speed
			else:
				velocity.x = input_x_direction * run_speed
				
			play_walking_sfx()
		else:
			velocity.x = lerp(velocity.x, 0.0, ground_friction * delta)

	velocity.x = clamp(velocity.x, -run_speed, run_speed)
	
func play_walking_sfx():
	if walking_sfx.playing == false:
		walking_sfx.pitch_scale = randf_range(.8, 1.2)
		walking_sfx.play()

func _handle_air_moves(delta: float) -> void:
	_updated_x_input()
	if input_x_direction != 0:
		velocity.x += input_x_direction * run_speed * air_accel_multiplier * delta
	else:
		velocity.x = lerp(velocity.x, 0.0, air_friction * delta)

	velocity.x = clamp(velocity.x, -run_speed, run_speed)

# endregion

# region Launch Ability & Zones
func _init_launch_ability() -> void:
	for child in get_children():
		if child is Node2D and child.has_method("start"):
			launch_ability = child
			return

	if launch_ability_scene:
		launch_ability = launch_ability_scene.instantiate()
		add_child(launch_ability)
	elif debug_input_events:
		push_error("No LaunchAbility configured; launch disabled.")

func _connect_zone_signals() -> void:
	for zone in get_tree().get_nodes_in_group("SlamZones"):
		zone.connect("body_entered", Callable(self, "_on_slam_zone_entered"))
		zone.connect("body_exited", Callable(self, "_on_slam_zone_exited"))
	for zone in get_tree().get_nodes_in_group("LaunchZones"):
		zone.connect("body_entered", Callable(self, "_on_launch_zone_entered"))
		zone.connect("body_exited", Callable(self, "_on_launch_zone_exited"))
# endregion

# region Jump
func _try_jump() -> void:
	if debug_enabled and debug_jumps:
		print_debug("Jump attempt - is_jump_held: ", is_jump_held, ", can_double_jump: ", can_double_jump, ", double_jump_enabled: ", double_jump_enabled, ", in_spike_grace: ", in_spike_grace, ", spike_jump_once: ", spike_jump_once, ", has_jumped_off_spikes: ", has_jumped_off_spikes, ", coyote_timer_node.is_stopped(): ", coyote_timer_node.is_stopped())

	# --- FLOOR JUMP ---
	if is_on_floor():
		velocity.y = - max_jump_velocity
		is_jump_held = true
		can_double_jump = double_jump_enabled
		coyote_timer_node.stop()
		has_jumped = true
		if debug_enabled and debug_jumps:
			print_debug("Floor jump")
		play_jump_sfx()
		return

	# --- COYOTE JUMP ---
	if not coyote_timer_node.is_stopped() and not has_jumped:
		velocity.y = - max_jump_velocity
		is_jump_held = true
		can_double_jump = double_jump_enabled
		coyote_timer_node.stop()
		has_jumped = true
		if debug_enabled and debug_jumps:
			print_debug("Coyote jump")
		play_jump_sfx()
		return

	# --- SPIKE GRACE JUMP ---
	if in_spike_grace and (not spike_jump_once or not has_jumped_off_spikes):
		velocity.y = - max_jump_velocity
		is_jump_held = true
		can_double_jump = double_jump_enabled
		has_jumped_off_spikes = true
		has_jumped = true
		if debug_enabled and debug_jumps:
			print_debug("Spike grace jump")
		play_jump_sfx()
		return

	# --- DOUBLE JUMP ---
	if double_jump_enabled and can_double_jump:
		velocity.y = - max_jump_velocity
		is_jump_held = true
		can_double_jump = false
		has_jumped = true
		if debug_enabled and debug_jumps:
			print_debug("Double jump")
		play_jump_sfx()
		return

func play_jump_sfx():
	var pitch = randf_range(.8, 1.2)
	var randomize_jump = randi_range(1, 2)
	match randomize_jump:
		1:
			jump1_sfx.pitch_scale = pitch
			jump1_sfx.play()
		_:
			jump2_sfx.pitch_scale = pitch
			jump2_sfx.play()

func play_animation(animation_name: String):
	animation_player.play(animation_name)
	
func is_animation_finished():
	return animation_player.animation_finished

func interact():
	GameManager.interact_with_npc()


func play_death_sfx():
	walking_sfx.stop()
	jump1_sfx.stop()
	jump2_sfx.stop()
	slam_sfx.stop()
	death_sfx.play(2.0 - death_duration)

# endregion

# region Destroy Ability
# Cast a short ray in facing direction to detect breakable rocks
func _try_destroy_ability() -> void:
	if debug_enabled and debug_state_changes:
		print_debug("Destroy ability triggered.")
	# Use the most recent input direction for the destroy ray
	var ray_origin: Vector2 = global_position
	var ray_end: Vector2 = ray_origin + Vector2(previous_input_x_direction * destroy_ability_range, 0) # Use exported range\
	var space = get_world_2d().direct_space_state
	var params = PhysicsRayQueryParameters2D.create(ray_origin, ray_end)
	if debug_enabled and debug_destroy_ray:
		# create a red debug line
		var debug_line := Line2D.new()
		debug_line.width = 2.0
		debug_line.default_color = Color.RED
		# points are local to the player, so subtract global_position
		debug_line.points = [
			ray_origin - global_position,
			ray_end - global_position
		]
		add_child(debug_line)
		# remove it shortly after
		await get_tree().create_timer(0.1).timeout
		debug_line.queue_free()
	params.exclude = [self]
	params.collision_mask = destroy_ability_collision_mask
	params.hit_from_inside = destroy_ability_hit_from_inside
	var result = space.intersect_ray(params)
	if result and result.collider and result.collider.is_in_group(destroy_ability_group):
		if debug_enabled and debug_state_changes:
			print("Destroying rock: ", result.collider.name)
		if debug_enabled and debug_destroy_ability:
			print_debug("Destroying rock: ", result.collider.name)
		# Break the initial object and start chain break


		if is_on_floor():
			_change_state(GroundState)
		else:
			_change_state(AirState)

		_chain_destroy(result.collider, global_position, 0)
		# Optionally play effect or sound here
	else:
		if debug_enabled and debug_state_changes:
			print("No breakable rock detected.")
		if debug_enabled and debug_destroy_ability:
			print_debug("No breakable rock detected.")

		if is_on_floor():
			_change_state(GroundState)
		else:
			_change_state(AirState)

# Progressive chain break with delay for surrounding objects
func _chain_destroy(center_obj: Node, center_pos: Vector2, depth: int) -> void:
	if debug_enabled and debug_destroy_ability:
		print_debug("Chain destroy called on: ", center_obj.name, " at depth: ", depth)
	if not center_obj:
		return
	# Optionally play destroy animation or effect
		#destroy_ability_timer.start(destroy_ability_cooldown)
	if debug_enabled and debug_state_changes:
		print("Destroy ability used on: ", center_obj.name)
		print_debug("Destroy ability used on: ", center_obj.name)
	if depth >= destroy_ability_chain_depth:
		return
	
	center_obj.get_node("Sprite2D/ShardEmitter").call_deferred("shatter") # Assuming the destructible has a ShardEmitter child

	# Use overlap shape (circle) to find only nearby destructibles
	var space = get_world_2d().direct_space_state
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = destroy_ability_chain_radius * (1 + depth) # Increase radius with depth
	var query = PhysicsShapeQueryParameters2D.new()
	query.shape = circle_shape
	query.transform = Transform2D(0, center_pos)
	query.exclude = [center_obj]
	query.collision_mask = destroy_ability_collision_mask
	query.margin = -0.01
	var results = space.intersect_shape(query)
	for result in results:
		if debug_enabled and debug_destroy_ability:
			print_debug("Chain destroy found: ", result.collider.name, " at depth: ", depth + 1)
		var obj = result.collider
		if obj and obj.is_in_group(destroy_ability_group):
			# Schedule next break with delay
			var delay = destroy_ability_chain_delay * (depth + 1)
			call_deferred("_delayed_chain_destroy", obj, center_obj.global_position, depth + 1, delay)

func _delayed_chain_destroy(obj: Node, pos: Vector2, depth: int, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	_chain_destroy(obj, pos, depth)

# endregion

# region Zone Callbacks
func _on_slam_zone_entered(_body: Node) -> void:
	in_slam_zone = true

func _on_slam_zone_exited(_body: Node) -> void:
	in_slam_zone = false

func _on_launch_zone_entered(_body: Node) -> void:
	if debug_enabled and debug_input_events:
		print_debug("Enteredlaunchzone")
	in_launch_zone = true
	launch_ability._show_prompt()

func _on_launch_zone_exited(_body: Node) -> void:
	if debug_enabled and debug_input_events:
		print_debug("Exitedlaunchzone")
	in_launch_zone = false
	launch_ability._hide_prompt()

func _on_spike_grace_timeout() -> void:
	if in_spike_grace:
		# Transition to DeathState if still in spikes
		in_spike_grace = false
		_change_state(DeathState)
# endregion

# region Collision & Spikes

func _get_tilemap_layers() -> void:
	if not ground_tilemap_layer_path.is_empty():
		ground_tilemap_layer = get_node(ground_tilemap_layer_path) as TileMapLayer
	else:
		push_error("Groundtilemaplayerpath is not set.")


## Detect layers for physics interactions
func _collision_checker() -> void:
	for i in range(get_slide_collision_count()):
		var collision: KinematicCollision2D = get_slide_collision(i)
		if collision:
			if debug_enabled and debug_collisions:
				print_debug("Collisiondetected: ", collision.get_collider().name, "at", collision.get_position())
			var collider = collision.get_collider()
			if not collider:
				continue
			if collider.is_in_group("spikes"):
				_in_spikes(true)
			else:
				in_spike_grace = false # Not in spikes this frame

			if collider.is_in_group("death"):
				if debug_enabled and debug_death:
					print_debug("Deathcolliderhit: ", collider.name)
				# If we hit a death collider, transition to DeathState
				_change_state(DeathState)


func _in_spikes(is_in_spike: bool) -> void:
	if is_in_spike:
		if not spike_grace_timer_node.is_stopped():
			return # Already in grace period
		in_spike_grace = true
		has_jumped_off_spikes = false
		spike_grace_timer_node.wait_time = spike_grace_time
		spike_grace_timer_node.start()

func _is_on_slippery() -> bool:
	if not is_on_floor():
		return false

	var half_height: float = _get_collision_half_height()
	var foot_position: Vector2 = global_position + Vector2(0, half_height + 1)
	var tile_size: Vector2 = ground_tilemap_layer.tile_set.tile_size
	var coords: Vector2i = Vector2i(int(foot_position.x / tile_size.x), int(foot_position.y / tile_size.y))
	var cell_data = ground_tilemap_layer.get_cell_tile_data(coords)

	return cell_data and cell_data.get_custom_data("slippery")

func _get_collision_half_height() -> float:
	var shape = $CollisionShape2D.shape
	if shape is CapsuleShape2D:
		return shape.height * 0.5 + shape.radius
	if shape is RectangleShape2D:
		return shape.extents.y
	if shape is CircleShape2D:
		return shape.radius
	return 0.0
# endregion


# region Input 
func _updated_x_input() -> void:
	# Update the input_x_direction based on current input
	input_x_direction = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	x_dir_just_pressed = Input.is_action_just_pressed("move_right") or Input.is_action_just_pressed("move_left")
	if input_x_direction != 0:
		if Input.is_action_pressed("move_right") and not Input.is_action_pressed("move_left"):
			previous_input_x_direction = 1.0
		elif Input.is_action_pressed("move_left") and not Input.is_action_pressed("move_right"):
			previous_input_x_direction = -1.0
