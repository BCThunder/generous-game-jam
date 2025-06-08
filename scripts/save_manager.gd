extends Node

var config = ConfigFile.new()
var player
var save_path := "res://game_save.cfg"
var last_location
var has_water_been_collected := {}


func _ready():
	get_tree().node_added.connect(_on_scene_changed)
	


func save_game():
	config.set_value("Player", "position", last_location)
	config.set_value("Player", "collected_water", GameManager.collected_water)
	save_collected_water()
	config.set_value("Level", "stage_progress", GameManager.stage_progress)
	config.set_value("Level", "small_water", has_water_been_collected)
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
		has_water_been_collected = config.get_value("Level", "small_water")
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
		player = _find_player()
	
		# Delay call until all nodes are ready
		await get_tree().process_frame
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
func save_collected_water():
	var small_water_tiles = get_tree().get_nodes_in_group("SmallWater")
	for tile in small_water_tiles:
		has_water_been_collected[tile.name] = tile.monitoring

func load_collected_water():
	var small_water_tiles = get_tree().get_nodes_in_group("SmallWater")
	for tile in small_water_tiles:
		if has_water_been_collected.has(tile.name):
			tile.set_deferred("monitoring", has_water_been_collected[tile.name])
		else:
			tile.set_deferred("monitoring", true)  # default

		
func get_collected_water_state(tile_name):
	return has_water_been_collected.get(tile_name, false)

# Manage Checkpoints
func update_checkpoint(location):
	last_location = location
	save_game()

func spawn_player():
	if not last_location:
		player = _find_player()
		last_location = player.global_position
		player.global_position = last_location
