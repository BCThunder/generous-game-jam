extends Node

var can_player_interact := false
var tile_data := []
var collected_water := 0

func remember_water(tilemap: TileMapLayer, file_path: String):
	for tile in tilemap.get_children(): # Layer 0, change if needed
		tile_data.append(tile.monitorable)
