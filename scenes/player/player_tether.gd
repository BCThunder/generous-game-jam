extends Line2D

## The player node that the tether will follow.
@export var player: Node2D
## How close the player must be to an existing point in the line to "cut" or prune the line from that point.
@export var overlap_threshold: float = 5.0
## The minimum distance the player must move from the last point before a new point is added to the line.
@export var min_point_distance: float = 2.0
## The minimum number of points that must exist after an overlapped point to allow pruning.
## This prevents pruning very recent segments of the line, preserving the "tail".
@export var min_tail_length_for_prune: int = 3
## Cosine of the angle for collinearity smoothing. Points forming an angle whose cosine is less than this value
## (e.g., an angle > 170 degrees for a threshold of -0.98) will be smoothed by replacing the middle point.
## Values closer to -1.0 mean the points must be almost perfectly in a straight line to be smoothed.
@export var collinearity_smooth_threshold: float = -0.98
## Cosine of the angle for spike detection. If the angle at the last point (formed by the point before last,
## the last point, and the new player position) is more acute than acos(this_value), it's considered part of a potential spike.
## E.g., 0.0 means an angle < 90 deg. 0.5 means an angle < 60 deg.
@export var spike_acute_angle_threshold_cos: float = 0.0
## Segments forming a potential spike (both the segment leading to the last point and the segment from the
## last point to the new player position) must be shorter than (min_point_distance * this_factor) to be considered a spike.
@export var spike_max_segment_length_factor: float = 3.0

## Iterative Smoothing Parameters
## If true, enables a background process that iteratively smooths the entire line over multiple frames.
@export var iterative_smoothing_enabled: bool = true
## The factor (0-1) determining how much an internal point moves towards the average position of its two neighbors during iterative smoothing.
## A value of 0 means no movement, 1 means it moves directly to the midpoint.
@export var iterative_smoothing_factor: float = 0.1
## The number of internal points in the line to process for iterative smoothing each physics frame.
@export var points_to_smooth_per_frame: int = 5

## Collision Detection for Smoothing
## The physics layer mask used to detect obstacles. The tether will try to avoid smoothing through colliders on these layers.
@export var obstacle_collision_mask: int = 1

var _current_iterative_smoothing_index: int = 1 # Start smoothing from the second point (index 1)
var _player_rid: RID # To exclude player from raycasts

func _ready() -> void:
	set_physics_process(false)
	await get_tree().physics_frame # Wait for physics server to be active
	clear_points()
	_current_iterative_smoothing_index = 1 # Reset index
	if player is PhysicsBody2D:
		_player_rid = player.get_rid()
	elif player and player.has_method("get_rid"): # For custom nodes that might have a RID
		_player_rid = player.get_rid()
	
	set_physics_process(true)

func _is_segment_obstructed(global_from: Vector2, global_to: Vector2, space_state: PhysicsDirectSpaceState2D) -> bool:
	if not space_state:
		return false # Should not happen if called from _physics_process

	var exclude_array = []
	if _player_rid.is_valid():
		exclude_array.append(_player_rid)

	var query = PhysicsRayQueryParameters2D.create(global_from, global_to, obstacle_collision_mask, exclude_array)
	var result = space_state.intersect_ray(query)
	return not result.is_empty()

func _physics_process(_delta: float) -> void:
	if not player:
		return
	
	var space_state = get_world_2d().direct_space_state
	var previous_point_count = get_point_count()
	
	_record_and_prune_path(player.global_position, space_state) # Pass player's global position
	
	if get_point_count() != previous_point_count:
		_current_iterative_smoothing_index = 1

	if iterative_smoothing_enabled and get_point_count() >= 3:
		_iteratively_smooth_line_segment(space_state)

	# print("Line length: ", get_line_length()) # Optional: for debugging

