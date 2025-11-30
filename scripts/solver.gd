# solver.gd
class_name PuzzleSolver
extends RefCounted

# Grid configuration
var grid_size: Vector2i
var cell_size: int
var grid_offset: Vector2

# Puzzle data
var puzzle_data := []
var bridges := []
var hint_bridges := []

# Puzzle state
var puzzle_solved := false

# Hint system
var current_puzzle_index := 1
var puzzle_folder: String = ""
var hints_used := 0
var max_hints_to_use := 0

# Hint timer
var hint_timer: float = 0.0
var hint_visible: bool = false

# CSP variables
var csp_domains := {}
var csp_constraints := []

# CSP-based hint system
var csp_hint_solution := []  # Stores the complete CSP solution for hints
var csp_hint_ready := false  # Whether CSP solution is computed and ready
var csp_hint_applied_bridges := {}  # Track which bridges from solution have been applied

# Step-by-step solver animation
var step_by_step_bridges := []  # Bridges to be shown step by step
var current_animation_step := 0
var animation_timer := 0.0
var animation_delay := 0.6  # Time between bridge appearances
var is_animating_solution := false
var animation_completed := false

# Initialize method
func initialize(grid_size_param: Vector2i, cell_size_param: int, grid_offset_param: Vector2) -> void:
	grid_size = grid_size_param
	cell_size = cell_size_param
	grid_offset = grid_offset_param

# Update method for handling hint timer and animation
func update(delta: float) -> void:
	if hint_visible:
		hint_timer -= delta
		if hint_timer <= 0:
			clear_hint_bridges()
			hint_visible = false
	
	# Handle step-by-step animation
	if is_animating_solution:
		animation_timer -= delta
		if animation_timer <= 0:
			_apply_next_animation_step()

# Set puzzle info for hint system
func set_puzzle_info(folder: String, index: int):
	puzzle_folder = folder
	current_puzzle_index = index

# ==================== STEP-BY-STEP SOLVER ANIMATION ====================

func start_step_by_step_solution() -> bool:
	"""
	Start step-by-step solution animation using CSP
	Returns true if solution was found and animation started
	"""
	print("Starting step-by-step solution animation...")
	
	# Clear current bridges for fresh start
	bridges.clear()
	for island in puzzle_data:
		island.connected_bridges = 0
	
	# Compute solution using CSP
	print("Computing solution for animation...")
	var success = _compute_solution_for_animation()
	
	if success:
		print("Solution computed, starting animation with %d steps" % step_by_step_bridges.size())
		current_animation_step = 0
		animation_timer = animation_delay
		is_animating_solution = true
		animation_completed = false
		puzzle_solved = false
		
		# ADD ALL BRIDGES IMMEDIATELY BUT MARK THEM AS HIDDEN
		for bridge_data in step_by_step_bridges:
			_add_bridge_internal(bridge_data.start_island, bridge_data.end_island, bridge_data.count)
			# Mark the bridge as hidden for animation
			if bridges.size() > 0:
				bridges[bridges.size() - 1]["visible"] = false
		
		# MAKE FIRST BRIDGE VISIBLE
		if step_by_step_bridges.size() > 0:
			bridges[0]["visible"] = true
			print("Made first bridge visible")
		
		return true
	else:
		print("Failed to compute solution for animation")
		return false

func _compute_solution_for_animation() -> bool:
	"""
	Compute solution using CSP and prepare step-by-step bridges for animation
	"""
	step_by_step_bridges.clear()
	
	# Create temporary solver state
	var temp_bridges = []
	var temp_islands = _create_island_copy()
	
	# Reset temporary islands
	for island in temp_islands:
		island.connected_bridges = 0
	
	# Solve using CSP
	var success = _csp_solve_for_animation(temp_islands, temp_bridges)
	
	if success:
		print("CSP solution found with %d bridges" % temp_bridges.size())
		
		# Convert solution to step-by-step format
		_convert_to_step_by_step(temp_bridges)
		return true
	
	return false

func _csp_solve_for_animation(islands: Array, current_bridges: Array) -> bool:
	"""
	CSP solver for animation preparation
	"""
	# Initialize CSP variables
	_init_csp_variables_for_hints(islands)
	
	# Use backtracking with constraint propagation
	var assignment = {}
	var success = _csp_backtrack_for_hints(assignment, islands)
	
	if success:
		# Apply the solution to temporary bridges
		_apply_csp_solution_to_hints(assignment, islands, current_bridges)
		return true
	return false

func _convert_to_step_by_step(temp_bridges: Array):
	"""
	Convert solution bridges to step-by-step format for animation
	"""
	step_by_step_bridges.clear()
	
	# Sort bridges in a logical order (by position, count, etc.)
	var sorted_bridges = temp_bridges.duplicate()
	sorted_bridges.sort_custom(_sort_bridges_for_animation)
	
	# Convert to actual island references
	for temp_br in sorted_bridges:
		var actual_start = _find_corresponding_island(temp_br.start_island)
		var actual_end = _find_corresponding_island(temp_br.end_island)
		
		if actual_start and actual_end:
			step_by_step_bridges.append({
				"start_island": actual_start,
				"end_island": actual_end,
				"start_pos": actual_start.node.position,
				"end_pos": actual_end.node.position,
				"count": temp_br.count
			})
	
	print("Animation prepared with %d bridge steps" % step_by_step_bridges.size())
	
	# Debug: Log all bridges in animation
	for i in range(step_by_step_bridges.size()):
		var br = step_by_step_bridges[i]
		var start_x = br.start_island.pos.x
		var start_y = br.start_island.pos.y
		var end_x = br.end_island.pos.x
		var end_y = br.end_island.pos.y
		var bridge_text = "bridge" if br.count == 1 else "bridges"
		print("  Step %d: %d %s between (%d,%d) and (%d,%d)" % [
			i + 1, br.count, bridge_text,
			start_x, start_y,
			end_x, end_y
		])

func _sort_bridges_for_animation(a, b) -> bool:
	"""
	Sort bridges for animation - simple left-to-right, top-to-bottom order
	"""
	if a.start_island.pos.x != b.start_island.pos.x:
		return a.start_island.pos.x < b.start_island.pos.x
	if a.start_island.pos.y != b.start_island.pos.y:
		return a.start_island.pos.y < b.start_island.pos.y
	if a.end_island.pos.x != b.end_island.pos.x:
		return a.end_island.pos.x < b.end_island.pos.x
	return a.end_island.pos.y < b.end_island.pos.y

