extends Node

var last_position
var player

func _ready():
	player = get_tree().get_current_scene().get_node("Player")
	last_position = player.global_position

func update_checkpoint(location):
	last_position = location

func respawn_at_checkpoint():
	return last_position
