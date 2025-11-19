extends Node2D

# Configuration for 7x7
@export var grid_size: Vector2i = Vector2i(8, 8) # 7x7 grid with border
@export var cell_size: int = 48
@export var puzzle_folder: String = "7x7"

# Audio
@onready var click: AudioStreamPlayer2D = $click

# Grid variables
var grid_offset := Vector2.ZERO

# Puzzle data
var puzzle_data := []
var bridges := []             # Player-built bridges
var hint_bridges := []        # Bridges shown as hints

# Interaction variables
var bridge_start_island = null
var temp_bridge_line = null

# Puzzle state
var current_puzzle_index := 1
var puzzle_solved := false

func _ready():
	randomize()
	_calculate_grid_offset()
	# Randomly pick a puzzle file from input-01.txt to input-05.txt
	current_puzzle_index = randi() % 5 + 1
	var file_path = "res://assets/input/%s/input-%02d.txt" % [puzzle_folder, current_puzzle_index]
	load_custom_puzzle(file_path)
	bridges.clear()
	hint_bridges.clear()
	puzzle_solved = false
	queue_redraw()

func _calculate_grid_offset():
	var window_size = Vector2(800, 650)
	var grid_pixel_size = Vector2(grid_size.x * cell_size, grid_size.y * cell_size)
	grid_offset = (window_size - grid_pixel_size) / 2

func _draw():
	_draw_grid()
	_draw_bridges()
	_draw_hint_bridges()
	if temp_bridge_line:
		draw_line(temp_bridge_line[0], temp_bridge_line[1], Color(0,0,0), 4)

func _draw_grid():
	# Draw horizontal lines with same thickness as other grids
	for y in range(1, grid_size.y ):
		draw_line(grid_offset + Vector2(0, y*cell_size),
				  grid_offset + Vector2(grid_size.x*cell_size, y*cell_size),
				  Color(0.7, 0.7, 0.7, 1.0), 2.0)  # Changed to 2.0 to match other grids
	
	# Draw vertical lines with same thickness as other grids
	for x in range(1, grid_size.x):
		draw_line(grid_offset + Vector2(x*cell_size, 0),
				  grid_offset + Vector2(x*cell_size, grid_size.y*cell_size),
				  Color(0.7, 0.7, 0.7, 1.0), 2.0)  # Changed to 2.0 to match other grids

func _draw_bridges():
	for br in bridges:
		_draw_bridge(br)

func _draw_hint_bridges():
	for br in hint_bridges:
		_draw_hint_bridge(br)

func _draw_bridge(br):
	var color = Color(0,0,0,)  # Default blue color
	if puzzle_solved:
		color = Color(0,0,0)  # Green for solved puzzle
	
	var width = 4
	var start_pos = br.start_island.node.position - global_position
	var end_pos = br.end_island.node.position - global_position

	if br.count == 2:
		if start_pos.x == end_pos.x: # vertical
			draw_line(start_pos + Vector2(-3,0), end_pos + Vector2(-3,0), color, width)
			draw_line(start_pos + Vector2(3,0), end_pos + Vector2(3,0), color, width)
		else: # horizontal
			draw_line(start_pos + Vector2(0,-3), end_pos + Vector2(0,-3), color, width)
			draw_line(start_pos + Vector2(0,3), end_pos + Vector2(0,3), color, width)
	else:
		draw_line(start_pos, end_pos, color, width)

func _draw_hint_bridge(br):
	var color = Color(1.0, 0.9, 0.1, 0.9)  # Bright yellow
	var width = 4
	var start_pos = br.start_island.node.position - global_position
	var end_pos = br.end_island.node.position - global_position

	if br.count == 2:
		if start_pos.x == end_pos.x: # vertical
			draw_line(start_pos + Vector2(-4,0), end_pos + Vector2(-4,0), color, width)
			draw_line(start_pos + Vector2(4,0), end_pos + Vector2(4,0), color, width)
		else: # horizontal
			draw_line(start_pos + Vector2(0,-4), end_pos + Vector2(0,-4), color, width)
			draw_line(start_pos + Vector2(0,4), end_pos + Vector2(0,4), color, width)
	else:
		draw_line(start_pos, end_pos, color, width)

# ==================== PUZZLE LOADING ====================