func _iteratively_smooth_line_segment(space_state: PhysicsDirectSpaceState2D) -> void:
	var point_count = get_point_count()
	if point_count < 3:
		_current_iterative_smoothing_index = 1
		return

	for _i in range(points_to_smooth_per_frame):
		if _current_iterative_smoothing_index <= 0 or _current_iterative_smoothing_index >= point_count - 1:
			_current_iterative_smoothing_index = 1
		
		if point_count < 3: # Re-check after potential reset if line became too short
			_current_iterative_smoothing_index = 1
			return

		var p_prev_local = get_point_position(_current_iterative_smoothing_index - 1)
		var p_curr_local = get_point_position(_current_iterative_smoothing_index)
		var p_next_local = get_point_position(_current_iterative_smoothing_index + 1)
		
		var midpoint_neighbors_local = (p_prev_local + p_next_local) / 2.0
		var smoothed_pos_local = p_curr_local.lerp(midpoint_neighbors_local, iterative_smoothing_factor)
		
		# Convert to global for collision check
		var global_p_prev = to_global(p_prev_local)
		var global_smoothed_pos = to_global(smoothed_pos_local)
		var global_p_next = to_global(p_next_local)

		# Check if the new segments would be obstructed
		var obstructed = _is_segment_obstructed(global_p_prev, global_smoothed_pos, space_state) or \
						 _is_segment_obstructed(global_smoothed_pos, global_p_next, space_state)
		
		if not obstructed:
			set_point_position(_current_iterative_smoothing_index, smoothed_pos_local)
		
		_current_iterative_smoothing_index += 1
		if _current_iterative_smoothing_index >= point_count - 1:
			_current_iterative_smoothing_index = 1
			break


func _record_and_prune_path(player_global_pos: Vector2, space_state: PhysicsDirectSpaceState2D) -> void:
	var player_local_pos = to_local(player_global_pos)

	var idx = _find_overlap_index(player_local_pos) # Overlap uses local position
	
	if idx >= 0 and idx < get_point_count() - min_tail_length_for_prune:
		_prune_from(idx)
	
	var current_point_count = get_point_count()
	var last_point_local_pos: Vector2
	if current_point_count > 0:
		last_point_local_pos = get_point_position(current_point_count - 1)

	if current_point_count == 0 or player_local_pos.distance_to(last_point_local_pos) >= min_point_distance:
		if current_point_count >= 2:
			var p_n_minus_2_local = get_point_position(current_point_count - 2)
			var p_new_local = player_local_pos
			
			var v_to_prev = p_n_minus_2_local - last_point_local_pos
			var v_to_new = p_new_local - last_point_local_pos
			
			if v_to_prev.length_squared() > 1e-5 and v_to_new.length_squared() > 1e-5:
				var cos_angle = v_to_prev.normalized().dot(v_to_new.normalized())
				var len_prev_segment = v_to_prev.length()
				var len_new_segment = v_to_new.length()
				var actual_spike_max_len = min_point_distance * spike_max_segment_length_factor

				var replace_last_point = false
				if cos_angle < collinearity_smooth_threshold: # Collinearity
					replace_last_point = true
				elif cos_angle > spike_acute_angle_threshold_cos and \
					 len_prev_segment < actual_spike_max_len and \
					 len_new_segment < actual_spike_max_len: # Short spike
					replace_last_point = true
				
				if replace_last_point:
					# Check if segment (P(n-2) to P_new) is obstructed
					var global_p_n_minus_2 = to_global(p_n_minus_2_local)
					# player_global_pos is P_new in global coordinates
					if not _is_segment_obstructed(global_p_n_minus_2, player_global_pos, space_state):
						set_point_position(current_point_count - 1, p_new_local)
					else: # Obstructed, so just add the new point instead of replacing
						add_point(p_new_local)
				else: # Standard case: add p_new.
					add_point(p_new_local)
			else:
				add_point(p_new_local)
		else:
			add_point(player_local_pos)

func _find_overlap_index(pos: Vector2) -> int:
	for i in range(get_point_count()):
		if pos.distance_to(get_point_position(i)) <= overlap_threshold:
			return i
	return -1

func _prune_from(idx: int) -> void:
	# keep points 0..idx, remove everything after
	while get_point_count() > idx + 1:
		remove_point(idx + 1)

func get_line_length() -> float:
	# Calculate the total length of the line by summing the distances between consecutive points.
	var total_length: float = 0.0
	for i in range(get_point_count() - 1):
		total_length += get_point_position(i).distance_to(get_point_position(i + 1))
	return total_length