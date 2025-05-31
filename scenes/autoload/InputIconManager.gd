# InputIconManager.gd
# ──────────────────────────────────────────────────────────────────────────────
# Singleton (AutoLoaded) that scans a folder of .tres AtlasTexture files and,
# at runtime, looks up which key or mouse button is bound to a given InputMap action,
# returning the corresponding AtlasTexture by filename.

extends Node

# Toggle this to enable/disable debug prints
@export var debug_mode: bool = false

# (1) The folder where all of your .tres AtlasTexture files live.
#     NOTE: Make sure this matches *exactly* what you see in the FileSystem dock,
#           including case and spacing, and only one slash at the end.
@export var icon_folder: String = "res://assets/kenny input sprites/"

# (2) We'll populate this dictionary with { lookup_key (uppercase) : AtlasTexture }.
#     e.g. { "A": AtlasTexture, "SPACE": AtlasTexture, "MOUSELEFT": AtlasTexture, ... }
var icon_map: Dictionary = {}

# (3) If you drop in a file called "UNKNOWN.tres", it'll be used as the fallback.
var fallback_icon: AtlasTexture = null

func _ready() -> void:
	_load_all_icons_from_folder()

#───────────────────────────────────────────────────────────────────────────────
# Internal helper: Open `icon_folder`, iterate through every file ending in ".tres",
# load it as an AtlasTexture, then store it in `icon_map` under a key equal to
# the filename_without_extension().to_upper().
#
#   e.g. "E.tres"       → stored under icon_map["E"]
#         "Space.tres"   → stored under icon_map["SPACE"]
#         "MouseLeft.tres" → stored under icon_map["MOUSELEFT"]
#         "UNKNOWN.tres"  → sets fallback_icon (stored under "UNKNOWN")
#
func _load_all_icons_from_folder() -> void:
	var dir = DirAccess.open(icon_folder)
	if dir == null:
		push_error("InputIconManager: ❌ Could not open folder: %s" % icon_folder)
		return

	# Start iterating
	dir.list_dir_begin()

	var filename = dir.get_next()
	while filename != "":
		# Only consider files ending in ".tres"
		if filename.to_lower().ends_with(".tres"):
			var file_path: String = icon_folder + filename
			var atlas_res := ResourceLoader.load(file_path)
			if atlas_res and atlas_res is AtlasTexture:
				# Strip off ".tres", convert to uppercase for consistent lookups
				var raw_key := filename.get_basename()
				var key_name := raw_key.to_upper() # ALWAYS store keys in uppercase

				icon_map[key_name] = atlas_res

				# If this file was "UNKNOWN.tres" (in any case), set fallback
				if key_name == "UNKNOWN":
					fallback_icon = atlas_res
			else:
				push_warning("InputIconManager: Skipped '%s' (not an AtlasTexture)." % filename)
		filename = dir.get_next()

	dir.list_dir_end()

	# If there was an "UNKNOWN.tres" but fallback_icon is still null, assign it now
	if fallback_icon == null and icon_map.has("UNKNOWN"):
		fallback_icon = icon_map["UNKNOWN"]

	# —— DEBUG: print every key we loaded ——
	if debug_mode:
		for key_name in icon_map.keys():
			print_debug("InputIconManager: Loaded icon_map['%s'] = %s" % [key_name, icon_map[key_name]])
		if fallback_icon:
			print_debug("InputIconManager: fallback_icon = %s" % fallback_icon)
		else:
			print_debug("InputIconManager: ❗ No fallback_icon found (no 'UNKNOWN.tres').")

#───────────────────────────────────────────────────────────────────────────────
# Public API:
#   Given an InputMap action name (e.g. "move_left", "jump", "context_interact"),
#   returns the AtlasTexture whose filename (without ".tres") matches the
#   *physical binding* (uppercase) for that action. If nothing matches, returns fallback_icon or null.
#
func get_icon_for_action(action_name: String) -> Texture2D:
	# 1) Fetch all events bound to this action
	var events := InputMap.action_get_events(action_name)
	if debug_mode:
		print_debug("InputIconManager: Events for action '%s': (count=%d) %s" % [action_name, events.size(), events])

	for i in range(events.size()):
		var ev = events[i]
		if ev is InputEventKey:
			var key_event := ev as InputEventKey
			# Debug: print both keycode and physical_scancode
			var kc := key_event.keycode
			var phys := key_event.physical_keycode
			if debug_mode:
				print_debug("  InputIconManager: Event #%d → keycode = %d, physical_scancode = %d" % [i, kc, phys])

			# Convert the raw Godot Key enum into a string (e.g. "A", "Space", "Shift")
			var raw_name := OS.get_keycode_string(phys)
			if raw_name == "":
				# If OS.get_keycode_string returned "", skip this event
				if debug_mode:
					print_debug("  InputIconManager: Skipped empty key_name for keycode %d (event #%d)" % [kc, i])
				continue

			# If for some reason it returns "KeyE", strip off the "Key" prefix:
			if raw_name.begins_with("Key"):
				raw_name = raw_name.replace("Key", "")

			# Always uppercase our lookup
			var key_name := raw_name.to_upper()
			if debug_mode:
				print_debug("  InputIconManager: Event #%d → Found InputEventKey, key_name = '%s'" % [i, key_name])

			if icon_map.has(key_name):
				if debug_mode:
					print_debug("  InputIconManager: Returning icon_map['%s']" % key_name)
				return icon_map[key_name]
			else:
				if debug_mode:
					print_debug("  InputIconManager: icon_map has no entry for '%s'" % key_name)

		elif ev is InputEventMouseButton:
			var mb_event := ev as InputEventMouseButton
			var mb_key := ""
			match mb_event.button_index:
				MouseButton.MOUSE_BUTTON_LEFT:
					mb_key = "MOUSELEFT"
				MouseButton.MOUSE_BUTTON_RIGHT:
					mb_key = "MOUSERIGHT"
				MouseButton.MOUSE_BUTTON_MIDDLE:
					mb_key = "MOUSEMIDDLE"
				_:
					# Skip XButton1, XButton2, etc. unless you explicitly have those icons
					if debug_mode:
						print_debug("  InputIconManager: Skipped unhandled mouse button (index %d, event #%d)" % [mb_event.button_index, i])
					continue

			if debug_mode:
				print_debug("  InputIconManager: Event #%d → Found mouse event, mb_key = '%s'" % [i, mb_key])
			if icon_map.has(mb_key):
				if debug_mode:
					print_debug("  InputIconManager: Returning icon_map['%s']" % mb_key)
				return icon_map[mb_key]

		else:
			# Could add support for InputEventJoyButton / Joypad if you wanted
			if debug_mode:
				print_debug("  InputIconManager: Skipped unsupported event type '%s' (event #%d)" % [ev.get_class(), i])
			continue

	# If we got here, no key or mouse icon matched—return fallback if present
	if fallback_icon:
		if debug_mode:
			print_debug("InputIconManager: No match; returning fallback_icon = %s" % fallback_icon)
		return fallback_icon

	if debug_mode:
		print_debug("InputIconManager: No match and no fallback; returning null")
	return null
