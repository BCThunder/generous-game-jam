extends CharacterBody2D

# — Tunables —————————————————————————————————————————————————
@export var run_speed = 300
@export var max_jump_vel = 600
@export var min_jump_vel = 300
@export var jump_grav_scale = 0.6
@export var fall_grav_scale = 1.5
@export var base_friction = 8.0 # higher = quicker slowdown on ground

# TileMapLayer for surface friction metadata
@export var ground_tilemap_layer_path: NodePath

# Context flags & unlocks
var can_double_jump = false
var has_dashed = false
var in_slam_zone = false
var in_launch_zone = false # new flag for launch context

# Launch aiming state
var is_aiming = false
var aim_direction = Vector2.RIGHT
var aim_cursor: Node2D = null
@export var launch_speed_curve: Curve # designers assign curve for speed
@export var max_launch_pullback = 200.0 # max distance for pullback aiming
@export var aim_cursor_scene: PackedScene # scene for the aiming cursor

# Internal state
var is_jump_held = false

# Cached references
var ground_tilemap_layer: TileMapLayer


@export_category("Debug")
@export var jump_debug: bool = false
@export var inputEvent_debug: bool = false


func _ready():
	# Cache tilemap layer
	ground_tilemap_layer = get_node(ground_tilemap_layer_path)
	if not ground_tilemap_layer:
		printerr("PlayerController: Ground TileMapLayer not found at path: ", ground_tilemap_layer_path)
	set_process_input(true)

	# Connect slam zones
	for zone in get_tree().get_nodes_in_group("SlamZones"):
		zone.connect("entered", Callable(self, "_on_slam_zone_entered"))
		zone.connect("exited", Callable(self, "_on_slam_zone_exited"))
	# Connect launch zones
	for lz in get_tree().get_nodes_in_group("LaunchZones"):
		lz.connect("entered", Callable(self, "_on_launch_zone_entered"))
		lz.connect("exited", Callable(self, "_on_launch_zone_exited"))

func _input(event: InputEvent) -> void:
	# UI focus check
	var focus_owner = get_viewport().gui_get_focus_owner()
	print("Focus owner: ", focus_owner)
	if focus_owner != null and focus_owner is Control:
		print("Input event ignored due to UI focus")
		return

	# If currently aiming, handle aim input
	if is_aiming:
		print("Handling launch aim input")
		_handle_launch_aim_input(event)
		return

	# Normal gameplay inputs
	if event is InputEvent and not event.is_echo():
		if inputEvent_debug:
			print("Handling action input: ", event.as_text())
		if event.is_action_pressed("jump"):
			if jump_debug:
				print("Jump pressed")
			_try_jump()
		# elif event.is_action_pressed("dash"):
		# 	_try_dash()
		# elif event.is_action_pressed("context_interact") and in_slam_zone:
		# 	_do_slam()
		# elif event.is_action_pressed("context_interact") and in_launch_zone:
		# 	_start_launch_aim()

		if event.is_action_released("jump"):
			is_jump_held = false
			if velocity.y < -min_jump_vel:
				velocity.y = - min_jump_vel

func _physics_process(delta: float) -> void:
	var was_on_floor = is_on_floor()
	if not is_aiming:
		_apply_gravity(delta)
		_handle_moves(delta)
		move_and_slide()
		if not was_on_floor and is_on_floor():
			has_dashed = false
	else:
		# disable physics movement while aiming
		pass

# — Launch Aiming & Execution ———————————————————————————————————
func _start_launch_aim() -> void:
	is_aiming = true
	velocity = Vector2.ZERO
	# spawn cursor
	aim_cursor = aim_cursor_scene.instantiate()
	add_child(aim_cursor)
	aim_cursor.global_position = global_position

func _handle_launch_aim_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		# aim with mouse direction
		var dir = (event.position - global_position).normalized()
		aim_direction = dir
		aim_cursor.global_position = global_position + dir * max_launch_pullback
	elif event is InputEventAction and event.is_action_released("context_interact"):
		# compute pullback distance
		var pullback = (aim_cursor.global_position - global_position).length()
		var t = min(pullback / max_launch_pullback, 1.0)
		var speed = launch_speed_curve.interpolate(t)
		velocity = aim_direction * speed
		# cleanup
		aim_cursor.queue_free()
		aim_cursor = null
		is_aiming = false

