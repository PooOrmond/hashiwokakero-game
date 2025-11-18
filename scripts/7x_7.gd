extends Node2D

@export var grid_size: Vector2i = Vector2i(8, 8) # 9x9 grid with border
@export var cell_size: int = 48
@export var total_islands: int = 10
@onready var click: AudioStreamPlayer2D = $click

var grid_offset := Vector2.ZERO
var puzzle_data := []
var bridges := []             # Player-built bridges
var solution_bridges := []    # Internal solution
var bridge_start_island = null
var temp_bridge_line = null
var current_puzzle_index := 1

func _ready():
	randomize()
	_calculate_grid_offset()
	# Randomly pick a puzzle file from input-01.txt to input-05.txt
	current_puzzle_index = randi() % 5 + 1
	var file_path = "res://assets/input/7x7/input-%02d.txt" % current_puzzle_index
	load_custom_puzzle(file_path)
	bridges.clear()
	queue_redraw()

func _calculate_grid_offset():
	var window_size = Vector2(800, 650)
	var grid_pixel_size = Vector2(grid_size.x * cell_size, grid_size.y * cell_size)
	grid_offset = (window_size - grid_pixel_size) / 2

func _draw():
	_draw_grid()
	_draw_bridges()
	if temp_bridge_line:
		draw_line(temp_bridge_line[0], temp_bridge_line[1], Color(0.2,0.8,0.2), 4)

func _draw_grid():
	for y in range(grid_size.y + 1):
		draw_line(grid_offset + Vector2(0, y*cell_size),
				  grid_offset + Vector2(grid_size.x*cell_size, y*cell_size),
				  Color(0,0,0), 1)
	for x in range(grid_size.x + 1):
		draw_line(grid_offset + Vector2(x*cell_size, 0),
				  grid_offset + Vector2(x*cell_size, grid_size.y*cell_size),
				  Color(0,0,0), 1)

func _draw_bridges():
	for br in bridges:
		_draw_bridge(br)

func _draw_bridge(br):
	var color = Color(0.2,0.2,0.8,1.0)
	var width = 3
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

# ---------------- Custom Puzzle Loader ------------------

func load_custom_puzzle(file_path: String) -> void:
	# Clear current puzzle
	for isl in puzzle_data:
		if "node" in isl and isl.node:
			isl.node.queue_free()
	puzzle_data.clear()
	bridges.clear()
	solution_bridges.clear()

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
			var texture_path = "res://assets/islands/7x7/%d.png" % bridges_target
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

# ---------------- Player Interaction ------------------

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

func _try_place_bridge(a, b):
	if a.pos.x != b.pos.x and a.pos.y != b.pos.y:
		return
	for br in bridges:
		if (br.start_island == a and br.end_island == b) or (br.start_island == b and br.end_island == a):
			if br.count < 2:
				br.count += 1
				a.connected_bridges += 1
				b.connected_bridges += 1
				return
			else:
				return
	for br in bridges:
		if _bridges_cross(a.node.position, b.node.position, br.start_pos, br.end_pos):
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

# ---------------- Solvability ------------------

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

func _on_check_pressed() -> void:
	click.play()
	if _is_puzzle_solvable():
		print("✅ Puzzle is already solvable!")
	else:
		print("⚠️ Puzzle is NOT solvable.")
	queue_redraw()

func _on_solution_pressed() -> void:
	click.play()
	bridges.clear()
	# Load solution from corresponding output file
	var output_file = "res://assets/output/7x7/output-%02d.txt" % current_puzzle_index
	_load_solution_from_file(output_file)
	queue_redraw()

