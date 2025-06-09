extends CanvasLayer

@onready var settings_panel: Panel = $SettingsPanel
@onready var button_container: BoxContainer = $Buttons
@onready var credits: Panel = $Credits

func _ready() -> void:
	settings_panel.visible = false

	$Buttons/LoadSaveButton.disabled = not SaveManager.has_valid_save()


func _on_start_button_pressed() -> void:
	if !GameManager.is_game_over:
		get_tree().change_scene_to_file("res://scenes/Level/the_beginning.tscn")
	elif GameManager.is_game_over:
		get_tree().change_scene_to_file("res://scenes/Level/Blackout scene.tscn")
	
	GameManager._init_game()

func _on_load_save_button_pressed() -> void:
	SaveManager.load_save()
	get_tree().change_scene_to_file("res://scenes/Level/Blackout scene.tscn")


func _on_settings_button_pressed() -> void:
	settings_panel.visible = true
	button_container.visible = false


func _on_exit_game_button_renamed() -> void:
	get_tree().quit()


func _on_close_settings_button_pressed() -> void:
	settings_panel.visible = false
	button_container.visible = true


func convert_volume_to_db(percentage) -> float:
	var vol_scale := 20.0
	var divisor := 50.0
	return vol_scale * log(percentage / divisor) / log(10)


func _on_music_slider_value_changed(value: float) -> void:
	if value == 0:
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), true)
	elif value > 0:
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), false)
	
	var decibles := convert_volume_to_db(value)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), decibles)


func _on_sfx_label_2_value_changed(value: float) -> void:
	if value == 0:
		AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), true)
	elif value > 0:
		AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), false)
	
	var decibles := convert_volume_to_db(value)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), decibles)


func _on_close_credits_button_pressed() -> void:
	print("Credits button pressed")
	credits.visible = false


func _on_credits_button_pressed() -> void:
	credits.visible = true
