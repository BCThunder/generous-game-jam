extends Node
signal ability_requested(ability_type: String)

@export var ability_bindings: Dictionary = {
	"jump": "JumpAbility",
	"dash": "DashAbility",
	"double_jump": "DoubleJumpAbility",
	"context_interact": "SlamAbility"
}

func _ready():
	# Tell Godot to send *all* InputEventAction here, before unhandled/unconsumed.
	set_process_input(true)


func _input(event: InputEvent) -> void:
	# Only care about *mapped* actions (not raw keys), pressed, non-echo.
	if event is InputEventAction and event.pressed and not event.is_echo():
		var ability_type = ability_bindings.get(event.action, null)
		if ability_type:
			emit_signal("ability_requested", ability_type)
			# Prevent any other node (UI or gameplay) from seeing this event
			# if you really want to claim it here.
			event.accept()
