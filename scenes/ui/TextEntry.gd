# TextEntry: holds a NodePath to a Label (or RichTextLabel) and a string to display.
class_name TextEntry
extends Resource

@export var node_path: NodePath # Path to a child Label or RichTextLabel
@export var label_text: String = "" # The string or translation key