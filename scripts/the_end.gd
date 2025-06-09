extends Area2D


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		body.play_animation("fade_out")
		GameManager.end_game()
		
		await body.is_animation_finished()
		
		get_tree().change_scene_to_file("res://scenes/Level/the_end.tscn")
