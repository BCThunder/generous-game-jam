extends Area2D

var checkpoint_manager
@onready var respawn_point: Marker2D = $RespawnPoint


func _ready() -> void:
	checkpoint_manager = get_parent().get_parent().get_node("CheckpointManager")

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		print("Checkpoint reached!!")
		checkpoint_manager.update_checkpoint(respawn_point.global_position)