func _apply_next_animation_step():
	"""
	Apply the next bridge in the animation sequence - SIMPLIFIED
	"""
	if current_animation_step < step_by_step_bridges.size() - 1:
		# Make the next bridge visible
		current_animation_step += 1
		bridges[current_animation_step]["visible"] = true
		
		var br = step_by_step_bridges[current_animation_step]
		var start_x = br.start_island.pos.x
		var start_y = br.start_island.pos.y
		var end_x = br.end_island.pos.x
		var end_y = br.end_island.pos.y
		var bridge_text = "bridge" if br.count == 1 else "bridges"
		
		print("Step %d/%d: Made %d %s between (%d,%d) and (%d,%d)" % [
			current_animation_step + 1, step_by_step_bridges.size(),
			br.count, bridge_text,
			start_x, start_y,
			end_x, end_y
		])
		
		animation_timer = animation_delay
	else:
		# All bridges are now visible
		print("All bridges are now visible, animation complete!")
		_animation_complete()

func _animation_complete():
	"""
	Called when step-by-step animation is complete
	"""
	print("Step-by-step animation complete!")
	is_animating_solution = false
	animation_completed = true
	puzzle_solved = true
	
	# Notify the main scene to update UI
	_notify_puzzle_scene()
	
	print("Animation completed, puzzle solved!")

func _update_puzzle_state():
	"""
	Update the puzzle state and trigger UI refresh
	"""
	# Check if puzzle is actually solved
	var is_solved = _verify_solution()
	puzzle_solved = is_solved
	
	if is_solved:
		print("Puzzle is correctly solved!")
	else:
		print("Puzzle verification failed!")
	
	# Notify the main scene to update UI
	_notify_puzzle_scene()

func _notify_puzzle_scene():
	"""
	Notify the puzzle scene to update its display
	"""
	# Use call_deferred to ensure this happens in the next frame
	call_deferred("_deferred_notify_puzzle_scene")

func _deferred_notify_puzzle_scene():
	"""
	Deferred notification to avoid state issues
	"""
	# Use groups to find and notify the puzzle scene
	if Engine.get_main_loop().has_method("call_group"):
		Engine.get_main_loop().call_group("puzzle_scene", "_on_solver_state_changed")
	
	print("Notified puzzle scene to update display")

func stop_animation():
	"""
	Stop the step-by-step animation
	"""
	is_animating_solution = false
	animation_completed = false
	print("Step-by-step animation stopped")

func is_animating() -> bool:
	"""
	Check if step-by-step animation is in progress
	"""
	return is_animating_solution

func is_animation_completed() -> bool:
	"""
	Check if step-by-step animation has completed
	"""
	return animation_completed

func get_animation_progress() -> float:
	"""
	Get animation progress (0.0 to 1.0)
	"""
	if step_by_step_bridges.is_empty():
		return 0.0
	return float(current_animation_step + 1) / float(step_by_step_bridges.size())

# ==================== CSP-BASED HINT SYSTEM ====================

func csp_based_hint() -> void:
	"""
	Generate hints using CSP algorithm - solves once, stores solution, provides hints from stored solution
	"""
	hint_bridges.clear()
	hint_visible = false
	
	print("Generating CSP-based hint...")
	
	# If CSP solution is not ready, compute it first
	if not csp_hint_ready:
		print("Computing CSP solution for hints...")
		if _compute_csp_hint_solution():
			print("CSP solution computed and stored for hints")
			csp_hint_ready = true
		else:
			print("Failed to compute CSP solution for hints")
			return
	
	# Find the next bridge from CSP solution that should be placed
	var suggested_bridge = _find_next_csp_hint_bridge()
	
	if suggested_bridge:
		hint_bridges.append({
			"start_island": suggested_bridge.start_island,
			"end_island": suggested_bridge.end_island,
			"start_pos": suggested_bridge.start_island.node.position,
			"end_pos": suggested_bridge.end_island.node.position,
			"count": suggested_bridge.count
		})
		
		hint_visible = true
		hint_timer = 1.0  # Show for 1 seconds
		
		var start_x = suggested_bridge.start_island.pos.x
		var start_y = suggested_bridge.start_island.pos.y
		var end_x = suggested_bridge.end_island.pos.x
		var end_y = suggested_bridge.end_island.pos.y
		var bridge_text = "bridge" if suggested_bridge.count == 1 else "bridges"
		
		print("CSP HINT: Add %d %s between island at (%d,%d) and (%d,%d)" % [
			suggested_bridge.count, bridge_text,
			start_x, start_y,
			end_x, end_y
		])
		
		# Mark this bridge as suggested (but don't apply it yet)
		var _bridge_key = _get_bridge_key(suggested_bridge.start_island, suggested_bridge.end_island)
	else:
		print("All CSP solution bridges are already placed!")

func _compute_csp_hint_solution() -> bool:
	"""
	Compute the complete CSP solution and store it for hints
	Returns true if successful
	"""
	csp_hint_solution.clear()
	csp_hint_applied_bridges.clear()
	
	print("Computing CSP solution for hint system...")
	
	# Create a temporary solver state
	var temp_bridges = []
	var temp_islands = _create_island_copy()
	
	# Reset temporary islands
	for island in temp_islands:
		island.connected_bridges = 0
	
	var start_time = Time.get_ticks_msec()
	var success = _csp_solve_for_hints(temp_islands, temp_bridges)
	var end_time = Time.get_ticks_msec()
	
	if success:
		print("CSP hint solution found in %d ms!" % (end_time - start_time))
		
		# Store the solution (sorted for consistent hint ordering)
		for bridge in temp_bridges:
			csp_hint_solution.append({
				"start_island": _find_corresponding_island_for_hint(bridge.start_island),
				"end_island": _find_corresponding_island_for_hint(bridge.end_island),
				"count": bridge.count
			})
		
		# Sort hints using the same logic as animation for consistency
		csp_hint_solution.sort_custom(_sort_hints_for_consistency)
		
		print("Stored %d bridges in CSP hint solution" % csp_hint_solution.size())
		return true
	else:
		print("Failed to compute CSP solution for hints")
		return false

