@tool
extends TileMapLayer

@export_category("Debug")
@export var debug_enabled: bool = false
@export var debug_replacement: bool = false
@export var debug_visibility: bool = false

@export var replacements: Array[SceneTilePair] = [] # Array of SceneTilePair

@export var offset: Vector2 = Vector2(0, 0):
	set(value):
		offset = value
		if replacements.size() > 0 and Engine.is_editor_hint():
			replace_with_scene()

@export var run_replacement: bool = false:
	set(value):
		if Engine.is_editor_hint():
			if value:
				replace_with_scene()
			else:
				# Remove all child nodes that were added as replacements
				for child in get_children():
					if child is Node2D and child != self:
						child.queue_free()
		run_replacement = value # do not auto-reset, so you can toggle on/off

func _ready() -> void:
	if not Engine.is_editor_hint():
		if not replacements or replacements.size() == 0:
			push_error("ReplaceTileWithScene: No valid scene_tile_pairs set.")
			return
		replace_with_scene()

func replace_with_scene() -> void:
	if Engine.is_editor_hint():
		if debug_enabled and debug_replacement:
			print_debug("ReplaceTileWithScene: Starting replacement process...")
		make_layer_visible()
		_replace()
	else:
		make_layer_invisible()
		_replace()
	if not replacements or replacements.size() == 0:
		push_error("ReplaceTileWithScene: No valid scene_tile_pairs set.")
		return

func _replace() -> void:
	var used_rect = get_used_rect()
	for x in range(used_rect.position.x, used_rect.position.x + used_rect.size.x):
		for y in range(used_rect.position.y, used_rect.position.y + used_rect.size.y):
			var cell = Vector2i(x, y)
			var tile_id = get_cell_source_id(cell)
			if tile_id == -1:
				continue

			var tile_data: TileData = get_cell_tile_data(cell)
			var type_value = tile_data.get_custom_data("Type") if tile_data else null

			for pair in replacements:
				if pair and pair.type == type_value:
					var scene_instance = pair.scene.instantiate()
					if not scene_instance:
						push_error("ReplaceTileWithScene: Failed to instantiate scene from PackedScene.")
						continue


					scene_instance.global_position = map_to_local(cell) + offset

					
					scene_instance.rotation = get_rotation_vector(cell)

					add_child(scene_instance)
					if debug_enabled and debug_replacement:
						print_debug("Replaced tile at %s with scene %s (rotation: %s)" % [str(cell), pair.scene.resource_name, str(scene_instance.rotation)])
					break # Only replace with the first matching pair

func make_layer_invisible():
	self.self_modulate = Color(1, 1, 1, 0)
	if debug_enabled and debug_visibility:
		print_debug("Layer made invisible.")

	self.set_deferred("collision_enabled", false)

func make_layer_visible():
	self.self_modulate = Color(1, 1, 1, 1)
	if debug_enabled and debug_visibility:
		print_debug("Layer made visible.")

	self.set_deferred("collision_enabled", false)


func get_rotation_vector(coords: Vector2i) -> float:
	var vec = Vector2.RIGHT
	var alt = get_cell_alternative_tile(coords)

	if alt & TileSetAtlasSource.TRANSFORM_TRANSPOSE:
		vec = Vector2(vec.y, vec.x)
	if alt & TileSetAtlasSource.TRANSFORM_FLIP_H:
		vec.x *= -1
	if alt & TileSetAtlasSource.TRANSFORM_FLIP_V:
		vec.y *= -1

	# Convert the direction vector to a degree angle
	return vec.angle()
