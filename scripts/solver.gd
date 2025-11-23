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

# Solution data for hints
var solution_bridges := []

# Algorithmic solver variables
var solving_steps := []
var current_step := 0

# CSP variables
var csp_domains := {}
var csp_constraints := []

# Initialize method
func initialize(grid_size_param: Vector2i, cell_size_param: int, grid_offset_param: Vector2) -> void:
	grid_size = grid_size_param
	cell_size = cell_size_param
	grid_offset = grid_offset_param

# Update method for handling hint timer
func update(delta: float) -> void:
	if hint_visible:
		hint_timer -= delta
		if hint_timer <= 0:
			clear_hint_bridges()
			hint_visible = false

# Set puzzle info for hint system
func set_puzzle_info(folder: String, index: int):
	puzzle_folder = folder
	current_puzzle_index = index

# ==================== ALGORITHMIC HINT SYSTEM ====================

func algorithmic_hint() -> void:
	"""
	Generate hints using algorithmic step-by-step solver
	"""
	hint_bridges.clear()
	hint_visible = false
	
	print("💡 Generating algorithmic hint...")
	
	if solve_step_by_step():
		var next_step = get_next_step()
		if next_step:
			var start_island = _find_island_by_pos(next_step.start.pos)
			var end_island = _find_island_by_pos(next_step.end.pos)
			
			if start_island and end_island:
				hint_bridges.append({
					"start_island": start_island,
					"end_island": end_island,
					"start_pos": start_island.node.position,
					"end_pos": end_island.node.position,
					"count": next_step.count
				})
				
				hint_visible = true
				hint_timer = 3.0
				
				print("💡 ALGORITHMIC HINT: %s" % next_step.description)
		else:
			print("💡 All steps completed!")
	else:
		print("❌ Could not generate algorithmic hint")

# ==================== OUTPUT FILE-BASED HINT SYSTEM ====================

func file_based_hint() -> void:
	"""
	Generate hints by reading from output files
	"""
	hint_bridges.clear()
	hint_visible = false
	
	print("💡 Generating hint from output file...")
	
	# Load solution from output file
	if not _load_solution_for_hint():
		print("❌ Could not load solution for hint")
		return
	
	# Find the first bridge from the solution that isn't in the current bridges
	var suggested_bridge = _find_next_suggested_bridge()
	
	if suggested_bridge:
		hint_bridges.append({
			"start_island": suggested_bridge.start_island,
			"end_island": suggested_bridge.end_island,
			"start_pos": suggested_bridge.start_island.node.position,
			"end_pos": suggested_bridge.end_island.node.position,
			"count": suggested_bridge.count
		})
		
		hint_visible = true
		hint_timer = 3.0  # Show for 3 seconds
		
		print("💡 FILE-BASED HINT: Add %d bridge(s) between island at (%d,%d) and (%d,%d)" % [
			suggested_bridge.count,
			suggested_bridge.start_island.pos.x - 1, suggested_bridge.start_island.pos.y - 1,
			suggested_bridge.end_island.pos.x - 1, suggested_bridge.end_island.pos.y - 1
		])
	else:
		print("💡 All solution bridges are already placed!")

func _load_solution_for_hint() -> bool:
	"""
	Load solution bridges from output file for hint system
	"""
	solution_bridges.clear()
	
	var solution_file = "res://assets/output/%s/output-%02d.txt" % [puzzle_folder, current_puzzle_index]
	if not FileAccess.file_exists(solution_file):
		print("❌ Solution file not found for hint: ", solution_file)
		return false
	
	print("📖 Loading solution for hint from: ", solution_file)
	
	var file = FileAccess.open(solution_file, FileAccess.READ)
	if file == null:
		return false
	
	# Read solution grid
	var solution_grid = []
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line.is_empty():
			continue
		var continuous_line = ""
		for i in range(line.length()):
			var character = line[i]
			if character != " ":
				continuous_line += character
		solution_grid.append(continuous_line)
	
	file.close()
	
	# Create island map
	var island_map = {}
	for island in puzzle_data:
		var key = Vector2(island.pos.x - 1, island.pos.y - 1)
		island_map[key] = island
	
	# Parse bridges from solution
	for y in range(solution_grid.size()):
		var row = solution_grid[y]
		_parse_solution_bridges_horizontal(row, y, island_map)
	
	for x in range(solution_grid[0].length()):
		_parse_solution_bridges_vertical(x, solution_grid, island_map)
	
	print("✅ Loaded %d solution bridges for hints" % solution_bridges.size())
	return true

