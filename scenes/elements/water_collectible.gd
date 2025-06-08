extends Area2D

@onready var collect_sfx: AudioStreamPlayer2D = $CollectSFX

func _on_body_entered(_body: Node2D) -> void:
	GameManager.collected_water += 1
	self.set_deferred("monitoring", false)
	collect_sfx.play()
	print("Small water collected!")
