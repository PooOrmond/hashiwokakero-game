extends Node2D

@onready var timer: Label = $timer
@onready var click: AudioStreamPlayer2D = $click
@onready var menu_panel = preload("res://scenes/menu_popup_panel.tscn")
@onready var solve_button: TextureButton = $"buttons/solve-button"
@onready var hint_button: TextureButton = $"buttons/hint-button"

# Configuration for 7x7 
@export var grid_size: Vector2i = Vector2i(10, 10) 
@export var cell_size: int = 42
@export var puzzle_folder: String = "9x9"

#bg change
@onready var congrats_bg: AnimatedSprite2D = $background/congrats_bg
@onready var normal_bg: AnimatedSprite2D = $background/normal_bg 

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

# Timer state
var is_time_up := false
var is_puzzle_solved_and_locked := false  # Track if puzzle is solved and locked

# Animation speed variables
var original_animation_delay := 0.6  # Store original animation speed
var current_animation_delay := 0.6   # Current animation speed (can be adjusted)

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
	_reset_background_to_normal()  # Ensure normal background on start
	_update_ui_state()
	
	# Initialize timer
	if TimerManager.get_selected_time() > 0:
		timer.text = TimerManager.get_formatted_time()
		timer.visible = true
		
		# Connect to timer signals
		TimerManager.timer_updated.connect(_on_timer_updated)
		TimerManager.timer_finished.connect(_on_time_up)
	else:
		timer.visible = false
		is_time_up = false
	
	# Reset lock state
	is_puzzle_solved_and_locked = false
	
	# Reset animation speed
	original_animation_delay = 0.6
	current_animation_delay = original_animation_delay
	
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
	
	# Update timer display
	if TimerManager.get_selected_time() > 0 and TimerManager.is_timer_active and not TimerManager.is_paused:
		timer.text = TimerManager.get_formatted_time()
		
		# Stop animation if timer runs out during animation
		if TimerManager.is_time_up() and puzzle_solver and puzzle_solver.is_animating():
			print("Timer ran out during animation - stopping animation")
			puzzle_solver.stop_animation()
			_on_time_up()
	
	# Check if puzzle was just solved to update UI
	if puzzle_solver and puzzle_solver.is_puzzle_solved() and not was_solved:
		was_solved = true
		_on_puzzle_solved()
	elif puzzle_solver and not puzzle_solver.is_puzzle_solved() and was_solved:
		was_solved = false
		is_puzzle_solved_and_locked = false  # Reset lock when puzzle is no longer solved
		_on_puzzle_unsolved()

func _on_timer_updated(time_left: float) -> void:
	timer.text = TimerManager.get_formatted_time()
	
	# Change color when time is running low
	if time_left <= 30:
		timer.modulate = Color(1, 0.3, 0.3)  # Red
	elif time_left <= 60:
		timer.modulate = Color(1, 1, 0.3)  # Yellow
	else:
		timer.modulate = Color(1, 1, 1)  # White
	
	# Adjust animation speed based on remaining time
	_adjust_animation_speed(time_left)

func _adjust_animation_speed(time_left: float) -> void:
	"""Adjust animation speed based on remaining time"""
	if puzzle_solver and puzzle_solver.is_animating():
		# Calculate speed multiplier based on time left
		# When time is low, speed up the animation
		var speed_multiplier = 1.0
		
		if time_left <= 10:
			# Very low time - maximum speed (4x faster)
			speed_multiplier = 4.0
		elif time_left <= 30:
			# Low time - faster animation (2x faster)
			speed_multiplier = 2.0
		elif time_left <= 60:
			# Medium time - slightly faster (1.5x faster)
			speed_multiplier = 1.5
		
		# Update animation delay in solver
		current_animation_delay = original_animation_delay / speed_multiplier
		puzzle_solver.set_animation_delay(current_animation_delay)
		
		# Optional: Print speed change for debugging
		if speed_multiplier > 1.0:
			print("Animation speed increased to %.1fx (%.2fs delay)" % [speed_multiplier, current_animation_delay])

func _on_time_up() -> void:
	print("Time's up!")
	is_time_up = true
	
	# Stop any ongoing animation immediately
	if puzzle_solver and puzzle_solver.is_animating():
		print("Stopping animation due to time up")
		puzzle_solver.stop_animation()
	
	# Stop auto-solve timer if running
	if has_node("AutoSolveTimer"):
		$AutoSolveTimer.stop()
	
	# Change timer label to "Time's Up!"
	timer.text = "Time's Up!"
	timer.modulate = Color(1, 0.3, 0.3)  # Red color
	
	# Hide hint and solve buttons
	if hint_button:
		hint_button.visible = false
	if solve_button:
		solve_button.visible = false
	
	# Reset background to normal (remove congratulations if shown)
	_reset_background_to_normal()
	
	# Disable puzzle interaction
	set_process_input(false)
	
	queue_redraw()