func _parse_solution_bridges_horizontal(row: String, y: int, island_map: Dictionary):
	var x = 0
	while x < row.length():
		var cell = row[x]
		
		if cell == "-" or cell == "=":
			var bridge_count = 2 if cell == "=" else 1
			
			# Find islands at ends
			var left_island = _find_island_horizontal(x - 1, y, -1, row, island_map)
			var right_island = _find_island_horizontal(x + 1, y, 1, row, island_map)
			
			if left_island and right_island:
				solution_bridges.append({
					"start_island": left_island,
					"end_island": right_island,
					"count": bridge_count
				})
			
			x += 1
		else:
			x += 1

func _parse_solution_bridges_vertical(x: int, grid: Array, island_map: Dictionary):
	var y = 0
	while y < grid.size():
		if x < grid[y].length():
			var cell = grid[y][x]
			
			if cell == "|" or cell == "$":
				var bridge_count = 2 if cell == "$" else 1
				
				# Find islands at ends
				var top_island = _find_island_vertical(x, y - 1, -1, grid, island_map)
				var bottom_island = _find_island_vertical(x, y + 1, 1, grid, island_map)
				
				if top_island and bottom_island:
					solution_bridges.append({
						"start_island": top_island,
						"end_island": bottom_island,
						"count": bridge_count
					})
				
				y += 1
			else:
				y += 1
		else:
			y += 1

func _find_next_suggested_bridge():
	"""
	Find the next bridge from solution that should be placed
	"""
	for sol_br in solution_bridges:
		var already_exists = false
		
		# Check if this bridge already exists in current bridges
		for current_br in bridges:
			if _bridges_match(current_br, sol_br):
				# Check if it has the correct count
				if current_br.count >= sol_br.count:
					already_exists = true
				break
		
		if not already_exists:
			# Check if we can add this bridge (basic validation)
			var can_add = _can_add_bridge_for_hint(sol_br.start_island, sol_br.end_island, sol_br.count)
			if can_add:
				return sol_br
	
	return null

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

func _find_island_horizontal(start_x: int, y: int, direction: int, row: String, island_map: Dictionary):
	var x = start_x
	while x >= 0 and x < row.length():
		var cell = row[x]
		
		# Check if this cell contains an island number
		if cell >= "1" and cell <= "9":
			var key = Vector2(x, y)
			if island_map.has(key):
				return island_map[key]
		
		# Stop if we hit a non-bridge, non-space character that's not a number
		if cell != " " and cell != "-" and cell != "=" and cell != "|" and cell != "$" and cell != "0":
			break
		
		x += direction
	
	return null

func _find_island_vertical(x: int, start_y: int, direction: int, grid: Array, island_map: Dictionary):
	var y = start_y
	while y >= 0 and y < grid.size():
		if x < grid[y].length():
			var cell = grid[y][x]
			
			# Check if this cell contains an island number
			if cell >= "1" and cell <= "9":
				var key = Vector2(x, y)
				if island_map.has(key):
					return island_map[key]
			
			# Stop if we hit a non-bridge, non-space character that's not a number
			if cell != " " and cell != "-" and cell != "=" and cell != "|" and cell != "$" and cell != "0":
				break
		
		y += direction
	
	return null

# ==================== CSP SOLVER ====================