func _sort_hints_for_consistency(a, b) -> bool:
	"""
	Sort hints using the same logic as animation for consistent ordering
	"""
	if a.start_island.pos.x != b.start_island.pos.x:
		return a.start_island.pos.x < b.start_island.pos.x
	if a.start_island.pos.y != b.start_island.pos.y:
		return a.start_island.pos.y < b.start_island.pos.y
	if a.end_island.pos.x != b.end_island.pos.x:
		return a.end_island.pos.x < b.end_island.pos.x
	return a.end_island.pos.y < b.end_island.pos.y

func _csp_solve_for_hints(islands: Array, current_bridges: Array) -> bool:
	"""
	CSP solver specifically for hint system
	"""
	# Initialize CSP variables for hint solving
	_init_csp_variables_for_hints(islands)
	
	# Use backtracking with constraint propagation
	var assignment = {}
	var success = _csp_backtrack_for_hints(assignment, islands)
	
	if success:
		# Apply the solution to temporary bridges
		_apply_csp_solution_to_hints(assignment, islands, current_bridges)
		return true
	return false

func _init_csp_variables_for_hints(islands: Array):
	"""
	Initialize CSP variables for hint solving
	"""
	csp_domains.clear()
	csp_constraints.clear()
	
	# Create variables for each possible bridge
	var possible_bridges = _get_all_possible_bridges_for_hints(islands)
	
	for bridge in possible_bridges:
		var var_name = _get_bridge_variable_name(bridge.start_island, bridge.end_island)
		# Domain: 0 (no bridge), 1 (single bridge), 2 (double bridge)
		csp_domains[var_name] = [0, 1, 2]
	
	# Add constraints
	_add_bridge_count_constraints_for_hints(islands)
	_add_intersection_constraints_for_hints(possible_bridges)

func _get_all_possible_bridges_for_hints(islands: Array) -> Array:
	"""
	Get all possible bridges between islands for hint solving
	"""
	var possible_bridges = []
	
	for i in range(islands.size()):
		var island_a = islands[i]
		for j in range(i + 1, islands.size()):
			var island_b = islands[j]
			if _can_connect_directly(island_a, island_b, islands):
				possible_bridges.append({
					"start_island": island_a,
					"end_island": island_b,
					"start_pos": Vector2(island_a.pos.x * cell_size, island_a.pos.y * cell_size),
					"end_pos": Vector2(island_b.pos.x * cell_size, island_b.pos.y * cell_size)
				})
	
	return possible_bridges

func _add_bridge_count_constraints_for_hints(islands: Array):
	"""
	Add constraints for island bridge counts for hint solving
	"""
	for island in islands:
		var connected_bridges = []
		
		# Find all possible bridges connected to this island
		for other in islands:
			if island != other and _can_connect_directly(island, other, islands):
				var var_name = _get_bridge_variable_name(island, other)
				connected_bridges.append(var_name)
		
		if not connected_bridges.is_empty():
			csp_constraints.append({
				"type": "bridge_count",
				"island": island,
				"variables": connected_bridges,
				"target": island.bridges_target
			})

func _add_intersection_constraints_for_hints(possible_bridges: Array):
	"""
	Add constraints to prevent bridge intersections for hint solving
	"""
	for i in range(possible_bridges.size()):
		var br1 = possible_bridges[i]
		for j in range(i + 1, possible_bridges.size()):
			var br2 = possible_bridges[j]
			
			if _bridges_cross(br1.start_pos, br1.end_pos, br2.start_pos, br2.end_pos):
				var var1 = _get_bridge_variable_name(br1.start_island, br1.end_island)
				var var2 = _get_bridge_variable_name(br2.start_island, br2.end_island)
				
				csp_constraints.append({
					"type": "no_intersection",
					"variables": [var1, var2],
					"condition": "not_both_nonzero"
				})

func _csp_backtrack_for_hints(assignment: Dictionary, islands: Array) -> bool:
	"""
	Backtracking search for CSP hint solving
	"""
	if assignment.size() == csp_domains.size():
		return _is_csp_solution_complete_for_hints(assignment, islands)
	
	var var_name = _select_unassigned_variable(assignment)
	if var_name == "":
		return false
	
	var domain = csp_domains[var_name].duplicate()
	domain.sort()  # Try values in order
	
	for value in domain:
		if _is_value_consistent_for_hints(var_name, value, assignment, islands):
			assignment[var_name] = value
			
			# Forward checking
			var inferences = {}
			if _forward_check_for_hints(var_name, value, inferences, assignment, islands):
				var result = _csp_backtrack_for_hints(assignment, islands)
				if result:
					return true
			
			# Backtrack
			assignment.erase(var_name)
			_remove_inferences(inferences)
	
	return false

func _is_value_consistent_for_hints(var_name: String, value: int, assignment: Dictionary, _islands: Array) -> bool:
	"""
	Check if a value is consistent with current assignment for hint solving
	"""
	for constraint in csp_constraints:
		if not _satisfies_constraint_for_hints(constraint, var_name, value, assignment):
			return false
	return true

func _satisfies_constraint_for_hints(constraint: Dictionary, changed_var: String, value: int, assignment: Dictionary) -> bool:
	match constraint.type:
		"bridge_count":
			# Check if this constraint involves the changed variable
			if constraint.variables.has(changed_var):
				var total = value
				for var_name in constraint.variables:
					if var_name != changed_var:
						if assignment.has(var_name):
							total += assignment[var_name]
				
				# If all variables are assigned, check exact match
				var all_assigned = true
				for var_name in constraint.variables:
					if not assignment.has(var_name) and var_name != changed_var:
						all_assigned = false
						break
				
				if all_assigned:
					return total == constraint.target
				else:
					return total <= constraint.target
			return true
		
		"no_intersection":
			if constraint.variables.has(changed_var):
				var other_var = constraint.variables[0] if constraint.variables[1] == changed_var else constraint.variables[1]
				if assignment.has(other_var):
					return not (value > 0 and assignment[other_var] > 0)
			return true
	
	return true

