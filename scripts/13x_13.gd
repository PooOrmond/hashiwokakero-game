extends Node2D

# Configuration for 13x13
@export var grid_size: Vector2i = Vector2i(14, 14) # 13x13 grid with border
@export var cell_size: int = 32
@export var puzzle_folder: String = "13x13"

# Background
@onready var congrats_bg: AnimatedSprite2D = $background/congrats_bg
@onready var normal_bg: AnimatedSprite2D = $background/normal_bg

# Audio
@onready var click: AudioStreamPlayer2D = $click
@onready var menu_panel = preload("res://scenes/menu_popup_panel.tscn")

# UI Buttons - Only these two will be invisible when solved
@onready var solve_button: TextureButton = $"buttons/solve-button"
@onready var hint_button: TextureButton = $"buttons/hint-button"

var panel

# Grid variables
var grid_offset := Vector2.ZERO

# Puzzle solver instance
var puzzle_solver

# Interaction variables
var bridge_start_island = null
var temp_bridge_line = null

# Puzzle state
var current_puzzle_index := 1
var was_solved := false  # Track if puzzle was just solved

func _ready():
	# Add this line to register this node for group calls
	add_to_group("puzzle_scene")
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
	
	# Initialize background and button states
	_reset_background_to_normal()
	_update_ui_state()
	queue_redraw()

func _process(delta):
	# Update the puzzle solver for hint timer and animation functionality
	if puzzle_solver:
		puzzle_solver.update(delta)
		# Always redraw when animating to ensure smooth updates
		if puzzle_solver.is_animating():
			queue_redraw()
		# Also redraw when hints change or animation completes
		elif puzzle_solver.get_hint_bridges().size() > 0:
			queue_redraw()
	
	# Check if puzzle was just solved to update UI
	if puzzle_solver and puzzle_solver.is_puzzle_solved() and not was_solved:
		was_solved = true
		_on_puzzle_solved()
	elif puzzle_solver and not puzzle_solver.is_puzzle_solved() and was_solved:
		was_solved = false
		_on_puzzle_unsolved()

func _on_puzzle_solved():
	"""Called when puzzle is solved"""
	print("🎉 Puzzle solved! Updating UI...")
	_update_ui_state()
	
	# Show congratulations background
	if congrats_bg:
		congrats_bg.visible = true
		congrats_bg.play()  # Play animation if it's an AnimatedSprite2D
	if normal_bg:
		normal_bg.visible = false

func _on_puzzle_unsolved():
	"""Called when puzzle is no longer solved (restart/new game)"""
	print("🔄 Puzzle reset, restoring normal UI...")
	_update_ui_state()
	_reset_background_to_normal()

func _reset_background_to_normal():
	"""Force reset background to normal state"""
	print("🔄 Resetting background to normal...")
	if congrats_bg:
		congrats_bg.visible = false
		congrats_bg.stop()  # Stop animation if it's an AnimatedSprite2D
	if normal_bg:
		normal_bg.visible = true

func _update_ui_state():
	"""Update button visibility based on puzzle state"""
	var is_solved = puzzle_solver and puzzle_solver.is_puzzle_solved()
	
	# Only hide solve and hint buttons when puzzle is solved
	if hint_button:
		hint_button.visible = not is_solved
	if solve_button:
		solve_button.visible = not is_solved

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
	# Draw horizontal lines
	for y in range(1, grid_size.y):
		draw_line(
			grid_offset + Vector2(1, y * cell_size),
			grid_offset + Vector2(grid_size.x * cell_size, y * cell_size),
			Color(0.7, 0.7, 0.7, 1.0),
			2.0
		)
	
	# Draw vertical lines
	for x in range(1, grid_size.x):
		draw_line(
			grid_offset + Vector2(x * cell_size, 0),
			grid_offset + Vector2(x * cell_size, grid_size.y * cell_size),
			Color(0.7, 0.7, 0.7, 1.0),
			2.0
		)

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
	var width = 3  # Thinner bridges for smaller grid
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
	var width = 3  # Thinner hint bridges
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
				# Click empty space: maybe remove bridge
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

# ==================== SOLVER BUTTON FUNCTIONS ====================

