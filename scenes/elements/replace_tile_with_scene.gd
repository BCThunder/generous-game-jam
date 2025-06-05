@tool
extends TileMapLayer

@export var replacement: SceneTilePair = null:
	set(value):
		if value and value is SceneTilePair:
			replacement = value
			if Engine.is_editor_hint():
				replace_with_scene()
		else:
			push_error("ReplaceTileWithScene: Invalid scene_tile_pair provided.")

@export var offset: Vector2 = Vector2(0, 0):
	set(value):
		offset = value
		if replacement and Engine.is_editor_hint():
			replace_with_scene()

@export var run_replacement: bool = false:
	set(value):
		if Engine.is_editor_hint():
			if value:
				replace_with_scene()
			else:
				# Remove all child nodes that were added as replacements
				for child in get_children():
					# Optionally, check for a marker or type if you only want to remove certain nodes
					if child is Node2D and child != self:
						#remove_child(child)
						child.queue_free()
			run_replacement = value # do not auto-reset, so you can toggle on/off

func _ready() -> void:
	if not Engine.is_editor_hint():
		if not replacement or not replacement.scene:
			push_error("ReplaceTileWithScene: No valid scene_tile_pair set.")
			return
		replace_with_scene()

func replace_with_scene() -> void:
	if Engine.is_editor_hint():
		print_debug("ReplaceTileWithScene: Starting replacement process...")
	
	if not replacement or not replacement.scene:
		push_error("ReplaceTileWithScene: No valid scene_tile_pair set.")
		return

	# Get the used rectangle (area with tiles)
	var used_rect = get_used_rect()
	for x in range(used_rect.position.x, used_rect.position.x + used_rect.size.x):
		for y in range(used_rect.position.y, used_rect.position.y + used_rect.size.y):
			var cell = Vector2i(x, y)
			var tile_id = get_cell_source_id(cell)
			if tile_id == -1:
				continue

			var tile_data = get_cell_tile_data(cell)
			var type_value = tile_data.get_custom_data("Type") if tile_data else null

			# Only replace if the type matches
			if type_value == replacement.type: # assuming you add this to SceneTilePair
				var scene_instance = replacement.scene.instantiate()
				if not scene_instance:
					push_error("ReplaceTileWithScene: Failed to instantiate scene from PackedScene.")
					continue

				# Position the scene at the cell's world position
				scene_instance.global_position = map_to_local(cell) + offset
				add_child(scene_instance) # Add to parent so it's not deleted with the layer

				set_cell(cell, -1) # Remove the tile

				print_debug("Replaced tile at %s with scene %s" % [str(cell), replacement.scene.resource_name])