func _forward_check_for_hints(var_name: String, _value: int, inferences: Dictionary, assignment: Dictionary, islands: Array) -> bool:
	"""
	Perform forward checking for hint solving
	"""
	for constraint in csp_constraints:
		if constraint.variables.has(var_name):
			for other_var in constraint.variables:
				if other_var != var_name and not assignment.has(other_var):
					var original_domain = csp_domains[other_var].duplicate()
					var new_domain = []
					
					for other_value in csp_domains[other_var]:
						# Temporarily assign to check consistency
						assignment[other_var] = other_value
						if _is_value_consistent_for_hints(other_var, other_value, assignment, islands):
							new_domain.append(other_value)
						assignment.erase(other_var)
					
					if new_domain.is_empty():
						return false
					
					if new_domain.size() < original_domain.size():
						if not inferences.has(other_var):
							inferences[other_var] = original_domain
						csp_domains[other_var] = new_domain
	
	return true

func _is_csp_solution_complete_for_hints(assignment: Dictionary, islands: Array) -> bool:
	"""
	Check if CSP assignment represents a complete valid solution for hints
	"""
	# Check all bridge count constraints
	for constraint in csp_constraints:
		if constraint.type == "bridge_count":
			var total = 0
			for var_name in constraint.variables:
				total += assignment[var_name]
			if total != constraint.target:
				return false
	
	# Check intersection constraints
	for constraint in csp_constraints:
		if constraint.type == "no_intersection":
			var var1 = constraint.variables[0]
			var var2 = constraint.variables[1]
			if assignment[var1] > 0 and assignment[var2] > 0:
				return false
	
	# Check connectivity
	return _is_csp_solution_connected_for_hints(assignment, islands)

func _is_csp_solution_connected_for_hints(assignment: Dictionary, islands: Array) -> bool:
	"""
	Check if the hint solution forms a connected graph
	"""
	var graph = {}
	
	# Build graph from assignment
	for island in islands:
		graph[island] = []
	
	for var_name in assignment:
		if assignment[var_name] > 0:
			var parts = var_name.split("_")
			var pos1 = Vector2(int(parts[1]), int(parts[2]))
			var pos2 = Vector2(int(parts[3]), int(parts[4]))
			
			var island1 = _find_island_by_pos_for_hints(islands, pos1)
			var island2 = _find_island_by_pos_for_hints(islands, pos2)
			
			if island1 and island2:
				graph[island1].append(island2)
				graph[island2].append(island1)
	
	# Check connectivity using BFS
	if islands.is_empty():
		return true
	
	var visited = {}
	var queue = [islands[0]]
	
	while not queue.is_empty():
		var current = queue.pop_front()
		visited[current] = true
		
		for neighbor in graph[current]:
			if not visited.has(neighbor):
				queue.append(neighbor)
	
	return visited.size() == islands.size()

func _find_island_by_pos_for_hints(islands: Array, pos: Vector2):
	"""
	Find island by position in hint solver islands
	"""
	for island in islands:
		if island.pos == pos:
			return island
	return null

func _apply_csp_solution_to_hints(assignment: Dictionary, islands: Array, current_bridges: Array):
	"""
	Apply the CSP solution to temporary bridges for hints
	"""
	current_bridges.clear()
	
	# Reset connected bridges
	for island in islands:
		island.connected_bridges = 0
	
	# Apply bridges from CSP assignment
	for var_name in assignment:
		var value = assignment[var_name]
		if value > 0:
			var parts = var_name.split("_")
			var pos1 = Vector2(int(parts[1]), int(parts[2]))
			var pos2 = Vector2(int(parts[3]), int(parts[4]))
			
			var island1 = _find_island_by_pos_for_hints(islands, pos1)
			var island2 = _find_island_by_pos_for_hints(islands, pos2)
			
			if island1 and island2:
				current_bridges.append({
					"start_island": island1,
					"end_island": island2,
					"start_pos": Vector2(island1.pos.x * cell_size, island1.pos.y * cell_size),
					"end_pos": Vector2(island2.pos.x * cell_size, island2.pos.y * cell_size),
					"count": value
				})
				island1.connected_bridges += value
				island2.connected_bridges += value

func _find_next_csp_hint_bridge():
	"""
	Find the next bridge from CSP solution that should be placed
	"""
	for sol_br in csp_hint_solution:
		# Check if this bridge is already placed in the actual puzzle
		var already_placed = false
		var current_count = 0
		
		for current_br in bridges:
			if _bridges_match(current_br, sol_br):
				current_count = current_br.count
				if current_count >= sol_br.count:
					already_placed = true
				break
		
		if not already_placed:
			# Check if we can add this bridge (basic validation)
			var can_add = _can_add_bridge_for_hint(sol_br.start_island, sol_br.end_island, sol_br.count)
			if can_add:
				return sol_br
	
	return null

func _get_bridge_key(a, b) -> String:
	"""
	Create a unique key for a bridge
	"""
	var pos1 = a.pos
	var pos2 = b.pos
	# Sort positions to ensure consistent key
	if pos1.x > pos2.x or (pos1.x == pos2.x and pos1.y > pos2.y):
		var temp = pos1
		pos1 = pos2
		pos2 = temp
	return "%d_%d_%d_%d" % [pos1.x, pos1.y, pos2.x, pos2.y]

func _find_corresponding_island_for_hint(solver_island):
	"""
	Find the actual island corresponding to a solver island for hints
	"""
	for actual_island in puzzle_data:
		if actual_island.pos == solver_island.pos:
			return actual_island
	return null

func reset_csp_hint_solution():
	"""
	Reset the CSP hint solution (call when puzzle changes)
	"""
	csp_hint_solution.clear()
	csp_hint_ready = false
	csp_hint_applied_bridges.clear()
	print("CSP hint solution reset")

# ==================== CSP SOLVER ====================

func csp_based_solver() -> bool:
	"""
	CSP-based solver using constraint satisfaction techniques
	"""
	print("Starting CSP solver...")
	
	# Save current state
	var original_bridges = _duplicate_bridges()
	var original_island_states = _save_island_states()
	
	# Clear for fresh start
	bridges.clear()
	for island in puzzle_data:
		island.connected_bridges = 0
	
	var start_time = Time.get_ticks_msec()
	var success = _csp_solve()
	var end_time = Time.get_ticks_msec()
	
	if success:
		print("CSP solver found solution in %d ms!" % (end_time - start_time))
		puzzle_solved = true
		return true
	else:
		print("CSP solver failed")
		_restore_bridges(original_bridges)
		_restore_island_states(original_island_states)
		puzzle_solved = false
		return false

