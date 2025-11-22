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

# ==================== SIMPLE BACKTRACKING SOLVER ====================

func solve_with_simple_backtracking() -> bool:
	"""
	Simpler backtracking solver that might work better for initial testing
	"""
	print("🧠 Starting simple backtracking solver...")
	
	# Save current state
	var original_bridges = _duplicate_bridges()
	var original_island_states = _save_island_states()
	
	# Clear for fresh start
	bridges.clear()
	for island in puzzle_data:
		island.connected_bridges = 0
	
	var solver_islands = _create_island_copy()
	var solver_bridges = []
	
	var start_time = Time.get_ticks_msec()
	var success = _simple_backtrack(solver_islands, solver_bridges, 0)
	var end_time = Time.get_ticks_msec()
	
	if success:
		print("✅ Simple backtracking found solution in %d ms!" % (end_time - start_time))
		_apply_solution(solver_bridges)
		puzzle_solved = true
		return true
	else:
		print("❌ Simple backtracking failed")
		_restore_bridges(original_bridges)
		_restore_island_states(original_island_states)
		puzzle_solved = false
		return false

func _simple_backtrack(islands: Array, current_bridges: Array, depth: int) -> bool:
	"""
	Simpler backtracking algorithm
	"""
	if _is_solution_complete(islands, current_bridges):
		return true
	
	if depth > 2000:  # Prevent infinite recursion
		return false
	
	# Find first unsatisfied island
	var target_island = null
	for island in islands:
		if island.connected_bridges < island.bridges_target:
			target_island = island
			break
	
	if not target_island:
		return false
	
	# Try all possible connections
	for neighbor in _get_available_neighbors(target_island, islands):
		for count in [1, 2]:
			# Check if this move is valid
			if (target_island.connected_bridges + count <= target_island.bridges_target and
				neighbor.connected_bridges + count <= neighbor.bridges_target):
				
				# Check if bridge already exists
				var existing_bridge = _find_existing_bridge(target_island, neighbor, current_bridges)
				if existing_bridge and existing_bridge.count + count > 2:
					continue
				
				# Check intersections
				if _would_cause_intersection(target_island, neighbor, current_bridges):
					continue
				
				# Apply the move
				var bridge_added = false
				if existing_bridge:
					existing_bridge.count += count
					target_island.connected_bridges += count
					neighbor.connected_bridges += count
				else:
					var new_bridge = {
						"start_island": target_island,
						"end_island": neighbor,
						"start_pos": target_island.node.position,
						"end_pos": neighbor.node.position,
						"count": count
					}
					current_bridges.append(new_bridge)
					target_island.connected_bridges += count
					neighbor.connected_bridges += count
					bridge_added = true
				
				# Recursively solve
				if _simple_backtrack(islands, current_bridges, depth + 1):
					return true
				
				# Backtrack
				if existing_bridge:
					existing_bridge.count -= count
					target_island.connected_bridges -= count
					neighbor.connected_bridges -= count
				elif bridge_added:
					current_bridges.pop_back()
					target_island.connected_bridges -= count
					neighbor.connected_bridges -= count
	
	return false

# ==================== ADVANCED BACKTRACKING SOLVER ====================

func solve_with_algorithm() -> bool:
	"""
	Solve the puzzle using constraint-based backtracking algorithm
	"""
	print("🧠 Starting algorithmic solver...")
	
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
		print("✅ Algorithm found solution in %d ms!" % (end_time - start_time))
		# Apply the solution
		_apply_solution(solver_bridges)
		puzzle_solved = true
		return true
	else:
		print("❌ Algorithm could not find solution")
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

# ==================== SIMPLE GUIDED SOLVER ====================

func solve_with_backtracking() -> bool:
	"""
	Simple solver that uses output files to directly guide the solution
	"""
	print("🧠 Starting simple guided solver...")
	
	# Save current state
	var original_bridges = _duplicate_bridges()
	var original_island_states = _save_island_states()
	
	# Clear for fresh start
	bridges.clear()
	for island in puzzle_data:
		island.connected_bridges = 0
	
	# Load solution bridges for guidance
	if not _load_solution_bridges():
		print("❌ Failed to load solution bridges")
		_restore_bridges(original_bridges)
		_restore_island_states(original_island_states)
		return false
	
	print("🔍 Building solution from guidance...")
	
	# Simply add all solution bridges that are valid
	var success = _build_from_solution()
	
	if success and _verify_solution():
		print("✅ Successfully built solution!")
		puzzle_solved = true
		return true
	else:
		print("❌ Failed to build solution, restoring original state")
		_restore_bridges(original_bridges)
		_restore_island_states(original_island_states)
		puzzle_solved = false
		return false

