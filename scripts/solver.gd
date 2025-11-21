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

# Solving statistics
var solving_iterations := 0
var max_depth := 0

# Hint system
var current_puzzle_index := 1
var puzzle_folder: String = ""
var hints_used := 0
var max_hints_to_use := 0

# Initialize method
func initialize(grid_size_param: Vector2i, cell_size_param: int, grid_offset_param: Vector2) -> void:
	grid_size = grid_size_param
	cell_size = cell_size_param
	grid_offset = grid_offset_param

# Set puzzle info for hint system
func set_puzzle_info(folder: String, index: int):
	puzzle_folder = folder
	current_puzzle_index = index

# ==================== PUZZLE LOADING ====================

func load_custom_puzzle(file_path: String, parent_node: Node) -> void:
	# Clear current puzzle
	for isl in puzzle_data:
		if "node" in isl and isl.node:
			isl.node.queue_free()
	puzzle_data.clear()
	bridges.clear()
	hint_bridges.clear()
	puzzle_solved = false

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
			var char = line[i]
			if char != " ":
				continuous_line += char
		solution_grid.append(continuous_line)
		print("📝 Line %d: '%s' -> '%s'" % [solution_grid.size() - 1, line, continuous_line])
	
	file.close()
	
	print("📊 Solution grid size: %d lines" % solution_grid.size())
	
	# Create a map of all puzzle islands by their grid position
	var island_map = {}
	for island in puzzle_data:
		var key = Vector2(island.pos.x - 1, island.pos.y - 1)  # Convert to 0-based
		island_map[key] = island
		print("🗺️ Island at (%d, %d) needs %d bridges" % [key.x, key.y, island.bridges_target])
	
	# Parse ALL horizontal bridges
	print("🔍 Parsing horizontal bridges...")
	for y in range(solution_grid.size()):
		var row = solution_grid[y]
		_parse_horizontal_bridges_complete(row, y, island_map)
	
	# Parse ALL vertical bridges  
	print("🔍 Parsing vertical bridges...")
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
				print("🌉 Horizontal bridge: (%d,%d) -> (%d,%d) with %d bridges" % [
					left_island.pos.x-1, left_island.pos.y-1,
					right_island.pos.x-1, right_island.pos.y-1,
					bridge_count
				])
				_add_solution_bridge(left_island, right_island, bridge_count)
			else:
				if not left_island:
					print("❌ Could not find left island for horizontal bridge at (%d,%d)" % [bridge_start_x - 1, y])
				if not right_island:
					print("❌ Could not find right island for horizontal bridge at (%d,%d)" % [bridge_end_x, y])
			
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
					print("🌉 Vertical bridge: (%d,%d) -> (%d,%d) with %d bridges" % [
						top_island.pos.x-1, top_island.pos.y-1,
						bottom_island.pos.x-1, bottom_island.pos.y-1,
						bridge_count
					])
					_add_solution_bridge(top_island, bottom_island, bridge_count)
				else:
					if not top_island:
						print("❌ Could not find top island for vertical bridge at (%d,%d)" % [x, bridge_start_y - 1])
					if not bottom_island:
						print("❌ Could not find bottom island for vertical bridge at (%d,%d)" % [x, bridge_end_y])
				
				y = bridge_end_y
			else:
				y += 1
		else:
			y += 1

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

func _add_solution_bridge(a, b, count: int):
	# Check if bridge already exists
	for br in bridges:
		if (br.start_island == a and br.end_island == b) or (br.start_island == b and br.end_island == a):
			var old_count = br.count
			br.count = count
			a.connected_bridges += (count - old_count)
			b.connected_bridges += (count - old_count)
			print("📝 Updated existing bridge: %d,%d -> %d,%d (now %d bridges)" % [
				a.pos.x-1, a.pos.y-1, b.pos.x-1, b.pos.y-1, count
			])
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
	print("📝 Created new bridge: %d,%d -> %d,%d (%d bridges)" % [
		a.pos.x-1, a.pos.y-1, b.pos.x-1, b.pos.y-1, count
	])

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
		else:
			print("✅ Island at (%d,%d) has correct number of bridges: %d" % [
				island.pos.x-1, island.pos.y-1, island.connected_bridges
			])
	
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
			var char = line[i]
			if char != " ":
				continuous_line += char
		solution_grid.append(continuous_line)
		print("📝 Line %d: '%s' -> '%s'" % [solution_grid.size() - 1, line, continuous_line])
	
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