func load_custom_puzzle(file_path: String) -> void:
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
				continue  # Skip empty cells
			var pos = Vector2(x+1, y+1) # +1 for border offset
			var bridges_target = val
			var sprite = Sprite2D.new()
			sprite.position = grid_offset + pos * cell_size
			sprite.centered = true
			sprite.scale = Vector2(0.6, 0.6)
			var texture_path = "res://assets/islands/%d.png" % bridges_target
			if ResourceLoader.exists(texture_path):
				sprite.texture = load(texture_path)
			add_child(sprite)

			puzzle_data.append({
				"pos": pos,
				"node": sprite,
				"bridges_target": bridges_target,
				"connected_bridges": 0,
				"neighbors": []
			})

	_calculate_neighbors()
	queue_redraw()
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

# ==================== PLAYER INTERACTION ====================

func _input(event):
	if event is InputEventMouseButton:
		if event.pressed:
			var clicked = _get_island_at_pos(event.position)
			if clicked:
				bridge_start_island = clicked
				temp_bridge_line = [clicked.node.position, clicked.node.position]
				queue_redraw()
			else:
				# Click empty space: maybe remove bridge
				var br = _get_bridge_at_pos(event.position)
				if br:
					_remove_bridge(br)
					queue_redraw()
		else:
			if bridge_start_island and temp_bridge_line:
				var end_island = _get_island_at_pos(event.position)
				if end_island and end_island != bridge_start_island:
					_try_place_bridge(bridge_start_island, end_island)
				bridge_start_island = null
				temp_bridge_line = null
				queue_redraw()
	elif event is InputEventMouseMotion:
		if bridge_start_island:
			temp_bridge_line = [bridge_start_island.node.position, event.position]
			queue_redraw()

func _get_island_at_pos(pos: Vector2):
	for isl in puzzle_data:
		if pos.distance_to(isl.node.position) < cell_size * 0.6:
			return isl
	return null

func _get_bridge_at_pos(pos: Vector2):
	for br in bridges:
		var start = br.start_island.node.position
		var end = br.end_island.node.position
		# Simple bounding box check
		var min_x = min(start.x,end.x) - 5
		var max_x = max(start.x,end.x) + 5
		var min_y = min(start.y,end.y) - 5
		var max_y = max(start.y,end.y) + 5
		if pos.x >= min_x and pos.x <= max_x and pos.y >= min_y and pos.y <= max_y:
			return br
	return null

func _remove_bridge(br):
	br.start_island.connected_bridges -= br.count
	br.end_island.connected_bridges -= br.count
	bridges.erase(br)
	_check_puzzle_completion()
	queue_redraw()

func _try_place_bridge(a, b):
	if a.pos.x != b.pos.x and a.pos.y != b.pos.y:
		return
	
	# Check if this bridge would intersect with existing bridges
	for br in bridges:
		if _bridges_cross(a.node.position, b.node.position, br.start_pos, br.end_pos):
			print("Cannot place bridge - would intersect with existing bridge")
			return
	
	for br in bridges:
		if (br.start_island == a and br.end_island == b) or (br.start_island == b and br.end_island == a):
			if br.count < 2:
				br.count += 1
				a.connected_bridges += 1
				b.connected_bridges += 1
				_check_puzzle_completion()
				return
			else:
				return
	
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

# ==================== PUZZLE COMPLETION ====================

func _check_puzzle_completion():
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
	
	queue_redraw()

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

func _bridges_cross(p1: Vector2, p2: Vector2, q1: Vector2, q2: Vector2) -> bool:
	if p1.x == p2.x and q1.y == q2.y:
		return (p1.x > min(q1.x,q2.x) and p1.x < max(q1.x,q2.x)) and (q1.y > min(p1.y,p2.y) and q1.y < max(p1.y,p2.y))
	if p1.y == p2.y and q1.x == q2.x:
		return (p1.y > min(q1.y,q2.y) and p1.y < max(q1.y,q2.y)) and (q1.x > min(p1.x,p2.x) and q1.x < max(p1.x,p2.x))
	return false

# ==================== HINT SYSTEM ====================

func _generate_enhanced_hint():
	hint_bridges.clear()
	
	# Find islands that need more bridges
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
	
	# Sort by most needed bridges first
	islands_needing_bridges.sort_custom(_sort_by_need)
	
	# Try to find the best hint
	for island_data in islands_needing_bridges:
		var island = island_data["island"]
		var needed = island_data["needed"]
		
		for neighbor in island.neighbors:
			var neighbor_needed = neighbor.bridges_target - neighbor.connected_bridges
			if neighbor_needed > 0:
				# Check if bridge already exists
				var bridge_exists = false
				var existing_bridge_count = 0
				for br in bridges:
					if (br.start_island == island and br.end_island == neighbor) or (br.start_island == neighbor and br.end_island == island):
						bridge_exists = true
						existing_bridge_count = br.count
						break
				
				# Check if this bridge would intersect with existing bridges
				var would_intersect = false
				if not bridge_exists:
					for br in bridges:
						if _bridges_cross(island.node.position, neighbor.node.position, br.start_pos, br.end_pos):
							would_intersect = true
							break
				
				if would_intersect:
					continue
				
				# Calculate optimal bridge count for hint
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

