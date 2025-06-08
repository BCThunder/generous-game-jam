# IconEntry: holds a NodePath to a TextureRect (or similar) and an InputMap action name.
# Must use 'class_name' so Godot recognizes it in the Inspector as a Resource type.
class_name IconEntry
extends Resource

@export var node_path: NodePath # Path to a child TextureRect
@export var action_name: String = "" # InputMap action (e.g. "interact")
