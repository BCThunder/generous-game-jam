extends Node2D

var checkpoint_manager
var player


func _ready() -> void:
	checkpoint_manager = get_parent().get_node("CheckpointManager")
	player = get_parent().get_node("Player")

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		print("You died...")
		kill_player()

func kill_player():
	player.position = checkpoint_manager.respawn_at_checkpoint()
