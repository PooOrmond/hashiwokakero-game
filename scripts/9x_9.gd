extends Node2D

# Configuration for 9x9 - Updated values for 9x9 grid
@export var grid_size: Vector2i = Vector2i(10, 10) # 9x9 grid with border
@export var cell_size: int = 42  # Reduced from 48 to make grid smaller
@export var puzzle_folder: String = "9x9"

# Audio
@onready var click: AudioStreamPlayer2D = $click

# Grid variables
var grid_offset := Vector2.ZERO

# Puzzle solver instance
var puzzle_solver

# Interaction variables
var bridge_start_island = null
var temp_bridge_line = null

# Puzzle state
var current_puzzle_index := 1

func _ready():
	randomize()
	_calculate_grid_offset()
	
	# Initialize puzzle solver
	puzzle_solver = load("res://scripts/solver.gd").new()
	puzzle_solver.initialize(grid_size, cell_size, grid_offset)
	
	current_puzzle_index = randi() % 5 + 1
	# Set puzzle info BEFORE loading the puzzle
	puzzle_solver.set_puzzle_info(puzzle_folder, current_puzzle_index)
	
	var file_path = "res://assets/input/%s/input-%02d.txt" % [puzzle_folder, current_puzzle_index]
	puzzle_solver.load_custom_puzzle(file_path, self)
	queue_redraw()


func _process(delta):
	# Update the puzzle solver for hint timer functionality
	if puzzle_solver:
		puzzle_solver.update(delta)
		# Redraw if hints were cleared by the timer
		if puzzle_solver.get_hint_bridges().is_empty():
			queue_redraw()

func _calculate_grid_offset():
	var window_size = Vector2(800, 650)
	var grid_pixel_size = Vector2(grid_size.x * cell_size, grid_size.y * cell_size)
	grid_offset = (window_size - grid_pixel_size) / 2
	# Keep the grid centered but with the new smaller cell size

func _draw():
	_draw_grid()
	_draw_bridges()
	_draw_hint_bridges()
	if temp_bridge_line:
		draw_line(temp_bridge_line[0], temp_bridge_line[1], Color(0,0,0), 4)

func _draw_grid():
	for y in range(1, grid_size.y):
		draw_line(grid_offset + Vector2(0, y*cell_size),
				  grid_offset + Vector2(grid_size.x*cell_size, y*cell_size),
				  Color(0.7, 0.7, 0.7, 1.0), 2.0)
	
	for x in range(1, grid_size.x):
		draw_line(grid_offset + Vector2(x*cell_size, 0),
				  grid_offset + Vector2(x*cell_size, grid_size.y*cell_size),
				  Color(0.7, 0.7, 0.7, 1.0), 2.0)

func _draw_bridges():
	for br in puzzle_solver.get_bridges():
		_draw_bridge(br)

func _draw_hint_bridges():
	for br in puzzle_solver.get_hint_bridges():
		_draw_hint_bridge(br)

func _draw_bridge(br):
	if not br or not br.start_island or not br.end_island:
		return
		
	var color = Color(0,0,0)
	var width = 3  # Slightly thinner for smaller grid
	var start_pos = br.start_island.node.position - global_position
	var end_pos = br.end_island.node.position - global_position

	if br.count == 2:
		if start_pos.x == end_pos.x: # vertical
			draw_line(start_pos + Vector2(-2,0), end_pos + Vector2(-2,0), color, width)
			draw_line(start_pos + Vector2(2,0), end_pos + Vector2(2,0), color, width)
		else: # horizontal
			draw_line(start_pos + Vector2(0,-2), end_pos + Vector2(0,-2), color, width)
			draw_line(start_pos + Vector2(0,2), end_pos + Vector2(0,2), color, width)
	else:
		draw_line(start_pos, end_pos, color, width)

func _draw_hint_bridge(br):
	if not br or not br.start_island or not br.end_island:
		return
		
	var color = Color(1.0, 0.9, 0.1, 0.9)
	var width = 3  # Slightly thinner for smaller grid
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

# ==================== PLAYER INTERACTION ====================

