extends Node

var config = ConfigFile.new()
var player

func _ready():
	player = get_parent().get_node("Player")

func save_game():
	print("Checkpoint Location to save: ", $%CheckpointManager.last_position)
	config.set_value("Player", "position", $%CheckpointManager.last_position)
	config.save("res://game_save.cfg")
	print("Game Saved!")

func load_save():
	var save_file = config.load("res://game_save.cfg")
	if save_file == OK:
		var player_last_location = config.get_value("Player", "position")
		print("Spawn character at ", player_last_location)
		$%CheckpointManager.update_checkpoint(player_last_location)
		print("Save Loaded!")


func _on_save_button_pressed() -> void:
	save_game()


func _on_load_button_pressed() -> void:
	load_save()
	player.position = $%CheckpointManager.respawn_at_checkpoint()
