extends Area2D


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player") and SaveManager.last_location != SaveManager.top_spawn_point:
		print_debug("Initiate fast travel...")
		SaveManager.fast_travel()
