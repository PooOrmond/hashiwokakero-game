# automated_solvable_puzzle_maker.gd
class_name AutomatedPuzzleMaker
extends RefCounted

var grid_size: Vector2i
var cell_size: int
var rng: RandomNumberGenerator

const GRID_PARAMS = {
	Vector2i(8, 8): {
		"grid_spacing": 2,
		"min_islands": 5,
		"max_islands": 9,
		"max_bridge_value": 4,
		"max_bridges_per_island": 4
	},
	Vector2i(10, 10): {
		"grid_spacing": 2,
		"min_islands": 12,
		"max_islands": 15,
		"max_bridge_value": 6,
		"max_bridges_per_island": 6
	},
	Vector2i(14, 14): {
		"grid_spacing": 2,
		"min_islands": 26,
		"max_islands": 29,
		"max_bridge_value": 8,
		"max_bridges_per_island": 8
	}
}

func _init():
	rng = RandomNumberGenerator.new()
	rng.randomize()

func generate_puzzle(target_grid_size: Vector2i, target_cell_size: int) -> Array:
	grid_size = target_grid_size
	cell_size = target_cell_size
	
	var params = GRID_PARAMS.get(grid_size, GRID_PARAMS[Vector2i(8, 8)])
	
	var puzzle_grid = _create_guaranteed_solvable_puzzle(params)
	
	if puzzle_grid != null and not puzzle_grid.is_empty():
		return puzzle_grid
	
	return _create_empty_grid()

func _create_guaranteed_solvable_puzzle(params: Dictionary) -> Array:	
	var islands = _create_centered_grid_islands(params)
	if islands.size() < params.min_islands:
		return []
	
	for island in islands:
		island.bridges = {
			"up": 0,
			"down": 0,
			"left": 0,
			"right": 0
		}
	
	var bridges = _generate_solution_bridges(islands, params)
	if bridges.is_empty() and islands.size() > 1:
		return []
	
	var island_numbers = _calculate_island_numbers(islands)
	var grid = _create_empty_grid()
	
	for island in islands:
		var number = island_numbers[island]
		var x = island.pos.x
		var y = island.pos.y
		if x >= 0 and x < grid_size.x and y >= 0 and y < grid_size.y:
			grid[y][x] = number
	
	if not _verify_puzzle_grid(grid, params):
		return []
	
	return grid

func _create_centered_grid_islands(params: Dictionary) -> Array:
	var islands = []
	
	var min_pos = 1
	var max_pos_x = grid_size.x - 2
	var max_pos_y = grid_size.y - 2
	
	var grid_spacing = params.grid_spacing
	
	var grid_width = int(ceil(float(max_pos_x - min_pos) / grid_spacing)) + 1
	var grid_height = int(ceil(float(max_pos_y - min_pos) / grid_spacing)) + 1
	
	if grid_width < 3:
		grid_width = 3
	if grid_height < 3:
		grid_height = 3
	
	var total_width = (grid_width - 1) * grid_spacing
	var total_height = (grid_height - 1) * grid_spacing
	
	var start_x_f = float(min_pos) + float(max_pos_x - min_pos - total_width) / 2.0
	var start_y_f = float(min_pos) + float(max_pos_y - min_pos - total_height) / 2.0
	
	var start_x = int(start_x_f)
	var start_y = int(start_y_f)
	
	start_x = start_x - (start_x % grid_spacing)
	start_y = start_y - (start_y % grid_spacing)
	
	if start_x < min_pos:
		start_x = min_pos
	if start_y < min_pos:
		start_y = min_pos
	if start_x + total_width > max_pos_x:
		start_x = max_pos_x - total_width
	if start_y + total_height > max_pos_y:
		start_y = max_pos_y - total_height
	
	var all_grid_points = []
	for gy in range(grid_height):
		for gx in range(grid_width):
			var x = start_x + gx * grid_spacing
			var y = start_y + gy * grid_spacing
			if x >= min_pos and x <= max_pos_x and y >= min_pos and y <= max_pos_y:
				all_grid_points.append(Vector2i(x, y))
	
	var target_islands = rng.randi_range(params.min_islands, params.max_islands)
	target_islands = min(target_islands, all_grid_points.size())
	
	var strategic_points = _get_centered_strategic_points(grid_spacing, start_x, start_y, grid_width, grid_height)
	
	var grid_points_set = {}
	for point in all_grid_points:
		var key = str(point.x) + "," + str(point.y)
		grid_points_set[key] = point
	
	for point in strategic_points:
		var key = str(point.x) + "," + str(point.y)
		if grid_points_set.has(key):
			islands.append({
				"pos": point,
				"bridges": null,
				"index": islands.size()
			})
			var index_to_remove = all_grid_points.find(point)
			if index_to_remove != -1:
				all_grid_points.remove_at(index_to_remove)
			grid_points_set.erase(key)
	
	while islands.size() < target_islands and not all_grid_points.is_empty():
		var random_index = rng.randi_range(0, all_grid_points.size() - 1)
		var pos = all_grid_points[random_index]
		
		islands.append({
			"pos": pos,
			"bridges": null,
			"index": islands.size()
		})
		
		all_grid_points.remove_at(random_index)
	
	return islands

