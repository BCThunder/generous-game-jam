extends CanvasLayer

@onready var water_amount: Label = $Panel/CollectibleAmount/Water/WaterAmount
@onready var npc_amount: Label = $Panel/CollectibleAmount/NPCs/NPCAmount


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


func update_collectibles():
	water_amount.text = "x" + str(GameManager.collected_water)


func pause_game():
	if Input.is_action_just_pressed("esc") and get_tree().paused == false:
		update_collectibles()
		pause()
	elif Input.is_action_just_pressed("esc") and get_tree().paused == true:
		resume()


func _on_resume_button_pressed() -> void:
	GameManager.is_in_the_game = true
	resume()


func _on_exit_button_pressed() -> void:
	GameManager.is_in_the_game = false
	resume()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
