extends RigidBody2D


@export var shard_emitter: ShardEmitter


func _ready() -> void:
	if not ShardEmitter:
		push_error("Stalactite: No ShardEmitter set. Please assign a ShardEmitter in the inspector.")
		return

	body_entered.connect(_on_body_entered)

	self.freeze = true
	self.sleeping = true
	self.contact_monitor = false

func drop() -> void:
	call_deferred("_on_drop")

func _on_drop():
	self.sleeping = false
	self.freeze = false
	self.contact_monitor = true
	self.max_contacts_reported = 1
	
func _on_body_entered(body: Node) -> void:
	print_debug("Stalactite: Body entered - ", body.name)
	call_deferred("_after_contact")
	if shard_emitter:
		shard_emitter.call_deferred("shatter")
		
	else:
		push_error("Stalactite: No ShardEmitter set. Please assign a ShardEmitter in the inspector.")


func _after_contact() -> void:
	body_entered.disconnect(_on_body_entered)
	$CollisionShape2D.disabled = true
	self.freeze = true
	gravity_scale = 0.0
	await get_tree().create_timer(shard_emitter.lifetime).timeout
	queue_free()