func _get_centered_strategic_points(
	grid_spacing: int,
	start_x: int,
	start_y: int,
	grid_width: int,
	grid_height: int
) -> Array:
	var points = []
	
	var min_pos = 1
	var max_x = grid_size.x - 2
	var max_y = grid_size.y - 2
	
	var candidates = [
		Vector2i(start_x, start_y),
		Vector2i(start_x + (grid_width - 1) * grid_spacing, start_y),
		Vector2i(start_x, start_y + (grid_height - 1) * grid_spacing),
		Vector2i(start_x + (grid_width - 1) * grid_spacing,
			   start_y + (grid_height - 1) * grid_spacing)
	]
	
	for p in candidates:
		if p.x >= min_pos and p.x <= max_x and p.y >= min_pos and p.y <= max_y:
			if p not in points:
				points.append(p)
	
	if grid_width >= 3 and grid_height >= 3:
		var center_grid_x = grid_width / 2
		var center_grid_y = grid_height / 2
		
		var cx = start_x + center_grid_x * grid_spacing
		var cy = start_y + center_grid_y * grid_spacing
		
		var center = Vector2i(cx, cy)
		if center.x >= min_pos and center.x <= max_x and center.y >= min_pos and center.y <= max_y:
			if center not in points:
				points.append(center)
				
				if grid_width >= 5 and grid_height >= 5:
					var around_center = [
						Vector2i(cx - grid_spacing, cy),
						Vector2i(cx + grid_spacing, cy),
						Vector2i(cx, cy - grid_spacing),
						Vector2i(cx, cy + grid_spacing)
					]
					
					for point in around_center:
						if point.x >= min_pos and point.x <= max_x and point.y >= min_pos and point.y <= max_y:
							if point not in points:
								points.append(point)
	
	return points

func _generate_solution_bridges(islands: Array, params: Dictionary) -> Array:
	var bridges := []
	
	if islands.size() < 2:
		return bridges
	
	var connected := [islands[0]]
	var remaining = islands.duplicate()
	remaining.erase(islands[0])
	
	while not remaining.is_empty():
		var connected_island = connected[rng.randi_range(0, connected.size() - 1)]
		var unconnected_island = remaining[rng.randi_range(0, remaining.size() - 1)]
		
		if not _can_connect_directly(connected_island, unconnected_island, islands):
			continue
		
		var dir = _get_direction(connected_island.pos, unconnected_island.pos)
		if dir == "":
			continue
		
		if not _can_add_bridge(connected_island, unconnected_island, dir, 1, params):
			continue
		
		var max_possible = min(2 - connected_island.bridges[dir], 2 - unconnected_island.bridges[_opposite_dir(dir)])
		var count = 1
		if max_possible >= 2 and rng.randf() < 0.3:
			count = 2
		
		var connected_total = connected_island.bridges["up"] + connected_island.bridges["down"] + connected_island.bridges["left"] + connected_island.bridges["right"]
		var unconnected_total = unconnected_island.bridges["up"] + unconnected_island.bridges["down"] + unconnected_island.bridges["left"] + unconnected_island.bridges["right"]
		
		if connected_total + count > params.max_bridge_value:
			count = min(count, params.max_bridge_value - connected_total)
		if unconnected_total + count > params.max_bridge_value:
			count = min(count, params.max_bridge_value - unconnected_total)
		
		if count <= 0:
			continue
		
		connected_island.bridges[dir] += count
		unconnected_island.bridges[_opposite_dir(dir)] += count
		
		bridges.append({
			"from": connected_island,
			"to": unconnected_island,
			"direction": dir,
			"count": count
		})
		
		connected.append(unconnected_island)
		remaining.erase(unconnected_island)
	
	var extra_bridge_attempts = islands.size() * 4
	var added_extra = 0
	
	for attempt in range(extra_bridge_attempts):
		if added_extra >= islands.size() * 2:
			break
		
		var idx1 = rng.randi_range(0, islands.size() - 1)
		var idx2 = rng.randi_range(0, islands.size() - 1)
		
		if idx1 == idx2:
			continue
		
		var island1 = islands[idx1]
		var island2 = islands[idx2]
		
		if not _can_connect_directly(island1, island2, islands):
			continue
		
		var dir = _get_direction(island1.pos, island2.pos)
		if dir == "":
			continue
		
		var already_connected = false
		for bridge in bridges:
			if (bridge.from == island1 and bridge.to == island2) or (bridge.from == island2 and bridge.to == island1):
				already_connected = true
				break
		
		if already_connected:
			continue
		
		if not _can_add_bridge(island1, island2, dir, 1, params):
			continue
		
		var max_possible = min(2 - island1.bridges[dir], 2 - island2.bridges[_opposite_dir(dir)])
		var count = 1
		if max_possible >= 2 and rng.randf() < 0.4:
			count = 2
		
		var island1_total = island1.bridges["up"] + island1.bridges["down"] + island1.bridges["left"] + island1.bridges["right"]
		var island2_total = island2.bridges["up"] + island2.bridges["down"] + island2.bridges["left"] + island2.bridges["right"]
		
		if island1_total + count > params.max_bridge_value:
			count = min(count, params.max_bridge_value - island1_total)
		if island2_total + count > params.max_bridge_value:
			count = min(count, params.max_bridge_value - island2_total)
		
		if count <= 0:
			continue
		
		island1.bridges[dir] += count
		island2.bridges[_opposite_dir(dir)] += count
		
		bridges.append({
			"from": island1,
			"to": island2,
			"direction": dir,
			"count": count
		})
		
		added_extra += 1
	
	return bridges

