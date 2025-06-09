extends CanvasLayer

var current_slide := 1
@onready var slide_1: TextureRect = $Slide1
@onready var slide_2: TextureRect = $Slide2
@onready var slide_3: TextureRect = $Slide3

func _on_next_slide_button_pressed() -> void:
	current_slide += 1
	
	if current_slide >= 4:
		current_slide = 4
	
	print("Current slide: ", current_slide)
	
	match current_slide:
		1:
			slide_1.visible = true
			slide_2.visible = false
			slide_3.visible = false
		2:
			slide_1.visible = false
			slide_2.visible = true
			slide_3.visible = false
		3:
			slide_1.visible = false
			slide_2.visible = false
			slide_3.visible = true
		4:
			if name == "TheBeginning":
				get_tree().change_scene_to_file("res://scenes/Level/Blackout scene.tscn")
			elif name == "TheEnd":
				get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
