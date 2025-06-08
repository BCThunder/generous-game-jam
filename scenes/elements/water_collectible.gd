extends Area2D

@onready var collect_sfx: AudioStreamPlayer2D = $CollectSFX
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D

func _ready():
	if SaveManager.get_collected_water_state(name) == false:
		disable_self()

func _on_body_entered(_body: Node2D) -> void:
	print_debug("Water collectible collected by: ", _body.name)
	GameManager.add_water()
	disable_self()
	collect_sfx.play()

func disable_self():
	self.set_deferred("monitoring", false)
	collision_shape_2d.set_deferred("monitoring", false)
