extends Area2D


@onready var sprite = $Sprite2D2
@export var intervals_per_second: float = 1.0 # Frequency of the sine wave oscillation
var is_active: bool = false
@export_category("Debug")
@export var debug_state_changes: bool = false

func _ready() -> void:
	is_active = false

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if debug_state_changes:
		print_debug("Body entered: ", body.name)

	is_active = true
	
	var tween := create_tween()
	await tween.tween_property(sprite, "modulate", Color(1, 1, 1, .8), 0.5).finished

	var delta = get_physics_process_delta_time()
	var time = 0.0
	while is_active:
		time += delta
		# Sine wave oscillates between 0 and 1
		var brightness = 0.5 + 0.5 * sin(time * intervals_per_second * 2 * PI)

		sprite.modulate.a = lerp(.5, 1.0, brightness)
		await get_tree().physics_frame
		print_debug("Brightness: ", brightness)
	
func _on_body_exited(body: Node2D) -> void:
	if debug_state_changes:
		print_debug("Body exited: ", body.name)

	is_active = false

	var tween := create_tween()
	await tween.tween_property(sprite, "modulate", Color(1, 1, 1, 0), 0.5).finished
