extends CanvasLayer


func _ready():
	self.visible = false


func _process(_delta: float) -> void:
	pause_game()


func pause():
	get_tree().paused = true
	self.visible = true


func resume():
	self.visible = false
	get_tree().paused = false


func pause_game():
	if Input.is_action_just_pressed("esc") and get_tree().paused == false:
		pause()
	elif Input.is_action_just_pressed("esc") and get_tree().paused == true:
		resume()


func _on_resume_button_pressed() -> void:
	resume()


func _on_exit_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