func _csp_solve() -> bool:
	"""
	Main CSP solver using backtracking with constraint propagation
	"""
	# Initialize CSP variables
	_init_csp_variables()
	
	# Use backtracking with constraint propagation
	var assignment = {}
	var success = _csp_backtrack(assignment)
	
	if success:
		# Apply the solution
		_apply_csp_solution(assignment)
		return true
	return false

func _init_csp_variables():
	"""
	Initialize CSP variables and constraints
	"""
	csp_domains.clear()
	csp_constraints.clear()
	
	# Create variables for each possible bridge
	var possible_bridges = _get_all_possible_bridges()
	
	for bridge in possible_bridges:
		var var_name = _get_bridge_variable_name(bridge.start_island, bridge.end_island)
		# Domain: 0 (no bridge), 1 (single bridge), 2 (double bridge)
		csp_domains[var_name] = [0, 1, 2]
	
	# Add constraints
	_add_bridge_count_constraints()
	_add_intersection_constraints()
	_add_connectivity_constraints()

func _get_all_possible_bridges() -> Array:
	"""
	Get all possible bridges between islands
	"""
	var possible_bridges = []
	var solver_islands = _create_island_copy()
	
	for i in range(solver_islands.size()):
		var island_a = solver_islands[i]
		for j in range(i + 1, solver_islands.size()):
			var island_b = solver_islands[j]
			if _can_connect_directly(island_a, island_b, solver_islands):
				possible_bridges.append({
					"start_island": island_a,
					"end_island": island_b,
					"start_pos": island_a.node.position,
					"end_pos": island_b.node.position
				})
	
	return possible_bridges

func _get_bridge_variable_name(a, b) -> String:
	"""
	Create a unique variable name for a bridge
	"""
	var pos1 = a.pos
	var pos2 = b.pos
	# Sort positions to ensure consistent naming
	if pos1.x > pos2.x or (pos1.x == pos2.x and pos1.y > pos2.y):
		var temp = pos1
		pos1 = pos2
		pos2 = temp
	return "bridge_%d_%d_%d_%d" % [pos1.x, pos1.y, pos2.x, pos2.y]

func _add_bridge_count_constraints():
	"""
	Add constraints for island bridge counts
	"""
	var solver_islands = _create_island_copy()
	
	for island in solver_islands:
		var connected_bridges = []
		
		# Find all possible bridges connected to this island
		for other in solver_islands:
			if island != other and _can_connect_directly(island, other, solver_islands):
				var var_name = _get_bridge_variable_name(island, other)
				connected_bridges.append(var_name)
		
		if not connected_bridges.is_empty():
			csp_constraints.append({
				"type": "bridge_count",
				"island": island,
				"variables": connected_bridges,
				"target": island.bridges_target
			})

func _add_intersection_constraints():
	"""
	Add constraints to prevent bridge intersections
	"""
	var possible_bridges = _get_all_possible_bridges()
	
	for i in range(possible_bridges.size()):
		var br1 = possible_bridges[i]
		for j in range(i + 1, possible_bridges.size()):
			var br2 = possible_bridges[j]
			
			if _bridges_cross(br1.start_pos, br1.end_pos, br2.start_pos, br2.end_pos):
				var var1 = _get_bridge_variable_name(br1.start_island, br1.end_island)
				var var2 = _get_bridge_variable_name(br2.start_island, br2.end_island)
				
				csp_constraints.append({
					"type": "no_intersection",
					"variables": [var1, var2],
					"condition": "not_both_nonzero"
				})

func _add_connectivity_constraints():
	"""
	Add constraints to ensure the graph is connected
	"""
	# This is a complex constraint that we'll handle during solution verification
	pass

func _csp_backtrack(assignment: Dictionary) -> bool:
	"""
	Backtracking search for CSP
	"""
	if assignment.size() == csp_domains.size():
		return _is_csp_solution_complete(assignment)
	
	var var_name = _select_unassigned_variable(assignment)
	if var_name == "":
		return false
	
	var domain = csp_domains[var_name].duplicate()
	domain.sort()  # Try values in order
	
	for value in domain:
		if _is_value_consistent(var_name, value, assignment):
			assignment[var_name] = value
			
			# Forward checking
			var inferences = {}
			if _forward_check(var_name, value, inferences, assignment):
				var result = _csp_backtrack(assignment)
				if result:
					return true
			
			# Backtrack
			assignment.erase(var_name)
			_remove_inferences(inferences)
	
	return false

func _select_unassigned_variable(assignment: Dictionary) -> String:
	"""
	Select unassigned variable using MRV (Minimum Remaining Values) heuristic
	"""
	var best_var = ""
	var best_size = INF
	
	for var_name in csp_domains:
		if not assignment.has(var_name):
			var domain_size = csp_domains[var_name].size()
			if domain_size < best_size:
				best_size = domain_size
				best_var = var_name
	
	return best_var

func _is_value_consistent(var_name: String, value: int, assignment: Dictionary) -> bool:
	"""
	Check if a value is consistent with current assignment
	"""
	for constraint in csp_constraints:
		if not _satisfies_constraint(constraint, var_name, value, assignment):
			return false
	return true

func _satisfies_constraint(constraint: Dictionary, changed_var: String, value: int, assignment: Dictionary) -> bool:
	match constraint.type:
		"bridge_count":
			# Check if this constraint involves the changed variable
			if constraint.variables.has(changed_var):
				var total = value
				for var_name in constraint.variables:
					if var_name != changed_var:
						if assignment.has(var_name):
							total += assignment[var_name]
				
				# If all variables are assigned, check exact match
				var all_assigned = true
				for var_name in constraint.variables:
					if not assignment.has(var_name) and var_name != changed_var:
						all_assigned = false
						break
				
				if all_assigned:
					return total == constraint.target
				else:
					return total <= constraint.target
			return true
		
		"no_intersection":
			if constraint.variables.has(changed_var):
				var other_var = constraint.variables[0] if constraint.variables[1] == changed_var else constraint.variables[1]
				if assignment.has(other_var):
					return not (value > 0 and assignment[other_var] > 0)
			return true
	
	return true

