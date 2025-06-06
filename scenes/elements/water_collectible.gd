extends Area2D


func _on_body_entered(body: Node2D) -> void:
	GameManager.collected_water += 1
	self.monitorable = false
