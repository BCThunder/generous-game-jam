@tool
extends Node2D

@export_category("Object")
@export var drop_object_scene: PackedScene:
	set(value):
		if value and value is PackedScene:
			drop_object_scene = value
			drop_object_instance = drop_object_scene.instantiate()

var drop_object_instance: Node2D = null
@export var offset: Vector2 = Vector2(0, 0):
	set(value):
		offset = value
		if drop_object_instance:
			drop_object_instance.global_position = global_position + offset

@export_category("Drop Settings")
@export var drop_delay: float = 0.5
@export var use_object_physics: bool = true

@export_category("Trigger Area Settings")
@export var trigger_area: Area2D

@export_category("Raycast Settings")
@export var use_raycast: bool = true
@export var raycast_node: RayCast2D


func _ready():
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		game_manager.player_respawn.connect(_reset)
	else:
		push_error("CeilingDrop: Could not find GameManager node in the scene tree.")
	
	if not use_raycast and trigger_area:
		trigger_area.body_entered.connect(drop)
	elif use_raycast and raycast_node:
		pass

	else:
		push_error("CeilingDrop: No trigger area or raycast node set. Please assign one in the inspector.")

	if use_object_physics or (use_raycast and raycast_node):
		_physics_process(true)
	else:
		_physics_process(false)
		
	call_deferred("_reset")

		
func _physics_process(delta):
	if use_raycast and raycast_node:
		raycast_node.force_raycast_update()
		if raycast_node.is_colliding():
			var collider = raycast_node.get_collider()
			if collider and collider is CharacterBody2D:
				drop()

			elif collider:
				raycast_node.add_exception(collider)

	elif trigger_area:
		var bodies = trigger_area.get_overlapping_bodies()
		for body in bodies:
			if body and body is RigidBody2D:
				drop()
				break


func _reset():
	print_debug("CeilingDrop: Resetting drop object.")
	if not drop_object_scene:
		push_error("CeilingDrop: No drop_object_scene set. Please assign a scene in the inspector.")
	else:
		if drop_object_instance:
			drop_object_instance.queue_free()
		drop_object_instance = drop_object_scene.instantiate()
		if not drop_object_instance:
			push_error("CeilingDrop: Failed to instantiate drop object from scene.")
			return
		add_child(drop_object_instance)
		drop_object_instance.global_position = global_position + offset
		drop_object_instance.rotation = rotation
		drop_object_instance.scale = scale

		call_deferred("_toggle_physics_process", drop_object_instance, false)
		call_deferred("_toggle_physics_process", self, true)


func drop(body: Node = null):
	if not drop_object_instance:
		push_error("CeilingDrop: No drop object instance to drop.")
		return
	else:
		print_debug("CeilingDrop: Dropping object.")
		if use_object_physics and drop_object_instance is RigidBody2D:
			drop_object_instance.freeze_mode = false
			#drop_object_instance.apply_impulse(Vector2.ZERO, Vector2(0, -1000)) # Example impulse
		else:
			drop_object_instance.global_position = global_position + offset
			drop_object_instance.rotation = rotation
			drop_object_instance.scale = scale
		call_deferred("_toggle_physics_process", drop_object_instance, true)
		call_deferred("_toggle_physics_process", self, false)


func _toggle_physics_process(object: Node2D, enable: bool = true):
	if enable:
		object.process_mode = Node.PROCESS_MODE_PAUSABLE
	else:
		object.process_mode = Node.PROCESS_MODE_DISABLED