func _on_puzzle_solved():
	"""Called when puzzle is solved"""
	print("Puzzle solved! Updating UI...")
	
	# Stop timer if active
	if TimerManager.get_selected_time() > 0:
		TimerManager.stop_timer()
		is_time_up = false
	
	# Stop any ongoing animation
	if puzzle_solver and puzzle_solver.is_animating():
		puzzle_solver.stop_animation()
	
	# Stop auto-solve timer if running
	if has_node("AutoSolveTimer"):
		$AutoSolveTimer.stop()
	
	# LOCK the puzzle - player cannot modify bridges anymore
	is_puzzle_solved_and_locked = true
	
	_update_ui_state()
	
	# Show congratulations background
	if congrats_bg:
		congrats_bg.visible = true
		congrats_bg.play()  # Play animation if it's an AnimatedSprite2D
	if normal_bg:
		normal_bg.visible = false

func _on_puzzle_unsolved():
	"""Called when puzzle is no longer solved (restart/new game)"""
	print("Puzzle reset, restoring normal UI...")
	
	# UNLOCK the puzzle
	is_puzzle_solved_and_locked = false
	
	_update_ui_state()
	_reset_background_to_normal()

func _reset_background_to_normal():
	"""Force reset background to normal state"""
	print("Resetting background to normal...")
	if congrats_bg:
		congrats_bg.visible = false
		congrats_bg.stop()  # Stop animation if it's an AnimatedSprite2D
	if normal_bg:
		normal_bg.visible = true

func _update_ui_state():
	"""Update button visibility based on puzzle and timer state"""
	var is_solved = puzzle_solver and puzzle_solver.is_puzzle_solved()
	
	# Hide buttons when time's up or puzzle is solved
	if hint_button:
		hint_button.visible = not is_solved and not is_time_up
	if solve_button:
		solve_button.visible = not is_solved and not is_time_up

func _calculate_grid_offset():
	var window_size = Vector2(800, 650)
	var grid_pixel_size = Vector2(grid_size.x * cell_size, grid_size.y * cell_size)
	grid_offset = (window_size - grid_pixel_size) / 2

func _draw():
	_draw_grid()
	if is_time_up:
		_draw_bridges_red()  # Draw bridges in red when time's up
	else:
		_draw_bridges()
	_draw_hint_bridges()
	if temp_bridge_line:
		draw_line(temp_bridge_line[0], temp_bridge_line[1], Color(0,0,0), 4)

func _draw_bridges_red():
	for br in puzzle_solver.get_bridges():
		_draw_bridge_red(br)

func _draw_bridge_red(br):
	if not br or not br.start_island or not br.end_island:
		return
		
	var color = Color(1, 0.3, 0.3, 0.7)  # Red with slight transparency
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
	if not br or not br.start_island or not br.end_island:
		return
		
	var color = Color(1.0, 0.9, 0.1, 0.9)
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

# ==================== PLAYER INTERACTION ====================

func _input(event):
	# Disable all input when time's up OR puzzle is solved and locked
	if is_time_up or is_puzzle_solved_and_locked:
		return
	
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

# ==================== SOLVER BUTTON FUNCTIONS ====================

func _on_csp_solve_pressed() -> void:
	if is_time_up or is_puzzle_solved_and_locked:
		return
	
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
	
	# PAUSE TIMER DURING LOADING (for consistency with 13x13, though 7x7 is fast)
	if TimerManager.get_selected_time() > 0:
		TimerManager.pause_timer()
	
	print("Starting CSP solver...")
	var success = puzzle_solver.csp_based_solver()
	
	if success:
		print("CSP solver completed!")
	else:
		print("CSP solver failed!")
	
	# RESUME TIMER AFTER LOADING
	if TimerManager.get_selected_time() > 0:
		TimerManager.resume_timer()
	
	queue_redraw()

func _on_solvebutton_pressed() -> void:
	if is_time_up or is_puzzle_solved_and_locked:
		return
	
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
	
	# Check time before starting - if very low time, warn user
	if TimerManager.get_selected_time() > 0:
		var time_left = TimerManager.get_time_left()
		if time_left < 15:  # Less than 15 seconds left
			print("Warning: Very little time left (%d seconds)" % time_left)
	
	# PAUSE TIMER DURING LOADING
	if TimerManager.get_selected_time() > 0:
		TimerManager.pause_timer()
	
	# Reset animation completion flag and solved state
	puzzle_solver.animation_completed = false
	was_solved = false
	
	# Reset animation speed to normal before starting
	current_animation_delay = original_animation_delay
	
	# Use step-by-step solver animation
	print("Starting step-by-step solver animation...")
	var success = puzzle_solver.start_step_by_step_solution()
	
	if success:
		print("Step-by-step animation started!")
	else:
		print("Failed to start animation, using instant solver...")
		# Fallback to instant solver
		if puzzle_solver.csp_based_solver():
			# If instant solver worked, update UI
			_on_puzzle_solved()
	
	# RESUME TIMER AFTER LOADING
	if TimerManager.get_selected_time() > 0:
		TimerManager.resume_timer()
	
	queue_redraw()

