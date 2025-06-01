# Handles player movement states, abilities, and environment interactions.

extends CharacterBody2D
class_name PlayerController

# Movement Tuning
@export_category("Movement")
@export var run_speed: float = 300.0
@export var air_accel_multiplier: float = 0.5
@export var air_friction: float = 1.0

# Gravity Tuning
@export_category("Gravity and Jumping")
@export var double_jump_enabled: bool = true
@export var max_jump_velocity: float = 600.0
@export var min_jump_velocity: float = 300.0
@export var jump_gravity_scale: float = 0.6
@export var fall_gravity_scale: float = 1.5
@export var down_hold_gravity_multiplier: float = 1.2
@export var coyote_time_duration: float = 0.2 # seconds of grace time
var coyote_timer: float = 0.0 # internal timer


# Ground & Slippery Tiles
@export_category("Ground & Slippery")
@export var ground_friction: float = 8.0
@export var slippery_acceleration_multiplier: float = 6.0
@export var slippery_friction: float = 0.5


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

# Debug Flags
@export_category("Debug")
@export var debug_movement: bool = false
@export var debug_input_events: bool = false
@export var debug_jumps: bool = false

# Context Flags
var is_jump_held: bool = false
var can_double_jump: bool = false
var in_slam_zone: bool = false
var in_launch_zone: bool = false

# Ability Reference
var launch_ability: Node2D = null

# Cached References
var ground_tilemap_layer: TileMapLayer


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
		player.coyote_timer = player.coyote_time_duration

		if player.debug_movement:
			print("Entered GroundState")

	func input(event: InputEvent) -> void:
		if event.is_action_pressed("jump"):
			if player.debug_jumps:
				print("Jump pressed (Ground)")
			player._try_jump()

	func physics(delta: float) -> void:
		player._apply_gravity(delta)
		player._handle_ground_moves(delta)
		player.move_and_slide()

		if not player.is_on_floor():
			player._change_state(AirState)


# --- Air State ---
class AirState extends PlayerState:
	func enter() -> void:
		if player.debug_movement:
			print("Entered AirState")
		player.can_double_jump = player.double_jump_enabled

	func input(event: InputEvent) -> void:
		# Handle double jump on second press
		if event.is_action_pressed("jump") and player.can_double_jump:
			if player.debug_jumps:
				print("Jump pressed (Air) - Double Jump")
			player._try_jump()

		# Release jump for variable height
		if event.is_action_released("jump"):
			player.is_jump_held = false
			if player.velocity.y < -player.min_jump_velocity:
				player.velocity.y = - player.min_jump_velocity

	func physics(delta: float) -> void:
		if player.coyote_timer > 0.0:
			player.coyote_timer -= delta

		player._apply_gravity(delta)
		player._handle_air_moves(delta)
		player.move_and_slide()

		if player.is_on_floor():
			player._change_state(GroundState)


# --- PlayerController Lifecycle ---
var current_state: PlayerState = null

func _ready() -> void:
	ground_tilemap_layer = get_node(ground_tilemap_layer_path)
	if not ground_tilemap_layer:
		push_error("TileMapLayer not found at %s" % ground_tilemap_layer_path)

	_init_launch_ability()

	current_state = GroundState.new(self)
	current_state.enter()

	set_process_input(true)
	set_physics_process(true)

	_connect_zone_signals()

func _input(event: InputEvent) -> void:
	if launch_ability and launch_ability.get("active"):
		launch_ability.call("input", event)
		return

	if in_launch_zone and launch_ability and event.is_action_pressed("context_interact"):
		launch_ability.call("start")
		return

	current_state.input(event)

func _physics_process(delta: float) -> void:
	if launch_ability and launch_ability.get("active"):
		launch_ability.call("physics", delta)
	else:
		current_state.physics(delta)


# --- State Transition ---
func _change_state(new_state_class) -> void:
	current_state.exit()
	current_state = new_state_class.new(self)
	current_state.enter()


# --- Gravity & Movement Helpers ---
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

	if is_slippery:
		var accel: float = run_speed * slippery_acceleration_multiplier
		if direction != 0:
			if just_pressed:
				# Instant acceleration on first press
				velocity.x = direction * run_speed * 0.2
			else:
				# Smooth acceleration otherwise
				velocity.x += direction * accel * delta
		else:
			velocity.x = lerp(velocity.x, 0.0, slippery_friction * delta)
	else:
		if direction != 0:
			if just_pressed:
				print_debug("Just pressed move key")
				# Instant acceleration on first press
				velocity.x = direction * run_speed * 0.2
			else:
				# Smooth acceleration otherwise
				velocity.x = direction * run_speed
		else:
			velocity.x = lerp(velocity.x, 0.0, ground_friction * delta)

	velocity.x = clamp(velocity.x, -run_speed, run_speed)

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


# --- Launch Ability & Zones ---
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

func _try_jump() -> void:
	if is_on_floor() or coyote_timer > 0.0:
		velocity.y = - max_jump_velocity
		is_jump_held = true
		can_double_jump = true
		coyote_timer = 0.0
	elif double_jump_enabled and can_double_jump:
		velocity.y = - max_jump_velocity
		is_jump_held = true
		can_double_jump = false

func _on_slam_zone_entered(_body: Node) -> void:
	in_slam_zone = true

func _on_slam_zone_exited(_body: Node) -> void:
	in_slam_zone = false

func _on_launch_zone_entered(_body: Node) -> void:
	print_debug("Entered launch zone")
	in_launch_zone = true
	launch_ability._show_prompt()

func _on_launch_zone_exited(_body: Node) -> void:
	print_debug("Exited launch zone")
	in_launch_zone = false
	launch_ability._hide_prompt()