func _on_csp_solve_pressed() -> void:
	"""
	Solve using CSP-based algorithmic solver (instant)
	"""
	if puzzle_solver.is_puzzle_solved():
		print("Puzzle already solved!")
		return
	
	if puzzle_solver.is_animating():
		print("Animation already in progress!")
		return
	
	click.play()
	puzzle_solver.clear_hint_bridges()
	
	print("🔄 Starting CSP solver...")
	var success = puzzle_solver.csp_based_solver()
	
	if success:
		print("🎉 CSP solver completed!")
	else:
		print("❌ CSP solver failed!")
	
	queue_redraw()

func _on_solvebutton_pressed() -> void:
	"""
	Solve using step-by-step animation
	"""
	if puzzle_solver.is_puzzle_solved():
		print("Puzzle already solved!")
		return
	
	if puzzle_solver.is_animating():
		print("Animation already in progress!")
		return
	
	click.play()
	puzzle_solver.clear_hint_bridges()
	
	# Use step-by-step solver animation
	print("🎬 Starting step-by-step solver animation...")
	var success = puzzle_solver.start_step_by_step_solution()
	
	if success:
		print("✅ Step-by-step animation started!")
	else:
		print("❌ Failed to start animation, using instant solver...")
		# Fallback to instant solver
		puzzle_solver.csp_based_solver()
	
	queue_redraw()

func _on_hintbutton_pressed() -> void:
	if puzzle_solver.is_puzzle_solved():
		print("Puzzle already solved! No hints needed.")
		return
	
	click.play()
	
	# Use CSP-based hints
	puzzle_solver.csp_based_hint()
	
	queue_redraw()
	
func show_menu_panel():
	if not panel:
		panel = menu_panel.instantiate()
		add_sibling(panel)

func _on_menupanel_pressed() -> void:
	show_menu_panel()

# ==================== NEW GAME & RESTART FUNCTIONS ====================

func load_new_puzzle():
	"""
	Load a completely new puzzle with different input/output files
	"""
	print("🔄 Loading new puzzle...")
	
	# Clear current state
	_clear_current_puzzle()
	
	# Generate a new random puzzle index (different from current)
	var new_puzzle_index = current_puzzle_index
	while new_puzzle_index == current_puzzle_index:
		new_puzzle_index = randi() % 5 + 1
	
	current_puzzle_index = new_puzzle_index
	print("🎲 Selected new puzzle index: ", current_puzzle_index)
	
	# Reload with new puzzle
	_reload_puzzle()
	
	# Force reset background
	_reset_background_to_normal()

func restart_current_puzzle():
	"""
	Restart the current puzzle (same input/output files)
	"""
	print("🔄 Restarting current puzzle...")
	
	# Clear current state
	_clear_current_puzzle()
	
	# Reload with same puzzle index
	print("🔄 Reloading puzzle index: ", current_puzzle_index)
	_reload_puzzle()
	
	# Force reset background
	_reset_background_to_normal()

func _clear_current_puzzle():
	"""
	Clear the current puzzle state
	"""
	# Clear bridges and reset islands
	if puzzle_solver:
		puzzle_solver.bridges.clear()
		puzzle_solver.hint_bridges.clear()
		puzzle_solver.puzzle_solved = false
		puzzle_solver.reset_solver()
		
		# Reset all islands' connected bridges count
		for island in puzzle_solver.get_puzzle_data():
			island.connected_bridges = 0
	
	# Clear interaction variables
	bridge_start_island = null
	temp_bridge_line = null

func _reload_puzzle():
	"""
	Reload the puzzle with current index
	"""
	if puzzle_solver:
		# Set puzzle info
		puzzle_solver.set_puzzle_info(puzzle_folder, current_puzzle_index)
		
		# Load the puzzle file
		var file_path = "res://assets/input/%s/input-%02d.txt" % [puzzle_folder, current_puzzle_index]
		puzzle_solver.load_custom_puzzle(file_path, self)
		
		# Reset AI solver state if active
		puzzle_solver.reset_solver()
		
		# Stop auto-solve timer if running
		if has_node("AutoSolveTimer"):
			$AutoSolveTimer.stop()
	
	# Reset UI state
	was_solved = false
	_update_ui_state()
	queue_redraw()
	print("✅ Puzzle reloaded successfully!")


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
		puzzle_solver.apply_next_step()
		queue_redraw()
	else:
		$AutoSolveTimer.stop()
		print("✅ Auto-solve completed!")
		puzzle_solver.clear_hint_bridges()
		queue_redraw()