func csp_based_solver() -> bool:
	"""
	CSP-based solver using constraint satisfaction techniques
	"""
	print("🧠 Starting CSP solver...")
	
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
		print("✅ CSP solver found solution in %d ms!" % (end_time - start_time))
		puzzle_solved = true
		return true
	else:
		print("❌ CSP solver failed")
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

func _find_island_by_pos_csp(islands: Array, pos: Vector2):
	"""
	Find island by position in CSP solver islands
	"""
	for island in islands:
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

# ==================== BACKTRACKING SOLVER ====================

func backtracking_solver() -> bool:
	"""
	Solve the puzzle using constraint-based backtracking algorithm
	"""
	print("🧠 Starting backtracking solver...")
	
	# Save current state
	var original_bridges = _duplicate_bridges()
	var original_island_states = _save_island_states()
	
	# Clear for fresh start
	bridges.clear()
	for island in puzzle_data:
		island.connected_bridges = 0
	
	# Create a copy for the solver to work with
	var solver_islands = _create_island_copy()
	var solver_bridges = []
	
	var start_time = Time.get_ticks_msec()
	var success = _backtrack_solve(solver_islands, solver_bridges, 0)
	var end_time = Time.get_ticks_msec()
	
	if success:
		print("✅ Backtracking solver found solution in %d ms!" % (end_time - start_time))
		# Apply the solution
		_apply_solution(solver_bridges)
		puzzle_solved = true
		return true
	else:
		print("❌ Backtracking solver could not find solution")
		_restore_bridges(original_bridges)
		_restore_island_states(original_island_states)
		puzzle_solved = false
		return false

func _backtrack_solve(islands: Array, current_bridges: Array, depth: int) -> bool:
	"""
	Recursive backtracking solver with constraint propagation
	"""
	# Base case: check if puzzle is solved
	if _is_solution_complete(islands, current_bridges):
		print("✅ Found solution at depth ", depth)
		return true
	
	if depth > 1000:  # Prevent infinite recursion
		print("⚠️  Depth limit reached at depth ", depth)
		return false
	
	# Select the most constrained island (MRV heuristic)
	var island = _select_most_constrained_island(islands)
	if not island:
		print("❌ No constrained island found at depth ", depth)
		return false
	
	# Get possible bridge moves for this island
	var possible_moves = _get_possible_bridge_moves(island, islands, current_bridges)
	
	# Try each possible move
	for move in possible_moves:
		# Apply the move
		var bridge_added = _apply_bridge_move(move, current_bridges)
		
		# Check constraints
		if _is_state_valid(islands, current_bridges):
			# Recursively solve
			if _backtrack_solve(islands, current_bridges, depth + 1):
				return true
		
		# Backtrack - remove the bridge
		if bridge_added:
			_remove_bridge_move(move, current_bridges)
	
	return false

func _select_most_constrained_island(islands: Array):
	"""
	Select island with fewest remaining bridge possibilities (MRV heuristic)
	"""
	var best_island = null
	var best_score = INF
	
	for island in islands:
		var remaining = island.bridges_target - island.connected_bridges
		if remaining <= 0:
			continue
		
		# Score based on remaining bridges and available neighbors
		var available_neighbors = _get_available_neighbors(island, islands)
		var score = remaining * 10 + available_neighbors.size()
		
		if score < best_score:
			best_score = score
			best_island = island
	
	return best_island