# ==================== SOLUTION LOADING ====================

func _load_solution_robust(file_path: String):
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		print("Failed to open solution file: ", file_path)
		return
	
	# Clear existing bridges
	bridges.clear()
	# Reset connected bridges count
	for isl in puzzle_data:
		isl.connected_bridges = 0
	
	# Read the solution file
	var solution_grid = []
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line.is_empty():
			continue
		solution_grid.append(line)
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

func _parse_horizontal_bridges_complete(row: String, y: int, island_map: Dictionary):
	var x = 0
	while x < row.length():
		var cell = row[x]
		
		if cell == "-" or cell == "=":
			var bridge_start_x = x
			var bridge_count = 2 if cell == "=" else 1
			
			var bridge_end_x = bridge_start_x
			while bridge_end_x < row.length() and (row[bridge_end_x] == "-" or row[bridge_end_x] == "="):
				bridge_end_x += 1
			
			var left_island = _find_island_horizontal(bridge_start_x - 1, y, -1, row, island_map)
			var right_island = _find_island_horizontal(bridge_end_x, y, 1, row, island_map)
			
			if left_island and right_island:
				_add_solution_bridge(left_island, right_island, bridge_count)
			
			x = bridge_end_x
		else:
			x += 1

func _find_island_horizontal(start_x: int, y: int, direction: int, row: String, island_map: Dictionary):
	var x = start_x
	while x >= 0 and x < row.length():
		var cell = row[x]
		
		if cell >= "1" and cell <= "9":
			var key = Vector2(x, y)
			if island_map.has(key):
				return island_map[key]
		
		if cell != " " and cell != "-" and cell != "=" and cell != "|":
			break
		
		x += direction
	
	return null

func _parse_vertical_bridges_complete(x: int, grid: Array, island_map: Dictionary):
	var y = 0
	while y < grid.size():
		if x < grid[y].length():
			var cell = grid[y][x]
			
			if cell == "|":
				var bridge_start_y = y
				var bridge_end_y = bridge_start_y
				
				while bridge_end_y < grid.size() and x < grid[bridge_end_y].length() and grid[bridge_end_y][x] == "|":
					bridge_end_y += 1
				
				var top_island = _find_island_vertical(x, bridge_start_y - 1, -1, grid, island_map)
				var bottom_island = _find_island_vertical(x, bridge_end_y, 1, grid, island_map)
				
				if top_island and bottom_island:
					_add_solution_bridge(top_island, bottom_island, 1)
				
				y = bridge_end_y
			else:
				y += 1
		else:
			y += 1

func _find_island_vertical(x: int, start_y: int, direction: int, grid: Array, island_map: Dictionary):
	var y = start_y
	while y >= 0 and y < grid.size():
		if x < grid[y].length():
			var cell = grid[y][x]
			
			if cell >= "1" and cell <= "9":
				var key = Vector2(x, y)
				if island_map.has(key):
					return island_map[key]
			
			if cell != " " and cell != "|" and cell != "-" and cell != "=":
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

# ==================== UI CONTROL FUNCTIONS ====================

func _on_backbutton_pressed() -> void:
	click.play()
	await get_tree().create_timer(0.1).timeout
	get_tree().change_scene_to_file("res://scenes/choose_grid_size.tscn")

func _on_hintbutton_pressed() -> void:
	if puzzle_solved:
		print("Puzzle already solved! No hints needed.")
		return
	
	click.play()
	_generate_enhanced_hint()
	queue_redraw()

func _on_texture_button_pressed() -> void:
	if puzzle_solved:
		print("Puzzle already solved!")
		return
	
	click.play()
	bridges.clear()
	hint_bridges.clear()
	# Load solution from corresponding output file
	var output_file = "res://assets/output/%s/output-%02d.txt" % [puzzle_folder, current_puzzle_index]
	_load_solution_robust(output_file)
	_check_puzzle_completion()
	queue_redraw()