func _forward_check(var_name: String, _value: int, inferences: Dictionary, assignment: Dictionary) -> bool:
	"""
	Perform forward checking and maintain arc consistency
	"""
	for constraint in csp_constraints:
		if constraint.variables.has(var_name):
			for other_var in constraint.variables:
				if other_var != var_name and not assignment.has(other_var):
					var original_domain = csp_domains[other_var].duplicate()
					var new_domain = []
					
					for other_value in csp_domains[other_var]:
						# Temporarily assign to check consistency
						assignment[other_var] = other_value
						if _is_value_consistent(other_var, other_value, assignment):
							new_domain.append(other_value)
						assignment.erase(other_var)
					
					if new_domain.is_empty():
						return false
					
					if new_domain.size() < original_domain.size():
						if not inferences.has(other_var):
							inferences[other_var] = original_domain
						csp_domains[other_var] = new_domain
	
	return true

func _remove_inferences(inferences: Dictionary):
	"""
	Remove inferences made during forward checking
	"""
	for var_name in inferences:
		csp_domains[var_name] = inferences[var_name]

func _is_csp_solution_complete(assignment: Dictionary) -> bool:
	"""
	Check if CSP assignment represents a complete valid solution
	"""
	# Check all bridge count constraints
	for constraint in csp_constraints:
		if constraint.type == "bridge_count":
			var total = 0
			for var_name in constraint.variables:
				total += assignment[var_name]
			if total != constraint.target:
				return false
	
	# Check intersection constraints
	for constraint in csp_constraints:
		if constraint.type == "no_intersection":
			var var1 = constraint.variables[0]
			var var2 = constraint.variables[1]
			if assignment[var1] > 0 and assignment[var2] > 0:
				return false
	
	# Check connectivity (simplified - we'll build the graph and check)
	return _is_csp_solution_connected(assignment)

func _is_csp_solution_connected(assignment: Dictionary) -> bool:
	"""
	Check if the solution forms a connected graph
	"""
	var solver_islands = _create_island_copy()
	var graph = {}
	
	# Build graph from assignment
	for island in solver_islands:
		graph[island] = []
	
	for var_name in assignment:
		if assignment[var_name] > 0:
			var parts = var_name.split("_")
			var pos1 = Vector2(int(parts[1]), int(parts[2]))
			var pos2 = Vector2(int(parts[3]), int(parts[4]))
			
			var island1 = _find_island_by_pos_csp(solver_islands, pos1)
			var island2 = _find_island_by_pos_csp(solver_islands, pos2)
			
			if island1 and island2:
				graph[island1].append(island2)
				graph[island2].append(island1)
	
	# Check connectivity using BFS
	if solver_islands.is_empty():
		return true
	
	var visited = {}
	var queue = [solver_islands[0]]
	
	while not queue.is_empty():
		var current = queue.pop_front()
		visited[current] = true
		
		for neighbor in graph[current]:
			if not visited.has(neighbor):
				queue.append(neighbor)
	
	return visited.size() == solver_islands.size()

func _find_island_by_pos_csp(solver_islands: Array, pos: Vector2):
	"""
	Find island by position in CSP solver islands
	"""
	for island in solver_islands:
		if island.pos == pos:
			return island
	return null

func _apply_csp_solution(assignment: Dictionary):
	"""
	Apply the CSP solution to the actual puzzle state
	"""
	bridges.clear()
	
	# Reset connected bridges
	for island in puzzle_data:
		island.connected_bridges = 0
	
	# Apply bridges from CSP assignment
	for var_name in assignment:
		var value = assignment[var_name]
		if value > 0:
			var parts = var_name.split("_")
			var pos1 = Vector2(int(parts[1]), int(parts[2]))
			var pos2 = Vector2(int(parts[3]), int(parts[4]))
			
			var island1 = _find_island_by_pos(pos1)
			var island2 = _find_island_by_pos(pos2)
			
			if island1 and island2:
				bridges.append({
					"start_island": island1,
					"end_island": island2,
					"start_pos": island1.node.position,
					"end_pos": island2.node.position,
					"count": value
				})
				island1.connected_bridges += value
				island2.connected_bridges += value

# ==================== HELPER FUNCTIONS ====================

func _can_add_bridge_for_hint(a, b, count: int) -> bool:
	"""
	Basic validation for hint bridge placement
	"""
	# Check if adding this bridge would exceed limits
	if a.connected_bridges + count > a.bridges_target:
		return false
	if b.connected_bridges + count > b.bridges_target:
		return false
	
	# Check if bridge already exists with same or higher count
	for br in bridges:
		if _bridges_match(br, {"start_island": a, "end_island": b}):
			if br.count >= count:
				return false
	
	return true

func _bridges_match(br1, br2) -> bool:
	"""
	Check if two bridges connect the same islands
	"""
	return (br1.start_island == br2.start_island and br1.end_island == br2.end_island) or \
		   (br1.start_island == br2.end_island and br1.end_island == br2.start_island)

func _can_connect_directly(a, b, all_islands: Array) -> bool:
	"""
	Check if two islands can be connected directly (no islands in between)
	"""
	if a.pos.x != b.pos.x and a.pos.y != b.pos.y:
		return false
	
	for island in all_islands:
		if island == a or island == b:
			continue
		
		if a.pos.x == b.pos.x and island.pos.x == a.pos.x:
			if (island.pos.y > min(a.pos.y, b.pos.y) and 
				island.pos.y < max(a.pos.y, b.pos.y)):
				return false
		elif a.pos.y == b.pos.y and island.pos.y == a.pos.y:
			if (island.pos.x > min(a.pos.x, b.pos.x) and 
				island.pos.x < max(a.pos.x, b.pos.x)):
				return false
	
	return true

