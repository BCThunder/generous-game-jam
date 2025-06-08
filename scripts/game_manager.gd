extends Node

var can_player_interact := false
var tile_data := []
var collected_water := 0
var is_in_the_game := false

# Oasis Levels
var stage_progress := {}
var stage_references := {}

var current_npc = null


func _ready():
	is_in_the_game = false


func _init_game():
	is_in_the_game = true
	
	while get_tree().get_current_scene() == null:
		await get_tree().process_frame
	
	# Initialize The Player's Oasis Progression
	check_water_threshold()
	
	#for i in range(1, 5):
		#var node_name = "OasisStage" + str(i)
		#print("Init oasis stage: ", node_name)
		#var node := get_tree().get_current_scene().get_node(node_name)
		#stage_references[node_name] = node
		#stage_progress[node_name] = node.visible


func end_game():
	pass
	
	# TO-DO
	# play cutscene
	# add finish screen


func add_water():
	collected_water += 1
	check_water_threshold()


func check_water_threshold():
	print("You have: " + str(collected_water) + " water")
	
	if collected_water < 5:
		return
	
	if collected_water > 5:
		stage_references["OasisStage1"] = true
		
	if collected_water > 20:
		stage_references["OasisStage2"] = true
		
	if collected_water > 30:
		stage_references["OasisStage3"] = true
		
	if collected_water > 40:
		stage_references["OasisStage4"] = true


func interact_with_npc():
	if current_npc:
		current_npc.emit_signal("player_interact")
