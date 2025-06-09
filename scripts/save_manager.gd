extends Node

var config = ConfigFile.new()
var player
var save_path := "res://game_save.cfg"
var top_spawn_point := Vector2(-63.0, -16.0)
var last_location
var collected_water_tiles := []


func _ready():
	get_tree().node_added.connect(_on_scene_changed)
	

func save_game():
	config.set_value("Player", "position", last_location)
	config.set_value("Player", "collected_water", GameManager.collected_water)
	config.set_value("Level", "stage_progress", GameManager.stage_progress)
	config.set_value("Level", "small_water", collected_water_tiles)
	config.save(save_path)
	
	var error := config.save(save_path)
	if error:
		print("An error happened while saving data: ", error)


func load_save():
	var save_file = config.load(save_path)
	if save_file == OK:
		last_location = config.get_value("Player", "position")
		GameManager.collected_water = config.get_value("Player", "collected_water")
		GameManager.stage_progress = config.get_value("Level", "stage_progress")
		collected_water_tiles = config.get_value("Level", "small_water")
		
		print("Player has collected: " + str(GameManager.collected_water) + " water.")
		
		load_collected_water()
		update_checkpoint(last_location)


func has_valid_save() -> bool:
	if not FileAccess.file_exists(save_path):
		return false
	var test_config = ConfigFile.new()
	var err = test_config.load(save_path)
	if err != OK:
		return false
	if not test_config.has_section_key("Player", "position"):
		return false
	if not test_config.has_section_key("Level", "small_water"):
		return false
	
	# You can add more checks here to ensure the save file is valid


	# Optionally check for other required keys/sections here
	return true


func _on_scene_changed(_node: Node) -> void:
	if not player and GameManager.is_in_the_game:
		# Delay call until all nodes are ready
		await get_tree().process_frame
		await get_tree().process_frame
		
		player = _find_player()
		
		await get_tree().process_frame
		load_save()
		load_collected_water()
		spawn_player()


func _find_player():
	player = get_tree().get_current_scene().get_node("Player")
	if not player:
		print("Error: Player node not found in the scene tree.")
		return null
	print_debug("Player node found: ", player.name, " type: ", player.get_class())
	return player


# Save collected water spots
func save_collected_water(water_to_save : Area2D):
	collected_water_tiles.append(water_to_save.name)


func load_collected_water():
	for tile in get_tree().get_nodes_in_group("SmallWater"):
		if tile.name in collected_water_tiles:
			print("Disabling collected water tile: ", tile.name)
			tile.set_deferred("monitoring", false)
			
			if tile.has_node("CollisionShape2D"):
				tile.get_node("CollisionShape2D").set_deferred("monitoring", false)


func get_collected_water_state(tile_name):
	return tile_name in collected_water_tiles


# Manage Checkpoints
func update_checkpoint(location):
	last_location = location
	save_game()


func spawn_player():
	if not last_location:
		player = _find_player()
		last_location = player.global_position
		player.global_position = last_location


func teleport_to_top():
	player = _find_player()
	player.global_position = top_spawn_point
