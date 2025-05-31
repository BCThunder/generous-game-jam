extends Area2D

var checkpoint_manager
@onready var respawn_point: Marker2D = $RespawnPoint


func _ready() -> void:
	checkpoint_manager = get_parent().get_parent().get_node("CheckpointManager")

func _on_body_entered(body: Node2D) -> void:
	print("Checkpoint reached!!")
	if body.is_in_group("Player"):
		checkpoint_manager.update_checkpoint(respawn_point.global_position)