func _bridges_cross(p1: Vector2, p2: Vector2, q1: Vector2, q2: Vector2) -> bool:
	if p1.x == p2.x and q1.y == q2.y:
		return (p1.x > min(q1.x,q2.x) and p1.x < max(q1.x,q2.x)) and (q1.y > min(p1.y,p2.y) and q1.y < max(p1.y,p2.y))
	if p1.y == p2.y and q1.x == q2.x:
		return (p1.y > min(q1.y,q2.y) and p1.y < max(q1.y,q2.y)) and (q1.x > min(p1.x,p2.x) and q1.x < max(p1.x,p2.x))
	return false

func _find_island_by_pos(pos: Vector2):
	"""
	Find island by position
	"""
	for island in puzzle_data:
		if island.pos == pos:
			return island
	print("Could not find island for position (%d, %d)" % [pos.x, pos.y])
	return null

func _create_island_copy() -> Array:
	"""
	Create a deep copy of islands for the solver
	"""
	var copy = []
	for original in puzzle_data:
		copy.append({
			"pos": original.pos,
			"node": original.node,  # Reference to actual node
			"bridges_target": original.bridges_target,
			"connected_bridges": original.connected_bridges
		})
	return copy

func _find_corresponding_island(solver_island):
	"""
	Find the actual island corresponding to a solver island
	"""
	for actual_island in puzzle_data:
		if actual_island.pos == solver_island.pos:
			return actual_island
	print("Could not find corresponding island for position (%d, %d)" % [solver_island.pos.x, solver_island.pos.y])
	return null

func _add_bridge_internal(a, b, count: int):
	bridges.append({
		"start_island": a,
		"end_island": b, 
		"start_pos": a.node.position,
		"end_pos": b.node.position,
		"count": count
	})
	a.connected_bridges += count
	b.connected_bridges += count
	
	# Print user action
	var bridge_text = "bridge" if count == 1 else "bridges"
	print("USER ACTION: Added %d %s between (%d,%d) and (%d,%d)" % [
		count, bridge_text,
		a.pos.x, a.pos.y,
		b.pos.x, b.pos.y
	])

func _verify_solution() -> bool:
	print("Verifying solution...")
	
	# Check if all islands have correct number of bridges
	for island in puzzle_data:
		if island.connected_bridges != island.bridges_target:
			print("Island at (%d,%d) has %d bridges but needs %d" % [
				island.pos.x, island.pos.y,
				island.connected_bridges, island.bridges_target
			])
			return false
	
	# Check if puzzle is connected
	if not _is_puzzle_connected():
		print("Puzzle is not fully connected")
		return false
	
	# Check for bridge intersections
	if not _no_bridge_intersections():
		print("Bridges intersect")
		return false
	
	print("Solution verified successfully!")
	return true

func _is_puzzle_connected() -> bool:
	if puzzle_data.size() == 0:
		return false
	
	var visited = {}
	var stack = [puzzle_data[0]]
	
	while stack.size() > 0:
		var isl = stack.pop_back()
		visited[isl] = true
		
		for br in bridges:
			var neighbor = null
			if br.start_island == isl:
				neighbor = br.end_island
			elif br.end_island == isl:
				neighbor = br.start_island
			
			if neighbor != null and neighbor not in visited:
				stack.append(neighbor)
	
	return visited.size() == puzzle_data.size()

func _no_bridge_intersections() -> bool:
	for i in range(bridges.size()):
		for j in range(i + 1, bridges.size()):
			var br1 = bridges[i]
			var br2 = bridges[j]
			if _bridges_cross(br1.start_pos, br1.end_pos, br2.start_pos, br2.end_pos):
				return false
	return true

func _check_puzzle_completion():
	"""
	Check if puzzle is solved (for manual play) - simplified version
	"""
	var all_correct = true
	for island in puzzle_data:
		if island.connected_bridges != island.bridges_target:
			all_correct = false
			break
	
	if all_correct:
		puzzle_solved = true
		print("PUZZLE SOLVED! Congratulations!")
	else:
		puzzle_solved = false

func _is_puzzle_complete() -> bool:
	return _check_puzzle_completion() and _is_puzzle_connected()

# ==================== STATE MANAGEMENT ====================

func _duplicate_bridges() -> Array:
	"""
	Create a deep copy of current bridges
	"""
	var bridge_copy = []
	for br in bridges:
		bridge_copy.append({
			"start_island": br.start_island,
			"end_island": br.end_island,
			"start_pos": br.start_pos,
			"end_pos": br.end_pos,
			"count": br.count
		})
	return bridge_copy

func _save_island_states() -> Array:
	"""
	Save current island bridge counts
	"""
	var states = []
	for island in puzzle_data:
		states.append(island.connected_bridges)
	return states

func _restore_bridges(bridge_copy: Array):
	"""
	Restore bridges from copy
	"""
	bridges.clear()
	for br_data in bridge_copy:
		bridges.append({
			"start_island": br_data.start_island,
			"end_island": br_data.end_island,
			"start_pos": br_data.start_pos,
			"end_pos": br_data.end_pos,
			"count": br_data.count
		})

func _restore_island_states(states: Array):
	"""
	Restore island bridge counts
	"""
	for i in range(puzzle_data.size()):
		puzzle_data[i].connected_bridges = states[i]

# ==================== INTERACTION FUNCTIONS ====================

func _get_island_at_pos(pos: Vector2, _global_position: Vector2):
	"""
	Find island at screen position (for mouse interaction)
	"""
	for isl in puzzle_data:
		var hitbox_scale = 0.6
		if grid_size.x <= 8:
			hitbox_scale = 0.6
		elif grid_size.x <= 10:
			hitbox_scale = 0.5
		else:
			hitbox_scale = 0.4
		
		if pos.distance_to(isl.node.position) < cell_size * hitbox_scale:
			return isl
	return null

func _get_bridge_at_pos(pos: Vector2, _global_position: Vector2):
	"""
	Find bridge at screen position (for mouse interaction)
	"""
	for br in bridges:
		var start = br.start_island.node.position
		var end = br.end_island.node.position
		var min_x = min(start.x, end.x) - 5
		var max_x = max(start.x, end.x) + 5
		var min_y = min(start.y, end.y) - 5
		var max_y = max(start.y, end.y) + 5
		if pos.x >= min_x and pos.x <= max_x and pos.y >= min_y and pos.y <= max_y:
			return br
	return null

