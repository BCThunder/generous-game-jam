extends Area2D

@onready var respawn_point: Marker2D = $RespawnPoint


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		SaveManager.update_checkpoint(respawn_point.global_position)
		print("Checkpoint reached!!")