func _get_possible_bridge_moves(island, islands: Array, current_bridges: Array) -> Array:
	"""
	Generate all possible valid bridge moves for an island
	"""
	var moves = []
	var remaining = island.bridges_target - island.connected_bridges
	
	if remaining <= 0:
		return moves
	
	# Check each possible neighbor
	for neighbor in _get_available_neighbors(island, islands):
		# Check if bridge already exists
		var existing_bridge = _find_existing_bridge(island, neighbor, current_bridges)
		var current_count = existing_bridge.count if existing_bridge else 0
		
		# Possible bridge counts (1 or 2, but respect limits)
		for count in [1, 2]:
			if current_count + count <= 2 and count <= remaining:
				# Check if this would exceed neighbor's capacity
				var neighbor_remaining = neighbor.bridges_target - neighbor.connected_bridges
				if count <= neighbor_remaining:
					# Check for intersections
					if not _would_cause_intersection(island, neighbor, current_bridges):
						moves.append({
							"start": island,
							"end": neighbor,
							"count": count,
							"existing": existing_bridge
						})
	
	return moves

func _get_available_neighbors(island, islands: Array) -> Array:
	"""
	Get all neighbors that can be connected to this island
	"""
	var neighbors = []
	
	for other in islands:
		if other == island:
			continue
		
		# Check if they're aligned and no islands between them
		if _can_connect_directly(island, other, islands):
			neighbors.append(other)
	
	return neighbors

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

func _would_cause_intersection(start_island, end_island, current_bridges: Array) -> bool:
	"""
	Check if adding this bridge would cause intersections
	"""
	var start_pos = start_island.node.position
	var end_pos = end_island.node.position
	
	for bridge in current_bridges:
		if (bridge.start_island == start_island and bridge.end_island == end_island) or \
		   (bridge.start_island == end_island and bridge.end_island == start_island):
			continue  # Same bridge, no intersection
		
		if _bridges_cross(start_pos, end_pos, bridge.start_pos, bridge.end_pos):
			return true
	
	return false

func _apply_bridge_move(move, current_bridges: Array) -> bool:
	"""
	Apply a bridge move to the current state
	"""
	if move.existing:
		# Update existing bridge
		move.existing.count += move.count
		move.start.connected_bridges += move.count
		move.end.connected_bridges += move.count
		return false  # Not a new bridge
	else:
		# Create new bridge
		var new_bridge = {
			"start_island": move.start,
			"end_island": move.end,
			"start_pos": move.start.node.position,
			"end_pos": move.end.node.position,
			"count": move.count
		}
		current_bridges.append(new_bridge)
		move.start.connected_bridges += move.count
		move.end.connected_bridges += move.count
		return true  # New bridge added

func _remove_bridge_move(move, current_bridges: Array):
	"""
	Remove a bridge move from the current state
	"""
	if move.existing:
		# Revert existing bridge
		move.existing.count -= move.count
		move.start.connected_bridges -= move.count
		move.end.connected_bridges -= move.count
	else:
		# Remove new bridge
		for i in range(current_bridges.size() - 1, -1, -1):
			var br = current_bridges[i]
			if br.start_island == move.start and br.end_island == move.end:
				current_bridges.remove_at(i)
				move.start.connected_bridges -= move.count
				move.end.connected_bridges -= move.count
				break

func _is_state_valid(islands: Array, current_bridges: Array) -> bool:
	"""
	Check if current state doesn't violate constraints
	"""
	# Check if any island exceeds its target
	for island in islands:
		if island.connected_bridges > island.bridges_target:
			return false
	
	# Check for bridge intersections
	for i in range(current_bridges.size()):
		for j in range(i + 1, current_bridges.size()):
			var br1 = current_bridges[i]
			var br2 = current_bridges[j]
			if _bridges_cross(br1.start_pos, br1.end_pos, br2.start_pos, br2.end_pos):
				return false
	
	return true

func _is_solution_complete(islands: Array, current_bridges: Array) -> bool:
	"""
	Check if puzzle is completely solved
	"""
	# All islands have correct number of bridges
	for island in islands:
		if island.connected_bridges != island.bridges_target:
			return false
	
	# Check connectivity
	return _is_fully_connected(islands, current_bridges)