func _build_from_solution() -> bool:
	"""
	Build the solution by adding bridges from the solution file
	"""
	# Add bridges in multiple passes to handle dependencies
	var max_passes = 10
	var pass_count = 0
	
	while pass_count < max_passes and not _is_puzzle_complete():
		pass_count += 1
		var bridges_added = 0
		
		for sol_br in solution_bridges:
			# Check if this bridge is already placed
			var already_exists = false
			for existing_br in bridges:
				if _bridges_match(existing_br, sol_br):
					already_exists = true
					break
			
			if already_exists:
				continue
			
			# Check if we can add this bridge
			if _can_add_bridge(sol_br.start_island, sol_br.end_island, sol_br.count):
				_add_bridge_internal(sol_br.start_island, sol_br.end_island, sol_br.count)
				bridges_added += 1
				print("🔧 Added solution bridge: %d bridge(s) between (%d,%d) and (%d,%d)" % [
					sol_br.count, sol_br.start_island.pos.x, sol_br.start_island.pos.y,
					sol_br.end_island.pos.x, sol_br.end_island.pos.y
				])
		
		# If no bridges were added this pass, we're stuck
		if bridges_added == 0:
			print("⚠️  No bridges added in pass %d, might be stuck" % pass_count)
			
			# Try to add any valid bridge that matches solution count
			for sol_br in solution_bridges:
				# Check if this bridge is already placed
				var already_exists = false
				for existing_br in bridges:
					if _bridges_match(existing_br, sol_br):
						already_exists = true
						break
				
				if already_exists:
					continue
				
				# Try with reduced count if needed
				var start_remaining = sol_br.start_island.bridges_target - sol_br.start_island.connected_bridges
				var end_remaining = sol_br.end_island.bridges_target - sol_br.end_island.connected_bridges
				var actual_count = min(sol_br.count, start_remaining, end_remaining)
				
				if actual_count > 0 and _can_add_bridge(sol_br.start_island, sol_br.end_island, actual_count):
					_add_bridge_internal(sol_br.start_island, sol_br.end_island, actual_count)
					bridges_added += 1
					print("🔧 Added partial solution bridge: %d bridge(s) between (%d,%d) and (%d,%d)" % [
						actual_count, sol_br.start_island.pos.x, sol_br.start_island.pos.y,
						sol_br.end_island.pos.x, sol_br.end_island.pos.y
					])
					break
			
			# If still no bridges added, we're really stuck
			if bridges_added == 0:
				print("❌ Completely stuck after %d passes" % pass_count)
				return false
	
	return _is_puzzle_complete()

func _load_solution_bridges() -> bool:
	"""
	Load solution bridges from output file
	"""
	solution_bridges.clear()
	
	var solution_file = "res://assets/output/%s/output-%02d.txt" % [puzzle_folder, current_puzzle_index]
	if not FileAccess.file_exists(solution_file):
		print("❌ Solution file not found: ", solution_file)
		return false
	
	print("📖 Loading solution bridges from: ", solution_file)
	
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
	
	# Parse bridges
	for y in range(solution_grid.size()):
		var row = solution_grid[y]
		_parse_solution_bridges_horizontal(row, y, island_map)
	
	for x in range(solution_grid[0].length()):
		_parse_solution_bridges_vertical(x, solution_grid, island_map)
	
	print("✅ Loaded %d solution bridges" % solution_bridges.size())
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

func _bridges_match(br1, br2) -> bool:
	"""
	Check if two bridges connect the same islands
	"""
	return (br1.start_island == br2.start_island and br1.end_island == br2.end_island) or \
		   (br1.start_island == br2.end_island and br1.end_island == br2.start_island)

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

# ==================== SIMPLE OUTPUT-BASED SOLVER ====================

func solve_puzzle() -> bool:
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
		print("🎉 Puzzle solved using output file!")
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

# ==================== HINT SYSTEM ====================

func _generate_enhanced_hint():
	"""
	Generate accurate hints using the solution data from output files
	"""
	hint_bridges.clear()
	hint_visible = false
	
	if solution_bridges.is_empty():
		print("❌ No solution data available for hints")
		return
	
	# Find the first missing or incorrect bridge from the solution
	for solution_br in solution_bridges:
		var start_island = solution_br.start_island
		var end_island = solution_br.end_island
		var solution_count = solution_br.count
		
		# Check if this bridge exists in the current player's bridges
		var found_bridge = null
		var current_count = 0
		
		for player_br in bridges:
			if (player_br.start_island == start_island and player_br.end_island == end_island) or \
			   (player_br.start_island == end_island and player_br.end_island == start_island):
				found_bridge = player_br
				current_count = player_br.count
				break
		
		# If bridge is missing or has wrong count, suggest it as a hint
		if not found_bridge or current_count != solution_count:
			hint_bridges.append({
				"start_island": start_island,
				"end_island": end_island,
				"start_pos": start_island.node.position,
				"end_pos": end_island.node.position,
				"count": solution_count
			})
			
			# Start the hint timer
			hint_visible = true
			hint_timer = 1.0  # 1 second
			
			if not found_bridge:
				print("💡 HINT: Add bridge from (%d,%d) to (%d,%d) with %d bridge(s)" % [
					start_island.pos.x - 1, start_island.pos.y - 1,
					end_island.pos.x - 1, end_island.pos.y - 1,
					solution_count
				])
			else:
				print("💡 HINT: Update bridge from (%d,%d) to (%d,%d) to have %d bridge(s) (currently has %d)" % [
					start_island.pos.x - 1, start_island.pos.y - 1,
					end_island.pos.x - 1, end_island.pos.y - 1,
					solution_count, current_count
				])
			return
	
	# If all bridges are correct, check for extra bridges that shouldn't be there
	for player_br in bridges:
		var found_in_solution = false
		for solution_br in solution_bridges:
			if (player_br.start_island == solution_br.start_island and player_br.end_island == solution_br.end_island) or \
			   (player_br.start_island == solution_br.end_island and player_br.end_island == solution_br.start_island):
				found_in_solution = true
				break
		
		if not found_in_solution:
			print("💡 HINT: Remove extra bridge from (%d,%d) to (%d,%d)" % [
				player_br.start_island.pos.x - 1, player_br.start_island.pos.y - 1,
				player_br.end_island.pos.x - 1, player_br.end_island.pos.y - 1
			])
			return
	
	print("✅ Puzzle appears to be correct! All bridges match the solution.")

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

# ==================== COMPATIBILITY METHODS ====================

func provide_ai_hint():
	if not solve_with_backtracking():
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
