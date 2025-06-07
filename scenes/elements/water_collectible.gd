extends Area2D

@export_category("Object")
@export var small_water_scene: PackedScene:
	set(value):
		if value and value is PackedScene:
			small_water_scene = value
			small_water_instance = small_water_scene.instantiate()
			
var small_water_instance: Node2D = null

func _on_body_entered(_body: Node2D) -> void:
	GameManager.collected_water += 1
	self.monitorable = false
	
	print("Small water collected!")