func _input(event):
	if event is InputEventMouseButton:
		if event.pressed:
			var clicked = puzzle_solver._get_island_at_pos(event.position, global_position)
			if clicked:
				bridge_start_island = clicked
				temp_bridge_line = [clicked.node.position, clicked.node.position]
				queue_redraw()
			else:
				var br = puzzle_solver._get_bridge_at_pos(event.position, global_position)
				if br:
					puzzle_solver._remove_bridge(br)
					queue_redraw()
		else:
			if bridge_start_island and temp_bridge_line:
				var end_island = puzzle_solver._get_island_at_pos(event.position, global_position)
				if end_island and end_island != bridge_start_island:
					puzzle_solver._try_place_bridge(bridge_start_island, end_island)
				bridge_start_island = null
				temp_bridge_line = null
				queue_redraw()
	elif event is InputEventMouseMotion:
		if bridge_start_island:
			temp_bridge_line = [bridge_start_island.node.position, event.position]
			queue_redraw()

# ==================== HINT SYSTEM ====================

func _generate_enhanced_hint():
	puzzle_solver._generate_enhanced_hint()
	queue_redraw()

# ==================== SOLUTION LOADING ====================

func _load_solution_robust():
	var output_file = "res://assets/output/%s/output-%02d.txt" % [puzzle_folder, current_puzzle_index]
	puzzle_solver._load_solution_robust(output_file)
	queue_redraw()

# ==================== UI CONTROL FUNCTIONS ====================

func _on_backbutton_pressed() -> void:
	click.play()
	await get_tree().create_timer(0.1).timeout
	get_tree().change_scene_to_file("res://scenes/choose_grid_size.tscn")

func _on_hintbutton_pressed() -> void:
	if puzzle_solver.is_puzzle_solved():
		print("Puzzle already solved! No hints needed.")
		return
	
	click.play()
	_generate_enhanced_hint()

func _on_solvebutton_pressed() -> void:
	if puzzle_solver.is_puzzle_solved():
		print("Puzzle already solved!")
		return
	
	click.play()
	puzzle_solver.clear_hint_bridges()
	_load_solution_robust()

# ==================== AI SOLVER BUTTONS ====================

func _on_ai_solve_button_pressed() -> void:
	if puzzle_solver.is_puzzle_solved():
		print("Puzzle already solved!")
		return
	
	click.play()
	puzzle_solver.clear_hint_bridges()
	
	# Use the new backtracking solver instead of file loading
	if puzzle_solver.solve_with_backtracking():
		print("✅ AI solved the puzzle with backtracking!")
		start_auto_solve_mode()
	else:
		print("❌ AI failed to solve the puzzle")

func _on_ai_hint_button_pressed() -> void:
	if puzzle_solver.is_puzzle_solved():
		print("Puzzle already solved! No hints needed.")
		return
	
	click.play()
	var hint = puzzle_solver.provide_ai_hint()
	show_ai_hint_popup(hint)

func _on_next_step_button_pressed() -> void:
	click.play()
	if puzzle_solver.auto_complete_step():
		queue_redraw()
		print("Step completed: ", puzzle_solver.get_step_progress())
	else:
		print("No more steps to complete or puzzle already solved")

# ==================== AI SOLVER SUPPORT FUNCTIONS ====================

func start_auto_solve_mode():
	print("🚀 Starting auto-solve mode")
	# Start a timer to auto-complete steps
	if not has_node("AutoSolveTimer"):
		var timer = Timer.new()
		timer.name = "AutoSolveTimer"
		timer.timeout.connect(_on_auto_solve_timer_timeout)
		add_child(timer)
	
	$AutoSolveTimer.start(0.3)  # One step every 0.3 seconds

func show_ai_hint_popup(hint_text: String):
	# Show AI-generated hint
	print("💡 AI HINT: ", hint_text)
	
	# If you have a UI label for hints, update it:
	# $UI/HintLabel.text = hint_text
	
	# Optional: Show the hint as a visual bridge
	puzzle_solver.show_next_hint_as_bridge()
	queue_redraw()

func _on_auto_solve_timer_timeout():
	if puzzle_solver.has_next_step():
		puzzle_solver.auto_complete_step()
		queue_redraw()
	else:
		$AutoSolveTimer.stop()
		print("✅ Auto-solve completed!")
		puzzle_solver.clear_hint_bridges()
		queue_redraw()
