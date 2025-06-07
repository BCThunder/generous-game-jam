extends CanvasLayer

@onready var settings_panel: Panel = $SettingsPanel
@onready var button_container: BoxContainer = $Buttons

func _ready() -> void:
	settings_panel.visible = false

	$Buttons/LoadSaveButton.disabled = not SaveManager.has_valid_save()


func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Level/Blackout scene.tscn")


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
	var scale := 20.0
	var divisor := 50.0
	return scale * log(percentage / divisor) / log(10)


func _on_volume_changed(value: float) -> void:
	if value == 0:
		AudioServer.set_bus_mute(0, true)
	elif value > 0:
		AudioServer.set_bus_mute(0, false)
	
	var decibles := convert_volume_to_db(value)
	AudioServer.set_bus_volume_db(0, decibles)
