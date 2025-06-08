@tool
extends TileMapLayer

@export_category("Debug")
@export var debug_enabled: bool = false
@export var debug_replacement: bool = false
@export var debug_visibility: bool = false

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
					if child is Node2D and child != self:
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
		if debug_enabled and debug_replacement:
			print_debug("ReplaceTileWithScene: Starting replacement process...")
		make_layer_visible()
		_replace()
	else:
		make_layer_invisible()
		_replace()
	if not replacement or not replacement.scene:
		push_error("ReplaceTileWithScene: No valid scene_tile_pair set.")
		return

func _replace() -> void:
	var used_rect = get_used_rect()
	for x in range(used_rect.position.x, used_rect.position.x + used_rect.size.x):
		for y in range(used_rect.position.y, used_rect.position.y + used_rect.size.y):
			var cell = Vector2i(x, y)
			var tile_id = get_cell_source_id(cell)
			if tile_id == -1:
				continue

			var tile_data = get_cell_tile_data(cell)
			var type_value = tile_data.get_custom_data("Type") if tile_data else null

			if type_value == replacement.type:
				var scene_instance = replacement.scene.instantiate()
				scene_instance.name = "Replacement_%d" % y
				if not scene_instance:
					push_error("ReplaceTileWithScene: Failed to instantiate scene from PackedScene.")
					continue

				scene_instance.global_position = map_to_local(cell) + offset
				add_child(scene_instance)
				if debug_enabled and debug_replacement:
					print_debug("Replaced tile at %s with scene %s" % [str(cell), replacement.scene.resource_name])

func make_layer_invisible():
	self.self_modulate = Color(1, 1, 1, 0)
	if debug_enabled and debug_visibility:
		print_debug("Layer made invisible.")

func make_layer_visible():
	self.self_modulate = Color(1, 1, 1, 1)
	if debug_enabled and debug_visibility:
		print_debug("Layer made visible.")
