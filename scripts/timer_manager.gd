# timer_manager.gd
extends Node

# Timer signals
signal timer_started
signal timer_paused
signal timer_resumed
signal timer_finished
signal timer_updated(time_left)

# Timer state
var is_timer_active := false
var is_paused := false
var time_left := 0.0  # Changed to float
var total_time := 0.0  # Changed to float
var selected_time := 0  # Store the chosen time in seconds

# Game state
var selected_grid_size := ""
var start_time := 0

func _process(delta: float) -> void:
	if is_timer_active and not is_paused and time_left > 0:
		time_left -= delta
		emit_signal("timer_updated", time_left)
		
		if time_left <= 0:
			time_left = 0.0
			is_timer_active = false
			emit_signal("timer_finished")

# Timer control methods
func start_timer(seconds: int) -> void:
	selected_time = seconds
	total_time = float(seconds)  # Explicit cast to float
	time_left = float(seconds)   # Explicit cast to float
	is_timer_active = true
	is_paused = false
	start_time = Time.get_unix_time_from_system()
	emit_signal("timer_started")

func pause_timer() -> void:
	if is_timer_active and not is_paused:
		is_paused = true
		emit_signal("timer_paused")

func resume_timer() -> void:
	if is_timer_active and is_paused:
		is_paused = false
		emit_signal("timer_resumed")

func stop_timer() -> void:
	is_timer_active = false
	is_paused = false
	time_left = 0.0

func get_time_left() -> int:
	return int(max(0.0, time_left))

func get_formatted_time() -> String:
	var time_int = int(time_left)  # Convert to int once
	var minutes = time_int / 60  # Intentional integer division
	var seconds = time_int % 60
	return "%02d:%02d" % [minutes, seconds]

func get_time_progress() -> float:
	if total_time <= 0.0:
		return 1.0
	return time_left / total_time

func is_time_up() -> bool:
	return time_left <= 0.0

# Grid size tracking
func set_grid_size(size: String) -> void:
	selected_grid_size = size

func get_grid_size() -> String:
	return selected_grid_size

func get_selected_time() -> int:
	return selected_time

func reset_timer_state() -> void:
	is_timer_active = false
	is_paused = false
	time_left = 0.0
	total_time = 0.0