func _on_hintbutton_pressed() -> void:
	if is_time_up or is_puzzle_solved_and_locked or puzzle_solver.is_puzzle_solved():
		return
	
	click.play()
	
	# PAUSE TIMER DURING HINT GENERATION (for consistency)
	if TimerManager.get_selected_time() > 0:
		TimerManager.pause_timer()
	
	# Use CSP-based hints
	puzzle_solver.csp_based_hint()
	
	# RESUME TIMER AFTER HINT GENERATION
	if TimerManager.get_selected_time() > 0:
		TimerManager.resume_timer()
	
	queue_redraw()
	
func show_menu_panel():
	if not panel:
		panel = menu_panel.instantiate()
		add_sibling(panel)

func _on_menupanelbutton_pressed() -> void:
	show_menu_panel()

# ==================== NEW GAME & RESTART FUNCTIONS ====================

func load_new_puzzle():
	"""
	Load a completely new puzzle with different input/output files
	"""
	print("Loading new puzzle...")
	
	# Clear current state
	_clear_current_puzzle()
	
	# Reset timer if active
	if TimerManager.get_selected_time() > 0:
		TimerManager.stop_timer()
		TimerManager.start_timer(TimerManager.get_selected_time())
		is_time_up = false
		set_process_input(true)
		timer.text = TimerManager.get_formatted_time()
		timer.modulate = Color(1, 1, 1)
	
	# UNLOCK the puzzle
	is_puzzle_solved_and_locked = false
	
	# Reset animation speed to normal
	current_animation_delay = original_animation_delay
	
	# Generate a new random puzzle index (different from current)
	var new_puzzle_index = current_puzzle_index
	while new_puzzle_index == current_puzzle_index:
		new_puzzle_index = randi() % 5 + 1
	
	current_puzzle_index = new_puzzle_index
	print("Selected new puzzle index: ", current_puzzle_index)
	
	# Reload with new puzzle
	_reload_puzzle()
	
	# Force reset background
	_reset_background_to_normal()
	
	# Re-enable buttons
	_update_ui_state()

func restart_current_puzzle():
	"""
	Restart the current puzzle (same input/output files)
	"""
	print("Restarting current puzzle...")
	
	# Clear current state
	_clear_current_puzzle()
	
	# Reset timer if active
	if TimerManager.get_selected_time() > 0:
		TimerManager.stop_timer()
		TimerManager.start_timer(TimerManager.get_selected_time())
		is_time_up = false
		set_process_input(true)
		timer.text = TimerManager.get_formatted_time()
		timer.modulate = Color(1, 1, 1)
	
	# UNLOCK the puzzle
	is_puzzle_solved_and_locked = false
	
	# Reset animation speed to normal
	current_animation_delay = original_animation_delay
	
	# Reload with same puzzle index
	print("Reloading puzzle index: ", current_puzzle_index)
	_reload_puzzle()
	
	# Force reset background
	_reset_background_to_normal()
	
	# Re-enable buttons
	_update_ui_state()

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
	print("Puzzle reloaded successfully!")


# ==================== AI SOLVER SUPPORT FUNCTIONS ====================

func start_auto_solve_mode():
	print("Starting auto-solve mode")
	# Start a timer to auto-complete steps
	if not has_node("AutoSolveTimer"):
		var auto_timer = Timer.new()  # Renamed to avoid shadowing
		auto_timer.name = "AutoSolveTimer"
		auto_timer.timeout.connect(_on_auto_solve_timer_timeout)
		add_child(auto_timer)
	
	$AutoSolveTimer.start(0.3)  # One step every 0.3 seconds

func show_ai_hint_popup(hint_text: String):
	# Show AI-generated hint
	print("AI HINT: ", hint_text)
	
	# Optional: Show the hint as a visual bridge
	puzzle_solver.show_next_hint_as_bridge()
	queue_redraw()

func _on_auto_solve_timer_timeout():
	if puzzle_solver.has_next_step():
		puzzle_solver.apply_next_step()
		queue_redraw()
	else:
		$AutoSolveTimer.stop()
		print("Auto-solve completed!")
		puzzle_solver.clear_hint_bridges()
		queue_redraw()

# Clean up connections when scene changes
func _exit_tree() -> void:
	if TimerManager.timer_updated.is_connected(_on_timer_updated):
		TimerManager.timer_updated.disconnect(_on_timer_updated)
	if TimerManager.timer_finished.is_connected(_on_time_up):
		TimerManager.timer_finished.disconnect(_on_time_up)
