extends Node

var config = ConfigFile.new()
var player
var save_path := "res://game_save.cfg"


func _ready():
	player = get_tree().get_current_scene().get_node("Player")


func save_game():
	print("Checkpoint Location to save: ", $%CheckpointManager.last_position)
	config.set_value("Player", "position", $%CheckpointManager.last_position)
	config.set_value("Level", "small_water", GameManager.tile_data)
	config.save(save_path)
	
	var error := config.save(save_path)
	if error:
		print("An error happened while saving data: ", error)


func load_save():
	var save_file = config.load(save_path)
	if save_file == OK:
		var player_last_location = config.get_value("Player", "position")
		GameManager.tile_data = config.get_value("Level", "small_water")
		print("Spawn character at ", player_last_location)
		$%CheckpointManager.update_checkpoint(player_last_location)


func _on_save_button_pressed() -> void:
	save_game()


func _on_load_button_pressed() -> void:
	load_save()
	player.position = $%CheckpointManager.respawn_at_checkpoint()