func _is_fully_connected(islands: Array, current_bridges: Array) -> bool:
	"""
	Check if all islands are connected in a single component
	"""
	if islands.is_empty():
		return true
	
	var visited = {}
	var stack = [islands[0]]
	
	while stack.size() > 0:
		var island = stack.pop_back()
		visited[island] = true
		
		# Find all connected neighbors via bridges
		for bridge in current_bridges:
			var neighbor = null
			if bridge.start_island == island:
				neighbor = bridge.end_island
			elif bridge.end_island == island:
				neighbor = bridge.start_island
			
			if neighbor and not visited.has(neighbor):
				stack.append(neighbor)
	
	return visited.size() == islands.size()

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

func _apply_solution(solver_bridges: Array):
	"""
	Apply the found solution to the actual puzzle state
	"""
	bridges.clear()
	
	# Update bridge counts on actual islands
	for island in puzzle_data:
		island.connected_bridges = 0
	
	# Add all bridges from solution
	for solver_br in solver_bridges:
		# Find corresponding actual islands
		var actual_start = _find_corresponding_island(solver_br.start_island)
		var actual_end = _find_corresponding_island(solver_br.end_island)
		
		if actual_start and actual_end:
			bridges.append({
				"start_island": actual_start,
				"end_island": actual_end,
				"start_pos": actual_start.node.position,
				"end_pos": actual_end.node.position,
				"count": solver_br.count
			})
			actual_start.connected_bridges += solver_br.count
			actual_end.connected_bridges += solver_br.count

func _find_corresponding_island(solver_island):
	"""
	Find the actual island corresponding to a solver island
	"""
	for actual_island in puzzle_data:
		if actual_island.pos == solver_island.pos:
			return actual_island
	return null

func _find_existing_bridge(a, b, bridge_list: Array):
	"""
	Find existing bridge between two islands
	"""
	for bridge in bridge_list:
		if (bridge.start_island == a and bridge.end_island == b) or \
		   (bridge.start_island == b and bridge.end_island == a):
			return bridge
	return null

# ==================== STEP-BY-STEP SOLVER ====================

func solve_step_by_step() -> bool:
	"""
	Prepare for step-by-step solving
	"""
	print("🔍 Preparing step-by-step solution...")
	
	# Clear previous steps
	solving_steps.clear()
	current_step = 0
	
	# Solve completely to get all steps
	var temp_islands = _create_island_copy()
	var temp_bridges = []
	
	if _backtrack_solve_with_steps(temp_islands, temp_bridges, 0):
		print("✅ Step-by-step solution prepared with %d steps" % solving_steps.size())
		return true
	
	return false

func _backtrack_solve_with_steps(islands: Array, current_bridges: Array, depth: int) -> bool:
	"""
	Backtracking solver that records steps
	"""
	if _is_solution_complete(islands, current_bridges):
		return true
	
	var island = _select_most_constrained_island(islands)
	if not island:
		return false
	
	var possible_moves = _get_possible_bridge_moves(island, islands, current_bridges)
	
	for move in possible_moves:
		var bridge_added = _apply_bridge_move(move, current_bridges)
		
		if _is_state_valid(islands, current_bridges):
			# Record this step
			solving_steps.append({
				"start": {"pos": move.start.pos, "bridges_target": move.start.bridges_target},
				"end": {"pos": move.end.pos, "bridges_target": move.end.bridges_target},
				"count": move.count,
				"description": "Add %d bridge(s) between (%d,%d) and (%d,%d)" % [
					move.count, move.start.pos.x-1, move.start.pos.y-1,
					move.end.pos.x-1, move.end.pos.y-1
				]
			})
			
			if _backtrack_solve_with_steps(islands, current_bridges, depth + 1):
				return true
			
			# Remove step if backtracking (we'll keep the successful path)
			solving_steps.pop_back()
		
		if bridge_added:
			_remove_bridge_move(move, current_bridges)
	
	return false

func has_next_step() -> bool:
	return current_step < solving_steps.size()

func get_next_step():
	if current_step < solving_steps.size():
		return solving_steps[current_step]
	return null

