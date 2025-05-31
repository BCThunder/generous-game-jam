extends Area2D

var gm
@onready var water_sprite: Sprite2D = $WaterSprite

func _ready():
	gm = get_node("%GameManager")
	water_sprite.visible = false
	
func _update():
	pass
	
func move():
	pass

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		gm.can_player_interact = true
		water_sprite.visible = true
		print("Player can interact:", gm.can_player_interact)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		gm.can_player_interact = false
		water_sprite.visible = false
		print("Player can interact:", gm.can_player_interact)
