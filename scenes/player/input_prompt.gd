extends Sprite2D

@export var required_flags: Array[String] = [] # List of flag names to check

@export_category("Debug")
@export var flag_debug: bool = false
var parent: Node = null
var previous_visible: bool = false # Tracks the previous visibility state

func _ready():
	visible = false
	previous_visible = visible
	parent = get_parent()
	if flag_debug:
		print("InputPrompt: Parent node is ", parent.name)

func _process(_delta):
	var enabled = false
	var debug_message = "InputPrompt: Checking flags: "

	for flag in required_flags:
		if flag in parent:
			var flag_value = parent.get(flag)
			debug_message += flag + "=" + str(flag_value) + "; "
			if flag_value:
				enabled = true
				break
		else:
			debug_message += flag + " (not found); "

	visible = enabled

	if flag_debug and visible != previous_visible:
		print(debug_message)
		if not visible:
			print("InputPrompt: No required flags are enabled")

	previous_visible = visible
