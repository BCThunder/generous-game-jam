extends Node

var last_position
var player

func _ready():
	player = get_tree().get_current_scene().get_node("Player")
	last_position = player.global_position
	if player:
		print_debug("Initial Player Position Saved")

func update_checkpoint(location):
	last_position = location
	print_debug("Checkpoint location saved")

func respawn_at_checkpoint():
	print_debug("Respawn at: ", last_position)
	return last_position
