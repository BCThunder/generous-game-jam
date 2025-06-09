extends Area2D

@onready var collect_sfx: AudioStreamPlayer2D = $CollectSFX
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D

func _ready():
	add_to_group("SmallWater")
	if SaveManager.get_collected_water_state(name):
		disable_self()

func disable_self():
	self.set_deferred("monitoring", false)
	collision_shape_2d.set_deferred("monitoring", false)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		GameManager.add_water(self)
		disable_self()
		collect_sfx.play()