func _calculate_island_numbers(islands: Array) -> Dictionary:
	var island_numbers = {}
	
	for island in islands:
		var total = 0
		total += island.bridges["up"]
		total += island.bridges["down"]
		total += island.bridges["left"]
		total += island.bridges["right"]
		
		island_numbers[island] = total
	
	return island_numbers

func _verify_puzzle_grid(grid: Array, params: Dictionary) -> bool:
	var island_count = 0
	var max_number = 0
	
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var val = grid[y][x]
			if val > 0:
				island_count += 1
				max_number = max(max_number, val)
				
				if val < 1 or val > params.max_bridge_value:
					return false
	
	if island_count < params.min_islands:
		return false
	
	if max_number > params.max_bridge_value:
		return false
	
	return true

func _get_direction(a: Vector2i, b: Vector2i) -> String:
	if a.x == b.x:
		return "down" if b.y > a.y else "up"
	if a.y == b.y:
		return "right" if b.x > a.x else "left"
	return ""

func _opposite_dir(dir: String) -> String:
	match dir:
		"up": return "down"
		"down": return "up"
		"left": return "right"
		"right": return "left"
		_: return ""

func _can_add_bridge(a, b, dir: String, count: int = 1, params: Dictionary = {}) -> bool:
	if dir == "":
		return false
	
	if a.bridges[dir] + count > 2:
		return false
	
	var opposite = _opposite_dir(dir)
	if b.bridges[opposite] + count > 2:
		return false
	
	if not params.is_empty():
		var a_total = a.bridges["up"] + a.bridges["down"] + a.bridges["left"] + a.bridges["right"]
		var b_total = b.bridges["up"] + b.bridges["down"] + b.bridges["left"] + b.bridges["right"]
		
		if a_total + count > params.max_bridge_value:
			return false
		if b_total + count > params.max_bridge_value:
			return false
	
	return true

func _can_connect_directly(a, b, all_islands: Array) -> bool:
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

func _create_empty_grid() -> Array:
	var grid = []
	for y in range(grid_size.y):
		var row = []
		row.resize(grid_size.x)
		row.fill(0)
		grid.append(row)
	return grid

func load_generated_puzzle(puzzle_grid: Array, parent_node: Node, grid_offset: Vector2) -> Array:
	var puzzle_data = []
	
	for y in range(puzzle_grid.size()):
		var row = puzzle_grid[y]
		for x in range(row.size()):
			var val = row[x]
			if val == 0:
				continue
				
			var pos = Vector2(x, y)
			var bridges_target = val
			
			var sprite = Sprite2D.new()
			sprite.position = grid_offset + pos * cell_size
			sprite.centered = true
			
			if grid_size.x <= 8:
				sprite.scale = Vector2(0.6, 0.6)
			elif grid_size.x <= 10:
				sprite.scale = Vector2(0.5, 0.5)
			else:
				sprite.scale = Vector2(0.4, 0.4)
			
			var texture_path = "res://assets/islands/%d.png" % bridges_target
			if ResourceLoader.exists(texture_path):
				sprite.texture = load(texture_path)
			else:
				var circle_texture = _create_circle_texture()
				sprite.texture = circle_texture
			
			parent_node.add_child(sprite)
			
			puzzle_data.append({
				"pos": pos,
				"node": sprite,
				"bridges_target": bridges_target,
				"connected_bridges": 0,
				"neighbors": []
			})
	
	return puzzle_data

func _create_circle_texture() -> ImageTexture:
	var image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.2, 0.4, 0.8))
	
	var center = Vector2(32, 32)
	var radius = 28
	
	for y in range(64):
		for x in range(64):
			var pos = Vector2(x, y)
			if pos.distance_to(center) <= radius:
				var dist = pos.distance_to(center) / radius
				var color = Color(1.0 - dist * 0.5, 1.0 - dist * 0.3, 1.0 - dist * 0.1)
				image.set_pixel(x, y, color)
	
	return ImageTexture.create_from_image(image)

func debug_island_placement(grid: Array):
	var island_positions = []
	for y in range(grid_size.y):
		var row = []
		for x in range(grid_size.x):
			var val = grid[y][x]
			row.append("X" if val > 0 else ".")
			if val > 0:
				island_positions.append(Vector2i(x, y))
	
	var y_counts = {}
	for pos in island_positions:
		y_counts[pos.y] = y_counts.get(pos.y, 0) + 1
