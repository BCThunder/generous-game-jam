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
@export var slam_abiility_scene: PackedScene
@export var slam_abiility_enabled: bool = true

# --- Destroy Ability ---
@export_category("Destroy Ability")
@export var destroy_ability_enabled: bool = true
@export var destroy_ability_cooldown: float = 0.3 # seconds
@export var destroy_ability_range: float = 32.0 # Raycast distance in pixels
@export var destroy_ability_collision_mask: int = 0xFFFFFFFF # Collision mask for raycast
@export var destroy_ability_hit_from_inside: bool = true # Allow hit from inside
@export var destroy_ability_group: String = "breakable_rock" # Group name for breakable objects
@export var destroy_ability_chain_radius: float = 48.0 # Radius for chain breaking
@export var destroy_ability_chain_delay: float = 0.08 # Delay between chain breaks (seconds)
@export var destroy_ability_chain_depth: int = 2 # How many layers deep to chain break
var destroy_ability_timer: Timer

# Debug Flags
@export_category("Debug")
@export var debug_enabled: bool = false
@export var debug_movement: bool = false
@export var debug_input_events: bool = false
@export var debug_jumps: bool = false
@export var debug_state_changes: bool = false
@export var debug_collisions: bool = false
@export var debug_death: bool = false

# Sound Effects
@onready var walking_sfx: AudioStreamPlayer2D = $SFX/WalkingSFX
@onready var launch_sfx: AudioStreamPlayer2D = $SFX/LaunchSFX
@onready var slam_sfx: AudioStreamPlayer2D = $SFX/SlamSFX
@onready var jump_sfx: AudioStreamPlayer2D = $SFX/JumpSFX

# Context Flags
var is_jump_held: bool = false
var can_double_jump: bool = false
var in_slam_zone: bool = false
var in_launch_zone: bool = false

# Ability Reference
var launch_ability: Node2D = null

# Cached References
var ground_tilemap_layer: TileMapLayer

# Timers for duration-based effects
var tap_boost_timer: Timer
var coyote_timer_node: Timer
var spike_grace_timer_node: Timer # Timer node for spike grace
# endregion

# region State Machine
# --- State Machine Base ---
class PlayerState:
	var player: PlayerController

	func _init(p_player: PlayerController) -> void:
		player = p_player

	func enter() -> void:
		pass

	func exit() -> void:
		pass

	func input(_event: InputEvent) -> void:
		pass

	func physics(_delta: float) -> void:
		pass

# --- Ground State ---
class GroundState extends PlayerState:
	func enter() -> void:
		# Reset jump flags on landing
		player.can_double_jump = false
		player.is_jump_held = false
		player.coyote_timer_node.start(player.coyote_time_duration)

		if player.debug_enabled and player.debug_movement:
			print("Entered GroundState")

	func input(event: InputEvent) -> void:
		if event.is_action_pressed("jump"):
			if player.debug_enabled and player.debug_jumps:
				print("Jump pressed (Ground)")
			player._try_jump()

	func physics(delta: float) -> void:
		player._apply_gravity(delta)
		player._handle_ground_moves(delta)
		player.move_and_slide()
		player._collision_checker()
		if not player.is_on_floor():
			player._change_state(AirState)

# --- Air State ---
class AirState extends PlayerState:

	func enter() -> void:
		if player.debug_enabled and player.debug_movement:
			print("Entered AirState")
		player.can_double_jump = player.double_jump_enabled
		# Start coyote time if not already running
		if player.coyote_timer_node.is_stopped():
			player.coyote_timer_node.start(player.coyote_time_duration)

	func input(event: InputEvent) -> void:
		# Handle double jump on second press
		if event.is_action_pressed("jump") and player.can_double_jump:
			if player.debug_enabled and player.debug_jumps:
				print("Jump pressed (Air) - Double Jump")
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
		player._apply_gravity(delta)
		player._handle_air_moves(delta)
		player.move_and_slide()
		player._collision_checker()
		if player.is_on_floor():
			player._change_state(GroundState)