# ==================== INTERACTION FUNCTIONS (for main game) ====================

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
			print("Cannot place bridge - would intersect with existing bridge")
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
	Generate hints for the player
	"""
	hint_bridges.clear()
	
	var islands_needing_bridges = []
	for island in puzzle_data:
		var needed_bridges = island.bridges_target - island.connected_bridges
		if needed_bridges > 0:
			islands_needing_bridges.append({
				"island": island,
				"needed": needed_bridges
			})
	
	if islands_needing_bridges.is_empty():
		print("✅ All islands have enough bridges!")
		return
	
	islands_needing_bridges.sort_custom(_sort_by_need)
	
	for island_data in islands_needing_bridges:
		var island = island_data["island"]
		var _needed = island_data["needed"]
		
		for neighbor in island.neighbors:
			var neighbor_needed = neighbor.bridges_target - neighbor.connected_bridges
			if neighbor_needed > 0:
				var bridge_exists = false
				var existing_bridge_count = 0
				for br in bridges:
					if (br.start_island == island and br.end_island == neighbor) or (br.start_island == neighbor and br.end_island == island):
						bridge_exists = true
						existing_bridge_count = br.count
						break
				
				var would_intersect = false
				if not bridge_exists:
					for br in bridges:
						if _bridges_cross(island.node.position, neighbor.node.position, br.start_pos, br.end_pos):
							would_intersect = true
							break
				
				if would_intersect:
					continue
				
				var optimal_count = _calculate_optimal_bridge_count(island, neighbor, bridge_exists, existing_bridge_count)
				
				if optimal_count > 0:
					hint_bridges.append({
						"start_island": island,
						"end_island": neighbor,
						"start_pos": island.node.position,
						"end_pos": neighbor.node.position,
						"count": optimal_count
					})
					
					if optimal_count == 2:
						print("💡 DOUBLE BRIDGE HINT: Connect (%d,%d) to (%d,%d) with 2 bridges" % [
							island.pos.x - 1, island.pos.y - 1,
							neighbor.pos.x - 1, neighbor.pos.y - 1
						])
					else:
						print("💡 HINT: Connect (%d,%d) to (%d,%d)" % [
							island.pos.x - 1, island.pos.y - 1,
							neighbor.pos.x - 1, neighbor.pos.y - 1
						])
					return
	
	print("No hints available - try exploring different connections")

func _sort_by_need(a, b):
	return a["needed"] > b["needed"]

func _calculate_optimal_bridge_count(island, neighbor, bridge_exists: bool, existing_count: int) -> int:
	var island_needed = island.bridges_target - island.connected_bridges
	var neighbor_needed = neighbor.bridges_target - neighbor.connected_bridges
	
	if not bridge_exists and island_needed >= 2 and neighbor_needed >= 2:
		return 2
	
	if bridge_exists and existing_count == 1 and island_needed >= 1 and neighbor_needed >= 1:
		return 2
	
	if not bridge_exists:
		return 1
	
	return 0

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
	Check if puzzle is solved (for manual play)
	"""
	var all_correct = true
	for island in puzzle_data:
		if island.connected_bridges != island.bridges_target:
			all_correct = false
			break
	
	if all_correct and _is_puzzle_solvable():
		puzzle_solved = true
		print("🎉 PUZZLE SOLVED! Congratulations!")
	else:
		puzzle_solved = false

func _is_puzzle_solvable() -> bool:
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
