extends Node

var can_player_interact := false
var tile_data := []
var collected_water := 0

func remember_water(tilemap: TileMapLayer, _file_path: String):
	for tile in tilemap.get_children(): # Layer 0, change if needed
		tile_data.append(tile.monitorable)

func add_water():
	collected_water += 1
	check_water_threshold()

func check_water_threshold():
	print("You have: " + str(collected_water) + " water")
	match collected_water:
		1:
			print("You have 1 water")
		2:
			print("You got 2 water")
		3:
			print("Clean the doods")
		_:
			print('bruh')
			