func apply_next_step() -> bool:
	"""
	Apply the next step in the solution
	"""
	if current_step >= solving_steps.size():
		return false
	
	var step = solving_steps[current_step]
	
	# Find the actual islands
	var start_island = _find_island_by_pos(step.start.pos)
	var end_island = _find_island_by_pos(step.end.pos)
	
	if start_island and end_island:
		# Add the bridge
		if _can_add_bridge(start_island, end_island, step.count):
			_add_bridge_internal(start_island, end_island, step.count)
			print("🔧 Applied step %d: %s" % [current_step + 1, step.description])
			current_step += 1
			return true
	
	return false

func _find_island_by_pos(pos: Vector2):
	"""
	Find island by position
	"""
	for island in puzzle_data:
		if island.pos == pos:
			return island
	return null

func show_next_hint_as_bridge():
	"""
	Show the next step as a visual hint bridge
	"""
	if current_step < solving_steps.size():
		var step = solving_steps[current_step]
		var start_island = _find_island_by_pos(step.start.pos)
		var end_island = _find_island_by_pos(step.end.pos)
		
		if start_island and end_island:
			hint_bridges.append({
				"start_island": start_island,
				"end_island": end_island,
				"start_pos": start_island.node.position,
				"end_pos": end_island.node.position,
				"count": step.count
			})
			hint_visible = true
			hint_timer = 2.0  # Show for 2 seconds

# ==================== OUTPUT FILE SOLVER ====================

func output_file_solver() -> bool:
	"""
	Solve by loading pre-computed solution from output file
	"""
	print("🧠 Loading solution from output file...")
	
	# Clear existing bridges
	bridges.clear()
	for island in puzzle_data:
		island.connected_bridges = 0
	
	var start_time = Time.get_ticks_msec()
	
	# Load and apply the complete solution
	var solution_file = "res://assets/output/%s/output-%02d.txt" % [puzzle_folder, current_puzzle_index]
	
	if not FileAccess.file_exists(solution_file):
		print("❌ Solution file not found: ", solution_file)
		puzzle_solved = false
		return false
	
	_load_solution_from_output(solution_file)
	
	var end_time = Time.get_ticks_msec()
	
	# Verify the solution
	if _verify_solution():
		print("🎉 Output file solver completed!")
		print("⏱️ Loading time: %d ms" % (end_time - start_time))
		puzzle_solved = true
		return true
	else:
		print("❌ Solution verification failed!")
		puzzle_solved = false
		return false

func _load_solution_from_output(solution_file: String):
	print("📖 Reading solution from: ", solution_file)
	
	var file = FileAccess.open(solution_file, FileAccess.READ)
	if file == null:
		print("❌ Failed to open solution file")
		return
	
	# Read the solution file - handle space-separated format
	var solution_grid = []
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line.is_empty():
			continue
		# Convert space-separated to continuous string for parsing
		var continuous_line = ""
		for i in range(line.length()):
			var character = line[i]
			if character != " ":
				continuous_line += character
		solution_grid.append(continuous_line)
	
	file.close()
	
	# Create a map of all puzzle islands by their grid position
	var island_map = {}
	for island in puzzle_data:
		var key = Vector2(island.pos.x - 1, island.pos.y - 1)  # Convert to 0-based
		island_map[key] = island
	
	# Parse ALL horizontal bridges
	for y in range(solution_grid.size()):
		var row = solution_grid[y]
		_parse_horizontal_bridges_complete(row, y, island_map)
	
	# Parse ALL vertical bridges  
	for x in range(solution_grid[0].length()):
		_parse_vertical_bridges_complete(x, solution_grid, island_map)
	
	print("✅ Solution applied - total bridges: %d" % bridges.size())

