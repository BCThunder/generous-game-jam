# DissolveTileMapLayer.gd
# Extends TileMapLayer to fade individual tiles in/out with collision toggles
#
# USAGE:
# 1. In your player controller's collision callback, obtain a reference to this TileMapLayer node:
#
#    var dissolve_map := get_node("../DissolveTileMapLayer")  # adjust the path accordingly
#    var collision_point := collision.position  # or global_position when detecting
#    var cell := dissolve_map.local_to_map(collision_point)
#    dissolve_map.start_dissolve(cell)
#
# 2. Ensure your TileMapLayer node is named or has a unique path so you can access it easily.
# 3. You can also emit a custom signal from your player and have this map listen to it:
#
#    // In DissolveTileMapLayer.gd _ready():
#    get_tree().get_root().connect("player_landed", Callable(self, "on_player_landed"))
#
#    func on_player_landed(collision_point: Vector2):
#        var cell = local_to_map(collision_point)
#        start_dissolve(cell)
#
# 4. The start_dissolve(cell) method handles fading and collision toggles automatically.

extends TileMapLayer

@export var fade_time: float = 1.0 # Duration of each fade (out or in)
@export var mid_toggle: float = 0.5 # Fraction of fade_time when collision is re-enabled
@export var respawn_delay: float = 2.0 # Delay before starting the fade-in

@export_category("Debug")
@export var debug_enabled: bool = false
@export var debug_replacement: bool = false
@export var debug_fade: bool = false

func dissolve_tile(cell: Vector2i) -> void:
	if debug_enabled:
		print_debug("DissolveTileMapLayer: Starting dissolve for cell ", cell)
	var source_id = get_cell_source_id(cell)
	if source_id < 0:
		if debug_enabled:
			print_debug("DissolveTileMapLayer: Cell ", cell, " has no tile set, skipping dissolve.")
		return

	var atlas_coords = get_cell_atlas_coords(cell)
	var alt_id = get_cell_alternative_tile(cell)

	# Create AtlasTexture for the tile's current appearance
	var ts = tile_set
	var src = ts.get_source(source_id) as TileSetAtlasSource
	var region = src.get_tile_texture_region(atlas_coords)
	var atlas_tex = AtlasTexture.new()
	atlas_tex.atlas = src.texture
	atlas_tex.region = region

	# Remove the tile (disable collision)
	set_cell(cell, -1)
	update_internals()

	# Spawn overlay sprite
	var spr = Sprite2D.new()
	spr.texture = atlas_tex
	spr.position = map_to_local(cell)
	add_child(spr)
	spr.modulate.a = 1.0

	# Fade-out tween
	var tw = create_tween()
	tw.tween_property(spr, "modulate:a", 0.0, fade_time)
	var fade_out_cb = Callable(self, "_on_fade_out_complete").bind(cell, source_id, atlas_coords, alt_id, spr)
	tw.tween_callback(fade_out_cb)

	# Schedule mid-fade collision re-enable
	var timer = get_tree().create_timer(fade_time * mid_toggle)
	timer.timeout.connect(Callable(self, "_reenable_collision"), [cell, source_id, atlas_coords, alt_id])

func _reenable_collision(cell: Vector2i, source_id: int, atlas_coords: Vector2i, alt_id: int) -> void:
	set_cell(cell, source_id, atlas_coords, alt_id)
	update_internals()
	if debug_enabled:
		print_debug("DissolveTileMapLayer: Collision re-enabled for cell ", cell, " at mid-toggle.")

func _on_fade_out_complete(cell: Vector2i, source_id: int, atlas_coords: Vector2i, alt_id: int, spr: Sprite2D) -> void:
	spr.queue_free()
	var timer = get_tree().create_timer(respawn_delay)
	timer.timeout.connect(Callable(self, "_start_fade_in"), [cell, source_id, atlas_coords, alt_id])

func _start_fade_in(cell: Vector2i, source_id: int, atlas_coords: Vector2i, alt_id: int) -> void:
	if debug_enabled and debug_fade:
		print_debug("DissolveTileMapLayer: Starting fade-in for cell ", cell)
	# Re-insert the tile (enable collision)
	set_cell(cell, source_id, atlas_coords, alt_id)
	update_internals()

	# Create overlay sprite for fade-in
	var ts = tile_set
	var src = ts.get_source(source_id) as TileSetAtlasSource
	var region = src.get_tile_texture_region(atlas_coords)
	var atlas_tex = AtlasTexture.new()
	atlas_tex.atlas = src.texture
	atlas_tex.region = region

	var spr = Sprite2D.new()
	spr.texture = atlas_tex
	spr.position = map_to_local(cell)
	add_child(spr)
	spr.modulate.a = 0.0
	var tw = create_tween()
	tw.tween_property(spr, "modulate:a", 1.0, fade_time)
	var fade_in_cb = Callable(self, "_on_fade_in_complete").bind(spr)
	tw.tween_callback(fade_in_cb)

func _on_fade_in_complete(spr: Sprite2D) -> void:
	spr.queue_free()
	if debug_enabled and debug_fade:
		print_debug("DissolveTileMapLayer: Fade-in complete, sprite removed.")
