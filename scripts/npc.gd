extends CharacterBody2D

@onready var water_sprite: Sprite2D = $WaterSprite
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var walk_timer: Timer = $WalkTimer

@export var patrol_points: Node
@export var walk_time := 4
@export var SPEED := 1500
@export var GRAVITY := 1000

signal player_interact

var can_walk := false
var direction := Vector2.LEFT
var number_of_points : int
var point_positions: Array[Vector2]
var current_point : Vector2
var current_point_position : int
var is_saved := false

func _ready():
	water_sprite.visible = false
	player_interact.connect(Callable(self, "_on_player_interact"))
	
	if patrol_points != null:
		number_of_points = patrol_points.get_children().size()
		for point in patrol_points.get_children():
			point_positions.append(point.global_position)
		current_point = point_positions[current_point_position]
	else:
		print_debug("No patrol points")


func _physics_process(delta: float) -> void:
	gravity(delta)
	idle(delta)
	walk(delta)
	
	move_and_slide()


func gravity(delta : float):
	velocity.y += GRAVITY * delta


func idle(delta : float):
	if !can_walk:
		velocity.x = move_toward(velocity.x, 0, SPEED * delta)
		play_animation("idle")


func walk(delta : float):
	if !can_walk and !GameManager.can_player_interact:
		return
	
	if abs(position.x - current_point.x) > 0.5:
		velocity.x = direction.x * SPEED * delta
		play_animation("walk")
	else: 
		current_point_position += 1
		
		if current_point_position >= number_of_points:
			current_point_position = 0
			
		current_point = point_positions[current_point_position]
		
		if current_point.x > position.x:
			direction = Vector2.RIGHT
		else:
			direction = Vector2.LEFT
		
		can_walk = false
		walk_timer.start()
		
	animated_sprite_2d.flip_h = direction.x > 0


func play_animation(anim_to_play : String):
	match anim_to_play:
		"walk":
			if !is_saved:
				animated_sprite_2d.play("dirty_walk")
			else:
				animated_sprite_2d.play("clean_walk")
		"idle":
			if !is_saved:
				animated_sprite_2d.play("dirty_idle")
			else:
				animated_sprite_2d.play("clean_idle")


func _on_interact_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		GameManager.can_player_interact = true
		GameManager.current_npc = self
		water_sprite.visible = true


func _on_interact_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		GameManager.can_player_interact = false
		GameManager.current_npc = null
		water_sprite.visible = false


func _on_player_interact():
	is_saved = true


func _on_walk_timer_timeout() -> void:
	can_walk = true