func _parse_horizontal_bridges_complete(row: String, y: int, island_map: Dictionary):
	var x = 0
	while x < row.length():
		var cell = row[x]
		
		if cell == "-" or cell == "=":
			var bridge_start_x = x
			var bridge_count = 2 if cell == "=" else 1
			
			# Find the full bridge span
			var bridge_end_x = bridge_start_x
			while bridge_end_x < row.length() and (row[bridge_end_x] == "-" or row[bridge_end_x] == "="):
				bridge_end_x += 1
			
			# Find the islands at both ends
			var left_island = _find_island_horizontal(bridge_start_x - 1, y, -1, row, island_map)
			var right_island = _find_island_horizontal(bridge_end_x, y, 1, row, island_map)
			
			if left_island and right_island:
				_add_solution_bridge(left_island, right_island, bridge_count)
			
			x = bridge_end_x
		else:
			x += 1

func _parse_vertical_bridges_complete(x: int, grid: Array, island_map: Dictionary):
	var y = 0
	while y < grid.size():
		if x < grid[y].length():
			var cell = grid[y][x]
			
			if cell == "|" or cell == "$":
				var bridge_start_y = y
				var bridge_count = 2 if cell == "$" else 1
				
				# Find the full bridge span
				var bridge_end_y = bridge_start_y
				while bridge_end_y < grid.size() and x < grid[bridge_end_y].length() and (grid[bridge_end_y][x] == "|" or grid[bridge_end_y][x] == "$"):
					bridge_end_y += 1
				
				# Find the islands at both ends
				var top_island = _find_island_vertical(x, bridge_start_y - 1, -1, grid, island_map)
				var bottom_island = _find_island_vertical(x, bridge_end_y, 1, grid, island_map)
				
				if top_island and bottom_island:
					_add_solution_bridge(top_island, bottom_island, bridge_count)
				
				y = bridge_end_y
			else:
				y += 1
		else:
			y += 1

func _add_solution_bridge(a, b, count: int):
	# Check if bridge already exists
	for br in bridges:
		if (br.start_island == a and br.end_island == b) or (br.start_island == b and br.end_island == a):
			var old_count = br.count
			br.count = count
			a.connected_bridges += (count - old_count)
			b.connected_bridges += (count - old_count)
			return
	
	# Create new bridge
	bridges.append({
		"start_island": a,
		"end_island": b,
		"start_pos": a.node.position,
		"end_pos": b.node.position,
		"count": count
	})
	a.connected_bridges += count
	b.connected_bridges += count

func _verify_solution() -> bool:
	print("🔍 Verifying solution...")
	
	# Check if all islands have correct number of bridges
	for island in puzzle_data:
		if island.connected_bridges != island.bridges_target:
			print("❌ Island at (%d,%d) has %d bridges but needs %d" % [
				island.pos.x-1, island.pos.y-1,
				island.connected_bridges, island.bridges_target
			])
			return false
	
	# Check if puzzle is connected
	if not _is_puzzle_connected():
		print("❌ Puzzle is not fully connected")
		return false
	
	# Check for bridge intersections
	if not _no_bridge_intersections():
		print("❌ Bridges intersect")
		return false
	
	print("🎉 Solution verified successfully!")
	return true

# ==================== SOLUTION LOADING (for main game) ====================