func _remove_bridge(br):
	"""
	Remove a bridge (for user interaction)
	"""
	br.start_island.connected_bridges -= br.count
	br.end_island.connected_bridges -= br.count
	bridges.erase(br)
	
	# Print user action
	var bridge_text = "bridge" if br.count == 1 else "bridges"
	print("USER ACTION: Removed %d %s between (%d,%d) and (%d,%d)" % [
		br.count, bridge_text,
		br.start_island.pos.x, br.start_island.pos.y,
		br.end_island.pos.x, br.end_island.pos.y
	])
	
	_check_puzzle_completion()

func _try_place_bridge(a, b):
	"""
	Try to place a bridge between two islands (for user interaction)
	"""
	if a.pos.x != b.pos.x and a.pos.y != b.pos.y:
		return false
	
	# Check for intersections
	for br in bridges:
		if _bridges_cross(a.node.position, b.node.position, br.start_pos, br.end_pos):
			return false
	
	# Check if bridge already exists
	for br in bridges:
		if (br.start_island == a and br.end_island == b) or (br.start_island == b and br.end_island == a):
			if br.count < 2:
				br.count += 1
				a.connected_bridges += 1
				b.connected_bridges += 1
				
				# Print user action
				print("USER ACTION: Upgraded to %d bridges between (%d,%d) and (%d,%d)" % [
					br.count,
					a.pos.x, a.pos.y,
					b.pos.x, b.pos.y
				])
				
				_check_puzzle_completion()
				return true
			else:
				return false
	
	# Create new bridge
	bridges.append({
		"start_island": a,
		"end_island": b,
		"start_pos": a.node.position,
		"end_pos": b.node.position,
		"count": 1
	})
	a.connected_bridges += 1
	b.connected_bridges += 1
	
	# Print user action
	print("USER ACTION: Added 1 bridge between (%d,%d) and (%d,%d)" % [
		a.pos.x, a.pos.y,
		b.pos.x, b.pos.y
	])
	
	_check_puzzle_completion()
	return true

# ==================== PUZZLE LOADING ====================

func load_custom_puzzle(file_path: String, parent_node: Node) -> void:
	"""
	Load a puzzle from a custom file
	"""
	# Clear current puzzle
	for isl in puzzle_data:
		if "node" in isl and isl.node:
			isl.node.queue_free()
	puzzle_data.clear()
	bridges.clear()
	hint_bridges.clear()
	puzzle_solved = false
	hint_visible = false
	# Reset CSP hint solution when loading new puzzle
	reset_csp_hint_solution()

	# Extract puzzle index from file path
	var file_name = file_path.get_file()
	if file_name.begins_with("input-") and file_name.ends_with(".txt"):
		var index_str = file_name.trim_prefix("input-").trim_suffix(".txt")
		current_puzzle_index = int(index_str)
		print("Detected puzzle index: ", current_puzzle_index, " from file: ", file_name)

	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		print("Failed to open file: ", file_path)
		return

	var lines = []
	while not file.eof_reached():
		lines.append(file.get_line())
	file.close()

	for y in range(len(lines)):
		var row = lines[y].split(",", false)
		for x in range(row.size()):
			var val = int(row[x])
			if val == 0:
				continue
			var pos = Vector2(x+1, y+1)
			var bridges_target = val
			var sprite = Sprite2D.new()
			sprite.position = grid_offset + pos * cell_size
			sprite.centered = true
			
			# Scale islands based on grid size
			if grid_size.x <= 8:  # 7x7
				sprite.scale = Vector2(0.6, 0.6)
			elif grid_size.x <= 10:  # 9x9
				sprite.scale = Vector2(0.5, 0.5)
			else:  # 13x13 and larger
				sprite.scale = Vector2(0.4, 0.4)
			
			var texture_path = "res://assets/islands/%d.png" % bridges_target
			if ResourceLoader.exists(texture_path):
				sprite.texture = load(texture_path)
			parent_node.add_child(sprite)

			puzzle_data.append({
				"pos": pos,
				"node": sprite,
				"bridges_target": bridges_target,
				"connected_bridges": 0,
				"neighbors": []
			})

	_calculate_neighbors()
	print("Custom puzzle loaded from ", file_path)

func _calculate_neighbors():
	"""
	Calculate which islands can connect to each other
	"""
	for isl in puzzle_data:
		isl["neighbors"] = []
		for other in puzzle_data:
			if isl == other:
				continue
			if isl.pos.x == other.pos.x or isl.pos.y == other.pos.y:
				var blocked = false
				for mid in puzzle_data:
					if mid == isl or mid == other:
						continue
					if isl.pos.x == other.pos.x and mid.pos.x == isl.pos.x:
						if mid.pos.y > min(isl.pos.y, other.pos.y) and mid.pos.y < max(isl.pos.y, other.pos.y):
							blocked = true
					elif isl.pos.y == other.pos.y and mid.pos.y == isl.pos.y:
						if mid.pos.x > min(isl.pos.x, other.pos.x) and mid.pos.x < max(isl.pos.x, other.pos.x):
							blocked = true
				if not blocked:
					isl["neighbors"].append(other)

# ==================== COMPATIBILITY METHODS ====================

func reset_solver():
	"""
	Reset all solver states including CSP hint solution and animation
	"""
	reset_csp_hint_solution()
	
	# Reset animation state
	stop_animation()
	step_by_step_bridges.clear()
	current_animation_step = 0
	animation_completed = false

# ==================== GETTERS ====================

func get_puzzle_data():
	return puzzle_data

func get_bridges():
	"""
	Get only visible bridges for drawing
	"""
	var visible_bridges = []
	for bridge in bridges:
		if bridge.get("visible", true):  # Default to true if no visibility property
			visible_bridges.append(bridge)
	return visible_bridges

func get_hint_bridges():
	return hint_bridges

func is_puzzle_solved():
	return puzzle_solved

func clear_hint_bridges():
	hint_bridges.clear()
	hint_visible = false

func is_csp_hint_ready() -> bool:
	"""
	Check if CSP hint solution is ready
	"""
	return csp_hint_ready

func get_csp_hint_solution_size() -> int:
	"""
	Get the number of bridges in CSP hint solution
	"""
	return csp_hint_solution.size()