func _load_solution_from_file(file_path: String):
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		print("Failed to open solution file: ", file_path)
		return
	
	# Clear existing bridges
	bridges.clear()
	# Reset connected bridges count
	for isl in puzzle_data:
		isl.connected_bridges = 0
	
	# Read and parse the solution
	var solution_grid = []
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line.is_empty():
			continue
		solution_grid.append(line)
	file.close()
	
	# Create a map of island positions for quick lookup
	var island_map = {}
	for isl in puzzle_data:
		var key = "%d,%d" % [isl.pos.x - 1, isl.pos.y - 1]  # Convert to 0-based coordinates
		island_map[key] = isl
	
	# Parse bridges by scanning the entire grid
	for y in range(solution_grid.size()):
		var row = solution_grid[y]
		for x in range(row.length()):
			var cell = row[x]
			
			# Check horizontal bridges to the right
			if x < row.length() - 1:
				var right_cell = row[x + 1]
				if right_cell == "-" or right_cell == "=":
					# Find the island to the left (current position or further left)
					var left_island = _find_nearest_island_left(x, y, solution_grid, island_map)
					# Find the island to the right (skip the bridge and find next island)
					var right_island = _find_nearest_island_right(x + 2, y, solution_grid, island_map)
					
					if left_island and right_island:
						var bridge_count = 2 if right_cell == "=" else 1
						_add_solution_bridge(left_island, right_island, bridge_count)
			
			# Check vertical bridges below
			if y < solution_grid.size() - 1:
				var below_cell = solution_grid[y + 1][x] if x < solution_grid[y + 1].length() else " "
				if below_cell == "|":
					# Find the island above (current position or further up)
					var top_island = _find_nearest_island_up(x, y, solution_grid, island_map)
					# Find the island below (skip the bridge and find next island)
					var bottom_island = _find_nearest_island_down(x, y + 2, solution_grid, island_map)
					
					if top_island and bottom_island:
						_add_solution_bridge(top_island, bottom_island, 1)

func _find_nearest_island_left(start_x: int, y: int, grid: Array, island_map: Dictionary) -> Variant:
	for x in range(start_x, -1, -1):
		var key = "%d,%d" % [x, y]
		if island_map.has(key):
			return island_map[key]
	return null

func _find_nearest_island_right(start_x: int, y: int, grid: Array, island_map: Dictionary) -> Variant:
	for x in range(start_x, grid[y].length()):
		var key = "%d,%d" % [x, y]
		if island_map.has(key):
			return island_map[key]
	return null

func _find_nearest_island_up(x: int, start_y: int, grid: Array, island_map: Dictionary) -> Variant:
	for y in range(start_y, -1, -1):
		if x >= grid[y].length():
			continue
		var key = "%d,%d" % [x, y]
		if island_map.has(key):
			return island_map[key]
	return null

func _find_nearest_island_down(x: int, start_y: int, grid: Array, island_map: Dictionary) -> Variant:
	for y in range(start_y, grid.size()):
		if x >= grid[y].length():
			continue
		var key = "%d,%d" % [x, y]
		if island_map.has(key):
			return island_map[key]
	return null

func _find_island_at_grid_pos(grid_x: int, grid_y: int):
	# Convert from solution grid coordinates to our internal coordinates
	# In the solution file, positions are 0-based without border
	var pos = Vector2(grid_x + 1, grid_y + 1) # +1 for border offset
	
	for isl in puzzle_data:
		if isl.pos == pos:
			return isl
	return null

func _add_solution_bridge(a, b, count: int):
	# Check if bridge already exists
	for br in bridges:
		if (br.start_island == a and br.end_island == b) or (br.start_island == b and br.end_island == a):
			# Update existing bridge count
			br.count = count
			a.connected_bridges = count
			b.connected_bridges = count
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
	
func _on_backbutton_pressed() -> void:
	click.play()
	await get_tree().create_timer(0.1).timeout
	get_tree().change_scene_to_file("res://scenes/choose_grid_size.tscn")

func _bridges_cross(p1: Vector2, p2: Vector2, q1: Vector2, q2: Vector2) -> bool:
	if p1.x == p2.x and q1.y == q2.y:
		return (p1.x > min(q1.x,q2.x) and p1.x < max(q1.x,q2.x)) and (q1.y > min(p1.y,p2.y) and q1.y < max(p1.y,p2.y))
	if p1.y == p2.y and q1.x == q2.x:
		return (p1.y > min(q1.y,q2.y) and p1.y < max(q1.y,q2.y)) and (q1.x > min(p1.x,p2.x) and q1.x < max(p1.x,p2.x))
	return false