func _load_solution_robust(file_path: String):
	"""
	Load and apply the complete solution from file - for main game compatibility
	"""
	print("🔍 Loading solution from: ", file_path)
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		print("Failed to open solution file: ", file_path)
		return
	
	# Clear existing bridges
	bridges.clear()
	# Reset connected bridges count
	for isl in puzzle_data:
		isl.connected_bridges = 0
	
	# Read the solution file - handle space-separated format
	var solution_grid = []
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line.is_empty():
			continue
		# Convert space-separated to continuous string for parsing
		var continuous_line = ""
		for i in range(line.length()):
			var character = line[i]
			if character != " ":
				continuous_line += character
		solution_grid.append(continuous_line)
	
	file.close()
	
	# Create a map of all puzzle islands by their grid position
	var island_map = {}
	for island in puzzle_data:
		var key = Vector2(island.pos.x - 1, island.pos.y - 1)  # Convert to 0-based
		island_map[key] = island
	
	# Parse ALL horizontal bridges
	for y in range(solution_grid.size()):
		var row = solution_grid[y]
		_parse_horizontal_bridges_complete(row, y, island_map)
	
	# Parse ALL vertical bridges
	for x in range(solution_grid[0].length()):
		_parse_vertical_bridges_complete(x, solution_grid, island_map)
	
	print("=== SOLUTION APPLIED ===")
	puzzle_solved = true

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
	solution_bridges.clear()
	puzzle_solved = false
	hint_visible = false

	# Extract puzzle index from file path
	var file_name = file_path.get_file()
	if file_name.begins_with("input-") and file_name.ends_with(".txt"):
		var index_str = file_name.trim_prefix("input-").trim_suffix(".txt")
		current_puzzle_index = int(index_str)
		print("🎯 Detected puzzle index: ", current_puzzle_index, " from file: ", file_name)

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
	print("✅ Custom puzzle loaded from ", file_path)

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
	_check_puzzle_completion()
	return true

# ==================== HELPER FUNCTIONS ====================

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

func _bridges_cross(p1: Vector2, p2: Vector2, q1: Vector2, q2: Vector2) -> bool:
	if p1.x == p2.x and q1.y == q2.y:
		return (p1.x > min(q1.x,q2.x) and p1.x < max(q1.x,q2.x)) and (q1.y > min(p1.y,p2.y) and q1.y < max(p1.y,p2.y))
	if p1.y == p2.y and q1.x == q2.x:
		return (p1.y > min(q1.y,q2.y) and p1.y < max(q1.y,q2.y)) and (q1.x > min(p1.x,p2.x) and q1.x < max(p1.x,p2.x))
	return false

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
		print("🎉 PUZZLE SOLVED! Congratulations!")
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

# ==================== BASIC BRIDGE OPERATIONS ====================

func _can_add_bridge(a, b, count: int) -> bool:
	# Check if adding this bridge would exceed limits
	if a.connected_bridges + count > a.bridges_target:
		return false
	if b.connected_bridges + count > b.bridges_target:
		return false
	
	# Check if bridge already exists
	for br in bridges:
		if (br.start_island == a and br.end_island == b) or (br.start_island == b and br.end_island == a):
			return false
	
	# Check for intersections
	var new_start = a.node.position
	var new_end = b.node.position
	for br in bridges:
		if _bridges_cross(new_start, new_end, br.start_pos, br.end_pos):
			return false
	
	return true

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

func _remove_bridge_internal(a, b):
	for i in range(bridges.size() - 1, -1, -1):
		var br = bridges[i]
		if (br.start_island == a and br.end_island == b) or (br.start_island == b and br.end_island == a):
			a.connected_bridges -= br.count
			b.connected_bridges -= br.count
			bridges.remove_at(i)
			break

# ==================== COMPATIBILITY METHODS ====================

func provide_ai_hint():
	if not output_file_solver():
		return "No solution found"
	
	# Find a helpful bridge suggestion
	for island in puzzle_data:
		if island.connected_bridges < island.bridges_target:
			for neighbor in island.neighbors:
				if _can_add_bridge(island, neighbor, 1):
					return "Try connecting island at (%d,%d) to (%d,%d)" % [
						island.pos.x, island.pos.y,
						neighbor.pos.x, neighbor.pos.y
					]
	
	return "Puzzle appears to be correct!"

func reset_solver():
	solution_bridges.clear()
	solving_steps.clear()
	current_step = 0

# ==================== GETTERS ====================

func get_puzzle_data():
	return puzzle_data

func get_bridges():
	return bridges

func get_hint_bridges():
	return hint_bridges

func is_puzzle_solved():
	return puzzle_solved

func clear_hint_bridges():
	hint_bridges.clear()
	hint_visible = false
