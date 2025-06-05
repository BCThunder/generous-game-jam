extends Node2D
class_name LaunchAbility

# — Exported Variables —
@export var launch_power: float = 1.0
@export var launch_aim_distance: float = 200.0
@export var aim_cursor_scene: PackedScene

@export_category("Debug")
@export var debug_state_changes: bool = false
@export var debug_input_events: bool = false

@export_category("Launch Mode")
@export var use_physics_launch: bool = false

@export_category("UI")
@export var launch_prompt_scene: PackedScene = preload("res://scenes/ui/prompts/launch_interact_prompt.tscn")
@export var launch_control_scene: PackedScene = preload("res://scenes/ui/prompts/launch_ability_controls.tscn")

# Runtime state
var show_prompt: bool = false
var player: CharacterBody2D
var aim_cursor: Node2D
var aim_direction: Vector2 = Vector2.RIGHT
var active: bool = false
var guide_line: Line2D
var controls_instance: Node2D
var prompt_instance: Node2D

# Internal states
enum State {IDLE, AIMING, FIRING}
var state: State = State.IDLE

# State name map
var state_names = {State.IDLE: "IDLE", State.AIMING: "AIMING", State.FIRING: "FIRING"}

func _ready():
	player = get_parent() as CharacterBody2D
	set_process_input(true)
	set_physics_process(true)
	# Create a Line2D for the guide
	guide_line = Line2D.new()
	guide_line.width = 2.0
	add_child(guide_line)
	guide_line.visible = false

func start():
	_change_state(State.AIMING)
	_hide_prompt()
	_show_controls()
	active = true
	player.velocity = Vector2.ZERO
	if not aim_cursor_scene:
		push_error("Aim cursor scene is not set.")
	else:
		aim_cursor = aim_cursor_scene.instantiate() as Node2D
		player.add_child(aim_cursor)
		aim_cursor.global_position = player.global_position
	guide_line.visible = true

func input(event):
	if debug_input_events and event is InputEventAction:
		print_debug("[LaunchAbility] Input event: %s in state %s" % [event.get_action(), state_names[state]])
	if state != State.AIMING:
		return
	if event.is_action_pressed("launch_fire"):
		_execute_launch()
	elif event.is_action_pressed("launch_cancel"):
		_cancel()
		

func physics(delta):
	if state == State.AIMING:
		var mouse_pos = player.get_global_mouse_position()
		aim_direction = (mouse_pos - player.global_position).normalized()
		aim_cursor.global_position = player.global_position + aim_direction * launch_aim_distance
		aim_cursor.rotation = aim_direction.angle() + PI / 2
		_update_guide_line()
	elif state == State.FIRING:
		if not use_physics_launch:
			player.velocity = aim_direction * launch_power
			var collision = player.move_and_collide(player.velocity * delta)
			if collision:
				_finish()
		else:
			# Physics-based launch logic
			player._apply_gravity(delta)
			var collision = player.move_and_slide()
			if collision:
				# Handle collision response if needed
				_finish()
	# elif state == State.IDLE:
	# 	# In IDLE state, we might want to show a prompt if conditions are met
	# 	if show_prompt:
	# 		prompt_instance.position = player.global_position + launch_prompt_offset

func _execute_launch():
	_change_state(State.FIRING)
	player.velocity = aim_direction * launch_power
	if aim_cursor:
		aim_cursor.queue_free()
		aim_cursor = null
	guide_line.visible = false
	_remove_controls()
	

func _cancel():
	_show_prompt()
	_cleanup()

func _finish():
	_cleanup()

func _cleanup():
	if aim_cursor:
		aim_cursor.queue_free()
		aim_cursor = null
	guide_line.visible = false
	_remove_controls()
	_change_state(State.IDLE)
	active = false

func _change_state(new_state: State) -> void:
	if debug_state_changes:
		print_debug("[LaunchAbility] State change: %s -> %s" % [state_names[state], state_names[new_state]])
	state = new_state

func _update_guide_line():
	# Draw a line from player's position to the cursor
	guide_line.clear_points()
	guide_line.add_point(player.to_local(player.global_position))
	guide_line.add_point(aim_cursor.position)


func _remove_controls():
	if controls_instance:
		controls_instance.queue_free()
		controls_instance = null

func _show_prompt():
	if not launch_prompt_scene:
		push_error("Launch prompt scene is not set.")
		return

	show_prompt = true
	if not prompt_instance:
		prompt_instance = launch_prompt_scene.instantiate() as Node2D
		add_child(prompt_instance)
		prompt_instance.set_follow_target(player)

func _hide_prompt():
	if not launch_prompt_scene:
		push_error("Launch prompt scene is not set.")
		return

	show_prompt = false
	if prompt_instance:
		prompt_instance.queue_free()
		prompt_instance = null

func _show_controls():
	if not launch_control_scene:
		push_error("Launch control scene is not set.")
		return

	if controls_instance:
		controls_instance.queue_free()
	controls_instance = launch_control_scene.instantiate() as Node2D
	add_child(controls_instance)
	controls_instance.set_follow_target(player)
