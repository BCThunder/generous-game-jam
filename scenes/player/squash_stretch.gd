extends AnimatedSprite2D

@export var stretch_factor := 0.003
@export var squash_factor := 0.003
@export var min_scale := 0.7
@export var max_scale := 1.3
@export var skew_factor := 0.002 # New: tweak for desired skew effect
@export var max_skew := 0.3 # New: clamp max skew

func _process(delta):
	var parent = get_parent()
	var vertical_velocity = parent.velocity.y
	var horizontal_velocity = parent.velocity.x

	var scale_y = clamp(1.0 - vertical_velocity * squash_factor, min_scale, max_scale)
	var scale_x = clamp(1.0 + vertical_velocity * stretch_factor, min_scale, max_scale)

	if vertical_velocity < 0:
		scale_y = clamp(1.0 + abs(vertical_velocity) * stretch_factor, min_scale, max_scale)
		scale_x = clamp(1.0 - abs(vertical_velocity) * squash_factor, min_scale, max_scale)
	elif vertical_velocity > 0:
		scale_y = clamp(1.0 - abs(vertical_velocity) * squash_factor, min_scale, max_scale)
		scale_x = clamp(1.0 + abs(vertical_velocity) * stretch_factor, min_scale, max_scale)
	else:
		scale_x = 1.0
		scale_y = 1.0

	scale = Vector2(scale_x, scale_y)

	# Skew based on x velocity
	skew = clamp(horizontal_velocity * skew_factor, -max_skew, max_skew)

	# Flip sprite based on x movement
	if horizontal_velocity > 0:
		flip_h = false
	elif horizontal_velocity < 0:
		flip_h = true