class SlamState extends PlayerState:
	func enter() -> void:
		if player.debug_enabled and player.debug_movement:
			print("Entered SlamState")
		# Reset jump flags
		player.is_jump_held = false
		player.can_double_jump = false

	func physics(delta: float) -> void:
		var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
		var grav_scale: float = 30.0

		player.velocity.y += gravity * grav_scale * delta
		player.velocity.x = 0.0 # Stop horizontal movement during slam

		var collision = player.move_and_slide()
		if collision:
			# Check if we hit the ground
			if player.is_on_floor():
				# Small delay to allow landing effects
				await player.get_tree().create_timer(1.0).timeout
				player._change_state(GroundState)
			else:
				# If not on ground, stay in slam state
				player.velocity.x = 0.0 # Stop horizontal movement during slam
				player.velocity.y = max(player.velocity.y, 0) # Prevent upward movement

		player._collision_checker()

# --- Destroy State ---
class DestroyState extends PlayerState:
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

# --- Death State ---
class DeathState extends PlayerState:
	func enter() -> void:
		if player.debug_enabled and player.debug_state_changes:
			print("Entered DeathState")
		# Stop all movement and input
		player.velocity = Vector2.ZERO
		player.set_process_input(false)
		# Optionally, play death animation, sound, or respawn logic here
		# Example: player._on_player_death()

		var tween = player.create_tween()
		tween.tween_property(player, "modulate:a", 0.0, player.death_duration)
		await tween.finished
		player.get_tree().reload_current_scene() # Reload the scene or handle respawn logic

	func input(_event: InputEvent) -> void:
		pass

	func physics(_delta: float) -> void:
		# No movement in death state
		pass
# endregion

# region PlayerController Lifecycle
var current_state: PlayerState = null

func _ready() -> void:
	ground_tilemap_layer = get_node(ground_tilemap_layer_path)
	if not ground_tilemap_layer:
		push_error("TileMapLayer not found at %s" % ground_tilemap_layer_path)

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

	current_state = GroundState.new(self)
	current_state.enter()

	set_process_input(true)
	set_physics_process(true)

	_collision_checker()
	_connect_zone_signals()
# endregion

# region Input and Physics
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
	current_state.exit()
	current_state = new_state_class.new(self)
	current_state.enter()
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
	var direction: float = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	var just_pressed: bool = Input.is_action_just_pressed("move_right") or Input.is_action_just_pressed("move_left")
	var is_slippery: bool = _is_on_slippery()

	# Tap boost logic
	if just_pressed and direction != 0:
		tap_boost_timer.start(tap_boost_duration)

	if is_slippery:
		var accel: float = run_speed * slippery_acceleration_multiplier
		if direction != 0:
			if not tap_boost_timer.is_stopped():
				velocity.x += direction * tap_speed * delta * tap_slippery_acceleration_multiplier
			else:
				velocity.x += direction * accel * delta
		else:
			velocity.x = lerp(velocity.x, 0.0, slippery_friction * delta)
	else:
		if direction != 0:
			if not tap_boost_timer.is_stopped():
				velocity.x = direction * tap_speed
			else:
				velocity.x = direction * run_speed
				
			play_walking_sfx()
		else:
			velocity.x = lerp(velocity.x, 0.0, ground_friction * delta)

	velocity.x = clamp(velocity.x, -run_speed, run_speed)
	
func play_walking_sfx():
	if walking_sfx.playing == false:
		walking_sfx.pitch_scale = randf_range(.8, 1.2)
		walking_sfx.play()

func _handle_air_moves(delta: float) -> void:
	var direction: float = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")

	if direction != 0:
		velocity.x += direction * run_speed * air_accel_multiplier * delta
	else:
		velocity.x = lerp(velocity.x, 0.0, air_friction * delta)

	velocity.x = clamp(velocity.x, -run_speed, run_speed)

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

# region Jump & Destroy Abilities
func _try_jump() -> void:
	if (is_on_floor() or not coyote_timer_node.is_stopped()) or (in_spike_grace and (not spike_jump_once or not has_jumped_off_spikes)):
		velocity.y = - max_jump_velocity
		is_jump_held = true
		can_double_jump = true
		coyote_timer_node.stop()
		if in_spike_grace and spike_jump_once:
			has_jumped_off_spikes = true
			
		play_jump_sfx()
	elif double_jump_enabled and can_double_jump:
		velocity.y = - max_jump_velocity
		is_jump_held = true
		can_double_jump = false
		
		play_jump_sfx()

