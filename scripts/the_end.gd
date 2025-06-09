extends Area2D


func _ready() -> void:
	# Connect the body_entered signal to the _on_body_entered function
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		body.play_animation("fade_out")
		GameManager.end_game()
		
		await body.is_animation_finished()
		
		get_tree().change_scene_to_file("res://scenes/Level/the_end.tscn")
