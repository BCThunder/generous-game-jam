extends Node

var can_player_interact := false
var water_threshold_met := false

var tile_data := []
var collected_water := 0
var is_in_the_game := false
var fresh_game := true
var is_game_over := false

# Oasis Levels
var stage_progress := {}

var current_npc = null


func _ready():
	is_in_the_game = false
	

func _init_game():
	is_in_the_game = true
	
	while get_tree().get_current_scene() == null:
		await get_tree().process_frame
	
	# Initialize The Player's Oasis Progression
	check_water_threshold()
	
	if is_game_over:
		SaveManager.teleport_to_top()


func end_game():
	is_game_over = true
	toggle_hud_tooltip(false)

func add_water(water_to_save : Area2D, amount : int):
	print("You collected water!")
	collected_water += amount
	SaveManager.save_collected_water(water_to_save)
	check_water_threshold()


func check_water_threshold():
	print("You have: " + str(collected_water) + " water")
	
	if collected_water < 5:
		return
	
	if collected_water >= 5:
		get_tree().get_current_scene().get_node("OasisStage1").visible = true
		get_tree().get_current_scene().get_node("NPC_Dwarf").visible = true
		water_threshold_met = true
		toggle_hud_tooltip(true)
		print_debug("Stage 1 Met")
	if collected_water >= 20:
		get_tree().get_current_scene().get_node("OasisStage2").visible = true
		var npc_human := get_tree().get_current_scene().get_node("NPC_Human")
		npc_human.global_position.x += 150
		get_tree().get_current_scene().get_node("NPC_Elf").visible = true
		water_threshold_met = true
		toggle_hud_tooltip(true)
		print_debug("Stage 2 Met")
	if collected_water >= 30:
		get_tree().get_current_scene().get_node("OasisStage3").visible = true
		water_threshold_met = true
		toggle_hud_tooltip(true)
		print_debug("Stage 3 Met")
	if collected_water >= 40:
		get_tree().get_current_scene().get_node("OasisStage4").visible = true
		water_threshold_met = true
		toggle_hud_tooltip(true)
		print_debug("Stage 4 Met")


func toggle_hud_tooltip(toggle : bool):
	var hud = get_tree().get_current_scene().get_node("HUD")
	hud.get_child(0).visible = toggle


func interact_with_npc():
	if current_npc and water_threshold_met:
		current_npc.emit_signal("player_interact")
		water_threshold_met = false
