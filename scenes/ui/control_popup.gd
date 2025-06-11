extends Control

# Exported Arrays (untyped) so Godot won't enforce GDScript-only elements
@export var icon_entries: Array[IconEntry] = [] # Populate with IconEntry resources in Inspector
@export var text_entries: Array[TextEntry] = [] # Populate with TextEntry resources in Inspector

# Exported boolean to toggle following the parent target or not
@export var follow_parent: bool = true

# Follow-target parameters
@export var follow_target_path: NodePath
@export var vertical_offset: float = -40.0

# Bobbing parameters
@export var bobbing_enabled: bool = true
@export var bob_amplitude: float = 10.0
@export var bob_speed: float = 2.0

# Internal state
var _base_position: Vector2

func _ready() -> void:
	update_popup()

	# Initialize base_position either from the follow_target or from our starting global_position
	if follow_parent and follow_target_path:
		var tnode = get_node_or_null(follow_target_path)
		if tnode and tnode is Node2D:
			_base_position = tnode.global_position + Vector2(0, vertical_offset)
		else:
			_base_position = global_position
	else:
		_base_position = global_position

	set_physics_process(true) # Ensure _physics_process will be called

# Call this externally if you need to refresh icons/texts mid-game
func update_popup() -> void:
	_populate_icons()
	_populate_texts()

func _physics_process(delta: float) -> void:
	if follow_target_path:
		_follow_owner(delta)
	if bobbing_enabled:
		_apply_bobbing(delta)

func _follow_owner(_delta: float) -> void:
	if follow_target_path:
		var target_node = get_node_or_null(follow_target_path)
		if target_node and target_node is Node2D:
			_base_position = target_node.global_position + Vector2(0, vertical_offset)
		else:
			push_warning("ContextPopup: cannot find follow_target at '%s'" % follow_target_path)

func _apply_bobbing(delta: float) -> void:
	if not has_meta("time_elapsed"):
		set_meta("time_elapsed", 0.0)
	var t = get_meta("time_elapsed") + delta * bob_speed
	set_meta("time_elapsed", t)
	var offset_y = sin(t) * bob_amplitude
	global_position = _base_position + Vector2(0, offset_y)

func _populate_icons() -> void:
	for entry in icon_entries:
		if entry is IconEntry:
			var icon_node = get_node_or_null(entry.node_path)
			if icon_node:
				if icon_node is TextureRect:
					var tex = InputIconManager.get_icon_for_action(entry.action_name)
					icon_node.texture = tex
				else:
					push_warning("ContextPopup: node_path '%s' is not a TextureRect." % entry.node_path)
			else:
				push_warning("ContextPopup: cannot find node at '%s'" % entry.node_path)
		else:
			push_warning("ContextPopup: icon_entries contains a non-IconEntry resource.")

func _populate_texts() -> void:
	for entry in text_entries:
		if entry is TextEntry:
			var label_node = get_node_or_null(entry.node_path)
			if label_node:
				if label_node is Label:
					label_node.text = tr(entry.label_text)
				elif label_node is RichTextLabel:
					label_node.bbcode = tr(entry.label_text)
				else:
					push_warning("ContextPopup: node_path '%s' is not a Label or RichTextLabel." % entry.node_path)
			else:
				push_warning("ContextPopup: cannot find node at '%s'" % entry.node_path)
		else:
			push_warning("ContextPopup: text_entries contains a non-TextEntry resource.")


func set_follow_target(new_target: Node2D) -> void:
	print_debug("ContextPopup: set_follow_target called with %s" % new_target)
	if new_target and new_target is Node2D:
		follow_target_path = new_target.get_path()
		_base_position = new_target.global_position + Vector2(0, vertical_offset)
		print_debug("ContextPopup: set_follow_target to %s" % follow_target_path)
	else:
		push_warning("ContextPopup: set_follow_target requires a valid Node2D target.")
		follow_target_path = NodePath() # Reset to no target