# — Movement & Gravity ————————————————————————————————————————
func _apply_gravity(delta: float) -> void:
	var gravity_value = ProjectSettings.get_setting("physics/2d/default_gravity")
	var scale: float
	if velocity.y < 0 and is_jump_held:
		scale = jump_grav_scale
	else:
		scale = fall_grav_scale
	velocity.y += gravity_value * scale * delta

func _handle_moves(delta: float) -> void:
	# Horizontal input
	var left_strength = Input.get_action_strength("move_left")
	var right_strength = Input.get_action_strength("move_right")
	var dir = right_strength - left_strength

	# Get tile data
	var is_slippery = false
	if is_on_floor():
		var half_height = _get_collision_half_height()
		var foot_offset = Vector2(0, half_height + 1.0)
		var world_pos = global_position + foot_offset
		var tile_size = ground_tilemap_layer.tile_set.tile_size
		var map_coords = Vector2i(
			int(world_pos.x / tile_size.x),
			int(world_pos.y / tile_size.y)
		)
		var tile_data: TileData = ground_tilemap_layer.get_cell_tile_data(map_coords)
		if tile_data and tile_data.get_custom_data("slippery") == true:
			is_slippery = true

	if is_slippery:
		# Slippery: acceleration and friction
		var friction_coeff = _get_tile_friction()
		var friction_factor = clamp(base_friction * friction_coeff * delta, 0, 1)
		var accel = run_speed * 4
		if dir != 0:
			velocity.x += dir * accel * delta
		if is_on_floor():
			velocity.x = lerp(velocity.x, 0.0, friction_factor)
		velocity.x = clamp(velocity.x, -run_speed, run_speed)
	else:
		# Normal: direct set
		if dir != 0:
			velocity.x = dir * run_speed
		else:
			if is_on_floor():
				var friction_coeff = _get_tile_friction()
				var friction_factor = clamp(base_friction * friction_coeff * delta, 0, 1)
				velocity.x = lerp(velocity.x, 0.0, friction_factor)

# — Tile Friction Utility —————————————————————————————————————
func _get_tile_friction() -> float:
	if not ground_tilemap_layer:
		return 1.0
	var tilemap = ground_tilemap_layer.get_parent() # Assuming TileMapLayer is a child of TileMap
	if not tilemap or not tilemap.has_method("local_to_map"):
		return 1.0
	var half_h = _get_collision_half_height()
	var foot_pos = global_position + Vector2(0, half_h + 1)
	var cell = tilemap.local_to_map(foot_pos)
	var layer_idx = ground_tilemap_layer.layer
	var tile_data = tilemap.get_cell_tile_data(layer_idx, cell)
	if tile_data:
		var f = tile_data.get_custom_data("friction")
		if f is float:
			return f
		elif f != null:
			var conv = float(f)
			if not is_nan(conv):
				return conv
	return 1.0

func _get_collision_half_height() -> float:
	var s = $CollisionShape2D.shape
	if s is CapsuleShape2D:
		return s.height * 0.5 + s.radius
	elif s is RectangleShape2D:
		return s.extents.y
	elif s is CircleShape2D:
		return s.radius
	return 0.0

# — Abilities —————————————————————————————————————————————————
func _try_jump() -> void:
	print("Attempting jump")
	if is_on_floor():
		velocity.y = - max_jump_vel
		is_jump_held = true
		can_double_jump = true
	elif can_double_jump:
		_try_double_jump()

func _try_double_jump() -> void:
	if can_double_jump and not is_on_floor():
		velocity.y = - max_jump_vel
		is_jump_held = true
		can_double_jump = false

func _try_dash() -> void:
	if not has_dashed:
		has_dashed = true
		var sign_dir = 1
		if velocity.x != 0:
			sign_dir = sign(velocity.x)
		velocity.x = sign_dir * run_speed * 2

func _do_slam() -> void:
	velocity = Vector2(0, run_speed * 3)

# — Zone Callbacks ——————————————————————————————————————
func _on_slam_zone_entered() -> void:
	in_slam_zone = true

func _on_slam_zone_exited() -> void:
	in_slam_zone = false

func _on_launch_zone_entered() -> void:
	in_launch_zone = true

func _on_launch_zone_exited() -> void:
	in_launch_zone = false
