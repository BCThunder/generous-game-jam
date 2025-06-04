extends Node

var last_position
var player

func _ready():
	player = get_parent().get_node("Player")
	last_position = player.global_position
	if player:
		print("Initial Player Position Saved")

func update_checkpoint(location):
	last_position = location

func respawn_at_checkpoint():
	return last_position
