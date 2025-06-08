extends Area2D


@export_category("Settings")
@export var dissolve_duration: float = 1.0 # Duration of the dissolving effect in seconds
@export var collision_disable_time: float = 0.5 # Time to disable collision after dissolving
@export var respawn_delay: float = 2.0 # Delay before the platform can respawn


@export_category("Debug")
@export var debug_enabled: bool = false # Enable debug messages

@export var physical_collider: CollisionShape2D
var spawn_position: Vector2

var collision_timer: Timer
var respawn_timer: Timer


func _ready() -> void:
	# Initialize timers
	collision_timer = Timer.new()
	collision_timer.wait_time = collision_disable_time
	collision_timer.one_shot = true
	collision_timer.timeout.connect(Callable(self, "_on_collision_timeout"))
	add_child(collision_timer)

	respawn_timer = Timer.new()
	respawn_timer.wait_time = respawn_delay
	respawn_timer.one_shot = true
	respawn_timer.timeout.connect(Callable(self, "_on_respawn_timeout"))
	add_child(respawn_timer)

	self.body_entered.connect(Callable(self, "_on_collision_entered"))

	
func _on_collision_entered(_collision: Node) -> void:
	if debug_enabled:
		print_debug("DissolvingPlatform: Collision detected with ", _collision.name)
	# Start the dissolving effect
	_dissolve_platform()


func _dissolve_platform() -> void:
	# Create a Tween for the dissolving effect
	collision_timer.start()
	var tween = create_tween()
	
	await tween.tween_property(self, "modulate:a", 0.0, dissolve_duration).finished

	respawn_timer.start()


func _on_collision_timeout() -> void:
	# Disable collision after dissolving
	_disable_collisions(true)
	if debug_enabled:
		print_debug("DissolvingPlatform: Collision disabled after dissolving.")

func _on_respawn_timeout() -> void:
	_reset()


func _reset() -> void:
	# Reset the platform's position and state
	global_position = spawn_position
	modulate = Color(1, 1, 1, 1) # Reset alpha to fully opaque
	
	# Stop any active timers
	collision_timer.stop()
	respawn_timer.stop()
	
	# Optionally, reset any other properties as needed
	spawn_position = global_position # Update spawn position to current position

	_disable_collisions(false)


func _disable_collisions(_enabled: bool) -> void:
	# Enable or disable collision
	if physical_collider:
		physical_collider.set_deferred("disabled", _enabled)
	if debug_enabled:
		if debug_enabled:
			var status: String = "disabled"
			if not _enabled:
				status = "enabled"
			print_debug("DissolvingPlatform: Collision " + status + " after respawn.")