func play_jump_sfx():
	jump_sfx.pitch_scale = randf_range(.8, 1.2)
	jump_sfx.play()

func _try_destroy_ability() -> void:
	# Cast a short ray in facing direction to detect breakable rocks
	var direction = Vector2(sign($Sprite2D.scale.x), 0)
	var ray_origin = global_position
	var ray_end = ray_origin + direction * destroy_ability_range # Use exported range
	var space = get_world_2d().direct_space_state
	var params = PhysicsRayQueryParameters2D.create(ray_origin, ray_end)
	params.exclude = [self]
	params.collision_mask = destroy_ability_collision_mask
	params.hit_from_inside = destroy_ability_hit_from_inside
	var result = space.intersect_ray(params)
	if result and result.collider and result.collider.is_in_group(destroy_ability_group):
		if debug_enabled and debug_state_changes:
			print("Destroying rock: ", result.collider.name)
		# Break the initial object and start chain break
		_chain_destroy(result.collider, global_position, 0)
		# Optionally play effect or sound here
	else:
		if debug_enabled and debug_state_changes:
			print("No breakable rock detected.")

# Progressive chain break with delay for surrounding objects
func _chain_destroy(center_obj: Node, center_pos: Vector2, depth: int) -> void:
	if not center_obj:
		return
	# Optionally play destroy animation or effect
	if center_obj.has_method("destroy"):
		center_obj.call("destroy")
	else:
		push_warning("DestroyAbility: Object does not have a 'destroy' method.")
	# Start cooldown timer only for the initial call
	if depth == 0:
		destroy_ability_timer.start(destroy_ability_cooldown)
	if debug_enabled and debug_state_changes:
		print("Destroy ability used on: ", center_obj.name)
	if depth >= destroy_ability_chain_depth:
		return
	for obj in get_tree().get_nodes_in_group(destroy_ability_group):
		if obj == center_obj:
			continue
		if obj.global_position.distance_to(center_pos) <= destroy_ability_chain_radius:
			# Schedule next break with delay
			var delay = destroy_ability_chain_delay * (depth + 1)
			call_deferred("_delayed_chain_destroy", obj, obj.global_position, depth + 1, delay)

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
		print_debug("Entered launch zone")
	in_launch_zone = true
	launch_ability._show_prompt()

func _on_launch_zone_exited(_body: Node) -> void:
	if debug_enabled and debug_input_events:
		print_debug("Exited launch zone")
	in_launch_zone = false
	launch_ability._hide_prompt()

func _on_spike_grace_timeout() -> void:
	if in_spike_grace:
		# Transition to DeathState if still in spikes
		in_spike_grace = false
		_change_state(DeathState)
# endregion

# region Collision & Spikes
## Detect layers for physics interactions
func _collision_checker() -> void:
	for i in range(get_slide_collision_count()):
		var collision: KinematicCollision2D = get_slide_collision(i)
		if collision:
			if debug_enabled and debug_collisions:
				print_debug("Collision detected: ", collision.get_collider().name, " at ", collision.get_position())
			var collider = collision.get_collider()
			if not collider:
				continue
			if collider.is_in_group("spikes"):
				_in_spikes(true)
			else:
				in_spike_grace = false # Not in spikes this frame
			if collider.is_in_group("death"):
				if debug_enabled and debug_death:
					print_debug("Death collider hit: ", collider.name)
				# If we hit a death collider, transition to DeathState
				_change_state(DeathState)
				return
	

func _in_spikes(is_in_spike: bool) -> void:
	if is_in_spike:
		if not spike_grace_timer_node.is_stopped():
			return # Already in grace period
		in_spike_grace = true
		has_jumped_off_spikes = false
		spike_grace_timer_node.wait_time = spike_grace_time
		spike_grace_timer_node.start()
# endregion
