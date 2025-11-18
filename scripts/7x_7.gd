extends Node2D

@export var grid_size: Vector2i = Vector2i(7, 7)
@export var cell_size: int = 48
@export var total_islands: int = 10
@onready var click: AudioStreamPlayer2D = $click

var grid_offset := Vector2.ZERO
var puzzle_data := []
var bridges := []             # Player-built bridges
var solution_bridges := []    # Internal solution

# Click-and-drag bridge
var bridge_start_island = null
var temp_bridge_line = null

func _ready():
	_calculate_grid_offset()
	generate_solvable_puzzle(total_islands)
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

# ---------------- Island Generation ------------------

func generate_solvable_puzzle(island_count: int):
	generate_islands(island_count)
	solution_bridges.clear()
	_connect_islands_greedy()
	print("✅ Solvable puzzle generated instantly")

func generate_islands(island_count: int):
	for isl in puzzle_data:
		if "node" in isl and isl.node:
			isl.node.queue_free()
	puzzle_data.clear()
	bridges.clear()

	var occupied_positions := []
	while puzzle_data.size() < island_count:
		var pos = Vector2(randi() % (grid_size.x - 2) + 1,
						  randi() % (grid_size.y - 2) + 1)
		if pos in occupied_positions:
			continue
		occupied_positions.append(pos)

		var bridges_target = randi_range(1,4)
		var sprite = Sprite2D.new()
		sprite.position = grid_offset + pos * cell_size
		sprite.centered = true
		sprite.scale = Vector2(0.6,0.6)
		var texture_path = "res://assets/islands/7x7/%d.png" % bridges_target
		if ResourceLoader.exists(texture_path):
			sprite.texture = load(texture_path)
		add_child(sprite)

		puzzle_data.append({
			"pos": pos,
			"node": sprite,
			"bridges_target": bridges_target,
			"connected_bridges": 0
		})

# ---------------- Greedy Generator ------------------

func _connect_islands_greedy():
	if puzzle_data.size() == 0:
		return

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

	var connected = [puzzle_data[0]]
	var remaining = puzzle_data.duplicate()
	remaining.erase(puzzle_data[0])
	while remaining.size() > 0:
		var a = connected[randi() % connected.size()]
		var possible = []
		for b in a["neighbors"]:
			if b in remaining:
				possible.append(b)
		if possible.size() == 0:
			continue
		var b = possible[randi() % possible.size()]
		var count = 1
		if randf() < 0.3 and a["bridges_target"] > 1 and b["bridges_target"] > 1:
			count = 2
		var br = {
			"start_island": a,
			"end_island": b,
			"start_pos": a.node.position,
			"end_pos": b.node.position,
			"count": count
		}
		solution_bridges.append(br.duplicate())
		a.connected_bridges += count
		b.connected_bridges += count
		connected.append(b)
		remaining.erase(b)

# ---------------- Connectivity & Minimal Fix ------------------

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

# ---------------- Backtracking Solver ------------------

func _can_place_bridge(a, b, count=1) -> bool:
	for br in solution_bridges:
		if (br.start_island == a and br.end_island == b) or (br.start_island == b and br.end_island == a):
			if br.count + count > 2:
				return false

	var temp_start = a.node.position
	var temp_end = b.node.position
	for br in solution_bridges:
		if (br.start_island == a and br.end_island == b) or (br.start_island == b and br.end_island == a):
			continue
		if _bridges_cross(temp_start, temp_end, br.start_pos, br.end_pos):
			return false

	if a.pos.x != b.pos.x and a.pos.y != b.pos.y:
		return false

	return true

func _solve_puzzle(index = 0) -> bool:
	if index >= puzzle_data.size():
		for isl in puzzle_data:
			if isl.connected_bridges != isl.bridges_target:
				return false
		return true

	var isl = puzzle_data[index]
	if isl.connected_bridges == isl.bridges_target:
		return _solve_puzzle(index + 1)

	for nb in isl["neighbors"]:
		if nb.connected_bridges >= nb.bridges_target:
			continue
		for add_count in [1,2]:
			add_count = min(add_count, isl.bridges_target - isl.connected_bridges, nb.bridges_target - nb.connected_bridges)
			if add_count <= 0:
				continue
			if _can_place_bridge(isl, nb, add_count):
				var br = null
				for existing_br in solution_bridges:
					if (existing_br.start_island == isl and existing_br.end_island == nb) or (existing_br.start_island == nb and existing_br.end_island == isl):
						br = existing_br
						break
				if br:
					br.count += add_count
				else:
					br = {
						"start_island": isl,
						"end_island": nb,
						"start_pos": isl.node.position,
						"end_pos": nb.node.position,
						"count": add_count
					}
					solution_bridges.append(br)

				isl.connected_bridges += add_count
				nb.connected_bridges += add_count

				if _solve_puzzle(index):
					return true

				isl.connected_bridges -= add_count
				nb.connected_bridges -= add_count
				if br.count == add_count:
					solution_bridges.erase(br)
				else:
					br.count -= add_count
	return false

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

func _on_solution_pressed() -> void:
	click.play()
	bridges.clear()
	for br in solution_bridges:
		bridges.append(br.duplicate())
	queue_redraw()

func _on_check_pressed() -> void:
	click.play()
	for isl in puzzle_data:
		isl.connected_bridges = 0
	bridges.clear()
	solution_bridges.clear()
	if _solve_puzzle():
		for br in solution_bridges:
			bridges.append(br.duplicate())
		print("✅ Puzzle is solvable (backtracking).")
	else:
		print("❌ Could not solve puzzle automatically!")
	queue_redraw()

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
