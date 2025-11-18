extends Node2D

@export var grid_size: Vector2i = Vector2i(7, 7)
@export var cell_size: int = 48
@export var total_islands: int = 10
@onready var click: AudioStreamPlayer2D = $click

var grid_offset := Vector2.ZERO
var puzzle_data := []
var bridges := []

# Click-and-drag bridge
var bridge_start_island = null
var temp_bridge_line = null

func _ready():
	_calculate_grid_offset()
	generate_puzzle(total_islands)
	queue_redraw()

func _calculate_grid_offset():
	var window_size = Vector2(800, 650)
	var grid_pixel_size = Vector2(grid_size.x * cell_size, grid_size.y * cell_size)
	grid_offset = (window_size - grid_pixel_size) / 2

func _draw():
	_draw_grid()
	_draw_bridges()
	# Draw temporary bridge while dragging
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

func generate_puzzle(island_count: int):
	# Clear previous islands
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

		# Create Sprite2D
		var sprite = Sprite2D.new()
		sprite.position = grid_offset + pos * cell_size
		sprite.centered = true
		sprite.scale = Vector2(0.6,0.6)

		# Load texture
		var texture_path = "res://assets/islands/7x7/%d.png" % bridges_target
		if ResourceLoader.exists(texture_path):
			sprite.texture = load(texture_path)
		else:
			print("⚠️ Missing texture:", texture_path)

		add_child(sprite)

		var island = {
			"pos": pos,
			"node": sprite,
			"bridges_target": bridges_target,
			"connected_bridges": 0
		}
		puzzle_data.append(island)

	print("✅ Puzzle generated with ", puzzle_data.size(), " islands")
	queue_redraw()

# ---------------- Bridge Placement ------------------

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
	# Must be horizontal or vertical
	if a.pos.x != b.pos.x and a.pos.y != b.pos.y:
		print("❌ Bridges must be horizontal or vertical")
		return

	# Max 2 bridges
	for br in bridges:
		if (br.start_island == a and br.end_island == b) or (br.start_island == b and br.end_island == a):
			if br.count < 2:
				br.count += 1
				a.connected_bridges += 1
				b.connected_bridges += 1
				print("✅ Added second bridge")
				return
			else:
				print("❌ Max 2 bridges reached")
				return

	# Check crossing bridges
	for br in bridges:
		if _bridges_cross(a.node.position, b.node.position, br.start_pos, br.end_pos):
			print("❌ Bridge would cross another bridge")
			return

	# Place first bridge
	bridges.append({
		"start_island": a,
		"end_island": b,
		"start_pos": a.node.position,
		"end_pos": b.node.position,
		"count": 1
	})
	a.connected_bridges += 1
	b.connected_bridges += 1
	print("✅ Bridge placed")

func _bridges_cross(p1, p2, q1, q2):
	# Only horizontal/vertical bridges
	if p1.x == p2.x and q1.y == q2.y:
		return (p1.x > min(q1.x,q2.x) and p1.x < max(q1.x,q2.x)) and (q1.y > min(p1.y,p2.y) and q1.y < max(p1.y,p2.y))
	if p1.y == p2.y and q1.x == q2.x:
		return (p1.y > min(q1.y,q2.y) and p1.y < max(q1.y,q2.y)) and (q1.x > min(p1.x,p2.x) and q1.x < max(p1.x,p2.x))
	return false
	
func _on_backbutton_pressed() -> void:
	click.play()
	await get_tree().create_timer(0.1).timeout
	get_tree().change_scene_to_file("res://scenes/choose_grid_size.tscn")
